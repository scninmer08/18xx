# 18IL Bot

The bot is a deterministic simulation harness. It can acquire and start corporations, convert them from 2 to 5 and
5 to 10 shares, buy minimum startup tokens, issue shares when required for a train, lay track, place home tokens, buy
trains, and pay dividends.

Players continue investing while a legal share remains affordable. The policy scores every legal purchase using
evolvable preferences for corporation ownership, the Market, the treasury, and price. It also participates in
post-conversion share buying and performs required stock sales and emergency sales for train purchases.

Auction decisions use evolvable values and cash reserves for concessions, private companies, IC certificates, and Big
Lots. All legal par prices are scored independently; no par price is designated as the normal target or fallback.
Conversion, dividends, private acquisition, train count, and stock-source preferences are also part of the policy
profile rather than fixed strategic rules.
Private company values are corporation-specific. The same valuation is used when judging concessions with assigned
privates, choosing post-conversion acquisitions, and bidding on privates in the Auction Pool. Auction-pool private bids
preserve cash for the next useful share purchase or for opening an owned concession, so private purchases compete with
stock investment instead of ignoring it.
The private valuation table is intentionally grounded in direct ability impact: Route Extension is strong throughout,
Train Subsidy and Rush Delivery rise when permanent-train pressure appears, GTL and ICC are useful but not automatic
premiums, and FWC is valued as a solid Galena track/subsidy private rather than above Train Subsidy by default.
Concession private value depends on corporation size: ten-share corporations use their attached private package, five-
share corporations value the best available Class A private fit, and two-share corporations value the best available
Class B plus Class A fit.
Train Subsidy and Rush Delivery receive extra value when they bridge a corporation into an immediate permanent-train
purchase, including cases where one legal share issue would complete the funding. IC auction certificates look beyond
the first two operating rounds when permanent trains are near or IC has connected endpoint pairs.
AT and Train Subsidy also receive a package bonus for late high-capital engines, especially IR, when the corporation
has a high share price, endpoint-pair route potential, or permanent trains are near.
Dividend choices override that static profile when retained earnings change train access: a corporation half pays if a
full payout would leave it short of a train rank it does not own, and withholds if that is needed to reach an
available permanent train.
Once IC forms, its auction certificates are valued over the next two operating rounds by assuming two payouts just
large enough to jump right, adding those dividends to the projected share price after both jumps. The president's 20%
certificate receives twice the ordinary-share value. IC certificate bidding uses available player cash rather than the
generic auction reserve.
In Stock Rounds, bots may sell holdings in a corporation that has operated, is trainless, and cannot afford the
cheapest Depot train. A non-president only does so when holding more than one ordinary share and another corporation's
share is available for reinvestment, selling down to zero or one share. A president may similarly sell down without a
replacement purchase when another player already owns enough shares to accept the presidency.
The same sale logic treats a corporation as weak when all its trains will rust on the next Depot train and it lacks
replacement funding. Presidents expecting a two- or five-share corporation to convert in the upcoming OR reserve
enough personal cash for the legal post-conversion treasury shares they expect to buy. In an Auction Round, a bot may
count the forecast proceeds of a legal weak-corporation presidency dump toward opening a new concession corporation
when the receiving player already holds the required shares and is later in player order. It does not rely on those
proceeds when at least two affordable, financially healthy shares are already available instead.
A president tied in share count with another player explicitly protects any corporation that is not operationally
weak by buying an available share. If personal cash is insufficient, the bot first sells the smallest legal bundle
outside that corporation that raises enough cash, preferring weak non-presidency holdings, then buys the protecting
share.
Presidents also prioritize buying their own corporation's shares from the Market, where the normal 60% holding cap
does not apply. If needed, they may sell a small non-presidency holding in another corporation to fund that purchase,
preferring weak holdings first. This helps prevent end-of-stock-round market-share penalties and supports the bonus for
fully player-held corporations.
Immediately below presidency defense, bots pursue IC shares throughout Stock Rounds: Market shares first, followed by
shares held by corporations from which that player may legally buy. They may sell non-presidency holdings to fund the
purchase, but never sell holdings in corporations they president for this purpose. This keeps pressure on the IC
presidency without sacrificing control of their other corporations.
In the first stock round after IC formation, bots first seek IC shares in the Market, then IC shares held by
corporations they president, before returning to normal share valuation.
Concession bids reserve enough player cash to buy the president's certificate at the cheapest currently legal par in
the next stock round. A bot that already holds an unused concession does not bid for another one.
Concession base values are equal across two-, five-, and ten-share corporations. When multiple concession targets have
the same computed value, the bot chooses among them with the game's seeded RNG instead of using corporation name as a
strategic tie-breaker.
First-concession auction bids normalize against the best currently available opening score: the best target maps to a
$60 hard cap, and other concessions bid as a percentage of that score. Later concession bids remain based on marginal
plan value.
At five and six players, the last player without an opening commitment may choose an investor start when the best
remaining concession package is weaker than one already claimed. That player avoids taking a presidency through phase
3, diversifies into healthy corporations, and will not buy a share that would move it ahead of the current president.
From phase 4A onward, it values an available concession against cash plus legal sales from its weaker investments. It
may sell those holdings before buying, then start a corporation at $120 or $150 only when its operating-order projection
shows the launch can fund the expected train. That projection accounts for likely train purchases by corporations ahead
of it and for one legal share issue before the train buy, using six president-owned share units as a ceiling rather than
a fixed requirement. A genuinely unaffordable launch is deferred rather than being forced at a lower capitalization.
Before bidding, the bot also projects whether the corporation can afford the next Depot train rank when it operates.
The launch projection conservatively includes par capitalization, required startup tokens, one conversion token, one
affordable president purchase after conversion, and one treasury/Reserve issuance. It does not assume purchases by
other players. If no legal par can fund that train, the concession receives no bid and the corporation is not parred.
IR is never parred at $40: that capitalization cannot both fund its required early track development and buy a
2-train. IR concession budgeting therefore treats $60 as its minimum bot-legal par.
If IR can only start below $120 after the train market has moved into 4-trains or later, the bot may delay launch to
preserve the option of a stronger late start.
RI is also never parred at $40, and corporations at $40 or below do not issue shares.

