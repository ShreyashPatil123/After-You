# Vertical Slice Specification — Floor 4 East, Wren House

Date: 2026-10-05 · Status: awaiting approval · Parent: MASTER_IMPLEMENTATION_PLAN.md §R

The slice must look, sound and play at final quality. It proves three things:
1. Players learn the rule "it can only walk where you've walked" without a popup.
2. The game is frightening without gore or loud stings.
3. The architecture (services, Director, event data files) supports adding content cheaply.

Play length: 8–12 minutes solo. Supports 1–4 players.

---

## 1. Layout

```text
                          N
   ┌──────────┬──────────┬───────────┬──────────┐
   │   4A     │   4B     │  LAUNDRY  │   4D     │
   │ (locked, │ (Theo's  │  & STORE  │ (sealed: │
   │  knock)  │  tape)   │ (fuse #1) │ plastic, │
   │          │          │           │ fuse #2) │
   ├───D──────┴───D──────┴────D──────┴───D──────┤
   │ STAIR A    CORRIDOR (dog-leg at midpoint)  LIFT LOBBY │
   │  (start)   fluorescent tubes, 2 working    (fuse box) │
   ├───D──────┬───D──────────────────┬───D──────┤
   │  4F      │   4E (flooded,       │ CARETAKER│
   │ (never   │   ankle water: loud  │  CLOSET  │
   │  opens)  │   footsteps)         │          │
   └──────────┴──────────────────────┴──────────┘
```
* Corridor ~120 studs long, 9 studs wide, 11 studs high, with a dog-leg at the midpoint so the full length is never visible at once.
* Cells: Stair A, Corridor West, Corridor East, Lift Lobby, 4B, Laundry, 4D, 4E, Caretaker Closet (9 cells; 4A and 4F are not enterable).
* 4D is the "clean room": sealed with plastic sheeting, dust untouched. It is where the player escapes during the first encounter.
* 4E's flooded floor makes footsteps loud: a deliberate hearing-risk route that's shorter.

## 2. Flow (beat sheet)

| # | Beat | Player action | System / event | Teaches |
|---|---|---|---|---|
| 1 | Cold open | Climbs Stair A, door to corridor sticks then opens | Intercom crackles from Lift Lobby: Theo's voice, one word, cut off | Sound pulls you forward |
| 2 | Orientation | Reads Theo's clipboard pinned to Stair A door: *"Lift's out. Fuses: laundry, and one in 4D."* | Objective set (diegetic) | Goal |
| 3 | Knock | Knocks on 4A (prompted by a note: "4A, knock twice, she's deaf") | Action logged for later echo | — |
| 4 | **Event 1: Behind you** (EchoSound) | Walks the corridor | Your own footsteps play 1 s behind you; when you stop they stop one step later. Turning around shows nothing | Echoes exist |
| 5 | Tape | Finds tape recorder in 4B | Theo: *"The dust is how I know where I've been. Clean dust, nobody's been. It's the clean rooms you want."* | Wear rule, verbally |
| 6 | Footprints | Flashlight at low angle shows scuffs on the corridor lino, none in 4D's doorway | FootprintController | Wear is visible |
| 7 | Fuse #1 | Laundry: fuse in a locker drawer. Machines thump | Machine noise masks sounds (audio ducking) | — |
| 8 | **Event 2: Door and light** (EchoObject + EchoLight) | Returns to corridor | 4B door, which you closed, opens and shuts exactly as you did. Then your flashlight beam sweeps from the far end of the dog-leg | Echoes copy *you* |
| 9 | Silence | Approaches 4D | Director Silence window: ambience drops to near zero for ~20 s | Anticipation |
| 10 | **Event 3: Crossing** (EchoFigure) | — | A figure that is *you* (your avatar, desaturated) crosses the corridor end, walking your earlier route into the laundry | Echo figures |
| 11 | Plastic | Cuts through 4D's plastic sheeting (hold interact) | Clean room, no footprints, quieter acoustics | Clean rooms feel different |
| 12 | Fuse #2 | Takes fuse from 4D's meter cupboard | — | — |
| 13 | **Event 4: The deviation** (Lodger) | Steps back into the corridor | An echo of you walks toward the lift, on your route. It stops. It turns. Its footsteps keep going for one step after it stops. The corridor's working tubes cut out | Echoes repeat; this one didn't |
| 14 | Encounter | Player flees | Lodger: Deviate → Pursue at a brisk walk along worn cells. Escape routes: back into 4D (clean, safe) or through 4E (shorter but loud) | **The rule, felt** |
| 15 | Threshold | Player in 4D | Lodger stops at the doorway line where footprints end. Breathing. Withdraws after menace gauge peaks | Clean dust is safe |
| 16 | Fade | Waits, then goes to Lift Lobby | Director Fade + Relax | Release |
| 17 | Power | Inserts both fuses | Lift lights up, doors open | Objective done |
| 18 | **Event 5: Payoff** (EchoObject, scripted) | Enters lift | Inside: footprints already lead in, none lead out. As the doors close, two knocks on the lift door from the corridor, the same rhythm you knocked on 4A. Doors shut. Cut to black, title card | Your past is following you |

