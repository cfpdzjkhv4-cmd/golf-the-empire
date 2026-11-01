import CourseArt
import GameCore
import SwiftUI

/// What's open over the map. The clock pauses while anything is.
enum MapSheet: Identifiable, Equatable {
    case plot(String)
    case market
    case clubs
    case letters
    case goals
    case news

    var id: String {
        switch self {
        case .plot(let id): "plot-\(id)"
        case .market: "market"
        case .clubs: "clubs"
        case .letters: "letters"
        case .goals: "goals"
        case .news: "news"
        }
    }
}

/// The home screen of a career: an illustrated map of Britain with land for sale, your clubs and your rivals'.
struct MapScreen: View {
    @Environment(GameStore.self) private var store
    @State private var sheet: MapSheet?
    @State private var zoom: CGFloat = 1
    @State private var settledZoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var settledPan: CGSize = .zero
    @AppStorage("showGreatClubs") private var showGreatClubs = true

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            MapHeader(sheet: $sheet)
            GeometryReader { geo in
                ZStack {
                    Color(MapStyle.sea)
                    BritainMap(zoom: zoom, pan: pan, size: geo.size)
                    pins(in: geo.size)
                }
                .clipped()
                .contentShape(Rectangle())
                .gesture(mapGestures)
            }
            ticker
            HStack(spacing: 10) {
                Button {
                    sheet = .market
                } label: {
                    Label("Land for sale (\(store.engine?.state.market.listings.count ?? 0))", systemImage: "signpost.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    sheet = .clubs
                } label: {
                    Label("My clubs (\(store.engine?.state.courses.count ?? 0))", systemImage: "flag")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
        }
        .sheet(item: $sheet) { which in
            MapSheetContent(which: which, sheet: $sheet)
                .presentationDetents(detents(for: which))
        }
        .onChange(of: sheet) { store.mapSheetOpen = sheet != nil }
        .onAppear { store.mapSheetOpen = sheet != nil }
    }

    private func detents(for which: MapSheet) -> Set<PresentationDetent> {
        if case .plot = which { return [.medium, .large] }
        return [.large]
    }

    // MARK: Pins

    @ViewBuilder
    private func pins(in size: CGSize) -> some View {
        if let engine = store.engine {
            let projection = MapProjection(map: store.data.map, size: size, zoom: zoom, pan: pan)
            ForEach(pinList(engine), id: \.plot.id) { pin in
                Button {
                    sheet = .plot(pin.plot.id)
                } label: {
                    MapPin(kind: pin.kind)
                }
                .position(projection.point(lat: pin.plot.lat, lon: pin.plot.lon))
                .accessibilityLabel("\(pin.plot.name), \(pin.kind.description)")
            }
        }
    }

    private struct PinItem {
        let plot: Plot
        let kind: MapPin.Kind
    }

    private func pinList(_ engine: GameEngine) -> [PinItem] {
        var items: [PinItem] = []
        let s = engine.state
        for id in store.data.plotOrder {
            guard let plot = store.data.plot(id) else { continue }
            if s.courses[id] != nil {
                items.append(PinItem(plot: plot, kind: .mine))
            } else if let rc = s.rivalCourses[id] {
                let colour = store.data.rivals.first { $0.id == rc.owner }?.colour ?? "#555555"
                items.append(PinItem(plot: plot, kind: .rival(colour)))
            } else if let l = s.market.listings[id] {
                items.append(PinItem(plot: plot, kind: l.builtCourse ? .administration : l.kind == .quiet ? .quiet : .sealed))
            } else if plot.isLegendary && showGreatClubs {
                items.append(PinItem(plot: plot, kind: .legendary))
            }
        }
        // Draw the important ones last, so they sit on top.
        return items.sorted { $0.kind.layer < $1.kind.layer }
    }

    // MARK: Gestures

    private var mapGestures: some Gesture {
        SimultaneousGesture(
            MagnifyGesture()
                .onChanged { value in zoom = min(6, max(1, settledZoom * value.magnification)) }
                .onEnded { _ in settledZoom = zoom },
            DragGesture()
                .onChanged { value in
                    pan = CGSize(width: settledPan.width + value.translation.width, height: settledPan.height + value.translation.height)
                }
                .onEnded { _ in settledPan = pan }
        )
    }

    // MARK: News ticker

    private var ticker: some View {
        Button {
            sheet = .news
        } label: {
            HStack(spacing: 8) {
                Text("Golf Gazette").font(.caption.bold()).foregroundStyle(Palette.gold)
                Text(store.engine?.state.news.first?.text ?? "")
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemBackground))
        }
        .accessibilityLabel("News: \(store.engine?.state.news.first?.text ?? "")")
    }
}

