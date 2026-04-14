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
    private enum SectionID: String {
        case previous7Days = "previous-7-days"
        case previous30Days = "previous-30-days"
    }

    // Relative-date sections use calendar-day boundaries, not rolling 24-hour windows.
    private static let previous7DaysWindow = 7
    private static let previous30DaysWindow = 30

    private enum RelativeSection {
        case today
        case previous7Days
        case previous30Days
        case monthly(Date)
    }

    static func homeItems(
        from recordings: [Recording],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [RecordingDisplayItem] {
        return sortedDisplayItems(from: recordings)
            .filter {
                if case .today = relativeSection(for: $0.recording.createdAt, comparedTo: now, calendar: calendar) {
                    return true
                }

                return false
            }
    }

    static func librarySections(
        from recordings: [Recording],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [RecordingLibrarySection] {
        let libraryItems = sortedDisplayItems(from: recordings)
            .filter { !calendar.isDate($0.recording.createdAt, inSameDayAs: now) }

        guard !libraryItems.isEmpty else { return [] }

        var previous7Days: [RecordingDisplayItem] = []
        var previous30Days: [RecordingDisplayItem] = []
        var monthlyBuckets: [Date: [RecordingDisplayItem]] = [:]

        for item in libraryItems {
            switch relativeSection(for: item.recording.createdAt, comparedTo: now, calendar: calendar) {
            case .today:
                continue
            case .previous7Days:
                previous7Days.append(item)
            case .previous30Days:
                previous30Days.append(item)
            case let .monthly(monthStart):
                monthlyBuckets[monthStart, default: []].append(item)
            }
        }

        var sections: [RecordingLibrarySection] = []

        if !previous7Days.isEmpty {
            sections.append(
                RecordingLibrarySection(
                    id: SectionID.previous7Days.rawValue,
                    title: "이전 7일",
                    items: sortedSectionItems(previous7Days)
                )
            )
        }

        if !previous30Days.isEmpty {
            sections.append(
                RecordingLibrarySection(
                    id: SectionID.previous30Days.rawValue,
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
                    title: monthSectionTitle(for: monthStart, comparedTo: now, calendar: calendar),
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

    private static func relativeSection(
        for date: Date,
        comparedTo referenceDate: Date,
        calendar: Calendar
    ) -> RelativeSection {
        let referenceDay = calendar.startOfDay(for: referenceDate)
        let targetDay = calendar.startOfDay(for: date)

        if targetDay == referenceDay {
            return .today
        }

        let previous7DaysStart = calendar.date(
            byAdding: .day,
            value: -previous7DaysWindow,
            to: referenceDay
        ) ?? referenceDay
        if previous7DaysStart <= targetDay && targetDay < referenceDay {
            return .previous7Days
        }

        let previous30DaysStart = calendar.date(
            byAdding: .day,
            value: -previous30DaysWindow,
            to: referenceDay
        ) ?? referenceDay
        if previous30DaysStart <= targetDay && targetDay < previous7DaysStart {
            return .previous30Days
        }

        let monthStart = calendar.dateInterval(of: .month, for: targetDay)?.start ?? targetDay
        return .monthly(monthStart)
    }

    private static func monthSectionID(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return "month-\(components.year ?? 0)-\(components.month ?? 0)"
    }

    private static func monthSectionTitle(for date: Date, comparedTo referenceDate: Date, calendar: Calendar) -> String {
        let currentYear = calendar.component(.year, from: referenceDate)
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        if year == currentYear {
            return "\(month)월"
        }

        return "\(year)년 \(month)월"
    }
}
