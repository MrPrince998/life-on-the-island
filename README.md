# Life on the Island

A cozy life-simulation and exploration game made with **Godot 4.7** (Forward+).
Current state: **Phase 5 started**: the greenhouse can be restored. Also farming (12 beds, 3 crops, fertilizer), weather with rain, sitting, fishing, the General Store, villagers and autosave.

## How to run (Windows)

1. Install **Godot 4.7.x stable (standard, not .NET)** from https://godotengine.org/download/windows/
   and unzip it anywhere (for example `C:\Godot`).
2. Unzip the latest `LifeOnTheIsland_….zip` to a folder, e.g. `Documents\LifeOnTheIsland`.
3. Start `Godot_v4.7.x-stable_win64.exe`. In the Project Manager click **Import**,
   pick the `project.godot` file inside the unzipped folder, then click **Import & Edit**.
4. The first time, wait a few seconds while Godot imports the files.
5. Press **F5** (or the ▶ button, top right) to play.

On macOS it works the same way: open Godot, choose **Import**, select `project.godot`, then press **F5**.

## Controls

| Key | Action |
|---|---|
| W A S D | Walk |
| Mouse | Look around |
| Mouse wheel | Move the camera closer or further |
| Shift | Sprint |
| Space | Jump |
| E | Interact (bench, bed, dock, store, garden beds, talk) |
| G | Give a villager a gift |
| U | Ukulele in / out (keys 1–8 play notes) |
| J | Journal: fish, crops, villagers, Grandpa's pages, songs |
| Q | Choose which seeds to plant |
| R | Fishing rod in / out |
| Left Click | Hold to charge a cast, click on a bite, hold to reel |
| Right Click | Reel in / let the fish go |
| Tab or I | Bag |
| Esc | Pause menu (the full controls list is under Settings) |

A gamepad also works (left stick moves, right stick looks, A jumps, X interacts).

## Things to try

- **A quiet corner at Moonlit Lake:** beside the path southwest of the fishing dock, clear three branch piles with **E**, then choose a bench facing the lake or sunset. Use the invitation sign to meet Oliver at the dock and catch a fish beside him for a daily friendship bonus. Birds return the next morning; the bench and progress are saved.

- Walk anywhere. The clock **does not move** while you explore.
- Sit on the porch steps, the lakeshore bench or the end of the dock (**E**). Sitting is free: no time passes. Press **E** again or walk to stand up.
- Sleep in the bed inside the cottage: time skips to 6:00 AM the next day and the sky changes.
- Farm on the **Sunflower Fields** (east of the village):
  1. Pick up Grandpa's watering can and turnip seeds by the garden shed, just inside the farm gate.
  2. Press **E** on an overgrown bed to dig it (15 min), again to plant (5 min), again to water (5 min).
  3. Crops grow only while time passes **and** the soil is damp (one watering lasts a day).
     Sleep, fish or rest, then come back. Turnips planted in the morning are ready the next morning.
  4. Harvest (10 min) and sell turnips, carrots and sunflowers at the General Store.
  Crops never die: dry soil just pauses growth until you water again. More seeds are sold at the store; **Q** switches seeds.
