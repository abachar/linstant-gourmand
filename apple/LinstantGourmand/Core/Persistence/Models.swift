import Foundation
import SwiftData

/// Local copies of the server entities, plus the sync bookkeeping (docs/ios-plan.md, Phase 5).
/// `version` is the last server version this copy is based on, `nil` for a creation never pushed.

nonisolated enum SyncState: String, Codable, Sendable {
	case synced
	case pending
	case conflict
	case rejected
}

nonisolated enum EntityKind: String, Codable, Sendable {
	case sale
	case purchase
	case product

	var label: String {
		switch self {
		case .sale: "Vente"
		case .purchase: "Achat"
		case .product: "Produit"
		}
	}
}

@Model
final class Sale {
	@Attribute(.unique) var id: UUID
	var version: Int?
	var clientName: String
	var deliveryDatetime: Date
	var deliveryAddress: String?
	var notes: String?
	var amount: Decimal
	var deposit: Decimal
	var depositPaymentMethod: String
	var remaining: Decimal
	var remainingPaymentMethod: String
	/// JSON of `[SaleItemDTO]`: the lines are always replaced as a whole, like on the server.
	var itemsData: Data
	var createdAt: Date
	var updatedAt: Date
	var syncStateRaw: String
	/// Deleted locally, waiting for the server to confirm: hidden from the lists.
	var isPendingDeletion: Bool

	init(
		id: UUID = UUID(),
		version: Int? = nil,
		clientName: String,
		deliveryDatetime: Date,
		deliveryAddress: String? = nil,
		notes: String? = nil,
		amount: Decimal,
		deposit: Decimal,
		depositPaymentMethod: String,
		remaining: Decimal,
		remainingPaymentMethod: String,
		items: [SaleItemDTO] = [],
		createdAt: Date = .now,
		updatedAt: Date = .now,
		syncState: SyncState = .pending
	) {
		self.id = id
		self.version = version
		self.clientName = clientName
		self.deliveryDatetime = deliveryDatetime
		self.deliveryAddress = deliveryAddress
		self.notes = notes
		self.amount = amount
		self.deposit = deposit
		self.depositPaymentMethod = depositPaymentMethod
		self.remaining = remaining
		self.remainingPaymentMethod = remainingPaymentMethod
		self.itemsData = (try? JSONEncoder().encode(items)) ?? Data("[]".utf8)
		self.createdAt = createdAt
		self.updatedAt = updatedAt
		self.syncStateRaw = syncState.rawValue
		self.isPendingDeletion = false
	}

	var items: [SaleItemDTO] {
		get { (try? JSONDecoder().decode([SaleItemDTO].self, from: itemsData)) ?? [] }
		set { itemsData = (try? JSONEncoder().encode(newValue)) ?? Data("[]".utf8) }
	}

	var syncState: SyncState {
		get { SyncState(rawValue: syncStateRaw) ?? .synced }
		set { syncStateRaw = newValue.rawValue }
	}
}

@Model
final class Purchase {
	@Attribute(.unique) var id: UUID
	var version: Int?
	var date: Date
	var amount: Decimal
	var notes: String?
	var isImported: Bool
	var createdAt: Date
	var updatedAt: Date
	var syncStateRaw: String
	var isPendingDeletion: Bool

	init(
		id: UUID = UUID(),
		version: Int? = nil,
		date: Date,
		amount: Decimal,
		notes: String? = nil,
		isImported: Bool = false,
		createdAt: Date = .now,
		updatedAt: Date = .now,
		syncState: SyncState = .pending
	) {
		self.id = id
		self.version = version
		self.date = date
		self.amount = amount
		self.notes = notes
		self.isImported = isImported
		self.createdAt = createdAt
		self.updatedAt = updatedAt
		self.syncStateRaw = syncState.rawValue
		self.isPendingDeletion = false
	}

	var syncState: SyncState {
		get { SyncState(rawValue: syncStateRaw) ?? .synced }
		set { syncStateRaw = newValue.rawValue }
	}
}

@Model
final class Product {
	@Attribute(.unique) var id: UUID
	var version: Int?
	var productName: String
	var quantity: Int
	var expirationDate: Date?
	var updatedAt: Date
	var syncStateRaw: String
	var isPendingDeletion: Bool

	init(
		id: UUID = UUID(),
		version: Int? = nil,
		productName: String,
		quantity: Int,
		expirationDate: Date? = nil,
		updatedAt: Date = .now,
		syncState: SyncState = .pending
	) {
		self.id = id
		self.version = version
		self.productName = productName
		self.quantity = quantity
		self.expirationDate = expirationDate
		self.updatedAt = updatedAt
		self.syncStateRaw = syncState.rawValue
		self.isPendingDeletion = false
	}

	var syncState: SyncState {
		get { SyncState(rawValue: syncStateRaw) ?? .synced }
		set { syncStateRaw = newValue.rawValue }
	}
}

nonisolated enum MutationOp: String, Codable, Sendable {
	case upsert
	case delete
}

nonisolated enum MutationStatus: String, Codable, Sendable {
	/// Waiting to be pushed.
	case pending
	/// The server answered 409: the user must choose.
	case conflict
	/// The server refused the data (422/403): the user must correct.
	case rejected
}

/// The outbox: at most one mutation per entity (later edits are coalesced into it). The payload is not
/// stored: it is rebuilt from the local entity when pushed.
@Model
final class PendingMutation {
	@Attribute(.unique) var id: UUID
	var kindRaw: String
	var entityId: UUID
	var opRaw: String
	/// Server version the change is based on, `nil` for a creation.
	var baseVersion: Int?
	var statusRaw: String
	/// Incremented on every local change, to detect edits made while a push was in flight.
	var revision: Int
	var createdAt: Date
	var attempts: Int
	var lastError: String?
	/// JSON of the server entity returned with a 409 (or seen during a pull).
	var serverSnapshot: Data?
	/// 409 with `current: null`: the server has no such entity.
	var serverMissing: Bool
	/// JSON `[String: String]` of the 422 field errors.
	var fieldErrorsData: Data?

	init(kind: EntityKind, entityId: UUID, op: MutationOp, baseVersion: Int?) {
		self.id = UUID()
		self.kindRaw = kind.rawValue
		self.entityId = entityId
		self.opRaw = op.rawValue
		self.baseVersion = baseVersion
		self.statusRaw = MutationStatus.pending.rawValue
		self.revision = 0
		self.createdAt = .now
		self.attempts = 0
		self.serverMissing = false
	}

	var kind: EntityKind {
		get { EntityKind(rawValue: kindRaw) ?? .sale }
		set { kindRaw = newValue.rawValue }
	}

	var op: MutationOp {
		get { MutationOp(rawValue: opRaw) ?? .upsert }
		set { opRaw = newValue.rawValue }
	}

	var status: MutationStatus {
		get { MutationStatus(rawValue: statusRaw) ?? .pending }
		set { statusRaw = newValue.rawValue }
	}

	var fieldErrors: [String: String] {
		get { fieldErrorsData.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:] }
		set { fieldErrorsData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue) }
	}
}

/// Singleton holding the sync cursor.
@Model
final class SyncMeta {
	var cursor: Int
	var lastSyncAt: Date?

	init(cursor: Int = 0) {
		self.cursor = cursor
	}
}

/// Last server answer of an online-only report (dashboard, taxes, clients), shown read-only offline.
@Model
final class CachedReport {
	@Attribute(.unique) var key: String
	var data: Data
	var fetchedAt: Date

	init(key: String, data: Data, fetchedAt: Date = .now) {
		self.key = key
		self.data = data
		self.fetchedAt = fetchedAt
	}
}
