import Foundation
import Observation
import SwiftData

/// Push the outbox, then pull `/sync` until `hasMore` is false (docs/ios-plan.md, Phase 5).
///
/// Rules:
/// - mutations are pushed oldest first; a 409 or 422 parks the mutation for the user and the push goes on;
///   a network or 5xx error stops everything and retries later with backoff;
/// - a pull never overwrites an entity that has a mutation: if the server moved past the mutation's
///   `baseVersion`, the mutation becomes a conflict.
@Observable
final class SyncEngine {
	enum Phase: Equatable {
		case idle
		case syncing
		case offline
		case failed(String)
	}

	private(set) var phase: Phase = .idle
	private(set) var lastSyncAt: Date?
	private(set) var pendingCount = 0
	private(set) var issueCount = 0

	/// Set by the connectivity monitor.
	var isOnline = true {
		didSet {
			if isOnline, !oldValue { scheduleSync(after: .zero) }
		}
	}

	/// Sync only while logged in and unlocked.
	@ObservationIgnored var canSync: () -> Bool = { true }
	/// The refresh token is gone: back to the login screen (local data and outbox are kept).
	@ObservationIgnored var onSessionExpired: (() -> Void)?

	@ObservationIgnored let outbox: Outbox
	@ObservationIgnored private let context: ModelContext
	@ObservationIgnored private let api: APIClientProtocol
	@ObservationIgnored private var isRunning = false
	@ObservationIgnored private var needsAnotherPass = false
	@ObservationIgnored private var debounceTask: Task<Void, Never>?
	@ObservationIgnored private var retryTask: Task<Void, Never>?
	@ObservationIgnored private var retryDelay: Duration = .seconds(5)

	static let pageSize = 500

	init(context: ModelContext, api: APIClientProtocol) {
		self.context = context
		self.api = api
		self.outbox = Outbox(context: context)
		lastSyncAt = context.syncMeta().lastSyncAt
		refreshCounts()
	}

	// MARK: Scheduling

	/// Coalesces bursts of local edits into one sync.
	func scheduleSync(after delay: Duration = .seconds(2)) {
		debounceTask?.cancel()
		debounceTask = Task {
			if delay > .zero { try? await Task.sleep(for: delay) }
			guard !Task.isCancelled else { return }
			await sync()
		}
	}

	func sync() async {
		guard canSync() else { return }
		guard !isRunning else {
			needsAnotherPass = true
			return
		}
		isRunning = true
		phase = .syncing
		defer {
			isRunning = false
			refreshCounts()
		}

		repeat {
			needsAnotherPass = false
			do {
				try await push()
				try await pull()
				phase = .idle
				lastSyncAt = .now
				retryDelay = .seconds(5)
				retryTask?.cancel()
			} catch let error as APIError {
				handle(error)
				return
			} catch {
				phase = .failed(error.localizedDescription)
				return
			}
		} while needsAnotherPass
	}

	private func handle(_ error: APIError) {
		switch error {
		case .network, .server:
			phase = isOnline ? .failed("Serveur injoignable") : .offline
			scheduleRetry()
		case .invalidRefreshToken:
			phase = .failed("Session expirée")
			onSessionExpired?()
		default:
			phase = .failed(error.localizedDescription)
		}
	}

	private func scheduleRetry() {
		retryTask?.cancel()
		let delay = retryDelay
		retryDelay = min(retryDelay * 3, .seconds(300))
		retryTask = Task {
			try? await Task.sleep(for: delay)
			guard !Task.isCancelled else { return }
			await sync()
		}
	}

	func refreshCounts() {
		pendingCount = outbox.pending().count
		issueCount = outbox.issues().count
	}

	// MARK: Push

	func push() async throws {
		for mutation in outbox.pending() {
			guard mutation.modelContext != nil, mutation.status == .pending else { continue }
			try await push(mutation)
			try context.save()
		}
	}

