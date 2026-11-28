# Tripo3D prompts for Life on the Island

These prompts match the look of the models already in the game (broadleaf tree, palm, bush, fern,
grass clump, lantern post): soft hand-painted textures, warm saturated colours and chunky, friendly shapes.

## How to deliver a model
1. Generate it in Tripo (text-to-3D). Use the **Stylized** style if offered.
2. Download it as **.glb** with textures.
3. Save it into `source_assets/tripo/` using the **exact file name** given below.
4. Tell Claude "new models added". Claude scales them, places them and adds collision.

**Status marks:** ✅ = you've made it and it's in the game ("as `file.glb`" is the name you saved it under). ⬜ = not made yet; the game uses a simple built-in look until it exists.

**Rules that help every model**
- One object per generation, centred, standing upright, nothing else in the scene.
- **No ground base, no soil disc and no grass patch under the object** (except where stated). Bases look like mats on the terrain.
- Target polygon budget: plants and props 3k–10k triangles, buildings 10k–25k, characters 15k–30k.

Paste this **style line** at the end of every prompt:

> *stylized cozy game asset, hand-painted texture, soft rounded shapes, warm vibrant colours, clean silhouette, no ground base, isolated on plain background*

---

## Priority 1: what the player sees most

**`player_character.glb`** — ✅ in the game as `tripo_convert_5283d58f-c5ab-416f-b627-ea86d64e6fa6.glb`: the player
> young adult islander, friendly face, wide woven straw sun hat, loose light-cream linen shirt with rolled sleeves, teal waistcoat, rolled brown trousers, sturdy leather boots, small canvas satchel on one hip, standing in A-pose with arms slightly away from body, full body, chibi-leaning proportions with slightly large head

Then use Tripo's **Auto-Rig** (humanoid) and download the rigged .glb. If you'd rather the main character be a particular gender or look, change the description; the rest still applies.

**`cottage_exterior.glb`** — ✅ in the game as `house.glb`: Grandpa's Cottage
> small old island cottage, cream lime-washed stone walls, weathered terracotta tile roof, crooked stone chimney, wooden front door with round top, two small square windows with wooden shutters and flower boxes, little covered wooden porch with two steps, ivy climbing one corner, slightly worn and charming, single storey

(Tripo models are solid shells, so Claude will keep a separate interior room behind the door.)

**`flowers_cluster.glb`** — ✅ in the game: replaces the current flowers patch, which has a base
> small cluster of mixed wildflowers, daisies, orange poppies, pink and blue bell flowers on thin green stems with a few leaves, no soil, no grass base, no stones

**`rock_boulder_a.glb`** — ✅ in the game
> rounded mossy grey boulder, soft chunky shape, patches of green moss on top, about as wide as it is tall

**`rock_boulder_b.glb`** — ✅ in the game as `boulder.glb`
> wide flat grey stone slab with cracks and a little moss, low and broad

**`rock_cluster.glb`** — ✅ in the game: gatherable stone piles, alongside the new pebble variants
> cluster of three small smooth grey pebbles and stones of different sizes, sitting together

## Priority 2: Moonlit Lake and the village

**`dock_segment.glb`** — ✅ in the game as `platform.glb`: modular piece; Claude repeats it to build any length of pier
> straight section of a wooden fishing pier, weathered grey-brown planks across two thick support beams, four round wooden posts going down underneath, rope wrapped around one post, length about three times its width

**`dock_platform.glb`** — ✅ in the game as `platform.glb`
> square wooden pier end platform, weathered planks, short wooden posts at the four corners, one coil of rope and a small wooden crate on top, posts extending down underneath

**`reeds_cattails.glb`** — ✅ in the game
> clump of tall lake reeds and cattails with brown fluffy cattail heads, slender green blades, slightly leaning

**`water_lily.glb`** — ✅ in the game as `lily_pad_pink_flower.glb`
> floating round water lily pads with one open pink water lily flower, flat

