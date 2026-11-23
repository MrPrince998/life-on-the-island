# Main story

**Status:** implemented · **Updated:** 2026-11-23 · [GDD](../../GDD.md)

A gentle, optional mystery that walks the player around the whole island: a prologue, five chapters (one per region) and a finale. Every chapter ends in a visible change to the world (pillar: **the island answers you**). Nothing is timed and nothing can be failed (pillar: **your own pace**). The places are in [world layout](../world-layout/design.md) and the people in [villagers](../villagers/design.md).

## The story so far (backstory)
- **The island's heart is the Moonwell**, a spring of soft light deep beneath Moonlit Lake. Long ago five **Glowstones** formed where its light reaches the surface, one in each corner of the island.
- The islanders set the Glowstones into the **lighthouse lens**. The lighthouse shone with the Moonwell's own light, ships always found the harbour, and Willowbrook was a busy market village.
- **Fifteen years ago a great storm** cracked the lens. The five shards scattered: one down the creek, one into the forest, one into the well, one into a sea cave, one into a wrecked ship. With the lighthouse dark, the mail boat came less often, trade dried up, and most families moved away.
- **Grandpa Elias** [ASSUMPTION name] stayed. He spent his last years quietly working out where each shard went, writing it all in his **journal**. He never gathered them; he grew too old, or perhaps he wanted his grandchild to find them. He hid the journal pages in the places he loved, "so you'd come to love them too."
- **The secret**, revealed in the finale: the Moonwell glows brighter when the island is cared for. The shards light the lens, but it was always the people who lit the island. There's no villain and no curse.

The player is Elias's grandchild, named by the player and gender-neutral [ASSUMPTION].

## Structure

| Part | Region | Gate cleared | Main helper | Restoration (visible change) | Journal pages | Glowstone |
|---|---|---|---|---|---|---|
| Prologue: A Letter from Grandpa | Village, lake, beach | — | Emma, Oliver | cottage lived in again (smoke from the chimney) | 1 | — |
| Ch. 1: Seeds of Spring | Sunflower Fields | overgrown hedge | Mia | windmill turns; orchard planted | 2 | shard 1 (windmill gearbox) |
| Ch. 2: The Carpenter's Bridge | Fernwood Forest | broken bridge | Theo | bridge rebuilt; ancient tree leafs out | 3, 4 | shard 2 (forest shrine) |
| Ch. 3: Market Day | Village, lake | — | Emma, Mr. Ambrose | 4 market stalls, warehouse, two houses reoccupied, lamps lit | 5, 6 | shard 3 (village well) |
| Ch. 4: The Keeper's Light | Whispering Coast | rockfall on the coast path | Luna, Theo | coast path open; the shipwreck searched | 7, 8 | shards 4 (sea cave) and 5 (shipwreck) |
| Finale: The Moonwell | Lighthouse, lake isle | — | everyone | lighthouse lit; the mail boat returns weekly | 9 (from Oliver), 10 (lake isle) | lens complete |

## Chapter beats

**Prologue: A Letter from Grandpa**
1. Captain Marlow's mail boat drops you at the beach jetty with Grandpa's letter: "The key is with Emma at the store." (The [opening scene](../opening-scene/design.md) shows this arrival.)
2. Follow the path and signpost to the village. Emma gives you the key, 50 coins and a little advice. (Store tutorial.)
3. In the cottage, Journal page 1 is on the desk: *"The lake remembers what we forget. Ask Oliver."* (Rest/sleep tutorial.)
4. Oliver at the dock gives you his spare rod and teaches fishing (D-003). After your first catch he mentions a soft light he sees in the lake on clear nights.
5. Visit the lake at night (any night): the faint glow under the water. **Prologue complete**. Emma mentions that Mia "could use a hand."

**Ch. 1: Seeds of Spring** (implemented 2026-11-21: quest `seeds_of_spring`, starts on `met_mia`)
1. The farm path is blocked by a bramble hedge. Mia meets you there; clearing it together takes 60 min of activity time.
2. Help Mia: plant, water and harvest one of each of the three crops.
3. Repair the windmill: 10 planks, 5 stone, 120 coins (2 hours of activity). Inside its gearbox: **Glowstone shard 1**, warm and faintly humming.
4. Journal page 2, in the garden shed: *"Five stones, five places. The first one kept the mill turning."*
5. World change: the windmill turns; Mia gives orchard saplings to plant; butterflies arrive over the fields.

