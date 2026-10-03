import SwiftUI

enum Formats {
	static let locale = Locale(identifier: "fr_FR")

	/// "ven. 3 oct. 2026 à 12:30"
	static func dateTime(_ date: Date) -> String {
		date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year().hour().minute().locale(locale))
	}

	/// "3 oct. 2026"
	static func date(_ date: Date) -> String {
		date.formatted(.dateTime.day().month(.abbreviated).year().locale(locale))
	}

	/// "octobre 2026"
	static func month(_ date: Date) -> String {
		date.formatted(.dateTime.month(.wide).year().locale(locale)).capitalized(with: locale)
	}

	static func relative(_ date: Date) -> String {
		date.formatted(.relative(presentation: .named).locale(locale))
	}
}

/// Small marker for entities not yet confirmed by the server.
struct SyncBadge: View {
	let state: SyncState

	var body: some View {
		switch state {
		case .synced:
			EmptyView()
		case .pending:
			Image(systemName: "arrow.triangle.2.circlepath")
				.foregroundStyle(.secondary)
				.accessibilityLabel("En attente de synchronisation")
		case .conflict:
			Image(systemName: "exclamationmark.triangle.fill")
				.foregroundStyle(.orange)
				.accessibilityLabel("Conflit à résoudre")
		case .rejected:
			Image(systemName: "xmark.octagon.fill")
				.foregroundStyle(.red)
				.accessibilityLabel("Refusé par le serveur")
		}
	}
}

/// Footer explaining why an online-only action is disabled.
struct OfflineNotice: View {
	var text = "Disponible uniquement en ligne."

	var body: some View {
		Label(text, systemImage: "wifi.slash")
			.font(.footnote)
			.foregroundStyle(.secondary)
	}
}

/// Label + value row used by the detail screens.
struct ValueRow: View {
	let label: String
	let value: String

	var body: some View {
		LabeledContent(label) {
			Text(value).multilineTextAlignment(.trailing)
		}
	}
}

/// Validation messages at the bottom of a form.
struct FormErrors: View {
	let errors: [String]

	var body: some View {
		if !errors.isEmpty {
			Section {
				ForEach(errors, id: \.self) { error in
					Label(error, systemImage: "exclamationmark.circle")
						.foregroundStyle(.red)
						.font(.footnote)
				}
			}
		}
	}
}

/// Amount text field with a decimal keyboard.
struct AmountField: View {
	let title: String
	@Binding var text: String

	var body: some View {
		LabeledContent(title) {
			HStack(spacing: 4) {
				TextField("0,00", text: $text)
					.keyboardType(.decimalPad)
					.multilineTextAlignment(.trailing)
				Text("€").foregroundStyle(.secondary)
			}
		}
	}
}

/// Opens a PDF of the sale (online only) in Quick Look, which offers sharing.
struct SalePDFButton: View {
	@Environment(AppServices.self) private var services
	let saleId: UUID
	let clientName: String
	let type: PrintType
	@Binding var previewURL: URL?
	@Binding var error: String?
	@State private var isLoading = false

	var body: some View {
		Button {
			Task { await load() }
		} label: {
			if isLoading {
				ProgressView()
			} else {
				Label(type.label, systemImage: "doc.richtext")
			}
		}
		.disabled(!services.isOnline || isLoading)
	}

	private func load() async {
		isLoading = true
		defer { isLoading = false }
		do {
			let data = try await services.api.salePDF(id: saleId, type: type)
			let name = "\(type.label)-\(clientName.replacingOccurrences(of: " ", with: "_")).pdf"
			let url = URL.temporaryDirectory.appending(path: name)
			try data.write(to: url, options: .completeFileProtection)
			previewURL = url
		} catch {
			self.error = error.localizedDescription
		}
	}
}
