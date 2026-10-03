import Foundation

// Form state and the business rules duplicated from the server (docs/api.md): the server stays the
// judge, these only spare a round trip to find out.

/// Default split of a sale total: the balance is 70 % rounded up to the ten (capped at the total so the
/// deposit never goes negative), the deposit the rest.
nonisolated enum PaymentRule {
	static func split(total: Decimal) -> (deposit: Decimal, remaining: Decimal) {
		var tens = total * Decimal(string: "0.7")! / 10
		var roundedTens = Decimal()
		NSDecimalRound(&roundedTens, &tens, 0, .up)
		let remaining = min(total, roundedTens * 10)
		return (total - remaining, remaining)
	}
}

struct SaleLineDraft: Identifiable, Hashable {
	var id = UUID()
	var description = ""
	var unitPrice = ""
	var quantity = 1

	var isBlank: Bool {
		description.trimmingCharacters(in: .whitespaces).isEmpty && unitPrice.trimmingCharacters(in: .whitespaces).isEmpty
	}

	var unitAmount: Decimal? { Amount(string: unitPrice)?.value }

	var total: Decimal { (unitAmount ?? 0) * Decimal(quantity) }
}

struct SaleDraft: Hashable {
	var clientName = ""
	var deliveryDatetime = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
	var deliveryAddress = ""
	var notes = ""
	var lines: [SaleLineDraft] = [SaleLineDraft()]
	/// Only editable when the sale has no lines (sales recorded before lines existed).
	var amount = ""
	var deposit = ""
	var depositPaymentMethod = PaymentMethod.bank.rawValue
	var remainingPaymentMethod = PaymentMethod.bank.rawValue

	init() {}

	init(sale: Sale) {
		clientName = sale.clientName
		deliveryDatetime = sale.deliveryDatetime
		deliveryAddress = sale.deliveryAddress ?? ""
		notes = sale.notes ?? ""
		lines = sale.items.map {
			SaleLineDraft(description: $0.description, unitPrice: $0.unitPrice.string, quantity: $0.quantity)
		}
		if lines.isEmpty { lines = [SaleLineDraft()] }
		amount = Amount(sale.amount).string
		deposit = Amount(sale.deposit).string
		depositPaymentMethod = PaymentMethod.normalize(sale.depositPaymentMethod)
		remainingPaymentMethod = PaymentMethod.normalize(sale.remainingPaymentMethod)
	}

	var filledLines: [SaleLineDraft] { lines.filter { !$0.isBlank } }

	var hasLines: Bool { !filledLines.isEmpty }

	var totalAmount: Decimal {
		hasLines ? filledLines.reduce(0) { $0 + $1.total } : (Amount(string: amount)?.value ?? 0)
	}

	var depositAmount: Decimal { Amount(string: deposit)?.value ?? 0 }

	var remainingAmount: Decimal { totalAmount - depositAmount }

	/// Lines changed: propose the default split again, like the web form.
	mutating func applyDefaultSplit() {
		let split = PaymentRule.split(total: totalAmount)
		amount = Amount(totalAmount).string
		deposit = Amount(split.deposit).string
	}

	var errors: [String] {
		var errors: [String] = []
		if clientName.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Le nom du client est obligatoire.") }
		for (index, line) in filledLines.enumerated() {
			if line.description.trimmingCharacters(in: .whitespaces).isEmpty {
				errors.append("Article \(index + 1) : description obligatoire.")
			}
			if line.unitAmount == nil || line.unitAmount! < 0 { errors.append("Article \(index + 1) : prix invalide.") }
			if line.quantity < 1 { errors.append("Article \(index + 1) : quantité minimale 1.") }
		}
		if !hasLines, Amount(string: amount) == nil { errors.append("Montant invalide.") }
		if Amount(string: deposit) == nil { errors.append("Acompte invalide.") }
		if totalAmount < 0 { errors.append("Le montant doit être positif.") }
		if depositAmount < 0 || depositAmount > totalAmount { errors.append("L'acompte doit être compris entre 0 et le total.") }
		return errors
	}

	var isValid: Bool { errors.isEmpty }

	func apply(to sale: Sale) {
		let total = Amount(totalAmount).rounded
		let depositValue = Amount(depositAmount).rounded
		sale.clientName = clientName.trimmingCharacters(in: .whitespaces)
		sale.deliveryDatetime = deliveryDatetime
		sale.deliveryAddress = deliveryAddress.trimmedOrNil
		sale.notes = notes.trimmedOrNil
		sale.items = filledLines.map {
			SaleItemDTO(description: $0.description.trimmingCharacters(in: .whitespaces),
			            unitPrice: Amount($0.unitAmount ?? 0).rounded, quantity: $0.quantity)
		}
		sale.amount = total.value
		sale.deposit = depositValue.value
		sale.remaining = (total - depositValue).value
		sale.depositPaymentMethod = depositPaymentMethod
		sale.remainingPaymentMethod = remainingPaymentMethod
		sale.updatedAt = .now
	}
}

struct PurchaseDraft: Hashable {
	var date = Date.now
	var amount = ""
	var notes = ""

	init() {}

	init(purchase: Purchase) {
		date = purchase.date
		amount = Amount(purchase.amount).string
		notes = purchase.notes ?? ""
	}

	var errors: [String] {
		Amount(string: amount) == nil ? ["Montant invalide."] : []
	}

	var isValid: Bool { errors.isEmpty }

	func apply(to purchase: Purchase) {
		purchase.date = date
		purchase.amount = Amount(string: amount)?.rounded.value ?? 0
		purchase.notes = notes.trimmedOrNil
		purchase.updatedAt = .now
	}
}

struct ProductDraft: Hashable {
	var productName = ""
	var quantity = 0
	var hasExpirationDate = false
	var expirationDate = Date.now

	init() {}

	init(product: Product) {
		productName = product.productName
		quantity = product.quantity
		hasExpirationDate = product.expirationDate != nil
		expirationDate = product.expirationDate ?? .now
	}

	var errors: [String] {
		var errors: [String] = []
		if productName.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Le nom du produit est obligatoire.") }
		if quantity < 0 { errors.append("La quantité doit être positive.") }
		return errors
	}

	var isValid: Bool { errors.isEmpty }

	func apply(to product: Product) {
		product.productName = productName.trimmingCharacters(in: .whitespaces)
		product.quantity = quantity
		product.expirationDate = hasExpirationDate ? Calendar.current.startOfDay(for: expirationDate) : nil
		product.updatedAt = .now
	}
}

extension String {
	var trimmedOrNil: String? {
		let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? nil : trimmed
	}
}
