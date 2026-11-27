# World layout

**Status:** in progress · **Updated:** 2026-11-19 · [GDD](../../GDD.md)

Where everything on the island sits, what each region looks like, and which models we still need. The layout follows the story (see [main story](../main-story/design.md)): each region is a chapter, opened by a visible restoration task (D-006). It serves the pillar **the island answers you**: every building has a *ruined* and a *restored* look.

Coordinates are world metres (x, z). **North is −z**. Existing items are marked ✓; "~" means a starting spot to fine-tune in the editor. New buildings must stay clear of paths (`IslandShape.is_reserved`) and sit in flat zones.

## Island map
```
                         NORTHERN HILLS (-20,-125)
                         watchtower ruins, stone circle
                                   |
  FERNWOOD FOREST (-115,-20)       |              WHISPERING COAST – headland
  ancient tree, forest shrine,  MOONLIT LAKE        lighthouse ✓ (172,-92)
  mushroom ring, Theo's         (10,15)             keeper's cottage, sea cave
  workshop        Willow Creek  lake isle (-8,2)
        \______bridge_________   |
                             \   | dock ✓ (10,57)
                              \  |                 SUNFLOWER FIELDS (115,70)
                     WILLOWBROOK VILLAGE (0,115)   farm ✓, windmill, orchard, hives
                    /
  WHISPERING COAST – beach (-85,178)
  mail-boat jetty, beach huts, shipwreck
```

## Regions and soft gates

| Region | Centre | Opens in | Gate at the start (cleared by) | Feel |
|---|---|---|---|---|
| Willowbrook Village | (0,115) | Prologue | — | warm, sleepy, half the windows boarded |
| Moonlit Lake | (10,15) | Prologue | — | still water, reeds, lilies; faint glow at night |
| Sunflower Fields | (115,70) | Ch. 1 | overgrown hedge across the farm path at ~(70,92) (Mia and the player clear it) | open, golden, breezy |
| Fernwood Forest | (−115,−20) | Ch. 2 | broken stone bridge over Willow Creek at ~(−75,45) (Theo rebuilds it) | dappled light, moss, birdsong once restored |
| Whispering Coast (beach) | (−85,178) | Prologue (arrival) | — | soft sand, gulls, the mail boat |
| Whispering Coast (headland) | (165,−88) | Ch. 4 | rockfall on the coast path at ~(110,−45) (Theo and the player clear it) | wind, sea spray, wide views |
| Northern Hills | (−20,−125) | Ch. 4 (optional) | none: just a steep climb | quiet, high, starry at night |

**Willow Creek (D-009):** a small stream from a spring in the western meadows (~(−138,42)) to the lake's west shore (~(−24,20)), crossing the forest path at the stone bridge (−75,45). It is carved into the terrain (`IslandShape.CREEK_POINTS`), only flows downhill, and has its own water surface (`CreekWater`). Near the bridge it runs in a small gully about 2 m deep.

**Placed in the game (2026-11-21):** every building and kit below that has a model now stands under `Island/StoryPlaces` (Village, Lake, Farm, Forest, Coast, Hills, Story). Restorable places show their ruined model until the story flag `restored_<id>` is set (`StoryVariant`); soft gates show until `ch1_hedge_cleared` / `ch4_rockfall_cleared`. The gates narrow the path but don't block it yet, because the chapters that clear them aren't built. Spots that moved from the plan below: boathouse (−14.8,44.6) at the west shore (clear of the lake bench); dock warehouse (36,59) on the east shore (the west shore was too crowded); Theo's workshop (−98,36) and logging clearing (−106,14), clear of the forest path; keeper's cottage (152,−96); sea cave (184,−70); orchard stumps around (128–143, 87–95), east of the greenhouse; beach jetty from (−82.8,173.6) out to ~(−91,189).

## Building placement

### Willowbrook Village (flat zone, radius 55 around (0,115))
The village square is the dirt circle around the well. Paths leave it to the north (dock), east (farm), north-west (forest) and south-west (beach). Buildings sit in the gaps between these paths.

