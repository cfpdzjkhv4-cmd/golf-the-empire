import CourseArt
import GameCore
import SpriteKit
import SwiftUI

struct CourseScreen: View {
    @Environment(GameStore.self) private var store
    private var scene: CourseScene { store.courseScene }

    private var design: CourseDesign? { store.quality?.design }
    /// Redraw when condition crosses a 5% step, not on every tiny change.
    private var conditionBand: Int { Int((store.course?.condition ?? 85) / 5) }
    private var carsBand: Int { min(12, 2 + (store.course?.today.rounds ?? 0) / 6) }

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            header
            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .overlay(alignment: .top) { messageBanner }
                .overlay(alignment: .bottom) {
                    if let watching = store.watching { PercyBox(watching: watching) }
                }
            holeStrip
            Picker("Tab", selection: $store.tab) {
                ForEach(GameStore.CourseTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .disabled(store.watching != nil)
            panel
                .frame(height: 300)
        }
        .onAppear {
            connectScene()
            startAmbience()
        }
        .onDisappear { SoundBoard.shared.stopAmbience() }
        .onChange(of: store.course?.weather) { startAmbience() }
        .onChange(of: store.currentHole) { redraw(resetCamera: false) }
        .onChange(of: store.course?.facilities) { redraw(resetCamera: false) }
        .onChange(of: conditionBand) { redraw(resetCamera: false) }
        .onChange(of: carsBand) { if store.selectedHole == 0 { redraw(resetCamera: false) } }
        .onChange(of: store.selectedHole) { redraw(resetCamera: store.watching == nil) }
        .onChange(of: store.mode) { scene.paintMode = store.mode != .look }
        .sheet(isPresented: $store.showingCloseOfPlay) {
            CloseOfPlayView()
                .interactiveDismissDisabled()
                .presentationDetents([.large])
        }
    }

    @ViewBuilder
    private var panel: some View {
        switch store.tab {
        case .build:
            VStack(spacing: 0) {
                ScrollView {
                    if let design, design.holes.indices.contains(store.selectedHole) {
                        HoleCardView(design: design, holeIndex: store.selectedHole, playtest: store.playtest)
                            .padding(12)
                    }
                }
                .background(Color(uiColor: .secondarySystemBackground))
                BuildBar()
            }
        case .run: RunPanel()
        case .club: ClubPanel()
        case .reviews: ReviewsPanel()
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                store.stopWatching()
                store.save()
                store.screen = .start
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Back to the start screen")
            VStack(alignment: .leading, spacing: 1) {
                Text(store.plot?.name ?? "").font(.headline).lineLimit(1)
                Text("\(store.dateLabel) · \(store.clockLabel) · \(store.course?.isOpen == true ? "Open" : "Closed")")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Money.text(store.engine?.state.cash ?? 0))
                .font(.headline.monospacedDigit())
                .foregroundStyle((store.engine?.state.cash ?? 0) < 0 ? Color.red : Color.primary)
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
                            .background(Palette.rating(score).opacity(i == store.selectedHole ? 1 : 0.55))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(i == store.selectedHole ? Color.primary : .clear, lineWidth: 2)
                            )
                        }
                        .disabled(store.watching != nil)
                        .accessibilityLabel("Hole \(i + 1), rated \(String(format: "%.1f", score))")
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

    // MARK: Sound

    private func startAmbience() {
        guard let plot = store.plot else { return }
        var beds: [String]
        switch plot.land {
        case .links: beds = ["amb_sea", "amb_wind"]
        case .moorland: beds = ["amb_wind", "amb_birdsong"]
        default: beds = ["amb_birdsong"]
        }
        if store.course?.weather == .wind || store.course?.weather == .storm, !beds.contains("amb_wind") { beds.append("amb_wind") }
        if store.course?.weather == .rain || store.course?.weather == .storm { beds.removeAll { $0 == "amb_birdsong" } }
        SoundBoard.shared.playAmbience(beds)
    }

    // MARK: Scene wiring

    private func connectScene() {
        scene.onPaint = { point in store.paint(at: point) }
        scene.onStrokeEnded = { store.endStroke() }
        scene.onSwipe = { step in
            guard store.watching == nil, let count = store.course?.holes.count else { return }
            store.selectHole(min(max(store.selectedHole + step, 0), count - 1))
        }
        scene.paintMode = store.mode != .look
        redraw(resetCamera: true)
    }

    private func redraw(resetCamera: Bool) {
        guard let hole = store.currentHole, let plot = store.plot, let course = store.course else { return }
        let club = store.selectedHole == 0
            ? ClubhouseArtist.Club(clubhouse: course.facilities.clubhouse, shop: course.facilities.shop, range: course.facilities.range,
                                   north: plot.lat >= 54, carsParked: min(12, 2 + course.today.rounds / 6))
            : nil
        scene.show(hole, land: plot.land, seed: HoleImageRenderer.seed(plotID: plot.id, hole: store.selectedHole),
                   condition: course.condition, club: club, resetCamera: resetCamera)
    }
}

/// Percy's commentary box while watching a round.
struct PercyBox: View {
    @Environment(GameStore.self) private var store
    let watching: GameStore.Watching

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Percy Hollis").font(.caption.bold())
                Spacer()
                Text("\(watching.round.golfer.name) · Hole \(watching.holeIndex + 1), par \(watching.round.holes[safe: watching.holeIndex]?.par ?? 0) · \(watching.strokesThisHole) so far")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(watching.line)
                .font(.system(.subheadline, design: .serif).italic())
                .fixedSize(horizontal: false, vertical: true)
            if let previous = watching.previousLine {
                Text(previous)
                    .font(.system(.caption, design: .serif).italic())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack {
                Spacer()
                Button(watching.finished ? "Done" : "Stop watching") { store.stopWatching() }
                    .font(.caption.bold())
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(8)
        .animation(.easeInOut(duration: 0.2), value: watching.line)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
