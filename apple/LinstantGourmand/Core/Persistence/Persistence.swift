import Foundation
import SwiftData

enum Persistence {
	static let schema = Schema([
		Sale.self,
		Purchase.self,
		Product.self,
		PendingMutation.self,
		SyncMeta.self,
		CachedReport.self,
	])

	/// The on-disk store lives in its own directory protected with `FileProtectionType.complete`:
	/// encrypted and unreadable while the iPhone is locked (files created inside inherit the class).
	static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
		if inMemory {
			return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
		}

		let directory = URL.applicationSupportDirectory.appending(path: "Store", directoryHint: .isDirectory)
		let fileManager = FileManager.default
		try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
		try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)

		let configuration = ModelConfiguration(schema: schema, url: directory.appending(path: "LinstantGourmand.store"))
		let container = try ModelContainer(for: schema, configurations: configuration)

		for file in (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? [] {
			try? fileManager.setAttributes(
				[.protectionKey: FileProtectionType.complete],
				ofItemAtPath: directory.appending(path: file).path
			)
		}
		return container
	}
}

extension ModelContext {
	func sale(id: UUID) -> Sale? {
		try? fetch(FetchDescriptor<Sale>(predicate: #Predicate { $0.id == id })).first
	}

	func purchase(id: UUID) -> Purchase? {
		try? fetch(FetchDescriptor<Purchase>(predicate: #Predicate { $0.id == id })).first
	}

	func product(id: UUID) -> Product? {
		try? fetch(FetchDescriptor<Product>(predicate: #Predicate { $0.id == id })).first
	}

	func syncMeta() -> SyncMeta {
		if let meta = try? fetch(FetchDescriptor<SyncMeta>()).first { return meta }
		let meta = SyncMeta()
		insert(meta)
		return meta
	}

	func cachedReport<T: Decodable>(_ type: T.Type, key: String) -> (value: T, fetchedAt: Date)? {
		guard let report = try? fetch(FetchDescriptor<CachedReport>(predicate: #Predicate { $0.key == key })).first,
		      let value = try? JSONCoding.makeDecoder().decode(T.self, from: report.data)
		else { return nil }
		return (value, report.fetchedAt)
	}

	func storeReport<T: Encodable>(_ value: T, key: String) {
		guard let data = try? JSONCoding.makeEncoder().encode(value) else { return }
		if let report = try? fetch(FetchDescriptor<CachedReport>(predicate: #Predicate { $0.key == key })).first {
			report.data = data
			report.fetchedAt = .now
		} else {
			insert(CachedReport(key: key, data: data))
		}
		try? save()
	}
}
