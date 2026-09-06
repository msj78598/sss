import SwiftUI
import Charts

struct StatsView: View {
    @Environment(Store.self) private var store

    private var week: [Store.DayCount] { store.lastWeek }

    var body: some View {
        NavigationStack {
            List {
                Section("آخر ٧ أيام") {
                    Chart(week) { item in
                        BarMark(x: .value("اليوم", item.day, unit: .day), y: .value("مراجعات", item.count))
                            .foregroundStyle(Color.accentColor.gradient)
                            .cornerRadius(6)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.narrow))
                        }
                    }
                    .frame(height: 180)
                    .padding(.vertical, 8)
                }
                Section("الملخص") {
                    LabeledContent("إجمالي البطاقات", value: "\(store.totalCards)")
                    LabeledContent("مستحقة الآن", value: "\(store.totalDue)")
                    LabeledContent("مراجعات اليوم", value: "\(store.reviewsOn(Date()))")
                    LabeledContent("إجمالي المراجعات", value: "\(store.reviewLog.count)")
                    LabeledContent("السلسلة اليومية", value: "\(store.streak) يوم")
                }
                Section("الإتقان بحسب المجموعة") {
                    if store.decks.isEmpty {
                        Text("لا توجد مجموعات بعد.").foregroundStyle(.secondary)
                    }
                    ForEach(store.decks) { deck in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(deck.emoji) \(deck.name)")
                                Spacer()
                                Text("\(deck.masteredCount)/\(deck.cards.count)").foregroundStyle(.secondary)
                            }
                            ProgressView(value: deck.cards.isEmpty ? 0 : Double(deck.masteredCount) / Double(deck.cards.count))
                                .tint(.green)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("الإحصاءات")
        }
    }
}
