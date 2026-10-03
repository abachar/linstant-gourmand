import SwiftData
import SwiftUI

@main
struct LinstantGourmandApp: App {
	@State private var services: AppServices? = Self.isRunningTests ? nil : Self.makeServices()

	var body: some Scene {
		WindowGroup {
			if let services {
				RootView()
					.environment(services)
					.modelContainer(services.container)
			} else {
				Color.clear
			}
		}
	}

	private static var isRunningTests: Bool {
		ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
	}

	private static func makeServices() -> AppServices {
		do {
			return AppServices(container: try Persistence.makeContainer())
		} catch {
			fatalError("Base locale illisible : \(error)")
		}
	}
}
