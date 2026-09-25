import SwiftUI

struct HomeView: View {
    private let meetups: [Meetup]
    private let isLoading: Bool
    private var nextMeetup: Meetup? {
        meetups.first { $0.confirmedTime.map { $0 > .now } ?? false }
    }
    private var planningMeetups: [Meetup] { meetups.filter { $0.status == .planning } }
    private let recentMemory = MockData.memories.first

    init(meetups: [Meetup] = MockData.meetups, isLoading: Bool = false) {
        self.meetups = meetups
        self.isLoading = isLoading
    }

    var body: some View {
        List {
            Section("다가오는 모임") {
                if let nextMeetup {
                    NextMeetupCard(meetup: nextMeetup)
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ContentUnavailableView(
                        planningMeetups.isEmpty ? "아직 모임이 없어요" : "아직 확정된 약속이 없어요",
                        systemImage: "calendar",
                        description: Text(
                            planningMeetups.isEmpty
                                ? "친구들과 다음 약속을 만들어 보세요."
                                : "아래에서 일정을 조율 중인 모임을 확인해 보세요."
                        )
                    )
                }
            }

            if !planningMeetups.isEmpty {
                Section("일정을 함께 정하고 있어요") {
                    ForEach(planningMeetups) { meetup in
                        MeetupRow(meetup: meetup)
                    }
                }
            }

            Section("친구") {
                ForEach(MockData.friends) { friend in
                    FriendRow(friend: friend)
                }
            }

            if let recentMemory {
                Section("함께한 순간") {
                    MemoryRow(memory: recentMemory)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("우리 사이")
    }
}

struct NextMeetupCard: View {
    let meetup: Meetup

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("다음 약속")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(meetup.title)
                        .font(.title3.weight(.semibold))
                }

                Spacer(minLength: 8)

                Label(meetup.status.rawValue, systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
                    .fixedSize(horizontal: true, vertical: false)
            }

            if let confirmedTime = meetup.confirmedTime {
                Label(confirmedTime.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    .foregroundStyle(.primary)
            }

            if let location = meetup.location {
                Label(location, systemImage: "mappin.and.ellipse")
                    .foregroundStyle(.primary)
            }

            HStack(spacing: -6) {
                ForEach(meetup.participants) { friend in
                    InitialsAvatar(friend: friend)
                }

                Spacer()

                Text("친구 \(meetup.participants.count)명")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(meetup.participants.map(\.name).joined(separator: ", "))
        }
        .padding(.vertical, 8)
    }
}

struct MeetupRow: View {
    let meetup: Meetup

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(meetup.title)
                    .font(.headline)
                Spacer(minLength: 8)
                Text(meetup.status.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(meetup.participants.map(\.name).joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let bestTime = meetup.bestSharedTime {
                Label("모두 가능한 시간 · \(bestTime.formatted(date: .abbreviated, time: .shortened))", systemImage: "person.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let firstCandidate = meetup.candidateTimes.map(\.startsAt).min() {
                let extraCount = meetup.candidateTimes.count - 1
                let candidateText = "후보 · \(firstCandidate.formatted(date: .abbreviated, time: .shortened))"
                    + (extraCount > 0 ? " 외 \(extraCount)개" : "")
                Label(candidateText, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct FriendRow: View {
    let friend: Friend

    var body: some View {
        HStack(spacing: 12) {
            InitialsAvatar(friend: friend)

            VStack(alignment: .leading, spacing: 3) {
                Text(friend.name)
                    .font(.headline)
                Text(friend.lastSharedContext)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

struct InitialsAvatar: View {
    let friend: Friend

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.18))
            Text(friend.initials)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(width: 36, height: 36)
        .accessibilityLabel(friend.name)
    }

    private var color: Color {
        switch friend.profileColor {
        case .blue: .blue
        case .green: .green
        case .orange: .orange
        case .pink: .pink
        }
    }
}

struct MemoryRow: View {
    let memory: Memory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(memory.title)
                    .font(.headline)
                Text("\(memory.location) · \(memory.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("사진과 순간 \(memory.momentCount)개")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
