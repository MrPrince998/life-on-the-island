# Art assets

**Status:** designed · **Updated:** 2026-11-21 · [GDD](../../GDD.md)

The one list of every model, prop, character, animation and ambient effect the game needs, each tied to the story moment that uses it. **Where** a building stands is in [world layout](../world-layout/design.md); **why** it matters is in [main story](../main-story/design.md) and [side quests](../side-quests/design.md); the **prompt text** to generate each model is in [TRIPO_ASSET_PROMPTS.md](../../TRIPO_ASSET_PROMPTS.md). This note owns the list, the status and the order. It serves the pillar **the island answers you**: anything the story restores needs a ruined and a restored model.

**Status words:** ✓ in game · ◐ downloaded, not placed yet · ○ needed.
**Priority:** P0 opening scene and prologue (M4) · P1 chapters 1–2 (M5) · P2 chapters 3–4 (M6) · P3 finale, side quests and later.

## Placement pass (2026-11-21)
**Now in the game (✓):** all seven new villagers (`npc_emma`, `npc_theo`, `npc_luna`, `npc_nana_bea`, `npc_pip`, `npc_mr-ambrose`, `npc_captain_marlow`; each with the 15 villager animations); `mail_boat`, `suitcase`, `journal_page` (pages 1, 2, 3, 4 and 7, readable), `crystal_shard` (glowing Glowstones at the shrine and the sea cave), `notice_board`, `welcome_sign`, `driftwood`, `mooring-post`, `mailbox`, `firewood_stack`, `fish_crate`, `potted_plant`, `basekt_of_vegetables`, `wooden_chair` (cottage yard), `street_lamp` (15 along the paths), `barzier`; `market-stall` + `collapsed_market_stall`, `ruined_village_house` (×4; the restored look reuses `house`), `village_inn` + `village_inn_ruined`, `village_library`, `fisherman's_shelter`, `boathouse` + `ruined_lakeside_boathouse`, `dock_warehouse`, `windmill` + `ruined_windmill`, `bramble_bush` (Ch. 1 gate), `beehive`, `bale`, `wheelbarrow`, `sunflower` (along the farm path), `tree_strump` (dead orchard; restored as `blossom_sapling`), `stone_arch_bridge` + `bridge` (broken), `carpenter's_workshop` + `ruined_carperter's_workshop`, `ancient_oak` (the sleeping look is the same model, tinted), `ancient_forest_shrine`, `mushroom_circle`, `branch-pile`, `mossy_fallen_log`, `boulder` (forest path and the Ch. 4 rockfall), `lighthouse_keeper's_cottage`, `cave_entrance`, `crystal_formation`, `shipwreck`, `watchtower_ruins`, `seagull` (5 gliding).

**Cottage interior (✓, 2026-11-21):** `bed` (sleep here), `writing_desk` with `journal` and journal page 1, two `wooden_chair`s (sit at the desk or by the window), `bookshelf`, `stove`, `braided_rug`, `oil-lamp` (bedside and hanging), `chest`, `small_storage_chest`, `suitcase`, `firewood_stack`, `potted_plant`, `basekt_of_vegetables`. See `scenes/buildings/cottage_interior.tscn`.

**Downloaded but not placed (◐), and why:** `key`: a held item for the prologue. `turnip`, `turnip_seedling`, `crop_carrot`, and `sunflower` as a crop stage: about 20k triangles each and up to 9 per bed, so they need simplifying before farm plots can use them. `watering_can`: Grandpa's can still uses `wooden_watering`. `dock`: the jetty reuses the fishing dock's `platform`. `driftwood copy`: a duplicate.

## Rules
1. **One style line for every model:** chunky, rounded, hand-painted, warm saturated colours, slightly crooked, no ground base (the style line in the prompts doc).
2. **Scale references:** the player is 1.76 m; doors 2.1 m; benches seat 0.45–0.55 m; a village house 6–8 m tall. Claude scales each model on import.
3. **Restorable = two models, same footprint.** The ruined and restored versions share size and door position, so nothing the player stands on moves (world layout, edge cases).
4. **Triangle budgets:** props 3k–10k, buildings 10k–25k, characters 15k–30k, scattered vegetation under 5k. Bigger Tripo models get decimated or LOD'd before scattering.
5. **File names** are lower_snake_case and match the names below, so the game can pick them up automatically. Models go in `source_assets/tripo/`.
6. **Characters** use the same A-pose and proportions as the player, then Tripo Auto-Rig (Mixamo bone names), so every Mixamo animation fits them ([villagers](../villagers/design.md) has their descriptions).
7. **Nothing is generated before its priority comes up.** The next batch is the P0 list.

