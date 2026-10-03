import SwiftUI

/// Colors come from the asset catalog (light and dark variants); the accent is the app's AccentColor.
enum Theme {
	static let background = Color("LGBackground")
	static let surface = Color("LGSurface")
	static let surfaceMuted = Color("LGSurfaceMuted")
	static let border = Color("LGBorder")
	static let textMuted = Color("LGTextMuted")
	static let success = Color("LGSuccess")
	static let warning = Color("LGWarning")
	static let info = Color("LGInfo")
	static let accent = Color.accentColor
	static let danger = Color.accentColor

	/// The color at 12 % opacity in light mode and 20 % in dark mode, for tinted backgrounds.
	static func tint(_ color: Color) -> TintStyle {
		TintStyle(color: color)
	}
}

/// Resolved by SwiftUI (possibly off the main thread): no UIKit dynamic color provider.
nonisolated struct TintStyle: ShapeStyle {
	let color: Color

	func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
		color.opacity(environment.colorScheme == .dark ? 0.2 : 0.12)
	}
}

enum Spacing {
	static let xs: CGFloat = 4
	static let s: CGFloat = 8
	static let m: CGFloat = 12
	static let l: CGFloat = 16
	static let xl: CGFloat = 24
}

enum Radius {
	static let card: CGFloat = 16
	static let tile: CGFloat = 12
}

extension Font {
	static let amountHero = Font.title.weight(.heavy)
	static let amountCard = Font.title3.weight(.heavy)
	static let statValue = Font.title2.bold()
	static let cardTitle = Font.headline.weight(.bold)
	static let blockTitle = Font.title3.bold()
}

extension View {
	/// Page background for `List` and `Form`. Never put an opaque background under the bars.
	func screenBackground() -> some View {
		scrollContentBackground(.hidden).background(Theme.background)
	}

	/// Page background for a `ScrollView`.
	func scrollScreenBackground() -> some View {
		background(Theme.background)
	}

	/// Card for content outside a `List`.
	func card() -> some View {
		padding(Spacing.l)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(Theme.surface, in: .rect(cornerRadius: Radius.card, style: .continuous))
			.overlay {
				RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Theme.border, lineWidth: 1)
			}
	}

	/// A `List` row drawn as a rounded card; the list uses `.insetGrouped` and `.listRowSpacing(12)`.
	func cardRow() -> some View {
		listRowBackground(Theme.surface)
			.listRowSeparator(.hidden)
			.listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
	}

	/// Small uppercase caption above a value.
	func overline(_ color: Color = Theme.textMuted) -> some View {
		font(.caption2.weight(.bold))
			.textCase(.uppercase)
			.tracking(0.6)
			.foregroundStyle(color)
	}
}
