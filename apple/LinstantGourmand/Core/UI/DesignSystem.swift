import SwiftUI

struct SectionTitle: View {
	let title: String
	var badge: String?

	var body: some View {
		HStack(spacing: Spacing.s) {
			Text(title).font(.blockTitle)
			if let badge {
				Text(badge)
					.font(.caption.weight(.semibold))
					.foregroundStyle(Theme.accent)
					.padding(.horizontal, Spacing.s)
					.padding(.vertical, 2)
					.background(Theme.tint(Theme.accent), in: .capsule)
			}
		}
		.accessibilityElement(children: .combine)
		.accessibilityAddTraits(.isHeader)
	}
}

struct AmountTile: View {
	enum Style {
		case neutral, accent, info, success

		var color: Color {
			switch self {
			case .neutral: Theme.textMuted
			case .accent: Theme.accent
			case .info: Theme.info
			case .success: Theme.success
			}
		}
	}

	let label: String
	let amount: Decimal
	var caption: String?
	var style: Style = .neutral
	var large = false

	var body: some View {
		VStack(spacing: 2) {
			Text(label).overline(style.color)
			Text(amount.euros)
				.font(large ? .title3.bold() : .subheadline.bold())
				.monospacedDigit()
				.foregroundStyle(style == .neutral ? Color.primary : style.color)
			if let caption {
				Text(caption).font(.caption2).foregroundStyle(Theme.textMuted)
			}
		}
		.lineLimit(1)
		.minimumScaleFactor(0.7)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.padding(10)
		.background(
			style == .neutral ? AnyShapeStyle(Theme.surfaceMuted) : AnyShapeStyle(Theme.tint(style.color)),
			in: .rect(cornerRadius: Radius.tile, style: .continuous)
		)
		.accessibilityElement(children: .combine)
	}
}

struct PaymentTiles: View {
	let deposit: Decimal
	let depositMethod: String
	let remaining: Decimal
	let remainingMethod: String
	let total: Decimal
	var large = false

	var body: some View {
		HStack(spacing: Spacing.s) {
			AmountTile(label: "Acompte", amount: deposit, caption: PaymentMethod.label(for: depositMethod), style: .neutral, large: large)
			AmountTile(label: "Reste", amount: remaining, caption: PaymentMethod.label(for: remainingMethod), style: .accent, large: large)
			AmountTile(label: "Total", amount: total, style: .neutral, large: large)
				.overlay {
					RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
						.strokeBorder(Theme.accent.opacity(0.25), lineWidth: 1)
				}
		}
		.fixedSize(horizontal: false, vertical: true)
	}
}

struct StatusPill: View {
	let text: String
	let color: Color
	var showsDot = true

	var body: some View {
		HStack(spacing: 6) {
			if showsDot { Circle().fill(color).frame(width: 8, height: 8) }
			Text(text).font(.caption2.weight(.bold)).textCase(.uppercase)
		}
		.foregroundStyle(color)
		.padding(.horizontal, 10)
		.padding(.vertical, 5)
		.background(Theme.tint(color), in: .capsule)
		.accessibilityElement(children: .combine)
	}
}

struct EmptyState: View {
	let systemImage: String
	let title: String
	var message: String?
	var actionTitle: String?
	var action: (() -> Void)?

	var body: some View {
		VStack(spacing: Spacing.m) {
			Image(systemName: systemImage)
				.font(.title2)
				.foregroundStyle(Theme.accent)
				.frame(width: 64, height: 64)
				.background(Theme.tint(Theme.accent), in: .circle)
				.accessibilityHidden(true)
			Text(title).font(.headline)
			if let message {
				Text(message)
					.font(.subheadline)
					.foregroundStyle(Theme.textMuted)
					.multilineTextAlignment(.center)
			}
			if let actionTitle, let action {
				Button(actionTitle, action: action)
					.buttonStyle(.borderedProminent)
					.controlSize(.large)
			}
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 32)
	}
}

struct FilterChips<Value: Hashable>: View {
	let values: [Value]
	@Binding var selection: Value
	let label: (Value) -> String

	var body: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: Spacing.s) {
				ForEach(values, id: \.self) { value in
					let isSelected = value == selection
					Button {
						selection = value
					} label: {
						Text(label(value))
							.font(.subheadline.weight(.semibold))
							.foregroundStyle(isSelected ? Color.white : Color.primary)
							.padding(.horizontal, 16)
							.padding(.vertical, 8)
							.background(isSelected ? Theme.accent : Theme.surface, in: .capsule)
							.overlay {
								if !isSelected { Capsule().strokeBorder(Theme.border, lineWidth: 1) }
							}
							.frame(minHeight: 44)
							.contentShape(.rect)
					}
					.buttonStyle(.plain)
					.accessibilityAddTraits(isSelected ? .isSelected : [])
				}
			}
		}
		.scrollClipDisabled()
		.fixedSize(horizontal: false, vertical: true)
	}
}

struct InfoBanner: View {
	enum Kind {
		case offline, warning, error, info

		var color: Color {
			switch self {
			case .offline: Theme.textMuted
			case .warning: Theme.warning
			case .error: Theme.danger
			case .info: Theme.info
			}
		}

		var symbol: String {
			switch self {
			case .offline: "wifi.slash"
			case .warning: "exclamationmark.triangle.fill"
			case .error: "xmark.circle.fill"
			case .info: "info.circle"
			}
		}
	}

	let kind: Kind
	let text: String
	var systemImage: String?

	var body: some View {
		Label(text, systemImage: systemImage ?? kind.symbol)
			.font(.footnote)
			.foregroundStyle(kind.color)
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(Spacing.m)
			.background(Theme.tint(kind.color), in: .rect(cornerRadius: Radius.tile, style: .continuous))
			.accessibilityElement(children: .combine)
	}
}

struct BrandAvatar: View {
	let size: CGFloat

	var body: some View {
		Image("Avatar")
			.resizable()
			.scaledToFill()
			.frame(width: size, height: size)
			.clipShape(.circle)
			.overlay { Circle().strokeBorder(Theme.accent, lineWidth: 2) }
			.accessibilityHidden(true)
	}
}

/// Skeleton shown while a report loads for the first time.
struct LoadingCards: View {
	var count = 4

	var body: some View {
		LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.m), GridItem(.flexible(), spacing: Spacing.m)], spacing: Spacing.m) {
			ForEach(0..<count, id: \.self) { _ in
				VStack(alignment: .leading, spacing: Spacing.s) {
					Text("Chargement").font(.caption2)
					Text("0000,00 €").font(.statValue)
					Text("Année : 0000,00 €").font(.caption)
				}
				.redacted(reason: .placeholder)
				.card()
			}
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel("Chargement")
	}
}
