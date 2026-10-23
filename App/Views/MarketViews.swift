import CourseArt
import GameCore
import SwiftUI

/// Routes each map sheet to its screen.
struct MapSheetContent: View {
    let which: MapSheet
    @Binding var sheet: MapSheet?

    var body: some View {
        switch which {
        case .plot(let id): PlotDetailView(plotID: id, sheet: $sheet)
        case .market: MarketListView(sheet: $sheet)
        case .clubs: MyClubsView(sheet: $sheet)
        case .letters: LettersView()
        case .goals: GoalsView()
        case .news: NewsView()
        }
    }
}

// MARK: Aerial photos

/// An "aerial photo" of a plot: the land itself drawn in the house style. Cached per plot.
@MainActor
enum PlotPhoto {
    private static var cache: [String: UIImage] = [:]

    static func image(_ plot: Plot, built: Bool, data: GameData) -> UIImage {
        let key = plot.id + (built ? "-built" : "")
        if let cached = cache[key] { return cached }
        let seed = HoleImageRenderer.seed(plotID: plot.id, hole: 99)
        var rng = SeededRandom(seed: seed)
        let generator = HoleGenerator(balance: data.balance)
        var hole = generator.baseLand(plot.land, rng: &rng)
        if built { hole = generator.autoLayout(par: 4, land: plot.land, on: hole, rng: &rng) }
        if plot.land == .links { for x in 0..<hole.columns { hole.set(x, 0, .sea) } }
        let image = HoleImageRenderer.image(for: hole, land: plot.land, seed: seed, condition: built ? 60 : 85, club: nil, pointsPerTile: 8)
        cache[key] = image
        return image
    }
}

struct PlotPhotoView: View {
    @Environment(GameStore.self) private var store
    let plot: Plot
    let built: Bool
    var height: CGFloat = 120

    var body: some View {
        Image(uiImage: PlotPhoto.image(plot, built: built, data: store.data))
            .resizable()
            .scaledToFill()
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipped()
            .accessibilityHidden(true)
    }
}

// MARK: Words for numbers

enum PlotWords {
    static func demand(_ d: Double) -> String {
        d >= 5 ? "Very busy area: lots of golfers" : d >= 3.5 ? "Busy area" : d >= 2 ? "Steady local demand" : "Quiet, out of the way"
    }

    static func wealth(_ w: Double) -> String {
        w >= 1.5 ? "Wealthy golfers: high green fees" : w >= 1.1 ? "Comfortable golfers" : w >= 0.8 ? "Modest green fees" : "Cheap and cheerful"
    }

    static func prestige(_ p: Double) -> String? {
        p >= 1.4 ? "Championship pedigree land" : p >= 1.25 ? "Land with a bit of history" : nil
    }

    static func region(_ plot: Plot) -> String {
        switch plot.lat {
        case 55.8...: "Scotland"
        case 54.2...: "The north"
        case 52.6...: "Midlands and north west"
        default: plot.lon < -3 ? "Wales and the south west" : "The south"
        }
    }
}

// MARK: Land for sale

struct MarketListView: View {
    @Environment(GameStore.self) private var store
    @Binding var sheet: MapSheet?
    @State private var sort = Sort.newest
    @State private var land: LandKind?
    @State private var holes = 0
    @State private var favouritesOnly = false

    enum Sort: String, CaseIterable, Identifiable {
        case newest = "Newest", cheapest = "Lowest price", dearest = "Highest price", closing = "Closing soon"
        var id: String { rawValue }
    }

    private var listings: [Listing] {
        guard let engine = store.engine else { return [] }
        var all = Array(engine.state.market.listings.values)
        if let land { all = all.filter { store.data.plot($0.plotID)?.land == land } }
        if holes > 0 { all = all.filter { store.data.plot($0.plotID)?.holes == holes } }
        if favouritesOnly { all = all.filter { engine.state.favourites.contains($0.plotID) } }
        switch sort {
        case .newest: return all.sorted { ($0.listedDay, $0.plotID) > ($1.listedDay, $1.plotID) }
        case .cheapest: return all.sorted { price($0) < price($1) }
        case .dearest: return all.sorted { price($0) > price($1) }
        case .closing: return all.sorted { ($0.closesDay ?? $0.expiresDay ?? 9999) < ($1.closesDay ?? $1.expiresDay ?? 9999) }
        }
    }

