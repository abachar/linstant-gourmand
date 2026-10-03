import SwiftData
import SwiftUI

/// "À traiter": conflicts (409) and refusals (422/403) waiting for a decision.
struct ConflictsListView: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(\.modelContext) private var context
	@Query(sort: \PendingMutation.createdAt) private var mutations: [PendingMutation]

	private var issues: [PendingMutation] { mutations.filter { $0.status != .pending } }

	var body: some View {
		NavigationStack {
			List {
				if issues.isEmpty {
					ContentUnavailableView("Rien à traiter", systemImage: "checkmark.circle")
				}
				ForEach(issues) { mutation in
					NavigationLink {
						ConflictDetailView(mutation: mutation)
					} label: {
						VStack(alignment: .leading, spacing: 2) {
							Text(ConflictText.title(of: mutation, in: context)).font(.headline)
							Text(ConflictText.situation(of: mutation))
								.font(.caption)
								.foregroundStyle(.secondary)
						}
					}
				}
			}
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
							.foregroundStyle(.red)
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
							Text(diff.label).font(.caption.bold()).foregroundStyle(.secondary)
							HStack(alignment: .top) {
								VStack(alignment: .leading) {
									Text("iPhone").font(.caption2).foregroundStyle(.secondary)
									Text(diff.mine)
								}
								.frame(maxWidth: .infinity, alignment: .leading)
								VStack(alignment: .leading) {
									Text("Serveur").font(.caption2).foregroundStyle(.secondary)
									Text(diff.server)
								}
								.frame(maxWidth: .infinity, alignment: .leading)
							}
							.font(.subheadline)
						}
						.listRowBackground(diff.differs ? Color.orange.opacity(0.15) : nil)
					}
				}
			}

			Section { actions }
		}
		.navigationTitle(mutation.status == .conflict ? "Conflit" : "Refusé")
		.navigationBarTitleDisplayMode(.inline)
		.sheet(item: $correcting) { kind in
			correctionForm(kind)
		}
	}

	@ViewBuilder private var actions: some View {
		switch (mutation.status, mutation.op, serverGone) {
		case (.conflict, .upsert, false):
			Button("Garder la mienne") { resolve { services.sync.keepMine(mutation) } }
			Button("Prendre le serveur") { resolve { services.sync.takeServer(mutation) } }
			Button("Corriger") { correcting = mutation.kind }
		case (.conflict, .upsert, true):
			Button("Recréer avec mes modifications") { resolve { services.sync.keepMine(mutation) } }
			Button("Abandonner", role: .destructive) { resolve { services.sync.takeServer(mutation) } }
		case (.conflict, .delete, false):
			Button("Supprimer quand même", role: .destructive) { resolve { services.sync.keepMine(mutation) } }
			Button("Garder la version serveur") { resolve { services.sync.takeServer(mutation) } }
		case (.conflict, .delete, true):
			Button("OK") { resolve { services.sync.keepMine(mutation) } }
		case (_, .delete, _):
			Button("Annuler la suppression") { resolve { services.sync.cancelDeletion(mutation) } }
		default:
			Button("Corriger") { correcting = mutation.kind }
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
