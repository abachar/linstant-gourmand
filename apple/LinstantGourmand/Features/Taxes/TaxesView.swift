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
				Picker("Année", selection: $year) {
					ForEach(years, id: \.self) { Text(String($0)).tag($0) }
				}

				if let report {
					if report.value.monthlyItems.isEmpty {
						ContentUnavailableView("Aucune vente cette année", systemImage: "chart.pie")
					}
					ForEach(report.value.monthlyItems) { item in
						Section(item.monthLabel.capitalized(with: Formats.locale)) {
							ValueRow(label: "Total encaissé", value: item.totalAmount.euros)
							ValueRow(label: "Bancaire", value: item.bankTotalAmount.euros)
							ValueRow(label: "Espèces", value: item.cashTotalAmount.euros)
							ValueRow(label: "Taxes (12,3 %)", value: item.taxAmount.euros)
								.fontWeight(.semibold)
						}
					}
					Section {
						EmptyView()
					} footer: {
						Text("Calculé par le serveur, à jour \(Formats.relative(report.fetchedAt)).")
					}
				} else if services.isOnline {
					ProgressView()
				} else {
					OfflineNotice(text: "Rapport indisponible hors ligne pour cette année.")
				}
			}
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
