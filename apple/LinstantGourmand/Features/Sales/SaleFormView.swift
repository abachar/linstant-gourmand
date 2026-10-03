import SwiftData
import SwiftUI

/// Create or edit a sale. Saving an entity in conflict or refused by the server is how it gets corrected.
struct SaleFormView: View {
	let sale: Sale?
	var onSaved: (() -> Void)?

	@Environment(AppServices.self) private var services
	@Environment(\.dismiss) private var dismiss
	@Query(sort: \Sale.clientName) private var allSales: [Sale]
	@State private var draft: SaleDraft
	@State private var showsErrors = false
	@FocusState private var clientFieldFocused: Bool

	init(sale: Sale?, onSaved: (() -> Void)? = nil) {
		self.sale = sale
		self.onSaved = onSaved
		_draft = State(initialValue: sale.map(SaleDraft.init(sale:)) ?? SaleDraft())
	}

	/// Distinct (client, address) pairs from the local sales, like the web autocomplete.
	private var suggestions: [(name: String, address: String?)] {
		let query = draft.clientName.trimmingCharacters(in: .whitespaces)
		guard clientFieldFocused, query.count >= 1 else { return [] }
		var seen = Set<String>()
		return allSales.compactMap { sale in
			guard sale.clientName.localizedCaseInsensitiveContains(query), sale.clientName != query else { return nil }
			let key = "\(sale.clientName)|\(sale.deliveryAddress ?? "")"
			guard seen.insert(key).inserted else { return nil }
			return (sale.clientName, sale.deliveryAddress)
		}
		.prefix(5)
		.map { $0 }
	}

	var body: some View {
		NavigationStack {
			Form {
				Section("Client") {
					TextField("Nom du client (obligatoire)", text: $draft.clientName)
						.focused($clientFieldFocused)
						.textContentType(.name)
					ForEach(suggestions, id: \.name) { suggestion in
						Button {
							draft.clientName = suggestion.name
							if let address = suggestion.address { draft.deliveryAddress = address }
							clientFieldFocused = false
						} label: {
							HStack(spacing: Spacing.m) {
								Image(systemName: "person").foregroundStyle(Theme.textMuted)
								VStack(alignment: .leading) {
									Text(suggestion.name)
									if let address = suggestion.address {
										Text(address).font(.caption).foregroundStyle(Theme.textMuted)
									}
								}
							}
						}
					}
					TextField("Adresse de livraison", text: $draft.deliveryAddress, axis: .vertical)
						.textContentType(.fullStreetAddress)
				}

				Section("Livraison") {
					DatePicker("Date et heure", selection: $draft.deliveryDatetime)
						.environment(\.locale, Formats.locale)
				}

				Section {
					ForEach($draft.lines) { $line in
						SaleLineEditor(line: $line)
					}
					.onDelete { offsets in
						draft.lines.remove(atOffsets: offsets)
						if draft.lines.isEmpty { draft.lines = [SaleLineDraft()] }
					}
					Button {
						draft.lines.append(SaleLineDraft())
					} label: {
						Label {
							Text("Ajouter un article")
						} icon: {
							Image(systemName: "plus.circle.fill").foregroundStyle(Theme.accent)
						}
					}
					if draft.hasLines {
						LabeledContent("Total") {
							Text(draft.totalAmount.euros)
								.font(.title3.weight(.heavy))
								.monospacedDigit()
						}
					}
				} header: {
					Text("Articles")
				}

				Section {
					if draft.hasLines {
						ValueRow(label: "Montant total", value: draft.totalAmount.euros)
					} else {
						AmountField(title: "Montant total", text: $draft.amount)
					}
					AmountField(title: "Acompte", text: $draft.deposit)
					PaymentMethodPicker(title: "Mode acompte", selection: $draft.depositPaymentMethod)
					LabeledContent("Solde") {
						Text(draft.remainingAmount.euros)
							.bold()
							.foregroundStyle(Theme.accent)
							.monospacedDigit()
					}
					PaymentMethodPicker(title: "Mode solde", selection: $draft.remainingPaymentMethod)
				} header: {
					Text("Paiement")
				} footer: {
					Text("Acompte proposé d'environ 30 % ; le solde est le total moins l'acompte.")
				}

				Section("Notes") {
					TextField("Informations complémentaires", text: $draft.notes, axis: .vertical)
				}

				if showsErrors { FormErrors(errors: draft.errors) }
			}
			.screenBackground()
			.navigationTitle(sale == nil ? "Nouvelle vente" : "Modifier la vente")
			.navigationBarTitleDisplayMode(.inline)
			.onChange(of: draft.lines) { old, new in
				// Lines changed (not just their identity): propose the default split again, like the web form.
				if old.map(\.total) != new.map(\.total) { draft.applyDefaultSplit() }
			}
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Annuler") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Enregistrer", action: save)
				}
			}
		}
	}

	private func save() {
		guard draft.isValid else {
			showsErrors = true
			return
		}
		services.store.save(draft, editing: sale)
		onSaved?()
		dismiss()
	}
}

private struct SaleLineEditor: View {
	@Binding var line: SaleLineDraft

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			TextField("Description (ex. mini-quiches)", text: $line.description)
			HStack {
				TextField("Prix unitaire", text: $line.unitPrice)
					.keyboardType(.decimalPad)
					.monospacedDigit()
				Text("€").foregroundStyle(Theme.textMuted)
				Spacer()
				Stepper("× \(line.quantity)", value: $line.quantity, in: 1...10_000)
					.fixedSize()
			}
			if !line.isBlank {
				Text(line.total.euros)
					.font(.subheadline.bold())
					.monospacedDigit()
					.frame(maxWidth: .infinity, alignment: .trailing)
			}
		}
		.padding(.vertical, 4)
	}
}

struct PaymentMethodPicker: View {
	let title: String
	@Binding var selection: String

	var body: some View {
		VStack(alignment: .leading, spacing: Spacing.s) {
			Text(title).font(.subheadline).foregroundStyle(Theme.textMuted)
			Picker(title, selection: $selection) {
				ForEach(PaymentMethod.allCases) { Text($0.label).tag($0.rawValue) }
				if PaymentMethod(rawValue: selection) == nil {
					Text(selection).tag(selection)
				}
			}
			.pickerStyle(.segmented)
			.labelsHidden()
		}
		.padding(.vertical, 2)
	}
}
