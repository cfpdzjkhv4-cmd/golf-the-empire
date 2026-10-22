# Golf: The Empire
## Game design document, version 2, from prototype 5

Owner: Harry Copeland. Built from five playable browser prototypes. The prototype source is in `prototype/prototype-5.html` and is the reference for how every system currently behaves. Numbers in this document match that file.

---

## 1. Vision

A British golf empire game for iPhone and iPad. You buy land across Great Britain, design courses on it, run them as businesses, see off rival owners, and build towards hosting The Championship. A dry, wandering commentator, **Percy Hollis**, narrates everything.

### Pillars
1. **Britishness.** Real places, real land types, rain, committees, coastal erosion, auctions in the room. Nobody else is making this game.
2. **Percy.** The commentary is the personality of the game and its main marketing hook. He is fictional and must never be a recognisable impression of any real broadcaster.
3. **An empire that can shrink.** Rivals, storms, unhappy members and debt mean success is never permanent. Pressure is what keeps a tycoon game alive.
4. **Premium and calm.** One purchase, no ads, no energy timers, no gems. The audience skews older golf fans on iPad.

### Platform and business
* Target: iPhone and iPad, App Store. Recommended engine: Swift with SpriteKit for the game, SwiftUI for menus (see CLAUDE.md).
* Monetisation (decided, see DECISIONS.md): paid upfront at £1.99, no in-app purchases. Later content ships as free updates.
* Apple Arcade is worth pitching.

### Fictional names and IP rules
* Commentator: Percy Hollis (fictional, inspired in spirit by classic BBC golf commentary). No voice or likeness impressions of any real person.
* The major is called **The Championship**. Never use "The Open" or R&A marks.
* Rival companies, the critic (Fenella Ashcombe, The Fairway Review), the Golf Gazette and all plot names are fictional. Plots sit in real places but are not real clubs.
* Map of Britain must be our own illustration, not map tiles.

---

## 2. Game modes

### Career
The open map from day 1 with £200,000, three rivals and the land market. No end state. Hosting The Championship is the milestone, then keeping it on the rota.

### Challenges
Scenarios with a start state, a goal and a deadline in game days. A goal strip shows progress and days left. Win or lose screen with a Percy line, then Keep playing, Try again or Main menu.

| Challenge | Difficulty | Days | Start | Goal |
|---|---|---|---|---|
| Back from the brink | Gentle | 45 | £60k, East Neuk Links (Crail, Fife) built but run down: rep 3.6 of 10, condition 42%, basic clubhouse | 8 of 10 reputation and £300k in the bank |
| The waiting list | Moderate | 60 | £120k, Tatton Edge (Cheshire) built, rep 3.0 | Every membership filled, with 20+ on the waiting list |
| Stockbroker belt | Moderate | 50 | £150k, three southern nine holers. Meridian owns Chobham and Cotswold, has £2.5m and targets 7.7 of 10 | Highest rated course in the south for 10 days running |
| Rising tide | Hard | 70 | £250k, Pegwell Bay Links (Kent) built long, rep 4.2, County and Regional already hosted. Storms 3x as frequent | Host The Championship at Pegwell |
| Shoestring | Very hard | 240 | £50k, nothing owned | Host The Championship anywhere |

### Start screen
Continue (shows mode, day, cash), New career, Challenges. Starting a new game over an existing save needs a second tap to confirm.

---

## 3. Time and the calendar

