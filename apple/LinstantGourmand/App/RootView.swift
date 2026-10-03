import SwiftUI

struct RootView: View {
	@Environment(AppServices.self) private var services
	@Environment(\.scenePhase) private var scenePhase

	var body: some View {
		Group {
			switch services.auth.state {
			case .loggedOut:
				LoginView()
			case .locked:
				LockView()
			case .unlocked:
				MainView()
			}
		}
		.animation(.default, value: services.auth.state)
		.onChange(of: scenePhase) { _, phase in
			switch phase {
			case .background:
				services.auth.lock()
			case .active where services.auth.state == .unlocked:
				services.sync.scheduleSync(after: .zero)
			default:
				break
			}
		}
	}
}