**`stone_well.glb`** — ✅ in the game as `village_well.glb`
> round village well, stacked grey stone ring, small wooden roof with terracotta tiles on two posts, wooden crank with rope and a wooden bucket

**`signpost.glb`** — ✅ in the game
> wooden village signpost, single thick post with three blank arrow-shaped boards pointing different directions, slightly crooked, mossy base

(The boards stay blank so Claude can put readable text on them.)

**`bench_wooden.glb`** — ✅ in the game as `garden_bench.glb`
> rustic wooden garden bench with backrest, thick planks, slightly worn

**`fence_segment.glb`** — ✅ in the game as `fence.glb`: modular
> one straight section of rustic wooden farm fence, two horizontal rails between two posts, posts slightly uneven

## Priority 3: variety and landmarks

**`tree_pine.glb`** — ✅ in the game as `pine_tree.glb`
> tall stylized pine tree, layered soft rounded clumps of dark green needles, straight reddish-brown trunk, no ground base

**`tree_broadleaf_b.glb`** — ✅ in the game as `broadleaf_tree.glb`: a second broadleaf with a different silhouette
> tall slender stylized tree with an oval light-green leafy crown made of soft leaf clumps, thin twisting trunk, no ground base, no roots spreading on the ground

**`tree_blossom.glb`** — ✅ in the game as `blossom_tree.glb`
> small stylized cherry blossom tree, wide rounded umbrella-shaped crown made of fluffy clumps of soft pink blossoms with pale pink and white highlights, short thick curved brown trunk splitting into three gently twisted branches that peek through the crown, crown about twice as wide as the trunk is tall, no ground base, no roots spreading on the ground, no fallen petals

**`tree_blossom_large.glb`** — ✅ in the game as `cherry_blossom.glb` (optional landmark for the village square)
> large old stylized cherry blossom tree, broad layered crown of soft pink blossom clumps drooping slightly at the edges, thick gnarled brown trunk with a gentle lean, a few smooth bare branch tips showing, no ground base, no roots spreading on the ground

**`tree_blossom_sapling.glb`** — ✅ in the game as `blossom_sapling.glb` (optional, for player-planted trees)
> young stylized cherry blossom sapling, thin slightly curved trunk, small round crown of a few soft pink blossom clumps, no ground base

**`mushroom_cluster.glb`** — ✅ in the game as `mushroom.glb`
> cluster of three cute forest mushrooms with red caps and white spots, plus two small brown mushrooms

**`lighthouse.glb`** — ✅ in the game
> small seaside lighthouse, round white-washed stone tower with one wide red stripe, black iron lantern room with glass windows at the top, red conical roof, small wooden door at the base

**`rowboat.glb`** — ✅ in the game
> small wooden rowboat, weathered teal paint, two oars resting inside, coil of rope

**`crate_barrel_set.glb`** — ✅ in the game as `wooden_crate.glb` + `wooden_barrel.glb`
> one wooden crate and one wooden barrel with metal bands standing side by side

## Fishing (Phase 2) — the game picks these up automatically by file name

Each fish shows a catch card, and is held up in 3D when its model exists (all but the Moonfin Koi have one).

**`fishing rod.glb`** — ✅ in the game (handle at the bottom, reel on one side)
> wooden bamboo fishing rod standing straight upright, cork handle at the bottom, small brass reel near the handle, thin tapering rod with tiny metal line guides, slightly curved tip, no line, no hook

**`fishing_bobber.glb`** — ✅ in the game
> classic round fishing bobber float, top half red, bottom half white, short thin stick on top, glossy painted wood

**Fish** — side view, lying horizontal, head pointing one way, mouth closed, no water, no stand:

Already in the game: **Azure Manta** (`Azure_manta.glb`) and **Flying Fish** (`Exocoetidae.glb`).

**`fish_silver_minnow.glb`** — ✅ in the game as `minnow.glb`
> small slim silver minnow fish, shiny silver scales with a pale blue stripe along the side, big friendly eyes, small fins