    private func price(_ l: Listing) -> Int { l.kind == .quiet ? l.askingPrice : l.guide }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    filters
                    if listings.isEmpty {
                        Text("Nothing matches. New land comes up every few days.")
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    }
                    ForEach(listings) { l in
                        if let plot = store.data.plot(l.plotID) {
                            Button {
                                sheet = .plot(l.plotID)
                            } label: {
                                ListingCard(listing: l, plot: plot)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Land for sale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Map") { sheet = nil } }
            }
            .safeAreaInset(edge: .top) {
                Text("Bramble & Pike, land agents to the golfing trade")
                    .font(.system(.caption, design: .serif).italic())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(.bar)
            }
        }
    }

    private var filters: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    chip("All land", selected: land == nil) { land = nil }
                    ForEach(LandKind.allCases, id: \.self) { kind in
                        chip(store.data.landTypes[kind]?.name ?? kind.rawValue, selected: land == kind) { land = land == kind ? nil : kind }
                    }
                    chip("9 holes", selected: holes == 9) { holes = holes == 9 ? 0 : 9 }
                    chip("18 holes", selected: holes == 18) { holes = holes == 18 ? 0 : 18 }
                    chip("♥ Saved", selected: favouritesOnly) { favouritesOnly.toggle() }
                }
            }
            Picker("Sort", selection: $sort) {
                ForEach(Sort.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Palette.accent : Color(uiColor: .secondarySystemBackground), in: Capsule())
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
    }
}

/// A listing card, property site style: photo, price, tags and the facts.
struct ListingCard: View {
    @Environment(GameStore.self) private var store
    let listing: Listing
    let plot: Plot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                PlotPhotoView(plot: plot, built: listing.builtCourse, height: 130)
                HStack(spacing: 4) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                .padding(8)
                HStack {
                    Spacer()
                    Button {
                        store.toggleFavourite(plot.id)
                    } label: {
                        Image(systemName: isFavourite ? "heart.fill" : "heart")
                            .font(.title3)
                            .foregroundStyle(isFavourite ? Color.red : Color.white)
                            .shadow(radius: 2)
                            .padding(10)
                    }
                    .accessibilityLabel(isFavourite ? "Remove from saved" : "Save")
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Money.text(listing.kind == .quiet ? listing.askingPrice : listing.guide))
                        .font(.title3.bold().monospacedDigit())
                    Text(listing.kind == .quiet ? "Asking price" : "Guide price")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if listing.myOffer != nil {
                        Label("Offer in", systemImage: "checkmark.seal.fill").font(.caption.bold()).foregroundStyle(Palette.accent)
                    }
                }
                Text(plot.name).font(.headline)
                Text("\(store.data.landTypes[plot.land]?.name ?? "") · \(plot.holes) holes · \(plot.area)")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(saleLine).font(.caption).foregroundStyle(listing.kind == .sealed ? Color(RGBA(hex: "#2F6DB5")) : Palette.accent)
            }
            .padding(12)
        }
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .accessibilityElement(children: .combine)
    }

    private var isFavourite: Bool { store.engine?.state.favourites.contains(plot.id) ?? false }

    private var tags: [String] {
        var t: [String] = []
        let day = store.engine?.state.day ?? 0
        if listing.backOnMarket { t.append("Back on the market") } else if day - listing.listedDay <= 3 { t.append("New") }
        if listing.reduced { t.append("Reduced") }
        if listing.builtCourse { t.append("Built course") }
        if !listing.rumoured.isEmpty { t.append("Rival interest") }
        return t
    }

    private var saleLine: String {
        guard let engine = store.engine else { return "" }
        switch listing.kind {
        case .quiet:
            let left = (listing.expiresDay ?? engine.state.day) - engine.state.day
            return "Buy outright. " + (left <= 2 ? "Could be withdrawn any day." : "On the market now.")
        case .sealed:
            return "Sealed bids close \(engine.calendar.shortLabel(day: listing.closesDay ?? engine.state.day))."
        }
    }
}

// MARK: One plot