Route selection uses a bounded route finder and branch-and-bound combination search to maximize total revenue across
all trains. The best validated route combination is cached by corporation and network state, so an identical later OR
cannot replace it with a lower-revenue partial result when the search times out. The deeper Auto-button path walker is
not used during batch bot route selection because some late-game 18IL networks can overflow Ruby 3.2's VM stack during
that speculative search. By default, isolated exact route verification is limited to 4-trains and complex trains such
as 0+3C, 1+3C, Pullmans, route-extension trains, 8s, 9s, and Ds. Set `G18_IL_BOT_EXACT_ROUTES=all` for exhaustive checking,
`long` for long trains only, or `off` to disable the isolated verifier. Other optional decisions are declined until
their policies are implemented.

Track choices favor new neighboring connections, revenue centers, and home development while accounting for cost.
A corporation without a city-to-city or city-to-offboard route first selects one nearest destination (breaking equal
distances consistently by hex ID) and builds directly toward it from its home network. Towns do not satisfy this
route-building goal. After it has a route, it ranks Peoria, Springfield, Chicago, St. Louis, and New Orleans by
eventual revenue divided by the shortest construction distance from any currently connected hex. Only exits on a
shortest-path frontier toward its two best unconnected destinations receive the bonus. Approaches through towns
receive that bonus only when a legal current-phase town upgrade can preserve existing track, accept the incoming path,
and continue toward the destination. This normally means #58, while special towns such as Jacksonville use their own
upgrade chain; ownership of Chicago-Virden Coal Co. also permits #838 in this lookahead. Improvements that add an IC
Line segment or complete an IC Line hex are the next track priority. Optional
tokens favor high-revenue and strategic cities, and are not purchased when doing so would
leave a trainless corporation unable to afford the next Depot train. Speculative track scoring avoids cloning and
replaying the game for immediate route-revenue lookahead, because that replay can hit native Ruby crashes in long batch
runs.
Each option cube increases that corporation's IC Line improvement bonus by 50%, encouraging corporations already
invested in the line to earn additional cubes.
Track upgrades and token placements receive explicit priority in Springfield, Peoria, and Chicago. A corporation that
can reach St. Louis buys an available STL permit whenever it has the $40. Token placement also includes a large bonus
based on each strategic location's eventual revenue, prioritizing the highest-valued reachable locations.
Once trains are running or permanent trains are near, track scoring also favors progress toward completing East/West
and North/South endpoint pairs.
Token placement is especially aggressive in high-value cities, IC Line cities, St. Louis, and endpoint-pair locations;
the score rises further as open slots disappear.
The STL permit is not exposed as a buyable item—and cannot legally be purchased—until the corporation has a connected
route to St. Louis.
If IC loses its last train to rusting, its trainless abilities are restored after the rust event resolves, including
rust delayed by Planned Obsolescence, so it continues borrowing a Depot train on subsequent operating turns.
Corporation-specific opening guidance may precede those general goals. C&EI first connects Evansville through
Harrisburg (G22) to G24, then through H19 to Louisville. Once it owns at least three trains, it adds the southern
H21-G20-F21-F23 link and turns the G20 junction toward the IC Line. CBQ may issue one share when its network has
reached St. Louis and the proceeds are needed to afford the immediately available permit.
C&EI also calculates its opening treasury as par price times the shares its president can actually purchase. It will
start when it can pass the normal train-funding launch check, then its president prioritizes buying treasury shares
until it can fund two trains plus the remaining river-track reserve. More generally, a corporation whose network
supports two distinct runs seeks at least two early trains: either two 2-trains or a 2-train and a 3-train. The two-2
fleet is a narrow exception to the usual guard against filling the train limit with identical trains.
Upgrading the Peoria and Springfield city tiles themselves takes precedence over constructing additional approaches
to those cities once the corporation has established a legal route. Approaches must connect to an entrance on the
city's current tile; Springfield is the exception because its yellow tile can preserve the north entrance and add the
southeast Pana entrance. The bot therefore treats Springfield as approachable only from Jacksonville or Pana, and
Pana only helps when its town upgrade can carry the route onward to Springfield.
Paid normal or private-company track lays are subject to the same protection: a trainless corporation preserves enough
treasury cash for the cheapest required Depot train. Free track lays always remain available, including NC's forced
Springfield development.
On conversion, a 2-share corporation buys its offered token when train funding permits. A 5-share corporation
converting to ten shares selects one to three tokens, buying the selected amount only when it preserves train funding.
A trainless corporation converts when its treasury plus one share issue cannot afford the next train. During the
post-conversion share round, its president repeatedly buys every legal affordable share; non-presidents decline shares
while it remains trainless. If the corporation already owns a train, each non-president buys one legal affordable
share. The corporation then issues one share if it remains short of its required train and is above the $40 issuance
safety floor.
Once permanent trains are available, two- and five-share corporations without one convert, their presidents buy all
legal affordable post-conversion shares, and they issue one share per OR while building the permanent-train fund.
In stock rounds, a president protects a vulnerable presidency before ordinary investments when the corporation owns a
permanent train or holds at least 75% of the cheapest permanent train's price.

