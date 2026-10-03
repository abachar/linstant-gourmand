import SwiftUI

struct LoginView: View {
	@Environment(AppServices.self) private var services
	@State private var email = ""
	@State private var password = ""
	@State private var isSubmitting = false
	@State private var error: String?
	@FocusState private var focus: Field?

	private enum Field { case email, password }

	var body: some View {
		NavigationStack {
			Form {
				Section {
					VStack(spacing: Spacing.m) {
						BrandAvatar(size: 80)
						Text("L'Instant Gourmand").font(.title2.bold())
						Text("Accédez à votre espace d'administration")
							.font(.subheadline)
							.foregroundStyle(Theme.accent)
							.multilineTextAlignment(.center)
					}
					.frame(maxWidth: .infinity)
					.padding(.vertical, Spacing.l)
					.listRowBackground(Color.clear)
				}

				Section {
					TextField("Email", text: $email)
						.textContentType(.username)
						.keyboardType(.emailAddress)
						.textInputAutocapitalization(.never)
						.autocorrectionDisabled()
						.focused($focus, equals: .email)
						.submitLabel(.next)
						.onSubmit { focus = .password }
					SecureField("Mot de passe", text: $password)
						.textContentType(.password)
						.focused($focus, equals: .password)
						.submitLabel(.go)
						.onSubmit(submit)
				} footer: {
					Text("Le mot de passe n'est demandé qu'une fois : ensuite, Face ID suffit.")
				}

				if let error {
					Section {
						InfoBanner(kind: .error, text: error)
							.listRowBackground(Color.clear)
							.listRowInsets(EdgeInsets())
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
					.buttonStyle(.glassProminent)
					.controlSize(.large)
					.disabled(email.isEmpty || password.isEmpty || isSubmitting)
					.listRowBackground(Color.clear)
					.listRowInsets(EdgeInsets())
				}
			}
			.screenBackground()
			.toolbar(.hidden, for: .navigationBar)
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
