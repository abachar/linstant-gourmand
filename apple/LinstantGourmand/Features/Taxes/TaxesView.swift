import SwiftData
import SwiftUI

/// Tax report computed by the server; the last answer per year is cached for offline reading.
struct TaxesView: View {
	@Environment(AppServices.self) private var services
	@Environment(\.modelContext) private var context
	@State private var year = Calendar.current.component(.year, from: .now)
	@State private var report: (value: TaxesDTO, fetchedAt: Date)?

	private var years: [Int] {
		let current = Calendar.current.component(.year, from: .now)
		return Set((report?.value.availableYears ?? []) + [current, year]).sorted(by: >)
	}

	var body: some View {
		NavigationStack {
			List {
				FilterChips(values: years, selection: $year) { String($0) }
					.listRowBackground(Color.clear)
					.listRowInsets(EdgeInsets())
					.listRowSeparator(.hidden)

				if let report {
					if report.value.monthlyItems.isEmpty {
						EmptyState(systemImage: "chart.pie", title: "Aucune vente cette année")
							.listRowBackground(Color.clear)
							.listRowSeparator(.hidden)
					} else {
						VStack(alignment: .leading, spacing: Spacing.xs) {
							Text("Total \(String(year))").overline()
							Text(report.value.monthlyItems.reduce(Decimal(0)) { $0 + $1.totalAmount }.euros)
								.font(.amountHero)
								.monospacedDigit()
								.minimumScaleFactor(0.6)
								.lineLimit(1)
							Text("TVA : \(report.value.monthlyItems.reduce(Decimal(0)) { $0 + $1.taxAmount }.euros)")
								.font(.subheadline.weight(.semibold))
								.monospacedDigit()
								.foregroundStyle(Theme.accent)
						}
						.frame(maxWidth: .infinity, alignment: .leading)
						.accessibilityElement(children: .combine)
						.cardRow()
					}
					ForEach(report.value.monthlyItems) { item in
						VStack(alignment: .leading, spacing: Spacing.m) {
							HStack(alignment: .firstTextBaseline) {
								Text(item.monthLabel.capitalized(with: Formats.locale)).font(.headline.bold())
								Spacer()
								Text(item.totalAmount.euros)
									.font(.amountCard)
									.monospacedDigit()
							}
							HStack(spacing: Spacing.s) {
								AmountTile(label: "Bancaire", amount: item.bankTotalAmount, style: .info)
								AmountTile(label: "Espèces", amount: item.cashTotalAmount, style: .success)
								AmountTile(label: "TVA 12,3 %", amount: item.taxAmount, style: .accent)
							}
							.fixedSize(horizontal: false, vertical: true)
						}
						.accessibilityElement(children: .contain)
						.cardRow()
					}
					Section {
						EmptyView()
					} footer: {
						Text("Calculé par le serveur, à jour \(Formats.relative(report.fetchedAt)).")
					}
				} else if services.isOnline {
					LoadingCards(count: 4)
						.listRowBackground(Color.clear)
						.listRowSeparator(.hidden)
				} else {
					InfoBanner(kind: .offline, text: "Rapport indisponible hors ligne pour cette année.")
						.listRowBackground(Color.clear)
						.listRowInsets(EdgeInsets())
				}
			}
			.listStyle(.insetGrouped)
			.listRowSpacing(12)
			.screenBackground()
			.navigationTitle("Taxes")
			.refreshable { await load() }
			.task(id: year) {
				report = context.cachedReport(TaxesDTO.self, key: "taxes-\(year)")
				await load()
			}
		}
	}

	private func load() async {
		guard services.isOnline else { return }
		let requested = year
		if let value = try? await services.api.taxes(year: requested) {
			context.storeReport(value, key: "taxes-\(requested)")
			if requested == year { report = (value, .now) }
		}
	}
}
