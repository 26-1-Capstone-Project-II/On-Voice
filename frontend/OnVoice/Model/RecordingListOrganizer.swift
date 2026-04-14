//
//  RecordingListOrganizer.swift
//  OnVoice
//

import Foundation

struct RecordingDisplayItem: Identifiable, Hashable {
    let index: Int
    let recording: Recording

    var id: Recording.ID {
        recording.id
    }
}

struct RecordingLibrarySection: Identifiable, Hashable {
    let id: String
    let title: String
    let items: [RecordingDisplayItem]
}

enum RecordingListOrganizer {
    static var currentDate: () -> Date = Date.init

    static func homeItems(
        from recordings: [Recording],
        calendar: Calendar = .current
    ) -> [RecordingDisplayItem] {
        let today = currentDate()
        return sortedDisplayItems(from: recordings)
            .filter { calendar.isDate($0.recording.createdAt, inSameDayAs: today) }
    }

    static func librarySections(
        from recordings: [Recording],
        calendar: Calendar = .current
    ) -> [RecordingLibrarySection] {
        let todayDate = currentDate()
        let libraryItems = sortedDisplayItems(from: recordings)
            .filter { !calendar.isDate($0.recording.createdAt, inSameDayAs: todayDate) }

        guard !libraryItems.isEmpty else { return [] }

        let today = calendar.startOfDay(for: todayDate)
        let previous7DaysStart = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        let previous30DaysStart = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        var previous7Days: [RecordingDisplayItem] = []
        var previous30Days: [RecordingDisplayItem] = []
        var monthlyBuckets: [Date: [RecordingDisplayItem]] = [:]

        for item in libraryItems {
            let recordingDay = calendar.startOfDay(for: item.recording.createdAt)

            switch recordingDay {
            case previous7DaysStart..<today:
                previous7Days.append(item)
            case previous30DaysStart..<previous7DaysStart:
                previous30Days.append(item)
            default:
                let monthStart = calendar.dateInterval(of: .month, for: item.recording.createdAt)?.start ?? recordingDay
                monthlyBuckets[monthStart, default: []].append(item)
            }
        }

        var sections: [RecordingLibrarySection] = []

        if !previous7Days.isEmpty {
            sections.append(
                RecordingLibrarySection(
                    id: "previous-7-days",
                    title: "이전 7일",
                    items: sortedSectionItems(previous7Days)
                )
            )
        }

        if !previous30Days.isEmpty {
            sections.append(
                RecordingLibrarySection(
                    id: "previous-30-days",
                    title: "이전 30일",
                    items: sortedSectionItems(previous30Days)
                )
            )
        }

        let sortedMonthStarts = monthlyBuckets.keys.sorted(by: >)
        for monthStart in sortedMonthStarts {
            guard let items = monthlyBuckets[monthStart] else { continue }

            sections.append(
                RecordingLibrarySection(
                    id: monthSectionID(for: monthStart, calendar: calendar),
                    title: monthSectionTitle(for: monthStart, calendar: calendar),
                    items: sortedSectionItems(items)
                )
            )
        }

        return sections
    }

    static func displayTitle(for item: RecordingDisplayItem) -> String {
        if item.recording.usesGeneratedDefaultTitle {
            return "새로운 대화 기록 (\(item.index))"
        }

        return item.recording.title
    }

    private static func sortedDisplayItems(from recordings: [Recording]) -> [RecordingDisplayItem] {
        let sortedRecordings = recordings.sorted { lhs, rhs in
            lhs.createdAt > rhs.createdAt
        }

        return sortedRecordings.enumerated().map { offset, recording in
            RecordingDisplayItem(
                index: sortedRecordings.count - offset,
                recording: recording
            )
        }
    }

    private static func sortedSectionItems(_ items: [RecordingDisplayItem]) -> [RecordingDisplayItem] {
        items.sorted { lhs, rhs in
            lhs.recording.createdAt > rhs.recording.createdAt
        }
    }

    private static func monthSectionID(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return "month-\(components.year ?? 0)-\(components.month ?? 0)"
    }

    private static func monthSectionTitle(for date: Date, calendar: Calendar) -> String {
        let currentYear = calendar.component(.year, from: currentDate())
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        if year == currentYear {
            return "\(month)월"
        }

        return "\(year)년 \(month)월"
    }
}
