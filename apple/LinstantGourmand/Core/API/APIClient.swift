import Foundation

/// Supplies bearer tokens to the API client (implemented by AuthService).
protocol TokenProvider: AnyObject {
	/// A non-expired access token, refreshed if needed.
	func validAccessToken() async throws -> String
	/// Called after a 401: force a refresh and return the new access token.
	func refreshAfterUnauthorized() async throws -> String
}

/// The authenticated endpoints used by the sync engine and the screens (faked in tests).
protocol APIClientProtocol: AnyObject {
	func sync(cursor: Int, limit: Int) async throws -> SyncResponse
	func putSale(id: UUID, input: SaleInput) async throws -> SaleDTO
	func deleteSale(id: UUID, baseVersion: Int) async throws -> SaleDTO
	func putPurchase(id: UUID, input: PurchaseInput) async throws -> PurchaseDTO
	func deletePurchase(id: UUID, baseVersion: Int) async throws -> PurchaseDTO
	func putProduct(id: UUID, input: ProductInput) async throws -> ProductDTO
	func deleteProduct(id: UUID, baseVersion: Int) async throws -> ProductDTO
	func dashboard(month: String) async throws -> DashboardDTO
	func taxes(year: Int) async throws -> TaxesDTO
	func clients() async throws -> [ClientDTO]
	func updateClient(_ input: ClientUpdateInput) async throws
	func salePDF(id: UUID, type: PrintType) async throws -> Data
	func importPurchases(csv: Data) async throws -> Int
}

enum AppConfig {
	/// Simulator debug builds talk to the local Next.js server, everything else to production.
	/// Override with the launch argument `-apiBaseURL http://…/api/v1`.
	static var apiBaseURL: URL {
		if let override = UserDefaults.standard.string(forKey: "apiBaseURL"), let url = URL(string: override) {
			return url
		}
		#if DEBUG && targetEnvironment(simulator)
			return URL(string: "http://localhost:3000/api/v1")!
		#else
			return URL(string: "https://linstant-gourmand.crafters.dev/api/v1")!
		#endif
	}
}

final class APIClient: APIClientProtocol {
	weak var tokenProvider: TokenProvider?

	private let baseURL: URL
	private let session: URLSession
	private let decoder = JSONCoding.makeDecoder()
	private let encoder = JSONCoding.makeEncoder()

	init(baseURL: URL = AppConfig.apiBaseURL, session: URLSession = .shared) {
		self.baseURL = baseURL
		self.session = session
	}

	// MARK: Auth (no bearer)

	func login(email: String, password: String, deviceName: String) async throws -> TokenPair {
		struct Body: Encodable { let email, password, deviceName: String }
		return try await decode(send("POST", "auth/login", body: encode(Body(email: email, password: password, deviceName: deviceName)), authorized: false))
	}

	func refresh(refreshToken: String) async throws -> TokenPair {
		struct Body: Encodable { let refreshToken: String }
		return try await decode(send("POST", "auth/refresh", body: encode(Body(refreshToken: refreshToken)), authorized: false))
	}

	func logout(refreshToken: String) async throws {
		struct Body: Encodable { let refreshToken: String }
		_ = try await send("POST", "auth/logout", body: encode(Body(refreshToken: refreshToken)))
	}

	// MARK: Sync & entities

	func sync(cursor: Int, limit: Int) async throws -> SyncResponse {
		try await decode(send("GET", "sync", query: ["cursor": "\(cursor)", "limit": "\(limit)"]))
	}

	func putSale(id: UUID, input: SaleInput) async throws -> SaleDTO {
		try await decode(send("PUT", "sales/\(id.apiString)", body: encode(input)))
	}

	func deleteSale(id: UUID, baseVersion: Int) async throws -> SaleDTO {
		try await decode(send("DELETE", "sales/\(id.apiString)", query: ["baseVersion": "\(baseVersion)"]))
	}

	func putPurchase(id: UUID, input: PurchaseInput) async throws -> PurchaseDTO {
		try await decode(send("PUT", "purchases/\(id.apiString)", body: encode(input)))
	}

	func deletePurchase(id: UUID, baseVersion: Int) async throws -> PurchaseDTO {
		try await decode(send("DELETE", "purchases/\(id.apiString)", query: ["baseVersion": "\(baseVersion)"]))
	}

	func putProduct(id: UUID, input: ProductInput) async throws -> ProductDTO {
		try await decode(send("PUT", "products/\(id.apiString)", body: encode(input)))
	}

	func deleteProduct(id: UUID, baseVersion: Int) async throws -> ProductDTO {
		try await decode(send("DELETE", "products/\(id.apiString)", query: ["baseVersion": "\(baseVersion)"]))
	}

	// MARK: Online-only

	func dashboard(month: String) async throws -> DashboardDTO {
		try await decode(send("GET", "dashboard", query: ["month": month]))
	}

	func taxes(year: Int) async throws -> TaxesDTO {
		try await decode(send("GET", "taxes", query: ["year": "\(year)"]))
	}

	func clients() async throws -> [ClientDTO] {
		try await decode(send("GET", "clients"))
	}

	func updateClient(_ input: ClientUpdateInput) async throws {
		_ = try await send("PUT", "clients", body: encode(input))
	}

	func salePDF(id: UUID, type: PrintType) async throws -> Data {
		try await send("GET", "sales/\(id.apiString)/pdf", query: ["type": type.rawValue])
	}

	func importPurchases(csv: Data) async throws -> Int {
		let result: ImportResult = try await decode(send("POST", "purchases/import", body: csv, contentType: "text/csv"))
		return result.inserted
	}

	// MARK: Transport

	private func encode<T: Encodable>(_ value: T) throws -> Data {
		try encoder.encode(value)
	}

	private func decode<T: Decodable>(_ data: Data) throws -> T {
		do {
			return try decoder.decode(T.self, from: data)
		} catch {
			throw APIError.decoding(String(describing: error))
		}
	}

	private func send(
		_ method: String,
		_ path: String,
		query: [String: String] = [:],
		body: Data? = nil,
		contentType: String = "application/json",
		authorized: Bool = true
	) async throws -> Data {
		var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
		if !query.isEmpty {
			components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
		}
		var request = URLRequest(url: components.url!)
		request.httpMethod = method
		request.timeoutInterval = 30
		request.setValue("application/json", forHTTPHeaderField: "Accept")
		if let body {
			request.httpBody = body
			request.setValue(contentType, forHTTPHeaderField: "Content-Type")
		}

		guard authorized else { return try await perform(request) }
		guard let tokenProvider else { throw APIError.unauthorized }

		request.setValue("Bearer \(try await tokenProvider.validAccessToken())", forHTTPHeaderField: "Authorization")
		do {
			return try await perform(request)
		} catch APIError.unauthorized {
			// The access token may have expired in flight: refresh once and replay.
			request.setValue("Bearer \(try await tokenProvider.refreshAfterUnauthorized())", forHTTPHeaderField: "Authorization")
			return try await perform(request)
		}
	}

	private func perform(_ request: URLRequest) async throws -> Data {
		let data: Data
		let response: URLResponse
		do {
			(data, response) = try await session.data(for: request)
		} catch {
			throw APIError.network(error.localizedDescription)
		}
		guard let http = response as? HTTPURLResponse else { throw APIError.network("Réponse invalide") }
		guard (200..<300).contains(http.statusCode) else {
			throw APIError.from(status: http.statusCode, body: data)
		}
		return data
	}
}

extension UUID {
	/// The API uses lowercase UUIDs.
	nonisolated var apiString: String { uuidString.lowercased() }
}
