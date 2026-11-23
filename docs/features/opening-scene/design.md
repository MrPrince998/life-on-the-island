# Opening scene

**Status:** implemented · **Updated:** 2026-11-21 · [GDD](../../GDD.md)

The first thing a new player sees after **New game**: a 67-second, in-engine "postcard" of the island at dawn, told only through Grandpa's letter. The mail boat brings you in across the sea, the camera drifts over the sleepy village and the quiet lake (with one blink of the strange light), you glimpse Oliver and Emma waking up, and the boat docks at the beach jetty, where the camera settles behind you and you take control. It sets up the **prologue** of the [main story](../main-story/design.md) and introduces its three threads: the cottage, the faded village, the light in the lake. It stays short, wordless apart from the letter, and skippable, so it respects the pillars **your own pace** and **gently curious** (D-007).

## Script: "A Letter from Grandpa"

Each line of the letter appears handwritten on a parchment card at the bottom of the screen, one at a time, while the camera moves. There is no voice-over. Music: soft guitar and piano that swells at the arrival. All positions are world metres (see [world layout](../world-layout/design.md)).

| # | Time | Shot (camera) | What happens | Letter on screen |
|---|---|---|---|---|
| 1 | 0:00–0:09 | **Black → sea at dawn.** Camera low over the water at ~(−170, 300), looking north-east at the island's silhouette; slow push in. | Waves and gulls fade in before the picture. The mail boat crosses the frame towards the island. Far away on the headland, the lighthouse stands dark. | *To my dear grandchild,* · *If you're reading this, the island has finally called you home.* |
| 2 | 0:09–0:19 | **On deck.** Camera behind and above the player at the bow, then drifts round to their side. | The player stands at the bow, Grandpa's letter in hand, hat brim fluttering. Captain Marlow at the wheel lifts his cap and points ahead. | *I've left you my cottage. It's small and a little dusty, but it was always full of light.* |
| 3 | 0:19–0:31 | **Flyover of Willowbrook.** Camera rises from the beach (~(−60, 190), 35 m up) and glides north over the rooftops to the square (0, 115). | Boarded windows, collapsed market awnings, a quiet well, a cat asleep on a step. One chimney smokes: Grandpa's cottage, warm and waiting. | *The village isn't what it was. After the storm, when the lighthouse went dark, most families moved away.* |
| 4 | 0:31–0:41 | **Over Moonlit Lake.** Camera skims low across the lake from the dock (10, 50) towards the lake isle (−8, 2). | Mist on still water, lilies, reeds. For two seconds a soft blue light pulses deep under the water near the isle, then fades. The music holds one quiet note. | *But some things here are still worth finding. You'll know them when you see them.* |
| 5 | 0:41–0:50 | **Two quick portraits.** (a) the dock at (11, 61): Oliver hears the boat's horn and turns to wave. (b) the General Store at (26, 119): Emma swings the shutters open and the window light comes on. | First look at the two people the player will meet first. | *Emma at the store has your key. Oliver will show you the lake. Be kind to them; they were kind to me.* |
| 6 | 0:50–1:02 | **Arrival at the beach jetty** (~(−95, 188)). Side view, then closer. | The boat glides in; two blasts on the horn; gulls lift off the bollards. Captain Marlow tosses the mooring rope. The player steps onto the jetty with an old suitcase and looks up the path towards the village. | *Take your time. The island isn't going anywhere.* · *With love, Grandpa Elias* |
| 7 | 1:02–1:07 | **Hand-off.** The camera swings round behind the player into the normal over-the-shoulder view; the black bars slide away. | "Life on the Island" fades in over the sky for 3 s and out. The HUD fades in; the quest line reads **"Find Emma at the General Store."** The player can move. Captain Marlow waves from the boat. | — |

**Captain Marlow's only line** (shown as a speech bubble in shot 6, like the villagers'): *"Willowbrook! Mind the gap, and give Emma my best."*