* **Calendar dates.** The game starts on the real date the player begins (stored as `date0`); every game day is the next calendar day. Dates show as "Sun 4 Oct" throughout (header, sales, inbox, news).
* **Seasons** scale demand by month: Jan 0.70, Feb 0.72, Mar 0.82, Apr 0.92, May 1.05, Jun 1.12, Jul 1.12, Aug 1.10, Sep 1.00, Oct 0.92, Nov 0.80, Dec 0.72. Coastal storms are 1.8x as likely October to February, and condition loses an extra point a day in winter.
* **Weekdays:** Saturday and Sunday 1.35x demand, Friday 1.1x.
* A day runs 07:00 to 19:00. At 1x, 1 real second is 10 game minutes (72 seconds a day). Speeds: Paused, 1x, 4x, 10x.
* **The clock only runs** on the map with nothing open and on a course's Run tab. Build, Club, Events, Reviews, any sheet, the inbox, auctions and menus pause it. Live auctions tick in real time regardless.
* **Close of play.** At 19:00 the clock stops and the day's books appear: money in (green fees, bar and shop, member subscriptions, tournaments, course sales), money out (upkeep, staff wages, building work, facilities, land and clubs bought), net for the day, cash in the bank, a line per course (rounds, takings, costs, net, reputation), and a "tomorrow" note (weekend, season change, booked events, storm forecasts, auctions). A **Start [date]** button begins the next day. An optional setting skips the summary and carries on automatically.
* Every cash movement goes through `earn(category, amount)` or `spend(category, amount)` so the books always reconcile.
* Close of play runs: events, storms, member income, upkeep and wages, the daily reputation update, condition recovery, tomorrow's weather. Starting the next day runs: the market, rivals, press, the weekly Gazette (every 7 days), milestones and challenge checks.

## 4. The map and land

An illustrated map of Great Britain with pan and pinch zoom, city labels and pins for every plot. Pin states: quiet sale, sealed bids, live auction (gold ring), administration (red), yours (gold), rival owned (rival colour).

### Land types
| Type | Character | Trees | Water chance per hole |
|---|---|---|---|
| Links | Coastal, firm, windy, hardly any trees. Can host The Championship. Suffers storms and erosion | Gorse | 15% |
| Heathland | Sandy, pine and heather, drains well | Pine | 20% |
| Parkland | Big old trees, soft turf | Oak | 40% |
| Moorland | Upland, rugged, damp | Scrub | 35% |

### Plots
Three kinds of site:

1. **Hand made plots** (about 66, listed below for the original 27): fixed sites used by challenges and as a base layer.
2. **Generated sites:** each career creates 30 fictional clubs at random towns from a list of about 100 real places (town, county, coordinates, allowed land types, wealth, demand), then spawns a new one every 4 to 8 days, up to 95. Names are random combinations from per terrain word lists (for example "Spindrift Sandhills", "Juniper Heath", "Dovecote Park", "Grouse Fell"). Holes, wealth, demand and prestige are randomised around the town's values. Generated sites are saved with the career. No two careers start with the same map.
3. **Legendary venues** (25): fictional stand ins for Britain's most famous clubs, always visible on the map as private clubs, finished and run at the highest level. See section 5.

Base price = (18 holes: 150,000, 9 holes: 70,000) × wealth^1.8 × (0.6 + prestige × 0.4), rounded to £5k, drifting daily by a small random walk.

The design intent: the north is cheap and carries prestige (championship links); the south is expensive and carries money.

Original 27 hand made plots, for reference:

| Plot | Area | Land | Holes | Wealth | Demand | Prestige | Base price | Notes |
|---|---|---|---|---|---|---|---|---|
| Embo Links | Dornoch, Highlands | links | 18 | 0.6 | 1.6 | 1.5 | £70,000 |  |
| Moray Firth Shore | Lossiemouth, Moray | links | 9 | 0.65 | 1.8 | 1.25 | £35,000 |  |
| Bay of Cruden Dunes | Aberdeenshire | links | 18 | 0.7 | 2.2 | 1.4 | £90,000 |  |
| Ochil Hills Parkland | Auchterarder, Perthshire | parkland | 18 | 1 | 2.8 | 1.2 | £160,000 | Reserve (comes to market later) |
| Tummel Moor | Pitlochry, Perthshire | moorland | 9 | 0.7 | 1.8 | 1 | £35,000 |  |
| East Neuk Links | Crail, Fife | links | 18 | 0.85 | 3 | 1.6 | £140,000 | Reserve (comes to market later) |
| Kintyre Links | Machrihanish, Argyll | links | 18 | 0.55 | 1 | 1.45 | £60,000 |  |
| Irvine Bay Links | Ayrshire coast | links | 18 | 0.75 | 3.5 | 1.5 | £105,000 |  |
| Castle View Links | Bamburgh, Northumberland | links | 9 | 0.8 | 1.6 | 1.3 | £50,000 |  |
| Derwent Fell | Keswick, Lake District | moorland | 9 | 0.85 | 2 | 1.05 | £55,000 |  |
| West Cumbria Links | Seascale, Cumbria | links | 9 | 0.6 | 1.4 | 1.2 | £30,000 |  |
| Ilkley Moor Edge | West Yorkshire | moorland | 18 | 0.95 | 4 | 1.05 | £140,000 |  |
| Stray Parkland | Harrogate, North Yorkshire | parkland | 18 | 1.1 | 4.2 | 1 | £180,000 |  |
| Sefton Sandhills | Southport, Merseyside | links | 18 | 0.9 | 5 | 1.55 | £150,000 | Reserve (comes to market later) |
| High Peak Moor | Buxton, Derbyshire | moorland | 9 | 0.85 | 3.2 | 1 | £50,000 |  |
| Tatton Edge Parkland | Knutsford, Cheshire | parkland | 18 | 1.35 | 5.5 | 1.05 | £265,000 |  |
| Cardigan Bay Dunes | Harlech, Gwynedd | links | 9 | 0.65 | 1.2 | 1.3 | £35,000 |  |
| The Wash Links | Hunstanton, Norfolk | links | 18 | 1 | 2.6 | 1.35 | £170,000 | Reserve (comes to market later) |
| Royal Town Parkland | Sutton Coldfield | parkland | 18 | 1.1 | 6 | 1 | £180,000 |  |
| Cotswold Ridge | Broadway, Worcestershire | parkland | 9 | 1.45 | 3 | 1.05 | £140,000 |  |
| Common Lane Parkland | Harpenden, Hertfordshire | parkland | 9 | 1.55 | 5.5 | 1 | £155,000 |  |
| Norwood Ridge | South East London | parkland | 9 | 1.65 | 7 | 0.95 | £170,000 |  |
| Chobham Common Heath | Surrey | heathland | 18 | 1.7 | 6.5 | 1.2 | £420,000 |  |
| Pegwell Bay Links | Sandwich, Kent | links | 18 | 1.3 | 4 | 1.6 | £300,000 | Reserve (comes to market later) |
| South Downs Parkland | Lewes, East Sussex | parkland | 9 | 1.3 | 3.5 | 1 | £110,000 |  |
| Braunton Burrows | North Devon coast | links | 18 | 1.05 | 2.4 | 1.4 | £190,000 | Reserve (comes to market later) |
| Camel Estuary Dunes | Rock, Cornwall | links | 9 | 1.25 | 2 | 1.3 | £115,000 | Reserve (comes to market later) |

Rivals start owning Common Lane (Meridian), Irvine Bay (Hollingworth), High Peak and Royal Town (Granite).

## 5. Land sales and auctions

| Type | When | How it works |
|---|---|---|
| Quiet sale | Guide under £90k and prestige under 1.3, or a lot that failed at auction | Buy outright. Withdrawn after 6 to 12 days if nobody buys. Granite Leisure may snap up quiet sales under £150k |
| Sealed bids | Most other lots | Guide and closing date. One offer, changeable until close. Reserve 90% of guide. Must have the cash at close |
| Live auction | Big 18 hole links and administration lots, plus 30% or so of ordinary lots, and every legendary venue | Real time bidding against rivals with an auctioneer. Opens at 70% of guide, 4% increments, going once at 3s of silence, twice at 5s, sold at 7s. If the player leads below the reserve they can raise their own bid |

**A market that moves:**
* A new career lists 14 sites (mostly generated) and guarantees two cheap quiet sales and one live auction in the first few days.
* New listings every 2 to 4 days (sometimes two). Withdrawn sites cool off for 8 to 25 days, then can return at a new price ("Back on the market").
* Sealed lots occasionally vanish before closing in a private deal (1.5% a day).
* Rivals sell clubs as well as buy them (about 1 in 220 per club per day), returning them to market.
* Administration sales every 12 to 20 days: a built course and clubhouse, a bit tired.

