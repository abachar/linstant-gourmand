import Foundation
import LocalAuthentication

/// Face ID, falling back to the device passcode. Works offline: it guards the local data, not the server.
struct BiometricGate {
	enum GateError: LocalizedError {
		case failed(String)

		var errorDescription: String? {
			switch self {
			case let .failed(message): message
			}
		}
	}

	var biometryName: String {
		let context = LAContext()
		_ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
		switch context.biometryType {
		case .faceID: return "Face ID"
		case .touchID: return "Touch ID"
		case .opticID: return "Optic ID"
		default: return "le code"
		}
	}

	/// Returns the evaluated context, reused to read the Keychain without a second prompt.
	/// A device with no passcode at all cannot be protected: the gate then lets through.
	func authenticate(reason: String) async throws -> LAContext {
		let context = LAContext()
		context.localizedCancelTitle = "Annuler"
		var error: NSError?
		guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return context }

		let failure: String? = await withCheckedContinuation { continuation in
			context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
				continuation.resume(returning: success ? nil : (error?.localizedDescription ?? "Authentification refusée."))
			}
		}
		if let failure { throw GateError.failed(failure) }
		return context
	}
}
