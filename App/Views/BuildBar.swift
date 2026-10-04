import GameCore
import SwiftUI

/// A first, plain version of the Build tools. Milestone 2 replaces it with the real
/// toolset (curved fairway brush, ring the green with water, bunker stamps).
struct BuildBar: View {
    @Environment(GameStore.self) private var store

    private struct ToolChoice: Identifiable {
        let id: String
        let label: String
        let symbol: String
        let tool: BuildTool?
    }

    private let tools: [ToolChoice] = [
        ToolChoice(id: "look", label: "Look", symbol: "hand.draw", tool: nil),
        ToolChoice(id: "fairway", label: "Fairway", symbol: "rectangle.fill", tool: .paint(.fairway)),
        ToolChoice(id: "green", label: "Green", symbol: "circle.fill", tool: .paint(.green)),
        ToolChoice(id: "bunker", label: "Bunker", symbol: "circle.dotted", tool: .paint(.bunker)),
        ToolChoice(id: "water", label: "Water", symbol: "drop.fill", tool: .paint(.water)),
        ToolChoice(id: "trees", label: "Trees", symbol: "tree.fill", tool: .paint(.trees)),
        ToolChoice(id: "rough", label: "Rough", symbol: "eraser", tool: .paint(.rough)),
        ToolChoice(id: "tee", label: "Tee", symbol: "t.square", tool: .tee),
        ToolChoice(id: "pin", label: "Pin", symbol: "flag.fill", tool: .pin),
    ]

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(tools) { choice in
                        Button {
                            store.endStroke()
                            store.tool = choice.tool
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: choice.symbol).font(.body)
                                Text(choice.label).font(.caption2)
                            }
                            .frame(width: 54, height: 44)
                            .background(store.tool == choice.tool ? Color.accentColor.opacity(0.25) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 8))
                        }
                        .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal, 8)
            }
            HStack(spacing: 10) {
                Button {
                    store.undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(!store.canUndo)

                Toggle(isOn: $store.largeBrush) {
                    Text("Big brush")
                }
                .toggleStyle(.button)

                Spacer()

                Menu {
                    Button("Auto layout this hole") { store.relayHole(signature: false) }
                    Button("Signature layout (debug)") { store.relayHole(signature: true) }
                } label: {
                    Label("Layout", systemImage: "wand.and.stars")
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .background(.bar)
    }
}