**Ch. 2: The Carpenter's Bridge** (implemented 2026-11-22: quest `carpenters_bridge`, starts on `met_theo`)
1. Theo sits by the broken bridge over Willow Creek. He can't rebuild it alone.
2. Bring 15 planks and 10 stone; rebuild together (3 hours). Theo's workshop over the bridge reopens: he now helps with every later restoration.
3. In the forest: page 3 at the mushroom ring (only visible at night) and page 4 under the leafless ancient tree.
4. Plant 3 saplings around the ancient tree; the next morning it is in full leaf, and birds return.
5. The forest shrine, now in sunlight, holds **Glowstone shard 2**.

**Ch. 3: Market Day** (implemented 2026-11-23: quests `market_ledger` → `market_day` → `well_light`, starts on `shard_2`)
1. Emma confides that the market died with the lighthouse. Mr. Ambrose finds Grandpa's supplier ledger in the library and translates pages 5 and 6 (Grandpa's shorthand).
2. Restore 4 market stalls and the dock warehouse; stock them with fish and crops (deliveries of 10 fish and 10 crops).
3. **Market Day**: the lamps are lit, two families move back into restored houses, Nana Bea reopens the inn, and music plays in the square.
4. That night the old village well glows: **Glowstone shard 3** at the bottom (Pip spots it first).

**Ch. 4: The Keeper's Light** (implemented 2026-11-23: quest `keepers_light`, starts on `shard_3`)
1. Theo and the player clear the rockfall on the coast path (2 hours).
2. Meet Luna, who has kept the dark lighthouse alone and knows about the lens.
3. Sea cave, reachable only in the morning (06:00–10:00) when the tide pools are low: **Glowstone shard 4** in a crystal pool. Page 7 is pinned inside.
4. A message bottle on the beach (page 8) holds the key to the captain's chest in the shipwreck: **Glowstone shard 5**.

**Finale: The Moonwell** (implemented 2026-11-23: quests `finale_page9` → `finale_lens`, starts on `shard_5`)
1. Oliver hands you page 9: "He asked me to keep this until you had all five."
2. Theo and Luna craft the lens from the five shards (5 planks, 5 stone, 1 day of activity).
3. Lighthouse night: everyone gathers on the headland. The lens is set, the beam sweeps the sea, and Moonlit Lake glows from below.
4. Row to the lake isle: page 10 under the lone tree, Grandpa's letter to you. The credits roll over the island at night.
5. Free play continues: the mail boat visits every 7 days, Luna offers star-gazing, and side quests stay open.

## Rules
1. Progress is gated only by **actions** (talk, gather, restore, catch), never by date, level or a timer. The one time-of-day condition (the sea cave in the morning, the mushroom ring at night) can be met any day.
2. Every step is a **story flag** in GameManager (D-005), so saving is automatic: `met_<npc>`, `has_fishing_rod`, `prologue_done`, `ch1_hedge_cleared`, `ch1_windmill_restored`, `ch2_bridge_restored`, `ch2_tree_restored`, `ch3_market_day`, `ch4_rockfall_cleared`, `shard_1`…`shard_5`, `journal_page_1`…`journal_page_10`, `lighthouse_lit`.
3. The **world builds its look from the flags** on load (ruined or restored model, gate present or gone).
4. Talking and walking cost no time; restoration and clearing are activities with the time costs below (D-001).
5. Side quests never block the main story, and the main story never blocks side quests already started.
6. A **quest log** in the journal shows the current step in one sentence ("Bring Theo 15 planks and 10 stone (7/15, 10/10)").

## Numbers
| Name | Value | Unit | What to watch in playtests |
|---|---|---|---|
| Clear the hedge | 60 | activity min | — |
| Windmill repair | 10 planks, 5 stone, 120 coins; 120 | items, coins, activity min | affordable after 2–3 fishing sessions |
| Bridge rebuild | 15 planks, 10 stone; 180 | items, activity min | gathering takes about one session |
| Market restoration | 4 stalls × (4 planks, 2 cloth [ASSUMPTION]); deliveries of 10 fish and 10 crops | items | the busiest chapter; watch for grind |
| Rockfall clearing | 120 | activity min | — |
| Sea cave window | 06:00–10:00 | game time | players understand "come back in the morning" |
| Lens crafting | 5 planks, 5 stone, 1440 | items, activity min (one day) | — |
| Target length per chapter | 2–4 | real hours | total main story 15–20 h [ASSUMPTION] |

