import SwiftUI

struct ContentView: View {
    @StateObject private var session = SessionStore()
    @State private var selectedTab: String = {
        let argument = ProcessInfo.processInfo.arguments.first {
            $0.hasPrefix("--screenshot-tab=")
        }
        return argument.map { String($0.dropFirst("--screenshot-tab=".count)) } ?? "home"
    }()

    var body: some View {
        Group {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--screenshot-preview") {
                UserTabs(
                    user: AppUser(id: "screenshot-demo", email: "demo@urisai.app", displayName: "우리 사이"),
                    session: session,
                    selectedTab: $selectedTab,
                    screenshotPreview: true
                )
            } else {
                authenticatedContent
            }
#else
            authenticatedContent
#endif
        }
        .animation(.default, value: session.user?.id)
    }

    private var authenticatedContent: some View {
        Group {
            if session.isLoading {
                ProgressView("불러오는 중")
            } else if let user = session.user {
                UserTabs(user: user, session: session, selectedTab: $selectedTab)
                    .id(user.id)
            } else {
                AuthView(session: session)
            }
        }
    }

}

private struct UserTabs: View {
    let user: AppUser
    @ObservedObject var session: SessionStore
    @Binding var selectedTab: String
    var screenshotPreview = false
    @StateObject private var meetupStore: MeetupStore

    init(user: AppUser, session: SessionStore, selectedTab: Binding<String>, screenshotPreview: Bool = false) {
        self.user = user
        self.session = session
        self._selectedTab = selectedTab
        self.screenshotPreview = screenshotPreview
        _meetupStore = StateObject(wrappedValue: MeetupStore(userID: user.id))
    }

    var body: some View {
        let screenshotMeetupCreation = ProcessInfo.processInfo.arguments.contains("--screenshot-meetup-create")
        return TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(
                    meetups: screenshotPreview ? MockData.meetups : meetupStore.meetups,
                    isLoading: !screenshotPreview && meetupStore.isLoading,
                    showsSampleContent: screenshotPreview
                )
                    .toolbar { accountToolbar(user: user) }
            }
            .tabItem {
                Label("홈", systemImage: "house")
            }
            .tag("home")

            NavigationStack {
                Group {
#if DEBUG
                if screenshotPreview {
                    ScreenshotGroupsView()
                } else {
                    GroupsView(user: user, meetupStore: meetupStore)
                }
#else
                GroupsView(user: user, meetupStore: meetupStore)
#endif
                }
                .toolbar { accountToolbar(user: user) }
            }
            .tabItem {
                Label("그룹", systemImage: "person.3")
            }
            .tag("groups")

            NavigationStack {
                FriendsView(onOpenGroups: { selectedTab = "groups" })
                    .toolbar { accountToolbar(user: user) }
            }
            .tabItem {
                Label("친구", systemImage: "person.2")
            }
            .tag("friends")

            NavigationStack {
                MeetupsView(
                    meetups: screenshotPreview ? MockData.meetups : meetupStore.meetups,
                    store: meetupStore,
                    allowsCreation: screenshotPreview && screenshotMeetupCreation,
                    onOpenGroups: { selectedTab = "groups" },
                    initiallyShowingCreateSheet: screenshotPreview && screenshotMeetupCreation
                )
                    .toolbar { accountToolbar(user: user) }
            }
            .tabItem {
                Label("모임", systemImage: "calendar")
            }
            .tag("meetups")

            NavigationStack {
                Group {
#if DEBUG
                    if screenshotPreview {
                        ScreenshotMemoriesView()
                    } else {
                        MemoriesView()
                    }
#else
                    MemoriesView()
#endif
                }
                    .toolbar { accountToolbar(user: user) }
            }
            .tabItem {
                Label("추억", systemImage: "photo.on.rectangle")
            }
            .tag("memories")
        }
        .task(id: user.id) {
            guard !screenshotPreview else { return }
            await meetupStore.load(userID: user.id)
        }
    }

    @ToolbarContentBuilder
    private func accountToolbar(user: AppUser) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Text(user.email)
                Button("로그아웃", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    session.signOut()
                }
            } label: {
                Image(systemName: "person.crop.circle")
            }
            .accessibilityLabel("계정 메뉴")
        }
    }
}

#if DEBUG
private struct ScreenshotGroupsView: View {
    private let groups = ["대학 친구들", "회사 동료", "주말 산책"]
    @State private var showingCreateSheet = ProcessInfo.processInfo.arguments.contains("--screenshot-group-create")
    @State private var groupName = ""

    var body: some View {
        List {
            Section("내 그룹") {
                ForEach(groups, id: \.self) { group in
                    HStack(spacing: 12) {
                        Image(systemName: "person.3.fill")
                            .foregroundStyle(.tint)
                            .frame(width: 40, height: 40)
                            .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(group)
                                .font(.headline)
                            Text("친구들과 함께하는 공간")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 3)
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
        .sheet(isPresented: $showingCreateSheet) {
            NavigationStack {
                Form {
                    Section("그룹 이름") {
                        TextField("예: 대학 친구들", text: $groupName)
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
                        Button("취소") { showingCreateSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("만들기") {}
                            .disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

private struct ScreenshotMemoriesView: View {
    var body: some View {
        List {
            ForEach(MockData.memories) { memory in
                MemoryRow(memory: memory)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("추억")
    }
}
#endif

private struct FriendsView: View {
    let onOpenGroups: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ContentUnavailableView(
                "아직 연결된 친구가 없어요",
                systemImage: "person.2",
                description: Text("실제 친구를 그룹에 초대하면 함께하는 사람을 확인할 수 있어요.")
            )
            Button("그룹으로 이동", systemImage: "person.3", action: onOpenGroups)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("친구")
    }
}

private struct MemoriesView: View {
    var body: some View {
        ContentUnavailableView(
            "아직 함께한 추억이 없어요",
            systemImage: "photo.on.rectangle",
            description: Text("모임에서 사진과 순간을 나누면 여기에 추억으로 모을 수 있어요.")
        )
        .navigationTitle("추억")
    }
}

#Preview {
    ContentView()
}
