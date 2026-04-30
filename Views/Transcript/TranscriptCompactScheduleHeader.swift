import SwiftUI

// MARK: - Shared copy & month labels (week + days transcript cards)

enum TranscriptCompactScheduleHeader {
    /// Trims `schedule.title`; empty when the user did not set a title (no default label).
    static func headline(for schedule: Schedule) -> String {
        schedule.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Distinct month labels (with year when not current year) from ISO day columns.
    static func monthParts(from isoDates: [String]) -> [String] {
        let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())
        var seenKeys = Set<String>()
        var parts: [String] = []
        for iso in isoDates {
            guard let (year, month, _) = parseISODate(iso) else { continue }
            let key = "\(year)-\(month)"
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)
            if year == currentYear {
                parts.append(monthName(month))
            } else {
                parts.append("\(monthName(month)) \(String(year))")
            }
        }
        return parts
    }
}

// MARK: - Layout metrics (must match `TranscriptCompactScheduleHeaderView`)

/// Header sizing for compact week/days transcript cards: split title vs single line, line wraps, and card height.
struct TranscriptCompactHeaderMetrics: Equatable {
    /// Pinned title area width inside the 300pt card (12pt padding each side).
    static let contentWidth: CGFloat = 276
    /// One-line header assumed by the original 240pt compact card (≈24pt line + bottom padding).
    static let defaultBaselineHeaderHeight: CGFloat = 34
    static let baseCompactCardHeight: CGFloat = 240

    let headline: String
    let monthLine: String
    /// Month line on top, title below (only when the headline is long and a month line exists).
    let usesSplitHeaderLayout: Bool
    let singleLineText: String

    /// Combined character count used for the header (split: month + title; single: one string).
    let totalHeaderCharacterCount: Int

    init(headline rawHeadline: String, monthParts: [String]) {
        let trimmed = rawHeadline.trimmingCharacters(in: .whitespacesAndNewlines)
        self.headline = trimmed
        self.monthLine = monthParts.joined(separator: " & ")
        let split = self.headline.count > 12 && !self.monthLine.isEmpty
        self.usesSplitHeaderLayout = split
        if split {
            self.singleLineText = ""
            self.totalHeaderCharacterCount = self.monthLine.count + self.headline.count
        } else if self.monthLine.isEmpty {
            self.singleLineText = self.headline
            self.totalHeaderCharacterCount = self.headline.count
        } else if self.headline.isEmpty {
            self.singleLineText = self.monthLine
            self.totalHeaderCharacterCount = self.monthLine.count
        } else {
            self.singleLineText = self.headline + " • " + self.monthLine
            self.totalHeaderCharacterCount = self.singleLineText.count
        }
    }

    /// When false, the header area can be omitted (no title and no month line).
    var hasVisibleHeaderContent: Bool {
        usesSplitHeaderLayout || !singleLineText.isEmpty
    }

    /// Estimated header block height (padding bottom included) for snapshot sizing.
    private var estimatedHeaderBlockHeight: CGFloat {
        let paddingBottom: CGFloat = 10
        if usesSplitHeaderLayout {
            let monthLines = Self.wrappedLineCount(monthLine, fontSize: 16)
            let titleLines = Self.wrappedLineCount(headline, fontSize: 20)
            let monthH = CGFloat(monthLines) * 19
            let titleH = CGFloat(titleLines) * 24
            return monthH + 4 + titleH + paddingBottom
        }
        let text = singleLineText
        guard !text.isEmpty else { return 0 }
        let lines = Self.wrappedLineCount(text, fontSize: 20)
        return CGFloat(lines) * 24 + paddingBottom
    }

    /// Extra card height so the snapshot is not clipped when the header grows (wraps or splits).
    var compactCardHeight: CGFloat {
        guard hasVisibleHeaderContent else {
            // No header rendered, so reclaim the baseline header + its bottom padding.
            return Self.baseCompactCardHeight - Self.defaultBaselineHeaderHeight
        }
        let delta = max(0, estimatedHeaderBlockHeight - Self.defaultBaselineHeaderHeight)
        // Small bump when many characters even if line estimate is flat (e.g. narrow glyphs).
        let charBump = Self.extraHeightForCharacterLoad(totalHeaderCharacterCount)
        return Self.baseCompactCardHeight + delta + charBump
    }

    private static func wrappedLineCount(_ text: String, fontSize: CGFloat) -> Int {
        guard !text.isEmpty else { return 0 }
        let charsPerLine = max(4, Int(Self.contentWidth / (fontSize * 0.55)))
        return max(1, Int(ceil(Double(text.count) / Double(charsPerLine))))
    }

    private static func extraHeightForCharacterLoad(_ totalChars: Int) -> CGFloat {
        switch totalChars {
        case ...35: return 0
        case 36...55: return 6
        case 56...75: return 12
        default: return 18
        }
    }
}

extension MessagePayload {
    /// ISO day columns backing week/days transcript cards (same as `WeekCardView` / `DaysCardView`).
    func compactTranscriptDayColumnIsoStrings() -> [String] {
        switch schedule.mode {
        case .week:
            guard let range = schedule.weekRange else { return [] }
            return dateRangeInclusive(startIso: range.startIso, endIso: range.endIso)
        case .days:
            return Array((schedule.specificDates ?? []).prefix(7))
        case .month:
            return []
        }
    }
}

// MARK: - View

struct TranscriptCompactScheduleHeaderView: View {
    let metrics: TranscriptCompactHeaderMetrics

    var body: some View {
        Group {
            if !metrics.hasVisibleHeaderContent {
                EmptyView()
            } else if metrics.usesSplitHeaderLayout {
                VStack(spacing: 4) {
                    Text(metrics.monthLine)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    Text(metrics.headline)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            } else {
                Text(metrics.singleLineText)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
