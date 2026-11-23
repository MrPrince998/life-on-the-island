# Side quests

**Status:** designed · **Updated:** 2026-11-19 · [GDD](../../GDD.md)

Small, self-contained tasks that reward curiosity and kindness: villager requests, discoveries, restorations and collections. None are timed, none can fail, and none block the [main story](../main-story/design.md) (pillars: **your own pace**, **kindness over grind**). Every quest ends with something you can *see*: a new decoration, an animal, a light, a lived-in building. Coins alone are never a quest reward.

## Rules
1. Quests start by talking to a villager, reading the **notice board** by the well, or finding something (a bottle, a glint). Each start sets a story flag `quest_<id>_started`; finishing sets `quest_<id>_done` (D-005).
2. No fail states, no time limits. A quest that needs a time of day ("at night") can be done on any day.
3. Up to all quests may be active at once; the journal's quest log lists them with one sentence for the current step.
4. Items needed are taken only on hand-in. If the player sells or uses them, they can get more.
5. Rewards: a friendship boost, an item or decoration, a **visible world change**, and sometimes a journal memory. Coins are only ever a side part of the reward.
6. Activity time costs follow D-001: talking and walking are free; crafting, building and placing cost the minutes listed.

## Quest list

| # | Quest | Giver | Unlocks after | Task | Reward and world change | Scope |
|---|---|---|---|---|---|---|
| 1 | **Fish Tales** | Oliver | Prologue | Catch each of the 5 starting fish species | Boathouse restored as Oliver's **fishing shop** (rod upgrades); Oliver +1 heart | MVP |
| 2 | **The One That Got Away** | Oliver | Fish Tales | Catch a Moonfin Koi at night | Oliver's **lucky lure** (rarer fish more often); a story about Grandpa | MVP |
| 3 | **Sunny Seeds** | Mia | Ch. 1 started | Grow and give Mia one of each crop | **Sunflower seeds**; sunflowers line the farm path | MVP |
| 4 | **Bee Kind** | Mia | Sunny Seeds | Build 3 beehives (3 planks + 2 flowers each; 30 min each) | Bees around the fields; **honey** item every few days | MVP |
| 5 | **Back in Stock** | Emma | Prologue | Deliver 5 fish and 5 crops | The store sells **new items** (cloth, decorations); Emma +1 heart | MVP |
| 6 | **The Old Watchtower** | discovery | Ch. 4 path open (or climbing the hills any time) | Reach the watchtower ruins on the summit | **Full island map** (M key) unlocked; a view of the whole island | MVP |
| 7 | **A Bench for Elias** | Theo | Ch. 2 | Bring 6 planks; Theo carves a bench (60 min) | **Memorial bench** by the cottage (rest spot with a unique memory) | later |
| 8 | **Birdhouses** | Theo | Ch. 2 | Build and hang 3 birdhouses in the forest (2 planks each; 20 min each) | Songbirds fly between the trees | later |
| 9 | **The Missing Ledger** | Emma | Ch. 3 | Find Grandpa's supplier ledger in the library | Part of Ch. 3; unlocks deliveries [main] | later |
| 10 | **Nana Bea's Recipe** | Nana Bea | Ch. 3 | Bring a sunfish, a turnip and a loaf of bread | The **inn kitchen** reopens: cozy meals to buy; warm lights at night | later |
| 11 | **Shells for Pip** | Pip | Ch. 1 | Collect 5 kinds of shell on the beach | A **shell wind chime** for the cottage porch; Pip +1 heart | later |
| 12 | **Message in a Bottle** | discovery | Prologue | Find 3 bottles washed up on the beach (one appears every few days) | Three short letters from Grandpa's youth (journal memories) | later |
| 13 | **Lantern Lighter** | discovery | Ch. 2 | Repair the 6 lanterns along the forest path (1 stone each; 10 min each) | The forest path glows at night | later |
| 14 | **The Mushroom Ring** | discovery | Ch. 2 | Visit the mushroom ring at night after rain | Fairy lights in the ring; a rare **glowcap mushroom** | later |
| 15 | **Starlight Survey** | Luna | Ch. 4 | Visit the stone circle on 3 different nights and sketch the stars | A **telescope** at the lighthouse; constellations appear in the night sky | later |
| 16 | **Sea Glass Garden** | Luna | Starlight Survey | Bring 8 pieces of sea glass | Sea-glass mosaic path at the keeper's cottage | later |
| 17 | **Captain's Cargo** | Captain Marlow | Finale | One small trade request on each mail-boat visit (repeatable) | Rare goods from the mainland (furniture, seeds) | later |
| 18 | **Home Sweet Home** | Emma | Ch. 3 | Restore all 4 village houses | All four families return; the square is full on Sundays | later |

## Numbers
| Name | Value | Unit | What to watch in playtests |
|---|---|---|---|
| Quests in the MVP | 6 | quests | enough variety without a quest-log wall |
| Friendship from a villager quest | +100 (one heart) | points | — |
| Bottle spawn | 1 every 3 | in-game days, until all 3 are found | players find them without a guide |
| Beehive build | 30 | activity min each | — |
| Honey yield | 1 per hive every 3 | in-game days | not an income source; a gift item |

## Edge cases
- A discovery quest completed before it "unlocks" (for example, climbing to the watchtower early): it completes immediately and counts.
- Two quests need the same item (fish for Fish Tales and Back in Stock): each takes only its own hand-in; catching a fish never "uses it up" for collection quests (Fish Tales checks the fish journal, not the bag).
- The player finishes the main story first: every unstarted side quest stays available.

## Open questions
- [ASSUMPTION] Sea glass, shells and cloth are new collectable items.
- [ASSUMPTION] The full island map (quest 6) also adds a full-screen map key (M).

## History
- 2026-11-19: designed.
