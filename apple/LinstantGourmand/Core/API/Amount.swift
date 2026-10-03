import Foundation

/// A money amount. The API exchanges amounts as two-decimal strings ("125.50") and also accepts numbers,
/// so decoding tolerates both while encoding always produces the string form.
nonisolated struct Amount: Codable, Hashable, Comparable, Sendable {
	var value: Decimal

	static let zero = Amount(0)

	init(_ value: Decimal) {
		self.value = value
	}

	init?(string: String) {
		let normalized = string.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
		guard !normalized.isEmpty, let value = Decimal(string: normalized, locale: Self.posix) else { return nil }
		self.value = value
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		if let string = try? container.decode(String.self) {
			guard let amount = Amount(string: string) else {
				throw DecodingError.dataCorruptedError(in: container, debugDescription: "Montant invalide: \(string)")
			}
			self = amount
		} else {
			self.value = try container.decode(Decimal.self)
		}
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(string)
	}

	/// "125.50": the wire format, always two decimals, dot separator.
	var string: String {
		rounded.value.formatted(.number.precision(.fractionLength(2)).grouping(.never).locale(Self.posix))
	}

	/// Rounded half-up to the cent.
	var rounded: Amount {
		var input = value
		var result = Decimal()
		NSDecimalRound(&result, &input, 2, .plain)
		return Amount(result)
	}

	/// "125,50 €"
	var formatted: String {
		value.formatted(.currency(code: "EUR").locale(Locale(identifier: "fr_FR")))
	}

	static func < (lhs: Amount, rhs: Amount) -> Bool { lhs.value < rhs.value }
	static func + (lhs: Amount, rhs: Amount) -> Amount { Amount(lhs.value + rhs.value) }
	static func - (lhs: Amount, rhs: Amount) -> Amount { Amount(lhs.value - rhs.value) }

	private static let posix = Locale(identifier: "en_US_POSIX")
}

extension Decimal {
	var euros: String {
		formatted(.currency(code: "EUR").locale(Locale(identifier: "fr_FR")))
	}
}
