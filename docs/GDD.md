# Life on the Island — Game Design Document

**Version:** 0.2 · **Updated:** 2026-11-21 · [Features](#feature-index) · [Decisions](#decisions) · [Change log](#change-log)

## Summary
You inherit your grandfather's cottage on a quiet island whose village has faded. You fish, farm, explore and help the few people who stayed, and the island visibly comes back to life around you. A gentle mystery runs through it all: your grandfather's journal and a soft light beneath Moonlit Lake. There is no fail state and no deadline. The main story ends when the lighthouse shines again, and play continues after.

| | |
|---|---|
| Genre and camera | Cozy life sim and exploration, third-person over-the-shoulder |
| Audience | Relaxed players of all skill levels |
| Platforms and input | Windows PC first; keyboard and mouse (controller later) |
| Session | 20–60 min sessions; main story about 15–20 h [ASSUMPTION] |
| Engine | Godot 4.7 (Forward+) |
| Scope | Small release, built in milestones (see CLAUDE.md §12) |
| References | Stardew Valley (village friendships, restoration), A Short Hike (gentle exploration, small open island), Animal Crossing (cozy routine, visible world change) |

## Pillars
1. **The island answers you.** Every main task leaves a visible change in the world (a repaired bridge, a busier market, birds returning). A task with only a progress bar is cut or reworked.
2. **Your own pace.** Time moves only through activities; nothing expires, wilts or fails. No timed quests, no crop death, no combat.
3. **Kindness over grind.** Progress comes from helping people and noticing things, not from optimising. Rewards favour stories, places and friendships over raw numbers.
4. **Gently curious.** The mystery is told through places, notes and small night-time wonders, never through cutscene-heavy exposition. It is always optional to chase.

## Core loop
```
explore & gather → fish / farm / help villagers → coins, items, friendship
      → restore a building or path → new area, service or villager → explore
```
- **Seconds:** walking, fishing minigame, planting, talking.
- **Minutes:** a catch, a harvest, a delivery, finding a journal page.
- **Session and between sessions:** a restoration project, a story chapter, the island looking different than last time.

## Feature index

| Feature | Status | Scope | Summary | Docs |
|---|---|---|---|---|
| World layout | in progress | MVP | Five regions, building placement, house styles, environment, assets to make | [design](features/world-layout/design.md) |
| Villagers | in progress | MVP | All nine villagers in the world with schedules and lines; gifts and friendship to come | [design](features/villagers/design.md) |
| Main story | implemented | MVP | Prologue, five chapters and a finale around the journal, the Glowstones and the lighthouse | [design](features/main-story/design.md) |
| Side quests | designed | MVP | 18 cozy quests: villager requests, discoveries, restoration and collections | [design](features/side-quests/design.md) |
| Opening scene | implemented | MVP | 67 s skippable in-engine intro: the mail boat at dawn, Grandpa's letter, hand-off at the beach jetty | [design](features/opening-scene/design.md) |
| Art assets | designed | MVP | Every model, prop, character, animation and ambient effect, tied to the story, with status and batch order | [design](features/art-assets/design.md) |
| Player and camera | implemented | MVP | Relaxed third-person movement, sprint, jump, collision-aware camera | — |
| Activity clock and day/night | implemented | MVP | Time advances only through activities; day/night lighting | — |
| Fishing | implemented | MVP | Cast, bite, tension reeling; 5+ species; rod given by Oliver | — |
| Bag, coins and General Store | implemented | MVP | 24-slot bag, stacks, coins, buy/sell at Emma's store | — |
| Farming | in progress | MVP | Plots, three crops, watering, no crop death | — |
| Cottage interior | implemented | MVP | Grandpa's cottage can be entered through the front door: furnished room, bed to sleep, desk and window chairs, journal page 1 on the desk, and Grandpa's chest as 30-slot storage (saved) | — |
| Save and autosave | implemented | MVP | Versioned JSON with backup; autosave after changes | — |
| Cozy UI, HUD and minimap | implemented | MVP | Parchment/wood theme, clock, coins, bag pop-up, minimap | — |
| Title and pause menus | implemented | MVP | Title, main menu, settings, pause | — |
| Ambient sound | implemented | MVP | Surf, lake, wind, birds by day, crickets and frogs at night, rain (on the roof indoors, plinking on the lake and sea, dripping from the forest canopy, and the island dripping after it stops), far-off gentle thunder with summer and autumn rain, wind gusts on cloudy and blustery days, a soft snow wind and snow sliding off branches and roofs, village chimes, coast gulls and a forest owl; market music, chatter and the glowing well's hum (Ch. 3); the Moonwell's shimmer (fuller per shard) and the lit lighthouse's hum with ships' horns (finale); seasonal mix (summer cicadas, autumn leaves, quiet winters, snow hush); follows place, time and weather, muffled indoors; all sounds synthesised | — |
| Footsteps | implemented | MVP | A step each time a foot lands in the walk or run animation, matching the ground: grass, earth paths, sand, wooden boards, stone, shallow-water splashes and snow while it snows; heavier when running, a thump on landing; villagers' steps heard nearby; Effects slider; never uses time; synthesised | — |
| Action sounds | implemented | MVP | Fishing: rod out/away, cast swish, reel clicks that follow the crank (a buzz as line runs out, drag clicks when a fish pulls), bobber plop and bite plunk from the water, thrashing splashes, a straining line, snap, escape, catch splash and jingle. Farming: dig, plant, a sprinkle exactly while the can pours, fertilizer, harvest pop with a chime, seed-packet rattle. Effects slider; never uses time; synthesised | — |
| Interface sounds | implemented | MVP | Autoload UISounds hooks every button, slider, tab, panel and villager by itself: wooden marimba clicks (lower for Back), hover/focus ticks, a muted bonk for disabled buttons, slider ticks, chimes as panels open/close (the journal opens, shuts and turns pages like a book), coins in/out, quest begin/step/finish chimes, friendship heart, message blip, a hummed "mm" per dialogue line (each villager's own pitch); quiet while the island loads; Effects slider; never uses time; synthesised | — |
| Story moment sounds | implemented | MVP | Autoload StorySounds plays a short piece of music when a story flag is set during play (never on load): a shimmer per Glowstone shard (a step higher each time), a music box per journal page, its own restoration sound per building (market awnings and squeeze-box, windmill groan and sails, bridge planks over the creek, greenhouse glass, lighthouse lens with five Glowstones, inn fire and cups, boathouse ropes and a shanty; only the most important plays when several happen at once) and afterwards its sound of life (windmill sails creaking round, greenhouse mist by day, inn fire mornings/evenings/rain, boathouse ropes, Theo sawing and hammering by day), a leafy sparkle for cleared paths and planting, birdsong for the oak, Market Day's handbell, a magical hum, a fanfare for Oliver's rod, a big swell for the lighthouse; the opening theme returns under the end credits. Ambience dips and interface chimes hold back meanwhile. Work swings sound too: branches, stone, brush, hammer. Music bus (work: Effects); never uses time; synthesised | — |
| Chapter 1: Seeds of Spring | implemented | MVP | Clear the brambles with Mia, help in the fields, repair the windmill (sails turn), find Glowstone shard 1, plant Grandpa's orchard | [main story](features/main-story/design.md) |
| Chapter 2: The Carpenter's Bridge | implemented | MVP | Rebuild the Willow Creek bridge with Theo (his workshop reopens), plant saplings round the ancient oak, which wakes overnight, and find Glowstone shard 2 at the shrine | [main story](features/main-story/design.md) |
| Chapter 3: Market Day | implemented | MVP | Emma and Mr. Ambrose (Grandpa's ledger), mend and stock the market stalls; Market Day lights the street lamps, reopens the inn and brings two families home; the well glows that night (Glowstone shard 3) | [main story](features/main-story/design.md) |
| Chapter 4: The Keeper's Light | implemented | MVP | Clear the coast rockfall with Theo, meet Luna and the cracked lens, the sea cave at low tide (6–10 AM, shard 4), a message bottle (page 8) and the captain's chest at the shipwreck (shard 5) | [main story](features/main-story/design.md) |
| Finale: The Moonwell | implemented | MVP | Oliver's page 9, mending the lighthouse lens with the five Glowstones, lighthouse night (sweeping beam, glowing lake), rowing to the lake isle for Grandpa's letter, closing credits, then free play | [main story](features/main-story/design.md) |
| Gathering wood and stone | implemented | MVP | 22 branch piles (wood) and 18 rocks (stone) around the forest, hills, coast and meadows; 10 min each, grow back after 2–3 days; Grandpa's sawhorse saws 2 wood into 1 plank (15 min) | — |
| Cooking | implemented | MVP | Grandpa's stove: 6 recipes from crops and fish (3 known, 3 taught by Oliver, Mia and Nana Bea); dishes sell for more and make good gifts | — |
| Village restoration | idea | MVP | Buildings with ruined and restored states, material requirements | — |
| Quest log and journal | idea | MVP | Journal tabs: quests, fish, crops, villagers, memories | — |
| Weather | idea | later | Sunny, rain, cloudy, fog, storm | — |
| Seasons | idea | later | Four seasons, after core systems are stable | — |

## Milestones
1. **M1, foundation:** player, camera, island blockout, activity clock · done.
2. **M2, fishing and economy:** fishing, bag, store · done.
3. **M3, farming:** three crops, plots, harvest and sell · in progress.
4. **M4, story prologue:** arrival, Emma, Oliver's rod, first journal page, world-layout pass for the village and lake · done when a new player reaches "First Catch" without outside help.
5. **M5, restoration and chapters 1–2:** restoration system, Mia and Theo chapters, Willow Creek bridge.
6. **M6, chapters 3–5 and finale:** market, coast, lighthouse; weather and ambience.

## Decisions

| ID | Date | Decision | Alternatives considered | Why | Affects |
|---|---|---|---|---|---|
| D-001 | 2026-11-18 | Time advances only through activities, never from walking | real-time clock | the cozy, own-pace pillar; CLAUDE.md §6 | all systems |
| D-002 | 2026-11-18 | No combat in the initial game | light combat | tone and pillars | all features |
| D-003 | 2026-11-19 | Player starts without a fishing rod; Oliver gives it and teaches fishing | rod at start with HUD hints | the story introduces fishing through a person, not UI | [main story](features/main-story/design.md), [villagers](features/villagers/design.md) |
| D-004 | 2026-11-19 | Mixamo two-handed fishing animations replace the hand-made ones | keep hand-made | user preference after side-by-side comparison | fishing |
| D-005 | 2026-11-19 | Story progress is saved as story flags (GameManager) | per-NPC save state | one simple, saved place for "what has happened" | [main story](features/main-story/design.md), [side quests](features/side-quests/design.md) |
| D-006 | 2026-11-19 | Regions open through soft gates (broken bridge, overgrown path, rockfall) cleared by restoration, never by level or date | fully open island; level gates | the island-answers-you pillar; no grind | [world layout](features/world-layout/design.md), [main story](features/main-story/design.md) |
| D-007 | 2026-11-21 | One short opening scene (70 s, letter-led, skippable, in-engine); no other cutscenes before the finale | no intro; a longer narrated intro | the user asked for an opening scene; kept short and wordless to honour "gently curious" and "your own pace" | [opening scene](features/opening-scene/design.md) |
| D-008 | 2026-11-21 | A new game starts at the beach jetty (arrival by mail boat), not in the village | start in the village by the cottage | matches the prologue's arrival and the opening scene; the walk up introduces the signpost and path | [opening scene](features/opening-scene/design.md), [main story](features/main-story/design.md) |
| D-009 | 2026-11-21 | Willow Creek is carved into the terrain, and the Ch. 2 gate is its broken stone bridge | a fallen giant tree as the gate | the user supplied broken and restored bridge models; a creek reads as a natural barrier and adds water to the forest | [world layout](features/world-layout/design.md) |

## Open questions
- **Assumptions to confirm:** main-story length (15–20 h); grandfather's name "Elias"; player is named and gender-neutral; the lake light is a benign "Moonwell" with no antagonist; four minor villagers added beyond the five in CLAUDE.md.
- **Risks:** soft gates may frustrate players who explore early (test whether the blocked spots read as "come back later" without text); 18 side quests may be too many for the MVP (build the 6 marked MVP first).

## Change log
**0.2 (2026-11-21):** opening scene and art-asset plan designed; D-007, D-008 logged. Opening scene implemented. All downloaded buildings, kits and the seven new villagers placed; Willow Creek added (D-009).

**0.1 (2026-11-19):** first draft; world layout, villagers, main story and side quests designed; D-001 to D-006 logged.
