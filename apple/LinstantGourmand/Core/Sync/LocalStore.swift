import Foundation
import SwiftData

/// Every local edit goes through here: update the entity, record it in the outbox, save, sync soon.
final class LocalStore {
	private let context: ModelContext
	private let engine: SyncEngine

	init(context: ModelContext, engine: SyncEngine) {
		self.context = context
		self.engine = engine
	}

	@discardableResult
	func save(_ draft: SaleDraft, editing sale: Sale?) -> Sale {
		let target = sale ?? Sale(clientName: "", deliveryDatetime: draft.deliveryDatetime, amount: 0, deposit: 0,
		                          depositPaymentMethod: draft.depositPaymentMethod, remaining: 0,
		                          remainingPaymentMethod: draft.remainingPaymentMethod)
		if sale == nil { context.insert(target) }
		draft.apply(to: target)
		recordEdit(kind: .sale, id: target.id, version: target.version) { target.syncState = $0 }
		return target
	}

	@discardableResult
	func save(_ draft: PurchaseDraft, editing purchase: Purchase?) -> Purchase {
		let target = purchase ?? Purchase(date: draft.date, amount: 0)
		if purchase == nil { context.insert(target) }
		draft.apply(to: target)
		recordEdit(kind: .purchase, id: target.id, version: target.version) { target.syncState = $0 }
		return target
	}

	@discardableResult
	func save(_ draft: ProductDraft, editing product: Product?) -> Product {
		let target = product ?? Product(productName: "", quantity: 0)
		if product == nil { context.insert(target) }
		draft.apply(to: target)
		recordEdit(kind: .product, id: target.id, version: target.version) { target.syncState = $0 }
		return target
	}

	func delete(_ sale: Sale) {
		recordDeletion(kind: .sale, id: sale.id, version: sale.version, model: sale) {
			sale.isPendingDeletion = true
			sale.syncState = .pending
		}
	}

	func delete(_ purchase: Purchase) {
		recordDeletion(kind: .purchase, id: purchase.id, version: purchase.version, model: purchase) {
			purchase.isPendingDeletion = true
			purchase.syncState = .pending
		}
	}

	func delete(_ product: Product) {
		recordDeletion(kind: .product, id: product.id, version: product.version, model: product) {
			product.isPendingDeletion = true
			product.syncState = .pending
		}
	}

	/// Saving an entity in conflict or rejected is how the user corrects it ("Corriger").
	private func recordEdit(kind: EntityKind, id: UUID, version: Int?, setState: (SyncState) -> Void) {
		if let existing = engine.outbox.mutation(for: id), existing.status == .conflict {
			existing.revision += 1
			engine.keepMine(existing)
			return
		}
		engine.outbox.recordUpsert(kind: kind, entityId: id, currentVersion: version)
		setState(.pending)
		commit()
	}

	private func recordDeletion(kind: EntityKind, id: UUID, version: Int?, model: any PersistentModel, markPending: () -> Void) {
		switch engine.outbox.recordDelete(kind: kind, entityId: id, currentVersion: version) {
		case .removeLocally: context.delete(model)
		case .pushDeletion: markPending()
		}
		commit()
	}

	private func commit() {
		try? context.save()
		engine.refreshCounts()
		engine.scheduleSync()
	}
}
