import Foundation
import Network
import Observation

/// Network reachability, used to trigger a sync when the connection comes back.
@Observable
final class Connectivity {
	private(set) var isOnline = true
	@ObservationIgnored var onChange: ((Bool) -> Void)?
	@ObservationIgnored private let monitor = NWPathMonitor()

	init() {
		monitor.pathUpdateHandler = { [weak self] path in
			let online = path.status == .satisfied
			Task { @MainActor in self?.update(online) }
		}
		monitor.start(queue: DispatchQueue(label: "dev.crafters.linstantgourmand.connectivity"))
	}

	private func update(_ online: Bool) {
		guard online != isOnline else { return }
		isOnline = online
		onChange?(online)
	}
}
