import Foundation
import LocalAuthentication
import Observation
import UIKit

/// Session lifecycle: password once, then Face ID.
///
/// - The refresh token lives in the Keychain behind Face ID and in memory once unlocked.
/// - The access token (15 min) only lives in memory.
/// - Refreshes are single-flight and rotate the refresh token.
@Observable
final class AuthService: TokenProvider {
	enum State: Equatable {
		case loggedOut
		case locked
		case unlocked
	}

	private(set) var state: State
	private(set) var lockError: String?
	var biometryName: String { gate.biometryName }

	/// Called once the session is usable (after login or unlock).
	@ObservationIgnored var onUnlocked: (() -> Void)?

	@ObservationIgnored private let api: APIClient
	@ObservationIgnored private let keychain = KeychainStore()
	@ObservationIgnored private let gate = BiometricGate()
	@ObservationIgnored private var refreshToken: String?
	@ObservationIgnored private var accessToken: String?
	@ObservationIgnored private var accessTokenExpiresAt = Date.distantPast
	@ObservationIgnored private var refreshTask: Task<String, Error>?
	@ObservationIgnored private var isUnlocking = false

	init(api: APIClient) {
		self.api = api
		state = keychain.hasRefreshToken() ? .locked : .loggedOut
		api.tokenProvider = self
	}

	func login(email: String, password: String) async throws {
		let pair = try await api.login(email: email, password: password, deviceName: UIDevice.current.name)
		try store(pair)
		state = .unlocked
		onUnlocked?()
	}

	func unlock() async {
		guard state == .locked, !isUnlocking else { return }
		isUnlocking = true
		defer { isUnlocking = false }
		lockError = nil
		do {
			let context = try await gate.authenticate(reason: "Déverrouiller L'Instant Gourmand")
			if refreshToken == nil {
				guard let token = try keychain.readRefreshToken(context: context) else {
					state = .loggedOut
					return
				}
				refreshToken = token
			}
			state = .unlocked
			onUnlocked?()
		} catch {
			lockError = error.localizedDescription
		}
	}

	/// The app went to the background: Face ID is required again on return.
	func lock() {
		if state == .unlocked { state = .locked }
	}

	func logout() async {
		if let refreshToken { try? await api.logout(refreshToken: refreshToken) }
		endSession()
	}

	// MARK: TokenProvider

	func validAccessToken() async throws -> String {
		if let accessToken, accessTokenExpiresAt.timeIntervalSinceNow > 30 { return accessToken }
		return try await refresh()
	}

	func refreshAfterUnauthorized() async throws -> String {
		accessToken = nil
		return try await refresh()
	}

	private func refresh() async throws -> String {
		if let refreshTask { return try await refreshTask.value }
		guard let refreshToken else { throw APIError.invalidRefreshToken }

		let task = Task { [api] in
			let pair = try await api.refresh(refreshToken: refreshToken)
			try self.store(pair)
			return pair.accessToken
		}
		refreshTask = task
		defer { refreshTask = nil }
		do {
			return try await task.value
		} catch APIError.invalidRefreshToken {
			endSession()
			throw APIError.invalidRefreshToken
		}
	}

	private func store(_ pair: TokenPair) throws {
		try keychain.saveRefreshToken(pair.refreshToken)
		refreshToken = pair.refreshToken
		accessToken = pair.accessToken
		accessTokenExpiresAt = pair.accessTokenExpiresAt
	}

	/// Forgets the credentials only: local data and the outbox are kept for the next login.
	func endSession() {
		keychain.deleteRefreshToken()
		refreshToken = nil
		accessToken = nil
		accessTokenExpiresAt = .distantPast
		state = .loggedOut
	}
}