## Characters
| Model | Status | First seen | Priority |
|---|---|---|---|
| player (`tripo_convert_…`) | ✓ | opening scene | — |
| `Oliver_character` | ✓ | opening scene (dock), prologue | — |
| `Mia_character` | ✓ | Ch. 1 | — |
| `npc_emma` | ○ | opening scene (store shutters), prologue (key) | P0 |
| `npc_captain_marlow` | ○ | opening scene (mail boat) | P0 |
| `npc_theo` | ○ | Ch. 2 (bridge) | P1 |
| `npc_pip` | ○ | Ch. 1 onward | P1 |
| `npc_luna` | ○ | Ch. 4 (headland) | P2 |
| `npc_mr_ambrose` | ○ | Ch. 3 (library) | P2 |
| `npc_nana_bea` | ○ | Ch. 3 (inn) | P2 |
| `npc_villager_a` / `_b` / `_c` / `_d` (families who move back) | ○ | Ch. 3 Market Day | P2 |

## Story props (things the plot hinges on)
| Model | Status | Used in | Priority |
|---|---|---|---|
| `grandpa_letter` (envelope, wax seal) | ○ | opening scene, prologue step 1 | P0 |
| `cottage_key` (big old iron key) | ○ | prologue step 2 (Emma hands it over) | P0 |
| `grandpa_journal` (leather book, strap) | ○ | cottage desk; the journal UI's cover | P0 |
| `journal_page` (loose folded page) | ○ | pages 1–10, glowing softly where they lie | P0 |
| `travel_suitcase` (old leather case, stickers) | ○ | opening scene, then by the cottage bed | P0 |
| `mail_boat` (small steam/sail mail boat, room for 3 on deck) | ○ | opening scene; weekly visits after the finale | P0 |
| `glowstone_shard` (blue-white crystal, glows) | ○ | Ch. 1–4, the five shards | P1 |
| `notice_board` (wooden, roof, pinned papers) | ○ | by the well; side-quest starts | P0 |
| `photo_frame_grandpa` (frame, back of photo shown) | ○ | cottage desk; Oliver's heart scene | P1 |
| `message_bottle` (corked, rolled note) | ○ | Ch. 4 page 8; side quest "Message in a Bottle" | P2 |
| `captains_chest` (sea chest, brass corners) | ○ | Ch. 4, shipwreck (shard 5) | P2 |
| `lighthouse_lens` cracked and whole | ○ | Ch. 4 (cracked), finale (whole) | P3 |
| `memorial_stone` (small engraved stone, flowers) | ○ | side quest "A Bench for Elias" | P3 |