Emergency train purchases take the cheapest legal train. Cash-funded purchases instead compare route capacity,
permanence, price, exchanges, and existing fleet size.
When a corporation exceeds its train limit, it discards the least useful train, preferring duplicate non-permanent and
lower-capacity trains before unique or permanent trains.
During emergency money raising, the president sells the smallest legal number of shares sufficient to cover the cash
shortfall. Equal-size choices prefer shares in trainless corporations. If no single bundle covers the shortfall, the
bot sells one high-value share and recalculates rather than dumping a larger insufficient block.
Bot corporations do not buy trains from other corporations. Human games retain the normal inter-corporation
train-buying rules.
Train Subsidy is saved for a permanent train and is used only when its discount is at least $60. Rush Delivery is used
for a trainless corporation after OR 1.1, or to buy an affordable permanent train before running.
Corporations reserve their last available token for an unused GTL and avoid acquiring GTL without an available token.
ICC ownership adds strong E/W endpoint incentives and smaller N/S endpoint incentives to track planning. FWC receives
an acquisition preference while its free G1 placement at Galena remains available.
An operating bot corporation buys an affordable Depot train rather than retaining a discretionary cash reserve. It will
not fill a multi-train fleet to its train limit when every train in the resulting fleet would be the same type.
At the issue-share step, it issues one treasury share when those proceeds bridge its cash to an available permanent
train. Conversion projects the full sequence of conversion, legal post-conversion purchases, and one subsequent issue.
The projection respects player cash, ownership limits, certificate limits, purchase order, and the 10-share Reserve.

