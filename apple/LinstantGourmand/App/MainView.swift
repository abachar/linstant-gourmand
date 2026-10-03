import SwiftUI

struct MainView: View {
	@Environment(AppServices.self) private var services
	@State private var showsIssues = false

	var body: some View {
		TabView {
			Tab("Accueil", systemImage: "square.grid.2x2") {
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
		.modifier(SyncAccessory(showsIssues: $showsIssues))
		.sheet(isPresented: $showsIssues) {
			ConflictsListView()
		}
	}
}

/// Sync runs by itself: the accessory only shows up when something is off (offline, failure, conflicts).
private struct SyncAccessory: ViewModifier {
	@Environment(AppServices.self) private var services
	@Binding var showsIssues: Bool

	private var isAbnormal: Bool {
		let sync = services.sync
		if case .failed = sync.phase { return true }
		return !services.isOnline || sync.phase == .offline || sync.issueCount > 0
	}

	func body(content: Content) -> some View {
		if #available(iOS 26.1, *) {
			content.tabViewBottomAccessory(isEnabled: isAbnormal) {
				SyncStatusBar(showsIssues: $showsIssues)
			}
		} else {
			content.tabViewBottomAccessory {
				SyncStatusBar(showsIssues: $showsIssues)
			}
		}
	}
}

/// Sync state, always visible above the tab bar; opens the conflicts when there are any.
struct SyncStatusBar: View {
	@Environment(AppServices.self) private var services
	@Binding var showsIssues: Bool

	var body: some View {
		let sync = services.sync
		HStack(spacing: Spacing.s) {
			Label(title, systemImage: symbol)
				.font(.footnote.weight(.medium))
				.foregroundStyle(color)
				.lineLimit(1)
			Spacer()
			if sync.issueCount > 0 {
				Button("\(sync.issueCount) à traiter") { showsIssues = true }
					.font(.footnote.weight(.semibold))
					.tint(Theme.warning)
					.frame(minHeight: 44)
			} else if case .failed = sync.phase, services.isOnline {
				Button("Réessayer") { Task { await sync.sync() } }
					.font(.footnote.weight(.semibold))
					.frame(minHeight: 44)
			}
		}
		.padding(.horizontal)
	}

	private var symbol: String {
		let sync = services.sync
		if !services.isOnline || sync.phase == .offline { return "wifi.slash" }
		if case .failed = sync.phase { return "exclamationmark.icloud" }
		if sync.issueCount > 0 { return "exclamationmark.triangle" }
		return "checkmark.icloud"
	}

	private var color: Color {
		if case .failed = services.sync.phase, services.isOnline { return Theme.warning }
		return Theme.textMuted
	}

	private var title: String {
		let sync = services.sync
		let pending = sync.pendingCount == 0 ? "" : sync.pendingCount == 1 ? " · 1 modification en attente" : " · \(sync.pendingCount) modifications en attente"
		if !services.isOnline || sync.phase == .offline { return "Hors ligne" + pending }
		if case let .failed(message) = sync.phase { return message }
		if sync.issueCount > 0 { return "Conflits de synchronisation" }
		return "À jour"
	}
}
