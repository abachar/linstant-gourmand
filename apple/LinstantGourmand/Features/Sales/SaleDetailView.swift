import QuickLook
import SwiftData
import SwiftUI

struct SaleDetailView: View {
	let saleId: UUID

	@Environment(AppServices.self) private var services
	@Environment(\.dismiss) private var dismiss
	@Query private var matches: [Sale]
	@State private var isEditing = false
	@State private var confirmsDeletion = false
	@State private var previewURL: URL?
	@State private var error: String?

	init(saleId: UUID) {
		self.saleId = saleId
		_matches = Query(filter: #Predicate<Sale> { $0.id == saleId })
	}

	var body: some View {
		if let sale = matches.first, !sale.isPendingDeletion {
			content(sale)
		} else {
			ContentUnavailableView("Vente supprimée", systemImage: "bag")
		}
	}

	private func content(_ sale: Sale) -> some View {
		List {
			if sale.syncState == .conflict || sale.syncState == .rejected {
				Section {
					if let mutation = services.sync.outbox.mutation(for: sale.id) {
						NavigationLink {
							ConflictDetailView(mutation: mutation)
						} label: {
							InfoBanner(
								kind: .warning,
								text: sale.syncState == .conflict ? "Modifiée ailleurs : à résoudre" : "Refusée par le serveur : à corriger"
							)
						}
						.listRowBackground(Color.clear)
						.listRowInsets(EdgeInsets())
					}
				}
			}

			Section {
				VStack(alignment: .leading, spacing: Spacing.s) {
					Text(sale.clientName).font(.title2.bold())
					Label(Formats.dateTime(sale.deliveryDatetime), systemImage: "clock")
						.font(.subheadline)
						.foregroundStyle(Theme.textMuted)
					Text(sale.amount.euros)
						.font(.amountHero)
						.monospacedDigit()
					if let address = sale.deliveryAddress {
						Label(address, systemImage: "mappin.and.ellipse")
							.font(.subheadline)
							.foregroundStyle(Theme.textMuted)
					}
					Text("Créée le \(Formats.dateTime(sale.createdAt))")
						.font(.caption)
						.foregroundStyle(Theme.textMuted)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.accessibilityElement(children: .combine)
			}

			if !sale.items.isEmpty {
				Section {
					ForEach(Array(sale.items.enumerated()), id: \.offset) { _, item in
						HStack(alignment: .firstTextBaseline) {
							VStack(alignment: .leading, spacing: 2) {
								Text(item.description).font(.subheadline.weight(.medium))
								Text("\(item.unitPrice.formatted) × \(item.quantity)")
									.font(.caption)
									.monospacedDigit()
									.foregroundStyle(Theme.textMuted)
							}
							Spacer()
							Text((item.unitPrice.value * Decimal(item.quantity)).euros)
								.font(.subheadline.bold())
								.monospacedDigit()
						}
						.accessibilityElement(children: .combine)
					}
				} header: {
					Text("Articles").overline()
				}
			}

			Section {
				PaymentTiles(
					deposit: sale.deposit,
					depositMethod: sale.depositPaymentMethod,
					remaining: sale.remaining,
					remainingMethod: sale.remainingPaymentMethod,
					total: sale.amount,
					large: true
				)
				.listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
			} header: {
				Text("Paiement").overline()
			}

			if let notes = sale.notes {
				Section {
					Text(notes)
				} header: {
					Text("Notes").overline()
				}
			}

			if !sale.items.isEmpty {
				Section {
					SalePDFButton(saleId: sale.id, clientName: sale.clientName, type: .quote, previewURL: $previewURL, error: $error)
					SalePDFButton(saleId: sale.id, clientName: sale.clientName, type: .invoice, previewURL: $previewURL, error: $error)
				} header: {
					Text("Documents").overline()
				} footer: {
					if !services.isOnline {
						OfflineNotice(text: "Les devis et factures sont générés par le serveur : disponibles en ligne uniquement.")
					} else if sale.version == nil || sale.syncState != .synced {
						Text("Le document reflète la dernière version reçue par le serveur.")
					}
				}
			}

			Section {
				Button(role: .destructive) {
					confirmsDeletion = true
				} label: {
					Label("Supprimer la vente", systemImage: "trash")
				}
			}
		}
		.listStyle(.insetGrouped)
		.screenBackground()
		.navigationTitle(sale.clientName)
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			Button("Modifier") { isEditing = true }
		}
		.sheet(isPresented: $isEditing) {
			SaleFormView(sale: sale)
		}
		.quickLookPreview($previewURL)
		.confirmationDialog("Supprimer cette vente ?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
			Button("Supprimer", role: .destructive) {
				services.store.delete(sale)
				dismiss()
			}
		}
		.alert("Erreur", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
			Button("OK") {}
		} message: {
			Text(error ?? "")
		}
	}
}
