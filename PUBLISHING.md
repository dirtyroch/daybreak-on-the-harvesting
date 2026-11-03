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

You create **8 passes, 14 developer products and 1 subscription**. The Item Shop uses one developer product per price point (`Shop25` ... `Shop1999`): the player picks an item in the game, a confirm card names it and its price, and the Roblox prompt charges that price. If a receipt ever arrives without a matching choice (for example after a server restart), the player gets a Shop Voucher for that amount, so nothing paid is ever lost.

### 6a. Passes (Monetization > Passes)

| Key | Name | Suggested price (R$) | What it does |
|---|---|---|---|
| PremiumLane | Season Track Premium Lane | 399 | Premium cosmetic lane for the season. Every reward is shown before you buy. |
| VIP | Spire VIP | 499 | Gold nametag, +10% Renown in casual matches, twist and No Betrayals controls in private servers you own. No combat power. |
| GalleryBox | Gallery Box Seat | 149 | Box seat and gold name in the gift feed. Cosmetic. |
| BigSponsor | Big Sponsor | 249 | Earn Favor 2x faster while spectating. Favor is never sold. |
| PatronPicks | Patron Picks | 199 | Two extra Gallery cheers (firework flare, cheering banner), paid with earned Favor. Cosmetic. |
| StarterSatchel | Starter Satchel | 199 | Apple and canteen at the start of casual matches. Free at Season Track tier 12. |
| TrailBoots | Trail Boots | 299 | +5% stamina regen in casual matches until 10 are left, and a footprint trail. Free at tier 24. |
| TrainingRetry | Extra Training Try | 99 | One more try at the pregame target range. Cosmetic score. |

### 6b. Developer products (Monetization > Developer Products)

Name the Item Shop products exactly as below so the store page reads clearly.

| Key | Name | Price (R$) | What it does |
|---|---|---|---|
| RenownBoost | Renown Boost | 49 | +50% Renown for 30 min in casual matches; everyone else in the server gets a 5-min Renown Shower. |
| TierSkip | Season Tier Skip | 75 | One Season Track tier. Rewards are cosmetic. |
| TierSkip10 | Season Tier Skip x10 | 599 | Ten tiers. |
| Shop25, Shop49, Shop99, Shop149, Shop199, Shop299, Shop399, Shop499, Shop799, Shop1299, Shop1999, Shop4999 | Daybreak Shop item (R$ N) | 25 / 49 / 99 / 149 / 199 / 299 / 399 / 499 / 799 / 1,299 / 1,999 / 4,999 | Pays for the item or bundle picked on the in-game confirm card. |

### 6c. Patron Club subscription (Monetization > Subscriptions)

| Key | Name | Suggested price | Perks |
|---|---|---|---|
| PatronClub | Patron Club | R$ 299 a month (or the $4.99 tier if you price in local currency) | A Patron cloak each month kept forever, 2 Tier Skips a month, +15% Renown in casual matches, a wax-seal stamp on letters. |

Subscription IDs look like `EXP-...`; paste it into `Monetization.Subscriptions.PatronClub.id` (a string, `""` until then). Roblox only shows it to accounts where PolicyService says subscriptions are allowed.

### 6d. Item Shop catalog (no Creator Hub setup needed; priced in `src/shared/Store.luau`)

18 items rotate on a fixed 3-week cycle, 6 at a time, changing every Monday 00:00 UTC. The shop says "Back in the shop in N weeks", which is always true. Nothing is random and nothing leaves forever.

