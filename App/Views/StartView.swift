import GameCore
import SwiftUI

struct StartView: View {
    @Environment(GameStore.self) private var store
    @State private var confirmNew = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // The poster: a links at dawn, with the title in the sky.
                ZStack(alignment: .top) {
                    Image(uiImage: AssetLibrary.shared.image("title_hero"))
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height * 0.58)
                        .clipped()
                        .overlay(alignment: .bottom) {
                            LinearGradient(colors: [.clear, Self.paper], startPoint: .top, endPoint: .bottom)
                                .frame(height: 60)
                        }
                        .accessibilityHidden(true)
                    VStack(spacing: 6) {
                        Text("GOLF")
                            .font(.system(size: 22, weight: .semibold, design: .serif))
                            .tracking(10)
                        Text("The Empire")
                            .font(.system(size: 46, weight: .bold, design: .serif))
                        Text("Build Britain's finest links")
                            .font(.system(.subheadline, design: .serif).italic())
                            .opacity(0.9)
                    }
                    .foregroundStyle(Color(red: 0.98, green: 0.95, blue: 0.88))
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                    .padding(.top, geo.safeAreaInsets.top + 36)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Golf: The Empire. Build Britain's finest links.")
                }
                .frame(height: geo.size.height * 0.58)

                VStack(spacing: 14) {
                    if let engine = store.engine {
                        Button {
                            store.screen = store.isCareer ? .map : .course
                        } label: {
                            VStack(spacing: 2) {
                                Text("Continue").font(.headline)
                                Text("\(engine.calendar.shortLabel(day: engine.state.day)) · \(Money.text(engine.state.cash)) · \(engine.state.courses.count == 1 ? "1 club" : "\(engine.state.courses.count) clubs")")
                                    .font(.caption)
                                    .opacity(0.85)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.accent)
                        .controlSize(.large)
                    }

                    Button {
                        if store.hasGame && !confirmNew {
                            confirmNew = true
                        } else {
                            confirmNew = false
                            store.newCareer()
                        }
                    } label: {
                        Text(confirmNew ? "Tap again to replace your saved game" : "New career")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .tint(confirmNew ? Color.red : Palette.accent)
                    .controlSize(.large)

                    Text("£200,000, no land, three rivals, and the whole of Britain for sale.")
                        .font(.system(.footnote, design: .serif).italic())
                        .foregroundStyle(Palette.ink.opacity(0.7))
                        .multilineTextAlignment(.center)

                    #if DEBUG
                    HStack {
                        Button("Sandbox course") {
                            confirmNew = false
                            store.screen = .pickPlot
                        }
                        Button("Asset gallery") { store.screen = .gallery }
                    }
                    .buttonStyle(.bordered)
                    .font(.footnote)
                    #endif
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .frame(maxWidth: 520)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Self.paper)
        }
        .ignoresSafeArea(edges: .top)
    }

    static let paper = Color(red: 0.957, green: 0.941, blue: 0.902)
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
