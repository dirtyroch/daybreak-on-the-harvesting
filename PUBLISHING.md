# Publishing Daybreak on the Harvesting (no coding needed)

This guide takes you from "I have a file" to "my game is live on Roblox". Plan on about an hour the first time.

> **Before you publish, decide on the title.** "Daybreak on the Harvesting" is a synonym swap of a well-known film title and could get a takedown. To rename, edit `src/shared/Names.luau` (the name-swap kit), run `./scripts/build.sh`, and publish the new `.rbxlx`. Nothing else needs to change.

---

## 1. Install Roblox Studio

1. Go to **https://create.roblox.com** and sign in.
2. Click **Start Creating** and download **Roblox Studio** (Windows or Mac).
3. Open Studio and sign in.

## 2. Open the game file

1. Download **`DaybreakOnTheHarvesting.rbxlx`** from the GitHub repo (click the file, then **Download raw file**).
2. In Studio choose **File > Open from File...** and pick it.
3. You'll spawn in the lobby plaza. Step on the gold pad or press **Enter the Harvesting**.
4. Press **Play** (▶). With just you, Stand-In bots fill the match to 48 after 25 seconds.

**Studio test mode notes:**
- Saving needs step 5. Until then a note says progress is not saved. That's normal.
- Shop items with ID 0 show a **"Studio test (free)"** button so you can try everything.
- Test with friends: **Test** tab, set **Clients** to 2-4, press **Start**. Use **👥 Partner** to queue together.

## 3. Publish it

1. **File > Publish to Roblox > Create new experience**.
2. Name: your final title.
3. Description idea: *"48 contenders. 24 Reaches. One champion at daybreak. Meet your mentor Rusty, launch from the Sundial, loot the Gilded Meadow, outrun the Veil, and if you get tapped out, watch from the Gallery and send gifts. Next match in 10 seconds! 🌅"*
4. Genre: **Fighting** (or Adventure). Devices: Computer, Phone, Tablet, Console.
5. Click **Create**.

## 4. Max players and privacy

1. **Game Settings > Places > (start place) > Max Players: 50** (48 contenders + room for spectators).
2. Privacy starts **Private**. Finish step 7 first, then set it to **Public** on the dashboard.

## 5. Turn on saving (API services)

**Home > Game Settings > Security > Enable Studio Access to API Services**, then **Save**. (The live game saves either way.)

## 6. Create the shop items (passes and products)

Every ID lives in **`src/shared/Monetization.luau`** (in Studio: **ReplicatedStorage > Shared > Monetization**). Anything left at **0** is hidden in the live game, so you can launch with none.

On the dashboard: your game > **Monetization > Passes > Create a Pass** for each pass, and **Monetization > Developer Products** for each product. Paste each new ID over its 0, save, rebuild and publish.

| Kind | Key | Name | Price (R$) | What it does |
|---|---|---|---|---|
| Pass | PremiumLane | Season Track Premium Lane | 399 | Premium cosmetic lane. All rewards shown first. No tiers or Stars sold. |
| Pass | GalleryBox | Gallery Box Seat | 149 | Box seat + gold name in the gift feed. Cosmetic. |
| Pass | BigSponsor | Big Sponsor | 249 | Earn Favor 2× faster while spectating. Favor is never sold. |
| Pass | StarterSatchel | Starter Satchel | 199 | Apple + canteen at the start of casual Jubilees. Free at Season Track tier 12. |
| Pass | TrailBoots | Trail Boots | 299 | +5% stamina regen in casual Jubilees + footprint trail. Free at tier 24. |
| Pass | TrainingRetry | Extra Training Try | 99 | One more try at the pregame target score. Cosmetic score only. |
| Product | RenownBoost | Renown Boost | 49 | +50% Renown 30 min; everyone else in the server gets a 5-min Renown Shower. |
| Product | FadeEmber / FadeVeil | Knockout fades | 75 | Cosmetic knockout dissolve. |
| Product | ParadeSunrise / ParadeEmber | Parade outfits | 120 | Cosmetic. |
| Product | BowGilded / SpearAshen / PackLantern | Skins | 80-90 | Same stats, new look. |

## 7. Maturity & Compliance questionnaire (prefilled answers)

Dashboard > your game > **Publish settings > Content rating** (older: **Audience > Maturity & Compliance**). Answer every page based on the most intense thing a player can see. Honest answers for this build:

| Category | Question | Answer | Why |
|---|---|---|---|
| Violence | Depicts violence? | **Yes** | Players hit each other with a bow, knife, spear and shoves. |
| Violence | How intense? | **Mild** | Non-graphic combat between human-proportioned characters (v2 realism pass). A knocked-out contender dissolves in light ("tapped out") and goes to the Gallery. No death animations, no bodies, no blood, no weapons aimed at the camera. The more realistic look can push a rating up, so check the preview result (see below). |
| Violence | How frequent? | **Repeated** | Combat is the core of a battle royale. |
| Blood | Any blood? | **No** | None. Hits show a white flash. |
| Fear | Scary elements? | **No** | Hazards are finches, pollen blooms and a glowing Veil wall. The dawn haze is moody, not scary. No jump scares. |
| Crude humor | Crude humor? | **No** | Rusty's lines and quips are clean. |
| Gambling | Unplayable gambling content? | **No** | Hazard and Encore votes are free ballots, not bets. |
| Strong language | Strong language? | **No** | All text is pre-written. |
| Romantic themes | Romance or adult settings? | **No** | Reach partners are teammates. No romance storyline. |
| Alcohol | Alcohol? | **No** | Rusty drinks sweet tea. |
| Social hangout | Primary theme is a social hangout? | **No** | It's a competitive match game. |
| Free-form creation | Free-form user creation? | **No** | Interview answers are preset quips; pacts are Offer / Accept / Snap buttons with no chat; sponsor letters are pre-written; Gallery gifts carry no player-written text. |
| Sensitive issues | Primary theme a sensitive issue? | **No** | The "Draw" is a lighthearted festival lottery for an arena game. Contenders volunteer through the queue. |
| Paid random items | Paid random items? | **No** | Nothing sold has a chance roll. Crates are free and found in the arena. |
| Paid item trading | Trade paid items? | **No** | No trading. |
| Media | Share media from gameplay? | **No** | |
| AI interaction | Users interact with generative AI? | **No** | All NPC lines are pre-written. |

**Expected result:** **Mild** (mild violence). If the preview shows higher, retake it. Retake it whenever you add content.

> The theme (a ceremony that picks young contenders for an arena fight) may read as close to a franchise. Keep everything in the game's own world, and keep the knockouts light and non-lethal.

## 7b. Avatar settings (realistic proportions)

The place file already sets **StarterPlayer > Avatar = R15** and **Collision = Inner Box**. The scale ranges can only be set on the website or in Studio's Game Settings, so set them once:

**Home > Game Settings > Avatar** (or dashboard > **Avatar settings**):

| Setting | Value | Why |
|---|---|---|
| Avatar Type | **R15** | Real joints and layered clothing. |
| Animation | **Player choice** | Keeps players' own animation packs. |
| Body Type scale | **60% to 100%** | Leans toward Rthro / realistic bodies. |
| Proportions scale | **0% to 50%** | Keeps bodies from going stick-thin. |
| Head scale | **95% to 100%** | No oversized heads. |
| Height / Width | **Default ranges** | Players keep their own height and build. |
| Layered clothing | **On** | Needed for the NPC and Stand-In outfits. |

The game also nudges each player's scales into these ranges when they spawn (`Look.playerScales`, turn off with `Look.nudgeAvatars = false`). Players' faces, hair and clothes stay their own.

## 8. Icon and thumbnails (ready-made files in `marketing/`)

| File | Use | Notes |
|---|---|---|
| `marketing/icon-512.png` | Game icon (512×512) | Rusty and the Herald on the Draw stage under the Sundial crest, with the title. |
| `marketing/thumbnail-1-launch.png` | Thumbnail 1 (1920×1080) | "48 contenders · one Sundial · last one standing" with all 48 lift plates. |
| `marketing/thumbnail-2-meadow.png` | Thumbnail 2 (1920×1080) | "NEXT MATCH IN 10s" over the Gilded Meadow. |

Upload them under **Configure > Thumbnails** and **Basic Info > Icon**. These come from a preview renderer; swap in real Studio screenshots once you can (hide the UI via **PlayerGui > Daybreak > Enabled = off**, then **View > Screenshot**). If you rename the game, re-letter the icon and thumbnail 1.

## 9. Make the characters look truly realistic (asset swap-in)

**Be clear on what's real today.** The game ships with the best realistic look we can build from parts: human proportions (about 7.5 heads tall, real faces with brows and expressions, coats with lapels, boots), Future lighting, dawn haze, a desaturated film grade, rusted metal, weathered wood, worn stone, grass clumps and mist. **That is still parts, not skin.** Real skin, cloth folds, wrinkles, hair strands and moving facial expressions only arrive when you add real mesh assets in Studio. We can't upload meshes from the build box. The slots are ready, and nothing breaks while an ID is still 0.

Every slot lives in **`src/shared/Look.luau`** (in Studio: **ReplicatedStorage > Shared > Look**). Get IDs from the **Creator Store / Marketplace** (Toolbox in Studio, or create.roblox.com/store). The number in the item's URL is its ID. Paste it over the 0, save, rebuild, publish.

### 9a. The three NPCs (each becomes a real R15 rig with a Dynamic Head)

