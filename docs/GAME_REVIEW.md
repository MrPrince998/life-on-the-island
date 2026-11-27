# Game review — 28 November 2026

The main story is completable in the automated playthrough. The game already has a substantial connected loop: explore, meet villagers, fish or farm, sell/process goods, restore places, and uncover Grandpa's story. The next development pass should prioritise preserving farming work, teaching the two farming systems clearly, and expanding settings before adding more content.

This is a source review plus automated runtime checks and a visual check of the new review menu. It is not a complete human playtest or a hardware performance benchmark. The story bot checks reachable routes and exercises interactions, but moves the player automatically; it cannot establish whether a new player understands directions or enjoys the pacing.

## Findings, in priority order

| Priority | Finding and evidence | Recommended next change |
|---|---|---|
| P1 | **Partial tractor work is lost on reload.** `CropField._coverage` explicitly stays in memory; `save_state()` stores completed row state, not worked segments. Finishing a row persists, stopping partway does not. This is an intentional current limitation, not a newly introduced regression. | Save tool identity and worked cells per row; restore the same furrows/cut plants and percentage. Add a save/reload test halfway through ploughing, sowing and harvesting. |
| P1 | **Settings are too limited for a wider PC audience.** Settings expose sensitivity, four audio sliders and fullscreen. No graphics presets, resolution choice, frame cap, FOV, invert-look, rebinding, text scale or reduced-motion option. See `GameSettings` and `SettingsPanel`. | Start with graphics quality, frame cap, invert-look and UI/text scaling; then rebind controls and show controller prompts. Do not claim full controller accessibility from movement bindings alone. |
| P2 | **Farming has two different growth clocks.** Garden beds consume damp growing minutes; rice/wheat/corn gain growth on day boundaries. Rice additionally needs flooded soil and must be drained before cutting. Walking advances neither system. All are intentional, but a player can reasonably confuse them. | Add a short first-use explanation and a shared crop status view: growth remaining, water condition, season and next action. Field prompts already show growth days; build on those. |
| P2 | **The design documents disagree with the shipped mechanics.** The GDD still marks journal, weather, seasons and restoration as ideas, and its milestone list predates the implemented chapters. The story design's original windmill price differs from the quest's 180 coins. | Reconcile the feature index and economy numbers with resources before using the documents to plan more work. Treat stated 15–20-hour story length as an unvalidated target. |
| P2 | **Shutdown reports resource/ObjectDB/RID leaks.** Reproduced in the story bot, tests and graphical preview. | Investigate ownership and cleanup, especially repeated title ↔ island transitions. A shutdown leak report alone does not prove steady gameplay memory growth; measure repeated transitions. |
| P2 | **Progression works in automation, but pacing and economic balance remain unvalidated.** A bot obtaining all restoration materials does not prove farming and fishing give equally enjoyable earnings per minute. | Time comparable fishing, garden, rice, wheat, corn and tractor sessions. Include animation, travel, inventory trips and processing. Compare profit and meaningful decisions, not only sale prices. |
| P3 | **Special music coverage is incomplete.** MusicDirector supports evening, night, rain and winter tracks but falls back when assets are absent. | Finish the missing tracks after core gameplay/UX work. Keep the working fallbacks. |
| P3 | **Two orphan import files remain.** The project reference checker reports the two `driftwood… copy.import` files with no source assets. | Clean up the stale import metadata when doing an asset maintenance pass. |

## Systems reviewed

