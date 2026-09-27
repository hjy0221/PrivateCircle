import FirebaseFirestore
import SwiftUI

@MainActor
final class MeetupStore: ObservableObject {
    @Published private(set) var meetups: [Meetup] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isWorking = false
    @Published private(set) var loadErrorMessage: String?
    @Published var errorMessage: String?

    private let database = Firestore.firestore()
    private var userID: String?
    private var loadRevision = 0

    init(userID: String? = nil) {
        self.userID = userID
    }

    func load(userID: String) async {
        loadRevision += 1
        let revision = loadRevision
        if self.userID != userID {
            meetups = []
            self.userID = userID
        }

        isLoading = true
        loadErrorMessage = nil
        defer {
            if loadRevision == revision {
                isLoading = false
            }
        }

        do {
            let personalSnapshot = try await database.collection("users").document(userID)
                .collection("meetups").getDocuments()
            let memberships = try await database.collection("users").document(userID)
                .collection("groups").getDocuments()
            guard loadRevision == revision, self.userID == userID, !Task.isCancelled else { return }

            var loadedMeetups = personalSnapshot.documents.compactMap { Self.decode($0) }
            for membership in memberships.documents {
                let groupID = membership.documentID
                let groupSnapshot = try await database.collection("groups").document(groupID)
                    .collection("meetups").getDocuments()
                guard loadRevision == revision, self.userID == userID, !Task.isCancelled else { return }
                for document in groupSnapshot.documents {
                    guard var meetup = Self.decode(document, groupID: groupID) else { continue }
                    let responseSnapshot = try await document.reference.collection("availability").getDocuments()
                    guard loadRevision == revision, self.userID == userID, !Task.isCancelled else { return }
                    var availableUsersByCandidate: [String: Set<String>] = [:]
                    var myAvailableCandidateIDs = Set<String>()
                    for response in responseSnapshot.documents {
                        let responseData = response.data()
                        guard let candidateIDs = responseData["availableCandidateIDs"] as? [String] else { continue }
                        for candidateID in candidateIDs {
                            availableUsersByCandidate[candidateID, default: []].insert(response.documentID)
                        }
                        if response.documentID == userID {
                            myAvailableCandidateIDs = Set(candidateIDs)
                        }
                    }
                    meetup.candidateTimes = meetup.candidateTimes.map { option in
                        MeetupTimeOption(
                            id: option.id,
                            startsAt: option.startsAt,
                            availableFriendIDs: availableUsersByCandidate[option.id, default: []]
                        )
                    }
                    meetup.myAvailableCandidateIDs = myAvailableCandidateIDs
                    loadedMeetups.append(meetup)
                }
            }

            meetups = loadedMeetups.sorted { Self.sortDate(for: $0) < Self.sortDate(for: $1) }
        } catch {
            guard loadRevision == revision, self.userID == userID, !Task.isCancelled else { return }
            loadErrorMessage = error.localizedDescription
        }
    }