The policy actively uses eligible private abilities for share issuance, train discounts, special track, and special
tokens. It also uses Planned Obsolescence when its corporation has a rusting train. Passive private benefits continue to
be resolved by the game engine.

Run a four-player regular game from the repository root:

```sh
bundle exec ruby -Ilib -e "require 'engine/logger'; Engine::Logger.set_level(Logger::FATAL); require 'require_all'; require_all 'lib/engine/game/g_18_il'; Engine::Game::G18IL::Bot.run(verbose: true)"
```

Add `log_path:` to watch the run while also saving the trace to a text file:

```sh
bundle exec ruby -Ilib -e "require 'engine/logger'; Engine::Logger.set_level(Logger::FATAL); require 'require_all'; require_all 'lib/engine/game/g_18_il'; Engine::Game::G18IL::Bot.run(verbose: true, log_path: 'bot_output.txt')"
```

Export a completed run for visual browser replay:

```sh
bundle exec ruby -Ilib -e "require 'engine/logger'; Engine::Logger.set_level(Logger::FATAL); require 'require_all'; require_all 'lib/engine/game/g_18_il'; Engine::Game::G18IL::Bot.run(seed: Random.rand(1..1_000_000), replay_dir: 'lib/engine/game/g_18_il/bot/reports/replays')"
```

In the browser, select **New Game**, choose **Import hotseat game**, and paste the contents of
the newly created `lib/engine/game/g_18_il/bot/reports/replays/replay_###.json`. The imported game uses the regular map and game interface, including action-history review and
rewind controls. Exported blocked or errored runs can also be imported to inspect the position immediately before the
failure.

For browser hotseat games against bots, 18IL exposes a bot personality dropdown for each bot seat. With Player 1 as the
human, the default bot order is Player 2 Balanced, Player 3 Operator, Player 4 Investor, Player 5 Aggressive, and
Player 6 Conservative. Bot player names are saved from their selected personality.

Run the Full Draft Variant with a fixed seed and inspect the final trace entries:

```sh
bundle exec ruby -Ilib -e "require 'engine/logger'; Engine::Logger.set_level(Logger::FATAL); require 'require_all'; require_all 'lib/engine/game/g_18_il'; result = Engine::Game::G18IL::Bot.run(optional_rules: [:full_draft_variant], seed: 1); p result.to_h.except(:game, :trace); pp result.trace.last(10)"
```

Run five seeded games and write readable and JSON reports:

```sh
bundle exec ruby -Ilib -e "require 'engine/logger'; Engine::Logger.set_level(Logger::FATAL); require 'require_all'; require_all 'lib/engine/game/g_18_il'; Engine::Game::G18IL::Bot.run_batch(games: 5, players: 4, first_seed: 1, report_dir: 'lib/engine/game/g_18_il/bot/reports')"
```

Use a random starting seed while retaining reproducible consecutive seeds within the batch:

```sh
bundle exec ruby -Ilib -e "require 'engine/logger'; Engine::Logger.set_level(Logger::FATAL); require 'require_all'; require_all 'lib/engine/game/g_18_il'; Engine::Game::G18IL::Bot.run_batch(games: 5, players: 4, first_seed: Random.rand(1..1_000_000), report_dir: 'lib/engine/game/g_18_il/bot/reports')"
```

Vary player count from game to game by passing a list or range. The runner cycles through the configured counts in
order, so this ten-game example runs 2p, 3p, 4p, 5p, 6p, then repeats:

```sh
bundle exec ruby -Ilib -e "require 'engine/logger'; Engine::Logger.set_level(Logger::FATAL); require 'require_all'; require_all 'lib/engine/game/g_18_il'; Engine::Game::G18IL::Bot.run_batch(games: 10, players: [2, 3, 4, 5, 6], first_seed: 1, report_dir: 'lib/engine/game/g_18_il/bot/reports')"
```

Process a saved hotseat or browser-export JSON from `bot/reports/tests` with the same batch-style stats:

```sh
bundle exec ruby -Ilib lib/engine/game/g_18_il/bot/replay_reporter.rb test18
```

Pass `--at-action 498` to stop the replay at a specific action id, or `--text path` / `--json path` to save the
readable and structured reports.

The selected seeds are recorded in both reports. With `report_dir:`, batches, tournaments, and evolutions are placed in
their corresponding subdirectories. Replays use the explicit `replay_dir:` shown above. Repeated runs create sequential
names such as `batches/batch_001.json` and `replays/replay_001.json` without overwriting earlier output. Explicit
`text_path:`, `json_path:`, and `hotseat_path:` remain available when a particular filename is desired.
Batch runs also create a per-game hotseat JSON folder beside the batch reports, such as `batches/batch_001/`, with
files named like `game_001_seed_12345.json`. These can be imported in the browser to inspect a specific simulated game.
The per-game progress line includes elapsed wall time, for example
`Game 1/5, seed 12345: finished (642 actions, in 4m 58s)`.

The batch report includes final rankings and wealth, seat win counts, auction bids, action totals, conversions, share
transactions, private acquisitions, route revenue, and details for incomplete games. Its seat diagnostics include
opening corporations by seat, IC first/final/ever presidency counts by seat, and winner opening-corporation
combinations. Its game-balance section also reports corporation-specific par prices, corporations opened per game and
per player, closures, purchased versus exported train cards, average and maximum peak track-tile usage, route count and
average route revenue by train type, city revenue hotspots, IC formation timing, completed-game IC non-formation
reasons, winner dividend receipts allocated across the trains that earned them, and corporations whose presidency was
held by the winner at any point. Mixed-player-count batches also add per-count train value and route-revenue trends.
Closure diagnostics distinguish planned market-close tactics from IC merger closures
and record the triggering action plus the corporation's cash, trains, market shares, and last route revenue. The JSON
report retains the underlying par, train, route, track-tile, dividend, closure, IC formation, and IC Line diagnostic
data for further analysis without rerunning the batch. Set
`verbose: false` to suppress per-game progress while retaining the final report. Pass `output: nil` to suppress terminal
output entirely.

On CRuby, each batch game runs in a separate child process and an incomplete game is retried once. A native Ruby crash
therefore affects only that seed; if the retry also fails, the report records it as an incomplete game and continues.
Child-process stderr, including native Ruby crash reports, is written beside the batch report in a directory such as
`batch_005_crashes`. The text report lists error-log paths for incomplete games and for games that finished only after
a failed child attempt; the JSON report keeps the same paths under `failure.crash_logs`.

Results have one of four statuses:

- `finished`: the game reached its normal end.
- `blocked`: the active decision needs a policy implementation.
- `limit`: the configured action limit was reached.
- `error`: the engine rejected an action or raised an exception.

`BaselinePolicy#choose` is the extension point for additional decisions. Keep action generation separate from scoring
once a decision has more than a few candidates.

## Strategy Tournaments

`PolicyProfile` contains the strategic values used by `BaselinePolicy`, including auction reserves, concession and
private values, independent scores for every par and dividend option, conversion choices, private acquisition, stock
purchases, train valuation, track scoring, and token scoring. The starter set contains six contrasting reference
profiles: Balanced, Operator, Investor, Aggressive, Conservative, and Opportunist. Normal bot runs and batches use
these personalities in seat order unless a custom policy or profile roster is supplied.

The current Balanced defaults were promoted after winning a three-seed training tournament and a separate five-seed,
twenty-game holdout against the named reference profiles.

Run one seed with every starter profile rotated through every seat. Six profiles and one seed produce six games:

```sh
bundle exec ruby -Ilib -e "require 'engine/logger'; Engine::Logger.set_level(Logger::FATAL); require 'require_all'; require_all 'lib/engine/game/g_18_il'; Engine::Game::G18IL::Bot.run_tournament(seeds: 1, first_seed: 101, report_dir: 'lib/engine/game/g_18_il/bot/reports')"
```

Increase `seeds:` for a more meaningful comparison. Each additional seed adds one complete set of seat rotations. The
standings award one point per opponent beaten and report wins, average rank, and average final value. Incomplete games
are retained as diagnostics but excluded from competitive scoring.

