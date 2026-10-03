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
							Label(
								sale.syncState == .conflict ? "Modifiée ailleurs : à résoudre" : "Refusée par le serveur : à corriger",
								systemImage: "exclamationmark.triangle.fill"
							)
							.foregroundStyle(.orange)
						}
					}
				}
			}

			Section("Client") {
				ValueRow(label: "Nom", value: sale.clientName)
				if let address = sale.deliveryAddress { ValueRow(label: "Adresse", value: address) }
				ValueRow(label: "Livraison", value: Formats.dateTime(sale.deliveryDatetime))
			}

			if !sale.items.isEmpty {
				Section("Articles") {
					ForEach(Array(sale.items.enumerated()), id: \.offset) { _, item in
						HStack(alignment: .firstTextBaseline) {
							VStack(alignment: .leading) {
								Text(item.description)
								Text("\(item.quantity) × \(item.unitPrice.formatted)")
									.font(.caption)
									.foregroundStyle(.secondary)
							}
							Spacer()
							Text((item.unitPrice.value * Decimal(item.quantity)).euros)
						}
					}
				}
			}

			Section("Paiement") {
				ValueRow(label: "Total", value: sale.amount.euros)
				ValueRow(label: "Acompte", value: "\(sale.deposit.euros) · \(PaymentMethod.label(for: sale.depositPaymentMethod))")
				ValueRow(label: "Solde", value: "\(sale.remaining.euros) · \(PaymentMethod.label(for: sale.remainingPaymentMethod))")
			}

			if let notes = sale.notes {
				Section("Notes") { Text(notes) }
			}

			if !sale.items.isEmpty {
				Section {
					SalePDFButton(saleId: sale.id, clientName: sale.clientName, type: .quote, previewURL: $previewURL, error: $error)
					SalePDFButton(saleId: sale.id, clientName: sale.clientName, type: .invoice, previewURL: $previewURL, error: $error)
				} header: {
					Text("Documents")
				} footer: {
					if !services.isOnline {
						OfflineNotice(text: "Les devis et factures sont générés par le serveur : disponibles en ligne uniquement.")
					} else if sale.version == nil || sale.syncState != .synced {
						Text("Le document reflète la dernière version reçue par le serveur.")
					}
				}
			}

			Section {
				Button("Supprimer la vente", role: .destructive) { confirmsDeletion = true }
			}
		}
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
