import GameCore
import SwiftUI

struct StartView: View {
    @Environment(GameStore.self) private var store
    @State private var confirmNew = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("Golf: The Empire")
                .font(.system(size: 38, weight: .semibold, design: .serif))
                .multilineTextAlignment(.center)
            Text("Build Britain's finest links")
                .font(.title3.italic())
                .foregroundStyle(.secondary)
            Spacer()

            if let engine = store.engine, let course = store.course, let plot = store.plot {
                Button {
                    store.screen = .course
                } label: {
                    VStack(spacing: 2) {
                        Text("Continue").font(.headline)
                        Text("\(plot.name) · \(engine.calendar.shortLabel(day: engine.state.day)) · \(Money.text(engine.state.cash))")
                            .font(.caption)
                            .opacity(0.85)
                        if course.isOpen { Text("Open for play").font(.caption2).opacity(0.7) }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Button {
                if store.hasGame && !confirmNew {
                    confirmNew = true
                } else {
                    confirmNew = false
                    store.screen = .pickPlot
                }
            } label: {
                Text(confirmNew ? "Tap again to replace your saved game" : "New sandbox course")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(confirmNew ? Color.red : Color.accentColor)

            Button("Asset gallery") { store.screen = .gallery }
                .buttonStyle(.bordered)

            Text("Milestone 1 preview. Career, challenges and the map arrive in later milestones.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: 520)
    }
}

struct PlotPickerView: View {
    @Environment(GameStore.self) private var store

    private var plots: [Plot] {
        store.data.plotOrder
            .compactMap { store.data.plot($0) }
            .filter { !$0.isLegendary }
            .sorted { $0.lat > $1.lat }
    }

    var body: some View {
        NavigationStack {
            List(plots) { plot in
                Button {
                    store.newSandbox(plotID: plot.id)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(plot.name).font(.headline)
                            Spacer()
                            Text(Money.text(store.data.basePrice(of: plot)))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Text("\(plot.area) · \(store.data.landTypes[plot.land]?.name ?? "") · \(plot.holes) holes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle("Choose a plot")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { store.screen = .start }
                }
            }
            .safeAreaInset(edge: .top) {
                Text("Sandbox: the land is free, building costs money. North to south.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
    }
}
