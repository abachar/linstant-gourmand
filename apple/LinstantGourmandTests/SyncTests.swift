import Foundation
import SwiftData
import Testing
@testable import LinstantGourmand

struct OutboxTests {
	@Test func coalescesEditsKeepingTheOriginalBaseVersion() throws {
		let h = try Harness()
		let sale = h.syncedSale(version: 3)

		h.store.save(.sample(client: "Martin"), editing: sale)
		h.store.save(.sample(client: "Martin bis"), editing: sale)

		let mutations = try h.context.fetch(FetchDescriptor<PendingMutation>())
		#expect(mutations.count == 1)
		#expect(mutations.first?.baseVersion == 3)
		#expect(mutations.first?.revision == 1)
		#expect(sale.clientName == "Martin bis")
		#expect(sale.syncState == .pending)
	}

	@Test func deletingANeverPushedCreationDropsEverything() throws {
		let h = try Harness()
		let sale = h.store.save(.sample(), editing: nil)
		#expect(h.engine.outbox.pending().count == 1)

		h.store.delete(sale)

		#expect(try h.context.fetch(FetchDescriptor<PendingMutation>()).isEmpty)
		#expect(try h.context.fetch(FetchDescriptor<Sale>()).isEmpty)
	}

	@Test func deletingASyncedEntityQueuesTheDeletion() throws {
		let h = try Harness()
		let sale = h.syncedSale(version: 2)
		h.store.save(.sample(), editing: sale)

		h.store.delete(sale)

		let mutation = try #require(h.engine.outbox.mutation(for: sale.id))
		#expect(mutation.op == .delete)
		#expect(mutation.baseVersion == 2)
		#expect(sale.isPendingDeletion)
	}
}

struct SyncEngineTests {
	@Test func pushesACreationAndAppliesTheServerAnswer() async throws {
		let h = try Harness()
		let sale = h.store.save(.sample(client: "Martin"), editing: nil)
		var sentBaseVersion: Int?? = .none
		h.api.putSaleHandler = { id, input in
			sentBaseVersion = .some(input.baseVersion)
			return makeSaleDTO(id: id, version: 1, clientName: input.clientName)
		}

		try await h.engine.push()

		#expect(sentBaseVersion == .some(nil))
		#expect(sale.version == 1)
		#expect(sale.syncState == .synced)
		#expect(h.engine.outbox.pending().isEmpty)
	}

	@Test func conflictParksTheMutationAndTheOthersGoOn() async throws {
		let h = try Harness()
		let sale = h.syncedSale(version: 3)
		h.store.save(.sample(client: "iPhone"), editing: sale)
		let product = h.store.save(ProductDraft(product: Product(productName: "Beurre", quantity: 2)), editing: nil)

		let server = makeSaleDTO(id: sale.id, version: 4, clientName: "Web")
		h.api.putSaleHandler = { _, _ in throw APIError.conflict(current: encodeJSON(server)) }
		h.api.putProductHandler = { id, input in makeProductDTO(id: id, version: 1, name: input.productName) }

		try await h.engine.push()

		let mutation = try #require(h.engine.outbox.mutation(for: sale.id))
		#expect(mutation.status == .conflict)
		#expect(SnapshotHeader.decode(mutation.serverSnapshot)?.version == 4)
		#expect(sale.syncState == .conflict)
		#expect(sale.clientName == "iPhone")
		#expect(product.version == 1)
		#expect(h.engine.outbox.mutation(for: product.id) == nil)
	}

	@Test func validationErrorRejectsTheMutation() async throws {
		let h = try Harness()
		let sale = h.store.save(.sample(), editing: nil)
		h.api.putSaleHandler = { _, _ in
			throw APIError.validation(message: "Invalide", fields: ["amount": "Le total ne correspond pas aux articles"])
		}

		try await h.engine.push()

		let mutation = try #require(h.engine.outbox.mutation(for: sale.id))
		#expect(mutation.status == .rejected)
		#expect(mutation.fieldErrors["amount"] == "Le total ne correspond pas aux articles")
		#expect(sale.syncState == .rejected)

		// Correcting it puts it back in the queue.
		h.store.save(.sample(total: "90"), editing: sale)
		#expect(mutation.status == .pending)
	}

	@Test func networkErrorStopsThePushAndKeepsTheRest() async throws {
		let h = try Harness()
		_ = h.store.save(.sample(client: "A"), editing: nil)
		let second = h.store.save(.sample(client: "B"), editing: nil)
		let third = h.store.save(.sample(client: "C"), editing: nil)
		h.api.putSaleHandler = { id, input in
			if input.clientName == "B" { throw APIError.network("offline") }
			return makeSaleDTO(id: id, version: 1, clientName: input.clientName)
		}

		await #expect(throws: APIError.network("offline")) {
			try await h.engine.push()
		}

