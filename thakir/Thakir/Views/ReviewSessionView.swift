import SwiftUI

/// جلسة مراجعة: عرض الوجه، كشف الخلف، ثم التقييم بأربعة أزرار.
struct ReviewSessionView: View {
    let deckID: UUID?
    var freePractice = false
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var queue: [(deckID: UUID, card: Card)] = []
    @State private var index = 0
    @State private var revealed = false
    @State private var results: [ReviewGrade: Int] = [:]

    var body: some View {
        NavigationStack {
            Group {
                if queue.isEmpty {
                    ContentUnavailableView("لا شيء للمراجعة الآن", systemImage: "checkmark.seal", description: Text("عد لاحقًا عندما تُستحق بطاقات جديدة."))
                } else if index >= queue.count {
                    summary
                } else {
                    cardView
                }
            }
            .navigationTitle(freePractice ? "تدريب حر" : "مراجعة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إنهاء") { dismiss() } }
                ToolbarItem(placement: .principal) {
                    if !queue.isEmpty, index < queue.count {
                        Text("\(index + 1) / \(queue.count)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear(perform: loadQueue)
        }
    }

    private var current: (deckID: UUID, card: Card) { queue[index] }

    private var cardView: some View {
        VStack(spacing: 20) {
            ProgressView(value: Double(index), total: Double(queue.count)).padding(.horizontal)

            VStack(spacing: 16) {
                Text(current.card.front)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                if revealed {
                    Divider().padding(.horizontal, 40)
                    Text(current.card.back)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.accentColor)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, minHeight: 280)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
            .padding(.horizontal)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.spring(duration: 0.35)) { revealed = true } }

            Spacer()

            if revealed {
                HStack(spacing: 10) {
                    gradeButton(.again, title: "نسيت", color: .red)
                    gradeButton(.hard, title: "صعب", color: .orange)
                    gradeButton(.good, title: "جيد", color: .green)
                    gradeButton(.easy, title: "سهل", color: .blue)
                }
                .padding(.horizontal)
            } else {
                Button { withAnimation(.spring(duration: 0.35)) { revealed = true } } label: {
                    Text("اعرض الإجابة").font(.headline).frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(.systemGroupedBackground))
    }

    private func gradeButton(_ grade: ReviewGrade, title: String, color: Color) -> some View {
        Button {
            submit(grade)
        } label: {
            VStack(spacing: 4) {
                Text(title).font(.headline)
                Text(Scheduler.previewInterval(current.card, grade: grade)).font(.caption2)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(color)
        }
    }

    private var summary: some View {
        VStack(spacing: 18) {
            Image(systemName: "party.popper.fill").font(.system(size: 60)).foregroundStyle(.orange)
            Text("أحسنت!").font(.largeTitle.bold())
            Text("راجعت \(queue.count) بطاقة في هذه الجلسة.").foregroundStyle(.secondary)
            HStack(spacing: 12) {
                summaryPill("نسيت", results[.again] ?? 0, .red)
                summaryPill("صعب", results[.hard] ?? 0, .orange)
                summaryPill("جيد", results[.good] ?? 0, .green)
                summaryPill("سهل", results[.easy] ?? 0, .blue)
            }
            .padding(.horizontal)
            Text("السلسلة الحالية: \(store.streak) يوم 🔥").font(.headline).padding(.top)
            Button("إغلاق") { dismiss() }.buttonStyle(.borderedProminent).padding(.top)
        }
        .padding()
    }

    private func summaryPill(_ title: String, _ value: Int, _ color: Color) -> some View {
        VStack { Text("\(value)").font(.title2.bold()).foregroundStyle(color); Text(title).font(.caption) }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private func loadQueue() {
        if freePractice, let deckID, let deck = store.deck(id: deckID) {
            queue = deck.cards.shuffled().prefix(30).map { (deckID: deckID, card: $0) }
        } else {
            queue = store.dueCards(in: deckID)
        }
    }

    private func submit(_ grade: ReviewGrade) {
        let item = current
        if !freePractice || item.card.isDue {
            store.review(item.card, in: item.deckID, grade: grade)
        } else {
            store.reviewLog.append(Date())
            store.save()
        }
        results[grade, default: 0] += 1
        withAnimation { revealed = false; index += 1 }
    }
}
