import SwiftUI

/// Shown on launch and when coming back from the background. Also what the app switcher snapshot shows.
struct LockView: View {
	@Environment(AppServices.self) private var services
	@Environment(\.scenePhase) private var scenePhase
	/// Prompt automatically once per appearance: the prompt itself bounces scenePhase through .inactive,
	/// and a cancelled prompt must not come back in a loop.
	@State private var didAutoPrompt = false

	var body: some View {
		VStack(spacing: 24) {
			Spacer()
			Image(systemName: "lock.fill")
				.font(.system(size: 56))
				.foregroundStyle(.tint)
			Text("L'Instant Gourmand")
				.font(.title.bold())
			if let error = services.auth.lockError {
				Text(error)
					.font(.footnote)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
			}
			Spacer()
			Button {
				Task { await services.auth.unlock() }
			} label: {
				Label("Déverrouiller avec \(services.auth.biometryName)", systemImage: "faceid")
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(.glassProminent)
			.controlSize(.large)
		}
		.padding(32)
		.task(id: scenePhase) {
			guard scenePhase == .active, !didAutoPrompt else { return }
			didAutoPrompt = true
			await services.auth.unlock()
		}
	}
}
