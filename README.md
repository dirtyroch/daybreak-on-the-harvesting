# 🌅 Daybreak on the Harvesting

A Roblox battle royale for 48 contenders: 24 Reaches send two each, a mentor named Rusty walks you
through the Draw, and everyone launches from lift plates around the Sundial into a 2,400-stud arena
that the Veil slowly closes. Spectators in the Viewing Gallery send gifts, vote hazards and vote one
knocked-out contender back in.

> **Title warning.** "Daybreak on the Harvesting" is a word-for-word synonym swap of a well-known film
> title. It may draw a trademark or impersonation takedown. Every player-facing name lives in
> **`src/shared/Names.luau`** (the name-swap kit), so a rename is one file, one rebuild, one publish.

## What's in v2

| Area | Status |
|---|---|
| Lobby plaza, Draw stage, Rusty walk-up cutscene (skippable) | **Playable** |
| The Capital Parade (floats; your Reach rolls out first), interview with Monty Gleam (3 preset answers, no chat), training range with a score reveal. All short and skippable | **Playable** (new) |
| Queue with Stand-In bots to fill to 48, auto-requeue, "Next match in 10s" | **Playable** |
| Real 2,400-stud arena: Sundial hub + crates, Gilded Meadow, Mirror Lake, Whisperwood, Ashen Ridge, Old Glassford, open fields | **Playable** |
| Combat (bow, knife, shove; spear melee **and spear throw** that bounces off the Veil once), Pep health, snacks, loot crates, the Veil | **Playable** |
| **Pacts**: offer, accept or decline a pact with a nearby contender from another Reach; snap it for a 3-second betrayal warning, a "Betrayed by…" kill-cam and a Turncoat title. Pacts end at 4 left | **Playable** (new) |
| **Sponsor letters**: pre-written letters from your Reach's sponsors with small, earned gifts | **Playable** (new) |
| **Food and water meters** (low meters slow stamina regen only) | **Playable** (new) |
| **Veil Breaker finale**: at 4 left a core lights; hit it with a thrown spear to calm the Veil | **Playable** (new) |
| Reach partners (allies until 4 remain), partner queue | **Playable** |
| Viewing Gallery: Favor, parachute gifts, hazard ballots, Encore vote-back | **Playable** (podium reward bug fixed) |
| Kill-cam, near-miss stats card, results + Play again | **Playable** |
| Levels, prestige, challenges, streaks, Season Track, Reach standings, Jubilee Tokens, Rusty gifts, twists | **Playable** |
| Shop: passes/products with IDs at 0 (hidden live; free "Studio test" grant); **PolicyService check** hides paid items where they aren't allowed | **Playable in Studio** |
| **Stamina**: server-authoritative, with a speed check that rubber-bands speed hacks | **Playable** (moved to server) |
| **Realism pass**: human-proportioned NPCs and Stand-Ins (no blocky or chibi shapes), Future lighting, dawn Atmosphere, film grade, cutscene depth of field, rusted metal / weathered wood / worn stone / grass / dirt, grass clumps, dust motes, lake mist, muted palette | **Built** (part-built approximations; see below) |
| Real skin, cloth and moving faces (Dynamic Heads, layered clothing, body bundles) | **Needs Studio assets**: slots ready in `src/shared/Look.luau`, spec in PUBLISHING §9 |
| Cross-server matchmaking (`Config.Matchmaking.crossServer = false`) | **Stubbed**: one server runs lobby + arena |

**How realistic is it, honestly?** The part-built people have real proportions, faces, coats and boots, and the world is lit and graded like a film. Up close they're still made of smooth shapes. They only look truly realistic once real body bundles, Dynamic Heads and layered clothing IDs go into `Look.luau`; `LookService` then swaps in real R15 rigs automatically. Players' own avatars stay their own; only their scales are nudged toward realistic proportions.

v2 has not been play-tested in live Roblox Studio yet. Everything below passes on the command line.

## What's in v3: the Daybreak Shop