struct PlotDetailView: View {
    @Environment(GameStore.self) private var store
    let plotID: String
    @Binding var sheet: MapSheet?
    @State private var offer = 0
    @State private var confirmBuy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let engine = store.engine, let plot = store.data.plot(plotID) {
                    VStack(alignment: .leading, spacing: 12) {
                        PlotPhotoView(plot: plot, built: engine.state.market.listings[plotID]?.builtCourse ?? (engine.state.courses[plotID] != nil),
                                      height: 170)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Text(plot.area).font(.subheadline).foregroundStyle(.secondary)
                        status(engine, plot)
                        facts(engine, plot)
                    }
                    .padding(16)
                }
            }
            .navigationTitle(store.data.plot(plotID)?.name ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { sheet = nil } }
            }
        }
    }

    @ViewBuilder
    private func status(_ engine: GameEngine, _ plot: Plot) -> some View {
        let s = engine.state
        if s.courses[plotID] != nil {
            Text("Your club.").font(.headline)
            Button {
                sheet = nil
                store.openCourse(plotID)
            } label: {
                Text("Go to the course").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        } else if let rc = s.rivalCourses[plotID], let rival = store.data.rivals.first(where: { $0.id == rc.owner }) {
            Text("Owned by \(rival.name)").font(.headline)
            Text(rival.blurb).font(.subheadline).foregroundStyle(.secondary)
            Text(String(format: "Reputation %.1f of 10. A rival club takes golfers from your courses within about 100 km, more so the better it is.", rc.reputation * 2))
                .font(.caption).foregroundStyle(.secondary)
        } else if let l = s.market.listings[plotID] {
            listing(l, engine)
        } else if plot.isLegendary {
            Text("A private club, not for sale").font(.headline)
            Text("One of the great venues of British golf, finished and run at the very highest level. Its last valuation was \(Money.text(plot.legendaryGuide ?? 0)).")
                .font(.subheadline).foregroundStyle(.secondary)
        } else {
            Text("Not on the market at the moment.").font(.headline)
        }
    }

    @ViewBuilder
    private func listing(_ l: Listing, _ engine: GameEngine) -> some View {
        let price = l.kind == .quiet ? l.askingPrice : l.guide
        HStack(alignment: .firstTextBaseline) {
            Text(Money.text(price)).font(.title.bold().monospacedDigit())
            Text(l.kind == .quiet ? (l.reduced ? "Reduced, buy outright" : "Buy outright") : "Guide, sealed bids")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        if l.builtCourse {
            Text("Sold as a going concern: a laid out course with a basic clubhouse, in need of some love.")
                .font(.subheadline)
        }
        if !l.rumoured.isEmpty {
            let names = l.rumoured.compactMap { id in store.data.rivals.first { $0.id == id }?.shortName }
            Text("Word is \(names.joined(separator: " and ")) \(names.count == 1 ? "is" : "are") interested.")
                .font(.subheadline).foregroundStyle(Color(RGBA(hex: "#B5523B")))
        }
        switch l.kind {
        case .quiet:
            Button {
                confirmBuy = true
            } label: {
                Text("Buy for \(Money.text(price))").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(engine.state.cash < price)
            .confirmationDialog("Buy \(store.data.plot(plotID)?.name ?? "") for \(Money.text(price))?", isPresented: $confirmBuy, titleVisibility: .visible) {
                Button("Buy it") {
                    if store.buyNow(plotID) {
                        sheet = nil
                        store.openCourse(plotID)
                    }
                }
            }
            if engine.state.cash < price {
                Text("You have \(Money.text(engine.state.cash)).").font(.caption).foregroundStyle(.secondary)
            }
        case .sealed:
            VStack(alignment: .leading, spacing: 8) {
                Text("Bids close \(engine.calendar.longLabel(day: l.closesDay ?? engine.state.day)). One offer each, opened after close. The highest offer over the reserve wins, and you must have the cash on the day.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button { offer = max(engine.minimumOffer(l), offer - store.data.balance.market.offerStep) } label: { Image(systemName: "minus.circle").font(.title2) }
                        .accessibilityLabel("Lower the offer")
                    Spacer()
                    Text(Money.text(offer)).font(.title2.bold().monospacedDigit())
                    Spacer()
                    Button { offer += store.data.balance.market.offerStep } label: { Image(systemName: "plus.circle").font(.title2) }
                        .accessibilityLabel("Raise the offer")
                }
                Button {
                    store.placeOffer(plotID, amount: offer)
                } label: {
                    Text(l.myOffer == nil ? "Submit offer" : "Change offer").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                if let mine = l.myOffer {
                    HStack {
                        Text("Your offer: \(Money.text(mine))").font(.subheadline.bold())
                        Spacer()
                        Button("Withdraw", role: .destructive) { store.withdrawOffer(plotID) }
                    }
                }
            }
            .onAppear { offer = l.myOffer ?? l.guide }
        }
    }

    @ViewBuilder
    private func facts(_ engine: GameEngine, _ plot: Plot) -> some View {
        let landType = store.data.landTypes[plot.land]
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("Key facts").font(.headline)
            fact("map", "\(plot.holes) holes of \(landType?.name.lowercased() ?? "") land, \(PlotWords.region(plot).lowercased())")
            fact("leaf", landType?.description ?? "")
            fact("person.3", PlotWords.demand(plot.demand))
            fact("sterlingsign.circle", PlotWords.wealth(plot.wealth))
            if let p = PlotWords.prestige(plot.prestige) { fact("trophy", p) }
            if plot.land == .links { fact("water.waves", "Coastal: the sea, the wind and the odd storm come with it") }
            let rivals = engine.nearbyRivals(of: plot.id)
            if !rivals.isEmpty {
                let names = rivals.prefix(3).map { "\(store.data.plot($0.course.plotID)?.name ?? "") (\(Int($0.km)) km)" }
                fact("exclamationmark.triangle", "Rival clubs nearby: \(names.joined(separator: ", "))")
            }
        }
    }

    private func fact(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol).font(.subheadline)
    }
}

// MARK: My clubs, letters, goals, news

struct MyClubsView: View {
    @Environment(GameStore.self) private var store
    @Binding var sheet: MapSheet?

    var body: some View {
        NavigationStack {
            List {
                if let engine = store.engine {
                    if engine.state.courses.isEmpty {
                        Text("You don't own any land yet. Have a look at what's for sale.").foregroundStyle(.secondary)
                        Button("Land for sale") { sheet = .market }
                    }
                    ForEach(engine.state.orderedCourses) { course in
                        if let plot = store.data.plot(course.plotID) {
                            Button {
                                sheet = nil
                                store.openCourse(course.plotID)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(plot.name).font(.headline)
                                        Spacer()
                                        Text(course.isOpen ? "Open" : "Closed").font(.caption.bold())
                                            .foregroundStyle(course.isOpen ? Palette.accent : Color.secondary)
                                    }
                                    Text(engine.openingProblem(course.plotID).map { "Not ready: \($0.lowercased())" }
                                        ?? String(format: "Reputation %.1f · %d rounds today · %@ taken", course.reputationOutOfTen, course.today.rounds, Money.text(course.today.takings)))
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .navigationTitle("My clubs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Map") { sheet = nil } } }
        }
    }
}

struct LettersView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let engine = store.engine {
                    if engine.state.letters.isEmpty { Text("No post yet.").foregroundStyle(.secondary) }
                    ForEach(engine.state.letters) { letter in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                if !letter.read { Circle().fill(Color.blue).frame(width: 8, height: 8) }
                                Text(letter.title).font(.headline)
                            }
                            Text("\(letter.from) · \(engine.calendar.shortLabel(day: letter.day))").font(.caption).foregroundStyle(.secondary)
                            Text(letter.body).font(.subheadline)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Letters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .onDisappear { store.markLettersRead() }
        }
    }
}

struct GoalsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.data.milestones) { m in
                        let done = store.engine?.state.milestones.contains(m.id) ?? false
                        Label(m.text, systemImage: done ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(done ? Palette.accent : Color.primary)
                    }
                } footer: {
                    Text("The big one is hosting The Championship. It needs championship links land, an 18 hole course of 6,500 yards or more rated 7.5 for design, a reputation of 9 out of 10, top facilities, and a Regional Pro Am hosted there first.")
                }
            }
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct NewsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let engine = store.engine {
                    ForEach(Array(engine.state.news.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(engine.calendar.shortLabel(day: item.day)).font(.caption).foregroundStyle(.secondary)
                            Text(item.text).font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Golf Gazette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
}