| Shelf | ID | Name | R$ | When on sale |
|---|---|---|---|---|
| Arms | `skin_bow_ashen` | Ashwood Bow | 99 | Always |
| Arms | `skin_bow_gilded` | Gilded Bow | 199 | Always |
| Arms | `skin_bow_mirror` | Mirrorwood Bow | 149 | Weekly rotation |
| Arms | `skin_bow_frost` | Frostline Bow | 299 | Weekly rotation |
| Arms | `skin_bow_regent` | Regent's Longbow | 499 | Weekly rotation |
| Arms | `skin_spear_ashen` | Ashen Spear | 99 | Always |
| Arms | `skin_spear_ember` | Ember Spear | 199 | Always |
| Arms | `skin_spear_lake` | Lakeglass Spear | 299 | Weekly rotation |
| Arms | `skin_knife_copper` | Copper Knife | 49 | Always |
| Arms | `skin_knife_night` | Nightglass Knife | 149 | Weekly rotation |
| Fades | `fade_ember` | Ember Light | 99 | Always |
| Fades | `fade_veil` | Veil Shimmer | 99 | Always |
| Fades | `fade_ash` | Ash and Embers | 149 | Weekly rotation |
| Fades | `fade_aurora` | Aurora Fade | 199 | Weekly rotation |
| Fades | `fade_starfall` | Starfall Fade | 299 | Weekly rotation |
| Poses | `pose_heart` | Hand on Heart | 49 | Always |
| Poses | `pose_bow` | Curtain Bow | 99 | Always |
| Poses | `pose_lantern` | Lantern Raise | 199 | Weekly rotation |
| Poses | `pose_crown` | Wheat Crown Toss | 299 | Weekly rotation |
| Poses | `pose_regent` | Regent's Stand | 499 | Weekly rotation |
| Emotes | `emote_tip` | Hat Tip | 25 | Always |
| Emotes | `emote_toast` | Thermos Toast | 49 | Always |
| Emotes | `emote_twirl` | Ribbon Twirl | 99 | Weekly rotation |
| Emotes | `emote_lantern` | Lantern Swing | 149 | Weekly rotation |
| Wraps | `wrap_gold` | Gold Ribbon Wrap | 49 | Always |
| Wraps | `wrap_lantern` | Paper Lantern Wrap | 99 | Always |
| Wraps | `wrap_meadow` | Meadow Bloom Wrap | 99 | Weekly rotation |
| Wraps | `wrap_star` | Starry Night Wrap | 149 | Weekly rotation |
| Nametags | `tag_ember` | Ember Nametag | 99 | Always |
| Nametags | `tag_lake` | Lake Nametag | 99 | Always |
| Nametags | `tag_aurora` | Aurora Nametag | 199 | Weekly rotation |
| Parade | `parade_sunrise` | Sunrise Parade Coat | 149 | Always |
| Parade | `parade_ember` | Ember Parade Cape | 149 | Always |
| Parade | `parade_regal` | Regal Parade Mantle | 399 | Weekly rotation |
| Rusty | `rusty_thermos` | Rusty's Brass Thermos | 99 | Always |
| Rusty | `rusty_stories` | Rusty: Old Stories | 149 | Always |
| Rusty | `rusty_coach` | Rusty: Coach Mode | 149 | Weekly rotation |
| Reach | `banner_pride_<reach>` | <Reach> Pride Banner (x24 Reaches) | 149 | Always |
| Reach | `sash_pride_<reach>` | <Reach> Parade Sash (x24) | 99 | Always |
| Reach | `tag_pride_<reach>` | <Reach> Nametag (x24) | 99 | Always |