## Rules
1. Plays **once**, right after **New game**, before the player can move. **Continue** never plays it. The story flag `opening_seen` is set when it ends or is skipped (D-005).
2. **Holding any key or mouse button for 1 s skips** straight to the end state of shot 7. A small "Hold to skip" hint fades in after 3 s, bottom-right. Esc counts as a skip key; the pause menu is disabled during the scene.
3. **No in-game time passes.** The ActivityClock stays at Day 1, 6:00 AM (dawn light); boat, camera and people move in real time, for presentation only (D-001).
4. A new game **starts at the beach jetty**, not in the village (D-008). The player walks the coast path, past the signpost, to the village (about 110 m; Emma's store is on the way to the cottage).
5. Black bars (letterbox) cover the top and bottom during shots 1–6, and the HUD and minimap are hidden.
6. The scene uses the real island, the real villagers and their schedules (Oliver at the dock and Emma at the store at 6:00), so nothing is faked.
7. It can be replayed later from the journal's **Memories** tab [ASSUMPTION].

## Feel and UI
- **Letter card:** parchment panel from the cozy theme, bottom-centre, 60% of the screen width, handwritten font (a new OFL handwriting font such as Caveat [ASSUMPTION]); each line fades in over 0.6 s and stays until the next line.
- **Sound:** sea, gulls, creaking boat, the horn (two short blasts), a soft whoosh under the flyover, wind chimes over the village, a single low bell-like tone during the lake glow.
- **Camera:** slow, smooth paths with gentle ease in and out; no cuts faster than 1 s; no shake.

## Assets needed
All are listed with status in [art assets](../art-assets/design.md) (batch 1): `mail_boat`, `npc_captain_marlow`, `npc_emma`, `grandpa_letter`, `travel_suitcase`, `seagull`, `jetty_bollard`, `welcome_sign`, `driftwood`, `general_store`, plus Mixamo "Pointing", "Throw", "Arm Stretching" and "Standing Idle". Already in the game: the island, cottage, well, dock, Oliver (wave), lake, lighthouse.

## Numbers
| Name | Value | Unit | What to watch in playtests |
|---|---|---|---|
| Total length | 67 | s | nobody skips before shot 3 out of boredom |
| Letter lines | 8 | lines | each readable before it changes |
| Minimum time per line | 4 | s | slow readers finish every line |
| Skip hold | 1.0 | s | no accidental skips; the skip feels instant once held |
| Skip hint delay | 3 | s | — |
| Letterbox bars | 10 | % of screen height each | — |
| Title card | 3 | s | — |
| Lake glow pulse | 2 | s | players mention "the light in the lake" afterwards |
| Walk jetty → village square | ~110 | m | the player finds the village without a marker (signpost, lamps, path) |

## Edge cases
- **Skipped mid-way:** the boat snaps to moored, the player stands on the jetty, the flag is set and the quest line appears; nothing that the scene "gives" is lost (it gives nothing but the letter, which is in the journal).
- **Quitting during the scene:** the flag is not set yet, so the next New game plays it again; no save exists until the scene ends.
- **The window loses focus:** the scene pauses and resumes on return (no pause menu).
- **A model is late** (not generated yet): the mail boat falls back to a larger `rowboat`, Captain Marlow and Emma are left out of their shots (the shutters still open and the light comes on), and the seagulls are skipped. The script still reads correctly.
- **Low frame rate:** the camera paths are time-based, so the scene keeps its length.
- **Weather:** a new game resets `WeatherManager` to sunny, and weather only changes when a new day starts, so the opening is always clear and dry.

## Open questions
- [ASSUMPTION] Grandpa's name is Elias and the letter never uses the player's name, so no naming screen is needed before it.
- [ASSUMPTION] A handwriting font is added for the letter (OFL licence).
- Should the opening play before or after a naming screen if naming is added later? (Recommended: after, so the letter can use the name.)

## As built
Code: `scripts/ui/opening_scene.gd` (scene `scenes/ui/opening_scene.tscn`), started by `scripts/main/main.gd` when the title screen's New game calls `OpeningScene.request()`. Tests: `tests/opening_tests.gd` (22 checks).
- Uses the real jetty set: `BeachJetty/MailBoat` (moved along a path, then put back exactly where it was placed), `ArrivalPoint` and `CaptainMarlow` (hidden until the boat docks). Without them, a larger rowboat and a beach spot stand in.
- On deck, a copy of the player's character stands at the bow with the suitcase beside them; the real player appears on the jetty at the cut in shot 6.
- The lake light is a soft additive glow and a blue light near the lake isle (2–3 s pulse). The store's window light is a warm light that comes on in shot 5b.
- Oliver turns and waves at the boat (`Villager.wave_towards`); Captain Marlow waves goodbye at the hand-off.
- The first quest (`data/quests/arrival.tres`, "Find Emma at the General Store") starts from the `opening_seen` flag.
- Sound: all synthesised by `tools/generate_opening_audio.py` (no samples, so no licences) into `assets/audio/opening/`: soft guitar and piano music (72 BPM, D major; thinner over the lake, a pad swells at the arrival, the last chord rings under the title), a looping sea (loud at sea and at the jetty, distant over the village), gulls, the horn (far off in shot 5a, two close blasts at the arrival), a whoosh for the flyover, wind chimes over the village, and a low bell for the lake light. A skip fades it all out in under a second.
- Not yet: the boat's creak, Emma opening the shutters (she stands by the store instead), gulls lifting off, the mooring rope, a replay from the journal.

## History
- 2026-11-21: designed (script, shot list, rules).
- 2026-11-21: implemented (67 s: the hand-off is 5 s; the title shows for 3 s). Sound added the same day.
