import Foundation
import Testing
@testable import LinstantGourmand

struct PaymentRuleTests {
	@Test(arguments: [
		("100", "30", "70"),
		("125", "35", "90"),
		("120.50", "30.50", "90"),
		("5", "0", "5"),
		("0", "0", "0"),
	])
	func split(total: String, deposit: String, remaining: String) {
		let result = PaymentRule.split(total: Decimal(string: total)!)
		#expect(result.deposit == Decimal(string: deposit)!)
		#expect(result.remaining == Decimal(string: remaining)!)
	}

	@Test func draftComputesTotalFromLines() {
		var draft = SaleDraft()
		draft.clientName = "Martin"
		draft.lines = [
			SaleLineDraft(description: "Mini-quiches", unitPrice: "1.50", quantity: 80),
			SaleLineDraft(description: "Wraps", unitPrice: "2,25", quantity: 4),
			SaleLineDraft(),
		]
		draft.applyDefaultSplit()
		#expect(draft.totalAmount == 129)
		#expect(draft.deposit == "29.00")
		#expect(draft.remainingAmount == 100)
		#expect(draft.isValid)
	}

	@Test func draftRejectsInvalidInput() {
		var draft = SaleDraft()
		draft.lines = [SaleLineDraft(description: "", unitPrice: "abc", quantity: 1)]
		draft.deposit = "10"
		#expect(draft.errors.contains("Le nom du client est obligatoire."))
		#expect(draft.errors.contains("Article 1 : description obligatoire."))
		#expect(draft.errors.contains("Article 1 : prix invalide."))
		#expect(draft.errors.contains("L'acompte doit être compris entre 0 et le total."))
	}
}

struct AmountTests {
	@Test func decodesStringsAndNumbers() throws {
		let decoded = try JSONCoding.makeDecoder().decode([Amount].self, from: Data(#"["125.50", 12.5, "-3"]"#.utf8))
		#expect(decoded.map(\.value) == [Decimal(string: "125.50")!, Decimal(string: "12.5")!, -3])
	}

	@Test func encodesTwoDecimalStrings() throws {
		let data = try JSONCoding.makeEncoder().encode([Amount(Decimal(string: "12.5")!), Amount(Decimal(string: "0.005")!)])
		#expect(String(data: data, encoding: .utf8) == #"["12.50","0.01"]"#)
	}

	@Test func parsesFrenchDecimalSeparator() {
		#expect(Amount(string: "2,25")?.value == Decimal(string: "2.25")!)
		#expect(Amount(string: "") == nil)
	}
}

struct DTOTests {
	/// The Sale example of docs/api.md.
	@Test func decodesSale() throws {
		let json = """
		{
		  "id": "3f5b1c2e-8d4a-4e6b-9c1d-2a3b4c5d6e7f", "version": 3,
		  "clientName": "Dupont", "deliveryDatetime": "2026-10-03T10:00:00.000Z", "deliveryAddress": null, "description": null,
		  "amount": "120.00", "deposit": "40.00", "depositPaymentMethod": "Bank",
		  "remaining": "80.00", "remainingPaymentMethod": "Cash",
		  "items": [ { "description": "Mini-quiches", "unitPrice": "1.50", "quantity": 80 } ],
		  "createdAt": "2026-10-01T08:00:00Z", "updatedAt": "2026-10-02T08:00:00.123Z", "deletedAt": null
		}
		"""
		let sale = try JSONCoding.makeDecoder().decode(SaleDTO.self, from: Data(json.utf8))
		#expect(sale.version == 3)
		#expect(sale.amount.value == 120)
		#expect(sale.items.first?.quantity == 80)
		#expect(sale.deliveryDatetime == Date(timeIntervalSince1970: 1_791_021_600))
		#expect(sale.deletedAt == nil)
	}

	@Test func decodesSyncPage() throws {
		let json = """
		{ "cursor": 1842, "hasMore": false, "sales": [], "purchases": [
		  { "id": "3f5b1c2e-8d4a-4e6b-9c1d-2a3b4c5d6e70", "version": 1, "date": "2026-10-03T00:00:00.000Z", "amount": "-35.20",
		    "description": null, "isImported": true, "createdAt": "2026-10-03T00:00:00.000Z",
		    "updatedAt": "2026-10-03T00:00:00.000Z", "deletedAt": "2026-10-04T00:00:00.000Z" } ],
		  "products": [ { "id": "3f5b1c2e-8d4a-4e6b-9c1d-2a3b4c5d6e71", "version": 2, "productName": "Beurre", "quantity": 4,
		    "expirationDate": null, "updatedAt": "2026-10-03T00:00:00.000Z", "deletedAt": null } ] }
		"""
		let page = try JSONCoding.makeDecoder().decode(SyncResponse.self, from: Data(json.utf8))
		#expect(page.cursor == 1842)
		#expect(page.purchases.first?.amount.value == Decimal(string: "-35.20")!)
		#expect(page.purchases.first?.deletedAt != nil)
		#expect(page.products.first?.productName == "Beurre")
	}

	@Test func normalizesLegacyPaymentMethods() {
		var dto = makeSaleDTO(version: 1)
		dto.depositPaymentMethod = "Bancaire"
		dto.remainingPaymentMethod = "Espèces"
		let sale = Sale(dto: dto)
		#expect(sale.depositPaymentMethod == "Bank")
		#expect(sale.remainingPaymentMethod == "Cash")
		#expect(PaymentMethod.label(for: "Inconnu") == "Inconnu")
	}

	@Test func encodesExplicitNulls() throws {
		let input = ProductInput(baseVersion: nil, productName: "Beurre", quantity: 2, expirationDate: nil)
		let json = try #require(String(data: JSONCoding.makeEncoder().encode(input), encoding: .utf8))
		#expect(json == #"{"baseVersion":null,"expirationDate":null,"productName":"Beurre","quantity":2}"#)
	}

	@Test func parsesConflictError() throws {
		let body = Data(#"{"error":{"code":"conflict","message":"Modifié"},"current":{"version":4,"deletedAt":null}}"#.utf8)
		guard case let .conflict(current) = APIError.from(status: 409, body: body) else {
			Issue.record("expected a conflict")
			return
		}
		#expect(SnapshotHeader.decode(current)?.version == 4)

		let missing = Data(#"{"error":{"code":"conflict","message":"Modifié"},"current":null}"#.utf8)
		#expect(APIError.from(status: 409, body: missing) == .conflict(current: nil))
	}

	@Test func parsesValidationError() {
		let body = Data(#"{"error":{"code":"validation","message":"Invalide","fields":{"items.0.quantity":"Minimum 1"}}}"#.utf8)
		#expect(APIError.from(status: 422, body: body) == .validation(message: "Invalide", fields: ["items.0.quantity": "Minimum 1"]))
		#expect(APIError.from(status: 401, body: Data(#"{"error":{"code":"invalid_refresh_token"}}"#.utf8)) == .invalidRefreshToken)
		#expect(APIError.from(status: 503, body: Data()).isTransient)
	}
}
