import FirebaseAuth
import FirebaseFirestore
import SwiftUI

struct AppUser: Identifiable, Sendable {
    let id: String
    let email: String
    let displayName: String
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var user: AppUser?
    @Published private(set) var isLoading = true

    private var authListener: AuthStateDidChangeListenerHandle?

    init() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            let user = firebaseUser.map {
                AppUser(
                    id: $0.uid,
                    email: $0.email ?? "",
                    displayName: $0.displayName ?? $0.email ?? "친구"
                )
            }
            Task { @MainActor [weak self] in
                self?.user = user
                self?.isLoading = false
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email.lowercased(), password: password)
    }

    func createAccount(name: String, email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email.lowercased(), password: password)
        let profile = result.user.createProfileChangeRequest()
        profile.displayName = name
        try await profile.commitChanges()

        try await Firestore.firestore().collection("users").document(result.user.uid).setData([
            "displayName": name,
            "email": email.lowercased(),
            "createdAt": FieldValue.serverTimestamp()
        ])
        user = AppUser(id: result.user.uid, email: email.lowercased(), displayName: name)
    }

    func signOut() {
        try? Auth.auth().signOut()
    }
}

struct AuthView: View {
    @ObservedObject var session: SessionStore
    @State private var isCreatingAccount = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        let passwordIsValid = password.count >= 6
        let confirmationIsValid = !isCreatingAccount || password == passwordConfirmation
        return !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && passwordIsValid
            && confirmationIsValid
            && (!isCreatingAccount || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("계정", selection: $isCreatingAccount) {
                        Text("로그인").tag(false)
                        Text("회원가입").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                Section("계정 정보") {
                    if isCreatingAccount {
                        TextField("이름", text: $name)
                            .textContentType(.name)
                            .submitLabel(.next)
                    }

                    TextField("이메일", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.plain)

                    SecureField("비밀번호", text: $password)
                        .textContentType(isCreatingAccount ? .newPassword : .password)

                    if isCreatingAccount {
                        SecureField("비밀번호 확인", text: $passwordConfirmation)
                            .textContentType(.newPassword)
                    }
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        HStack {
                            Spacer()
                            if isWorking {
                                ProgressView()
                            } else {
                                Text(isCreatingAccount ? "계정 만들기" : "로그인")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSubmit || isWorking)
                }

                if isCreatingAccount && password.count > 0 && password.count < 6 {
                    Section {
                        Label("비밀번호는 6자 이상 입력해 주세요.", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if isCreatingAccount && !passwordConfirmation.isEmpty && password != passwordConfirmation {
                    Section {
                        Label("비밀번호가 서로 달라요.", systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("우리 사이")
            .alert("계속할 수 없어요", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("확인", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "잠시 후 다시 시도해 주세요.")
            }
        }
    }

    private func submit() {
        isWorking = true
        errorMessage = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            defer { isWorking = false }
            do {
                if isCreatingAccount {
                    try await session.createAccount(name: trimmedName, email: trimmedEmail, password: password)
                } else {
                    try await session.signIn(email: trimmedEmail, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
