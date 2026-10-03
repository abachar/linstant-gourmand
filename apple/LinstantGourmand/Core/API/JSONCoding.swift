import Foundation

/// ISO 8601 UTC dates with milliseconds ("2026-10-03T10:00:00.000Z"), tolerant of a missing fraction on input.
nonisolated enum JSONCoding {
	static func makeDecoder() -> JSONDecoder {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .custom { decoder in
			let container = try decoder.singleValueContainer()
			let string = try container.decode(String.self)
			if let date = parseDate(string) { return date }
			throw DecodingError.dataCorruptedError(in: container, debugDescription: "Date invalide: \(string)")
		}
		return decoder
	}

	static func makeEncoder() -> JSONEncoder {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .custom { date, encoder in
			var container = encoder.singleValueContainer()
			try container.encode(formatDate(date))
		}
		encoder.outputFormatting = [.sortedKeys]
		return encoder
	}

	static func parseDate(_ string: String) -> Date? {
		(try? Date(string, strategy: withFraction)) ?? (try? Date(string, strategy: withoutFraction))
	}

	static func formatDate(_ date: Date) -> String {
		date.formatted(withFraction)
	}

	private static let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .gmt)
	private static let withoutFraction = Date.ISO8601FormatStyle(timeZone: .gmt)
}