**`fish_sunfish.glb`** — ✅ in the game as `sunfish.glb`
> round chubby golden-orange sunfish, warm yellow belly, tiny blue spots on the cheeks, rounded fins, friendly face

**`fish_moonfin_koi.glb`** — ✅ in the game: as `koi.glb`, used for Moonfin Koi catches
> elegant koi fish, pearl-white body with soft blue and silver patches, long flowing fins that glow faintly pale blue, magical gentle look

**`fish_sea_bream.glb`** — ✅ in the game as `sea_bream.glb`
> sturdy sea bream fish, rosy pink-silver body, slightly darker back, spiky dorsal fin, round eye

**`fish_blue_mackerel.glb`** — ✅ in the game as `blue_mackerel.glb`
> sleek blue mackerel fish, dark blue wavy stripes on a bright blue-green back, silver belly, forked tail

## Phase 3: General Store

The store is in the village square, using a copy of the cottage model with a sign.
A proper building would make the village read better:

**`general_store.glb`** — ✅ in the game: the village General Store
> cozy village general store, two storeys, cream plaster walls with timber frame, wide shop front window with goods on display, striped green-and-cream fabric awning over the door, wooden hanging shop sign with a blank board, crates of vegetables and a barrel beside the door, terracotta tile roof, single building, no ground base


## Phase 4: Farming