| Building | Spot | State at start | Restored by | Model |
|---|---|---|---|---|
| Grandpa's cottage (player home) | ✓ (−25.5,100) | lived-in, dusty | — | house (cottage) ✓ |
| General Store (Emma) | ✓ (26,119) | open | — | store ✓ |
| Village well | ✓ (0,115) | working | — | village_well ✓ |
| Signpost | ✓ (3,93) | ✓ | — | signpost ✓ |
| Market stalls ×4 | ring of radius ~13 around the well, south-east side: ~(12,119), (8,125), (2,128), (−3,128) | collapsed awnings | Ch. 3 "Market Day" | market-stall ✓ (+ ruined variant) |
| Village Inn (Nana Bea) | ~(−32,122), facing the square | shuttered | side quest "Nana Bea's Recipe" | village_inn ✓ (+ ruined variant) |
| Village Library (Mr. Ambrose) | ~(20,140) | dusty but open | Ch. 3 | village_library ✓ |
| Villager houses ×4 | ~(20,94), (40,128), (−44,130), (−40,105) | boarded up | one per restoration step in Ch. 3 (people move back) | house variants (new colourways) |
| Notice board (quests) | ~(7,108), by the well | — | — | NEW notice_board |
| Memorial bench for Grandpa | ~(−30,92), beside the cottage | — | side quest "A Bench for Elias" | garden_bench ✓ + NEW memorial stone |
| Street lamps | along the paths, every ~18 m | unlit | restored with the market | street_lamp ✓, lantern_post ✓ |

### Moonlit Lake (lake radius 42 around (10,15))
| Building | Spot | State | Restored by | Model |
|---|---|---|---|---|
| Fishing dock | ✓ (10,57) | ✓ | — | dock ✓ |
| Oliver's fisherman's shelter (his home) | ~(24,64), east shore by the dock | lived-in | — | fisherman's_shelter ✓ |
| Boathouse → fishing shop | ~(−6,60), west shore | sagging roof | Oliver's quest "Fish Tales" | boathouse ✓ (+ ruined variant) |
| Dock warehouse | ~(−16,64) | locked | Ch. 3 (stock for the market) | dock_warehouse ✓ |
| Lake bench | ✓ (−8,63) | ✓ | — | garden_bench ✓ |
| Rowboat | ✓ (14.6,50.5) | ✓ | — | rowboat ✓ |
| Lake isle and lone tree | ✓ (−8,2) | — | reached by rowboat in the finale | tree ✓ |
| Moonwell glow | under the water by the isle | dim | brightens each chapter | NEW shader/light, no model |

### Sunflower Fields (flat zone, radius 36 around (115,70))
Already placed ✓ (relative to the field): farmhouse, barn, greenhouse, garden shed, scarecrow, compost bin, water trough, 12 plots. To add:
| Building | Spot | State | Restored by | Model |
|---|---|---|---|---|
| Windmill (landmark seen from the village) | ~(140,48), on the rise | broken sails | Ch. 1 | NEW windmill |
| Orchard rows | ~(130–145, 60–85) | dead stumps | Ch. 1 (plant saplings) | blossom_sapling ✓, tree_stump ✓ |
| Beehives ×3 | ~(100,88) by the flowers | empty | side quest "Bee Kind" | NEW beehive |
| Sunflower patch | along the farm path | patchy | grows as the farm is restored | flowers ✓ + NEW sunflower |

### Fernwood Forest (around (−115,−20))
| Building | Spot | State | Restored by | Model |
|---|---|---|---|---|
| Stone arch bridge over Willow Creek | ~(−75,45) | broken | Ch. 2 | stone_arch_bridge ✓ (+ ruined variant) |
| Theo's workshop (his home) | ~(−92,30), just over the bridge | dusty | Ch. 2 | NEW carpenter's workshop (log cabin) |
| Ancient tree | ~(−130,−30) | leafless | Ch. 2 finale | NEW ancient_tree (huge) |
| Forest shrine (Glowstone shard 2) | ~(−140,−5) | moss-covered | Ch. 2 | ancient_forest_shrine ✓ |
| Mushroom ring | ~(−105,−45) | — | glows after rain at night | mushroom_circle ✓ |
| Logging clearing | ~(−98,10) | — | — | tree_stump ✓, wooden logs |
| Birdhouses ×3 | on trees near the path | — | side quest "Birdhouses" | NEW birdhouse |

### Whispering Coast
| Building | Spot | State | Restored by | Model |
|---|---|---|---|---|
| Mail-boat jetty (arrival) | ~(−95,188), south-west beach | old but usable | — | dock ✓ / platform ✓ |
| Beach huts ×2 | ~(−70,182), (−110,170) | empty | later | NEW beach_hut |
| Shipwreck (shard 5) | ~(−135,160), west end of the beach | — | Ch. 4 | shipwreck ✓ |
| Lighthouse | ✓ (172,−92) | dark, cracked lens | Finale | lighthouse ✓ |
| Lighthouse keeper's cottage (Luna) | ~(158,−78) | lived-in | — | lighthouse_keeper's_cottage ✓ |
| Sea cave (shard 4) | ~(188,−66), at the foot of the cliffs | sealed by tide pools | Ch. 4 | cave_entrance ✓, crystal_formation ✓ |
| Coast path rockfall (gate) | ~(110,−45) | blocking | Ch. 4 | rock_boulder ✓ |

