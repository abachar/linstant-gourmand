import SwiftUI

struct LoginView: View {
	@Environment(AppServices.self) private var services
	@State private var email = ""
	@State private var password = ""
	@State private var isSubmitting = false
	@State private var error: String?

	var body: some View {
		NavigationStack {
			Form {
				Section {
					TextField("Email", text: $email)
						.textContentType(.username)
						.keyboardType(.emailAddress)
						.textInputAutocapitalization(.never)
						.autocorrectionDisabled()
					SecureField("Mot de passe", text: $password)
						.textContentType(.password)
						.onSubmit(submit)
				} footer: {
					Text("Le mot de passe n'est demandé qu'une fois : ensuite, Face ID suffit.")
				}

				if let error {
					Section {
						Label(error, systemImage: "exclamationmark.triangle.fill")
							.foregroundStyle(.red)
					}
				}

				Section {
					Button(action: submit) {
						if isSubmitting {
							ProgressView().frame(maxWidth: .infinity)
						} else {
							Text("Se connecter").frame(maxWidth: .infinity)
						}
					}
					.disabled(email.isEmpty || password.isEmpty || isSubmitting)
				}
			}
			.navigationTitle("Connexion")
		}
	}

	private func submit() {
		guard !email.isEmpty, !password.isEmpty, !isSubmitting else { return }
		isSubmitting = true
		error = nil
		Task {
			do {
				try await services.auth.login(email: email.trimmingCharacters(in: .whitespaces), password: password)
				password = ""
			} catch {
				self.error = error.localizedDescription
			}
			isSubmitting = false
		}
	}
}