	private func push(_ mutation: PendingMutation) async throws {
		let revision = mutation.revision
		let id = mutation.entityId
		let base = mutation.baseVersion
		mutation.attempts += 1

		do {
			switch (mutation.kind, mutation.op) {
			case (.sale, .upsert):
				guard let sale = context.sale(id: id) else { return context.delete(mutation) }
				let dto = try await api.putSale(id: id, input: sale.makeInput(baseVersion: base))
				completeUpsert(mutation, revision: revision, version: dto.version) {
					sale.apply(dto)
				} keepLocal: {
					sale.version = dto.version
				}
			case (.purchase, .upsert):
				guard let purchase = context.purchase(id: id) else { return context.delete(mutation) }
				let dto = try await api.putPurchase(id: id, input: purchase.makeInput(baseVersion: base))
				completeUpsert(mutation, revision: revision, version: dto.version) {
					purchase.apply(dto)
				} keepLocal: {
					purchase.version = dto.version
				}
			case (.product, .upsert):
				guard let product = context.product(id: id) else { return context.delete(mutation) }
				let dto = try await api.putProduct(id: id, input: product.makeInput(baseVersion: base))
				completeUpsert(mutation, revision: revision, version: dto.version) {
					product.apply(dto)
				} keepLocal: {
					product.version = dto.version
				}
			case (_, .delete):
				if let base {
					switch mutation.kind {
					case .sale: _ = try await api.deleteSale(id: id, baseVersion: base)
					case .purchase: _ = try await api.deletePurchase(id: id, baseVersion: base)
					case .product: _ = try await api.deleteProduct(id: id, baseVersion: base)
					}
				}
				guard mutation.modelContext != nil else { return }
				removeEntity(mutation.kind, id: id)
				context.delete(mutation)
			}
		} catch let error as APIError {
			guard mutation.modelContext != nil else { return }
			switch error {
			case let .conflict(current):
				markConflict(mutation, snapshot: current, serverMissing: current == nil)
			case let .validation(message, fields):
				markRejected(mutation, message: message, fields: fields)
			case let .forbidden(message), let .badRequest(message):
				markRejected(mutation, message: message, fields: [:])
			case .notFound where mutation.op == .delete:
				removeEntity(mutation.kind, id: id)
				context.delete(mutation)
			case .notFound:
				markRejected(mutation, message: "Introuvable sur le serveur.", fields: [:])
			default:
				mutation.lastError = error.localizedDescription
				throw error
			}
		}
	}

	/// The server accepted the change. If the user edited the entity while the request was in flight,
	/// keep the local fields and the mutation, now based on the version the server just returned.
	private func completeUpsert(
		_ mutation: PendingMutation,
		revision: Int,
		version: Int,
		apply: () -> Void,
		keepLocal: () -> Void
	) {
		guard mutation.modelContext != nil else { return }
		if mutation.revision == revision {
			apply()
			context.delete(mutation)
		} else {
			keepLocal()
			mutation.baseVersion = version
		}
	}

	private func markConflict(_ mutation: PendingMutation, snapshot: Data?, serverMissing: Bool) {
		mutation.status = .conflict
		mutation.serverSnapshot = snapshot
		mutation.serverMissing = serverMissing
		setState(.conflict, kind: mutation.kind, id: mutation.entityId)
	}

	private func markRejected(_ mutation: PendingMutation, message: String, fields: [String: String]) {
		mutation.status = .rejected
		mutation.lastError = message
		mutation.fieldErrors = fields
		setState(.rejected, kind: mutation.kind, id: mutation.entityId)
	}

	// MARK: Pull

	func pull() async throws {
		let meta = context.syncMeta()
		while true {
			let page = try await api.sync(cursor: meta.cursor, limit: Self.pageSize)
			let encoder = JSONCoding.makeEncoder()

			for dto in page.sales {
				if let mutation = outbox.mutation(for: dto.id) {
					holdBack(mutation, version: dto.version, snapshot: try? encoder.encode(dto))
				} else if let sale = context.sale(id: dto.id) {
					if dto.deletedAt == nil { sale.apply(dto) } else { context.delete(sale) }
				} else if dto.deletedAt == nil {
					context.insert(Sale(dto: dto))
				}
			}
			for dto in page.purchases {
				if let mutation = outbox.mutation(for: dto.id) {
					holdBack(mutation, version: dto.version, snapshot: try? encoder.encode(dto))
				} else if let purchase = context.purchase(id: dto.id) {
					if dto.deletedAt == nil { purchase.apply(dto) } else { context.delete(purchase) }
				} else if dto.deletedAt == nil {
					context.insert(Purchase(dto: dto))
				}
			}
			for dto in page.products {
				if let mutation = outbox.mutation(for: dto.id) {
					holdBack(mutation, version: dto.version, snapshot: try? encoder.encode(dto))
				} else if let product = context.product(id: dto.id) {
					if dto.deletedAt == nil { product.apply(dto) } else { context.delete(product) }
				} else if dto.deletedAt == nil {
					context.insert(Product(dto: dto))
				}
			}

			meta.cursor = page.cursor
			meta.lastSyncAt = .now
			try context.save()
			if !page.hasMore { break }
		}
	}

