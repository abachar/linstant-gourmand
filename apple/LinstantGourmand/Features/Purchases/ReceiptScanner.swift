import PhotosUI
import SwiftUI
import UIKit

/// "Scanner un ticket" in the purchase form: photo (camera or library) → server → prefilled draft. Online only.
struct ReceiptScanSection: View {
	@Binding var draft: PurchaseDraft

	@Environment(AppServices.self) private var services
	@State private var showsSourceChoice = false
	@State private var showsCamera = false
	@State private var showsLibrary = false
	@State private var libraryItem: PhotosPickerItem?
	@State private var isScanning = false
	@State private var warnings: [String] = []
	@State private var error: String?

	var body: some View {
		Section {
			Button {
				showsSourceChoice = true
			} label: {
				HStack {
					if isScanning {
						ProgressView()
						Text("Lecture du ticket…")
					} else {
						Label("Scanner un ticket", systemImage: "doc.viewfinder")
					}
				}
				.frame(maxWidth: .infinity)
			}
			.disabled(isScanning || !services.isOnline)
			ForEach(warnings, id: \.self) { InfoBanner(kind: .warning, text: $0) }
			if let error { InfoBanner(kind: .error, text: error) }
		} footer: {
			Text(services.isOnline ? "Date, montant et description sont proposés à partir de la photo, à vérifier avant d'enregistrer." : "Le scan nécessite une connexion.")
		}
		.listRowBackground(Color.clear)
		.listRowInsets(EdgeInsets())
		.confirmationDialog("Scanner un ticket", isPresented: $showsSourceChoice, titleVisibility: .hidden) {
			if UIImagePickerController.isSourceTypeAvailable(.camera) {
				Button("Prendre une photo") { showsCamera = true }
			}
			Button("Choisir dans la photothèque") { libraryItem = nil; showsLibrary = true }
		}
		.photosPicker(isPresented: $showsLibrary, selection: $libraryItem, matching: .images)
		.fullScreenCover(isPresented: $showsCamera) {
			CameraPicker { image in Task { await scan(image) } }
				.ignoresSafeArea()
		}
		.onChange(of: libraryItem) { _, item in
			guard let item else { return }
			Task {
				if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
					await scan(image)
				} else {
					error = "Photo illisible."
				}
			}
		}
	}

	private func scan(_ image: UIImage) async {
		guard let jpeg = image.receiptJPEG() else { return error = "Photo illisible." }
		isScanning = true
		error = nil
		warnings = []
		defer { isScanning = false }
		do {
			let scan = try await services.api.scanReceipt(image: jpeg)
			if let date = scan.date.flatMap(ReceiptScanDTO.parseDate) { draft.date = date }
			if let amount = scan.amount { draft.amount = amount.string }
			if let description = scan.description { draft.notes = description }
			warnings = scan.warnings
		} catch {
			self.error = error.localizedDescription
		}
	}
}

/// The system camera, full screen; calls back with the picture taken.
private struct CameraPicker: UIViewControllerRepresentable {
	let onPick: (UIImage) -> Void
	@Environment(\.dismiss) private var dismiss

	func makeUIViewController(context: Context) -> UIImagePickerController {
		let picker = UIImagePickerController()
		picker.sourceType = .camera
		picker.cameraCaptureMode = .photo
		picker.delegate = context.coordinator
		return picker
	}

	func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

	func makeCoordinator() -> Coordinator { Coordinator(self) }

	final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
		let parent: CameraPicker

		init(_ parent: CameraPicker) { self.parent = parent }

		func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
			parent.dismiss()
			if let image = info[.originalImage] as? UIImage { parent.onPick(image) }
		}

		func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
			parent.dismiss()
		}
	}
}

extension UIImage {
	/// Longest side of the photo sent to the server: enough to read a receipt, light enough for mobile data.
	private static let receiptMaxSide: CGFloat = 1600

	/// Downscaled, orientation applied, JPEG 80 %.
	func receiptJPEG() -> Data? {
		let scale = min(1, Self.receiptMaxSide / max(size.width, size.height))
		let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
		let format = UIGraphicsImageRendererFormat.default()
		format.scale = 1
		let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
			draw(in: CGRect(origin: .zero, size: target))
		}
		return rendered.jpegData(compressionQuality: 0.8)
	}
}
