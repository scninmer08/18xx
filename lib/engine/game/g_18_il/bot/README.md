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

Route search samples a bounded set of legal routes for each train and scores compatible combinations through the game
engine. The limits keep late-game simulations responsive; this is a baseline policy rather than an exhaustive
revenue-maximizing autorouter. Other optional decisions are declined until their policies are implemented.

Track choices favor new neighboring connections, revenue centers, home development, and IC Line progress while
accounting for cost. Optional tokens favor high-revenue and strategic cities, and are not purchased when doing so would
leave a trainless corporation unable to afford the next Depot train. Route path depth is bounded for stable batch runs.

Emergency train purchases take the cheapest legal train. Cash-funded purchases instead compare route capacity,
permanence, price, exchanges, existing fleet size, and an evolvable cash reserve.

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
bundle exec ruby -Ilib -e "require 'engine/logger'; Engine::Logger.set_level(Logger::FATAL); require 'require_all'; require_all 'lib/engine/game/g_18_il'; Engine::Game::G18IL::Bot.run(seed: Random.rand(1..1_000_000), hotseat_path: 'lib/engine/game/g_18_il/bot/18il_bot_replay.json')"
```

In the browser, select **New Game**, choose **Import hotseat game**, and paste the contents of
`lib/engine/game/g_18_il/bot/18il_bot_replay.json`. The imported game uses the regular map and game interface, including action-history review and
rewind controls. Exported blocked or errored runs can also be imported to inspect the position immediately before the
failure.

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

The selected seeds are recorded in both reports. With `report_dir:`, repeated runs create sequential pairs such as
`batch_001.txt` and `batch_001.json` without overwriting earlier reports. Tournaments and evolution runs similarly use
the `tournament_###` and `evolution_###` prefixes. Explicit `text_path:` and `json_path:` remain available when a
particular filename is desired.

The batch report includes final rankings and wealth, seat win counts, auction bids, action totals, par and train-purchase
mixes, conversions, share transactions, private acquisitions, route revenue, and details for incomplete games. Set
`verbose: false` to suppress per-game progress while retaining the final report. Pass `output: nil` to suppress terminal
output entirely.

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
purchases, train valuation, track scoring, and token scoring. The starter set contains four contrasting reference
profiles: Balanced, Financier, Expansionist, and Engineer.

The current Balanced defaults were promoted after winning a three-seed training tournament and a separate five-seed,
twenty-game holdout against the named reference profiles.

Run one seed with every starter profile rotated through every seat. Four profiles and one seed produce four games:

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
  concession_cash_reserve: 240,
  presidency_penalty: 80,
  train_cash_reserve: 80,
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
bundle exec ruby -Ilib -rjson -e "require 'engine/logger'; Engine::Logger.set_level(Logger::FATAL); require 'require_all'; require_all 'lib/engine/game/g_18_il'; dir = 'lib/engine/game/g_18_il/bot/reports'; latest = Dir[File.join(dir, 'evolution_*.json')].max_by { |path| path[/evolution_(\d+)\.json$/, 1].to_i }; data = JSON.parse(File.read(latest)); champion = Engine::Game::G18IL::Bot::PolicyProfile.from_h(data['champion']); Engine::Game::G18IL::Bot.evolve(initial_profile: champion, generations: 5, mutations: 4, training_seeds: 5, holdout_seeds: 20, first_seed: Random.rand(1..1_000_000), report_dir: dir)"
```

The current learner evolves a linear scoring policy over engineered game features. It explores much more broadly than
the original baseline, but it is not AlphaZero: it does not learn new features, search future game states, model hidden
intent, or use a neural network. Rules such as one private of each class per charter remain enforced by the game engine
and are never evolution parameters.
