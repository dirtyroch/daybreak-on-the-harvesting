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
| Violence | How intense? | **Mild** | Blocky cartoon combat. A knocked-out contender dissolves in light ("tapped out") and goes to the Gallery. No death animations, no bodies, no weapons aimed at the camera. |
| Violence | How frequent? | **Repeated** | Combat is the core of a battle royale. |
| Blood | Any blood? | **No** | None. Hits show a white flash. |
| Fear | Scary elements? | **No** | Hazards are candy-colored finches, pollen blooms and a glowing Veil wall. No jump scares. |
| Crude humor | Crude humor? | **No** | Rusty's lines and quips are clean. |
| Gambling | Unplayable gambling content? | **No** | Hazard and Encore votes are free ballots, not bets. |
| Strong language | Strong language? | **No** | All text is pre-written. |
| Romantic themes | Romance or adult settings? | **No** | Reach partners are teammates. No romance storyline. |
| Alcohol | Alcohol? | **No** | Rusty drinks sweet tea. |
| Social hangout | Primary theme is a social hangout? | **No** | It's a competitive match game. |
| Free-form creation | Free-form user creation? | **No** | Interview answers are preset quips; Gallery gifts carry no player-written text. |
| Sensitive issues | Primary theme a sensitive issue? | **No** | The "Draw" is a lighthearted festival lottery for an arena game. Contenders volunteer through the queue. |
| Paid random items | Paid random items? | **No** | Nothing sold has a chance roll. Crates are free and found in the arena. |
| Paid item trading | Trade paid items? | **No** | No trading. |
| Media | Share media from gameplay? | **No** | |
| AI interaction | Users interact with generative AI? | **No** | All NPC lines are pre-written. |

**Expected result:** **Mild** (mild violence). If the preview shows higher, retake it. Retake it whenever you add content.

> The theme (a ceremony that picks young contenders for an arena fight) may read as close to a franchise. Keep everything in the game's own world, and keep the knockouts light and non-lethal.

## 8. Icon and thumbnails (ready-made files in `marketing/`)

| File | Use | Notes |
|---|---|---|
| `marketing/icon-512.png` | Game icon (512×512) | Rusty and the Herald on the Draw stage under the Sundial crest, with the title. |
| `marketing/thumbnail-1-launch.png` | Thumbnail 1 (1920×1080) | "48 contenders · one Sundial · last one standing" with all 48 lift plates. |
| `marketing/thumbnail-2-meadow.png` | Thumbnail 2 (1920×1080) | "NEXT MATCH IN 10s" over the Gilded Meadow. |

Upload them under **Configure > Thumbnails** and **Basic Info > Icon**. These come from a preview renderer; swap in real Studio screenshots once you can (hide the UI via **PlayerGui > Daybreak > Enabled = off**, then **View > Screenshot**). If you rename the game, re-letter the icon and thumbnail 1.

## 9. After launch

- Watch **Day 1 retention**, **Average session time** and **matches per session** in Analytics.
- Weekly rules rotate by themselves (Gallery Week, Token Hunt, Double Encore, Starfall).
- Every update: edit, `./scripts/build.sh`, **File > Publish to Roblox**.
