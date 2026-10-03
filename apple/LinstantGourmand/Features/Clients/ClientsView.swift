import SwiftData
import SwiftUI

/// Clients are derived from the sales on the server. Renaming one rewrites all its sales: online only.
struct ClientsView: View {
	@Environment(AppServices.self) private var services
	@Environment(\.modelContext) private var context
	@State private var clients: (value: [ClientDTO], fetchedAt: Date)?
	@State private var editing: ClientDTO?
	@State private var error: String?
	@State private var searchText = ""

	private var filtered: [ClientDTO] {
		let query = searchText.trimmingCharacters(in: .whitespaces)
		guard let clients else { return [] }
		guard !query.isEmpty else { return clients.value }
		return clients.value.filter {
			$0.clientName.localizedCaseInsensitiveContains(query)
				|| ($0.deliveryAddress?.localizedCaseInsensitiveContains(query) ?? false)
		}
	}

	var body: some View {
		List {
			if let error {
				InfoBanner(kind: .error, text: error)
					.listRowBackground(Color.clear)
					.listRowInsets(EdgeInsets())
			}
			if clients != nil {
				ForEach(filtered) { client in
					Button {
						editing = client
					} label: {
						HStack(alignment: .top, spacing: Spacing.m) {
							VStack(alignment: .leading, spacing: 2) {
								HStack(alignment: .firstTextBaseline) {
									Text(client.clientName).font(.cardTitle)
									Spacer()
									Text(client.totalAmount.formatted)
										.font(.headline.bold())
										.monospacedDigit()
										.foregroundStyle(Theme.accent)
								}
								if let address = client.deliveryAddress {
									Text(address).font(.subheadline).foregroundStyle(Theme.textMuted)
								}
								Text(client.orderCount <= 1 ? "\(client.orderCount) commande" : "\(client.orderCount) commandes")
									.font(.caption)
									.foregroundStyle(Theme.textMuted)
							}
							if !services.isOnline {
								Image(systemName: "lock")
									.foregroundStyle(Theme.textMuted)
									.accessibilityLabel("Modification disponible en ligne uniquement")
							}
						}
						.frame(maxWidth: .infinity, alignment: .leading)
						.accessibilityElement(children: .combine)
					}
					.tint(.primary)
					.disabled(!services.isOnline)
					.cardRow()
				}
			} else if services.isOnline {
				LoadingCards(count: 4)
					.listRowBackground(Color.clear)
					.listRowSeparator(.hidden)
			}

			Section {
				EmptyView()
			} footer: {
				if !services.isOnline {
					OfflineNotice(text: "Modification des clients disponible en ligne uniquement.")
				} else if let clients {
					Text("À jour \(Formats.relative(clients.fetchedAt)).")
				}
			}
		}
		.listStyle(.insetGrouped)
		.listRowSpacing(12)
		.screenBackground()
		.searchable(text: $searchText, prompt: "Rechercher un client")
		.navigationTitle("Clients")
		.refreshable { await load() }
		.task {
			clients = context.cachedReport([ClientDTO].self, key: "clients")
			await load()
		}
		.sheet(item: $editing) { client in
			ClientEditView(client: client) { await load() }
		}
	}

	private func load() async {
		guard services.isOnline else { return }
		do {
			let value = try await services.api.clients()
			error = nil
			context.storeReport(value, key: "clients")
			clients = (value, .now)
		} catch {
			self.error = error.localizedDescription
		}
	}
}

private struct ClientEditView: View {
	let client: ClientDTO
	let onSaved: () async -> Void

	@Environment(AppServices.self) private var services
	@Environment(\.dismiss) private var dismiss
	@State private var name: String
	@State private var address: String
	@State private var isSaving = false
	@State private var error: String?

	init(client: ClientDTO, onSaved: @escaping () async -> Void) {
		self.client = client
		self.onSaved = onSaved
		_name = State(initialValue: client.clientName)
		_address = State(initialValue: client.deliveryAddress ?? "")
	}

	var body: some View {
		NavigationStack {
			Form {
				Section {
					TextField("Nom", text: $name)
					TextField("Adresse", text: $address, axis: .vertical)
				} footer: {
					Text("La modification s'applique aux \(client.orderCount) vente(s) de ce client.")
				}
				if let error {
					Section {
						InfoBanner(kind: .error, text: error)
							.listRowBackground(Color.clear)
							.listRowInsets(EdgeInsets())
					}
				}
			}
			.screenBackground()
			.navigationTitle("Modifier le client")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
				ToolbarItem(placement: .confirmationAction) {
					Button("Enregistrer") { Task { await save() } }
						.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving || !services.isOnline)
				}
			}
		}
	}

	private func save() async {
		isSaving = true
		defer { isSaving = false }
		do {
			try await services.api.updateClient(ClientUpdateInput(
				oldClientName: client.clientName,
				oldDeliveryAddress: client.deliveryAddress,
				newClientName: name.trimmingCharacters(in: .whitespaces),
				newDeliveryAddress: address.trimmedOrNil
			))
			// The renamed sales come back through the next pull (and may conflict with pending edits).
			await services.sync.sync()
			await onSaved()
			dismiss()
		} catch {
			self.error = error.localizedDescription
		}
	}
}
