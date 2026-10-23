import GameCore
import SwiftUI

/// Run tab: open the course, set the fee, run the clock, watch a round.
struct RunPanel: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        @Bindable var store = store
        ScrollView {
            if let engine = store.engine, let course = store.course, let plot = store.plot, let quality = store.quality {
                let economy = engine.economy
                let fair = economy.localFairFee(course, plot: plot, quality: quality)
                let perHour = economy.groupsPerHour(course, plot: plot, quality: quality, calendar: engine.calendar, day: engine.state.day)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button(course.isOpen ? "Close the course" : "Open the course") { store.toggleOpen() }
                            .buttonStyle(.borderedProminent)
                            .tint(course.isOpen ? Color.gray : Color.green)
                        Spacer()
                        Button {
                            store.watchRound()
                        } label: {
                            Label("Watch a round", systemImage: "binoculars")
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.watching != nil)
                    }

                    HStack {
                        Text("Speed").font(.subheadline)
                        Picker("Speed", selection: $store.speedIndex) {
                            ForEach(store.speeds.indices, id: \.self) { i in
                                Text(store.speeds[i] == 0 ? "Pause" : "\(store.speeds[i])x").tag(i)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    if !course.isOpen {
                        Text("The clock runs here while the course is open. Open it to welcome golfers.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button("Skip to close of play") { store.finishDay() }
                        .font(.subheadline)

                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Green fee").font(.subheadline)
                            Text("Locals think \(Money.text(Int(fair.rounded()))) is fair")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { store.changeFee(by: -1) } label: { Image(systemName: "minus.circle") }
                            .accessibilityLabel("Lower the fee")
                        Text(Money.text(course.fee)).font(.title3.bold().monospacedDigit()).frame(minWidth: 60)
                        Button { store.changeFee(by: 1) } label: { Image(systemName: "plus.circle") }
                            .accessibilityLabel("Raise the fee")
                    }
                    .font(.title3)

                    Divider()
                    Text("Today: \(weatherText(course.weather))").font(.subheadline.bold())
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                        statRow("Rounds played", "\(course.today.rounds)")
                        statRow("Turned away (tee busy)", "\(course.today.walkedAway) groups")
                        statRow("Green fees", Money.text(course.today.greenFees))
                        statRow("Bar and shop", Money.text(course.today.barAndShop))
                        statRow("Running costs", "\(Money.text(engine.upkeep(of: course) + engine.wages(of: course))) a day")
                        statRow("Golfers expected", String(format: "%.1f groups an hour", perHour))
                    }
                    .font(.subheadline)
                    let rivals = engine.nearbyRivals(of: course.plotID)
                    if !rivals.isEmpty {
                        Text("Rival clubs nearby are taking \(Int(((1 - engine.competition(for: course.plotID)) * 100).rounded()))% of your golfers: \(rivals.prefix(3).map { store.data.plot($0.course.plotID)?.name ?? "" }.joined(separator: ", ")).")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    if let yesterday = course.yesterday {
                        Text("Yesterday: \(yesterday.rounds) rounds, \(Money.text(yesterday.takings)) taken, net \(Money.text(yesterday.net)).")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(12)
            }
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).monospacedDigit()
        }
    }

    private func weatherText(_ w: Weather) -> String {
        switch w {
        case .sun: "sunshine"
        case .cloud: "cloudy"
        case .wind: "windy"
        case .rain: "rain"
        case .storm: "storm"
        }
    }
}

/// Club tab: reputation and its ceiling, facilities, greenkeepers.
struct ClubPanel: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        ScrollView {
            if let engine = store.engine, let course = store.course, let plot = store.plot, let quality = store.quality {
                let ceiling = engine.economy.reputationCeiling(course, quality: quality)
                let next = engine.economy.nextCeiling(course, quality: quality)
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Reputation").font(.headline)
                            Spacer()
                            Text(String(format: "%.1f of 10", course.reputationOutOfTen)).monospacedDigit()
                        }
                        ProgressView(value: course.reputation, total: 5)
                        Text(String(format: "Ceiling %.1f. ", ceiling * 2) + (next.map { "To go higher: \($0.need.lowercased())." } ?? "As high as it goes."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Condition").font(.headline)
                            Spacer()
                            Text("\(Int(course.condition.rounded()))%").monospacedDigit()
                        }
                        ProgressView(value: course.condition, total: 100)
                    }

                    Divider()
                    ForEach(store.data.facilities.filter { $0.id != "staff" && ($0.linksOnly != true || plot.land == .links) }) { f in
                        let current = level(of: f.id, course)
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(f.name): \(f.levels[current])").font(.subheadline.bold())
                                Text(f.effect).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if current + 1 < f.levels.count {
                                Button("\(f.levels[current + 1]), \(Money.text(f.costs[current + 1]))") { store.upgrade(f.id) }
                                    .buttonStyle(.bordered)
                                    .font(.caption)
                                    .disabled((engine.state.cash) < f.costs[current + 1])
                            } else {
                                Text("Top level").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }

                    Divider()
                    let names = store.data.balance.greenkeepers.levels
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Greenkeepers: \(names[course.facilities.staff - 1])").font(.subheadline.bold())
                            Text("Wages \(Money.text(engine.wages(of: course))) a day. A bigger team keeps the course in better condition.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Stepper("Team size", value: Binding(
                            get: { course.facilities.staff },
                            set: { store.setStaff($0) }
                        ), in: 1...3)
                        .labelsHidden()
                    }
                }
                .padding(12)
            }
        }
    }

    private func level(of id: String, _ course: Course) -> Int {
        switch id {
        case "club": course.facilities.clubhouse
        case "shop": course.facilities.shop
        case "range": course.facilities.range
        case "sea": course.facilities.seaDefence
        default: 0
        }
    }
}

