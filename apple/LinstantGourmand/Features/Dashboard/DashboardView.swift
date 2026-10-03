import SwiftData
import SwiftUI

/// Month statistics come from the server (cached for offline use), the calendar from the local sales.
struct DashboardView: View {
	@Environment(AppServices.self) private var services
	@Environment(\.modelContext) private var context
	@Query(sort: \Sale.deliveryDatetime) private var sales: [Sale]
	@State private var month = Calendar.current.dateInterval(of: .month, for: .now)!.start
	@State private var stats: (value: DashboardDTO, fetchedAt: Date)?
	@State private var selectedDay: DaySelection?
	@State private var confirmsLogout = false

	private var monthKey: String {
		let components = Calendar.current.dateComponents([.year, .month], from: month)
		return String(format: "%04d-%02d", components.year!, components.month!)
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(spacing: 16) {
					monthHeader
					MonthCalendar(month: month, sales: sales.filter { !$0.isPendingDeletion }) { day, daySales in
						selectedDay = DaySelection(date: day, saleIds: daySales.map(\.id))
					}
					statistics
				}
				.padding()
			}
			.navigationTitle("Tableau de bord")
			.refreshable {
				await services.sync.sync()
				await loadStats()
			}
			.task(id: monthKey) {
				stats = context.cachedReport(DashboardDTO.self, key: "dashboard-\(monthKey)")
				await loadStats()
			}
			.toolbar {
				Menu {
					NavigationLink {
						ClientsView()
					} label: {
						Label("Clients", systemImage: "person.2")
					}
					Button {
						Task { await services.sync.sync() }
					} label: {
						Label("Synchroniser", systemImage: "arrow.clockwise")
					}
					Button(role: .destructive) {
						confirmsLogout = true
					} label: {
						Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right")
					}
				} label: {
					Label("Plus", systemImage: "ellipsis")
				}
			}
			.sheet(item: $selectedDay) { DaySalesSheet(selection: $0) }
			.confirmationDialog(
				"Se déconnecter ?",
				isPresented: $confirmsLogout,
				titleVisibility: .visible
			) {
				Button("Se déconnecter", role: .destructive) {
					Task { await services.auth.logout() }
				}
			} message: {
				Text("Les données restent sur l'iPhone. Les modifications non envoyées le seront à la prochaine connexion.")
			}
		}
	}

	private var monthHeader: some View {
		HStack {
			Button {
				month = Calendar.current.date(byAdding: .month, value: -1, to: month)!
			} label: {
				Image(systemName: "chevron.left")
			}
			Spacer()
			Text(Formats.month(month)).font(.title3.bold())
			Spacer()
			Button {
				month = Calendar.current.date(byAdding: .month, value: 1, to: month)!
			} label: {
				Image(systemName: "chevron.right")
			}
		}
		.buttonStyle(.glass)
	}

	@ViewBuilder private var statistics: some View {
		if let stats {
			let value = stats.value
			VStack(alignment: .leading, spacing: 12) {
				Text("Ce mois-ci").font(.headline)
				StatGrid(items: [
					("Ventes", value.currentMonthSales),
					("Dépenses", value.currentMonthExpenses),
					("Taxes", value.currentMonthTax),
				])
				Text("Cette année").font(.headline)
				StatGrid(items: [
					("Ventes", value.currentYearSales),
					("Dépenses", value.currentYearExpenses),
					("Taxes", value.currentYearTax),
				])
				Text("Calculé par le serveur, à jour \(Formats.relative(stats.fetchedAt)).")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		} else if services.isOnline {
			ProgressView()
		} else {
			OfflineNotice(text: "Statistiques indisponibles hors ligne pour ce mois.")
		}
	}

	private func loadStats() async {
		guard services.isOnline else { return }
		let key = monthKey
		if let value = try? await services.api.dashboard(month: key) {
			context.storeReport(value, key: "dashboard-\(key)")
			if key == monthKey { stats = (value, .now) }
		}
	}
}

private struct StatGrid: View {
	let items: [(String, Decimal)]

	var body: some View {
		HStack(spacing: 8) {
			ForEach(items, id: \.0) { label, value in
				VStack(alignment: .leading, spacing: 4) {
					Text(label).font(.caption).foregroundStyle(.secondary)
					Text(value.euros).font(.subheadline.bold()).minimumScaleFactor(0.7).lineLimit(1)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(12)
				.glassEffect(in: .rect(cornerRadius: 16))
			}
		}
	}
}

struct DaySelection: Identifiable {
	let date: Date
	let saleIds: [UUID]
	var id: Date { date }
}

private struct MonthCalendar: View {
	let month: Date
	let sales: [Sale]
	let onSelect: (Date, [Sale]) -> Void

	private var calendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.locale = Formats.locale
		calendar.firstWeekday = 2
		return calendar
	}

	/// The month's days, padded with nils so the first day sits under its weekday (Monday first).
	private var days: [Date?] {
		let range = calendar.range(of: .day, in: .month, for: month)!
		let firstWeekday = calendar.component(.weekday, from: month)
		let padding = (firstWeekday - calendar.firstWeekday + 7) % 7
		let dates = range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
		return Array(repeating: nil, count: padding) + dates
	}

	private var salesByDay: [Date: [Sale]] {
		Dictionary(grouping: sales.filter { calendar.isDate($0.deliveryDatetime, equalTo: month, toGranularity: .month) }) {
			calendar.startOfDay(for: $0.deliveryDatetime)
		}
	}

	var body: some View {
		let byDay = salesByDay
		let symbols = calendar.veryShortStandaloneWeekdaySymbols
		let ordered = Array(symbols[(calendar.firstWeekday - 1)...] + symbols[..<(calendar.firstWeekday - 1)])

		LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
			ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
				Text(symbol).font(.caption.bold()).foregroundStyle(.secondary)
			}
			ForEach(Array(days.enumerated()), id: \.offset) { _, day in
				if let day {
					let daySales = byDay[day] ?? []
					Button {
						if !daySales.isEmpty { onSelect(day, daySales) }
					} label: {
						VStack(spacing: 2) {
							Text("\(calendar.component(.day, from: day))")
								.font(.callout.weight(calendar.isDateInToday(day) ? .bold : .regular))
								.foregroundStyle(calendar.isDateInToday(day) ? Color.accentColor : .primary)
							Circle()
								.fill(daySales.isEmpty ? Color.clear : Color.accentColor)
								.frame(width: 6, height: 6)
						}
						.frame(maxWidth: .infinity, minHeight: 40)
					}
					.buttonStyle(.plain)
					.accessibilityLabel("\(Formats.date(day)), \(daySales.count) vente(s)")
				} else {
					Color.clear.frame(height: 40)
				}
			}
		}
		.padding(12)
		.glassEffect(in: .rect(cornerRadius: 20))
	}
}

private struct DaySalesSheet: View {
	let selection: DaySelection
	@Query private var sales: [Sale]

	init(selection: DaySelection) {
		self.selection = selection
		let ids = selection.saleIds
		_sales = Query(filter: #Predicate<Sale> { ids.contains($0.id) }, sort: \Sale.deliveryDatetime)
	}

	var body: some View {
		NavigationStack {
			List(sales) { sale in
				NavigationLink(value: sale.id) { SaleRow(sale: sale) }
			}
			.navigationTitle(Formats.date(selection.date))
			.navigationBarTitleDisplayMode(.inline)
			.navigationDestination(for: UUID.self) { SaleDetailView(saleId: $0) }
		}
		.presentationDetents([.medium, .large])
	}
}
