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
				if visible.isEmpty {
					ContentUnavailableView("Aucun produit en stock", systemImage: "refrigerator")
				}
				ForEach(visible) { product in
					Button {
						editing = product
					} label: {
						ProductRow(product: product)
					}
					.tint(.primary)
					.swipeActions {
						Button("Supprimer", role: .destructive) { services.store.delete(product) }
					}
				}
			}
			.navigationTitle("Stock")
			.refreshable { await services.sync.sync() }
			.toolbar {
				Button {
					isCreating = true
				} label: {
					Label("Nouveau produit", systemImage: "plus")
				}
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
		case 0: .red
		case ..<10: .orange
		default: .green
		}
	}

	private var expirationColor: Color {
		guard let date = product.expirationDate else { return .secondary }
		if date < .now { return .red }
		if date < Calendar.current.date(byAdding: .month, value: 1, to: .now)! { return .orange }
		return .secondary
	}

	var body: some View {
		HStack {
			VStack(alignment: .leading, spacing: 2) {
				HStack(spacing: 6) {
					Text(product.productName).font(.headline)
					SyncBadge(state: product.syncState)
				}
				Text(product.expirationDate.map { "DLC \(Formats.date($0))" } ?? "Pas de date limite")
					.font(.caption)
					.foregroundStyle(expirationColor)
			}
			Spacer()
			Text(product.quantity <= 1 ? "\(product.quantity) unité" : "\(product.quantity) unités")
				.font(.subheadline.bold())
				.foregroundStyle(quantityColor)
		}
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