Already in the game: **farmhouse**, **small_barn**, **greenhouse**, **garden_shed**, **scarecrow**,
**compost_bin** and **wooden_watering** (used as the farm's water trough).

Crop models are wired in through `CropData.stage_models` (each crop's tiny first sprout stays a simple built-in look).
Crops: **no soil, no pot, no base**, one plant, upright:

**`watering_can.glb`** — ✅ in the game
> small old tin watering can, soft teal paint worn to silver at the edges, long spout with a round sprinkler rose, curved handle over the top, a few dents

**`crop_turnip_sprout.glb`** — ✅ in the game as `turnip_seedling.glb`
> tiny turnip seedling, two small round bright-green leaves on short stems

**`crop_turnip_ready.glb`** — ✅ in the game as `turnip.glb`
> ripe turnip plant, round white turnip root with a purple top half poking out, bunch of leafy green turnip greens on top

**`crop_carrot_ready.glb`** — ✅ in the game as `crop_carrot.glb`
> ripe carrot plant, orange carrot shoulder just visible, tall feathery bright-green carrot fronds

**`crop_sunflower_ready.glb`** — ✅ in the game as `sunflower.glb`
> tall sunflower plant, sturdy green stem with big heart-shaped leaves, one large flower head with golden-yellow petals and a brown seed centre, facing slightly upward

### Still drawn in code (new models welcome)

Added with seasons, the ukulele and the greenhouse. Same rules: one object, upright, no base.

**`crop_tomato_ready.glb`** — ✅ in the game: ripe tomato beds
> bushy tomato plant tied to a short wooden stake, deep green leaves, several clusters of round shiny red tomatoes and a couple of green ones

**`crop_pumpkin_ready.glb`** — ✅ in the game: ripe pumpkin beds
> one big round orange pumpkin with deep ribs and a curly green stem, a few broad green pumpkin leaves and a curling vine around it

**`crop_kale_ready.glb`** — ✅ in the game: as `crop_kale.glb`, ripe kale beds
> leafy kale plant, tall frilly curly leaves in blue-green with purple veins, a little frost on the leaf tips

**`crop_sprout.glb`** — ✅ in the game: early tomato, pumpkin and kale growth stages
> tiny generic vegetable seedling, three small bright-green leaves on a short stem

**`ukulele.glb`** — ✅ in the game: the cottage pickup and the instrument the player holds
> small old wooden ukulele, warm honey-brown body with a darker edge binding, round sound hole with a little painted flower around it, four strings, short neck with wooden tuning pegs, a faded ribbon tied to the headstock

**`seed_sack.glb`** — ✅ in the game: supplies beside the thresher
> small burlap sack tied at the top with string, slightly slumped, a painted leaf symbol on the front

**`seed_tray.glb`** — ✅ in the game: the greenhouse’s daily seed trays
> shallow wooden seed tray with rows of tiny green seedlings in dark soil

**`message_bottle.glb`** — ✅ in the game: the beach journal bottle
> old green glass bottle lying on its side, cork stopper, a rolled paper letter tied with twine visible inside, a little sand and a tiny shell stuck to it

## Phase 5: Restoration

Run-down buildings use a grime overlay plus loose planks and weeds until a matching
"ruined" model exists. Same building, same size and footprint, same facing, so it swaps cleanly:

**`greenhouse_ruined.glb`** — ✅ in the game: the greenhouse before repair
> run-down old wooden greenhouse, same shape as a small gabled garden greenhouse with a water barrel at one side, several glass panes cracked or missing, grimy glass, peeling paint, a loose hanging door, ivy and weeds creeping up the frame, broken terracotta pots, single building, no ground base

## Later (Phase 6: NPCs)

**`npc_oliver.glb`** — ✅ in the game as `Oliver_character.glb`
> friendly elderly fisherman, white beard, knitted navy fisherman's sweater, yellow rain hat, rolled trousers, rubber boots, A-pose, full body, same proportions as the player character

**`npc_mia.glb`** — ✅ in the game as `Mia_character.glb`
> cheerful young farmer woman, auburn braid, wide straw hat with a ribbon, green overalls over a white shirt, gardening gloves, A-pose, full body, same proportions as the player character

Use Auto-Rig for both.

## Story batches (from the art-assets plan)

The full list, status and order live in [features/art-assets/design.md](features/art-assets/design.md).
Generate one batch at a time, in order. Add the **style line** to every prompt. Save each model under the exact file name.
**Characters** (Emma, Captain Marlow, Pip, Theo…): use the prompts in [features/villagers/design.md](features/villagers/design.md#model-prompts-tripo-same-proportions-and-a-pose-as-the-player-then-auto-rig), A-pose, full body, then **Auto-Rig**.
**Ruined + restored pairs:** generate the restored one first, then the ruined one with "same building, same shape and size" added, so the footprints match.

### Batch 1: opening scene
**`mail_boat.glb`** — ✅ in the game
> small old island mail boat, wooden hull painted navy with a cream stripe, little wheelhouse with round windows, short chimney, a mast with a furled sail, rope coils and a few parcels and mail sacks on the deck, a brass bell, room for three people on deck

**`npc_captain_marlow.glb`**, **`npc_emma.glb`** — ✅ both in the game: see the villagers doc.

**`grandpa_letter.glb`** — ✅ in the game: on Grandpa’s writing desk
> folded old paper letter in a cream envelope with a red wax seal stamped with a little lighthouse, slightly worn edges

**`travel_suitcase.glb`** — ✅ in the game as `suitcase.glb`
> old brown leather travel suitcase with brass corners and clasps, a leather handle, faded travel stickers, standing upright

**`seagull.glb`** — ✅ in the game
> cute stylized seagull gliding, wings spread wide, white body, grey wings with black tips, yellow beak

**`jetty_bollard.glb`** — ✅ in the game as `mooring-post.glb`
> short thick wooden mooring post with rope wrapped around the top, weathered grey wood

**`welcome_sign.glb`** — ✅ in the game
> wooden welcome sign on two posts with one wide blank board, painted seashells in the corners, slightly weathered

**`driftwood.glb`** — ✅ in the game
> twisted pale driftwood log, smooth sun-bleached wood, lying flat

**`general_store.glb`** — ✅ in the game: the village General Store

### Batch 2: prologue
**`cottage_key.glb`** — ✅ in the game as `key.glb`
> large old iron key with an ornate round bow shaped like a leaf, on a small loop of string

**`grandpa_journal.glb`** — ✅ in the game as `journal.glb`
> thick old leather-bound journal, brown cover with a stitched compass rose, a leather strap and brass buckle, loose papers peeking out

**`journal_page.glb`** — ✅ in the game
> single folded page of old handwritten paper, slightly curled, a small doodle of a lighthouse in the corner

**`notice_board.glb`** — ✅ in the game
> village notice board, wooden frame with a small shingle roof, cork board with a few pinned blank paper notes, two posts

**`village_house_ruined.glb`** — ✅ in the game as `ruined_village_house.glb`
> small abandoned two-storey village house, cream stone walls, terracotta roof with missing tiles and a tarp, windows boarded with planks, ivy climbing the walls, a crooked door, weeds by the step

**`market_stall_ruined.glb`** — ✅ in the game as `collapsed_market_stall.glb`
> collapsed wooden market stall, torn faded striped awning hanging down, broken counter planks, an empty tipped crate (same shape and size as a market stall)

**`village_inn_ruined.glb`** — ✅ in the game
> shuttered old village inn, two storeys, timber frame, closed wooden shutters, faded hanging sign with a blank board, moss on the roof, an empty bench by the door (same building as the village inn, same shape and size)

**`mailbox.glb`** — ✅ in the game
> cozy wooden post mailbox with a curved red roof, a little flag on the side, on one post

**`firewood_stack.glb`** — ✅ in the game
> neat stack of split firewood logs with a small sloped plank roof

**`fish_crate.glb`** — ✅ in the game
> wooden fish crate filled with ice and three stylized fish

### Batch 3: cottage interior
**`bed.glb`** — ✅ in the game
> cozy single wooden bed, patchwork quilt in warm colours, two fluffy pillows, carved headboard

**`writing_desk.glb`** — ✅ in the game
> old wooden writing desk with drawers, an oil lamp, an ink pot with a quill and a few stacked papers on top

**`wooden_chair.glb`** — ✅ in the game
> simple rustic wooden chair with a woven seat

**`bookshelf.glb`** — ✅ in the game
> tall wooden bookshelf full of old books, a few shells and a ship in a bottle on the shelves

**`wood_stove.glb`** — ✅ in the game as `stove.glb`
> small cast-iron wood stove with a kettle on top and a chimney pipe, painted dark green

**`round_rug.glb`** — ✅ in the game as `braided_rug.glb`
> round braided rug in warm red, cream and blue rings, flat

**`oil_lamp.glb`** — ✅ in the game as `oil-lamp.glb`
> brass oil lamp with a glass chimney and a little flame

**`storage_trunk.glb`** — ✅ in the game as `chest.glb`
> old wooden storage trunk with iron bands and a domed lid

**`potted_plant.glb`** — ✅ in the game
> leafy green plant in a terracotta pot

**`produce_basket.glb`** — ✅ in the game as `basekt_of_vegetables.glb`
> woven wicker basket full of colourful vegetables, carrots, turnips and apples

### Batch 4: chapter 1 (Sunflower Fields)
**`windmill.glb`** — ✅ in the game
> charming farm windmill, round stone tower with a cream-painted top, wooden cap with a shingle roof, four large wooden sails with fabric, a small door and a window

**`windmill_ruined.glb`** — ✅ in the game as `ruined_windmill.glb`
> same windmill, same shape and size, broken sails with torn fabric, missing roof shingles, door hanging open, overgrown with vines

**`bramble_hedge.glb`** — ✅ in the game as `bramble_bush.glb`
> wide thick tangle of wild bramble bushes and thorny vines with a few white flowers, wide and low, blocking a path

**`glowstone_shard.glb`** — ✅ in the game as `crystal_shard.glb`
> jagged shard of glowing crystal, soft blue-white glow, smooth facets, small

**`beehive.glb`** — ✅ in the game
> traditional wooden beehive box on short legs, painted pale yellow, a slanted lid, a few cartoon bees

**`sunflower.glb`** — ✅ in the game
> single tall sunflower, big golden flower head, green leaves

**`hay_bale.glb`** — ✅ in the game as `bale.glb`
> round golden hay bale

**`wheelbarrow.glb`** — ✅ in the game
> old wooden wheelbarrow with one wheel, a few tools leaning inside

**`npc_pip.glb`** — ✅ in the game: see the villagers doc.

**`fish_moonfin_koi.glb`** — ✅ in the game: as `koi.glb`, used for Moonfin Koi catches

### Batch 5: chapter 2 (Fernwood Forest)
**`stone_arch_bridge_ruined.glb`** — ✅ in the game as `bridge.glb`
> same mossy stone arch bridge, same shape and size, the middle of the arch collapsed into the stream, loose stones, broken wooden railing

**`carpenter_workshop.glb`** — ✅ in the game as `carpenter's_workshop.glb`
> cozy log-cabin carpenter's workshop, moss on the shingle roof, wide open barn doors, a workbench with tools visible inside, stacked planks and a sawhorse outside, a stone chimney

**`carpenter_workshop_ruined.glb`** — ✅ in the game as `ruined_carperter's_workshop.glb`
> same log-cabin workshop, same shape and size, dusty, doors closed and crooked, moss and fallen branches on the roof, no tools outside

**`ancient_tree_bare.glb`** — ✅ in the game as `ancient_oak.glb`
> huge ancient oak tree with a massive twisted trunk and wide roots, bare leafless branches, a hollow in the trunk, very old and grand

**`ancient_tree_leafy.glb`** — ✅ in the game as `ancient_oak.glb`
> same huge ancient oak tree, same trunk and shape, now in full lush green leaf with a few glowing blossoms

**`npc_theo.glb`** — ✅ in the game: see the villagers doc.

**`boathouse_ruined.glb`** — ✅ in the game as `ruined_lakeside_boathouse.glb`
> same lakeside boathouse, same shape and size, sagging roof, missing planks, cracked door, reeds growing through the deck

**`branch_pile.glb`** — ✅ in the game as `branch-pile.glb`
> small pile of fallen branches and sticks on the ground

**`stone_node.glb`** — ✅ in the game as `boulder.glb`
> chunky grey boulder with cracks and a few loose stones around it

**`fallen_log.glb`** — ✅ in the game as `mossy_fallen_log.glb`
> long mossy fallen tree log with a few mushrooms growing on it

---

## Realistic farming, slice 1: woodcutting and the blacksmith
The game uses simple built-in shapes for these until the models exist.

**`axe.glb`** — ✅ in the game: on Bram’s tool rack (held tool still uses the existing animated placeholder)
> woodcutter's axe, single iron head with a bright sharpened edge, long slightly curved ash-wood handle with a leather grip wrap, lying flat, real-world proportions

**`steel_axe.glb`** — ✅ in the game: on Bram’s tool rack (held tool still uses the existing animated placeholder)
> fine felling axe, polished steel head with a gently flared blade and a small brass maker's stamp, dark oiled hardwood handle, lying flat

**`blacksmith_forge.glb`** — ⬜ not made yet (the forge is built from simple blocks for now)
> village blacksmith's open-fronted forge, stone back wall and stone hearth with glowing coals and a brick chimney, timber posts holding a sloping tiled roof, tools hanging on the back wall, a water barrel at the side, open to the front

**`anvil.glb`** — ✅ in the game: Bram’s working forge counter
> blacksmith's iron anvil with a pointed horn, sitting on a thick tree-stump base, a hammer resting on top

**`npc_bram.glb`** — ✅ in the game: Bram, with his own retargeted animation library
> burly friendly village blacksmith, broad shoulders, short dark beard, rolled-up sleeves, thick leather apron over a grey linen shirt, soot on his forearms, sturdy boots, T-pose, full body
> Then put him through Mixamo like the other villagers (see the villagers doc) and tell Claude.

**`log.glb`** — ✅ in the game: spare timber beside the forge (felled logs retain their existing visuals)
> single cut log about one metre long, rough brown bark, pale wood rings showing on both cut ends, lying on its side

## Realistic farming, slice 2: rice
The paddy, rice plants, thresher and huller are built in code until these exist.

**`sickle.glb`** — ✅ in the game: on Bram’s tool rack
> rice harvesting sickle, thin crescent-shaped steel blade with a finely serrated inner edge, short round wooden handle, lying flat

**`rice_sheaf.glb`** — ✅ in the game: beside the thresher
> bundle of freshly cut golden rice stalks tied around the middle with a twist of straw, drooping grain heads at one end, lying on its side

**`pedal_thresher.glb`** — ✅ in the game: assembled from the four component models in `threshing_shed/`; drum retains its working animation
> old wooden pedal-powered rice threshing machine, a wide drum studded with wire loops under a curved hood, red painted wooden side panels, a foot treadle at the front, a catching tray below

**`rice_huller.glb`** — ✅ in the game: as `rice_huller/tripo_convert_c5ded7be-a1b0-4753-af6e-3e3a8026b04b.glb`, at the processing shed
> small hand-cranked wooden rice huller, a square hopper on top, a big iron crank wheel on one side, a chute at the front pouring into a sack, standing on four legs

**`threshing_shed.glb`** — ✅ in the game: the farm processing shelter
> open-sided farm shed, four rough timber posts, a thick golden thatched roof, packed-earth floor, open on all sides

**`hand_pump_well.glb`** — ✅ in the game: as `hand_pump.glb`, at the rice paddy
> old cast-iron farm hand pump painted green, on a low round stone well, with a short wooden water trough leading away from the spout

## Realistic farming, slice 3: wheat on Amber Plains
Wheat plants, the hoe, the scythe and the millstone are built in code until these exist.

**`hoe.glb`** — ✅ in the game: on Bram’s tool rack
> farm hoe, a broad flat steel blade set at a right angle to a long straight ash handle, lying flat

**`scythe.glb`** — ✅ in the game: as `scyth.glb`, on Bram’s tool rack
> traditional farm scythe, long gently curved steel blade, long wooden snath (handle) with two small hand grips, lying flat

**`wheat_sheaf.glb`** — ✅ in the game: beside the thresher
> bundle of cut golden wheat stalks tied round the middle with a twist of straw, plump bearded ears at one end, standing upright

**`flour_sack.glb`** — ✅ in the game: at the restored windmill
> plump cloth sack of flour tied at the top with string, a faint wheat-ear stamp on the front, a dusting of flour on the cloth

**`millstone.glb`** — ✅ in the game: at the restored windmill
> round grey stone millstone with a square hole in the centre and grooves cut across its face, leaning on its edge

## Realistic farming, slice 4: Grandpa's tractor and implements
The tractor and its implements are built in code until these exist. Models for vehicles need the
wheels as separate parts; if Tripo gives one solid mesh, Claude can still use it with spinning
wheels drawn in code.

**`tractor.glb`** — ✅ in the game: Grandpa’s drivable tractor; single mesh wheels are static
> small vintage farm tractor from the 1950s, faded red paint, big ridged rear wheels and small front wheels, cream wheel hubs, rounded engine hood with a front grille, single tall exhaust pipe, open driver's seat with a little backrest, steering wheel, rear mudguards, no cab, side view friendly proportions

**`tractor_rusty.glb`** — ⬜ not made yet
> the same small vintage farm tractor, rusted and weathered, flaking red paint, one flat front tyre, weeds growing round the wheels, cracked seat

**`plough_implement.glb`** — ✅ in the game: as `tractor_plough.glb`, the tractor’s plough
> three-furrow tractor plough, sturdy grey steel frame with a towing drawbar, three curved polished mouldboard shares

**`seed_drill.glb`** — ✅ in the game: the tractor’s seed drill
> small tractor-towed seed drill, long green seed hopper box with a hinged lid, a row of small steel discs underneath, two little rubber wheels at the ends

**`harvester_header.glb`** — ✅ in the game: the tractor’s harvester attachment
> front-mounted grain harvester header for a small tractor, wide yellow cutting platform with a row of pointed guards, a red slatted reel turning above it

