import QuickLook
import SwiftData
import SwiftUI

/// Picks the sales of the month to put on one invoice (all of them by default), then opens the PDF in Quick Look.
struct GroupedInvoiceView: View {
	let sale: Sale

	@Environment(AppServices.self) private var services
	@Query(sort: \Sale.deliveryDatetime) private var allSales: [Sale]
	@State private var excluded: Set<UUID> = []
	@State private var isLoading = false
	@State private var previewURL: URL?
	@State private var error: String?

	private var candidates: [Sale] { InvoiceGrouping.candidates(for: sale, in: allSales) }
	private var chosen: [Sale] { candidates.filter { !excluded.contains($0.id) } }
	private var total: Decimal { chosen.reduce(0) { $0 + $1.amount } }

	var body: some View {
		List {
			Section {
				ForEach(candidates) { candidate in
					let checked = !excluded.contains(candidate.id)
					Button {
						if checked { excluded.insert(candidate.id) } else { excluded.remove(candidate.id) }
					} label: {
						HStack(alignment: .top, spacing: Spacing.m) {
							Image(systemName: checked ? "checkmark.circle.fill" : "circle")
								.font(.title3)
								.foregroundStyle(checked ? Theme.accent : Theme.textMuted)
							VStack(alignment: .leading, spacing: 2) {
								Text(Formats.dateTime(candidate.deliveryDatetime))
									.font(.subheadline.weight(.medium))
								if let address = candidate.deliveryAddress {
									Text(address).font(.caption).foregroundStyle(Theme.textMuted).lineLimit(1)
								}
								Text("\(candidate.items.count) article\(candidate.items.count > 1 ? "s" : "")")
									.font(.caption)
									.foregroundStyle(Theme.textMuted)
							}
							Spacer()
							Text(candidate.amount.euros)
								.font(.subheadline.bold())
								.monospacedDigit()
						}
						.opacity(checked ? 1 : 0.5)
					}
					.buttonStyle(.plain)
					.accessibilityAddTraits(checked ? .isSelected : [])
				}
			} header: {
				Text("Ventes de \(Formats.month(sale.deliveryDatetime))").overline()
			} footer: {
				Text("Décochez les ventes à exclure de la facture.")
			}

			Section {
				LabeledContent("\(chosen.count) vente\(chosen.count > 1 ? "s" : "")") {
					Text(total.euros).font(.amountCard).monospacedDigit()
				}
				Button {
					Task { await open() }
				} label: {
					if isLoading {
						ProgressView()
					} else {
						Label("Ouvrir la facture", systemImage: "doc.text")
					}
				}
				.disabled(chosen.isEmpty || !services.isOnline || isLoading)
			} footer: {
				if !services.isOnline {
					OfflineNotice(text: "La facture est générée par le serveur : disponible en ligne uniquement.")
				} else if chosen.contains(where: { $0.version == nil || $0.syncState != .synced }) {
					Text("Le document reflète la dernière version reçue par le serveur.")
				}
			}
		}
		.listStyle(.insetGrouped)
		.screenBackground()
		.navigationTitle("Facture groupée")
		.navigationBarTitleDisplayMode(.inline)
		.quickLookPreview($previewURL)
		.alert("Erreur", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
			Button("OK") {}
		} message: {
			Text(error ?? "")
		}
	}

	private func open() async {
		isLoading = true
		defer { isLoading = false }
		do {
			let data = try await services.api.salesPDF(ids: chosen.map(\.id), type: .invoice)
			let month = sale.deliveryDatetime.formatted(.iso8601.year().month())
			let name = "Facture-\(sale.clientName.replacingOccurrences(of: " ", with: "_"))-\(month).pdf"
			let url = URL.temporaryDirectory.appending(path: name)
			try data.write(to: url, options: .completeFileProtection)
			previewURL = url
		} catch {
			self.error = error.localizedDescription
		}
	}
}