## Edge cases
- The player finds a journal page or shard "early" (for example, sees the well glowing at night before Ch. 3): it stays hidden or untouchable until its chapter flag is set, with a curious line ("Something glints at the bottom… too deep to reach for now.").
- Quitting mid-step: every step is a flag, so the game continues from the last completed step.
- Items for a restoration are taken only when the restoration starts, never in advance.
- The player sells materials they need: no lock; the store and the world always have more.

## Open questions
- [ASSUMPTION] Grandpa's name is "Elias"; the player is named and gender-neutral.
- [ASSUMPTION] The Moonwell is benign and there is no antagonist.
- [ASSUMPTION] Cloth is a new item (bought at the store, or woven later).
- Should the finale include a short cutscene, or stay fully in-game with the camera free? (Recommended: in-game, with the camera free.)

## Implementation notes (Ch. 1)
- The bramble gate is a `StoryActivity` on the farm path (needs `met_mia`, 60 min, sets `ch1_hedge_cleared`). The brambles narrow the path but never block it, so the farm stays reachable before the chapter.
- "Help Mia" is any 3 harvests (quest EVENT step), not one of each crop.
- The windmill repair is a `RestorationSite` (`data/buildings/windmill.tres`: 10 planks, 5 stone, 120 coins, 120 min), unlocked by `ch1_hedge_cleared`. Stone is sold at the General Store until gathering exists.
- Restored, the windmill's sails turn (`SpinningSails`), and Glowstone shard 1 glows at its door (`StoryPickup`, sets `shard_1`, adds the item).
- Planting the orchard is a `StoryActivity` by the stumps (needs `shard_1`, 60 min, sets `ch1_orchard_planted`); saplings replace the stumps and butterflies arrive. Reward: 80 coins.
- Journal page 2 already lies by the garden shed.

## History
- 2026-11-19: designed.
- 2026-11-21: Chapter 1 implemented.
- 2026-11-22: Chapter 2 implemented: the bridge is a RestorationSite (15 planks, 10 stone, 180 min, needs met_theo) and also reopens Theo's workshop; planting saplings is a StoryActivity (needs restored_bridge, 60 min); OvernightChange sets ch2_tree_restored the next morning; Glowstone shard 2 is a StoryPickup at the shrine. Page 3 (mushroom ring) is not night-only yet.
- 2026-11-23: Chapter 3 implemented: TALK steps with Emma and Mr. Ambrose (the ledger quest rewards journal_page_5/6); the market stalls are a RestorationSite (12 planks, 6 stone, 80 coins, 120 min, needs journal_page_6); "stock the market" = sell 10 fish and 10 crops at Emma's store; the market_day reward sets ch3_market_day, restored_inn, restored_house_1/2 (village street lamps light only after ch3_market_day); the well glows from 19:00 the first evening after (OvernightChange at_hour) and holds Glowstone shard 3. Cloth and the dock warehouse restoration were left out. Houses 3 and 4 stay boarded for later.
- 2026-11-23: Chapter 4 implemented: the rockfall is a StoryActivity (needs shard_3, 120 min, "with Theo"); a TALK step with Luna; the sea cave's Glowstone (StoryPickup) needs ch4_rockfall_cleared and is reachable only 6–10 AM, while a TidePool floods the cave mouth at other hours; the message bottle is JournalPage 8 on the west beach; the captain's chest by the shipwreck (needs journal_page_8) holds shard 5. Page 7 is still in the cave, readable any time.
- 2026-11-23: Finale implemented: a TALK step with Oliver rewards journal_page_9; the lens is a RestorationSite (5 glowstone_shard, 5 planks, 5 stone, 1440 min, needs journal_page_9) that sets restored_lighthouse; lighthouse_lit comes at 19:00 that evening (OvernightChange); the lighthouse lamp and its sweeping beam (LighthouseBeam) shine only after lighthouse_lit; the Moonwell glow under the lake (MoonwellGlow) brightens per shard and fully after lighthouse_lit; the rowboat by the dock (HouseDoor, needs lighthouse_lit) rows to the lake isle, where page 10 (Grandpa's letter) waits; reading it plays the closing credits (FinaleCredits) and free play continues. Not built: everyone gathering on the headland, the weekly mail boat, Luna's star-gazing.
