import SwiftUI

struct TodayView: View {
    @Environment(Store.self) private var store
    @State private var reviewing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("\(store.totalDue)")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundStyle(store.totalDue > 0 ? Color.orange : Color.green)
                        Text(store.totalDue > 0 ? "بطاقة مستحقة اليوم" : "لا بطاقات مستحقة. أحسنت!")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 30)

                    Button { reviewing = true } label: {
                        Label("ابدأ المراجعة", systemImage: "play.fill")
                            .font(.headline).frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.totalDue == 0)
                    .padding(.horizontal)

                    HStack(spacing: 12) {
                        InfoTile(icon: "flame.fill", value: "\(store.streak)", label: "يوم متتالي", color: .orange)
                        InfoTile(icon: "checkmark.circle.fill", value: "\(store.reviewsOn(Date()))", label: "مراجعة اليوم", color: .green)
                        InfoTile(icon: "rectangle.stack.fill", value: "\(store.totalCards)", label: "إجمالي البطاقات", color: .accentColor)
                    }
                    .padding(.horizontal)

                    if !store.decks.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("بحسب المجموعة").font(.headline)
                            ForEach(store.decks) { deck in
                                HStack {
                                    Text(deck.emoji)
                                    Text(deck.name)
                                    Spacer()
                                    Text("\(deck.dueCount)").foregroundStyle(deck.dueCount > 0 ? .orange : .secondary).bold()
                                }
                                .padding(12)
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("المراجعة")
            .fullScreenCover(isPresented: $reviewing) { ReviewSessionView(deckID: nil) }
        }
    }
}

struct InfoTile: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.title2.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
