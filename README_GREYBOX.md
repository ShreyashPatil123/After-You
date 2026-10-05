# After You — greybox prototype (M1)

Grey blocks only. This build exists to answer one question before any art is made:
**do fresh players work out that the Lodger can only walk where someone has already walked?**

## Open it
1. Roblox Studio > File > Open from File > `AfterYou_Greybox.rbxlx`
2. Press **Play** (F5). The map builds itself at start (Floor 4 East of Wren House).
3. For co-op tests: Test tab > Clients and Servers > 2–4 players.

## Controls
| Key | Action |
|---|---|
| WASD | walk |
| Shift (hold) | run (loud) |
| C / Ctrl | crouch toggle (quiet) |
| F | flashlight |
| E | use (doors, notes, tape, fuses, fuse box) · hold on plastic sheeting to cut it |
| Q | knock on a door |
| Tab | Theo's list (after reading the clipboard) |
| F2 | debug overlay (Studio only): pacing state, tension, wear per cell, why each event is or isn't ready |

## What should happen (slice beats)
Clipboard in the stairwell → corridor → tape in 4B (Theo explains the dust) → fuse 1 in the laundry →
echoes start (your footsteps behind you, a door you used, your own flashlight, a copy of you) →
cut the plastic into 4D (clean dust) → fuse 2 → step back out: the Lodger appears as an echo of you,
stops, turns solid, lights die → escape into a room you haven't worn down → fuse box → lift → payoff.

## Layout
`src/shared` (ReplicatedStorage.Shared): Config (all tunables + asset ids), Logic (pure, unit-tested),
Events (one file per horror event), Net (every remote, validated), Util.
`src/server/Services`: GreyboxBuilder, Player, Cell, Wear, Interaction, Echo, HorrorEvent, Objective, Lodger, Director, Analytics.
`src/client/Controllers`: Settings, Audio, UI, Movement, Camera, Flashlight, Door, Interaction, Footprint, Echo, LodgerPresentation.

## Build and checks (from this folder)
```
luau tests/run.luau                         # 17 unit tests for pure logic
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau src
stylua --check src tests
rojo build default.project.json -o AfterYou_Greybox.rbxlx
```

## Known gaps (on purpose for M1)
- Most sounds have no asset yet (`Config/AssetIds.luau`); footsteps use the built-in plastic step. Missing sounds are skipped with one warning each.
- No mobile touch controls yet; PC keyboard only.
- No save/DataStore, menus or settings screen; tier is auto-detected.
- Footprints are dark slabs, not decals, and don't need grazing light yet.
