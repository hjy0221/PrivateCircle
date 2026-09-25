import SwiftUI

struct ContentView: View {
    @StateObject private var session = SessionStore()

    var body: some View {
        Group {
            if session.isLoading {
                ProgressView("불러오는 중")
            } else if let user = session.user {
                appTabs(for: user)
            } else {
                AuthView(session: session)
            }
        }
        .animation(.default, value: session.user?.id)
    }

    private func appTabs(for user: AppUser) -> some View {
        TabView {
            NavigationStack {
                HomeView()
                    .toolbar { accountToolbar(user: user) }
            }
            .tabItem {
                Label("홈", systemImage: "house")
            }

            NavigationStack {
                GroupsView(user: user)
                    .toolbar { accountToolbar(user: user) }
            }
            .tabItem {
                Label("그룹", systemImage: "person.3")
            }

            NavigationStack {
                FriendsView()
                    .toolbar { accountToolbar(user: user) }
            }
            .tabItem {
                Label("친구", systemImage: "person.2")
            }

            NavigationStack {
                MeetupsView()
                    .toolbar { accountToolbar(user: user) }
            }
            .tabItem {
                Label("모임", systemImage: "calendar")
            }

            NavigationStack {
                MemoriesView()
                    .toolbar { accountToolbar(user: user) }
            }
            .tabItem {
                Label("추억", systemImage: "photo.on.rectangle")
            }
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

private struct FriendsView: View {
    var body: some View {
        List(MockData.friends) { friend in
            FriendRow(friend: friend)
        }
        .navigationTitle("친구")
    }
}

private struct MeetupsView: View {
    var body: some View {
        List(MockData.meetups) { meetup in
            MeetupRow(meetup: meetup)
        }
        .navigationTitle("모임")
    }
}

private struct MemoriesView: View {
    var body: some View {
        List(MockData.memories) { memory in
            VStack(alignment: .leading, spacing: 6) {
                Text(memory.title)
                    .font(.headline)
                Text(memory.location)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("사진과 순간 \(memory.momentCount)개")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("추억")
    }
}

#Preview {
    ContentView()
}