Each tournament game runs in a clean Ruby subprocess. This prevents mutable engine state from leaking between
simulations and allows a native worker crash to be recorded without terminating the campaign. Failed games are retried
once in another clean process; only failures that persist on the retry appear as incomplete games in the report.

Create a custom profile by changing selected settings from an existing profile:

```ruby
balanced = Engine::Game::G18IL::Bot::PolicyProfile.new
cautious = balanced.with(
  name: 'Cautious',
  presidency_penalty: 80,
)
```

Pass an array of custom profiles through `profiles:` to `run_tournament`. The number of profiles determines the player
count, so it must be valid for the selected variant.

## Evolution

Evolution starts with a parent profile and creates bounded deterministic mutations. Each generation also includes one
global explorer sampled across the entire parameter space, so evolution is not confined to small variations of the
human-authored starter profile. Each candidate plays a separate four-player tournament against the unchanged initial
parent and two rotating starter profiles. The strongest candidate becomes the next generation's parent. After the final
generation, the champion plays the same reference field on separate holdout seeds.

Run one generation with three mutations, then perform one holdout-seed evaluation:

```sh
bundle exec ruby -Ilib -e "require 'engine/logger'; Engine::Logger.set_level(Logger::FATAL); require 'require_all'; require_all 'lib/engine/game/g_18_il'; Engine::Game::G18IL::Bot.evolve(generations: 1, mutations: 3, training_seeds: 1, holdout_seeds: 1, first_seed: 201, report_dir: 'lib/engine/game/g_18_il/bot/reports')"
```

With three mutations, a generation evaluates four candidates. Each candidate and training seed requires four games to
rotate the candidate and references through every seat. Increase `training_seeds:` before increasing `generations:`;
otherwise a mutation can easily overfit one setup. Keep `holdout_first_seed:` separate from the training range when
specifying it manually. Evolution stops without promoting a candidate if any training or holdout game is incomplete.

The returned result exposes `result.champion`. A champion saved in the JSON report can be loaded for another run:

```ruby
data = JSON.parse(File.read('lib/engine/game/g_18_il/bot/evolution.json'))
champion = Engine::Game::G18IL::Bot::PolicyProfile.from_h(data['champion'])
Engine::Game::G18IL::Bot.evolve(initial_profile: champion, first_seed: 500)
```

## Local Iteration

Bot simulations run entirely on your machine and consume no model or chat tokens. A useful exploratory run is:

```sh
bundle exec ruby -Ilib -e "require 'engine/logger'; Engine::Logger.set_level(Logger::FATAL); require 'require_all'; require_all 'lib/engine/game/g_18_il'; Engine::Game::G18IL::Bot.evolve(generations: 5, mutations: 4, training_seeds: 5, holdout_seeds: 20, first_seed: Random.rand(1..1_000_000), report_dir: 'lib/engine/game/g_18_il/bot/reports')"
```

This evaluates 100 training games per generation and 80 holdout games, so it may take a while. Start with
`training_seeds: 1` and `holdout_seeds: 2` to verify a new code change quickly, then increase the sample sizes for useful
comparisons. Progress prints as games finish, and the text and JSON reports are written when the run completes.

Continue from a saved champion without involving Codex:

```sh
bundle exec ruby -Ilib -rjson -e "require 'engine/logger'; Engine::Logger.set_level(Logger::FATAL); require 'require_all'; require_all 'lib/engine/game/g_18_il'; dir = 'lib/engine/game/g_18_il/bot/reports'; latest = Dir[File.join(dir, 'evolutions', 'evolution_*.json')].max_by { |path| path[/evolution_(\d+)\.json$/, 1].to_i }; data = JSON.parse(File.read(latest)); champion = Engine::Game::G18IL::Bot::PolicyProfile.from_h(data['champion']); Engine::Game::G18IL::Bot.evolve(initial_profile: champion, generations: 5, mutations: 4, training_seeds: 5, holdout_seeds: 20, first_seed: Random.rand(1..1_000_000), report_dir: dir)"
```

The current learner evolves a linear scoring policy over engineered game features. It explores much more broadly than
the original baseline, but it is not AlphaZero: it does not learn new features, search future game states, model hidden
intent, or use a neural network. Rules such as one private of each class per charter remain enforced by the game engine
and are never evolution parameters.