Death at any point: "Taken" sequence (camera pulls back, your avatar walks away), respawn at Stair A with fuses kept, forced Relax 90 s, the death run becomes a new echo.

## 3. Systems in scope

| System | Scope in slice | Out of scope |
|---|---|---|
| Player controller & camera | First person, walk/run/crouch, head-bob toggle | Lean, climbing |
| Flashlight | On/off, grazing-light footprint reveal, tier-based shadows | Battery |
| Interaction | Doors (open/close/knock), pickups, hold-to-cut plastic, fuse insert, tape play | Puzzles |
| Inventory | 4 slots, key items only, server-owned | Item use UI beyond fuses |
| Objectives | Clipboard checklist (2 fuses → power) | Multiple chapters |
| Wear + footprints | Full | Persistent wear across sessions |
| Echoes | Sound, object, light, figure | Echoes from other servers |
| Lodger | Mimic, Deviate, Pursue, Search, Withdraw, Take | Stalk across floors |
| Director | Relax/Build/Peak/Fade, tension, cooldowns | Cross-chapter progress |
| Events | The 5 above + 2 Fake + 1 Silence | — |
| Audio | All layers, buses, Acoustic Simulation + fallback | Music score |
| UI | Main menu (Solo/Co-op), pause, settings, subtitles, tape transcript | Store |
| Save | Checkpoint in memory only | DataStore |
| Quality tiers | Low/Medium/High switching | Auto-benchmark |
| Co-op | 1–4 players, shared wear, per-player events | Split objectives |

## 4. Art scope
* Kits: Corridor, Apartment (one dressed unit 4B, one sealed 4D), Laundry, Stairwell landing, Lift lobby + lift car.
* About 40 unique props, all from shared meshes and MaterialVariants.
* Hero assets: corridor doors (peephole, number plate, letterbox), intercom panel, tape recorder, fuse box, plastic sheeting, lift doors.
* Lighting: Realistic style, ambient near black, 2 working fluorescent fixtures, sodium light through stair window, flashlight.
* Characters: echo rig (player's avatar, clamped proportions, desaturated); Lodger (player's avatar, opaque, slightly wrong animation timing).

## 5. Audio scope
* About 60 sounds: footsteps (lino, concrete, water, plastic) × 6 variations, doors (open, close, creak, knock, slam), fluorescent buzz, laundry machines, rain, building hum, intercom crackle, Theo's tape lines (voice actor or TTS placeholder labelled as placeholder), breathing (player, Lodger), lift.
* Theo's voice: placeholder via `AudioTextToSpeech` [V class exists] until a real voice is recorded.

## 6. Technical scope
* Code under `src/` per Master Plan §G, `--!strict` where practical.
* Every tunable in `Config/`; every asset ID in `AssetIds.luau`.
* All Remotes declared in `Net.luau` with validators.
* Analytics events: death cell, time per beat, events played/skipped/missed.

## 7. Test plan for the slice

| Area | Test |
|---|---|
| Functional | Solo full run; 4-player run; die at each beat and respawn; leave/rejoin mid-run; fuses can't be lost or duplicated |
| Horror | Does Event 1 get noticed? (measured: player turned around within 3 s) Is the deviation noticed before the lights cut? Do testers state the rule afterwards? |
| Technical | 200 ms simulated latency; Low tier on a low-end phone; MicroProfiler capture at Event 4; server heartbeat with 4 players |
| UX | First-launch brightness calibration; subtitles on all events; head-bob off; reduced flashing on |

## 8. Acceptance criteria
- [ ] 8–12 minute run, no soft-locks, solo and 4-player
- [ ] At least 4 of 5 fresh testers can explain the Lodger's rule after playing (A1)
- [ ] Low tier ≥ 30 FPS on a low-end phone; Medium ≥ 45 FPS on an integrated-GPU laptop during Event 4
- [ ] Every event plays from a data file; adding a sixth event needs no changes to Director code (demonstrated by adding one)
- [ ] Owner approves visual and audio quality as representative of the final game
