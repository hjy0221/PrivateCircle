import FirebaseFirestore
import SwiftUI

@MainActor
final class MeetupStore: ObservableObject {
    @Published private(set) var meetups: [Meetup] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    private let database = Firestore.firestore()
    private var userID: String?

    func load(userID: String) async {
        if self.userID != userID {
            meetups = []
            self.userID = userID
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await database.collection("users").document(userID)
                .collection("meetups").getDocuments()
            meetups = snapshot.documents.compactMap(Self.decode)
                .sorted { Self.sortDate(for: $0) < Self.sortDate(for: $1) }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create(
        title: String,
        participants: [Friend],
        candidateDates: [Date],
        location: String
    ) async throws {
        guard let userID else { throw MeetupStoreError.notSignedIn }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !participants.isEmpty, !candidateDates.isEmpty else {
            throw MeetupStoreError.incomplete
        }

        isWorking = true
        defer { isWorking = false }

        let meetupID = UUID()
        let participantData: [[String: Any]] = participants.map { friend in
            [
                "id": friend.id.uuidString,
                "name": friend.name,
                "initials": friend.initials,
                "profileColor": friend.profileColor.rawValue,
                "lastSharedContext": friend.lastSharedContext
            ]
        }
        var data: [String: Any] = [
            "title": cleanTitle,
            "participants": participantData,
            "candidateTimes": candidateDates.sorted().map { Timestamp(date: $0) },
            "status": "planning",
            "ownerUID": userID,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if !cleanLocation.isEmpty {
            data["location"] = cleanLocation
        }

        try await database.collection("users").document(userID)
            .collection("meetups").document(meetupID.uuidString)
            .setData(data)

        let meetup = Meetup(
            id: meetupID,
            title: cleanTitle,
            participants: participants,
            candidateTimes: candidateDates.sorted().map {
                MeetupTimeOption(id: UUID(), startsAt: $0, availableFriendIDs: [])
            },
            confirmedTime: nil,
            location: cleanLocation.isEmpty ? nil : cleanLocation,
            status: .planning,
            arrivalStates: [],
            moments: []
        )
        meetups.append(meetup)
        meetups.sort { Self.sortDate(for: $0) < Self.sortDate(for: $1) }
    }

    private static func decode(_ document: QueryDocumentSnapshot) -> Meetup? {
        let data = document.data()
        guard let id = UUID(uuidString: document.documentID),
              let title = data["title"] as? String,
              let participantData = data["participants"] as? [[String: Any]],
              let timestamps = data["candidateTimes"] as? [Timestamp] else {
            return nil
        }

        let participants = participantData.compactMap { item -> Friend? in
            guard let rawID = item["id"] as? String,
                  let id = UUID(uuidString: rawID),
                  let name = item["name"] as? String else { return nil }
            return Friend(
                id: id,
                name: name,
                initials: item["initials"] as? String ?? String(name.prefix(1)),
                profileColor: ProfileColor(rawValue: item["profileColor"] as? String ?? "blue") ?? .blue,
                lastSharedContext: item["lastSharedContext"] as? String ?? "함께할 친구"
            )
        }
        guard !participants.isEmpty else { return nil }

        return Meetup(
            id: id,
            title: title,
            participants: participants,
            candidateTimes: timestamps.map {
                MeetupTimeOption(id: UUID(), startsAt: $0.dateValue(), availableFriendIDs: [])
            },
            confirmedTime: nil,
            location: data["location"] as? String,
            status: .planning,
            arrivalStates: [],
            moments: []
        )
    }

    private static func sortDate(for meetup: Meetup) -> Date {
        meetup.confirmedTime ?? meetup.candidateTimes.map(\.startsAt).min() ?? .distantFuture
    }
}

private enum MeetupStoreError: LocalizedError {
    case notSignedIn
    case incomplete

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            "로그인한 뒤 모임을 만들 수 있어요."
        case .incomplete:
            "모임 이름, 친구, 후보 시간을 확인해 주세요."
        }
    }
}

struct MeetupsView: View {
    let meetups: [Meetup]
    @ObservedObject var store: MeetupStore
    let allowsCreation: Bool

    @State private var showingCreateSheet = false

    init(
        meetups: [Meetup],
        store: MeetupStore,
        allowsCreation: Bool,
        initiallyShowingCreateSheet: Bool = false
    ) {
        self.meetups = meetups
        self.store = store
        self.allowsCreation = allowsCreation
        _showingCreateSheet = State(initialValue: initiallyShowingCreateSheet)
    }

