# MASTER IMPLEMENTATION PLAN — AFTER YOU

Date: 2026-10-05 · Status: **awaiting owner approval** · Companion docs: `01_RESEARCH_REPORT.md`, `VERTICAL_SLICE_SPEC.md`, `TASK_BREAKDOWN.md`

Labels: **[V]** verified in docs, **[V\*]** believed correct, confirm in Studio, **[R]** recommendation, **[A]** assumption, **[E]** experimental.

---

## A. Executive summary

*After You* is a first-person psychological horror game for 1–4 players, set inside Wren House, a nine-storey 1970s housing block emptied for demolition. You are looking for your older brother Theo, the building's night caretaker.

The building remembers footsteps. Everywhere you walk, you scuff the dust and leave a trail. Minutes later the building **replays** that trail: your footsteps, your doors, your flashlight beam, and eventually a figure walking your exact route. These are **echoes**, and they are harmless.

The thing that took Theo, **the Lodger**, lives inside those echoes. **It can only travel where someone has already walked.** Clean dust is safe ground. The more you backtrack, the more road you build for it. The game's horror comes from the player slowly realising that their own habits are the map the monster uses.

Three chapters (about 12–20 minutes each), checkpoints between them, three endings, solo-first with optional co-op.

---

## B. Why this concept

| | Original ("Don't Turn Around") | Revised ("After You") |
|---|---|---|
| Core rule | Don't look behind you | The entity follows only where someone has walked |
| Player agency | Avoid an input you use constantly | Plan routes, avoid backtracking, read the dust |
| Environment change | Arbitrary, unexplained | Caused by the player; learnable; still unsettling |
| "I don't want to go back into that room" | Hoped for | **Built into the rule**: going back is literally dangerous |
| "Something is wrong but I can't tell what" | Hoped for | Echoes repeat exactly; the Lodger *improvises*. The tell is a deviation from your own past |
| Replayability | Random events | Every run's echoes come from that run; routes differ; secret ending needs a clean route |
| Clip moments | Jumpscares | "It walked exactly like me, then it stopped and looked at me" |
| Genre crowding | Look-away rules and anomaly games are saturated | No Roblox horror hit we found uses player history as the threat |

The original's best ideas are kept: the residential building, the missing relative, doors behaving inconsistently, audio from impossible places, distant figures, unreliable reality. They now all have one cause.

---

## C. Competitive position

* **Doors / Pressure** teach many entities, one rule each. We teach **one entity, one deep rule**, and let the player's skill with it grow across the game.
* **Anomaly games** ask "what changed?". We ask "**what changed because of me?**", and the answer has consequences.
* **Chase games** make the monster fast. The Lodger is slow, deliberate, and constrained. Danger comes from being cornered by your own trail.
* **Technical edge:** Acoustic Simulation (released 2026-09-22 [V]) means footsteps really sound like they are behind a wall or around a corner. Combined with echoes, sound becomes the primary information channel, as the brief asks.

---

## D. Signature mechanic: Wear, Echoes and the Lodger

### D.1 Wear (the building's memory)
* The playable space is divided into **cells** (one per room, corridor segment, stair landing; authored as tagged volumes). [R]
* Each cell has a **wear** value 0–1. Walking through a cell adds wear; running adds more; standing still adds a little. Wear **decays** slowly (dust settles). Defaults in config, e.g. half-life 6 minutes. [A, tune in playtest]
* Wear is shown **diegetically**: grazing flashlight light reveals scuffed footprints in dust. Fresh rooms have undisturbed dust, thin cobweb strands, closed curtains. No HUD map. [R]
* Wear is **shared** between all players on the server. More players = more wear = more danger. This scales difficulty for co-op without extra tuning code.

