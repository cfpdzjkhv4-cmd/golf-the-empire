import GameCore
import SpriteKit
import SwiftUI

struct CourseScreen: View {
    @Environment(GameStore.self) private var store
    private var scene: CourseScene { store.courseScene }

    private var design: CourseDesign? {
        store.course.flatMap { store.engine?.design(of: $0.plotID) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .overlay(alignment: .top) { messageBanner }
            holeStrip
            ScrollView {
                if let design, design.holes.indices.contains(store.selectedHole) {
                    HoleCardView(design: design, holeIndex: store.selectedHole)
                        .padding(12)
                }
            }
            .frame(height: 210)
            .background(Color(uiColor: .secondarySystemBackground))
            BuildBar()
        }
        .onAppear(perform: connectScene)
        .onChange(of: store.currentHole) { redraw(resetCamera: false) }
        .onChange(of: store.selectedHole) { redraw(resetCamera: true) }
        .onChange(of: store.tool) { scene.paintMode = store.tool != nil }
        .alert(dayTitle, isPresented: Binding(
            get: { store.dayJustEnded != nil },
            set: { if !$0 { store.dayJustEnded = nil } }
        )) {
            Button("Start \(store.dateLabel)") { store.dayJustEnded = nil }
        } message: {
            Text(dayMessage)
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                store.save()
                store.screen = .start
            } label: {
                Image(systemName: "chevron.left")
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(store.plot?.name ?? "").font(.headline).lineLimit(1)
                Text("\(store.dateLabel) · \(store.course?.isOpen == true ? "Open" : "Closed")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Money.text(store.engine?.state.cash ?? 0))
                .font(.headline.monospacedDigit())
                .foregroundStyle((store.engine?.state.cash ?? 0) < 0 ? Color.red : Color.primary)
            Menu {
                Button(store.course?.isOpen == true ? "Close the course" : "Open the course") { store.toggleOpen() }
                Button("End the day") { store.finishDay() }
            } label: {
                Image(systemName: "ellipsis.circle").font(.title3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var holeStrip: some View {
        let scores = design?.effectiveHoleScores ?? []
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array((store.course?.holes ?? []).indices), id: \.self) { i in
                        let score = scores[safe: i] ?? 0
                        Button {
                            store.selectHole(i)
                        } label: {
                            VStack(spacing: 1) {
                                Text("\(i + 1)").font(.subheadline.bold())
                                Text(score > 0 ? String(format: "%.1f", score) : "·")
                                    .font(.caption2.monospacedDigit())
                            }
                            .frame(width: 40, height: 40)
                            .background(Color(uiColor: PlaceholderPalette.rating(score)).opacity(i == store.selectedHole ? 1 : 0.55))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(i == store.selectedHole ? Color.primary : .clear, lineWidth: 2)
                            )
                        }
                        .id(i)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .onChange(of: store.selectedHole) {
                withAnimation { proxy.scrollTo(store.selectedHole, anchor: .center) }
            }
        }
    }

    @ViewBuilder
    private var messageBanner: some View {
        if let message = store.message {
            Text(message)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule())
                .padding(.top, 8)
                .task(id: message) {
                    try? await Task.sleep(for: .seconds(2.5))
                    if store.message == message { store.message = nil }
                }
        }
    }

    // MARK: Day summary

    private var dayTitle: String {
        guard let books = store.dayJustEnded, let engine = store.engine else { return "" }
        return "Close of play, \(engine.calendar.shortLabel(day: books.day))"
    }

    private var dayMessage: String {
        guard let books = store.dayJustEnded else { return "" }
        var lines: [String] = []
        for category in LedgerCategory.allCases where books[category] != 0 {
            lines.append("\(category.label): \(Money.text(books[category]))")
        }
        if lines.isEmpty { lines.append("No money in or out today.") }
        lines.append("Net for the day: \(Money.text(books.net))")
        lines.append("In the bank: \(Money.text(books.closingCash))")
        return lines.joined(separator: "\n")
    }

    // MARK: Scene wiring

    private func connectScene() {
        scene.onPaint = { point in store.paint(at: point) }
        scene.onStrokeEnded = { store.endStroke() }
        scene.onSwipe = { step in
            guard let count = store.course?.holes.count else { return }
            store.selectHole(min(max(store.selectedHole + step, 0), count - 1))
        }
        scene.paintMode = store.tool != nil
        redraw(resetCamera: true)
    }

    private func redraw(resetCamera: Bool) {
        guard let hole = store.currentHole, let plot = store.plot else { return }
        scene.show(hole, land: plot.land, resetCamera: resetCamera)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
