import SwiftUI

/// Debug screen: every manifest asset by id, so Harry can review the pack on his phone
/// and ask for changes by id ("make icon_inbox rounder").
struct AssetGalleryView: View {
    @Environment(GameStore.self) private var store
    @State private var search = ""
    @State private var showOnly = "All"

    private var library: AssetLibrary { .shared }
    private let filters = ["All", "Placeholder", "Final", "Missing"]

    private func matches(_ e: AssetLibrary.Entry) -> Bool {
        let statusOK = showOnly == "All" || e.status == showOnly.lowercased()
        let searchOK = search.isEmpty || e.id.localizedCaseInsensitiveContains(search)
            || e.description.localizedCaseInsensitiveContains(search)
        return statusOK && searchOK
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Show", selection: $showOnly) {
                        ForEach(filters, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(summary).font(.caption).foregroundStyle(.secondary)
                }
                ForEach(library.categories, id: \.self) { category in
                    let items = library.entries.filter { $0.category == category && matches($0) }
                    if !items.isEmpty {
                        Section(category) {
                            ForEach(items) { entry in
                                NavigationLink(value: entry) { AssetRow(entry: entry) }
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search by id or description")
            .navigationTitle("Asset gallery")
            .navigationDestination(for: AssetLibrary.Entry.self) { AssetDetailView(entry: $0) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { store.screen = .start }
                }
            }
        }
    }

    private var summary: String {
        let all = library.entries
        let count = { (s: String) in all.filter { $0.status == s }.count }
        return "\(all.count) assets: \(count("final")) final, \(count("placeholder")) placeholders, \(count("missing")) still to make, \(count("cut")) cut."
    }
}

private struct AssetRow: View {
    let entry: AssetLibrary.Entry

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if entry.kind == "image" {
                    Image(uiImage: AssetLibrary.shared.image(entry.id))
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                } else {
                    Image(systemName: entry.kind == "audio" ? "waveform" : entry.kind == "cut" ? "xmark" : "camera")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.id).font(.subheadline.monospaced())
                Text(entry.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Text(entry.status)
                .font(.caption2)
                .foregroundStyle(entry.status == "final" ? Color.green : Color.secondary)
        }
    }
}

private struct AssetDetailView: View {
    let entry: AssetLibrary.Entry

    var body: some View {
        List {
            if entry.kind == "image" {
                Image(uiImage: AssetLibrary.shared.image(entry.id))
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxHeight: 320)
                    .frame(maxWidth: .infinity)
            }
            LabeledContent("Id", value: entry.id)
            LabeledContent("Status", value: entry.status)
            LabeledContent("Priority", value: entry.priority)
            LabeledContent("Size", value: entry.sizePt)
            LabeledContent("Frames", value: entry.frames)
            LabeledContent("Variants", value: entry.variants)
            LabeledContent("Format", value: entry.format)
            Section("Description") { Text(entry.description) }
            Section("How it's made") { Text(entry.source) }
            if !entry.notes.isEmpty { Section("Notes") { Text(entry.notes) } }
        }
        .navigationTitle(entry.id)
        .navigationBarTitleDisplayMode(.inline)
    }
}
