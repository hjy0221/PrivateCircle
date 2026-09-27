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
    @Published private(set) var pendingVerificationEmail: String?

    private var authListener: AuthStateDidChangeListenerHandle?

    init() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            let user = firebaseUser.flatMap { firebaseUser -> AppUser? in
                guard firebaseUser.isEmailVerified else { return nil }
                return AppUser(
                    id: firebaseUser.uid,
                    email: firebaseUser.email ?? "",
                    displayName: firebaseUser.displayName ?? firebaseUser.email ?? "친구"
                )
            }
            let unverifiedEmail = firebaseUser.flatMap { $0.isEmailVerified ? nil : $0.email }
            Task { @MainActor [weak self] in
                self?.user = user
                if let unverifiedEmail {
                    self?.pendingVerificationEmail = unverifiedEmail
                } else if user != nil {
                    self?.pendingVerificationEmail = nil
                }
                self?.isLoading = false
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email.lowercased(), password: password)
        guard result.user.isEmailVerified else {
            pendingVerificationEmail = result.user.email
            throw SessionStoreError.emailNotVerified
        }
        pendingVerificationEmail = nil
    }

    func createAccount(name: String, email: String, password: String) async throws {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let result = try await Auth.auth().createUser(withEmail: normalizedEmail, password: password)
        let profile = result.user.createProfileChangeRequest()
        profile.displayName = name
        try await profile.commitChanges()

        try await Firestore.firestore().collection("users").document(result.user.uid).setData([
            "displayName": name,
            "email": normalizedEmail,
            "createdAt": FieldValue.serverTimestamp()
        ])
        try await result.user.sendEmailVerification()
        pendingVerificationEmail = normalizedEmail
        user = nil
    }

    func resendVerificationEmail() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw SessionStoreError.signInAgain
        }
        try await currentUser.sendEmailVerification()
        pendingVerificationEmail = currentUser.email
    }

    func refreshVerificationStatus() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw SessionStoreError.signInAgain
        }
        try await currentUser.reload()
        guard currentUser.isEmailVerified else {
            throw SessionStoreError.emailNotVerified
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            currentUser.getIDTokenForcingRefresh(true) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        user = AppUser(
            id: currentUser.uid,
            email: currentUser.email ?? "",
            displayName: currentUser.displayName ?? currentUser.email ?? "친구"
        )
        pendingVerificationEmail = nil
    }

    func signOut() {
        try? Auth.auth().signOut()
        user = nil
        pendingVerificationEmail = nil
    }
}

private enum SessionStoreError: LocalizedError {
    case emailNotVerified
    case signInAgain

    var errorDescription: String? {
        switch self {
        case .emailNotVerified:
            "이메일 인증을 마친 뒤 ‘인증 확인’을 눌러 주세요."
        case .signInAgain:
            "로그인한 뒤 인증 메일을 다시 요청해 주세요."
        }
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
    @State private var noticeMessage: String?

    private var canSubmit: Bool {
        let passwordIsValid = password.count >= 6
        let confirmationIsValid = !isCreatingAccount || password == passwordConfirmation
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameIsValid = !isCreatingAccount || (!name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 80)
        return normalizedEmail.contains("@")
            && passwordIsValid
            && confirmationIsValid
            && nameIsValid
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

                if let email = session.pendingVerificationEmail {
                    Section("이메일 인증") {
                        Text("\(email)로 보낸 인증 링크를 누른 뒤 확인해 주세요. 인증 전에는 그룹과 초대 기능을 사용할 수 없습니다.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button("인증 메일 다시 보내기", systemImage: "envelope") {
                            resendVerificationEmail()
                        }
                        .disabled(isWorking)

                        Button("인증 확인", systemImage: "checkmark.circle") {
                            refreshVerificationStatus()
                        }
                        .disabled(isWorking)
                    }
                }

                if let noticeMessage {
                    Section {
                        Label(noticeMessage, systemImage: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                }

                if isCreatingAccount && password.count > 0 && password.count < 6 {
                    Section {
                        Label("비밀번호는 6자 이상 입력해 주세요.", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if isCreatingAccount && name.count > 80 {
                    Section {
                        Label("이름은 80자까지 입력할 수 있어요.", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.red)
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
        noticeMessage = nil
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

    private func resendVerificationEmail() {
        isWorking = true
        errorMessage = nil
        noticeMessage = nil

        Task {
            defer { isWorking = false }
            do {
                try await session.resendVerificationEmail()
                noticeMessage = "인증 메일을 보냈어요. 받은 편지함을 확인해 주세요."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func refreshVerificationStatus() {
        isWorking = true
        errorMessage = nil
        noticeMessage = nil

        Task {
            defer { isWorking = false }
            do {
                try await session.refreshVerificationStatus()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
