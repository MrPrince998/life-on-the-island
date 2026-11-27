# Suno music prompts for Life on the Island

Background music for the game, made in Suno. All tracks share one sound: warm acoustic folk with
**Grandpa's ukulele** as the signature instrument. Every prompt repeats that, so the tracks belong together.

## How to make each track
1. In Suno, choose **Custom** mode and turn **Instrumental** ON.
2. Paste the **Style** text into "Style of Music" and the **Title** into the title box. Leave the lyrics empty.
3. Generate. Suno makes two versions: keep the one you like better. Regenerate if it has singing,
   heavy drums or a sudden loud part.
4. Download it as **MP3** (or WAV if your plan allows) and rename it to the exact **File name** below.
5. Put the files in `source_assets/music/` and tell Claude "music added". Claude trims the starts and ends,
   makes them loop smoothly, and plays the right one for the place, time of day, season and weather.

**Licence:** on Suno's free plan the music can't be used in a game you sell. Make the final tracks on a
paid plan (Pro or Premier), and check Suno's current terms before release. If the game goes on Steam,
tick the "AI-generated content" disclosure.

**Status marks:** ⬜ = not made yet, ✅ = made and playing in the game.

**Progress:** 6 of 10 made. Still to make: `evening.mp3`, `night.mp3`, `rain.mp3`, `winter.mp3`.
Drop them into `source_assets/music/` with these exact names and the game picks them up by itself
(until then, the place's own track plays instead, and the calm lake track plays late at night).

**Sound effects:** Suno's effects didn't come out natural enough, so they're being made another way.

## Must-have (make these first)

**`title_theme.mp3`** — Title screen — ✅ in the game
- Title: `Life on the Island`
- Style: `instrumental, warm acoustic folk, gentle ukulele melody, nylon guitar, soft felt piano, light strings, nostalgic and hopeful, cozy island morning, 84 bpm, no vocals`

**`village_day.mp3`** — Willowbrook Village in the daytime — ✅ in the game
- Title: `Willowbrook Morning`
- Style: `instrumental, cheerful acoustic folk, bright ukulele and mandolin, wooden flute melody, soft shaker, easygoing village stroll, sunny and friendly, 100 bpm, no vocals`

**`fields_day.mp3`** — the farm, the rice paddy and field work — ✅ in the game
- Title: `Working the Fields`
- Style: `instrumental, upbeat acoustic folk, strummed guitar, warm fiddle melody, ukulele, soft kick drum, steady walking rhythm, sunny farm work, content and calm, 96 bpm, no vocals`

**`amber_plains.mp3`** — Amber Plains and the wheat fields — ✅ in the game
- Title: `Amber Plains`
- Style: `instrumental, wide open acoustic, slow fingerpicked guitar, soft string pads, gentle french horn, golden fields in the wind, spacious and peaceful, 78 bpm, no vocals`

**`evening.mp3`** — everywhere from about 6 PM ⬜
- Title: `Evening Glow`
- Style: `instrumental, slow warm acoustic, fingerpicked ukulele, cello, soft piano, sunset after a long day, tender and relaxed, 70 bpm, no vocals`

**`night.mp3`** — everywhere late at night ⬜
- Title: `Quiet Night`
- Style: `instrumental, sparse lullaby, celesta and soft piano, warm ambient pads, starry sky, sleepy and safe, very gentle, 60 bpm, no vocals, no drums`

## Nice to have

**`lake_forest.mp3`** — Moonlit Lake and Fernwood Forest — ✅ in the game
- Title: `Moonlit Lake`
- Style: `instrumental, gentle and mysterious, harp-like plucks, kalimba, soft clarinet, airy pads, still water and old trees, calm wonder, light reverb, 72 bpm, no vocals`

**`rain.mp3`** — rainy days ⬜
- Title: `Rainy Day`
- Style: `instrumental, mellow acoustic, soft piano, brushed drums, upright bass, nylon guitar, cozy rainy afternoon indoors, warm and unhurried, 76 bpm, no vocals`

**`winter.mp3`** — winter days ⬜
- Title: `Winter Hearth`
- Style: `instrumental, cozy winter acoustic, soft bells, celesta, piano, warm strings, gentle ukulele, snow outside a warm fire, 72 bpm, no vocals`

**`finale.mp3`** — the finale at the moonwell and the credits — ✅ in the game
- Title: `Light Beneath the Lake`
- Style: `instrumental, emotional acoustic finale, ukulele main melody returns, swelling strings, piano, soft choir pad, hopeful homecoming, cinematic but gentle, 76 bpm, no vocals`

## Tips
- Don't put artist or game names in prompts. Suno blocks them, and the music should be our own.
- Any length from 2 to 4 minutes is fine.
- If a track comes out too busy, add `minimal, soft dynamics` to the end of the style and regenerate.
- If a track sounds too sad, swap `tender` or `nostalgic` for `warm, gently happy`.

---

# Sound effects (trying Suno for these too)

Suno is built for music, so sound effects are an experiment. Try a few; anything that doesn't sound
natural, Claude can still build from recorded-style noise instead.

## How to make each sound
1. If your Suno has a **Sounds** option (one-shot or loop), use it. Otherwise use **Custom** mode with
   **Instrumental** ON and paste the prompt into "Style of Music".
2. Every prompt starts with `sound effect only, no music`. If Suno still adds a melody or a beat,
   regenerate, or add `no melody, no instruments` to the end.
3. A long clip, or one with several hits in it, is fine: Claude cuts out the best part and makes loops seamless.
4. Download (WAV if you can, MP3 is fine), rename to the **File name** below and put it in
   `source_assets/sfx/`. Then tell Claude "sounds added".

## Woodcutting and the forge

**`axe_chop.mp3`** ⬜
`sound effect only, no music, an iron axe chopping into a thick tree trunk, several separate chops with pauses, deep wooden thunk and crack, outdoors, close up`

**`tree_fall.mp3`** ⬜
`sound effect only, no music, a large tree creaking and splitting at the base, slowly toppling over, leaves and branches swishing, then a heavy thud on grass, outdoors`

**`logs_pickup.mp3`** ⬜
`sound effect only, no music, cut wooden logs being picked up and stacked, hollow wooden knocks and bark scraping, outdoors, close up`

**`anvil_forge.mp3`** ⬜
`sound effect only, no music, a blacksmith hammering hot metal on an anvil, bright ringing clangs with pauses, then a hiss of quenching in water`

**`forge_fire_loop.mp3`** ⬜
`sound effect only, no music, a crackling forge fire with glowing coals, soft bellows breaths, steady and even, seamless loop`

## Rice and wheat

**`sickle_cut.mp3`** ⬜
`sound effect only, no music, a sickle slicing through dry rice stalks, quick swish and crisp tearing of straw, several separate cuts, close up`

**`scythe_sweep.mp3`** ⬜
`sound effect only, no music, a long scythe sweeping through ripe wheat, long airy swoosh and crisp stalks falling, several slow sweeps, outdoors`

**`hoe_soil.mp3`** ⬜
`sound effect only, no music, a steel hoe striking and breaking up soft farm soil, dull earthy thuds and crumbling dirt, several strokes, outdoors`

**`pump_water.mp3`** ⬜
`sound effect only, no music, an old iron hand pump creaking and squeaking, water gushing out into a wooden trough and splashing into a shallow flooded field`

**`straw_tie.mp3`** ⬜
`sound effect only, no music, gathering an armful of dry straw and tying it into a bundle, rustling and crackling straw, close up`

**`thresher_loop.mp3`** ⬜
`sound effect only, no music, an old wooden pedal-powered threshing machine, spinning drum whirring and rattling, grain pattering, foot treadle clacking, steady seamless loop`

**`huller_loop.mp3`** ⬜
`sound effect only, no music, a hand-cranked wooden rice huller, wooden gears turning and grinding grain, husks rustling, steady seamless loop`

**`millstone_loop.mp3`** ⬜
`sound effect only, no music, heavy stone millstones grinding grain inside a wooden windmill, deep rumble and creaking wooden gears, steady seamless loop`

## Coming next: machines (slice 4)

**`tractor_idle.mp3`** ⬜
`sound effect only, no music, an old small farm tractor engine idling, steady low chugging, slight rattle, seamless loop`

**`tractor_drive.mp3`** ⬜
`sound effect only, no music, an old small farm tractor driving slowly across a dirt field, engine chugging under load, tyres crunching soil, seamless loop`

