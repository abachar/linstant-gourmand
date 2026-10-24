import Foundation

/// Which sales can share one invoice: same client, delivered the same month, each with items (same rule as the server).
enum InvoiceGrouping {
	static func candidates(for sale: Sale, in sales: [Sale], calendar: Calendar = .current) -> [Sale] {
		sales
			.filter { other in
				!other.isPendingDeletion
					&& !other.items.isEmpty
					&& other.clientName == sale.clientName
					&& calendar.isDate(other.deliveryDatetime, equalTo: sale.deliveryDatetime, toGranularity: .month)
			}
			.sorted { ($0.deliveryDatetime, $0.createdAt) < ($1.deliveryDatetime, $1.createdAt) }
	}
}
