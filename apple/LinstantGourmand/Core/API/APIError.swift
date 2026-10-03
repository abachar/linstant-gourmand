import Foundation

/// Errors of docs/api.md, plus transport failures.
nonisolated enum APIError: Error, Equatable, Sendable {
	/// No network, timeout, DNS…: retry later.
	case network(String)
	/// 5xx: retry later.
	case server(status: Int)
	/// Access token rejected even after a refresh.
	case unauthorized
	case invalidCredentials(String)
	/// Refresh token unknown, expired or revoked: the password must be typed again.
	case invalidRefreshToken
	case forbidden(String)
	case notFound
	/// `current` is the raw JSON of the server entity, `nil` when the server has none.
	case conflict(current: Data?)
	case validation(message: String, fields: [String: String])
	case rateLimited(String)
	case badRequest(String)
	case decoding(String)

	/// Worth retrying the same request later without user action.
	var isTransient: Bool {
		switch self {
		case .network, .server: true
		default: false
		}
	}

	/// Parses `{ "error": { "code", "message", "fields" }, "current": … }`.
	static func from(status: Int, body: Data) -> APIError {
		let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
		let error = json?["error"] as? [String: Any]
		let code = error?["code"] as? String
		let message = error?["message"] as? String ?? HTTPURLResponse.localizedString(forStatusCode: status)

		switch (status, code) {
		case (_, "conflict"), (409, _):
			var current: Data?
			if let value = json?["current"], !(value is NSNull) {
				current = try? JSONSerialization.data(withJSONObject: value)
			}
			return .conflict(current: current)
		case (_, "validation"), (422, _):
			let fields = (error?["fields"] as? [String: Any])?.compactMapValues { $0 as? String } ?? [:]
			return .validation(message: message, fields: fields)
		case (_, "invalid_credentials"):
			return .invalidCredentials(message)
		case (_, "invalid_refresh_token"):
			return .invalidRefreshToken
		case (401, _):
			return .unauthorized
		case (403, _):
			return .forbidden(message)
		case (404, _):
			return .notFound
		case (429, _):
			return .rateLimited(message)
		case (400, _):
			return .badRequest(message)
		case (500..., _):
			return .server(status: status)
		default:
			return .badRequest(message)
		}
	}
}

extension APIError: LocalizedError {
	var errorDescription: String? {
		switch self {
		case .network: "Connexion au serveur impossible."
		case let .server(status): "Erreur serveur (\(status))."
		case .unauthorized: "Session expirée."
		case let .invalidCredentials(message): message
		case .invalidRefreshToken: "Session expirée, reconnectez-vous."
		case let .forbidden(message): message
		case .notFound: "Introuvable."
		case .conflict: "Modifié ailleurs entre-temps."
		case let .validation(message, fields):
			fields.isEmpty ? message : fields.values.sorted().joined(separator: "\n")
		case let .rateLimited(message): message
		case let .badRequest(message): message
		case let .decoding(message): "Réponse illisible : \(message)"
		}
	}
}
