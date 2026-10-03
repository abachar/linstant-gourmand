import Foundation
import SwiftData

/// Records local changes as pending mutations, coalesced to one per entity.
final class Outbox {
	enum DeleteOutcome: Equatable {
		/// Never reached the server: remove the entity right away, nothing to push.
		case removeLocally
		/// Hide the entity and push the deletion.
		case pushDeletion
	}

	private let context: ModelContext

	init(context: ModelContext) {
		self.context = context
	}

	func mutation(for entityId: UUID) -> PendingMutation? {
		try? context.fetch(FetchDescriptor<PendingMutation>(predicate: #Predicate { $0.entityId == entityId })).first
	}

	/// Mutations to push, oldest first.
	func pending() -> [PendingMutation] {
		let pending = MutationStatus.pending.rawValue
		let descriptor = FetchDescriptor<PendingMutation>(
			predicate: #Predicate { $0.statusRaw == pending },
			sortBy: [SortDescriptor(\.createdAt)]
		)
		return (try? context.fetch(descriptor)) ?? []
	}

	/// Conflicts and rejections waiting for the user.
	func issues() -> [PendingMutation] {
		let pending = MutationStatus.pending.rawValue
		let descriptor = FetchDescriptor<PendingMutation>(
			predicate: #Predicate { $0.statusRaw != pending },
			sortBy: [SortDescriptor(\.createdAt)]
		)
		return (try? context.fetch(descriptor)) ?? []
	}

	/// A creation or an edit. Coalesced into the existing mutation, which keeps its original `baseVersion`.
	@discardableResult
	func recordUpsert(kind: EntityKind, entityId: UUID, currentVersion: Int?) -> PendingMutation {
		if let existing = mutation(for: entityId) {
			existing.op = .upsert
			existing.revision += 1
			if existing.status == .rejected {
				existing.status = .pending
				existing.lastError = nil
				existing.fieldErrors = [:]
			}
			return existing
		}
		let mutation = PendingMutation(kind: kind, entityId: entityId, op: .upsert, baseVersion: currentVersion)
		context.insert(mutation)
		return mutation
	}

	func recordDelete(kind: EntityKind, entityId: UUID, currentVersion: Int?) -> DeleteOutcome {
		if let existing = mutation(for: entityId) {
			if existing.baseVersion == nil, currentVersion == nil {
				context.delete(existing)
				return .removeLocally
			}
			existing.op = .delete
			existing.revision += 1
			if existing.status == .rejected { existing.status = .pending }
			return .pushDeletion
		}
		guard let currentVersion else { return .removeLocally }
		context.insert(PendingMutation(kind: kind, entityId: entityId, op: .delete, baseVersion: currentVersion))
		return .pushDeletion
	}
}
