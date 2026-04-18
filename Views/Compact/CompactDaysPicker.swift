import SwiftUI

struct CompactDaysPicker: View {
    @Binding var selectedDatesIso: [String]

    @State private var pendingDate: Date = Date()

    private var pendingIso: String {
        let cal = Calendar.current
        return toISODate(
            year: cal.component(.year, from: pendingDate),
            month: cal.component(.month, from: pendingDate) - 1,
            day: cal.component(.day, from: pendingDate)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Pick Days")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Theme.voteGreenHigh)

            Spacer(minLength: 0)

            // Date picker centered; Add below (compact popover opens from picker, not over Add)
            VStack(alignment: .center, spacing: 10) {
                DatePicker("", selection: $pendingDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .accentColor(Theme.voteGreenHigh)
                    .padding(.horizontal, 8)
                    .background(Theme.cardBackground)
                    .cornerRadius(12)

                Button {
                    addDate(pendingIso)
                } label: {
                    Text("Add")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(
                            selectedDatesIso.contains(pendingIso)
                                ? Theme.cellDefault
                                : Theme.primaryBlue
                        )
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)
                .disabled(selectedDatesIso.contains(pendingIso))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)

            Spacer(minLength: 0)

            // Selected pills section
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Selected")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.voteGreenHigh)
                    Spacer()
                    Text("\(selectedDatesIso.count)")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(Theme.voteGreenHigh)
                }

                if selectedDatesIso.isEmpty {
                    Text("Your chosen days appear below.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.top, 2)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(selectedDatesIso, id: \.self) { iso in
                                datePill(iso)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func datePill(_ iso: String) -> some View {
        HStack(spacing: 6) {
            Text(formattedShortDate(iso))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)

            Button {
                removeDate(iso)
            } label: {
                Text("×")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .background(Theme.cellDefault)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .frame(height: 28)
        .background(Theme.cardBackground)
        .clipShape(Capsule())
    }

    private func addDate(_ iso: String) {
        guard !selectedDatesIso.contains(iso) else { return }
        selectedDatesIso.append(iso)
        selectedDatesIso.sort()
    }

    private func removeDate(_ iso: String) {
        selectedDatesIso.removeAll { $0 == iso }
    }

    private func formattedShortDate(_ iso: String) -> String {
        guard let (y, m, d) = parseISODate(iso) else { return iso }
        let comps = DateComponents(year: y, month: m + 1, day: d)
        let cal = Calendar(identifier: .gregorian)
        guard let date = cal.date(from: comps) else { return iso }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