| Area | Status |
|---|---|
| Item Shop with a real weekly rotation (6 picks every Monday, fixed 3-week cycle, "Back in N weeks") | **Playable in Studio** |
| 109 cosmetic items: weapon skins (bow/spear/knife streak colors), knockout fades, podium poses, emotes (B), gift wraps, nametags, parade outfits, Rusty voice packs, 24 Reach Pride sets | **Playable in Studio** (poses/emotes/voice are text until animation and sound IDs are added) |
| Bundles that are only offered while still a real saving; one-time R$ 99 Starter Pack | **Playable in Studio** |
| Gifting to a friend in the server; Shop Vouchers so no payment is ever lost | **Playable in Studio** |
| Spire VIP, Patron Picks, Tier Skips, Patron Club subscription, private-server rules, Roblox Plus button | **Built**; subscription and Plus calls need a check in Studio |
| Locker and purchase history in Profile; a calm "new this week" dot | **Playable in Studio** |

Fair-play rules for v3 are in tests: nothing random, no pressure words, every paid perk casual-only, Trail Boots off at 10 left, bundles always a real saving, every ID ships as 0.

## What's in v4: weapons you can see, moves that move, and a season

| Area | Status |
|---|---|
| Held weapon meshes built from parts: every bow, spear and knife skin looks different in your hand, on statues and in try-on (tested: no two skins share a shape) | **Playable in Studio** |
| Real pose and emote animations (8 poses, 7 emotes, with props like a lantern, thermos and crown), played on every client | **Playable in Studio**; check joint timing (PUBLISHING 6i) |
| Rusty speaks: a voice babble per pack, with slots for real recordings | **Playable in Studio** |
| Weapon mastery (5 levels per skin, brighter tracers, ★ in the kill feed, ✦ on your nametag at max) | **Playable in Studio** |
| Victory Podium after every match (top 3 as statues, shown to the whole lobby) and a weekly Hall of Champions | **Built**; statues need API access to show real avatars |
| Knockout finishers by fade style (column, comet, lanterns, petals, sunburst) | **Playable in Studio** |
| Try before you buy: a private practice double for weapons, poses, emotes and fades | **Playable in Studio** |
| Calm offer cards: free First Light pose on your first win, one fade preview after a match with a knockout (max 2 shop cards a session, "No thanks" sticks), a Gallery "help your partner" gift card | **Playable in Studio** |
| Six named weekly drops (18 items) on a fixed schedule, a "Next week" row, and the R$ 4,999 First Light Grand Collection | **Playable in Studio** |
| Premium/Plus monthly member cosmetic, Daily Ten bonus, invite a friend (both get the Torchbearer Sash) | **Built**; Plus and invites need a published game |
| Season 2 "High Harvest" skeleton (track, 12 items, rules, twists) | Superseded in v5: the 12 items are now real shop drops |

Still fair: nothing random for Robux, no timers or pressure copy (tested), every card hidden when policy hides paid items, boosts casual-only.

## What's in v5: the first five minutes, family parties and Founders' Dawn

| Area | Status |
|---|---|
| **Quick Trials**: a 5-minute match (short Draw, no ceremony, faster Veil). New players get it for their first 2 matches, then the full Jubilee; pick Auto / Quick / Full in Settings. The queue follows the majority | **Playable in Studio** |
| **First-match checklist** from Rusty (open a crate, hold a weapon, eat, outrun the Veil, help from the Gallery), +120 Renown in total, softer Stand-Ins for your first 3 matches, hidden after 5 | **Playable in Studio** |
| **Parties of up to 10**: invite anyone in the server, the leader queues everyone, the queue never splits a party, and a party results card after every match | **Playable in Studio** |
| **Family Rules** (free, on by default in private servers): your party can't hurt each other until the final 4 | **Playable in Studio** |
| **Welcome back**: after 3+ days away, banked Favor, +50% Renown for 3 matches and double stars up to a weekly pace (never past where a weekly player would be) | **Playable in Studio** |
| **Founders' Dawn** festival, 18–30 Nov every year (launch week): three free rewards, an Archive Reel match every 3rd match (sepia grade, "Young Rusty" in the field, "the 25th Trials"), and a festival shelf with the R$ 499 Founders' Dawn Set (R$ 646 of items) | **Playable in Studio** |
| **Share this moment**: one card after a win, top 3, Veil Breaker, Encore or 5 knockouts opens Roblox's own share sheet with a screenshot (only when policy allows sharing). Friends who join from it count as invites | **Built**; CaptureService needs a published game |
| **Season 2 shelf**: 12 High Harvest items in four drops (season weeks 10–13) and the R$ 1,999 High Harvest Collection (R$ 2,488 of items) | **Playable in Studio** |
| **Bundles show the saving** plainly ("R$ X less as a set"); a bundle is only offered while it really saves | **Playable in Studio** |
| **Funnels**: onboarding and first-purchase steps logged to Roblox Analytics (server-side) | **Built**; data appears only in a published game |
| New realistic icon and thumbnails in `marketing/` | **Ready** |

