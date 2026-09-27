import Foundation

struct Friend: Identifiable, Hashable {
    let id: String
    var name: String
    var initials: String
    var profileColor: ProfileColor
    var lastSharedContext: String
}

enum ProfileColor: String, Hashable {
    case blue
    case green
    case orange
    case pink
}

struct Meetup: Identifiable, Hashable {
    let id: UUID
    var groupID: String? = nil
    var ownerID: String? = nil
    var myAvailableCandidateIDs: Set<String> = []
    var submittedAvailabilityIDs: Set<String> = []
    var confirmedCandidateID: String? = nil
    var title: String
    var participants: [Friend]
    var candidateTimes: [MeetupTimeOption]
    var confirmedTime: Date?
    var location: String?
    var status: MeetupStatus
    var arrivalStates: [ArrivalState]
    var moments: [Moment]

    var bestSharedTime: Date? {
        let participantIDs = Set(participants.map(\.id))
        return candidateTimes.first { $0.availableFriendIDs.isSuperset(of: participantIDs) }?.startsAt
    }
}

struct MeetupTimeOption: Identifiable, Hashable {
    let id: String
    var startsAt: Date
    var availableFriendIDs: Set<Friend.ID>
}

enum MeetupStatus: String, CaseIterable, Hashable {
    case planning = "일정 조율 중"
    case confirmed = "약속 확정"
    case today = "오늘 만나요"
    case collectingMoments = "사진 모으는 중"
    case remembered = "추억으로 저장됨"
}

struct ArrivalState: Identifiable, Hashable {
    let userID: String
    var friend: Friend
    var state: ArrivalProgress
    var updatedAt: Date

    var id: String { userID }
}

enum ArrivalProgress: String, CaseIterable, Hashable {
    case notStarted
    case leavingSoon
    case onTheWay
    case arrivingSoon
    case arrived

    var title: String {
        switch self {
        case .notStarted: "아직 출발 전"
        case .leavingSoon: "곧 출발"
        case .onTheWay: "이동 중"
        case .arrivingSoon: "거의 도착"
        case .arrived: "도착했어요"
        }
    }

    var symbolName: String {
        switch self {
        case .notStarted: "clock"
        case .leavingSoon: "figure.walk"
        case .onTheWay: "tram.fill"
        case .arrivingSoon: "location.circle"
        case .arrived: "checkmark.circle.fill"
        }
    }
}

struct Moment: Identifiable, Hashable {
    let id: UUID
    var author: Friend
    var capturedAt: Date
    var caption: String
}

struct Memory: Identifiable, Hashable {
    let id: UUID
    var title: String
    var location: String
    var createdAt: Date
    var people: [Friend]
    var momentCount: Int
}
