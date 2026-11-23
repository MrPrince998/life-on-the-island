# Villagers

**Status:** in progress · **Updated:** 2026-11-19 · [GDD](../../GDD.md)

The people who stayed on the island, and the ones who come back as you restore it. Each main villager anchors one chapter of the [main story](../main-story/design.md) and has a personal quest in [side quests](../side-quests/design.md). Talking never costs time (D-001). Friendship rises through talking, gifts and help, and it never falls. This serves the pillar **kindness over grind**.

All nine villagers are in the game (`data/npcs/*.tres`): Oliver and Mia in `Villagers`, the other six beside them, and Captain Marlow on the beach jetty. Gifts, friendship hearts and personal quests are still to come.

## Main villagers

| Villager | Role, age | Personality | Home (see [world layout](../world-layout/design.md)) | Chapter | Loves | Likes |
|---|---|---|---|---|---|---|
| **Oliver** | fisherman, 60s | warm, unhurried, a born storyteller; Grandpa's best friend | fisherman's shelter by the dock | Prologue | Moonfin Koi, coffee | any fish, bread |
| **Mia** | farmer, 20s | cheerful, energetic, talks to her plants | farmhouse, Sunflower Fields | Ch. 1 | sunflowers, honey | crops, flowers |
| **Emma** | shopkeeper, 40s | practical, organised, secretly sentimental | above the General Store | Prologue, Ch. 3 | a rare shell, tea | bread, polished stones |
| **Theo** | carpenter, 30s | quiet, gentle, speaks through his work | workshop over Willow Creek bridge | Ch. 2 | ancient-tree acorn, wooden planks | stone, mushrooms |
| **Luna** | lighthouse keeper, 19 | curious, dreamy, maps the stars | keeper's cottage on the headland | Ch. 4, finale | Glowstone dust, star map | sea glass, blue mackerel |

## Minor villagers (fewer lines, no friendship meter at first)

| Villager | Role | Home | Appears | Purpose |
|---|---|---|---|---|
| **Nana Bea** | innkeeper, 70s | Village Inn | Ch. 3 (inn reopens) | stories about the old village; recipe quest |
| **Pip** | child, 9, Emma's nephew, visiting | General Store | Ch. 1 onward (summer visit) | curiosity quests; points out secrets |
| **Mr. Ambrose** | librarian, 60s | Village Library | Ch. 3 | reads Grandpa's shorthand; journal-page hints |
| **Captain Marlow** | mail-boat captain | the mail boat | Prologue (drops you off), weekly after the finale | arrivals, trade requests |

## Rules
1. Each villager has a **schedule** of 3–4 spots by hour, already supported by `NPCData` entries (`from_hour`, `position`, `activity`). Schedules only change when time advances through activities.
2. **First meeting:** an intro conversation (`intro_lines`) sets the flag `met_<id>`. Oliver's intro ends by giving the rod (D-003).
3. **Daily line:** after the intro, one line per in-game day. It is chosen by the latest story flag first, then the weather/time, then a random friendly line.
4. **Gifts:** one gift per villager per day. Loved +60, liked +30, other +10 friendship. A villager never refuses or dislikes a gift (pillar: kindness).
5. **Friendship hearts:** 0–10 hearts, 100 points per heart. At 2, 5 and 8 hearts a small scene unlocks: a memory about Grandpa or a personal story.
6. Villagers who "move back" (houses restored in Ch. 3) are ambient: they walk the square and say one line each. No gifts at first.

## Schedules (starting proposal)

| Villager | 06:00 | 12:00 | 17:00 | 21:00 |
|---|---|---|---|---|
| Oliver | dock ✓ | lake bench ✓ (sits) | dock ✓ | shelter (sleeps) |
| Mia | farm plots ✓ | greenhouse ✓ | barn ✓ | farmhouse |
| Emma | store counter | store counter | village square | store (upstairs) |
| Theo | workshop | logging clearing | bridge | workshop |
| Luna | keeper's cottage | lighthouse gallery | coast path | lighthouse (star-gazing) |

## Numbers
| Name | Value | Unit | What to watch in playtests |
|---|---|---|---|
| Friendship per heart | 100 | points | 2 hearts within the first week of play feels warm, not grindy |
| Talk (first of the day) | +10 | points | — |
| Gift: loved / liked / other | +60 / +30 / +10 | points | players shouldn't feel they must min-max gifts |
| Heart scenes | at 2, 5, 8 | hearts | each scene reached in a natural pace |
| Time cost of talking | 0 | minutes | — |

## Model prompts (Tripo; same proportions and A-pose as the player, then Auto-Rig)
- **Emma:** practical shopkeeper woman in her forties, dark hair in a neat bun, rolled-up sleeves, mustard apron with pockets and a pencil behind her ear, sensible boots.
- **Theo:** quiet young carpenter, short beard, flannel shirt with rolled sleeves, leather tool belt, canvas trousers, a pencil tucked in his cap.
- **Luna:** teenage lighthouse keeper girl, messy silver-blonde braid, oversized navy knitted sweater with a star pattern, yellow rain boots, brass spyglass on her belt.
- **Nana Bea:** round, smiling old innkeeper woman, white curls, floral dress, knitted cardigan, wooden spoon in her apron pocket.
- **Pip:** small curious child, freckles, oversized straw hat, striped shirt, shorts with a shell bag.
- **Mr. Ambrose:** tall old librarian, round glasses, tweed waistcoat, bow tie, a stack of books under one arm.
- **Captain Marlow:** stocky mail-boat captain, grey beard, peaked captain's cap, navy pea coat, a satchel of letters.

## Edge cases
- The player gives a gift during the intro: it counts after the intro finishes.
- A villager is mid-walk when time jumps (sleeping): they snap to their new schedule spot.
- Save: met flags and the story progress use GameManager story flags (D-005). Friendship points are saved per villager under the save's `world` section [ASSUMPTION].

## Open questions
- [ASSUMPTION] Four minor villagers beyond the five in CLAUDE.md.
- [ASSUMPTION] Gift values and heart thresholds are first guesses for playtesting.

## History
- 2026-11-19: designed; Oliver and Mia in progress.
