# Task Breakdown — After You

Date: 2026-10-05 · Parent: MASTER_IMPLEMENTATION_PLAN.md §Q

**Where** column: **Code** = Luau files written in the project folder (no Studio needed). **Studio** = needs Roblox Studio on the owner's computer (Claude drives it through Studio's MCP server in a Remote Control session). **Owner** = needs the owner's hands or decision.

Status: ☐ not started · ◐ in progress · ☑ done

## Phase A–C: Research, design, technical design
| ID | Task | Where | Depends | Status |
|---|---|---|---|---|
| P1 | Research report | Code | — | ☑ |
| P2 | Revised concept + Master Implementation Plan (A–T) | Code | P1 | ☑ |
| P3 | Vertical slice spec | Code | P2 | ☑ |
| P4 | Task breakdown (this file) | Code | P2 | ☑ |
| P5 | **Owner approves concept and plan** (or asks for changes) | Owner | P2–P4 | ☑ |

## M0: Setup
| ID | Task | Where | Depends | Status |
|---|---|---|---|---|
| S1 | Create a GitHub repo for code + docs (optional but recommended) | Owner | P5 | ☐ |
| S2 | Rojo project (`default.project.json`), selene, StyLua, luau-lsp config | Code | P5 | ☑ |
| S3 | Turn on Remote Control for a folder on the owner's PC; enable Studio Assistant → MCP Servers → Claude Code | Owner | P5 | ☑ |
| S4 | New place, Unified Lighting set to Realistic, StreamingEnabled check, R15 forced, avatar scale clamps | Studio | S3 | ☐ |
| S5 | Verify [V\*] APIs in the command bar (AudioFader, AudioPitchShifter, etc.) and record results in the research assumptions log | Studio | S3 | ☑ |
| S6 | Sync `src/` into the place (Rojo or Script Sync) and confirm both bootstraps run | Studio | S2, S4 | ☐ |

## M1: Mechanic prototype (greybox)
| ID | Task | Where | Depends | Status |
|---|---|---|---|---|
| F1 | Shared foundation: Net (Remotes + validators), Config, Types, Janitor, Signal, RingBuffer, Bitpack, service/controller loader | Code | S2 | ☑ |
| F2 | PlayerService: character setup, R15, avatar clamp, spawn | Code | F1 | ☑ |
| F3 | CameraController: first person, head-bob, FX hooks | Code | F1 | ☑ |
| F4 | FlashlightController + server toggle replication | Code | F1 | ☑ |
| F5 | InteractionService/Controller: doors (open/close/knock), pickups, hold actions | Code | F1 | ☑ |
| F6 | CellService: cells from tagged volumes, occupancy tracking | Code | F1 | ☑ |
| F7 | WearService: add/decay/replicate wear (packed deltas) | Code | F6 | ☑ |
| F8 | FootprintController: pooled decals, grazing-light reveal, tier caps | Code | F7 | ◐ |
| F9 | EchoService: 4 Hz recording, action log, payload packing | Code | F6 | ☑ |
| F10 | EchoController: play sound/object/light/figure echoes from payloads | Code | F9 | ☑ |
| F11 | LodgerService: perception (hearing, sight), state machine, wear-restricted pathfinding via PathfindingModifier costs | Code | F7, F9 | ☑ |
| F12 | DirectorService + HorrorEventService + event data format | Code | F7, F9, F11 | ☑ |
| F13 | Greybox Floor 4 East (generated in code by GreyboxBuilder from LevelLayout) | Code | S2 | ☑ |
| F14 | Wire everything in the greybox, fix integration bugs | Studio | F1–F13 | ☐ |
| F15 | **Gate: playtest with 5 fresh players**; record whether they can state the rule | Owner | F14 | ☐ |

## M2: Vertical slice
| ID | Task | Where | Depends | Status |
|---|---|---|---|---|
| V1 | Source assets: Creator Store (Open Use, scripts stripped), CC0 PBR textures, Assistant-generated meshes; log in ASSETS.md | Studio | F15 | ☐ |
| V2 | Kits: Corridor, Apartment, Laundry, Stairwell, Lift with MaterialVariants | Studio | V1 | ☐ |
| V3 | Build Floor 4 East from kits, dress props, set sightlines | Studio | V2 | ☐ |
| V4 | Lighting pass: Realistic, ambient, practicals, shadow budget, Atmosphere, post | Studio | V3 | ☐ |
| V5 | AudioController: buses, listener, Acoustic Simulation + raycast fallback | Code | F1 | ◐ |
| V6 | Source/record ~60 sounds, IDs into AudioConfig/AssetIds | Studio | V5 | ☐ |
| V7 | Author 5 slice events + 2 Fake + 1 Silence as data files + presenters | Code | F12, V5 | ☐ |
| V8 | Objective (fuses), lift power, payoff sequence, Taken death sequence | Code | F5, F12 | ☐ |
| V9 | Echo rig + Lodger rig visuals and animation timing | Studio | F10, F11 | ☐ |
| V10 | UI: main menu, pause, settings, subtitles, tape transcript, brightness calibration | Code | F1 | ◐ |
| V11 | Quality tiers + SettingsController | Code | V4, V5 | ☐ |
| V12 | Analytics events | Code | F12 | ◐ |
| V13 | Perf pass on 3 tiers (MicroProfiler, memory) | Studio | V3–V11 | ☐ |
| V14 | Slice test plan (spec §7) and bug fixing | Studio | V13 | ☐ |
| V15 | **Gate: owner review of the slice** | Owner | V14 | ☐ |

## M3–M5: Production (planned at a coarser grain; refined after M2)
| ID | Task | Where |
|---|---|---|
| C1 | Chapter 1: lobby, mailroom, stair A full, tapes 1–4, DataStore save + chapter checkpoints | Code + Studio |
| C2 | Chapter 2: floors 3/5/6 variants with landmarks, stairwell B, Theo's flat, revelation, Lodger Stalk across floors | Code + Studio |
| C3 | Chapter 3: basement, lift shaft, roof, finale route, all-runs echo flood | Code + Studio |
| C4 | Endings: Leave, Taken, Clean Route; ending tracking | Code |
| C5 | Co-op: split objectives, teammate echoes, Lodger wearing teammates, voice routing | Code |
| C6 | 20–30 more events across chapters | Code |
| C7 | Story: full tape script, notes, intercom lines; real voice recording | Owner + Code |

## M6: Polish
| ID | Task | Where |
|---|---|---|
| X1 | Animation polish (Lodger timing, echo stutter, door animation) | Studio |
| X2 | Material and lighting polish per area | Studio |
| X3 | Final audio mix, ducking, silence windows tuned | Code + Studio |
| X4 | Accessibility pass (subtitles, flashing, FOV, colour cues, controller + mobile controls) | Code |
| X5 | Optimisation to targets on reference devices | Studio |
| X6 | Exploit/security checklist on all Remotes | Code |

## M7: Release
| ID | Task | Where |
|---|---|---|
| R1 | Onboarding check: first 5 minutes with no instructions | Owner |
| R2 | Maturity questionnaire, experience description, genre tags | Owner |
| R3 | Icon, thumbnails, screenshots, trailer capture | Studio + Owner |
| R4 | Monetization that doesn't sell survival (private servers, supporter pass) | Owner decision |
| R5 | Analytics dashboard review and post-launch tuning plan | Code |