/// Date, clock, cash, speed and the letters and goals buttons.
struct MapHeader: View {
    @Environment(GameStore.self) private var store
    @Binding var sheet: MapSheet?

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Menu {
                    Button("Goals") { sheet = .goals }
                    Button("Save and go to the start screen") {
                        store.save()
                        store.screen = .start
                    }
                } label: {
                    Image(systemName: "line.3.horizontal").font(.title3)
                }
                .accessibilityLabel("Menu")
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.dateLabel).font(.headline)
                    Text(store.clockLabel).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                Spacer()
                Text(Money.text(store.engine?.state.cash ?? 0))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle((store.engine?.state.cash ?? 0) < 0 ? Color.red : Color.primary)
                Button {
                    sheet = .letters
                } label: {
                    Image(systemName: "envelope").font(.title3)
                        .overlay(alignment: .topTrailing) {
                            if store.unreadLetters > 0 {
                                Text("\(store.unreadLetters)").font(.caption2.bold()).foregroundStyle(.white)
                                    .padding(3).background(Circle().fill(Color.red)).offset(x: 8, y: -8)
                            }
                        }
                }
                .accessibilityLabel("Letters, \(store.unreadLetters) unread")
            }
            Picker("Speed", selection: $store.speedIndex) {
                ForEach(store.speeds.indices, id: \.self) { i in
                    Text(store.speeds[i] == 0 ? "Pause" : "\(store.speeds[i])x").tag(i)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: Drawing the map

enum MapStyle {
    static let sea = RGBA(hex: ArtStyle.shared.mapColour("sea"))
    static let land = RGBA(hex: "#E3E3C6")
    static let coast = RGBA(hex: "#7E8E6E")
    static let city = RGBA(hex: ArtStyle.shared.mapColour("label"))
}

/// Turns latitude and longitude into points on screen, fitting Britain to the view and applying zoom and pan.
struct MapProjection {
    let size: CGSize
    let zoom: CGFloat
    let pan: CGSize
    /// The map's area in map units (see MapArtist), and how it is fitted to the view.
    let bounds: (minX: Double, minY: Double, width: Double, height: Double)
    let scale: Double
    private let offsetX: Double, offsetY: Double

    init(map: MapData, size: CGSize, zoom: CGFloat, pan: CGSize) {
        self.size = size
        self.zoom = zoom
        self.pan = pan
        bounds = MapArtist.bounds(map)
        // Fill the view, cropping a little sea rather than leaving bands.
        scale = max(Double(size.width) / bounds.width, Double(size.height) / bounds.height)
        offsetX = (Double(size.width) - bounds.width * scale) / 2
        offsetY = (Double(size.height) - bounds.height * scale) / 2
    }

    /// A point in map units to a point on screen, after zoom (about the centre of the view) and pan.
    func point(x: Double, y: Double) -> CGPoint {
        let sx = offsetX + (x - bounds.minX) * scale
        let sy = offsetY + (y - bounds.minY) * scale
        let cx = Double(size.width) / 2, cy = Double(size.height) / 2
        return CGPoint(x: cx + (sx - cx) * Double(zoom) + Double(pan.width), y: cy + (sy - cy) * Double(zoom) + Double(pan.height))
    }

    func point(lat: Double, lon: Double) -> CGPoint {
        point(x: MapArtist.x(lon), y: MapArtist.y(lat))
    }
}

/// The illustrated map, drawn once by CourseArt's MapArtist and then scaled; city names stay crisp on top.
@MainActor
enum MapImage {
    private static var image: UIImage?

    static func get(_ map: MapData) -> UIImage {
        if let image { return image }
        let b = MapArtist.bounds(map)
        let ops = MapArtist().paint(map).map { $0.translated(-b.minX, -b.minY) }
        let made = HoleImageRenderer.render(ops, size: CGSize(width: b.width * 1.5, height: b.height * 1.5), unit: 1.5, opaque: true)
        image = made
        return made
    }
}

struct BritainMap: View {
    @Environment(GameStore.self) private var store
    let zoom: CGFloat
    let pan: CGSize
    let size: CGSize

    var body: some View {
        let map = store.data.map
        let projection = MapProjection(map: map, size: size, zoom: zoom, pan: pan)
        let b = projection.bounds
        ZStack {
            Image(uiImage: MapImage.get(map))
                .resizable()
                .interpolation(.high)
                .frame(width: b.width * projection.scale * zoom, height: b.height * projection.scale * zoom)
                .position(projection.point(x: b.minX + b.width / 2, y: b.minY + b.height / 2))
            Canvas { ctx, _ in
                for city in map.cities {
                    let pt = projection.point(lat: city.lat, lon: city.lon)
                    ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 2.5, y: pt.y - 2.5, width: 5, height: 5)), with: .color(Color(MapStyle.city)))
                    ctx.draw(Text(city.name).font(.system(size: 10 + min(4, zoom), weight: .medium, design: .serif)).italic()
                                .foregroundColor(Color(MapStyle.city)),
                             at: CGPoint(x: pt.x + 5, y: pt.y), anchor: .leading)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}

/// A map pin, coloured by what's there.
struct MapPin: View {
    enum Kind: Equatable {
        case quiet, sealed, administration, mine, rival(String), legendary

        var description: String {
            switch self {
            case .quiet: "for sale"
            case .sealed: "sealed bids"
            case .administration: "in administration"
            case .mine: "your club"
            case .rival: "a rival's club"
            case .legendary: "a great private club"
            }
        }

        var layer: Int {
            switch self {
            case .legendary: 0
            case .rival: 1
            case .quiet, .sealed, .administration: 2
            case .mine: 3
            }
        }
    }

    let kind: Kind

    var body: some View {
        ZStack {
            Circle().fill(fill).frame(width: size, height: size)
            Circle().stroke(rim, lineWidth: 2.5).frame(width: size, height: size)
            if let symbol {
                Image(systemName: symbol).font(.system(size: size * 0.45, weight: .bold)).foregroundStyle(symbolColour)
            }
        }
        .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }

    private var size: CGFloat {
        switch kind {
        case .legendary: 12
        case .mine: 22
        default: 18
        }
    }

    private var fill: Color {
        switch kind {
        case .mine: Palette.gold
        case .rival(let hex): Color(RGBA(hex: hex))
        case .legendary: Color(RGBA(hex: "#1E2B4A"))
        default: .white
        }
    }

    private var rim: Color {
        switch kind {
        case .quiet: Color(RGBA(hex: "#2E6B45"))
        case .sealed: Color(RGBA(hex: "#2F6DB5"))
        case .administration: Color(RGBA(hex: "#B5523B"))
        case .legendary: Palette.gold
        case .mine: .white
        case .rival: .white
        }
    }

    private var symbol: String? {
        switch kind {
        case .quiet: "sterlingsign"
        case .sealed: "envelope.fill"
        case .administration: "exclamationmark"
        case .mine: "flag.fill"
        default: nil
        }
    }

    private var symbolColour: Color {
        switch kind {
        case .mine: .white
        default: rim
        }
    }
}