## Buildings and landmarks
Placement for each is in [world layout](../world-layout/design.md#building-placement).

| Model | Status | Story | Priority |
|---|---|---|---|
| `house` (Grandpa's cottage) | ✓ | player home | — |
| `general_store` | ○ (store reuses the cottage model today) | prologue | P0 |
| `village_well`, `signpost`, `lantern_post`, `street_lamp` | ✓ ✓ ✓ ◐ | village | P0 (place lamps) |
| `market-stall` + `market_stall_ruined` | ◐ + ○ | Ch. 3 Market Day | P0 ruined (visible from day 1), P2 restored placed |
| `village_house_a`, `village_house_b` (two colourways) + `village_house_ruined` | ○ | boarded at start; families return in Ch. 3 | P0 ruined, P2 restored |
| `village_inn` + `village_inn_ruined` | ◐ + ○ | Nana Bea, Ch. 3 | P0 ruined, P2 |
| `village_library` | ◐ | Mr. Ambrose, Ch. 3 | P2 |
| `dock`, `platform`, `rowboat` | ◐ ✓ ✓ | lake; the beach jetty for the opening scene reuses `dock` | P0 (jetty) |
| `fisherman's_shelter` | ◐ | Oliver's home | P0 |
| `boathouse` + `boathouse_ruined` | ◐ + ○ | "Fish Tales" → fishing shop | P1 |
| `dock_warehouse` | ◐ | Ch. 3 | P2 |
| `farmhouse`, `small_barn`, `greenhouse`, `garden_shed`, `scarecrow`, `compost_bin`, `wooden_watering` | ✓ | farm | — |
| `windmill` + `windmill_ruined` | ○ | Ch. 1 (shard 1) | P1 |
| `bramble_hedge` (gate) | ○ | Ch. 1 gate | P1 |
| `beehive` | ○ | "Bee Kind" | P1 |
| `stone_arch_bridge` + `stone_arch_bridge_ruined` | ◐ + ○ | Ch. 2 gate | P1 |
| `carpenter_workshop` + `carpenter_workshop_ruined` | ○ | Theo's home, Ch. 2 | P1 |
| `ancient_tree_bare` + `ancient_tree_leafy` | ○ | Ch. 2 finale | P1 |
| `ancient_forest_shrine` | ◐ | Ch. 2 (shard 2) | P1 |
| `mushroom_circle` | ◐ | "The Mushroom Ring" | P1 |
| `birdhouse` | ○ | "Birdhouses" | P3 |
| `lighthouse` | ✓ | finale | — |
| `lighthouse_keeper's_cottage` | ◐ | Luna's home | P2 |
| `cave_entrance`, `crystal_formation` | ◐ | Ch. 4 sea cave (shard 4) | P2 |
| `shipwreck` | ◐ | Ch. 4 (shard 5) | P2 |
| `beach_hut` | ○ | coast dressing | P2 |
| `rockfall` (boulder pile, readable as "clear me") | ○ | Ch. 4 gate | P2 |
| `watchtower_ruins` | ◐ | "The Old Watchtower" | P2 |
| `stone_circle` | ○ | "Starlight Survey" | P3 |
| `telescope` | ○ | "Starlight Survey" reward | P3 |

## Set dressing kits
Small props that make each place feel lived-in. Each kit is placed as a group around its building. ✓/◐ items are reused; ○ items are new.

| Kit | Where | Props | New models |
|---|---|---|---|
| **Village square** | around the well | notice board, 2 benches, flower barrels, cobble patch, brazier (`barzier` ◐), bunting between lamps (Ch. 3) | `flower_barrel`, `bunting_string` (P2), `village_cat` (P1) |
| **Store front** | General Store | crates ✓, barrels ✓, produce baskets, chalkboard sign, potted plants | `produce_basket`, `chalkboard_sign`, `potted_plant` (P0) |
| **Boarded house** | each ruined house | planks across windows (part of the ruined model), weeds, a tipped bucket | `wooden_bucket` (P0) |
| **Cottage yard** | Grandpa's cottage | mailbox, firewood stack, washing line, porch chair, flower boxes | `mailbox`, `firewood_stack`, `washing_line` (P0) |
| **Cottage interior** | inside the cottage | bed, desk with journal, chair, bookshelf, stove, rug, lamp, trunk | `bed`, `writing_desk`, `wooden_chair`, `bookshelf`, `wood_stove`, `round_rug`, `oil_lamp`, `storage_trunk` (P0) |
| **Dock** | fishing dock, shelter | rope coils, nets on a rack, buoys, fish crate, bait bucket, lanterns ✓ | `fishing_net_rack`, `buoy_set`, `fish_crate` (P0) |
| **Beach jetty** | arrival point | crates ✓, bollards, a "Willowbrook" welcome sign, driftwood | `jetty_bollard`, `welcome_sign`, `driftwood` (P0) |
| **Farm yard** | Sunflower Fields | hay bales, sacks, wheelbarrow, tool rack, milk cans, sunflowers | `hay_bale`, `grain_sacks`, `wheelbarrow`, `tool_rack` (P1), `sunflower` (P1) |
| **Workshop** | Theo's | sawhorse, plank stack, log pile, workbench | `sawhorse`, `plank_stack`, `workbench` (P1) |
| **Forest path** | Fernwood | fallen log, moss rocks, stumps (`tree_strump` ◐), mushrooms ✓, ferns ✓ | `fallen_log`, `mossy_rock` (P1) |
| **Market Day** | square, Ch. 3 | goods on each stall: fish, vegetables, flowers, bread, jars | `stall_goods_fish`, `stall_goods_veg`, `stall_goods_flowers`, `jam_jars` (P2) |
| **Headland** | lighthouse, keeper's cottage | anchor, lobster pots, coiled rope, wind-bent grass | `anchor`, `lobster_pot` (P2) |
| **Beach** | coast | shells, sea glass, crabs, tide-pool rocks | `beach_rocks` (P2) |

## Gatherables and collectibles
| Model | Gives | Where | Priority |
|---|---|---|---|
| `branch_pile` ✓ | wood (→ planks at the sawhorse) | forest, meadows round the village, lake west shore (GatherSpawner) | P1 |
| `stone_node` (uses `boulder` ✓) | stone | hills, coast path, forest north, west beach (GatherSpawner) | P1 |
| `herb_patch` | herbs | forest, meadows | P1 |
| `wild_flowers` (`flowers` ◐) | flowers | meadows | P1 |
| `shell_a`…`shell_e` (5 kinds) | shells | beach ("Shells for Pip") | P2 |
| `sea_glass` | sea glass | beach ("Sea Glass Garden") | P3 |
| `glowcap_mushroom` | rare mushroom | mushroom ring at night | P3 |
| `fish_moonfin_koi` | fish | lake at night ("The One That Got Away") | P1 |

## Wildlife and ambience
Small, slow, peaceful; they appear as the island is restored ([world layout](../world-layout/design.md#environment-and-life-the-island-answers-you)).

| Item | Made as | Appears | Priority |
|---|---|---|---|
| seagulls | `seagull` model gliding on a path (no flapping needed) | opening scene; coast | P0 |
| butterflies | particles (no model) | fields after Ch. 1 | P1 |
| songbirds | `songbird` model, simple hop/fly by code | forest after Ch. 2 | P1 |
| deer | `deer` model in a grazing pose; fades in at dawn and out when the player comes close | ancient tree after Ch. 2 | P3 |
| village cat | `village_cat` model, sleeps in sun spots | village | P1 |
| bees | particles | beehives | P1 |
| crabs | `crab` model, side-steps by code | beach | P2 |
| fireflies | particles | lake at night, more per Glowstone | P1 |
| Moonwell glow | shader and light under the lake | brightens per chapter | P0 (dim version for the opening scene) |
| fish shadows | decals moving under the water | lake | P1 |

## Animations (Mixamo, "Without Skin", 30 fps)
Already in: player walk, run, fishing idle and cast; villager idle, look around, happy, nod, wave, 3 talks, thinking, walk, sit down, sitting, stand up, planting, watering.

| Needed for | Search on Mixamo | Priority |
|---|---|---|
| opening scene, player at the bow | "Standing Idle" (letter in hand, pose fixed by code) | P0 |
| opening scene, Captain Marlow | "Pointing", "Throw" (the mooring rope) | P0 |
| prologue, Emma | "Arm Stretching" (opening shutters), reuses talk/wave | P0 |
| player picks things up | "Picking Up" | P0 |
| player reads (journal page) | "Reading" | P0 |
| player sleeps | "Laying Idle" or "Sleeping Idle" | P1 |
| player waters, digs, plants | reuse "Watering Plant", "Planting"; search "Digging" | P1 |
| restoration (player and Theo) | "Hammering", "Sawing" | P1 |
| carrying planks | "Carrying" | P2 |
| Market Day and finale crowd | "Clapping", "Cheering" | P2 |

## Production order (batches of about 10 models)
1. **Batch 1 (P0, opening scene):** `mail_boat`, `npc_captain_marlow`, `npc_emma`, `grandpa_letter`, `travel_suitcase`, `seagull`, `jetty_bollard`, `welcome_sign`, `driftwood`, `general_store`.
2. **Batch 2 (P0, prologue):** `cottage_key`, `grandpa_journal`, `journal_page`, `notice_board`, `village_house_ruined`, `market_stall_ruined`, `village_inn_ruined`, `mailbox`, `firewood_stack`, `fish_crate`.
3. **Batch 3 (P0, cottage interior):** `bed`, `writing_desk`, `wooden_chair`, `bookshelf`, `wood_stove`, `round_rug`, `oil_lamp`, `storage_trunk`, `potted_plant`, `produce_basket`.
4. **Batch 4 (P1, Ch. 1):** `windmill`, `windmill_ruined`, `bramble_hedge`, `glowstone_shard`, `beehive`, `sunflower`, `hay_bale`, `wheelbarrow`, `npc_pip`, `fish_moonfin_koi`.
5. **Batch 5 (P1, Ch. 2):** `stone_arch_bridge_ruined`, `carpenter_workshop`, `carpenter_workshop_ruined`, `ancient_tree_bare`, `ancient_tree_leafy`, `npc_theo`, `boathouse_ruined`, `branch_pile`, `stone_node`, `fallen_log`.
6. Batches 6 onward follow P2, then P3.

## Numbers
| Name | Value | Unit | What to watch in playtests |
|---|---|---|---|
| Models in game ✓ | about 40 | models | — |
| Downloaded, not placed ◐ | 17 | models | place them with world layout's P0/P1 work |
| New models ○ | about 80 | models | about 8 batches; one batch per milestone step |
| Batch size | 10 | models | one evening of Tripo generation |
| Opening-scene models (batch 1) | 10 | models | the opening can ship with fallbacks if a model is late ([opening scene](../opening-scene/design.md#edge-cases)) |

## Edge cases
- A model arrives tilted, floating or with a ground disc: Claude levels it, drops it to the ground and strips the base on import (the water trough fix, 2026-11-19).
- A ruined/restored pair with different footprints: regenerate the one that differs; never move the building.
- A character without Mixamo bone names: re-run Tripo Auto-Rig; the NPC animation builder needs `mixamorig_` bones.

## Open questions
- [ASSUMPTION] Gatherables (wood, stone, herbs) are visible world nodes, not menus; their gathering rules belong to a future gathering feature note.
- [ASSUMPTION] Deer and songbirds move by simple code, not rigged animation.
- [ASSUMPTION] The General Store gets its own model (`general_store`), so the store and the cottage stop looking identical.

## History
- 2026-11-21: designed; first full asset list aligned with the main story and world layout.
- 2026-11-21: placement pass; see "Placement pass" above.
