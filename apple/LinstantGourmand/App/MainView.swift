import SwiftUI

struct MainView: View {
	@Environment(AppServices.self) private var services
	@State private var showsIssues = false

	var body: some View {
		TabView {
			Tab("Tableau de bord", systemImage: "square.grid.2x2") {
				DashboardView()
			}
			.badge(services.sync.issueCount)

			Tab("Ventes", systemImage: "bag") {
				SalesListView()
			}

			Tab("Achats", systemImage: "basket") {
				PurchasesListView()
			}

			Tab("Stock", systemImage: "refrigerator") {
				ProductsListView()
			}

			Tab("Taxes", systemImage: "chart.pie") {
				TaxesView()
			}
		}
		.tabViewBottomAccessory {
			SyncStatusBar(showsIssues: $showsIssues)
		}
		.sheet(isPresented: $showsIssues) {
			ConflictsListView()
		}
	}
}

/// Sync state, always visible above the tab bar; opens the conflicts when there are any.
struct SyncStatusBar: View {
	@Environment(AppServices.self) private var services
	@Binding var showsIssues: Bool

	var body: some View {
		let sync = services.sync
		HStack(spacing: 10) {
			icon
			VStack(alignment: .leading, spacing: 0) {
				Text(title).font(.subheadline.weight(.semibold))
				if let subtitle {
					Text(subtitle).font(.caption).foregroundStyle(.secondary)
				}
			}
			Spacer()
			if sync.issueCount > 0 {
				Button("\(sync.issueCount) à traiter") { showsIssues = true }
					.buttonStyle(.borderedProminent)
					.tint(.orange)
					.controlSize(.small)
			} else {
				Button {
					Task { await sync.sync() }
				} label: {
					Image(systemName: "arrow.clockwise")
				}
				.disabled(!services.isOnline || sync.phase == .syncing)
				.accessibilityLabel("Synchroniser")
			}
		}
		.padding(.horizontal)
	}

	@ViewBuilder private var icon: some View {
		switch services.sync.phase {
		case .syncing: ProgressView()
		case .offline: Image(systemName: "wifi.slash").foregroundStyle(.secondary)
		case .failed: Image(systemName: "exclamationmark.icloud").foregroundStyle(.orange)
		case .idle:
			Image(systemName: services.isOnline ? "checkmark.icloud" : "wifi.slash").foregroundStyle(.secondary)
		}
	}

	private var title: String {
		let sync = services.sync
		if !services.isOnline { return "Hors ligne" }
		switch sync.phase {
		case .syncing: return "Synchronisation…"
		case .offline: return "Hors ligne"
		case let .failed(message): return message
		case .idle: return sync.pendingCount > 0 ? "Modifications en attente" : "À jour"
		}
	}

	private var subtitle: String? {
		let sync = services.sync
		if sync.pendingCount > 0 {
			return sync.pendingCount == 1 ? "1 modification à envoyer" : "\(sync.pendingCount) modifications à envoyer"
		}
		return sync.lastSyncAt.map { "Synchronisé \(Formats.relative($0))" }
	}
}