Still fair: nothing random for Robux, no timers or pressure copy (tested), festival items return every year, boosts never in ranked matches or finals. The old raised-hand pose is now "Hand on Heart" and its Season emote is "Nod".

## Project layout

```
src/shared/Names.luau        name-swap kit (title, world, NPCs, currencies)
src/shared/Config.luau       tuning: match size, Veil, loot, XP, streaks, gallery
src/shared/Content.luau      challenges, season tiers, tokens, quips, Rusty gifts
src/shared/Monetization.luau every Robux ID (all 0) and fair-play rules
src/shared/MapBuilder.luau   builds lobby, arena and gallery (baked into the .rbxlx)
src/shared/Logic/*           pure, unit-tested game rules
src/server/Services/*        Data, Match, Bot, Gallery, Progress, Purchase
src/client/*                 HUD, panels, cutscene, results, gallery UI
tests/run.luau               Lune test runner
scripts/build.sh             rojo build + bake the map
ci/github-actions-ci.yml     CI workflow (copy to .github/workflows/ to enable)
marketing/                   icon + thumbnails rendered from the real map
```

## Build, lint and test

Tools are pinned in `rokit.toml` (rojo, selene, lune, luau-lsp).

```bash
rokit install
selene generate-roblox-std && selene src tests scripts
lune run tests/run
curl -sSL -o globalTypes.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src
./scripts/build.sh          # -> DaybreakOnTheHarvesting.rbxlx (map baked in)
```

Open `DaybreakOnTheHarvesting.rbxlx` in Studio, or `rojo serve` for live sync. See
[PUBLISHING.md](PUBLISHING.md) for the no-code publish steps.

## Why it's sticky (and still fair)

The loop: Draw ceremony (about 38 s, or 3 s when skipped) → 10 s launch → a match of up to 12 min → results with kill-cam and near-miss card → "Next match
in 10s" with the match streak carried over. Around it sit daily/weekly challenges, a free Season Track,
contender levels with prestige, Reach loyalty banners, Jubilee Tokens hidden in the arena, Rusty's
gifts, partner queue, rotating twists and weekly rules, and the Gallery Encore so a knockout isn't the
end of your match.

Fair Play rules are enforced by tests:
- No paid random items, anywhere. Crates are free and in the arena.
- Calm copy only: no countdown pressure, no "last chance", no FOMO in the shop.
- Favor is never sold. Tier Skips move you along the Season Track, whose rewards are all cosmetic.
- Paid perks are casual-only (off in ranked). Renown bonuses only speed up cosmetic progress. The only paid perk that touches play, Trail Boots, switches off at 10 left, so money never decides a final showdown.
- Two passes (Starter Satchel, Trail Boots) give small casual-only perks; both are also free on the
  Season Track.

## IP guardrails

The world is original: Halcyon, the Spire, the Reaches, the Sundial, the Veil, Rusty Dunmore, Herald
Marigold Vane. Tests fail if any source file names the franchise, its places or characters, or
hard-codes the title outside `Names.luau`. Knockouts are a light-dissolve "tapped out", never death or
blood.

## Cross-server (later)

v1 runs lobby and arena in one server and fills with Stand-Ins. To split them, set
`Config.Matchmaking.crossServer = true` and wire MemoryStore queues + `TeleportService:ReserveServer` in
MatchService (the Queue logic module is already server-agnostic).

## CI

`ci/github-actions-ci.yml` runs lint, tests, type check and build. It lives under `ci/` so it can be
pushed without the GitHub `workflow` scope; move it to `.github/workflows/ci.yml` to turn it on.