		#expect(h.api.calls == ["putSale A", "putSale B"])
		#expect(h.engine.outbox.pending().map(\.entityId) == [second.id, third.id])
	}

	@Test func editDuringAnInFlightPushIsKept() async throws {
		let h = try Harness()
		let sale = h.syncedSale(version: 2)
		h.store.save(.sample(client: "Premier"), editing: sale)
		h.api.putSaleHandler = { id, _ in
			// The user saves again while the request is in flight.
			h.store.save(.sample(client: "Second"), editing: sale)
			return makeSaleDTO(id: id, version: 3, clientName: "Premier")
		}

		try await h.engine.push()

		let mutation = try #require(h.engine.outbox.mutation(for: sale.id))
		#expect(mutation.baseVersion == 3)
		#expect(mutation.status == .pending)
		#expect(sale.clientName == "Second")
		#expect(sale.version == 3)
	}

	@Test func pullAppliesChangesAndDeletions() async throws {
		let h = try Harness()
		let kept = h.syncedSale(version: 1, clientName: "Avant")
		let removed = h.syncedSale(version: 1)
		let created = makeSaleDTO(version: 1, clientName: "Nouveau")
		h.api.syncPages = [
			SyncResponse(cursor: 10, hasMore: true,
			             sales: [makeSaleDTO(id: kept.id, version: 2, clientName: "Après"), created],
			             purchases: [], products: []),
			SyncResponse(cursor: 12, hasMore: false,
			             sales: [makeSaleDTO(id: removed.id, version: 2, deletedAt: .now)],
			             purchases: [], products: []),
		]

		try await h.engine.pull()

		#expect(h.api.syncCursors == [0, 10])
		#expect(h.context.syncMeta().cursor == 12)
		#expect(kept.clientName == "Après")
		#expect(h.context.sale(id: removed.id) == nil)
		#expect(h.context.sale(id: created.id)?.clientName == "Nouveau")
	}

	@Test func pullNeverOverwritesAPendingEdit() async throws {
		let h = try Harness()
		let sale = h.syncedSale(version: 2)
		h.store.save(.sample(client: "iPhone"), editing: sale)
		h.api.syncPages = [
			SyncResponse(cursor: 5, hasMore: false, sales: [makeSaleDTO(id: sale.id, version: 3, clientName: "Web")],
			             purchases: [], products: []),
		]

		try await h.engine.pull()

		let mutation = try #require(h.engine.outbox.mutation(for: sale.id))
		#expect(sale.clientName == "iPhone")
		#expect(mutation.status == .conflict)
		#expect(SnapshotHeader.decode(mutation.serverSnapshot)?.version == 3)
	}

	@Test func pullOfALostCreationResponseIsNotAConflict() async throws {
		let h = try Harness()
		let sale = h.store.save(.sample(client: "iPhone"), editing: nil)
		h.api.syncPages = [
			SyncResponse(cursor: 5, hasMore: false, sales: [makeSaleDTO(id: sale.id, version: 1, clientName: "iPhone")],
			             purchases: [], products: []),
		]

		try await h.engine.pull()

		#expect(h.engine.outbox.mutation(for: sale.id)?.status == .pending)
	}

	@Test func keepMineReplaysOnTopOfTheServerVersion() async throws {
		let h = try Harness()
		let sale = h.syncedSale(version: 3)
		h.store.save(.sample(client: "iPhone"), editing: sale)
		h.api.putSaleHandler = { _, _ in throw APIError.conflict(current: encodeJSON(makeSaleDTO(id: sale.id, version: 5))) }
		try await h.engine.push()
		let mutation = try #require(h.engine.outbox.mutation(for: sale.id))

		h.engine.keepMine(mutation)

		#expect(mutation.status == .pending)
		#expect(mutation.baseVersion == 5)
		#expect(sale.syncState == .pending)
	}

	@Test func takeServerAppliesTheSnapshot() async throws {
		let h = try Harness()
		let sale = h.syncedSale(version: 3)
		h.store.save(.sample(client: "iPhone"), editing: sale)
		h.api.putSaleHandler = { _, _ in
			throw APIError.conflict(current: encodeJSON(makeSaleDTO(id: sale.id, version: 4, clientName: "Web")))
		}
		try await h.engine.push()

		h.engine.takeServer(try #require(h.engine.outbox.mutation(for: sale.id)))

		#expect(h.engine.outbox.mutation(for: sale.id) == nil)
		#expect(sale.clientName == "Web")
		#expect(sale.version == 4)
		#expect(sale.syncState == .synced)
	}

	@Test func keepMineRecreatesASaleDeletedOnTheServer() async throws {
		let h = try Harness()
		let sale = h.syncedSale(version: 3)
		let oldId = sale.id
		h.store.save(.sample(client: "iPhone"), editing: sale)
		h.api.putSaleHandler = { _, _ in
			throw APIError.conflict(current: encodeJSON(makeSaleDTO(id: oldId, version: 4, deletedAt: .now)))
		}
		try await h.engine.push()

		h.engine.keepMine(try #require(h.engine.outbox.mutation(for: oldId)))

		let sales = try h.context.fetch(FetchDescriptor<Sale>())
		#expect(sales.count == 1)
		#expect(sales.first?.id != oldId)
		#expect(sales.first?.clientName == "iPhone")
		#expect(h.engine.outbox.mutation(for: sales.first!.id)?.baseVersion == nil)
	}

	@Test func deletionIsPushedThenTheEntityRemoved() async throws {
		let h = try Harness()
		let sale = h.syncedSale(version: 2)
		h.store.delete(sale)
		h.api.deleteSaleHandler = { id, base in makeSaleDTO(id: id, version: base + 1, deletedAt: .now) }

		try await h.engine.push()

		#expect(h.api.calls == ["deleteSale 2"])
		#expect(try h.context.fetch(FetchDescriptor<Sale>()).isEmpty)
		#expect(h.engine.outbox.pending().isEmpty)
	}
}
