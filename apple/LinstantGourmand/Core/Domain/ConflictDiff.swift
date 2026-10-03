import Foundation

/// One compared field of a conflict screen.
struct FieldDiff: Identifiable, Hashable {
	let label: String
	let mine: String
	let server: String

	var id: String { label }
	var differs: Bool { mine != server }
}

/// Field-by-field comparison of the local version against the server snapshot.
enum ConflictDiff {
	static func sale(mine: SaleDTO, server: SaleDTO) -> [FieldDiff] {
		func lines(_ dto: SaleDTO) -> String {
			dto.items.isEmpty ? "—" : dto.items.map { "\($0.quantity) × \($0.description) (\($0.unitPrice.formatted))" }
				.joined(separator: "\n")
		}
		return [
			FieldDiff(label: "Client", mine: mine.clientName, server: server.clientName),
			FieldDiff(label: "Livraison", mine: Formats.dateTime(mine.deliveryDatetime), server: Formats.dateTime(server.deliveryDatetime)),
			FieldDiff(label: "Adresse", mine: mine.deliveryAddress ?? "—", server: server.deliveryAddress ?? "—"),
			FieldDiff(label: "Articles", mine: lines(mine), server: lines(server)),
			FieldDiff(label: "Total", mine: mine.amount.formatted, server: server.amount.formatted),
			FieldDiff(label: "Acompte", mine: payment(mine.deposit, mine.depositPaymentMethod),
			          server: payment(server.deposit, server.depositPaymentMethod)),
			FieldDiff(label: "Solde", mine: payment(mine.remaining, mine.remainingPaymentMethod),
			          server: payment(server.remaining, server.remainingPaymentMethod)),
			FieldDiff(label: "Notes", mine: mine.description ?? "—", server: server.description ?? "—"),
		]
	}

	static func purchase(mine: PurchaseDTO, server: PurchaseDTO) -> [FieldDiff] {
		[
			FieldDiff(label: "Date", mine: Formats.date(mine.date), server: Formats.date(server.date)),
			FieldDiff(label: "Montant", mine: mine.amount.formatted, server: server.amount.formatted),
			FieldDiff(label: "Description", mine: mine.description ?? "—", server: server.description ?? "—"),
		]
	}

	static func product(mine: ProductDTO, server: ProductDTO) -> [FieldDiff] {
		[
			FieldDiff(label: "Produit", mine: mine.productName, server: server.productName),
			FieldDiff(label: "Quantité", mine: "\(mine.quantity)", server: "\(server.quantity)"),
			FieldDiff(label: "Date limite", mine: mine.expirationDate.map(Formats.date) ?? "—",
			          server: server.expirationDate.map(Formats.date) ?? "—"),
		]
	}

	private static func payment(_ amount: Amount, _ method: String) -> String {
		"\(amount.formatted) · \(PaymentMethod.label(for: method))"
	}
}
