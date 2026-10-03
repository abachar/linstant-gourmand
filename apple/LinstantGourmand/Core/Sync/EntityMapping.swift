import Foundation

// DTO <-> local model conversions.

extension Sale {
	convenience init(dto: SaleDTO) {
		self.init(id: dto.id, clientName: dto.clientName, deliveryDatetime: dto.deliveryDatetime, amount: 0, deposit: 0,
		          depositPaymentMethod: "", remaining: 0, remainingPaymentMethod: "")
		apply(dto)
	}

	func apply(_ dto: SaleDTO) {
		version = dto.version
		clientName = dto.clientName
		deliveryDatetime = dto.deliveryDatetime
		deliveryAddress = dto.deliveryAddress
		notes = dto.description
		amount = dto.amount.value
		deposit = dto.deposit.value
		depositPaymentMethod = PaymentMethod.normalize(dto.depositPaymentMethod)
		remaining = dto.remaining.value
		remainingPaymentMethod = PaymentMethod.normalize(dto.remainingPaymentMethod)
		items = dto.items
		createdAt = dto.createdAt
		updatedAt = dto.updatedAt
		syncState = .synced
		isPendingDeletion = false
	}

	func makeInput(baseVersion: Int?) -> SaleInput {
		SaleInput(
			baseVersion: baseVersion,
			clientName: clientName,
			deliveryDatetime: deliveryDatetime,
			deliveryAddress: deliveryAddress,
			description: notes,
			amount: Amount(amount),
			deposit: Amount(deposit),
			depositPaymentMethod: depositPaymentMethod,
			remaining: Amount(remaining),
			remainingPaymentMethod: remainingPaymentMethod,
			items: items
		)
	}

	/// The local state in wire form, to compare with a server snapshot.
	var asDTO: SaleDTO {
		SaleDTO(id: id, version: version ?? 0, clientName: clientName, deliveryDatetime: deliveryDatetime,
		        deliveryAddress: deliveryAddress, description: notes, amount: Amount(amount), deposit: Amount(deposit),
		        depositPaymentMethod: depositPaymentMethod, remaining: Amount(remaining),
		        remainingPaymentMethod: remainingPaymentMethod, items: items, createdAt: createdAt, updatedAt: updatedAt,
		        deletedAt: nil)
	}

	/// A copy under a new id, to recreate a sale the server deleted.
	func duplicate() -> Sale {
		Sale(clientName: clientName, deliveryDatetime: deliveryDatetime, deliveryAddress: deliveryAddress, notes: notes,
		     amount: amount, deposit: deposit, depositPaymentMethod: depositPaymentMethod, remaining: remaining,
		     remainingPaymentMethod: remainingPaymentMethod, items: items)
	}
}

extension Purchase {
	convenience init(dto: PurchaseDTO) {
		self.init(id: dto.id, date: dto.date, amount: 0)
		apply(dto)
	}

	func apply(_ dto: PurchaseDTO) {
		version = dto.version
		date = dto.date
		amount = dto.amount.value
		notes = dto.description
		isImported = dto.isImported
		createdAt = dto.createdAt
		updatedAt = dto.updatedAt
		syncState = .synced
		isPendingDeletion = false
	}

	func makeInput(baseVersion: Int?) -> PurchaseInput {
		PurchaseInput(baseVersion: baseVersion, date: date, amount: Amount(amount), description: notes)
	}

	var asDTO: PurchaseDTO {
		PurchaseDTO(id: id, version: version ?? 0, date: date, amount: Amount(amount), description: notes,
		            isImported: isImported, createdAt: createdAt, updatedAt: updatedAt, deletedAt: nil)
	}

	func duplicate() -> Purchase {
		Purchase(date: date, amount: amount, notes: notes)
	}
}

extension Product {
	convenience init(dto: ProductDTO) {
		self.init(id: dto.id, productName: dto.productName, quantity: dto.quantity)
		apply(dto)
	}

	func apply(_ dto: ProductDTO) {
		version = dto.version
		productName = dto.productName
		quantity = dto.quantity
		expirationDate = dto.expirationDate
		updatedAt = dto.updatedAt
		syncState = .synced
		isPendingDeletion = false
	}

	func makeInput(baseVersion: Int?) -> ProductInput {
		ProductInput(baseVersion: baseVersion, productName: productName, quantity: quantity, expirationDate: expirationDate)
	}

	var asDTO: ProductDTO {
		ProductDTO(id: id, version: version ?? 0, productName: productName, quantity: quantity,
		           expirationDate: expirationDate, updatedAt: updatedAt, deletedAt: nil)
	}

	func duplicate() -> Product {
		Product(productName: productName, quantity: quantity, expirationDate: expirationDate)
	}
}

/// The version and deletion state of any server snapshot, whatever its kind.
nonisolated struct SnapshotHeader: Decodable, Sendable {
	var version: Int
	var deletedAt: Date?

	static func decode(_ data: Data?) -> SnapshotHeader? {
		guard let data else { return nil }
		return try? JSONCoding.makeDecoder().decode(SnapshotHeader.self, from: data)
	}
}
