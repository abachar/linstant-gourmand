import Foundation

// Wire types of docs/api.md. Optional inputs are encoded as explicit `null`, never omitted.

nonisolated enum PaymentMethod: String, CaseIterable, Identifiable, Sendable {
	case bank = "Bank"
	case cash = "Cash"

	var id: String { rawValue }

	var label: String {
		switch self {
		case .bank: "Bancaire"
		case .cash: "Espèces"
		}
	}

	/// Legacy rows may hold the French label instead of the code: map them, keep anything else raw.
	static func normalize(_ raw: String) -> String {
		switch raw {
		case "Bancaire": PaymentMethod.bank.rawValue
		case "Espèces", "Especes": PaymentMethod.cash.rawValue
		default: raw
		}
	}

	static func label(for raw: String) -> String {
		PaymentMethod(rawValue: normalize(raw))?.label ?? raw
	}
}

nonisolated struct SaleItemDTO: Codable, Hashable, Sendable {
	var description: String
	var unitPrice: Amount
	var quantity: Int
}

nonisolated struct SaleDTO: Codable, Hashable, Sendable, Identifiable {
	var id: UUID
	var version: Int
	var clientName: String
	var deliveryDatetime: Date
	var deliveryAddress: String?
	var description: String?
	var amount: Amount
	var deposit: Amount
	var depositPaymentMethod: String
	var remaining: Amount
	var remainingPaymentMethod: String
	var items: [SaleItemDTO]
	var createdAt: Date
	var updatedAt: Date
	var deletedAt: Date?
}

nonisolated struct PurchaseDTO: Codable, Hashable, Sendable, Identifiable {
	var id: UUID
	var version: Int
	var date: Date
	var amount: Amount
	var description: String?
	var isImported: Bool
	var createdAt: Date
	var updatedAt: Date
	var deletedAt: Date?
}

nonisolated struct ProductDTO: Codable, Hashable, Sendable, Identifiable {
	var id: UUID
	var version: Int
	var productName: String
	var quantity: Int
	var expirationDate: Date?
	var updatedAt: Date
	var deletedAt: Date?
}

nonisolated struct SaleInput: Encodable, Hashable, Sendable {
	var baseVersion: Int?
	var clientName: String
	var deliveryDatetime: Date
	var deliveryAddress: String?
	var description: String?
	var amount: Amount
	var deposit: Amount
	var depositPaymentMethod: String
	var remaining: Amount
	var remainingPaymentMethod: String
	var items: [SaleItemDTO]

	private enum CodingKeys: String, CodingKey {
		case baseVersion, clientName, deliveryDatetime, deliveryAddress, description, amount, deposit
		case depositPaymentMethod, remaining, remainingPaymentMethod, items
	}

	func encode(to encoder: Encoder) throws {
		var c = encoder.container(keyedBy: CodingKeys.self)
		try c.encode(baseVersion, forKey: .baseVersion)
		try c.encode(clientName, forKey: .clientName)
		try c.encode(deliveryDatetime, forKey: .deliveryDatetime)
		try c.encode(deliveryAddress, forKey: .deliveryAddress)
		try c.encode(description, forKey: .description)
		try c.encode(amount, forKey: .amount)
		try c.encode(deposit, forKey: .deposit)
		try c.encode(depositPaymentMethod, forKey: .depositPaymentMethod)
		try c.encode(remaining, forKey: .remaining)
		try c.encode(remainingPaymentMethod, forKey: .remainingPaymentMethod)
		try c.encode(items, forKey: .items)
	}
}

nonisolated struct PurchaseInput: Encodable, Hashable, Sendable {
	var baseVersion: Int?
	var date: Date
	var amount: Amount
	var description: String?

	private enum CodingKeys: String, CodingKey { case baseVersion, date, amount, description }

	func encode(to encoder: Encoder) throws {
		var c = encoder.container(keyedBy: CodingKeys.self)
		try c.encode(baseVersion, forKey: .baseVersion)
		try c.encode(date, forKey: .date)
		try c.encode(amount, forKey: .amount)
		try c.encode(description, forKey: .description)
	}
}

nonisolated struct ProductInput: Encodable, Hashable, Sendable {
	var baseVersion: Int?
	var productName: String
	var quantity: Int
	var expirationDate: Date?

	private enum CodingKeys: String, CodingKey { case baseVersion, productName, quantity, expirationDate }

	func encode(to encoder: Encoder) throws {
		var c = encoder.container(keyedBy: CodingKeys.self)
		try c.encode(baseVersion, forKey: .baseVersion)
		try c.encode(productName, forKey: .productName)
		try c.encode(quantity, forKey: .quantity)
		try c.encode(expirationDate, forKey: .expirationDate)
	}
}

nonisolated struct SyncResponse: Codable, Sendable {
	var cursor: Int
	var hasMore: Bool
	var sales: [SaleDTO]
	var purchases: [PurchaseDTO]
	var products: [ProductDTO]
}

nonisolated struct TokenPair: Codable, Sendable {
	var accessToken: String
	var accessTokenExpiresAt: Date
	var refreshToken: String
	var refreshTokenExpiresAt: Date
}

nonisolated struct DashboardDTO: Codable, Hashable, Sendable {
	var month: String
	var currentMonthSales: Decimal
	var currentMonthExpenses: Decimal
	var currentMonthTax: Decimal
	var currentYearSales: Decimal
	var currentYearExpenses: Decimal
	var currentYearTax: Decimal
}

nonisolated struct TaxMonthDTO: Codable, Hashable, Sendable, Identifiable {
	var month: Int
	var monthLabel: String
	var totalAmount: Decimal
	var bankTotalAmount: Decimal
	var cashTotalAmount: Decimal
	var taxAmount: Decimal

	var id: Int { month }
}

nonisolated struct TaxesDTO: Codable, Hashable, Sendable {
	var selectedYear: Int
	var availableYears: [Int]
	var monthlyItems: [TaxMonthDTO]
}

nonisolated struct ClientDTO: Codable, Hashable, Sendable, Identifiable {
	var clientName: String
	var deliveryAddress: String?
	var orderCount: Int
	var totalAmount: Amount

	var id: String { "\(clientName)|\(deliveryAddress ?? "")" }
}

nonisolated struct ClientUpdateInput: Encodable, Sendable {
	var oldClientName: String
	var oldDeliveryAddress: String?
	var newClientName: String
	var newDeliveryAddress: String?

	private enum CodingKeys: String, CodingKey { case oldClientName, oldDeliveryAddress, newClientName, newDeliveryAddress }

	func encode(to encoder: Encoder) throws {
		var c = encoder.container(keyedBy: CodingKeys.self)
		try c.encode(oldClientName, forKey: .oldClientName)
		try c.encode(oldDeliveryAddress, forKey: .oldDeliveryAddress)
		try c.encode(newClientName, forKey: .newClientName)
		try c.encode(newDeliveryAddress, forKey: .newDeliveryAddress)
	}
}

nonisolated struct ImportResult: Codable, Sendable {
	var inserted: Int
}

nonisolated enum PrintType: String, Sendable {
	case quote
	case invoice

	var label: String {
		switch self {
		case .quote: "Devis"
		case .invoice: "Facture"
		}
	}
}
