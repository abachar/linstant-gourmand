import SwiftData
import SwiftUI

/// "À traiter": conflicts (409) and refusals (422/403) waiting for a decision.
struct ConflictsListView: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(\.modelContext) private var context
	@Query(sort: \PendingMutation.createdAt) private var mutations: [PendingMutation]

	private var issues: [PendingMutation] { mutations.filter { $0.status != .pending } }

	private func icon(for kind: EntityKind) -> String {
		switch kind {
		case .sale: "bag"
		case .purchase: "basket"
		case .product: "refrigerator"
		}
	}

	var body: some View {
		NavigationStack {
			List {
				if issues.isEmpty {
					EmptyState(systemImage: "checkmark.circle", title: "Rien à traiter")
						.listRowBackground(Color.clear)
						.listRowSeparator(.hidden)
				}
				ForEach(issues) { mutation in
					NavigationLink {
						ConflictDetailView(mutation: mutation)
					} label: {
						HStack(alignment: .top, spacing: Spacing.m) {
							Image(systemName: icon(for: mutation.kind))
								.font(.title3)
								.foregroundStyle(Theme.accent)
								.frame(width: 28)
								.accessibilityHidden(true)
							VStack(alignment: .leading, spacing: Spacing.xs) {
								Text(ConflictText.title(of: mutation, in: context)).font(.headline)
								Text(ConflictText.situation(of: mutation))
									.font(.footnote)
									.foregroundStyle(Theme.textMuted)
								if mutation.status == .rejected {
									StatusPill(text: "Refusé", color: Theme.danger)
								} else {
									StatusPill(text: "Conflit", color: Theme.warning)
								}
							}
						}
						.accessibilityElement(children: .combine)
					}
					.cardRow()
				}
			}
			.listStyle(.insetGrouped)
			.listRowSpacing(12)
			.screenBackground()
			.navigationTitle("À traiter")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				Button("Fermer") { dismiss() }
			}
		}
	}
}

enum ConflictText {
	static func title(of mutation: PendingMutation, in context: ModelContext) -> String {
		let id = mutation.entityId
		let name: String? = switch mutation.kind {
		case .sale: context.sale(id: id)?.clientName
		case .purchase: context.purchase(id: id)?.notes ?? context.purchase(id: id).map { Formats.date($0.date) }
		case .product: context.product(id: id)?.productName
		}
		return "\(mutation.kind.label) · \(name ?? "—")"
	}

	static func situation(of mutation: PendingMutation) -> String {
		if mutation.status == .rejected {
			return mutation.op == .delete
				? "Suppression refusée par le serveur."
				: "Refusée par le serveur : \(mutation.lastError ?? "données invalides")."
		}
		let header = SnapshotHeader.decode(mutation.serverSnapshot)
		let serverGone = mutation.serverMissing || header?.deletedAt != nil
		switch (mutation.op, serverGone) {
		case (.upsert, false): return "Modifiée sur le web pendant que l'iPhone était hors ligne."
		case (.upsert, true): return "Supprimée sur le web, modifiée sur l'iPhone."
		case (.delete, false): return "Supprimée sur l'iPhone, modifiée sur le web."
		case (.delete, true): return "Supprimée des deux côtés."
		}
	}
}

struct ConflictDetailView: View {
	let mutation: PendingMutation

	@Environment(AppServices.self) private var services
	@Environment(\.modelContext) private var context
	@Environment(\.dismiss) private var dismiss
	@State private var correcting: EntityKind?

	private var serverGone: Bool {
		mutation.serverMissing || SnapshotHeader.decode(mutation.serverSnapshot)?.deletedAt != nil
	}

	var body: some View {
		if mutation.modelContext == nil {
			ContentUnavailableView("Résolu", systemImage: "checkmark.circle")
		} else {
			content
		}
	}

