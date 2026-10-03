import Foundation
import Observation
import SwiftData

/// Wires the services together; injected into the views through the environment.
@Observable
final class AppServices {
	let container: ModelContainer
	let api: APIClient
	let auth: AuthService
	let sync: SyncEngine
	let store: LocalStore
	let connectivity: Connectivity

	init(container: ModelContainer) {
		self.container = container
		let api = APIClient()
		let auth = AuthService(api: api)
		let sync = SyncEngine(context: container.mainContext, api: api)
		let connectivity = Connectivity()

		self.api = api
		self.auth = auth
		self.sync = sync
		self.store = LocalStore(context: container.mainContext, engine: sync)
		self.connectivity = connectivity

		sync.canSync = { [weak auth] in auth?.state == .unlocked }
		sync.onSessionExpired = { [weak auth] in auth?.endSession() }
		auth.onUnlocked = { [weak sync] in sync?.scheduleSync(after: .zero) }
		connectivity.onChange = { [weak sync] online in sync?.isOnline = online }
	}

	var isOnline: Bool { connectivity.isOnline }
}