| Area | Current behaviour / review assessment |
|---|---|
| Movement, camera, interactions | Third-person movement, sprint, jump, contextual interaction selection, camera collision and tractor view. Automated coverage exists; crowded-object targeting and camera comfort still deserve a mouse/controller playtest. |
| Story | Arrival → farm/windmill → forest/bridge → market → coast → lighthouse/Moonwell → credits/free play. Flags drive visible restoration, dependent quests and dialogue. Full automated story completed with zero reported problems, including save/continue checkpoints. |
| Quest UI | Four objectives on HUD; J opens all active quests with directions and progress. Later chapter navigation should be tested by a fresh player with only the retained village sign. |
| Garden farming | Dig → plant seasonal seeds → water → grow during activities → harvest. Dry soil pauses growth; fertiliser doubles growth. No crop death. First-use directions explain sleeping and activity time. |
| Large fields | Rice grows in 4 day boundaries, wheat in 5, corn in 6. Rice needs flooding; dry-field tilling and seasonal sowing rules differ. Manual cutting/tying feeds processing; machines shorten labour. Cheats now let each stage be inspected quickly. |
| Tractor | Restoration, mounting, driving, implement selection, lowered tools and segment coverage exist. Completed rows and tractor parking/hitch state persist. Partial row persistence is the priority gap above. |
| Economy and processing | Bag limits, buying/selling, gathering, tools/upgrades, cooking, threshing, hulling, milling, packing and shipping are implemented. Validate throughput and bag pressure with timed sessions before rebalancing. |
| Villagers and side activities | Schedules, introductions, friendship, gifts, requests, lakeside restoration/company and ukulele activities are covered by existing tests. Schedule changes and dialogue readability need human review. |
| Time, seasons, weather | Time advances through activities. Four seasons and sunny/cloudy/rain/snow weather drive visuals and farm conditions. Multi-day jumps are useful test cases, not a substitute for testing ordinary sleep transitions. |
| Audio and visuals | Region music, ambience, action/story/UI sounds, seasonal foliage and painted sky are connected. Sky was visually checked in day, dusk, rain and night in the preceding work. No FPS benchmark or art audit of every asset was performed here. |
| Saving and settings | Versioned JSON saves with a backup and separate settings file. Review cheats branch the save before any mutation. Broader settings and partial tractor persistence remain follow-ups. |

## Temporary review cheats

Open **F8**, or **Esc → Review cheats · F8**, during gameplay. On keyboards using F8 for media, use Fn+F8 or the pause-menu button. Finish an interaction or get off the tractor first.

Opening the menu does not change progress. The first cheat saves your current normal game, then routes all saves to a separate `.review.json` file. A gold review indicator remains visible during play. Return to the title screen and choose Continue to resume the normal game. Restarting also selects the normal save. Review progress is not offered by Continue after returning to the title screen.

Available shortcuts:

- Add 10,000 coins, tools/seeds, or twenty of a chosen item. Normal bag limits still apply; item messages report how many actually fit.
- Repair the tractor without spending materials.
- Plant empty garden beds and field rows; ripen existing crops without advancing time. Existing planted crop types are preserved. Drain ripe rice before harvesting.
- Advance 1/6/24 hours or move to the next 06:00, 12:00, 20:00 or 23:00 using the real activity clock.
- Select sunny/cloudy/rain/snow. Automatic weather changes are suspended for the review and restored when leaving it.
- Unlock Chapters 1–4 or the finale in order, completing preceding quest prerequisites and setting restoration flags. These are forward-only shortcuts, not chapter replay. Materials still fit within normal inventory capacity.
- Complete a selected active quest. This bypasses its objectives, so use it to inspect later content, not to validate that quest's gameplay.
- Travel to the village, farm, tractor, or the current position of Oliver, Mia, Theo, Emma or Luna.

### Suggested 15-minute director's pass

1. Open the menu, get tools and coins, travel to the farm, and plant empty beds/fields.
2. Close it and inspect sowing prompts. Ripen crops, harvest by hand, and try processing/selling.
3. Repair the tractor, travel to it, and try the plough, drill and harvester. Choose a suitable empty/tilled/ripe row for each implement.
4. Unlock each chapter in turn; visit its villager and restored area. Read the journal and remaining objective text.
5. Unlock the finale, give yourself any needed planks/stone, then complete the lighthouse interaction. Test night, the lake and the ending through ordinary interactions.
6. Check rain/night readability and audio, then return to the title screen and Continue your protected normal save.

## Validation record

- New review-cheat tests: **17 passed**, including save isolation, physical Glowstone rewards, repeated story shortcut safety, crop readiness, pause/focus handling and refusing to interrupt locked actions.
- Automated main-story playthrough: **STORY COMPLETE, zero reported problems**.
- Full regression suite: **1,045 passed, zero failed**. An initial run using `--fixed-fps 60` hit its watchdog without a reported assertion failure; rerun uses the documented command without that option.
- Menu bounds and rendering checked in 1280×720 and 2560×1080 viewports, plus an in-game screenshot. Project reference checker: zero errors, two pre-existing orphan import warnings.
- Documentation checker: zero errors and 24 existing feature-document coverage warnings; the project currently mixes design-only notes with fuller feature docs. Existing shutdown resource-leak diagnostics remain; they are not counted as passing memory validation.

Re-run cheat tests with `Godot --headless --path . res://tests/review_runner.tscn`. The test runner uses its own process-specific save file. Review tools are intentionally available in this development build; remove the menu integration before a public release.
