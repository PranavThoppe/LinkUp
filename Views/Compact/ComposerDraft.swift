import Combine
import Foundation

final class ComposerDraft: ObservableObject {
    @Published var selectedTab: ScheduleMode = .month
    @Published var selectedMonths: [MonthYear]
    @Published var weekStartIso: String? = nil
    @Published var weekEndIso: String? = nil
    @Published var selectedDatesIso: [String] = []

    init() {
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        let currentMonth = MonthYear(
            month: cal.component(.month, from: now) - 1,
            year: cal.component(.year, from: now)
        )
        self.selectedMonths = [currentMonth]
    }
}
