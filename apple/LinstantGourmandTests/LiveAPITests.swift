import Foundation
import SwiftData
import Testing
@testable import LinstantGourmand

/// End-to-end against a running server (skipped by default):
/// `TEST_RUNNER_LG_LIVE_API=1 TEST_RUNNER_LG_EMAIL=… TEST_RUNNER_LG_PASSWORD=… xcodebuild test …`
@Suite(.enabled(if: ProcessInfo.processInfo.environment["LG_LIVE_API"] != nil))
struct LiveAPITests {
	final class StaticTokens: TokenProvider {
		let api: APIClient
		var pair: TokenPair?

		init(api: APIClient) { self.api = api }

		func validAccessToken() async throws -> String { try #require(pair).accessToken }

		func refreshAfterUnauthorized() async throws -> String {
			pair = try await api.refresh(refreshToken: try #require(pair).refreshToken)
			return pair!.accessToken
		}
	}

	@Test func loginSyncPushAndConflict() async throws {
		let env = ProcessInfo.processInfo.environment
		let api = APIClient(baseURL: URL(string: env["LG_API_URL"] ?? "http://localhost:3000/api/v1")!)
		let tokens = StaticTokens(api: api)
		api.tokenProvider = tokens
		tokens.pair = try await api.login(email: env["LG_EMAIL"] ?? "demo@linstant.fr",
		                                  password: env["LG_PASSWORD"] ?? "demo1234", deviceName: "tests")
		// Rotation: the new pair works.
		_ = try await tokens.refreshAfterUnauthorized()

		let container = try Persistence.makeContainer(inMemory: true)
		let engine = SyncEngine(context: container.mainContext, api: api)
		engine.canSync = { false }
		let store = LocalStore(context: container.mainContext, engine: engine)

		try await engine.pull()

		// Create a product offline, push it.
		var draft = ProductDraft()
		draft.productName = "Test iOS \(UUID().uuidString.prefix(6))"
		draft.quantity = 3
		let product = store.save(draft, editing: nil)
		try await engine.push()
		#expect(product.version == 1)
		#expect(product.syncState == .synced)

		// Someone else (the web) bumps it, then the iPhone edits its stale copy: 409.
		_ = try await api.putProduct(id: product.id, input: ProductInput(baseVersion: 1, productName: product.productName,
		                                                                   quantity: 10, expirationDate: nil))
		draft.quantity = 5
		store.save(draft, editing: product)
		try await engine.push()
		let mutation = try #require(engine.outbox.mutation(for: product.id))
		#expect(mutation.status == .conflict)
		#expect(SnapshotHeader.decode(mutation.serverSnapshot)?.version == 2)

		// Keep mine, push again: accepted on top of version 2.
		engine.keepMine(mutation)
		try await engine.push()
		#expect(product.version == 3)
		#expect(product.quantity == 5)

		// A sale with lines, then its deletion.
		var sale = SaleDraft.sample(client: "Test iOS", total: "42.50")
		sale.deliveryDatetime = .now
		let created = store.save(sale, editing: nil)
		try await engine.push()
		#expect(created.version == 1)
		#expect(created.remaining == 30)

		store.delete(created)
		store.delete(product)
		try await engine.push()
		try await engine.pull()
		#expect(container.mainContext.sale(id: created.id) == nil)
		#expect(engine.outbox.pending().isEmpty)
		#expect(engine.outbox.issues().isEmpty)
	}
}