	/// A server change for an entity with a local mutation: never applied, possibly a conflict.
	private func holdBack(_ mutation: PendingMutation, version: Int, snapshot: Data?) {
		switch mutation.status {
		case .pending, .rejected:
			// A creation whose response was lost exists on the server as version 1: not a conflict.
			let serverAhead = mutation.baseVersion.map { version > $0 } ?? (version > 1)
			if serverAhead { markConflict(mutation, snapshot: snapshot, serverMissing: false) }
		case .conflict:
			mutation.serverSnapshot = snapshot
			mutation.serverMissing = false
		}
	}

	// MARK: Resolution

	/// "Garder la mienne" (and the end of "Corriger"): replay on top of the server version.
	/// If the server deleted the entity, an edit is recreated under a new id and a deletion is simply done.
	func keepMine(_ mutation: PendingMutation) {
		let header = SnapshotHeader.decode(mutation.serverSnapshot)
		let serverGone = mutation.serverMissing || header?.deletedAt != nil

		if serverGone {
			if mutation.op == .delete {
				removeEntity(mutation.kind, id: mutation.entityId)
				context.delete(mutation)
			} else {
				recreate(mutation)
			}
		} else {
			mutation.baseVersion = header?.version ?? mutation.baseVersion
			mutation.status = .pending
			mutation.serverSnapshot = nil
			mutation.lastError = nil
			mutation.fieldErrors = [:]
			setState(.pending, kind: mutation.kind, id: mutation.entityId)
		}
		try? context.save()
		refreshCounts()
		scheduleSync(after: .zero)
	}

	/// "Prendre le serveur": drop the local change and apply the server snapshot.
	func takeServer(_ mutation: PendingMutation) {
		let decoder = JSONCoding.makeDecoder()
		let id = mutation.entityId
		let snapshot = mutation.serverSnapshot

		if mutation.serverMissing || snapshot == nil {
			removeEntity(mutation.kind, id: id)
		} else if let snapshot {
			switch mutation.kind {
			case .sale:
				if let dto = try? decoder.decode(SaleDTO.self, from: snapshot) {
					if dto.deletedAt != nil { removeEntity(.sale, id: id) } else { context.sale(id: id)?.apply(dto) }
				}
			case .purchase:
				if let dto = try? decoder.decode(PurchaseDTO.self, from: snapshot) {
					if dto.deletedAt != nil { removeEntity(.purchase, id: id) } else { context.purchase(id: id)?.apply(dto) }
				}
			case .product:
				if let dto = try? decoder.decode(ProductDTO.self, from: snapshot) {
					if dto.deletedAt != nil { removeEntity(.product, id: id) } else { context.product(id: id)?.apply(dto) }
				}
			}
		}
		context.delete(mutation)
		try? context.save()
		refreshCounts()
	}

	/// Abandon a refused deletion: the entity comes back as it was.
	func cancelDeletion(_ mutation: PendingMutation) {
		guard mutation.op == .delete else { return }
		switch mutation.kind {
		case .sale: context.sale(id: mutation.entityId).map { $0.isPendingDeletion = false; $0.syncState = .synced }
		case .purchase: context.purchase(id: mutation.entityId).map { $0.isPendingDeletion = false; $0.syncState = .synced }
		case .product: context.product(id: mutation.entityId).map { $0.isPendingDeletion = false; $0.syncState = .synced }
		}
		context.delete(mutation)
		try? context.save()
		refreshCounts()
	}

	private func recreate(_ mutation: PendingMutation) {
		let id = mutation.entityId
		let newId: UUID?
		switch mutation.kind {
		case .sale:
			newId = context.sale(id: id).map { old in
				let copy = old.duplicate()
				context.insert(copy)
				context.delete(old)
				return copy.id
			}
		case .purchase:
			newId = context.purchase(id: id).map { old in
				let copy = old.duplicate()
				context.insert(copy)
				context.delete(old)
				return copy.id
			}
		case .product:
			newId = context.product(id: id).map { old in
				let copy = old.duplicate()
				context.insert(copy)
				context.delete(old)
				return copy.id
			}
		}
		let kind = mutation.kind
		context.delete(mutation)
		if let newId { outbox.recordUpsert(kind: kind, entityId: newId, currentVersion: nil) }
	}

	// MARK: Helpers

	private func removeEntity(_ kind: EntityKind, id: UUID) {
		switch kind {
		case .sale: context.sale(id: id).map(context.delete)
		case .purchase: context.purchase(id: id).map(context.delete)
		case .product: context.product(id: id).map(context.delete)
		}
	}

	private func setState(_ state: SyncState, kind: EntityKind, id: UUID) {
		switch kind {
		case .sale: context.sale(id: id)?.syncState = state
		case .purchase: context.purchase(id: id)?.syncState = state
		case .product: context.product(id: id)?.syncState = state
		}
	}
}