- **Grandpa's ukulele** lies on the cottage floor. Press **U** to play, keys **1–8** for notes (free play uses no time).
  His melodies (shown in the song book while playing) do gentle things: Sunset Song (pass the day until 6 PM),
  Serenade (a villager's day gets brighter), and, from his journal pages, Rain Song, Lake Lullaby and Starlight Song.
- **Villager quests:** when a villager has a request, a **!** floats above them (usually once you're friends, 1 heart). Chat to accept;
  when you have what they asked for, a **?** shows. Talk to them to hand it over. Oliver (Fish Tales, The One That Got Away), Mia (Sunny Seeds),
  Emma (Back in Stock), Theo (A Bench for Elias, after the bridge), Nana Bea (her Garden Pie recipe), Pip, Luna and Mr. Ambrose all have one.
- **Woodcutting:** with an axe, stand by any tree and press E. A few swings and it falls away from you, leaving a stump. Cut the trunk into logs, then pick them up. The stump sprouts again and is a full tree a week later.
- **Bram the blacksmith:** his forge is just south of the village square. He either forges a tool from your materials (cheaper; you wait while he works) or sells one ready-made (dearer; no wait). The Axe takes 4 wood; the Steel Axe takes 6 logs and needs half the swings.
- **Rice, the real way:** Grandpa's paddy is just west of the farm's garden beds.
  1. Work the **pump** at its corner to flood it (20 min). Buy **Rice Seedlings** at the General Store (spring to autumn).
  2. Press **E** in a row to plant it (20 min, one bundle a row). Rice grows a day at a time while the paddy holds water (4 days). Drained, it just waits; it never dies.
  3. When it's golden, **drain** the paddy (the pump again) and cut each row with a **sickle** from Bram (2 logs + 30 coins, or 120 coins). The cut stalks lie in the row.
  4. Press **E** again to gather and tie them into **Rice Sheaves**.
  5. In the **Threshing Shed** at the paddy's north end, the pedal **thresher** beats each sheaf into 3 Unhusked Rice + 1 Straw. The **huller** turns 3 Unhusked Rice into 2 Rice.
  Each step is worth more: sheaves sell for 8, rice for 12 each. Cook it in the Fish and Rice Bowl.
- **Amber Plains and wheat:** the island now reaches further east. Follow the new path from the farm's east gate to **Amber Plains**, a wide flat stretch of farmland with a 10-row wheat field.
  1. **Till** a row with a **hoe** from Bram (1 log + 25 coins). It turns to dark furrowed soil (30 min).
  2. **Sow** it with a sack of **Wheat Seed** from Emma (autumn, winter and spring). No watering: it lives on the rain and is ripe in 5 days.
  3. **Cut** it with a sickle, or a **scythe** from Bram (3 logs + 80 coins), which takes half the strokes and is quicker. Tie the cut wheat into **Wheat Sheaves**; the row then needs tilling again.
  4. The pedal **thresher** by the paddy takes wheat too: 1 sheaf gives 3 Wheat Grain + 1 Straw.
  5. Once the **windmill** is restored, its **millstones** grind 3 grain into 2 **Flour**. Bake flour into a **Fresh Farmhouse Loaf**.
  Wheat is for the cool seasons and rice for the warm ones, so there's always something to grow.
- **Music:** each place has its own gentle track (village, farm and paddy, Amber Plains, lake and forest), with the title theme on the title screen and a finale theme for the credits. Tracks fade into each other as you walk between places, rest quietly for half a minute between plays, dip while you chat or a story jingle plays, and fade out while you play the ukulele. Volume: Settings → Music.
- **Shop view (F):** at the General Store counter or Bram's forge, press F. The camera frames the shop and its keeper, and the shop window opens at the side.
- **Daily notice board:** in the village square. Each morning, villagers you've met pin small requests on it ("Nana Bea would love 3 Carrots for a hearty stew").
  Press **E** to read it and take up to 3 requests; bring the things to that villager for coins and friendship. A **!** over the board means new requests.
  Requests only ask for things you can get this season, never run out once taken, and untaken ones are swapped for new ones after 3 days.
- **Friendship:** chat with villagers once a day and give gifts (**G** next to them, one gift each per day). Everyone has favourites, and hearts (up to 5) show above them while you chat. Good friends share more personal things.
- **Quests** are listed under the minimap: Grandpa's Garden, Friendly Faces, Oliver's Lessons (after he gives you the rod) and Mend the Greenhouse. Steps tick themselves off as you play.
- **Seasons:** every 28 days the season turns (spring, summer, autumn, winter). Summer is lush, autumn turns the meadows gold and the
  broadleaf trees orange and red, winter brings snow. Each crop has its seasons (the store only sells seeds in season):
  spring turnip/carrot, summer carrot/sunflower/tomato, autumn turnip/carrot/pumpkin, winter kale. Crops already planted keep growing.
  Weather follows the season (rainy spring, sunny summer, snowy winter; snow waters the garden too).
- **Weather:** each new day is sunny, cloudy or rainy. Rain waters every dug garden bed for you.
- **Compost bin** (inside the farm gate): one sack of fertilizer every morning. Spread it on a planted bed and it grows twice as fast. The store sells it too.
- **Restore the greenhouse** (south of the farm): bring 8 wooden planks (General Store) and 100 coins, press **E** at its door (2 hours of work).
  It gets cleaned up, lights up at night, and its seedling trays give you free seed packets every morning.
- Visit Fernwood Forest, the Sunflower Fields farm, the Northern Hills and the lighthouse on the Whispering Coast.
  The region name appears when you arrive.

## For developers

- Automated checks: `tools/run_tests.sh` (exit code 0 = all passed; stops itself after 6 minutes)
- Screenshots: `godot --path . res://tests/screenshot_runner.tscn -- --out=/some/folder`
- Layout probe (heights + ASCII map): `godot --headless --path . --script res://tools/probe_layout.gd`
- Rebuild input map: `godot --headless --path . --script res://tools/setup_input_map.gd`
- Character animations: `godot --headless --path . --script res://tools/build_character_animations.gd` rebuilds `resources/animations/character_library.tres` (idle, walk, jump, fish_cast, fish_reel, farm_swing, wave).
- Design brief and rules for Claude: `CLAUDE.md`
- 3D models: Tripo3D `.glb` files live in `source_assets/tripo/`. Prompts for the models still needed are in `docs/TRIPO_ASSET_PROMPTS.md`.

### Architecture (Phase 1)

| Piece | Where | What it does |
|---|---|---|
| `ActivityClock` (autoload) | `scripts/systems/activity_clock.gd` | The only place time lives. Changes only through `advance_minutes(amount, activity_id)`. |
| `GameManager` (autoload) | `scripts/systems/game_manager.gd` | Current region, HUD notifications, interaction prompt. |
| `IslandShape` | `scripts/world/island_shape.gd` | Deterministic landform: coastline, hills, cliffs, lake, flattened village/farm, paths. |
| `IslandTerrain` | `scripts/world/island_terrain.gd` | Builds terrain mesh + heightmap collision from `IslandShape`. Replaceable by Terrain3D later. |
| `VegetationScatter` | `scripts/world/vegetation_scatter.gd` | Scatters the Tripo plant models (chunked MultiMesh, wind shader, trunk collision). |
| `FoliageLayer` data | `data/foliage/*.tres` | One file per plant model: where it grows, how many, size, wind, collision. |
| `DayNightController` | `scripts/world/day_night_controller.gd` | Shows the clock's time of day (sun, sky). Never changes time. |
| `RegionArea`, `WaterBody`, `Interactable`, `RestSpot` | `scripts/world/` | Reusable components with stable string IDs. |
| `CharacterAnimator` | `scripts/player/character_animator.gd` | Picks idle/walk/run/jump from movement; `play_action()` starts fish_cast, fish_reel, farm_swing, wave. |
| `FishingController` | `scripts/systems/fishing/fishing_controller.gd` | Cast → wait → bite → reel → catch, and the fishing time rules. |
| `ReelMinigame` | `scripts/systems/fishing/reel_minigame.gd` | Tension minigame logic (tested on its own). |
| `FishData` / catalog | `data/fish/*.tres` | The five fish: where, when, how hard, size, price. |
| `ItemData` / `ItemDB` | `data/items/*.tres`, `scripts/systems/item_db.gd` | Items (seeds, tools, materials); fish become sellable items automatically. |
| `ShopService`, `ShopPanel`, `ShopCounter` | `scripts/systems/shop/` | Buying and selling rules, the store screen, and the counter you press E at. |
| `FarmField`, `FarmPlot`, `FarmingController` | `scripts/systems/farming/` | The farm (growth from the clock, saving), each garden bed, and the player's dig/plant/water/harvest with its time costs. |
| `CropData` / catalog | `data/crops/*.tres` | Turnip, carrot, sunflower: seeds, grow hours, harvest. Optional per-stage models. |
| `ItemPickup` | `scripts/world/item_pickup.gd` | One-time finds (Grandpa's watering can), remembered in saves. |
| `WeatherManager` (autoload) | `scripts/systems/weather_manager.gd` | Today's weather, rolled each new in-game day; rain waters the farm. `RainEffect` and `DayNightController` show it. |
| `RestorationSite` + `BuildingData` | `scripts/systems/restoration/`, `data/buildings/*.tres` | Run-down look, repair cost and time; sets the story flag `restored_<id>`. |
| `DailyProduce` | `scripts/systems/farming/daily_produce.gd` | Things that make an item each morning (compost bin, greenhouse seedling trays). |
| `QuestLog` (autoload), `QuestData` | `scripts/systems/quest_log.gd`, `data/quests/*.tres` | Quests and their steps (story flags, items, coins or events like "dig"/"catch_fish"); the tracker under the minimap (`scripts/ui/quest_tracker.gd`) shows them. |
| `RequestBoard` (autoload), `RequestBoardPanel`, `NoticeBoardSpot` | `scripts/systems/requests/request_board.gd`, `scripts/ui/request_board_panel.gd`, `scripts/world/notice_board_spot.gd` | The village notice board's daily requests. Taken requests become QuestLog *runtime quests* (deliveries saved with their own definition), so the tracker, the villager **?** and turn-in work like any quest. |
| `Friendship` (autoload), `GiftPanel` | `scripts/systems/friendship.gd`, `scripts/ui/gift_panel.gd` | Hearts per villager (daily chat, gifts), gift tastes from `NPCData`, story flags `hearts_<id>_<n>`. |
| `UkuleleController`, `MelodyData` | `scripts/systems/music/`, `data/melodies/*.tres` | Grandpa's ukulele: synthesized plucked-string sound, free play, melodies and their time rules. |
| `JournalPanel` | `scripts/ui/journal_panel.gd` | The collection journal (J): fish, crops harvested, villagers' hearts and discovered tastes, Grandpa's pages, songs. |
| `InventoryManager`, `Journal` (autoloads) | `scripts/systems/` | Bag contents and fish records, with save-ready `to_dict()`. |
| Player | `scenes/player/player.tscn` | `CharacterBody3D` + over-the-shoulder `SpringArm3D` camera rig. |
