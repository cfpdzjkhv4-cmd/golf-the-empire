import GameCore
import SwiftUI

/// Build tools: brushes that follow your finger, quick helpers for greens, and bunker stamps.
struct BuildBar: View {
    @Environment(GameStore.self) private var store

    private struct ToolChoice: Identifiable {
        let id: String
        let label: String
        let symbol: String
        let mode: GameStore.BuildMode
    }

    private let tools: [ToolChoice] = [
        ToolChoice(id: "look", label: "Look", symbol: "hand.draw", mode: .look),
        ToolChoice(id: "fairway", label: "Fairway", symbol: "scribble.variable", mode: .brush(.fairway)),
        ToolChoice(id: "green", label: "Green", symbol: "circle.fill", mode: .brush(.green)),
        ToolChoice(id: "bunker", label: "Sand", symbol: "circle.dotted", mode: .brush(.bunker)),
        ToolChoice(id: "water", label: "Water", symbol: "drop.fill", mode: .brush(.water)),
        ToolChoice(id: "trees", label: "Trees", symbol: "tree.fill", mode: .brush(.trees)),
        ToolChoice(id: "rough", label: "Rough", symbol: "eraser", mode: .brush(.rough)),
        ToolChoice(id: "tee", label: "Tee", symbol: "t.square", mode: .tee),
        ToolChoice(id: "pin", label: "Pin", symbol: "flag.fill", mode: .pin),
    ]

    private let stampNames = ["pot": "Pot bunker", "pair": "Pair of pots", "kidney": "Kidney bunker",
                              "showcase": "Showcase bunker", "waste": "Waste area"]

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(tools) { choice in
                        Button {
                            store.setMode(choice.mode)
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: choice.symbol).font(.body)
                                Text(choice.label).font(.caption2)
                            }
                            .frame(width: 54, height: 44)
                            .background(store.mode == choice.mode ? Color.accentColor.opacity(0.25) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 8))
                        }
                        .foregroundStyle(.primary)
                        .accessibilityLabel(choice.label)
                    }
                }
                .padding(.horizontal, 8)
            }
            HStack(spacing: 12) {
                Button {
                    store.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!store.canUndo)
                .accessibilityLabel("Undo")

                Picker("Brush", selection: $store.brushSize) {
                    Text("S").tag(0)
                    Text("M").tag(1)
                    Text("L").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
                .accessibilityLabel("Brush size")

                Menu {
                    ForEach(store.engine?.stampIDs ?? [], id: \.self) { id in
                        Button(stampNames[id] ?? id) { store.setMode(.stamp(id)) }
                    }
                } label: {
                    Label("Stamp", systemImage: "seal")
                }

                Menu {
                    Button("Island green (water all round)") { store.ringGreen(with: .water, style: .all) }
                    Button("Water in front of the green") { store.ringGreen(with: .water, style: .front) }
                    Button("Bunkers round the green") { store.ringGreen(with: .bunker, style: .all) }
                    Button("Sand in front of the green") { store.ringGreen(with: .bunker, style: .front) }
                    Divider()
                    Button("Auto layout this hole") { store.relayHole(signature: false) }
                    #if DEBUG
                    Button("Signature layout (debug)") { store.relayHole(signature: true) }
                    #endif
                } label: {
                    Label("Green", systemImage: "wand.and.stars")
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            if case .stamp(let id) = store.mode {
                Text("Tap the course to place a \(stampNames[id]?.lowercased() ?? id).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .background(.bar)
    }
}
