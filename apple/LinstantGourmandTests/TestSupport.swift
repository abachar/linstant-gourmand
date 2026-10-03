import Foundation
import SwiftData
@testable import LinstantGourmand

/// Scripted API: each test sets the handlers it needs, unexpected calls fail like a network error.
final class FakeAPI: APIClientProtocol {
	var calls: [String] = []
	var putSaleHandler: (UUID, SaleInput) throws -> SaleDTO = { _, _ in throw APIError.network("unexpected") }
	var deleteSaleHandler: (UUID, Int) throws -> SaleDTO = { _, _ in throw APIError.network("unexpected") }
	var putProductHandler: (UUID, ProductInput) throws -> ProductDTO = { _, _ in throw APIError.network("unexpected") }
	var syncPages: [SyncResponse] = []
	var syncCursors: [Int] = []

	func sync(cursor: Int, limit: Int) async throws -> SyncResponse {
		calls.append("sync \(cursor)")
		syncCursors.append(cursor)
		guard !syncPages.isEmpty else { return SyncResponse(cursor: cursor, hasMore: false, sales: [], purchases: [], products: []) }
		return syncPages.removeFirst()
	}

	func putSale(id: UUID, input: SaleInput) async throws -> SaleDTO {
		calls.append("putSale \(input.clientName)")
		return try putSaleHandler(id, input)
	}

	func deleteSale(id: UUID, baseVersion: Int) async throws -> SaleDTO {
		calls.append("deleteSale \(baseVersion)")
		return try deleteSaleHandler(id, baseVersion)
	}

	func putPurchase(id: UUID, input: PurchaseInput) async throws -> PurchaseDTO { throw APIError.network("unexpected") }
	func deletePurchase(id: UUID, baseVersion: Int) async throws -> PurchaseDTO { throw APIError.network("unexpected") }

	func putProduct(id: UUID, input: ProductInput) async throws -> ProductDTO {
		calls.append("putProduct \(input.productName)")
		return try putProductHandler(id, input)
	}

	func deleteProduct(id: UUID, baseVersion: Int) async throws -> ProductDTO { throw APIError.network("unexpected") }
	func dashboard(month: String) async throws -> DashboardDTO { throw APIError.network("unexpected") }
	func taxes(year: Int) async throws -> TaxesDTO { throw APIError.network("unexpected") }
	func clients() async throws -> [ClientDTO] { throw APIError.network("unexpected") }
	func updateClient(_ input: ClientUpdateInput) async throws { throw APIError.network("unexpected") }
	func salePDF(id: UUID, type: PrintType) async throws -> Data { throw APIError.network("unexpected") }
	func importPurchases(csv: Data) async throws -> Int { throw APIError.network("unexpected") }
}

/// In-memory store + engine + local store, with automatic syncs disabled so tests drive push/pull.
struct Harness {
	let container: ModelContainer
	let api = FakeAPI()
	let engine: SyncEngine
	let store: LocalStore

	var context: ModelContext { container.mainContext }

	init() throws {
		container = try Persistence.makeContainer(inMemory: true)
		engine = SyncEngine(context: container.mainContext, api: api)
		engine.canSync = { false }
		store = LocalStore(context: container.mainContext, engine: engine)
	}

	/// A sale already known by the server at `version`.
	@discardableResult
	func syncedSale(version: Int, clientName: String = "Dupont") -> Sale {
		let sale = Sale(dto: makeSaleDTO(version: version, clientName: clientName))
		context.insert(sale)
		try? context.save()
		return sale
	}
}

func makeSaleDTO(
	id: UUID = UUID(),
	version: Int,
	clientName: String = "Dupont",
	amount: String = "120.00",
	deletedAt: Date? = nil
) -> SaleDTO {
	let total = Amount(string: amount)!
	let split = PaymentRule.split(total: total.value)
	return SaleDTO(
		id: id, version: version, clientName: clientName,
		deliveryDatetime: Date(timeIntervalSince1970: 1_790_000_000),
		deliveryAddress: "1 rue de Rivoli", description: nil,
		amount: total, deposit: Amount(split.deposit), depositPaymentMethod: "Bank",
		remaining: Amount(split.remaining), remainingPaymentMethod: "Cash",
		items: [], createdAt: .now, updatedAt: .now, deletedAt: deletedAt
	)
}

func makeProductDTO(id: UUID = UUID(), version: Int, name: String = "Beurre", quantity: Int = 4) -> ProductDTO {
	ProductDTO(id: id, version: version, productName: name, quantity: quantity, expirationDate: nil, updatedAt: .now, deletedAt: nil)
}

func encodeJSON<T: Encodable>(_ value: T) -> Data {
	try! JSONCoding.makeEncoder().encode(value)
}

extension SaleDraft {
	static func sample(client: String = "Martin", total: String = "100") -> SaleDraft {
		var draft = SaleDraft()
		draft.clientName = client
		draft.lines = [SaleLineDraft(description: "Mini-quiches", unitPrice: total, quantity: 1)]
		draft.applyDefaultSplit()
		return draft
	}
}