### Northern Hills (around (−20,−125))
| Building | Spot | State | Model |
|---|---|---|---|
| Watchtower ruins (viewpoint, unlocks the big map) | ~(−20,−125), summit | ruined | watchtower_ruins ✓ |
| Stone circle (star-gazing spot) | ~(5,−112) | — | NEW stone_circle |
| New path from the lake's north shore | (10,−27) → (−20,−110) | — | terrain path |

## House styles

Each region has its own building language, so players can tell where they are at a glance. All buildings are chunky, hand-painted and slightly crooked, as in the existing models.

| Region | Walls | Roof | Details | Ruined look |
|---|---|---|---|---|
| Village | cream lime-washed stone, timber frames | terracotta tiles | window boxes, round-top doors, lanterns | boarded windows, missing tiles, ivy, a tarp |
| Lake | weathered grey-blue planks on stilts | wooden shingles | rope, nets, buoys, crates | sagging roof, broken planks |
| Farm | ochre and barn-red timber, stone base | thatch or red shingles | flower boxes, fences, sacks | flaking paint, overgrowth, broken fence |
| Forest | logs and moss on a stone base | moss-covered shingles | carved trims, stacked firewood | moss everywhere, fallen branches |
| Coast | white-washed stone | slate grey and blue | blue shutters, shells, sea glass | salt stains, cracked windows |

## Environment and life (the island answers you)
| Trigger | Visible change |
|---|---|
| Plant orchard saplings (Ch. 1) | blossom trees grow in stages; butterflies over the fields |
| Rebuild the bridge (Ch. 2) | birdsong in the forest; deer at dawn near the ancient tree |
| Birdhouses (side quest) | small birds fly between the trees |
| Market Day (Ch. 3) | lamps lit, villagers walk the square, music near the inn |
| Each Glowstone found | the Moonwell glow under the lake grows brighter; more fireflies at night |
| Lighthouse lit (finale) | a beam sweeps at night; the mail boat visits weekly; gulls at the jetty |

Ambient set: fireflies by the lake at night, crabs on the beach, fog over the coast in the morning, wind chimes in the village.

## Quest guidance (implemented)

The journal opens on a Quests tab with every active objective, landmark directions and live progress. The HUD keeps four objectives and points to J for the complete list. Early quests describe routes to Emma, Oliver, Mia, the garden shed and the shop; Emma introduces the cottage mailbox requests.

The village junction keeps one three-arrow signpost, with carved destination lettering and moss-coloured 3D vines. All other signboards and floating location-name replacements are absent: welcome boards, building plaques, farm boards, repair signs, shipping signs and the notice-board model are removed from the active scenes. Quests and existing interaction prompts guide the player.

Daily village requests are available at the existing village mailbox; their saved interaction ID and request progress are unchanged. Bench choices and invitations remain available beside the lakeside bench, without a sign or floating labels. `tests/sign_tests.gd` checks that only the village junction sign loads and that the affected activities remain usable.

## New models to make (Tripo)
The full list of models, their status, priority and generation batches is in [art assets](../art-assets/design.md); prompts are in `docs/TRIPO_ASSET_PROMPTS.md`. Restorable buildings need **two models with the same footprint**: ruined and restored.

## Numbers
| Name | Value | Unit | What to watch in playtests |
|---|---|---|---|
| Path clearance for buildings | ≥ 6 | m | nothing blocks a path or the camera |
| Lamp spacing along paths | ~18 | m | paths readable at night |
| Walk village → farm | ~120 | m (about 70 s at walk speed) | feels like a short stroll, not a trek |
| Walk village → lighthouse | ~330 | m | worth a sprint; no fast travel before the finale |

## Edge cases
- The player reaches a gate before its chapter: the blocker has a short line ("A tangle of brambles. Maybe Mia knows a way through.") and is never an invisible wall.
- A restored building must never change its footprint, so nothing the player stands on moves.
- Saves store restoration as story flags; the world builds its look from the flags on load (see [main story](../main-story/design.md)).

## Open questions
- [ASSUMPTION] There is no fast travel until the mail boat in the finale (it can then stop at the beach and the headland).

## History
- 2026-11-19: designed (plan for placement, styles, environment and models).
- 2026-11-21: model list moved to [art assets](../art-assets/design.md).
- 2026-11-21: all downloaded building, kit and villager models placed; Willow Creek carved into the terrain (D-009).
