import FirebaseFirestore
import SwiftUI

struct CircleGroup: Identifiable, Hashable {
    let id: String
    let name: String
}

struct GroupInvitation: Identifiable {
    let id: String
    let groupID: String
    let groupName: String
    let inviterName: String
}

struct GroupMember: Identifiable {
    let id: String
    let displayName: String
    let role: String
}

@MainActor
final class GroupsStore: ObservableObject {
    @Published private(set) var groups: [CircleGroup] = []
    @Published private(set) var invitations: [GroupInvitation] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    let user: AppUser
    private let database = Firestore.firestore()

    init(user: AppUser) {
        self.user = user
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let membershipSnapshot = try await database.collection("users").document(user.id)
                .collection("groups").getDocuments()
            let invitationSnapshot = try await database.collection("groupInvites")
                .whereField("inviteeEmail", isEqualTo: user.email.lowercased())
                .whereField("status", isEqualTo: "pending")
                .getDocuments()
            groups = membershipSnapshot.documents.compactMap { document in
                guard let name = document.data()["name"] as? String else { return nil }
                return CircleGroup(id: document.documentID, name: name)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

            invitations = invitationSnapshot.documents.compactMap { document in
                let data = document.data()
                guard let groupID = data["groupID"] as? String,
                      let groupName = data["groupName"] as? String,
                      let inviterName = data["inviterName"] as? String else { return nil }
                return GroupInvitation(
                    id: document.documentID,
                    groupID: groupID,
                    groupName: groupName,
                    inviterName: inviterName
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createGroup(named name: String) async throws {
        let groupName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !groupName.isEmpty else { return }

        isWorking = true
        defer { isWorking = false }

        let groupReference = database.collection("groups").document()
        let memberReference = groupReference.collection("members").document(user.id)
        let membershipReference = database.collection("users").document(user.id)
            .collection("groups").document(groupReference.documentID)
        let batch = database.batch()

        batch.setData([
            "name": groupName,
            "createdBy": user.id,
            "createdAt": FieldValue.serverTimestamp()
        ], forDocument: groupReference)
        batch.setData([
            "displayName": user.displayName,
            "role": "owner",
            "joinedAt": FieldValue.serverTimestamp()
        ], forDocument: memberReference)
        batch.setData([
            "groupID": groupReference.documentID,
            "name": groupName,
            "createdAt": FieldValue.serverTimestamp()
        ], forDocument: membershipReference)

        try await batch.commit()
        await reload()
    }

    func invite(email: String, to group: CircleGroup) async throws {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedEmail.contains("@"), normalizedEmail != user.email.lowercased() else {
            throw GroupActionError.invalidEmail
        }

        isWorking = true
        defer { isWorking = false }

        try await database.collection("groupInvites").addDocument(data: [
            "groupID": group.id,
            "groupName": group.name,
            "inviteeEmail": normalizedEmail,
            "invitedByUID": user.id,
            "inviterName": user.displayName,
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func accept(_ invitation: GroupInvitation) async throws {
        isWorking = true
        defer { isWorking = false }

        let inviteReference = database.collection("groupInvites").document(invitation.id)
        let memberReference = database.collection("groups").document(invitation.groupID)
            .collection("members").document(user.id)
        let membershipReference = database.collection("users").document(user.id)
            .collection("groups").document(invitation.groupID)
        let batch = database.batch()

        batch.updateData([
            "status": "accepted",
            "acceptedByUID": user.id,
            "acceptedAt": FieldValue.serverTimestamp()
        ], forDocument: inviteReference)
        batch.setData([
            "displayName": user.displayName,
            "role": "member",
            "joinedAt": FieldValue.serverTimestamp(),
            "inviteId": invitation.id
        ], forDocument: memberReference)
        batch.setData([
            "groupID": invitation.groupID,
            "name": invitation.groupName,
            "createdAt": FieldValue.serverTimestamp()
        ], forDocument: membershipReference)

        try await batch.commit()
        await reload()
    }

    func members(of group: CircleGroup) async throws -> [GroupMember] {
        let snapshot = try await database.collection("groups").document(group.id)
            .collection("members").getDocuments()
        return snapshot.documents.compactMap { document in
            let data = document.data()
            guard let displayName = data["displayName"] as? String,
                  let role = data["role"] as? String else { return nil }
            return GroupMember(id: document.documentID, displayName: displayName, role: role)
        }
        .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
}

private enum GroupActionError: LocalizedError {
    case invalidEmail

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            "본인과 다른 유효한 이메일 주소를 입력해 주세요."
        }
    }
}

struct GroupsView: View {
    let user: AppUser
    @StateObject private var store: GroupsStore
    @State private var showingCreateSheet = false

    init(user: AppUser) {
        self.user = user
        _store = StateObject(wrappedValue: GroupsStore(user: user))
    }

    var body: some View {
        List {
            if !store.invitations.isEmpty {
                Section("받은 초대") {
                    ForEach(store.invitations) { invitation in
                        InvitationRow(invitation: invitation, store: store)
                    }
                }
            }

            Section("내 그룹") {
                if store.isLoading && store.groups.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if store.groups.isEmpty {
                    ContentUnavailableView(
                        "아직 그룹이 없어요",
                        systemImage: "person.3",
                        description: Text("친구들과 함께할 그룹을 만들어 보세요.")
                    )
                } else {
                    ForEach(store.groups) { group in
                        NavigationLink {
                            GroupDetailView(group: group, store: store)
                        } label: {
                            GroupRow(group: group)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("그룹")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("그룹 만들기")
            }
        }
        .task { await store.reload() }
        .refreshable { await store.reload() }
        .sheet(isPresented: $showingCreateSheet) {
            CreateGroupSheet(store: store)
        }
        .alert("그룹을 불러올 수 없어요", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "잠시 후 다시 시도해 주세요.")
        }
    }
}

private struct GroupRow: View {
    let group: CircleGroup

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(.headline)
                Text("친구들과 함께하는 공간")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct InvitationRow: View {
    let invitation: GroupInvitation
    @ObservedObject var store: GroupsStore

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(invitation.groupName)
                    .font(.headline)
                Text("\(invitation.inviterName)님의 초대")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button("수락") {
                Task {
                    do {
                        try await store.accept(invitation)
                    } catch {
                        store.errorMessage = error.localizedDescription
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isWorking)
        }
        .padding(.vertical, 4)
    }
}

private struct CreateGroupSheet: View {
    @ObservedObject var store: GroupsStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("그룹 이름") {
                    TextField("예: 대학 친구들", text: $name)
                        .textInputAutocapitalization(.never)
                    if name.count > 50 {
                        Text("그룹 이름은 50자까지 입력할 수 있어요.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Text("그룹을 만든 뒤 이메일로 친구를 초대할 수 있어요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("새 그룹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("만들기") {
                        Task {
                            do {
                                try await store.createGroup(named: name)
                                dismiss()
                            } catch {
                                store.errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || name.count > 50
                            || store.isWorking
                    )
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct GroupDetailView: View {
    let group: CircleGroup
    @ObservedObject var store: GroupsStore
    @State private var members: [GroupMember] = []
    @State private var isLoading = true
    @State private var showingInviteSheet = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                ForEach(members) { member in
                    HStack(spacing: 12) {
                        Image(systemName: member.role == "owner" ? "person.crop.circle.fill.badge.checkmark" : "person.crop.circle")
                            .foregroundStyle(member.role == "owner" ? Color.accentColor : Color.secondary)
                            .font(.title3)
                        Text(member.displayName)
                        if member.role == "owner" {
                            Text("방장")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if isLoading && members.isEmpty {
                    ProgressView()
                }
            } header: {
                Text("멤버 \(members.count)명")
            }

            Section {
                Button {
                    showingInviteSheet = true
                } label: {
                    Label("이메일로 친구 초대", systemImage: "person.badge.plus")
                }
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadMembers() }
        .refreshable { await loadMembers() }
        .sheet(isPresented: $showingInviteSheet, onDismiss: {
            Task { await loadMembers() }
        }) {
            InviteMemberSheet(group: group, store: store)
        }
        .alert("그룹을 불러올 수 없어요", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "잠시 후 다시 시도해 주세요.")
        }
    }

    private func loadMembers() async {
        isLoading = true
        defer { isLoading = false }
        do {
            members = try await store.members(of: group)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct InviteMemberSheet: View {
    let group: CircleGroup
    @ObservedObject var store: GroupsStore
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var errorMessage: String?
    @State private var sent = false

    var body: some View {
        NavigationStack {
            Form {
                Section("초대할 친구") {
                    TextField("이메일 주소", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    Text("친구가 이 이메일로 가입하고 초대를 수락하면 그룹에 참여해요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("친구 초대")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(sent ? "완료" : "초대 보내기") {
                        if sent {
                            dismiss()
                            return
                        }
                        Task {
                            do {
                                try await store.invite(email: email, to: group)
                                sent = true
                                errorMessage = nil
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isWorking)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
