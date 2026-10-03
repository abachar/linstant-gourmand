import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct PurchasesListView: View {
	@Environment(AppServices.self) private var services
	@Query(sort: \Purchase.date, order: .reverse) private var purchases: [Purchase]
	@State private var year = Calendar.current.component(.year, from: .now)
	@State private var editing: Purchase?
	@State private var isCreating = false
	@State private var isImporting = false
	@State private var message: String?

	private var years: [Int] {
		let current = Calendar.current.component(.year, from: .now)
		return Set(purchases.map { Calendar.current.component(.year, from: $0.date) } + [current]).sorted(by: >)
	}

	private var visible: [Purchase] {
		purchases.filter { !$0.isPendingDeletion && Calendar.current.component(.year, from: $0.date) == year }
	}

	private var total: Decimal {
		visible.reduce(0) { $0 + $1.amount }
	}

	var body: some View {
		NavigationStack {
			List {
				Section {
					Picker("Année", selection: $year) {
						ForEach(years, id: \.self) { Text(String($0)).tag($0) }
					}
					ValueRow(label: "Total", value: total.euros)
				}

				if visible.isEmpty {
					ContentUnavailableView("Aucun achat", systemImage: "basket")
				}
				ForEach(visible) { purchase in
					Button {
						if !purchase.isImported { editing = purchase }
					} label: {
						PurchaseRow(purchase: purchase)
					}
					.tint(.primary)
					.swipeActions {
						if !purchase.isImported {
							Button("Supprimer", role: .destructive) { services.store.delete(purchase) }
						}
					}
				}
			}
			.navigationTitle("Achats")
			.refreshable { await services.sync.sync() }
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button {
						isImporting = true
					} label: {
						Label("Importer un relevé Revolut", systemImage: "square.and.arrow.down")
					}
					.disabled(!services.isOnline)
				}
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						isCreating = true
					} label: {
						Label("Nouvel achat", systemImage: "plus")
					}
				}
			}
			.sheet(isPresented: $isCreating) { PurchaseFormView(purchase: nil) }
			.sheet(item: $editing) { PurchaseFormView(purchase: $0) }
			.fileImporter(isPresented: $isImporting, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
				Task { await importCSV(result) }
			}
			.alert("Import", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
				Button("OK") {}
			} message: {
				Text(message ?? "")
			}
		}
	}

	/// Online only: the server parses and deduplicates the Revolut export, the next pull brings the rows.
	private func importCSV(_ result: Result<URL, Error>) async {
		do {
			let url = try result.get()
			let accessing = url.startAccessingSecurityScopedResource()
			defer { if accessing { url.stopAccessingSecurityScopedResource() } }
			let inserted = try await services.api.importPurchases(csv: Data(contentsOf: url))
			message = inserted == 0 ? "Aucun nouvel achat." : "\(inserted) achat(s) importé(s)."
			await services.sync.sync()
		} catch {
			message = error.localizedDescription
		}
	}
}

struct PurchaseRow: View {
	let purchase: Purchase

	var body: some View {
		HStack {
			VStack(alignment: .leading, spacing: 2) {
				HStack(spacing: 6) {
					Text(purchase.notes ?? "Achat").lineLimit(1)
					SyncBadge(state: purchase.syncState)
				}
				HStack(spacing: 6) {
					Text(Formats.date(purchase.date))
					if purchase.isImported {
						Label("Importé", systemImage: "lock.fill").labelStyle(.titleAndIcon)
					}
				}
				.font(.caption)
				.foregroundStyle(.secondary)
			}
			Spacer()
			Text(purchase.amount.euros).monospacedDigit()
		}
	}
}

struct PurchaseFormView: View {
	let purchase: Purchase?

	@Environment(AppServices.self) private var services
	@Environment(\.dismiss) private var dismiss
	@State private var draft: PurchaseDraft
	@State private var showsErrors = false

	init(purchase: Purchase?) {
		self.purchase = purchase
		_draft = State(initialValue: purchase.map(PurchaseDraft.init(purchase:)) ?? PurchaseDraft())
	}

	var body: some View {
		NavigationStack {
			Form {
				Section {
					DatePicker("Date", selection: $draft.date, displayedComponents: .date)
						.environment(\.locale, Formats.locale)
					AmountField(title: "Montant", text: $draft.amount)
					TextField("Description (ex. ingrédients)", text: $draft.notes, axis: .vertical)
				} footer: {
					Text("Un montant négatif correspond à un remboursement.")
				}
				if showsErrors { FormErrors(errors: draft.errors) }
			}
			.navigationTitle(purchase == nil ? "Nouvel achat" : "Modifier l'achat")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
				ToolbarItem(placement: .confirmationAction) {
					Button("Enregistrer") {
						guard draft.isValid else { return showsErrors = true }
						services.store.save(draft, editing: purchase)
						dismiss()
					}
				}
			}
		}
	}
}
