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
				VStack(spacing: Spacing.l) {
					VStack(alignment: .leading, spacing: Spacing.m) {
						monthHeader
						MonthCalendar(month: month, sales: sales.filter { !$0.isPendingDeletion }) { day, daySales in
							selectedDay = DaySelection(date: day, saleIds: daySales.map(\.id))
						}
					}
					.card()
					statistics
				}
				.padding()
			}
			.scrollScreenBackground()
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

	private var isCurrentMonth: Bool {
		Calendar.current.isDate(month, equalTo: .now, toGranularity: .month)
	}

	private var monthHeader: some View {
		VStack(alignment: .leading, spacing: Spacing.s) {
			SectionTitle(title: "Planning des commandes")
			HStack(spacing: Spacing.s) {
				Text(Formats.month(month))
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(Theme.accent)
				Spacer()
				if !isCurrentMonth {
					Button("Aujourd'hui") {
						month = Calendar.current.dateInterval(of: .month, for: .now)!.start
					}
					.buttonStyle(.bordered)
					.controlSize(.small)
				}
				monthButton("chevron.left", label: "Mois précédent", offset: -1)
				monthButton("chevron.right", label: "Mois suivant", offset: 1)
			}
		}
	}

	private func monthButton(_ systemImage: String, label: String, offset: Int) -> some View {
		Button {
			month = Calendar.current.date(byAdding: .month, value: offset, to: month)!
		} label: {
			Image(systemName: systemImage)
				.font(.footnote.weight(.semibold))
				.frame(width: 32, height: 32)
				.background(Theme.surfaceMuted, in: .rect(cornerRadius: 8, style: .continuous))
				.frame(width: 44, height: 44)
				.contentShape(.rect)
		}
		.buttonStyle(.plain)
		.padding(.horizontal, -6)
		.accessibilityLabel(label)
	}

	@ViewBuilder private var statistics: some View {
		VStack(alignment: .leading, spacing: Spacing.m) {
			SectionTitle(title: "Finances", badge: "Ce mois")
			if let stats {
				let value = stats.value
				LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.m), GridItem(.flexible(), spacing: Spacing.m)], spacing: Spacing.m) {
					StatCard(title: "Chiffre d'affaires", month: value.currentMonthSales, year: value.currentYearSales)
					StatCard(title: "Dépenses", month: value.currentMonthExpenses, year: value.currentYearExpenses)
					StatCard(
						title: "Bénéfice net",
						month: value.currentMonthSales - value.currentMonthExpenses,
						year: value.currentYearSales - value.currentYearExpenses,
						negativeIsDanger: true
					)
					StatCard(title: "Taxe", month: value.currentMonthTax, year: value.currentYearTax)
				}
				Text("Calculé par le serveur, à jour \(Formats.relative(stats.fetchedAt)).")
					.font(.caption)
					.foregroundStyle(Theme.textMuted)
			} else if services.isOnline {
				LoadingCards(count: 4)
			} else {
				InfoBanner(kind: .offline, text: "Statistiques indisponibles hors ligne pour ce mois.")
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
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

private struct StatCard: View {
	let title: String
	let month: Decimal
	let year: Decimal
	var negativeIsDanger = false

	var body: some View {
		VStack(alignment: .leading, spacing: Spacing.xs) {
			Text(title).overline()
			Text(month.euros)
				.font(.statValue)
				.monospacedDigit()
				.minimumScaleFactor(0.6)
				.lineLimit(1)
				.foregroundStyle(negativeIsDanger && month < 0 ? Theme.danger : Color.primary)
			Text("Année : \(year.euros)")
				.font(.caption)
				.monospacedDigit()
				.foregroundStyle(Theme.textMuted)
				.minimumScaleFactor(0.8)
				.lineLimit(1)
		}
		.card()
		.accessibilityElement(children: .combine)
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

		LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
			ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
				Text(symbol).overline()
			}
			ForEach(Array(days.enumerated()), id: \.offset) { _, day in
				if let day {
					let daySales = byDay[day] ?? []
					let isToday = calendar.isDateInToday(day)
					Button {
						if !daySales.isEmpty { onSelect(day, daySales) }
					} label: {
						VStack(spacing: 2) {
							Text("\(calendar.component(.day, from: day))")
								.font(.callout.weight(isToday || !daySales.isEmpty ? (isToday ? .bold : .semibold) : .regular))
								.foregroundStyle(isToday ? Color.white : (daySales.isEmpty ? Theme.textMuted : Color.primary))
								.frame(minWidth: 36, minHeight: 36)
								.background { if isToday { Circle().fill(Theme.accent) } }
							HStack(spacing: 2) {
								ForEach(0..<min(daySales.count, 3), id: \.self) { _ in
									Circle().fill(isToday ? Color.white : Theme.accent).frame(width: 5, height: 5)
								}
							}
							.frame(height: 5)
						}
						.frame(maxWidth: .infinity, minHeight: 44)
						.contentShape(.rect)
					}
					.buttonStyle(.plain)
					.accessibilityLabel("\(Formats.date(day)), \(daySales.count) vente(s)")
					.accessibilityAddTraits(daySales.isEmpty ? [] : .isButton)
				} else {
					Color.clear.frame(height: 44)
				}
			}
		}
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
			List {
				Section {
					ForEach(sales) { sale in
						NavigationLink(value: sale.id) { SaleRow(sale: sale) }
							.navigationLinkIndicatorVisibility(.hidden)
							.cardRow()
					}
				} header: {
					Text("\(sales.count) vente(s) · \(sales.reduce(Decimal(0)) { $0 + $1.amount }.euros)")
						.font(.subheadline.weight(.semibold))
						.foregroundStyle(Theme.textMuted)
						.textCase(nil)
				}
			}
			.listStyle(.insetGrouped)
			.listRowSpacing(12)
			.screenBackground()
			.navigationTitle(Formats.date(selection.date))
			.navigationBarTitleDisplayMode(.inline)
			.navigationDestination(for: UUID.self) { SaleDetailView(saleId: $0) }
		}
		.presentationDetents([.medium, .large])
	}
}
