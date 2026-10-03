import SwiftData
import SwiftUI

struct ProductsListView: View {
	@Environment(AppServices.self) private var services
	@Query(sort: \Product.productName) private var products: [Product]
	@State private var editing: Product?
	@State private var isCreating = false

	private var visible: [Product] { products.filter { !$0.isPendingDeletion } }

	var body: some View {
		NavigationStack {
			List {
				Section {
					if visible.isEmpty {
						EmptyState(
							systemImage: "refrigerator",
							title: "Aucun produit en stock",
							actionTitle: "Ajouter le premier produit"
						) { isCreating = true }
							.listRowBackground(Color.clear)
							.listRowSeparator(.hidden)
					}
					ForEach(visible) { product in
						Button {
							editing = product
						} label: {
							ProductRow(product: product)
						}
						.tint(.primary)
						.cardRow()
						.swipeActions {
							Button("Supprimer", role: .destructive) { services.store.delete(product) }
						}
					}
				} header: {
					HStack {
						Text("Stock actuel").overline()
						Spacer()
						Text(visible.count <= 1 ? "\(visible.count) produit" : "\(visible.count) produits")
							.font(.caption)
							.foregroundStyle(Theme.textMuted)
					}
				}
			}
			.listStyle(.insetGrouped)
			.listRowSpacing(12)
			.screenBackground()
			.navigationTitle("Stock")
			.refreshable { await services.sync.sync() }
			.toolbar {
				Button {
					isCreating = true
				} label: {
					Label("Nouveau produit", systemImage: "plus")
				}
				.buttonStyle(.glassProminent)
			}
			.sheet(isPresented: $isCreating) { ProductFormView(product: nil) }
			.sheet(item: $editing) { ProductFormView(product: $0) }
		}
	}
}

struct ProductRow: View {
	let product: Product

	private var quantityColor: Color {
		switch product.quantity {
		case 0: Theme.danger
		case ..<10: Theme.warning
		default: Theme.success
		}
	}

	private var expirationColor: Color {
		guard let date = product.expirationDate else { return Theme.textMuted }
		if date < .now { return Theme.danger }
		if date < Calendar.current.date(byAdding: .month, value: 1, to: .now)! { return Theme.warning }
		return Theme.textMuted
	}

	private var status: (text: String, color: Color) {
		switch product.quantity {
		case 0: ("Rupture", Theme.danger)
		case ..<10: ("Stock faible", Theme.warning)
		default: ("En stock", Theme.success)
		}
	}

	var body: some View {
		VStack(alignment: .leading, spacing: Spacing.m) {
			HStack(alignment: .firstTextBaseline, spacing: 6) {
				Text(product.productName).font(.cardTitle)
				SyncBadge(state: product.syncState)
				Spacer()
				Text(product.quantity <= 1 ? "\(product.quantity) unité" : "\(product.quantity) unités")
					.font(.subheadline.bold())
					.foregroundStyle(quantityColor)
			}
			HStack(alignment: .bottom, spacing: Spacing.l) {
				VStack(alignment: .leading, spacing: 2) {
					Text("Modifié le").overline()
					Text(Formats.date(product.updatedAt)).font(.footnote)
				}
				VStack(alignment: .leading, spacing: 2) {
					Text("Date limite").overline()
					Text(product.expirationDate.map(Formats.date) ?? "Aucune")
						.font(.footnote)
						.foregroundStyle(expirationColor)
				}
				Spacer()
				StatusPill(text: status.text, color: status.color)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.accessibilityElement(children: .combine)
	}
}

struct ProductFormView: View {
	let product: Product?

	@Environment(AppServices.self) private var services
	@Environment(\.dismiss) private var dismiss
	@State private var draft: ProductDraft
	@State private var showsErrors = false

	init(product: Product?) {
		self.product = product
		_draft = State(initialValue: product.map(ProductDraft.init(product:)) ?? ProductDraft())
	}

	var body: some View {
		NavigationStack {
			Form {
				Section {
					TextField("Nom du produit", text: $draft.productName)
					Stepper("Quantité : \(draft.quantity)", value: $draft.quantity, in: 0...100_000)
					Toggle("Date limite de consommation", isOn: $draft.hasExpirationDate)
					if draft.hasExpirationDate {
						DatePicker("Date limite", selection: $draft.expirationDate, displayedComponents: .date)
							.environment(\.locale, Formats.locale)
					}
				}
				if showsErrors { FormErrors(errors: draft.errors) }
			}
			.screenBackground()
			.navigationTitle(product == nil ? "Nouveau produit" : "Modifier le produit")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
				ToolbarItem(placement: .confirmationAction) {
					Button("Enregistrer") {
						guard draft.isValid else { return showsErrors = true }
						services.store.save(draft, editing: product)
						dismiss()
					}
				}
			}
		}
	}
}