/// Reviews tab: what golfers said.
struct ReviewsPanel: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        List {
            if let course = store.course {
                if course.reviews.isEmpty {
                    Text("No reviews yet. Open the course and let some golfers play.")
                        .foregroundStyle(.secondary)
                } else {
                    let average = Double(course.reviews.reduce(0) { $0 + $1.stars }) / Double(course.reviews.count)
                    Text(String(format: "Average of the last %d: %.1f stars", course.reviews.count, average))
                        .font(.subheadline.bold())
                    ForEach(Array(course.reviews.enumerated()), id: \.offset) { _, review in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(String(repeating: "★", count: review.stars) + String(repeating: "☆", count: 5 - review.stars))
                                    .foregroundStyle(Palette.gold)
                                Text(review.golfer).font(.subheadline.bold())
                                Spacer()
                                Text("\(review.score) (\(GameEngine.relativeText(review.score - review.par)))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Text("\u{201C}\(review.quote)\u{201D}").font(.subheadline.italic())
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

/// The day's books at 19:00, with the Start button for tomorrow.
struct CloseOfPlayView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                if let engine = store.engine {
                    let books = engine.state.today
                    Section("Money in") {
                        ForEach(LedgerCategory.allCases.filter { $0.isIncome && books[$0] != 0 }, id: \.self) { row($0.label, books[$0]) }
                        row("Total in", books.moneyIn).bold()
                    }
                    Section("Money out") {
                        ForEach(LedgerCategory.allCases.filter { !$0.isIncome && books[$0] != 0 }, id: \.self) { row($0.label, books[$0]) }
                        row("Total out", books.moneyOut).bold()
                    }
                    Section {
                        row("Net for the day", books.net).bold()
                        row("In the bank", books.closingCash)
                    }
                    ForEach(engine.state.orderedCourses) { course in
                        Section(store.data.plot(course.plotID)?.name ?? "") {
                            Text("\(course.today.rounds) rounds, \(Money.text(course.today.takings)) taken, \(Money.text(course.today.costs)) costs. Reputation \(String(format: "%.1f", course.reputationOutOfTen)) of 10.")
                                .font(.subheadline)
                            if course.today.walkedAway > 0 {
                                Text("\(course.today.walkedAway) groups went home because the tee was busy.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Section("Tomorrow") {
                        Text(tomorrowNote(engine)).font(.subheadline)
                    }
                }
            }
            .navigationTitle("Close of play, \(store.dateLabel)")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    store.startNextDay()
                } label: {
                    Text("Start \(nextDateLabel)").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
            }
        }
    }

    private var nextDateLabel: String {
        guard let engine = store.engine else { return "" }
        return engine.calendar.shortLabel(day: engine.state.day + 1)
    }

    private func tomorrowNote(_ engine: GameEngine) -> String {
        let cal = engine.calendar
        let day = engine.state.day + 1
        var notes: [String] = []
        let weekday = cal.weekday(ofDay: day)
        if weekday == 6 || weekday == 0 { notes.append("It's the weekend: expect a third more golfers.") }
        if cal.seasonName(day: day) != cal.seasonName(day: engine.state.day) { notes.append("\(cal.seasonName(day: day)) starts tomorrow.") }
        if let w = engine.state.orderedCourses.first?.weather { notes.append("Forecast: \(w.rawValue).") }
        return notes.joined(separator: " ")
    }

    private func row(_ label: String, _ amount: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(Money.text(amount)).monospacedDigit()
        }
    }
}

/// Events tab: what each event needs, and booking it for tomorrow.
struct EventsPanel: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        ScrollView {
            if let engine = store.engine, let course = store.course {
                VStack(alignment: .leading, spacing: 14) {
                    if let booking = course.booking, let spec = store.data.events.first(where: { $0.id == booking.eventID }) {
                        HStack {
                            Label("\(spec.name) on \(engine.calendar.shortLabel(day: booking.day)). Closed to the public that day.", systemImage: "calendar")
                                .font(.subheadline.bold())
                            Spacer()
                            Button("Cancel", role: .destructive) { store.cancelBooking() }.font(.caption)
                        }
                    }
                    ForEach(store.data.events) { spec in
                        if let status = engine.eventStatus(courseID: course.plotID, eventID: spec.id) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(spec.name).font(.headline)
                                    Spacer()
                                    Text(Money.text(spec.pay)).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                                }
                                Text(spec.blurb).font(.caption).foregroundStyle(.secondary)
                                ForEach(Array(status.requirements.enumerated()), id: \.offset) { _, r in
                                    Label(r.text, systemImage: r.met ? "checkmark.circle.fill" : "circle")
                                        .font(.caption)
                                        .foregroundStyle(r.met ? Palette.accent : Color.secondary)
                                }
                                if status.waitDays > 0 {
                                    Text(spec.onRota == true ? "The Championship rota opens in \(status.waitDays) days." : "Can be held here again in \(status.waitDays) days.")
                                        .font(.caption).foregroundStyle(.orange)
                                }
                                Button("Book for tomorrow") { store.bookEvent(spec.id) }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(!status.canBook)
                            }
                            .padding(12)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(12)
            }
        }
    }
}