As soon as an NPC's `body` IDs are filled in, `LookService` replaces the part-built stand-in with a real R15 rig made from a HumanoidDescription. The rig gets your body parts, a Dynamic Head (its FACS expression is set from `expression`), layered clothing, hair, accessories and an idle animation.

| NPC | `Look.NPCS` key | Body bundle (6 parts) | Dynamic Head | Layered clothing | Hair / accessories | FACS expression (already set) |
|---|---|---|---|---|---|---|
| Rusty Dunmore (mentor, 40s) | `Rusty` | A realistic male body bundle (search "realistic man", "Rthro male") | A rugged 40s man with stubble ("realistic head stubble") | Faded mustard tee (TShirt), open teal/brown **plaid flannel** (Jacket), worn work jeans (Pants), scuffed **work boots** (Shoes) | Messy grown-out dirty-blond hair with dark roots; a green thermos (accessory) | Wry half-smile, one brow up |
| Herald Marigold Vane (escort) | `Herald` | A slim realistic female body bundle | A poised woman, warm complexion | Cream blouse (Shirt), **ochre tailored long coat** (Jacket), slim trousers (Pants), heeled boots (Shoes) | Copper hair in a tight **bun**; pearl necklace | Bright, practiced smile |
| Monty Gleam (interview host) | `Monty` | A lean realistic male body bundle | A 50s man, silver-streaked | White dress shirt (Shirt), **midnight suit jacket** (Jacket), suit trousers (Pants), black dress shoes (Shoes) | Slicked-back grey hair; burgundy tie, gold pocket square | Big TV smile, cheeks raised |

Tips: pick bundles and heads labelled **"Dynamic Head"** (they include FaceControls). Avoid anything labelled R6, "blocky" or chibi. Free items work fine.

### 9b. Stand-In bots (`Look.STAND_IN`)

Bots are always real R15 rigs (they walk and animate). With no IDs they wear the realistic part-built body welded to their limbs. To make them fully realistic, add lists of IDs; each bot picks one at random:

| Pool | What to add (5 to 10 each) |
|---|---|
| `bodies` | Realistic body bundles (6 part IDs each), mixed builds and genders |
| `dynamicHeads` | Plain realistic Dynamic Heads, varied ages and skin tones |
| `hair` | Short, messy, long, bun, shaved |
| `tops` | Muted work jackets, hoodies, flannels (layered) |
| `bottoms` | Worn jeans, cargo pants (layered) |
| `shoes` | Boots and sneakers (layered) |

### 9c. Materials (`Look.MATERIALS`, PBR MaterialVariants)

The place already uses the 2022 materials with rusted metal, weathered planks, limestone, cobbles, leafy grass and mud. For a film look, add PBR texture sets (color, normal, roughness, metalness). Search the Creator Store for "PBR" + the name, or use **Material Generator** in Studio (it creates the variant for you; then copy its texture IDs here). A variant only turns on once its `colorMap` is set.

| Variant | Base material | Look for | Studs per tile |
|---|---|---|---|
| `WeatheredWood` | WoodPlanks | Grey, sun-bleached planks with cracks | 8 |
| `RustedMetal` | CorrodedMetal | Flaking orange rust over dark steel | 6 |
| `WornStone` | Limestone | Pitted pale stone with grime in cracks | 10 |
| `OldCobbles` | Cobblestone | Rounded, mossy cobbles | 10 |
| `MeadowGrass` | LeafyGrass | Olive, sun-dried grass | 12 |
| `TrailDirt` | Mud | Dry packed dirt with pebbles | 12 |

### 9d. Vegetation and terrain

- **Terrain grass:** on by default (`Look.terrainGrass`). At server start the arena ground tiles become Terrain grass with animated grass blades (Terrain > Decoration). Colors come from `Look.TERRAIN`.
- **Real foliage meshes** (`Look.VEGETATION`: `grassClump`, `fern`, `bush`, `pine`, `oak`, `reeds`): the slots are reserved, but swapping them in automatically is **not wired yet**. For now, drop realistic tree and bush meshes into **Workspace > Map** by hand in Studio (search "realistic tree mesh LOD"), or ask for the auto-swap in the next pass. Until then, trees, bushes and grass clumps are built from parts.

### 9e. What's already set in the place (no action needed)

Lighting **Technology = Future**, **Atmosphere** (density 0.42, dawn haze 2.2), a **film grade** (ColorCorrection: saturation −0.28, contrast +0.14), Bloom, SunRays, **depth of field during cutscenes only**, dust motes in the light, mist on the lake and haze over the meadow.

## 10. After launch

- Watch **Day 1 retention**, **Average session time** and **matches per session** in Analytics.
- Weekly rules rotate by themselves (Gallery Week, Token Hunt, Double Encore, Starfall).
- Every update: edit, `./scripts/build.sh`, **File > Publish to Roblox**.