### D.2 Echoes (harmless replays)
* The server samples each player's position, facing, and actions (door use, flashlight toggle, knock, item pickup) at a low rate (4 Hz) into a ring buffer. [R]
* The Director schedules echo replays: a segment of a player's past, replayed with a delay of 1–5 minutes, in a cell the player can hear or see but isn't standing in.
* Echo layers, introduced progressively: **sound only** (footsteps) → **object** (a door opening/closing as you did) → **light** (your flashlight beam sweeping) → **figure** (a desaturated, softly lit copy of the player's avatar walking the route).
* Echoes never deviate from what happened. That is the rule the player learns first.

### D.3 The Lodger (the entity)
* **Rule 1:** It can only enter cells whose wear is above a threshold. Implemented as PathfindingModifier costs (`math.huge` for unworn cells) plus a room-graph check. [V for Costs/Modifier API]
* **Rule 2:** It hides inside echoes. It appears as an echo of the player it is hunting and walks their route, until it **deviates** (stops, turns, takes a door the player didn't). The deviation is the tell.
* **Rule 3:** It hears. Running, slamming doors and dropped items in worn cells draw it. Closed doors muffle the player's noise (server-side perception approximation, see §I).
* **Limitation:** It cannot cross clean dust. A player standing in an unworn room is safe, but staying there wears it down.
* **Death:** No gore. The Lodger "takes your place": the camera pulls out behind you and you watch your own avatar walk away down the corridor. You respawn at the last checkpoint. The run you died on becomes a new echo.

### D.4 Why it is fair
Every Lodger appearance is explainable afterwards: "it got to me because I came back through the laundry room three times." Players can learn, plan and outplay it. [H5 in research]

---

## E. Player experience

| Time | What the player feels | What is happening |
|---|---|---|
| **First 30 s** | Quiet, cold, curious. A building that feels recently lived in | Arrive at the Wren House lobby at night. Rain on glass, a buzzing intercom panel, Theo's van outside. One clear goal: find Theo. No HUD |
| **5 min** | "Did I just hear myself?" | Footsteps behind you stop one beat after you stop. Turn around: nothing. You find Theo's tape recorder: *"The dust is how I know where I've been."* |
| **15 min** | Distrust of the building, then of your own route | You see your own flashlight sweep the far end of a corridor you left. A door you closed is open. An echo figure walks your path; one of them stops and looks at you. First Lodger encounter; you escape into a room you've never entered and it halts at the threshold |
| **Midgame (ch. 2)** | Mastery and dread; planning routes; "I'm not going back that way" | Floors 3–6 repeat the same layout with small differences. Resources pull you back through worn areas. Revelation: Theo's echo is still walking the building on a loop; the Lodger wore Theo first |
| **Finale (ch. 3)** | Highest stakes; the rule turned against you | Basement and roof. The building starts replaying echoes of *every* run, including deaths. Reaching the roof needs a route through the building with little backtracking. The Lodger wears your face in plain sight |

---

## F. Gameplay systems

Only systems that serve the mechanic or the horror. Cut list at the end.

| System | Purpose | Notes |
|---|---|---|
| First-person controller and camera | Immersion; controls the frame for scares | Locked first person; subtle head-bob (toggleable); lean-free |
| Flashlight | Main tool; reveals footprints (grazing light) | Battery is **not** a resource (avoids busywork). Flicker only in scripted events |
| Interaction | Doors, drawers, items, tapes, fuses, knocking | Prompt-free on PC (crosshair dot); ProximityPrompt-style on mobile |
| Inventory | Small: key items only (max 4 slots) | Server-owned |
| Clues and tapes | Story and rule teaching | Theo's tape memos, notes, intercom messages |
| Objectives | Unobtrusive progression | Diegetic: Theo's checklist on a clipboard, opened with a key |
| Doors and locks | Navigation, acoustic barriers, echo replays | Doors are the most important prop in the game |
| **Wear system** | Signature mechanic | Server-authoritative cell values, replicated as compact numbers |
| **Echo system** | Signature mechanic | Server records, client renders |
| Horror Director | Pacing | See §J |
| Horror Event system | Data-driven scares | See §J |
| Lodger AI | Entity | See §I |
| Audio manager | Primary horror channel | See §M |
| Camera/post FX | Fear response, transitions | Breath, vignette, slight FOV pull; all toggleable |
| Checkpoints and save | Short Roblox sessions | Chapter checkpoints in DataStore; mid-chapter checkpoints in memory |
| Endings | Payoff | 3 endings (§K) |
| Co-op sync | Shared building, private fears | §N |
| UI | Minimal | Main menu, pause/settings, subtitles, tape transcript log |
| Accessibility | Required | Subtitles with sound direction, brightness calibration, head-bob/shake toggle, reduced flashing, FOV slider, colour-blind safe cues |
| Quality settings | Low-end support | 3 tiers, auto-detected, overridable (§O) |
| Analytics | Tuning | Deaths per cell, time per chapter, event trigger/skip counts |

**Cut on purpose:** stamina bar, battery management, hiding lockers, crafting, procedural rooms, multiple entities, shop. Each was considered and adds busywork or copies competitors.

---

## G. Technical architecture

### G.1 Tech stack [R]

| Concern | Choice | Why |
|---|---|---|
| Language | Luau, `--!strict` in services and shared modules | Type checking catches Remote payload bugs early |
| Code ↔ Studio | **Rojo** project layout for code only (map stays in the .rbxl) | File-first, git-friendly. Studio Script Sync [V] is the fallback if Rojo setup is a problem for the owner |
| Studio automation | Studio's built-in MCP server + Claude Code on the owner's computer [V] | Lets Claude place assets, set lighting, playtest and screenshot |
| Lint/format | selene + StyLua + luau-lsp | Standard Luau toolchain |
| Framework | Small in-house loader (Services/Controllers with `Init`/`Start`), no third-party framework | Brief asks for clear ownership; avoids dependency risk |
| Cleanup | In-house `Janitor`-style module | Explicit lifecycles, no leaks |
| Version control | Git repo for code + docs; place file versions via Roblox | Owner to create a GitHub repo when ready |

### G.2 Folder structure

```text
src/
├── shared/                      → ReplicatedStorage.Shared
│   ├── Config/                  -- all tunables, asset IDs, per-tier settings
│   │   ├── WearConfig.luau
│   │   ├── EchoConfig.luau
│   │   ├── LodgerConfig.luau
│   │   ├── DirectorConfig.luau
│   │   ├── AudioConfig.luau     -- every asset ID lives here or in AssetIds
│   │   ├── QualityTiers.luau
│   │   └── AssetIds.luau
│   ├── Types.luau               -- shared type definitions
│   ├── Net.luau                 -- declares every Remote (name, direction, payload type)
│   ├── Util/ (Janitor, Signal, Spring, RingBuffer, Bitpack, Tags)
│   └── Events/                  -- horror event definitions (data + client presenter refs)
├── server/                      → ServerScriptService
│   ├── Bootstrap.server.luau
│   └── Services/
│       ├── GameStateService     -- chapter flow, checkpoints, endings
│       ├── PlayerService        -- join/leave, character setup, avatar clamp
│       ├── CellService          -- cell registry from tagged volumes, who-is-where
│       ├── WearService          -- wear values, decay, replication
│       ├── EchoService          -- recording ring buffers, echo scheduling payloads
│       ├── DirectorService      -- tension model, pacing state, event selection
│       ├── HorrorEventService   -- runs events, cooldowns, history
│       ├── LodgerService        -- entity AI (perception, state machine, movement)
│       ├── InteractionService   -- validates interactions, doors, items
│       ├── InventoryService
│       ├── ObjectiveService
│       ├── SaveService          -- DataStore, session locking, retries
│       └── AnalyticsService
└── client/                      → StarterPlayer.StarterPlayerScripts
    ├── Bootstrap.client.luau
    └── Controllers/
        ├── CameraController      -- first person, head-bob, FX hooks
        ├── FlashlightController
        ├── InteractionController
        ├── FootprintController   -- renders wear as pooled decals
        ├── EchoController        -- plays echo payloads (sound, door, light, figure)
        ├── AudioController       -- buses, listener, acoustic sim fallback
        ├── HorrorFXController    -- client presenters for events
        ├── LodgerPresentationController -- local-only visuals/audio for the entity
        ├── UIController
        ├── SettingsController    -- quality tier, accessibility
        └── CheckpointController

Studio-only (not in Rojo):
Workspace/Map/<Chapter>/<Area>/<Room> (Atomic models, tagged "Cell")
Workspace/Dynamic, Workspace/Interactables (CollectionService tags)
ServerStorage/Templates (Lodger rig, echo rig, kit pieces)
ReplicatedStorage/Assets (client-side props for events, sounds config refs)
```

### G.3 Module responsibilities and rules
* One owner per piece of state. Wear lives only in WearService; clients get read-only copies.
* Services expose typed methods and Signals; no service reads another service's internals.
* Every Remote is declared once in `Net.luau` with a validator. No ad-hoc `RemoteEvent` creation.
* Instances are found through CollectionService tags and attributes, never hard-coded paths (streaming-safe).
* All tunables in `Config/`. No asset IDs or magic numbers in logic files.

---

## H. Data flow

```text
                ┌────────────── SERVER (authoritative) ───────────────┐
 Character pos ─► CellService ─► WearService ──(WearDelta, 2 Hz)──────┼──► FootprintController
                │      │             │                                │
                │      ▼             ▼                                │
                │  EchoService ◄─ action log (doors, light, knocks)    │
                │      │                                              │
                │      ▼                                              │
                │  DirectorService ── picks event ─► HorrorEventService ──(EventPlay{id, seed, payload})──► HorrorFXController / EchoController
                │      ▲                    │                         │
                │      │                    ▼                         │
                │  tension inputs     LodgerService ── moves rig (server physics, replicated)
                │                           │                         │
 Client input ──► InteractionService (validate: distance, cooldown, state) ─► Objective/Inventory/Door state ──► replicated via attributes
                └──────────────────────────────────────────────────────┘
```

| Remote | Direction | Payload | Rate |
|---|---|---|---|
| `Interact` | C→S | target instance, action enum | user-driven, rate-limited 8/s |
| `FlashlightToggle` | C→S | bool | rate-limited |
| `Knock` | C→S | door instance | rate-limited |
| `WearDelta` | S→C | packed {cellIndex: u16, wear: u8} list | ≤2 Hz, changes only |
| `EventPlay` | S→C | event id, seed, target players, payload (e.g. packed echo path) | per event |
| `EchoPlay` | S→C | packed path (positions quantised to 0.25 studs, yaw u8, action markers) | per echo |
| `LookReport` | C→S (Unreliable) | camera look vector, 4 Hz | used only for "is anyone looking" checks |
| `SettingsSave` | C→S | validated table | rare |

Per-player hallucinations: the server sends `EventPlay` only to the targeted player; the other players genuinely don't see it. [R]

---

## I. AI architecture: the Lodger

### I.1 Perception (server-side)
| Sense | Implementation | Notes |
|---|---|---|
| Wear map | Reads WearService; knows which cells it can enter | Its "world" is the worn graph |
| Hearing | Noise events (run, door slam, drop, knock) with loudness; attenuated per door/wall between source and Lodger using the room graph | Acoustic Simulation is client-only [V], so the server uses its own approximation |
| Sight | Raycast from head to player chest + vision cone; reduced range in darkness unless player's flashlight is on and pointing toward it | Flashlight on = visible from further away. A real trade-off |
| Director hints | Director can give an approximate cell ("menace hint") when tension is low | Never an exact position; never into an unworn cell |

### I.2 State machine
```text
Dormant ──(Director wake)──► Mimic (walks a player's echo route, looks like an echo)
Mimic ──(player close & looking / noise)──► Deviate (stops, turns, holds — the tell)
Deviate ──(player flees)──► Stalk (follows worn path at walking speed, out of sight)
Deviate/Stalk ──(sight confirmed, distance < X)──► Pursue (brisk walk, not a sprint)
Pursue ──(target reaches unworn cell / line broken > N s)──► Search (checks last-known cell & neighbours)
Search ──(timeout / menace gauge high)──► Withdraw (walks away, fades into an echo, back to Dormant)
Any ──(target caught)──► Take (death sequence) ──► Withdraw
```
* **Menace gauge** per player: rises while the Lodger is near/visible; above a threshold forces Withdraw and a Director relax phase. [Alien: Isolation pattern]
* Movement: Humanoid on server with PathfindingService; `Costs` give unworn cells `math.huge` via PathfindingModifier labels per cell [V API]. Paths recomputed on wear change of relevant cells or `Path.Blocked`.
* Speed is tuned so a walking player can stay ahead and a running player always escapes, but running is loud.
* Multiplayer: the Lodger has one target at a time; the others see it as an echo-like figure unless it deviates for them.

---

## J. Horror Director and event system

### J.1 Inputs
Per player: current cell, wear of current cell, time since last event, recent event categories, movement speed, is alone (no teammate within N studs or line of sight), progress (0–1 per chapter), deaths this chapter, menace gauge, recent failed scares (event played but player was not looking / not in earshot: measured client-side with `AudioListener:GetAudibilityFor` [V] and camera dot product, reported back).

### J.2 States (per player, L4D-style)
| State | Behaviour | Exit |
|---|---|---|
| Relax | Ambience only, no events; silence windows allowed | Timer (60–120 s) or entering a new area |
| Build | Low-intensity events: echo sounds, distant doors, light echoes | Tension ≥ build threshold |
| Peak | One major event or Lodger encounter | Event finished |
| Fade | Quiet aftermath, maybe a fake setup with no payoff | Timer → Relax |

Tension is a number 0–100 built from recent events, Lodger proximity, darkness, running. It decays over time.

### J.3 Event definition
```lua
-- src/shared/Events/HallwayEchoCrossing.luau (illustrative, not final)
return {
	Id = "HallwayEchoCrossing",
	Category = "EchoFigure",           -- EchoSound | EchoObject | EchoLight | EchoFigure | Environmental | Lodger | Fake | Silence
	Intensity = 2,                      -- 1 low .. 5 major
	MinProgress = 0.2,
	Cooldown = 120,                     -- seconds, per player
	GlobalCooldown = 30,
	Weight = 0.7,
	States = { "Build" },               -- director states where it can fire
	Requires = {
		Tags = { "LongCorridor" },      -- cell tags
		PlayerAlone = true,
		MinWearInTargetCell = 0.3,
		EchoHistorySeconds = 90,        -- needs this much recorded path to replay
	},
	Select = "EchoFigure.SelectSegment",   -- server function: choose payload
	Present = "EchoFigure.Present",        -- client presenter id
	MaxPlaysPerSession = 2,
}
```
* **Selection:** filter by state, requirements and cooldowns → weight by recency penalty (same category recently = lower weight) → pick with a seeded RNG (seed logged for repro).
* **Repetition guard:** every event has MaxPlaysPerSession; categories have diminishing weight.
* **Adding an event** = one data file + optionally one client presenter. No core changes.

### J.4 Pacing rules
* No two Intensity ≥4 events within 4 minutes for the same player. [A, tune]
* At least one Fake or Silence event before each Peak.
* After a death, forced Relax for 90 s.
* Co-op: events prefer the player who is alone; synchronized events only for set pieces.

---

## K. Level design

| Chapter | Area | Gameplay purpose | Horror purpose | Visual identity |
|---|---|---|---|---|
| 1 Arrival | Lobby & mailroom | Orientation, first clue | Normality with small wrongness | Sodium-orange street light through wired glass, terrazzo floor |
| 1 | Floor 4 East wing (**vertical slice**) | Teach wear, echoes, first Lodger encounter | Trust in the environment breaks | Long corridor, green linoleum, fluorescent tubes (mostly dead), doors with peepholes |
| 1 | Laundry & caretaker's store | Objective (fuses) | Machine noise masks footsteps | Wet concrete, pipes, steam |
| 2 Floors | Floors 3, 5, 6 (same layout, altered) | Route planning across repeating floors | "Have I been on this floor?" | Each floor has a distinct landmark (a pram, a mural, a flooded unit) so players can orient |
| 2 | Stairwells A and B | Choke points; vertical echoes (hear footsteps above/below) | Sound from impossible directions | Bare concrete, numbered landings |
| 2 | Theo's flat (6D) | Major revelation | Theo's echo loops here | Lived-in, warm lamp, the only warm colour in the building |
| 3 Below/Above | Basement boiler room | Restore lift to roof | Densest echoes, every run replays | Dark, red pilot lights, very reverberant |
| 3 | Lift shaft & roof | Finale route | Clean-route challenge | Dawn light, wind, open sky after hours inside |

**Principles applied:** dense spaces, controlled sightlines (corridor dog-legs, glass door panels), thresholds everywhere (doors are acoustic and visual gates), visual landmarks per floor, backtracking is a *designed* risk rather than filler, false objectives (a fuse box that's already been emptied).

**Endings**
| Ending | Condition |
|---|---|
| Leave (standard) | Reach the roof, find Theo's echo, play his last tape, leave at dawn alone |
| Taken (bad) | Caught by the Lodger during the finale: you watch "you" walk out of the front door to Theo's van |
| Clean Route (secret) | Complete the finale without re-entering any cell (wear stays low). The Lodger can't reach the roof. Theo's echo follows your path and becomes solid. Hidden clues on tapes hint at this |

---

## L. Art direction

* **Look:** grounded, cold, slightly overexposed practical lights against deep but readable shadows. Not pitch black: the player should always see the shape of a room, never every detail.
* **Palette:** desaturated greens and greys; sodium orange from outside; one warm colour per chapter as a "safe" signal that later becomes untrustworthy.
* **Materials:** MaterialVariants for linoleum, terrazzo, painted plaster, concrete, wired glass, laminate, carpet; SurfaceAppearance for hero props (doors, intercom, tape recorder). Wear and grime as detail, not gore.
* **Lighting:** `LightingStyle = Realistic`, `PrioritizeLightingQuality = true` [V]. Ambient near black; practicals do the work. Shadow-casting lights capped per room (§O).
* **Atmosphere:** light `Atmosphere` haze for corridor depth; dust motes ParticleEmitter only in flashlight cone on Medium+.
* **Props:** kits listed below; real-world clutter (post, prams, boxes, plastic sheeting over sealed units).
* **Animation:** echo figures use the standard walk with subtle stutter on loop points; the Lodger moves with too-even steps and a delayed head turn.
* **VFX:** echo figures = desaturated, slightly transparent, lit only by the light they "remember". Lodger is fully opaque, that's another tell.
* **Kits:** Corridor, Apartment, Stairwell, Lift, Laundry/Utility, Basement, Roof, Exterior.
* **Asset sourcing:** Creator Store Open Use models (scripts stripped and audited), CC0 PBR textures (Poly Haven, ambientCG), Studio Assistant mesh/material generation for gaps, self-made hero meshes in Blender if needed. Every asset logged in `ASSETS.md` with source and licence.

---

## M. Audio direction

Layers (top = always on, bottom = rare):
1. **Global bed:** building hum, distant traffic, rain (2D, quiet)
2. **Area ambience:** per area, crossfaded by AudioController (fluorescent buzz, boiler, wind)
3. **Room tone:** per room emitters (fridge hum, dripping tap) with Acoustic Simulation
4. **Environmental one-shots:** pipe knocks, settling floorboards, distant doors (Director-scheduled)
5. **Player:** footsteps by floor material, breathing that rises with tension, cloth, flashlight click
6. **Echoes:** player footsteps/doors replayed through 3D emitters, slightly band-limited
7. **Lodger:** almost silent. Its footsteps land **a fraction late** against its animation; a wet inhale before it deviates
8. **Drones/music:** rare, only in Peak; silence is the default

**Mix:** buses (Ambience, World, Player, Echo, Lodger, UI, Voice) each through AudioFader + AudioCompressor [V\*] into AudioDeviceOutput. Ducking: Lodger bus ducks Ambience. Silence windows drop the bed to near zero for 10–30 s before Peaks.

**Acoustic Simulation** on (`SoundService.AcousticSimulationEnabled`) for World/Echo/Lodger emitters [V]. Fallback when unavailable or disabled on Low: one raycast per active emitter per 0.25 s; if blocked, drive an AudioFilter low-pass. Doors set `AudioCanCollide` true; plastic sheeting false.

**Subtitles** include direction and distance hints ("[footsteps, behind you, close]").

---

## N. Multiplayer design

* **Why it exists:** Roblox players expect to play with friends, and echoes create real distrust between them. Solo is the intended first experience and the default menu option.
* **Shared:** wear, doors, objectives, the Lodger.
* **Per-player:** most Director events (hallucinations), echo figures (each player's own echoes play to them, teammates' echoes play to everyone nearby), post FX.
* **Distrust:** teammates' echo figures look exactly like them. The Lodger can wear a teammate. Proximity voice (if players have it) is spatial and occluded; the Lodger never speaks, which is a tell experienced players will share.
* **Separation:** objectives in co-op are split across floors (two fuse boxes on different floors).
* **Risks handled:** desync (server owns state; clients only present), latency (echoes are pre-sent as complete paths and played locally), exploits (Remote validation, server-side position checks).

---

## O. Performance plan

### O.1 Targets [A — to be measured, not guessed]
| Tier | Device class | FPS target | Client memory | Notes |
|---|---|---|---|---|
| Low | Low-end Android/iPhone, 3–4 GB RAM | 30 stable | ≤ 1.0 GB | Acoustic sim off, flashlight Shadows off, footprint cap 120 |
| Medium | Typical laptop, integrated GPU | 60 (≥45 floor) | ≤ 1.5 GB | Acoustic sim on, 2 shadow lights per room |
| High | Gaming PC | 60+ | ≤ 2.0 GB | Flashlight Shadows on, 4 shadow lights, dust particles |

Server: heartbeat ≥ 55 Hz with 4 players and the Lodger active. Network: average ≤ 15 KB/s per client. Load to playable: ≤ 15 s on Medium.

### O.2 Strategy
* Measure with MicroProfiler, Developer Console memory, `Stats` service. Profile before optimizing.
* Room-state system: lights and room-tone emitters off in rooms more than one cell away from all players.
* Kits built from shared meshes and MaterialVariants (instancing [V]).
* 512² textures by default, 1024² for hero surfaces [V].
* Box collision on props, `CastShadow` off on small props [V].
* Footprint decals pooled client-side; capped per tier.
* Tier auto-picked from Roblox's quality level and device type, overridable in settings.

---

## P. Safety / policy

* Target maturity label **Moderate** [V labels]. No blood, gore, disfigurement or self-harm themes. Theo is missing, not dead on screen.
* Fill in the maturity questionnaire against the most intense moment (the death sequence and Peak encounters) [V rule].
* No strobing; flicker effects limited in frequency and toggleable ("Reduce flashing"). [R]
* Voice chat: we don't record, imitate or alter player voices. [R]
* Thumbnails and ads: unsettling but not graphic (an empty corridor with a second flashlight beam). Re-check ad/thumbnail rules in Phase G. [A]
* Monetization must not sell survival. Options: paid private servers, cosmetic flashlight colours that stay in tone, a supporter pass. No revives for Robux. [R]

---

## Q. Production roadmap (dependency order)

| Milestone | Contents | Gate |
|---|---|---|
| **M0 Setup** | Repo, Rojo/Script Sync, Studio MCP session on owner's PC, toolchain | Code syncs into a blank place |
| **M1 Mechanic prototype (greybox)** | Controller, flashlight, cells, wear, footprints, echoes (sound + figure), basic Lodger with wear-restricted pathing | **5 fresh testers explain the rule unprompted** (A1). If not, redesign before art |
| **M2 Vertical slice** | Floor 4 East at final quality, 5 events, Director, audio system, one objective, payoff | Slice acceptance criteria (VERTICAL_SLICE_SPEC.md §8) |
| M3 Chapter 1 | Lobby, mailroom, laundry, stairwell; tapes; save/checkpoints | Full chapter playable solo and 4-player |
| M4 Chapter 2 | Floors 3/5/6, Theo's flat, revelation | Pacing review |
| M5 Chapter 3 + endings | Basement, roof, 3 endings | All endings reachable |
| M6 Polish | Animation, materials, audio mix, UI, accessibility, perf | Perf targets met on all tiers |
| M7 Release | Onboarding, thumbnail, icon, trailer, description, analytics, maturity questionnaire | Acceptance criteria (§T) |

---

## R. Vertical slice scope

See `VERTICAL_SLICE_SPEC.md`. In short: Floor 4 East wing of Wren House; first-person controller, flashlight, interaction; wear + footprints; echoes (sound, door, light, figure); the Lodger with Mimic → Deviate → Pursue → Withdraw; 5 Director-driven events; layered audio with Acoustic Simulation; one objective (restore lift power with two fuses); payoff at the lift. 8–12 minutes.

---

## S. Risks

| Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|
| Players don't read the wear/echo rule | Core mechanic fails | Medium | Greybox gate M1; tape memos + footprints teach it; iterate before art |
| Lodger feels unfair in co-op (teammates wear paths for you) | Frustration | Medium | Menace gauge, slower speed, wear decay; co-op tuning pass |
| Acoustic Simulation too costly on mobile or auto-disables | Audio inconsistency | Medium | Raycast + AudioFilter fallback; off on Low |
| Avatar extremes (huge or tiny avatars, bright outfits) break echo/Lodger tone | Immersion | High | Force R15, clamp body scales, limit accessories, desaturate echoes |
| Too dark on low-end screens | Players quit | Medium | Brightness calibration at first launch; practicals not pitch black |
| Free models with hidden scripts | Security | Medium | Strip scripts on insert, audit, prefer self-upload |
| Scope creep | Never ships | High | Cut list (§F), milestone gates |
| New API names wrong ([V\*] items) | Rework | Low | Verify in Studio command bar before coding against them |

---

## T. Acceptance criteria (production-ready)

**Horror**
- [ ] In blind playtests, most players describe at least one moment of "I didn't want to go back there"
- [ ] No major event repeats within one playthrough unless designed to
- [ ] Each chapter has at least one Fake and one Silence beat before its Peak

**Gameplay**
- [ ] 80% of testers can state the Lodger's rule after Chapter 1
- [ ] All three endings reachable; Clean Route achieved by at least one tester without a guide
- [ ] No soft-locks in 4-player sessions (objective items can't be lost)

**Technical**
- [ ] Performance targets in §O met on reference devices for each tier
- [ ] Zero unvalidated Remotes; exploit checklist passed
- [ ] Server heartbeat ≥ 55 Hz with 4 players over a full chapter
- [ ] DataStore save/load survives forced disconnect and rejoin

**Audio/Visual**
- [ ] Every event has subtitles with direction
- [ ] Brightness calibration and reduced-flashing options work

**Platform**
- [ ] Maturity questionnaire completed honestly; label Moderate or lower
- [ ] All assets logged with licence in ASSETS.md

---

## Implementation order (summary)

1. M0 setup → 2. Shared foundation (Net, Config, Types, Janitor, loader) → 3. Player controller, camera, flashlight → 4. Interaction + doors → 5. Cells + Wear + footprints → 6. Echo record/replay → 7. Lodger AI → 8. Director + event system → 9. Greybox Floor 4 → **M1 playtest gate** → 10. Art kits + lighting → 11. Audio system + mix → 12. 5 slice events authored → 13. Objective + payoff → 14. UI, settings, accessibility → 15. Perf pass on 3 tiers → **M2 slice review**.

Full task list with IDs and dependencies: `TASK_BREAKDOWN.md`.
