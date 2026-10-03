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
				FilterChips(values: SaleFilter.allCases, selection: $filter) { $0.label }
					.listRowBackground(Color.clear)
					.listRowInsets(EdgeInsets())
					.listRowSeparator(.hidden)

				if visibleSales.isEmpty {
					EmptyState(
						systemImage: "bag",
						title: "Aucune vente",
						message: "Aucune vente pour cette période.",
						actionTitle: "Créer une vente"
					) { isCreating = true }
						.listRowBackground(Color.clear)
						.listRowSeparator(.hidden)
				}
				ForEach(visibleSales) { sale in
					NavigationLink(value: sale.id) {
						SaleRow(sale: sale)
					}
					.navigationLinkIndicatorVisibility(.hidden)
					.cardRow()
					.swipeActions {
						Button("Supprimer", role: .destructive) { services.store.delete(sale) }
					}
				}
			}
			.listStyle(.insetGrouped)
			.listRowSpacing(12)
			.screenBackground()
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
					.buttonStyle(.glassProminent)
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
		VStack(alignment: .leading, spacing: Spacing.s) {
			HStack {
				Label(Formats.dateTime(sale.deliveryDatetime), systemImage: "clock")
					.font(.footnote)
					.foregroundStyle(Theme.textMuted)
				Spacer()
				SyncBadge(state: sale.syncState)
			}
			HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
				Text(sale.clientName)
					.font(.cardTitle)
					.lineLimit(2)
				Spacer(minLength: Spacing.s)
				Text(sale.amount.euros)
					.font(.amountCard)
					.monospacedDigit()
			}
			if let address = sale.deliveryAddress {
				Label(address, systemImage: "mappin.and.ellipse")
					.font(.subheadline)
					.foregroundStyle(Theme.textMuted)
					.lineLimit(1)
			}
			if let notes = sale.notes {
				Text(notes)
					.font(.subheadline.weight(.medium))
					.lineLimit(2)
			}
			PaymentTiles(
				deposit: sale.deposit,
				depositMethod: sale.depositPaymentMethod,
				remaining: sale.remaining,
				remainingMethod: sale.remainingPaymentMethod,
				total: sale.amount
			)
		}
		.accessibilityElement(children: .combine)
	}
}