	private var content: some View {
		List {
			Section {
				Text(ConflictText.situation(of: mutation))
				if mutation.status == .rejected, !mutation.fieldErrors.isEmpty {
					ForEach(mutation.fieldErrors.sorted(by: { $0.key < $1.key }), id: \.key) { field, message in
						Label("\(field) : \(message)", systemImage: "exclamationmark.circle")
							.font(.footnote)
							.foregroundStyle(Theme.danger)
					}
				}
			} header: {
				Text(ConflictText.title(of: mutation, in: context))
			}

			let diffs = comparison
			if !diffs.isEmpty {
				Section("Comparaison") {
					ForEach(diffs) { diff in
						VStack(alignment: .leading, spacing: 6) {
							HStack(spacing: 6) {
								if diff.differs {
									Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.warning)
								}
								Text(diff.label).font(.caption.bold()).foregroundStyle(Theme.textMuted)
							}
							HStack(alignment: .top) {
								VStack(alignment: .leading) {
									Text("iPhone").overline()
									Text(diff.mine)
								}
								.frame(maxWidth: .infinity, alignment: .leading)
								VStack(alignment: .leading) {
									Text("Serveur").overline()
									Text(diff.server)
								}
								.frame(maxWidth: .infinity, alignment: .leading)
							}
							.font(.subheadline)
						}
						.accessibilityElement(children: .combine)
						.accessibilityLabel(
							"\(diff.label)\(diff.differs ? ", différent" : "") : iPhone \(diff.mine), serveur \(diff.server)"
						)
						.listRowBackground(Rectangle().fill(diff.differs ? AnyShapeStyle(Theme.tint(Theme.warning)) : AnyShapeStyle(Theme.surface)))
					}
				}
			}

			Section {
				actions
					.controlSize(.large)
					.listRowBackground(Color.clear)
			}
		}
		.screenBackground()
		.navigationTitle(mutation.status == .conflict ? "Conflit" : "Refusé")
		.navigationBarTitleDisplayMode(.inline)
		.sheet(item: $correcting) { kind in
			correctionForm(kind)
		}
	}

	@ViewBuilder private var actions: some View {
		switch (mutation.status, mutation.op, serverGone) {
		case (.conflict, .upsert, false):
			actionButton("Garder la mienne", prominent: true) { resolve { services.sync.keepMine(mutation) } }
			actionButton("Prendre le serveur") { resolve { services.sync.takeServer(mutation) } }
			actionButton("Corriger") { correcting = mutation.kind }
		case (.conflict, .upsert, true):
			actionButton("Recréer avec mes modifications", prominent: true) { resolve { services.sync.keepMine(mutation) } }
			actionButton("Abandonner", role: .destructive) { resolve { services.sync.takeServer(mutation) } }
		case (.conflict, .delete, false):
			actionButton("Supprimer quand même", role: .destructive, prominent: true) { resolve { services.sync.keepMine(mutation) } }
			actionButton("Garder la version serveur") { resolve { services.sync.takeServer(mutation) } }
		case (.conflict, .delete, true):
			actionButton("OK", prominent: true) { resolve { services.sync.keepMine(mutation) } }
		case (_, .delete, _):
			actionButton("Annuler la suppression", prominent: true) { resolve { services.sync.cancelDeletion(mutation) } }
		default:
			actionButton("Corriger", prominent: true) { correcting = mutation.kind }
		}
	}

	@ViewBuilder private func actionButton(
		_ title: String,
		role: ButtonRole? = nil,
		prominent: Bool = false,
		action: @escaping () -> Void
	) -> some View {
		let button = Button(role: role, action: action) {
			Text(title).frame(maxWidth: .infinity)
		}
		if prominent {
			button.buttonStyle(.borderedProminent)
		} else {
			button.buttonStyle(.bordered)
		}
	}

	private func resolve(_ action: () -> Void) {
		action()
		dismiss()
	}

	private var comparison: [FieldDiff] {
		guard mutation.status == .conflict, mutation.op == .upsert, !serverGone, let snapshot = mutation.serverSnapshot else {
			return []
		}
		let decoder = JSONCoding.makeDecoder()
		let id = mutation.entityId
		switch mutation.kind {
		case .sale:
			guard let mine = context.sale(id: id), let server = try? decoder.decode(SaleDTO.self, from: snapshot) else { return [] }
			return ConflictDiff.sale(mine: mine.asDTO, server: server)
		case .purchase:
			guard let mine = context.purchase(id: id), let server = try? decoder.decode(PurchaseDTO.self, from: snapshot) else { return [] }
			return ConflictDiff.purchase(mine: mine.asDTO, server: server)
		case .product:
			guard let mine = context.product(id: id), let server = try? decoder.decode(ProductDTO.self, from: snapshot) else { return [] }
			return ConflictDiff.product(mine: mine.asDTO, server: server)
		}
	}

	/// The usual form, prefilled with the iPhone version; saving it resolves the conflict on top of the
	/// server version (LocalStore → SyncEngine.keepMine).
	@ViewBuilder private func correctionForm(_ kind: EntityKind) -> some View {
		let id = mutation.entityId
		switch kind {
		case .sale: SaleFormView(sale: context.sale(id: id)) { dismiss() }
		case .purchase: PurchaseFormView(purchase: context.purchase(id: id))
		case .product: ProductFormView(product: context.product(id: id))
		}
	}
}

extension EntityKind: Identifiable {
	var id: String { rawValue }
}
