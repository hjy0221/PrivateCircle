import Foundation

enum MockData {
    static let jaeyun = Friend(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "재윤",
        initials: "JY",
        profileColor: .blue,
        lastSharedContext: "퇴근 후 커피"
    )

    static let minsu = Friend(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "민수",
        initials: "MS",
        profileColor: .green,
        lastSharedContext: "지난주 저녁 식사"
    )

    static let jihyun = Friend(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "지현",
        initials: "JH",
        profileColor: .orange,
        lastSharedContext: "동네 책방 산책"
    )

    static let sora = Friend(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        name: "소라",
        initials: "SR",
        profileColor: .pink,
        lastSharedContext: "주말 브런치"
    )

    static let friends = [jaeyun, minsu, jihyun, sora]

    static let meetups: [Meetup] = {
        let nextSaturday = nextSaturdayAtDinner
        let nextSunday = Calendar.current.date(byAdding: .day, value: 1, to: nextSaturday)
            ?? nextSaturday.addingTimeInterval(60 * 60 * 24)
        let followingSaturday = Calendar.current.date(byAdding: .day, value: 7, to: nextSaturday)
            ?? nextSaturday.addingTimeInterval(60 * 60 * 24 * 7)

        return [
            Meetup(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                title: "저녁 식사",
                participants: [jaeyun, minsu, jihyun],
                candidateTimes: [
                    MeetupTimeOption(
                        id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
                        startsAt: nextSaturday,
                        availableFriendIDs: [jaeyun.id, minsu.id, jihyun.id]
                    ),
                    MeetupTimeOption(
                        id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
                        startsAt: nextSunday,
                        availableFriendIDs: [minsu.id, jihyun.id]
                    )
                ],
                confirmedTime: nextSaturday,
                location: "성수동",
                status: .confirmed,
                arrivalStates: [
                    ArrivalState(id: UUID(), friend: jaeyun, state: .notStarted, updatedAt: .now),
                    ArrivalState(id: UUID(), friend: minsu, state: .notStarted, updatedAt: .now),
                    ArrivalState(id: UUID(), friend: jihyun, state: .notStarted, updatedAt: .now)
                ],
                moments: []
            ),
            Meetup(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
                title: "전시 보러 가기",
                participants: [jaeyun, sora],
                candidateTimes: [
                    MeetupTimeOption(
                        id: UUID(uuidString: "20000000-0000-0000-0000-000000000003")!,
                        startsAt: followingSaturday,
                        availableFriendIDs: [jaeyun.id, sora.id]
                    )
                ],
                confirmedTime: nil,
                location: nil,
                status: .planning,
                arrivalStates: [],
                moments: []
            )
        ]
    }()

    static let memories = [
        Memory(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
            title: "퇴근 후 커피 한 잔",
            location: "합정",
            createdAt: Date.now.addingTimeInterval(-60 * 60 * 24 * 10),
            people: [jaeyun, minsu],
            momentCount: 18
        )
    ]

    private static let nextSaturdayAtDinner: Date = {
        var date = DateComponents()
        date.weekday = 7
        date.hour = 18
        date.minute = 30
        return Calendar.current.nextDate(
            after: .now,
            matching: date,
            matchingPolicy: .nextTime
        ) ?? .now.addingTimeInterval(60 * 60 * 24 * 3)
    }()
}