    var body: some View {
        List {
            if meetups.isEmpty {
                if store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ContentUnavailableView(
                        "아직 모임이 없어요",
                        systemImage: "calendar",
                        description: Text("친구들과 만날 약속을 만들어 보세요.")
                    )
                }
            } else {
                ForEach(meetups) { meetup in
                    MeetupRow(meetup: meetup)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("모임")
        .toolbar {
            if allowsCreation {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("모임 만들기")
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateMeetupSheet(
                store: store,
                screenshotPreview: ProcessInfo.processInfo.arguments.contains("--screenshot-meetup-create")
            )
        }
        .alert("모임을 처리할 수 없어요", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "잠시 후 다시 시도해 주세요.")
        }
    }
}

private struct CreateMeetupSheet: View {
    @ObservedObject var store: MeetupStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var location = ""
    @State private var selectedFriendIDs = Set<UUID>()
    @State private var candidateDates: [Date] = []
    @State private var candidateDate: Date = {
        Calendar.current.nextDate(
            after: .now,
            matching: DateComponents(hour: 18, minute: 30),
            matchingPolicy: .nextTime
        ) ?? .now.addingTimeInterval(60 * 60)
    }()

    init(store: MeetupStore, screenshotPreview: Bool) {
        self.store = store
        if screenshotPreview, let sample = MockData.meetups.first {
            _title = State(initialValue: "토요일 저녁 식사")
            _location = State(initialValue: "성수동")
            _selectedFriendIDs = State(initialValue: Set(sample.participants.map(\.id)))
            let candidate = sample.candidateTimes.first?.startsAt ?? .now.addingTimeInterval(60 * 60)
            _candidateDates = State(initialValue: [candidate])
            _candidateDate = State(initialValue: candidate)
        }
    }

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !selectedFriendIDs.isEmpty
            && !candidateDates.isEmpty
            && !store.isWorking
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("모임") {
                    TextField("예: 토요일 저녁", text: $title)
                        .textInputAutocapitalization(.sentences)
                    TextField("장소 (선택)", text: $location)
                }

                Section {
                    ForEach(MockData.friends) { friend in
                        friendSelectionRow(friend)
                    }
                } header: {
                    Text("함께할 친구")
                } footer: {
                    Text("현재 친구 목록은 화면 확인용 샘플입니다. 선택한 친구에게 초대가 전송되지는 않으며, 모임은 내 계정에만 저장됩니다.")
                }

                Section {
                    DatePicker(
                        "후보 시간",
                        selection: $candidateDate,
                        in: Date.now...,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    Button(action: addCandidateDate) {
                        Label("이 시간 후보 추가", systemImage: "plus")
                    }
                    .disabled(candidateDates.count >= 8)

                    if candidateDates.isEmpty {
                        Text("친구들과 맞춰 볼 시간을 추가해 주세요.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(candidateDates, id: \.self) { date in
                            HStack {
                                Text(date.formatted(date: .abbreviated, time: .shortened))
                                Spacer()
                                Button {
                                    candidateDates.removeAll { $0 == date }
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("후보 시간 삭제")
                            }
                        }
                    }
                } header: {
                    Text("일정 후보")
                } footer: {
                    Text("최대 8개까지 추가할 수 있어요. 실제 공통 시간 투표는 다음 단계에서 연결됩니다.")
                }
            }
            .navigationTitle("새 모임")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("만들기") { createMeetup() }
                        .disabled(!canCreate)
                }
            }
            .disabled(store.isWorking)
            .overlay {
                if store.isWorking {
                    ProgressView("저장 중")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func friendSelectionRow(_ friend: Friend) -> some View {
        let isSelected = selectedFriendIDs.contains(friend.id)
        return Button {
            if isSelected {
                selectedFriendIDs.remove(friend.id)
            } else {
                selectedFriendIDs.insert(friend.id)
            }
        } label: {
            HStack(spacing: 12) {
                InitialsAvatar(friend: friend)
                Text(friend.name)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func addCandidateDate() {
        let roundedDate = Calendar.current.dateInterval(of: .minute, for: candidateDate)?.start ?? candidateDate
        guard !candidateDates.contains(where: { abs($0.timeIntervalSince(roundedDate)) < 60 }) else { return }
        candidateDates.append(roundedDate)
        candidateDates.sort()
    }

    private func createMeetup() {
        let participants = MockData.friends.filter { selectedFriendIDs.contains($0.id) }
        Task {
            do {
                try await store.create(
                    title: title,
                    participants: participants,
                    candidateDates: candidateDates,
                    location: location
                )
                dismiss()
            } catch {
                store.errorMessage = error.localizedDescription
            }
        }
    }
}