**Selling your own clubs** (from the club's pin on the map), allowed two weeks after buying:
* Valuation = (land price + build cost × 0.6 + facilities cost × 0.7) × (0.7 + rep/5 × 0.6) × (0.85 + design × 0.03) × a members bonus of up to 15%.
* **Quick sale** at 85% of valuation to the rival best placed to buy, or a private buyer.
* **Auction it:** sealed bids over 5 days, rivals and sometimes a private buyer bid, reserve 90%. The club trades normally until sold. If nobody meets the reserve it stays yours.

**Legendary venues.** Stand ins for: St Andrews (Old Grey Links), Wentworth (Wentwood), Sunningdale (Sunningvale Heath), Gleneagles (Glen Aiglon), Turnberry (Lighthouse Point Links), Muirfield (Muirhaven), Royal Birkdale (Birkmoor Links), Carnoustie (Carnock Links), Royal St George's (Stonar Bay Links), St Enodoc (Brea Hill Links), Swinley Forest (Swinford Forest), Royal Lytham (Ansdell Links), Ganton (Potter Brompton Heath), St George's Hill (Brooklands Heath), Royal Cinque Ports (Five Ports Links), Walton Heath (Mere Heath), Royal Liverpool (Red Rocks Links), Woodhall Spa (Kirkstead Heath), Royal West Norfolk (Scolt Head Links), Formby (Freshfield Pines), Notts (Kirkby Holywell), Royal Dornoch (Dornoch Firth Links), Royal Troon (Marr Links), Kingsbarns (Cambo Links), Royal Aberdeen (Don Mouth Links). **Never use the real names in the game.**
* Shown as navy pins with gold rims, "private club, not for sale", with a last valuation.
* About every 20 to 32 days one comes up at live auction, announced 7 days ahead with breaking news in the inbox. Guides £2.5m to £6m.
* Rivals can borrow up to 4x their cash for these. If the reserve isn't met it goes back to being private.
* Bought with: signature course (design around 9.9), grand clubhouse, flagship shop, range, championship greenkeeping, 75% full membership, rep 9.2 of 10, County and Regional already hosted.
* Resale is capped at about 75% to 105% of the guide, so they're prestige holdings, not flips.

## 6. Rivals

| Rival | Colour | Personality | Starting cash | Bids (× guide) | Target rep | Max courses | Wants |
|---|---|---|---|---|---|---|---|
| Meridian Capital | Purple #6A55A8 | Cash rich consortium, home counties, overpays for prestige | £1.2m | 1.05 to 1.40 | 4.3 | 5 | Wealth 1.2+ or prestige 1.45+ |
| Hollingworth Estates | Brown #9A5B26 | Old money, north and Scotland, protective | £700k | 0.95 to 1.25 | 4.1 | 4 | North of latitude 54, or championship links |
| Granite Leisure | Slate #55636B | Budget chain, cheap nine holers | £400k | 0.90 to 1.10 | 3.0 | 5 | Guide £120k or less and (9 holes or under £80k) |

* Each rival is interested in a qualifying lot with 38% probability.
* Rival courses drift towards their owner's target reputation and earn daily income: (18 holes: £2,600, 9 holes: £1,200) × wealth × rep/4.
* **Competition:** every rival course within about 100 km reduces a player course's demand by up to 20% × (rival rep / 5), fading with distance. The Run tab tells the player how many golfers rivals are costing them.
* **Administration:** Granite courses under 3.3 rep have a 1 in 90 daily chance of going bust; any rival course 1 in 450. Their land returns to market as an administration sale.
* Rivals can take The Championship slot (see section 10).

---

## 7. Course design (the heart of the game)

Design must matter more than anything else. A beautifully designed course should clearly out earn a lazily laid out one, and the game must tell the player why.

Each hole is a grid of 16 columns by 32 rows; one row is 17 yards. Hole 1 has extra rows for the clubhouse, pro shop and car park.

### Tiles and build costs
| Tile | Cost per tile | Notes |
|---|---|---|
| Rough | £5 | Default ground |
| Fairway | £15 | |
| Green | £60 | |
| Bunker | £30 | |
| Water | £80 | Penalty stroke |
| Trees | £20 | |
| Tee | £150 | One per hole |
| Pin | Free | Must be on a green |
| Sea | Not buildable | Erosion only |

Par from yardage: up to 250 par 3, up to 440 par 4, longer par 5. A hole needs a tee, a pin on a green and 80+ yards.

### Hole rating (0 to 10)
Every hole is analysed for features:

| Feature | Detection | Points |
|---|---|---|
| Island green | 70%+ of tiles around the green are water | 3.2 |
| Water guarding the green | 30% to 70% | 1.5 |
| Tee shot over water (par 3) | Water on the straight line from tee to pin | 2.2 |
| Carry over water (par 4/5) | Same | 1.6 |
| Double dogleg | Fairway centreline deviates 1.6+ tiles both ways from the tee to pin line | 2.2 |
| Dogleg left/right | Deviates 1.8+ tiles one way | 1.6 |
| Risk and reward corner | Dogleg with water, sand or trees inside the corner | 1.4 |
| Vast waste bunker | A connected bunker of 18+ tiles | 2.0 |
| Showcase bunker | 10+ tiles | 1.6 |
| Well guarded green | 3+ bunker groups within 4 tiles of the pin | 1.0 |
| Pot bunkers | 5+ bunkers of one or two tiles | 1.0 |
| Driveable par 4 | 300 yards or less with a protected green | 1.2 |
| Tree lined | Trees within 2 tiles both sides on 60%+ of fairway rows | 0.8 |
| Water in play | Water within a tile of the fairway | 0.7 |
| Fairway too narrow | Average under 2.2 tiles | -1.0 |
| Bland | No positive features | -0.8 |

Score = 3.8 + small bunker and tree bonuses + features with diminishing returns (best feature full value, then 80%, 65%, 50%, 40%, 30%) + penalties, clamped 1 to 10.

### Course design score (0 to 10)
Average hole score × 0.85 + up to 1.5 for distinct feature types (0.2 each) + 0.3 for using all three pars (−0.4 if only one) + 0.3 if the best hole is 8.5+. The best hole (7.5+) is the **signature hole**, which golfers and the Fairway Review mention by name.

Words: Basic (under 4), Ordinary, Good (5.5), Excellent (6.5), Championship class (7.5), Masterpiece (8.5).

### What design drives
* **Reviews:** (design − 5) × 0.34 stars, plus quotes about the signature hole.
* **Demand:** × (0.75 + design × 0.06).
* **Fair green fee:** × (0.8 + design × 0.045).
* **Reputation ceiling** (section 8) and event requirements (Regional Pro Am 6.5+, The Championship 7.5+).
* **Club valuation** and the Fairway Review score.
* In testing, redesigning the same nine holes from auto layout to well featured holes roughly doubled daily takings.

### Auto layout is deliberately basic
Auto layout gives a straight, playable hole with a couple of greenside bunkers and no water; it scores about 3.4. Legendary venues and rival courses use a signature generator (doglegs with hazards in the corner, island greens, carries, waste bunkers, pot bunkers) scoring 7 to 9+.

### Feedback in Build mode
A hole card under the tools shows the rating (coloured), every detected feature as a chip, the signature hole badge, the most useful tip (for example "Bend the fairway round a corner to make a dogleg"), and the course design score. The hole strip shows each hole's rating.

## 8. Golfers and play

* Tee times every 8 game minutes. Each tee time goes to a group of 1 to 4 golfers (members: 2 to 4).
* Visitor groups arrive at rate per hour = demand × 3 × (0.5 + rep/5) × price factor × weather × range bonus (1.1) × rival competition × review buzz. Price factor = clamp(1.5 − 0.6 × fee/fair fee, 0.15, 1.5).
* Weather multipliers: sun 1.15, cloud 1.0, wind 0.85, rain 0.55, storm 0.15.
* If the tee is busy, the group walks away and is counted as turned away.
* Golfer skill = 0.2 to 0.75 random, plus 0.03 × course rep. Handicap shown from skill.
* **Shot simulation:** each shot picks the best reachable target, scattering by skill, lie (rough, bunker, trees worse) and wind (×1.35, storm ×1.6). Roll on fairways and greens. Water and sea cost a stroke with a drop. Out of bounds is stroke and distance. Putting holes out with probability based on distance and skill. Pick up after 10 shots, scored as par + 4.
* **Watch a round:** follow one golfer through every hole with Percy commentating shot by shot.
* Ambient golfers walk the course for life.

### Money per round
* Green fee (player sets it in £5 steps). Fair fee = (20 + rep × 7) × wealth × (1.6 for 18 holes).
* Bar and shop spend = ((10 + stars × 3) × clubhouse multiplier [0.6, 1, 1.5, 2.2] + shop bonus [0, 6, 14]) × √wealth.

### Reviews and reputation
Every round leaves a 1 to 5 star review with a one line quote, built from: design, prettiness, variety, setting (prestige), score against par, penalties, weak holes, condition, facilities (and a members' club bonus), rain, price against fair value, and a bargain bonus.

**Reputation is shown out of 10** (stored internally as 0 to 5). Once a day it moves 7% of the way towards that day's average review stars, so it takes weeks to build. It is capped by a **ceiling**:

| Ceiling (of 10) | Requirement |
|---|---|
| 6.0 | Open and finished |
| 7.0 | A clubhouse and condition 70%+ |
| 8.0 | Design 6.5+ and a clubhouse with restaurant |
| 9.0 | Design 7.5+ and a County Amateur hosted |
| 10.0 | Design 8.5+, condition 85%+ and a Regional Pro Am hosted |

Nine hole courses top out at 8.0. The Club tab shows reputation, the ceiling and what unlocks the next level.

---

## 9. Running the club

### Facilities
| Facility | Levels and costs | Effect |
|---|---|---|
| Clubhouse | Portacabin (free), Clubhouse £25k, with restaurant £60k, Grand £150k | Bar spend multiplier, reviews, member mood +8 per upgrade |
| Pro shop | None, Pro shop £15k, Flagship £40k | Extra spend per round |
| Driving range | None, Range £30k | +10% golfers, better reviews |
| Greenkeepers | Skeleton crew, Full team, Championship team | Wages (level − 1) × £90 a day (9 holes) or £160 (18). Recover condition 3, 7 or 12 points a day |
| Sea defences (links with shore holes) | None, Rock armour £40k, Sea wall £120k | Halves or stops storm erosion |

### Condition
Starts at 85%. Each round wears it 0.03 (9 holes) or 0.02 (18). Rain costs 3 points a day, storms 6. It shows visually as browning turf and affects reviews.

### Upkeep
£60 base plus per hole £12 + fairway tiles × 0.15 + green × 0.8 + bunker × 0.2 + water × 0.1, plus wages. Charged daily once the course has opened.

---

## 10. Events and The Championship

| Event | Pay | Rep | Cooldown | Requirements |
|---|---|---|---|---|
| Society day | £3k (× 1.6 for 18 holes, × √wealth) | +0.1 of 10 | 5 days | Course finished, rep 5.0+ |
| County Amateur | £20k | +0.5 of 10 | 20 days | 18 holes, rep 7.0+, condition 70%+, a clubhouse |
| Regional Pro Am | £75k | +0.7 of 10 | 30 days | 18 holes, rep 8.0+, design 6.5+, 6,000+ yards, clubhouse level 2, range, County Amateur hosted here |
| The Championship | £750k | +2.0 of 10 | Rota | Links land, prestige 1.4+, 18 holes, rep 9.0+, design 7.5+, 6,500+ yards, grand clubhouse, flagship pro shop, range, condition 85%+, members' club with 200+ members, Regional Pro Am hosted here |

* Booking closes the course to the public for the next day. The field is simulated and Percy reports the winner.
* If the club has members, every event needs the committee on side (mood 40+), and hosting costs 6 mood.
* **The Championship rota:** after anyone hosts it, the next slot opens 45 days later. A rival links course (prestige 1.4+, 18 holes, rep 4.3+) has a 1 in 20 daily chance of taking an open slot.

---

## 11. Members

Every club starts pay and play. The player can welcome members from the Club tab.

* Capacity: 25 per hole (225 for 9 holes, 450 for 18).
* Annual subscription, adjustable. Fair sub = fair fee × 30, rounded to £50. Daily income = members × sub / 100.
* Membership moves 10% a day towards a target based on local demand, reputation, sub against fair value and committee mood. Demand above capacity becomes a **waiting list**.
* Members take morning tee times first (before 11:00 at 4 groups an hour at full membership, 1.3 an hour after), so they displace higher paying visitors. That is the core trade: steady income and prestige against peak visitor money.
* Members count towards The Championship and give a review bonus.
* **Committee mood** (0 to 100, starts 70) drifts towards 65 and moves with: condition under 65% (−1.5 a day), condition 85%+ (+1), rep 4+ (+0.5), visitors outnumbering members 4 to 1 (−0.6), heavy redesigns (−3), sub rises (−3 each), clubhouse upgrades (+8), hosted events (−6).
* Bands: Happy 60+, Content 40+, Grumbling 25+, Mutinous below. Dropping a band sends a letter from the committee naming the cause. Below 40 they block tournaments; below 35 members resign at 3% a day.
* Disbanding the membership costs 0.4 reputation and makes the news.

---

## 12. Weather, storms and erosion

Weather rolls daily per course: rain (more likely north of latitude 54.5), wind (more likely on links), cloud, sun. Links courses can get storms (4.5% a day, ×3 in Rising tide).

Each links course has 2 or more **shore holes** (about a third of holes). New links courses start with one row of sea at the top of each shore hole.

A storm hits 1 to 2 shore holes and takes 1 to 2 rows (17 to 34 yards) each, up to a maximum of 10 rows. Rock armour gives each hit a 50% chance of taking 1 row; a sea wall stops it entirely. If the sea reaches a pin, the green is lost and the course closes until that hole is rebuilt. Auto layout works around the new shoreline, so holes get shorter, which can push a course below The Championship's 6,500 yards.

---

## 13. News, inbox and press

* **Golf Gazette ticker** along the bottom of the map with the latest headline; tap for the archive.
* **Inbox** (envelope in the header with unread count). Senders: Golf Gazette, The Fairway Review, Auction house, the club committee, the head greenkeeper.
* **Weekly Gazette** every 7 days: Pick of the week, Up for grabs (every sale with type, guide, close date, rumours, and a View button), Rival watch (course counts, how well funded each rival is, this week's deals), Your week (profit, best course), Percy's corner (a quip).
* **The Fairway Review:** a critic (Fenella Ashcombe) visits each open course 6 to 10 days after opening, then every 18 to 28 days. A full feature with headline, setting, clubhouse, design, a standout hole, condition, value, members, erosion worries, a verdict and a score out of 10. 8+ gives +0.15 rep and 25% more golfers for 7 days; 4 or below the reverse.
* **Career milestones:** buy land, open a course, £2,000 profit in a day, 4.0 rep, three courses, host each event.

---

## 14. Percy Hollis

About 70 shot by shot lines plus weather, round end, building and facility lines in the prototype. Categories: arrive, next hole, fairway, rough, bunker, water, trees, out of bounds, green, putt missed, holed putt, holed long, ace, eagle, birdie, par, bogey, double, pick up, weather (sun, cloud, rain, wind, storm), round end. Tone: dry, gently mocking, affectionate, never cruel, very British. No repeats back to back. The full line set is in the prototype source (const L).

Decision: Percy is text only. All assets are made by Claude with no spend (see ASSET_PACK.md).

---

## 15. Known issues and open decisions

1. **Name: decided, Golf: The Empire.** "Golf empire" is the tagline of Golf Inc. Tycoon, a big idle game, so the App Store subtitle must carry the Britishness, for example "Build Britain's finest links".
2. **Hole view is tall and narrow on a phone.** Use a camera that follows the hole rather than shrinking it to fit.
3. **Build mode pauses time**, so open courses can be redesigned with no downtime. Proposed: redesigning a hole on an open course closes it for the rest of the day.
4. **Tee sheet / online bookings** (slot intervals, peak pricing, no shows, members against visitors) designed but not built.
5. **Rivals buy quickly** in the first months; watch in playtesting.
6. **Economy needs a full balance pass** once design scoring, seasons and ceilings are all in. Target: a new player's first course earns enough for a second site within roughly two game weeks.
7. **Generated names** can occasionally echo a real club; keep a blocklist of real club names and reject matches.
8. **Painting tools** should make features easy to build on a phone: a curved fairway brush, a "ring the green with water" helper and a bunker shape stamp would all help design feel creative rather than fiddly.