Bundles (offered only while the pieces you don't own are worth more than the price):

| ID | Name | R$ | Worth | Contents |
|---|---|---|---|---|
| `starter` | Starter Pack | 99 | 222 | One per account: Ashwood Bow, Copper Knife, Gold Ribbon Wrap and the Hat Tip emote. |
| `ember_set` | Ember Set | 399 | 546 | Ember Spear, Ember Light fade, Ember Parade Cape and Ember Nametag. |
| `rusty_set` | Rusty's Corner | 299 | 446 | Brass Thermos, Old Stories, Coach Mode and the Thermos Toast emote. |
| `regent_set` | Regent Collection | 1299 | 1696 | Regent's Longbow, Regent's Stand, Starfall Fade and Regal Parade Mantle. |
| `arms_locker` | Complete Arms Locker | 1299 | 2040 | All 10 weapon skins in this season's shop. |
| `spire_collection` | Spire Collection | 1999 | 2708 | Every fade, pose, emote and gift wrap in this season's shop. |
| `pride_<reach>` | <Reach> Pride Bundle (x24) | 199 | 347 | Banner, sash and nametag for one Reach. |

### 6e. Other earnings to switch on

- **Private servers:** Creator Hub > your game > Monetization > Private Servers. Suggested R$ 99 a month. Spire VIP owners get twist and No Betrayals controls; private matches don't count for Reach standings.
- **Price optimization / regional pricing:** Monetization > Price Optimization. Turn it on after launch so Roblox tests prices for you.
- **Roblox Plus:** the Passes & Club tab has a calm "Roblox Plus" button (`MarketplaceService:PromptRobloxSubscriptionPurchase`). Check this call works in Studio first; if it errors, the button quietly does nothing.
- **Creator Rewards:** automatic. Roblox pays for Active Spenders who play and for new players you bring in through links.
- **Age checks:** DevEx pays more for spending from age-checked US adults. No setup is needed in the game.
- **Rewarded video ads:** not built. They need 2,000+ monthly visitors, a passed questionnaire and a 13+ ID-verified owner, and they can't be shown to under-13 players. Add them after launch if you want, as an optional "watch for a small Renown bonus", never as a progress gate.
- **Animations and voice lines:** poses and emotes now move with code-made keyframe clips (`src/shared/Anim.luau`), and Rusty "babbles" each line in a pitch per pack. Uploaded animations and recorded lines are optional upgrades: paste IDs into the `anim` slots in `Store.luau` and `sound` in `Content.RUSTY_VOICE` (see 6g).

### 6f. Season 1 weekly drops (set the start week at launch)

`Store.SEASON1_START_WEEK` is the Monday Season 1 starts (default: week 2967, Mon 16 Nov 2026 UTC). Weeks 1 to 3 rotate the launch items; weeks 4 to 9 each bring a named drop of three new items (Harvest Moon, Wheatsheaf, Comet Night, Lantern Festival, Gallery Gala, Regent's Return). If you launch later, set it to `Store.week(os.time())` on your launch Monday, otherwise the drops will appear early. The "Next week" row in the shop shows names only, never a countdown.

### 6g. Rusty voice packs (optional recordings)

Each Rusty pack plays a short babble from a stock Roblox sound, pitched per pack. To use real recordings, upload one audio per pack (Creator Hub > Audio), then set `sound = <id>` for that pack in `Content.RUSTY_VOICE`. Keep lines kind; the text is in `Content.RUSTY_PACKS`.

### 6h. Roblox Premium / Plus member perk

Members (`player.HasRobloxSubscription`, falling back to `MembershipType == Premium`) get one free cosmetic each month, cycling through `Store.MEMBER_MONTHLY`, granted when they join. It is never sold. Premium Payouts are retired; your Plus income now comes through Creator Rewards, which counts Active Spenders who play 10+ minutes. The Daily Ten bonus (+150 XP and 2 ★ for 10 minutes a day) is built around that. Check in Studio that `HasRobloxSubscription` reads without errors (it's wrapped in pcall).

### 6j. v5: Founders' Dawn, Season 2 and funnels

- **Founders' Dawn** runs 18–30 November (UTC) every year by itself (`src/shared/Logic/Events.luau`). During it the shop shows a festival shelf:

| ID | Name | R$ |
|---|---|---|
| `skin_bow_founders` | Founders' Bow | 199 |
| `pose_first_sunrise` | First Sunrise | 199 |
| `wrap_s_festival` | Festival Lantern Wrap | 99 |
| `parade_dawn_coat` | Dawn Festival Coat | 149 |
| `founders_set` (bundle) | Founders' Dawn Set (all four, R$ 646 of items) | 499 |

  Free festival rewards: Founders' Lantern banner (3 matches), Dawn Ribbon nametag (3 different days) and the Archive Reel fade (top 5 in an Archive Reel match).
- **Season 2 "High Harvest"** opens at season week 10 (`Store.SEASON2_WEEK`): four drops of three items in weeks 10–13, plus the **High Harvest Collection** (`high_harvest`, R$ 1,999 for 12 items worth R$ 2,488). No setup is needed; everything uses the shop vouchers.
- **Funnels:** the server logs the onboarding funnel (`LogOnboardingFunnelStepEvent`: joined, first match, the five checklist steps, second match, first shop open) and a `ShopFirstPurchase` funnel (`LogFunnelStepEvent`: shop open, item view, try on, prompt, purchase; only until the first purchase). See Creator Hub > Analytics > Funnels after launch.
- **Share moments** use `CaptureService:TakeScreenshotCaptureAsync` and `PromptShareCapture`, shown only when `PolicyService` says `IsContentSharingAllowed`. Test in the published game.
- **Family Rules** for private servers is free and on by default; the owner can switch it off in Party.

### 6i. Things to check in Studio before launch

- **Held weapons:** grips are set in `Arms.luau` (`grip()`); if a bow sits at an odd angle on your avatar type, change the angle there.
- **Poses and emotes:** they write `Motor6D.Transform` every frame in `AnimPlayer.luau`. If the default Animate script fights them on your own character, switch `RunService.Stepped` to `RunService.PreSimulation`.
- **Podium and Hall statues** use `Players:CreateHumanoidModelFromUserId`; without API access in Studio they fall back to stand-in models.
- **Hall of Champions DataStores:** `HallWins_<week>` (OrderedDataStore) and `HallLoadout` (DataStore). Turn on API services (step 5).
- **Invites:** `SocialService:PromptGameInvite` only works in a published game; the join's `LaunchData` "ref:<userId>" gives both players the Torchbearer Sash (capped at 20 a week).

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
| Paid random items | Paid random items? | **No** | Nothing sold has a chance roll. The Item Shop sells named items at named prices; the weekly rotation is a fixed schedule. Crates are free and found in the arena. |
| Paid item trading | Trade paid items? | **No** | No trading. Gifting buys a new copy for a friend; nothing moves between players. |
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
| `marketing/icon-512.png` | Game icon (512×512) | v5 realistic render: the Sundial at dawn with the serif title. |
| `marketing/thumbnail-1-launch.png` | Thumbnail 1 (1920×1080) | v5 realistic render: 48 lift plates around the Sundial, "48 contenders · one Sundial · last one standing". |
| `marketing/thumbnail-2-meadow.png` | Thumbnail 2 (1920×1080) | v5 realistic render: the Gilded Meadow in haze, "Quick Trials: 5-minute matches · squads of up to 10 · Family Rules in private servers". |

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
