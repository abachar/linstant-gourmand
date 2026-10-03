import Foundation
import LocalAuthentication
import Security

/// The refresh token, stored in the Keychain behind Face ID (`.biometryCurrentSet`): readable only after
/// a biometric match, invalidated when the enrolled faces change.
struct KeychainStore {
	enum KeychainError: Error {
		case status(OSStatus)
	}

	private let service = "dev.crafters.linstantgourmand"
	private let account = "refreshToken"

	/// Strongest protection first. The fallbacks only matter on devices without Face ID or without a passcode
	/// (simulator): the token then stays at least device-bound and unreadable while locked.
	private var protections: [(SecAccessControlCreateFlags?, CFString)] {
		[
			(.biometryCurrentSet, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly),
			(.userPresence, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly),
			(nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly),
		]
	}

	/// Replaces the token (delete + add: updating a protected item would itself require authentication).
	func saveRefreshToken(_ token: String) throws {
		deleteRefreshToken()
		var lastStatus: OSStatus = errSecSuccess
		for (flags, accessibility) in protections {
			var query = baseQuery
			query[kSecValueData] = Data(token.utf8)
			if let flags {
				guard let access = SecAccessControlCreateWithFlags(nil, accessibility, flags, nil) else { continue }
				query[kSecAttrAccessControl] = access
			} else {
				query[kSecAttrAccessible] = accessibility
			}
			lastStatus = SecItemAdd(query as CFDictionary, nil)
			if lastStatus == errSecSuccess { return }
		}
		throw KeychainError.status(lastStatus)
	}

	/// Reads the token with an already evaluated context, so the unlock prompt is not shown twice.
	func readRefreshToken(context: LAContext) throws -> String? {
		var query = baseQuery
		query[kSecReturnData] = true
		query[kSecMatchLimit] = kSecMatchLimitOne
		query[kSecUseAuthenticationContext] = context

		var result: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &result)
		switch status {
		case errSecSuccess:
			return (result as? Data).flatMap { String(data: $0, encoding: .utf8) }
		case errSecItemNotFound:
			return nil
		default:
			throw KeychainError.status(status)
		}
	}

	/// Whether a token exists, without triggering any authentication UI.
	func hasRefreshToken() -> Bool {
		let context = LAContext()
		context.interactionNotAllowed = true
		var query = baseQuery
		query[kSecUseAuthenticationContext] = context
		let status = SecItemCopyMatching(query as CFDictionary, nil)
		return status == errSecSuccess || status == errSecInteractionNotAllowed
	}

	func deleteRefreshToken() {
		SecItemDelete(baseQuery as CFDictionary)
	}

	private var baseQuery: [CFString: Any] {
		[
			kSecClass: kSecClassGenericPassword,
			kSecAttrService: service,
			kSecAttrAccount: account,
		]
	}
}