    func reload() async {
        guard let userID else { return }
        await load(userID: userID)
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
                "id": friend.id,
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
                MeetupTimeOption(id: UUID().uuidString, startsAt: $0, availableFriendIDs: [])
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

    func createShared(
        groupID: String,
        title: String,
        participants: [Friend],
        candidateDates: [Date],
        location: String
    ) async throws {
        guard let userID else { throw MeetupStoreError.notSignedIn }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, cleanTitle.count <= 80,
              !participants.isEmpty, participants.count <= 20,
              participants.contains(where: { $0.id == userID }),
              !candidateDates.isEmpty, candidateDates.count <= 8,
              cleanLocation.count <= 100 else {
            throw MeetupStoreError.incomplete
        }

        isWorking = true
        defer { isWorking = false }

        let meetupID = UUID()
        let sortedDates = candidateDates.sorted()
        let candidateOptions = sortedDates.map { (id: UUID().uuidString, date: $0) }
        let participantData = Self.encode(participants)
        var data: [String: Any] = [
            "groupID": groupID,
            "title": cleanTitle,
            "participants": participantData,
            "participantUIDs": participants.map(\.id),
            "candidateIDs": candidateOptions.map(\.id),
            "candidateTimes": candidateOptions.map { ["id": $0.id, "startsAt": Timestamp(date: $0.date)] as [String: Any] },
            "status": "planning",
            "ownerUID": userID,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if !cleanLocation.isEmpty {
            data["location"] = cleanLocation
        }

        try await database.collection("groups").document(groupID)
            .collection("meetups").document(meetupID.uuidString)
            .setData(data)

        meetups.append(Meetup(
            id: meetupID,
            groupID: groupID,
            title: cleanTitle,
            participants: participants,
            candidateTimes: candidateOptions.map {
                MeetupTimeOption(id: $0.id, startsAt: $0.date, availableFriendIDs: [])
            },
            confirmedTime: nil,
            location: cleanLocation.isEmpty ? nil : cleanLocation,
            status: .planning,
            arrivalStates: [],
            moments: []
        ))
        meetups.sort { Self.sortDate(for: $0) < Self.sortDate(for: $1) }
    }

    func saveAvailability(for meetup: Meetup, candidateIDs: Set<String>) async throws {
        guard let userID,
              let groupID = meetup.groupID,
              meetup.participants.contains(where: { $0.id == userID }) else {
            throw MeetupStoreError.notSignedIn
        }
        let allowedCandidateIDs = Set(meetup.candidateTimes.map(\.id))
        guard candidateIDs.isSubset(of: allowedCandidateIDs) else {
            throw MeetupStoreError.incomplete
        }

        isWorking = true
        defer { isWorking = false }

        try await database.collection("groups").document(groupID)
            .collection("meetups").document(meetup.id.uuidString)
            .collection("availability").document(userID)
            .setData([
                "availableCandidateIDs": candidateIDs.sorted(),
                "updatedAt": FieldValue.serverTimestamp()
            ])

        guard let index = meetups.firstIndex(where: { $0.id == meetup.id && $0.groupID == groupID }) else { return }
        var updatedMeetup = meetups[index]
        updatedMeetup.myAvailableCandidateIDs = candidateIDs
        updatedMeetup.candidateTimes = updatedMeetup.candidateTimes.map { option in
            var availableFriendIDs = option.availableFriendIDs
            availableFriendIDs.remove(userID)
            if candidateIDs.contains(option.id) {
                availableFriendIDs.insert(userID)
            }
            return MeetupTimeOption(
                id: option.id,
                startsAt: option.startsAt,
                availableFriendIDs: availableFriendIDs
            )
        }
        meetups[index] = updatedMeetup
    }

    private static func encode(_ participants: [Friend]) -> [[String: String]] {
        participants.map { friend in
            [
                "id": friend.id,
                "name": friend.name,
                "initials": friend.initials,
                "profileColor": friend.profileColor.rawValue,
                "lastSharedContext": friend.lastSharedContext
            ]
        }
    }

    private static func decode(_ document: QueryDocumentSnapshot, groupID: String? = nil) -> Meetup? {
        let data = document.data()
        guard let id = UUID(uuidString: document.documentID),
              let title = data["title"] as? String,
              let participantData = data["participants"] as? [[String: Any]],
              let candidateValues = data["candidateTimes"] as? [Any] else {
            return nil
        }

        let participants = participantData.compactMap { item -> Friend? in
            guard let rawID = item["id"] as? String,
                  let name = item["name"] as? String else { return nil }
            return Friend(
                id: rawID,
                name: name,
                initials: item["initials"] as? String ?? String(name.prefix(1)),
                profileColor: ProfileColor(rawValue: item["profileColor"] as? String ?? "blue") ?? .blue,
                lastSharedContext: item["lastSharedContext"] as? String ?? "함께할 친구"
            )
        }
        guard !participants.isEmpty else { return nil }
        let candidateTimes = candidateValues.compactMap(Self.decodeCandidateTime)
        guard !candidateTimes.isEmpty else { return nil }

        return Meetup(
            id: id,
            groupID: groupID ?? data["groupID"] as? String,
            title: title,
            participants: participants,
            candidateTimes: candidateTimes,
            confirmedTime: nil,
            location: data["location"] as? String,
            status: .planning,
            arrivalStates: [],
            moments: []
        )
    }

    private static func decodeCandidateTime(_ value: Any) -> MeetupTimeOption? {
        if let timestamp = value as? Timestamp {
            let date = timestamp.dateValue()
            return MeetupTimeOption(
                id: "legacy-\(Int(date.timeIntervalSince1970))",
                startsAt: date,
                availableFriendIDs: []
            )
        }
        guard let candidate = value as? [String: Any],
              let id = candidate["id"] as? String,
              let timestamp = candidate["startsAt"] as? Timestamp else { return nil }
        return MeetupTimeOption(id: id, startsAt: timestamp.dateValue(), availableFriendIDs: [])
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
    let onOpenGroups: () -> Void

    @State private var showingCreateSheet = false

    init(
        meetups: [Meetup],
        store: MeetupStore,
        allowsCreation: Bool,
        onOpenGroups: @escaping () -> Void = {},
        initiallyShowingCreateSheet: Bool = false
    ) {
        self.meetups = meetups
        self.store = store
        self.allowsCreation = allowsCreation
        self.onOpenGroups = onOpenGroups
        _showingCreateSheet = State(initialValue: initiallyShowingCreateSheet)
    }

    var body: some View {
        List {
            if meetups.isEmpty {
                if store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if store.loadErrorMessage != nil {
                    VStack(spacing: 12) {
                        ContentUnavailableView(
                            "모임을 불러오지 못했어요",
                            systemImage: "arrow.clockwise",
                            description: Text("네트워크 연결을 확인한 뒤 다시 시도해 주세요.")
                        )
                        Button("다시 시도", systemImage: "arrow.clockwise") {
                            Task { await store.reload() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    VStack(spacing: 12) {
                        ContentUnavailableView(
                            "아직 모임이 없어요",
                            systemImage: "calendar",
                            description: Text(allowsCreation
                                ? "친구들과 만날 약속을 만들어 보세요."
                                : "실제 그룹 멤버와 함께하는 모임을 준비 중이에요. 먼저 그룹 탭에서 친구를 초대해 주세요.")
                        )
                        if !allowsCreation {
                            Button("그룹으로 이동", systemImage: "person.3", action: onOpenGroups)
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            } else {
                if let loadErrorMessage = store.loadErrorMessage {
                    Section {
                        Label(loadErrorMessage, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("다시 시도", systemImage: "arrow.clockwise") {
                            Task { await store.reload() }
                        }
                    }
                }
                ForEach(meetups) { meetup in
                    NavigationLink {
                        MeetupDetailView(meetup: meetup, store: store)
                    } label: {
                        MeetupRow(meetup: meetup)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("모임")
        .refreshable { await store.reload() }
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

struct MeetupDetailView: View {
    let meetup: Meetup
    @ObservedObject var store: MeetupStore
    @State private var selectedCandidateIDs: Set<String>
    @State private var errorMessage: String?
    @State private var didSave = false

    init(meetup: Meetup, store: MeetupStore) {
        self.meetup = meetup
        self.store = store
        _selectedCandidateIDs = State(initialValue: meetup.myAvailableCandidateIDs)
    }

    private var currentMeetup: Meetup {
        store.meetups.first { $0.id == meetup.id && $0.groupID == meetup.groupID } ?? meetup
    }

    var body: some View {
        List {
            Section {
                Text(currentMeetup.participants.map(\.name).joined(separator: " · "))
                    .foregroundStyle(.secondary)
                if let location = currentMeetup.location {
                    Label(location, systemImage: "mappin.and.ellipse")
                }
                if let bestSharedTime = currentMeetup.bestSharedTime {
                    Label(
                        "모두 가능한 시간 · \(bestSharedTime.formatted(date: .abbreviated, time: .shortened))",
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)
                }
            } header: {
                Text(currentMeetup.title)
            }

            if currentMeetup.groupID != nil {
                Section {
                    ForEach(currentMeetup.candidateTimes.sorted { $0.startsAt < $1.startsAt }) { option in
                        Toggle(isOn: candidateBinding(for: option.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.startsAt.formatted(date: .complete, time: .shortened))
                                Text("가능 \(option.availableFriendIDs.count) / \(currentMeetup.participants.count)명")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if didSave {
                        Label("일정 응답을 저장했어요.", systemImage: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                } header: {
                    Text("가능한 시간")
                } footer: {
                    Text("참여 가능한 시간을 모두 선택해 주세요. 선택하지 않은 시간은 어렵다는 응답으로 저장됩니다.")
                }
            } else {
                Section {
                    Text("이 모임은 만든 사람 계정에만 저장된 개인 초안이에요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("모임")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.reload() }
        .toolbar {
            if currentMeetup.groupID != nil {
                ToolbarItem(placement: .confirmationAction) {
                    Button("응답 저장") { saveAvailability() }
                        .disabled(store.isWorking)
                }
            }
        }
        .alert("응답을 저장하지 못했어요", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "잠시 후 다시 시도해 주세요.")
        }
        .onChange(of: currentMeetup.myAvailableCandidateIDs) { _, newValue in
            selectedCandidateIDs = newValue
        }
    }

    private func candidateBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { selectedCandidateIDs.contains(id) },
            set: { isSelected in
                if isSelected {
                    selectedCandidateIDs.insert(id)
                } else {
                    selectedCandidateIDs.remove(id)
                }
                didSave = false
            }
        )
    }

    private func saveAvailability() {
        Task {
            do {
                try await store.saveAvailability(for: currentMeetup, candidateIDs: selectedCandidateIDs)
                didSave = true
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct CreateMeetupSheet: View {
    @ObservedObject var store: MeetupStore
    private let groupID: String?
    private let participants: [Friend]
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var location = ""
    @State private var selectedFriendIDs = Set<Friend.ID>()
    @State private var candidateDates: [Date] = []
    @State private var candidateDate: Date = {
        Calendar.current.nextDate(
            after: .now,
            matching: DateComponents(hour: 18, minute: 30),
            matchingPolicy: .nextTime
        ) ?? .now.addingTimeInterval(60 * 60)
    }()

    init(
        store: MeetupStore,
        groupID: String? = nil,
        participants: [Friend] = [],
        screenshotPreview: Bool
    ) {
        self.store = store
        self.groupID = groupID
        self.participants = screenshotPreview ? MockData.friends : participants
        _selectedFriendIDs = State(initialValue: Set((screenshotPreview ? MockData.friends : participants).map(\.id)))
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
            && title.count <= 80
            && location.count <= 100
            && !selectedFriendIDs.isEmpty
            && candidateDates.count <= 8
            && !candidateDates.isEmpty
            && !store.isWorking
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("모임") {
                    TextField("예: 토요일 저녁", text: $title)
                        .textInputAutocapitalization(.sentences)
                    if title.count > 80 {
                        Text("모임 이름은 80자까지 입력할 수 있어요.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    TextField("장소 (선택)", text: $location)
                    if location.count > 100 {
                        Text("장소는 100자까지 입력할 수 있어요.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    ForEach(participants) { friend in
                        if groupID == nil {
                            friendSelectionRow(friend)
                        } else {
                            HStack(spacing: 12) {
                                InitialsAvatar(friend: friend)
                                Text(friend.name)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                } header: {
                    Text("함께할 친구")
                } footer: {
                    Text(groupID == nil
                        ? "샘플 화면에서만 사용하는 친구예요. 실제 앱에서는 저장·초대되지 않습니다."
                        : "현재 그룹 멤버 모두에게 공유되는 모임입니다.")
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
        let selectedParticipants = participants.filter { selectedFriendIDs.contains($0.id) }
        Task {
            do {
                if let groupID {
                    try await store.createShared(
                        groupID: groupID,
                        title: title,
                        participants: selectedParticipants,
                        candidateDates: candidateDates,
                        location: location
                    )
                } else {
                    try await store.create(
                        title: title,
                        participants: selectedParticipants,
                        candidateDates: candidateDates,
                        location: location
                    )
                }
                dismiss()
            } catch {
                store.errorMessage = error.localizedDescription
            }
        }
    }
}
