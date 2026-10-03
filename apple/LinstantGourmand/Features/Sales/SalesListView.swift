import SwiftData
import SwiftUI

enum SaleFilter: String, CaseIterable, Identifiable {
	case upcoming
	case month
	case past
	case all

	var id: String { rawValue }

	var label: String {
		switch self {
		case .upcoming: "À venir"
		case .month: "Ce mois"
		case .past: "Passées"
		case .all: "Toutes"
		}
	}

	/// Same ranges as the web list: "à venir" starts tomorrow, "passées" ends yesterday.
	func contains(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
		let today = calendar.startOfDay(for: now)
		switch self {
		case .upcoming:
			return date >= calendar.date(byAdding: .day, value: 1, to: today)!
		case .month:
			return calendar.isDate(date, equalTo: now, toGranularity: .month)
		case .past:
			return date < today
		case .all:
			return true
		}
	}
}

struct SalesListView: View {
	@Query(sort: \Sale.deliveryDatetime, order: .reverse) private var sales: [Sale]
	@AppStorage("salesFilter") private var filter = SaleFilter.upcoming
	@State private var isCreating = false
	@Environment(AppServices.self) private var services

	private var visibleSales: [Sale] {
		sales.filter { !$0.isPendingDeletion && filter.contains($0.deliveryDatetime) }
	}

	var body: some View {
		NavigationStack {
			List {
				Picker("Période", selection: $filter) {
					ForEach(SaleFilter.allCases) { Text($0.label).tag($0) }
				}
				.pickerStyle(.segmented)
				.listRowBackground(Color.clear)
				.listRowInsets(EdgeInsets())

				if visibleSales.isEmpty {
					ContentUnavailableView("Aucune vente", systemImage: "bag", description: Text("Aucune vente pour cette période."))
				}
				ForEach(visibleSales) { sale in
					NavigationLink(value: sale.id) {
						SaleRow(sale: sale)
					}
				}
			}
			.navigationTitle("Ventes")
			.navigationDestination(for: UUID.self) { id in
				SaleDetailView(saleId: id)
			}
			.refreshable { await services.sync.sync() }
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					NavigationLink {
						ClientsView()
					} label: {
						Label("Clients", systemImage: "person.2")
					}
				}
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						isCreating = true
					} label: {
						Label("Nouvelle vente", systemImage: "plus")
					}
				}
			}
			.sheet(isPresented: $isCreating) {
				SaleFormView(sale: nil)
			}
		}
	}
}

struct SaleRow: View {
	let sale: Sale

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack {
				Text(sale.clientName).font(.headline)
				SyncBadge(state: sale.syncState)
				Spacer()
				Text(sale.amount.euros).font(.headline)
			}
			Text(Formats.dateTime(sale.deliveryDatetime))
				.font(.subheadline)
				.foregroundStyle(.secondary)
			if let address = sale.deliveryAddress {
				Label(address, systemImage: "mappin.and.ellipse")
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
		}
	}
}
