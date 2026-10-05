# Research Report — Roblox Horror Game (Phase A)

Date: 2026-10-05
Status: draft for owner review

**Labels used in this document**

| Label | Meaning |
|---|---|
| **[V]** | Verified fact, checked against official Roblox docs or a primary source on the date above |
| **[V\*]** | Believed correct from prior knowledge of the engine, not re-checked today. Must be confirmed in Studio before code depends on it |
| **[R]** | Informed recommendation |
| **[A]** | Assumption, to be measured or tested |
| **[E]** | Experimental idea, only kept if a prototype proves it |

---

## 1. Research summary (one screen)

1. **Roblox audio got much stronger this year.** The object-based audio API (AudioPlayer → Wire → AudioEmitter / AudioListener) is out of beta, and **Acoustic Simulation reached full release on 2026-09-22**: sound is muffled by walls, bends around corners and picks up room reverb from real geometry [V]. Almost no Roblox horror game uses this yet. It is the biggest technical opportunity we found.
2. **Lighting is now "Unified Lighting".** `Lighting.Technology` was replaced by `LightingStyle` (Realistic / Soft) and `PrioritizeLightingQuality` [V]. Realistic replaces the old Future mode and scales down on weaker devices automatically. We design for Realistic and budget shadow-casting lights per room.
3. **The "anomaly / something changed" idea is now saturated on Roblox.** After The Exit 8 (2023), Roblox filled up with spot-the-difference shift games (e.g. Animal Hospital-style anomaly titles). The brief's "spaces subtly change" premise, on its own, would land in that crowd.
4. **The top Roblox horror hits are built on readable entity rules plus audio tells** (Doors, Pressure), or on asymmetric chase (Forsaken, Violence District), or on long-duration dread (99 Nights in the Forest). None makes the *player's own behaviour* the source of the horror. That gap is where our signature mechanic goes.
5. **Pacing systems are a solved design problem outside Roblox.** Left 4 Dead's director (build-up → sustained peak → fade → relax) and Alien: Isolation's two-brain design (a director that knows where you are, and an alien that doesn't, with a "menace gauge" that forces it to back off) give us a proven template for the Horror Director.
6. **Policy is workable.** Content maturity labels go Minimal / Mild / Moderate / Restricted [V]. A no-gore, psychologically intense game lands at **Moderate** ("moderate fear-based content"), which is open to 9–15 (Roblox Select) and 16+ [V]. No blood is needed for anything in our plan.
7. **Studio can be driven by Claude directly.** Studio now has a built-in MCP server with a Claude Code quick-connect toggle (scripts, asset search and insertion, run Luau, playtest, screenshots, simulated input) [V]. Studio Script Sync reached full release in June 2026 and syncs scripts and folders to disk [V]. So code can be written as files and world-building can happen in Studio through a session on the owner's computer.

**Recommended direction:** keep the residential building and the missing-relative hook, drop "don't turn around" as the rule, and build the game around one signature mechanic: **the building remembers where you have walked, and the entity can only travel along those remembered paths.** Details in the Master Plan.

---

## 2. Sources

Official Roblox

| Topic | Source |
|---|---|
| Audio objects (AudioPlayer, Emitter, Listener, Wire, effects) | https://create.roblox.com/docs/audio/objects |
| AudioEmitter reference | https://create.roblox.com/docs/reference/engine/classes/AudioEmitter |
| AudioListener reference | https://create.roblox.com/docs/reference/engine/classes/AudioListener |
| AudioFilter reference | https://create.roblox.com/docs/reference/engine/classes/AudioFilter |
| Acoustic Simulation full release (DevForum announcement) | https://devforum.roblox.com/t/full-release-acoustic-simulation-emit-audio-with-presence/4307121 |
| Audio API out of beta (DevForum) | https://devforum.roblox.com/t/roblox-audio-api-exits-beta-enhanced-sound-controls-now-available/3153454 |
| Lighting properties | https://create.roblox.com/docs/environment/lighting |
| Unified Lighting announcement | https://devforum.roblox.com/t/let-there-be-unified-light-unified-lighting-is-fully-live/3401512 |
| Instance streaming | https://create.roblox.com/docs/workspace/streaming |
| Pathfinding | https://create.roblox.com/docs/characters/pathfinding |
| Performance optimisation | https://create.roblox.com/docs/performance-optimization/improve |
| Content maturity labels | https://create.roblox.com/docs/production/promotion/content-maturity |
| Creator Store (asset licensing, Open Use vs Restricted) | https://create.roblox.com/docs/production/creator-store |
| Studio MCP server | https://create.roblox.com/docs/studio/mcp |
| Studio Script Sync full release | https://devforum.roblox.com/t/full-release-studio-script-sync/4688454 |

Design and industry

| Topic | Source |
|---|---|
| Left 4 Dead AI Director (Valve, 2009) | https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf |
| Alien: Isolation AI, two-brain + menace gauge | https://www.gamedeveloper.com/design/the-perfect-organism-the-ai-of-alien-isolation |
| Alien: Isolation AI revisited (Tommy Thompson) | https://www.aiandgames.com/p/revisiting-alien-isolation |
| Player reception of "cheating" horror AI (Game Studies journal) | https://gamestudies.org/2002/articles/jaroslav_svelch |
| The Exit 8 and anomaly design | https://en.wikipedia.org/wiki/The_Exit_8 , https://ludonodestudios.medium.com/the-art-of-the-loop-what-the-exit-8-teaches-us-about-liminal-horror-and-anomaly-design-a52b5c4f1385 |
| Doors overview | https://en.wikipedia.org/wiki/Doors_(game) |
| Pressure overview | https://urbanshade.org/wiki/Pressure |
| Current Roblox horror landscape, peak CCU figures (secondary source, treat numbers as approximate) | https://adellion.com/roblox-horror-games |

---

## 3. Important Roblox technical findings

### 3.1 Rendering and lighting

| Finding | Label | Consequence for us |
|---|---|---|
| `Lighting.Technology` replaced by `LightingStyle` (Realistic/Soft) + `PrioritizeLightingQuality`. Future → Realistic + true | [V] | Use Realistic + PrioritizeLightingQuality = true. Do not write code that sets `Technology` |
| Lighting properties include `Ambient`, `OutdoorAmbient`, `ExposureCompensation`, `GlobalShadows`, `ShadowSoftness`, `EnvironmentDiffuseScale`, `EnvironmentSpecularScale` | [V] | Interior darkness comes from very low Ambient + EnvironmentDiffuse/Specular near 0, then practical lights. Avoids the "black screen" darkness the brief rejects |
| Light types: PointLight, SpotLight, SurfaceLight with `Shadows` toggle | [V\*] | Flashlight = SpotLight with Shadows on (High tier). Most practicals have Shadows off |
| Post-processing: ColorCorrectionEffect, BloomEffect, DepthOfFieldEffect, BlurEffect, SunRaysEffect; `Atmosphere` (Density, Haze, Glare, Offset, Decay) | [V\*] | Restrained grade + light Atmosphere for depth haze in long corridors. DoF only in scripted moments |
| PBR via `SurfaceAppearance` (ColorMap, NormalMap, RoughnessMap, MetalnessMap) and `MaterialVariant` in `MaterialService` | [V\*] | Kit pieces use MaterialVariants (shared, instancing-friendly); hero props use SurfaceAppearance |
| Instancing collapses identical meshes into one draw call only when mesh, material and SurfaceAppearance/texture match | [V] | Modular kits must reuse the *same* mesh assets. Re-uploading near-duplicates breaks instancing |
| A 1024² texture costs 4× a 512²; docs recommend ≤512² for most assets | [V] | Texture budget: 512² default, 1024² for hero surfaces only |
| `CastShadow` off on small/distant parts; turn lights off room-by-room indoors | [V] | Room-state system disables lights in rooms far from all players |
| `RenderFidelity` Automatic/Performance; `CollisionFidelity` Box is cheapest | [V] | Props default to Box collision, Automatic render fidelity |
| Overlapping semi-transparent parts cause overdraw | [V] | Plastic-sheeting and dust must be used sparingly |
| Mesh import triangle cap and max texture resolution | [A] | Believed ~20k tris/mesh and 1024² textures; confirm in the 3D importer before the art pass |

### 3.2 Audio

| Finding | Label | Consequence |
|---|---|---|
| Object audio: `AudioPlayer` → `Wire` → `AudioEmitter` (3D) or → `AudioDeviceOutput` (2D); `AudioListener` is the microphone | [V] | Entire game uses the new API, not legacy `Sound` |
| Emitters/listeners have `DistanceAttenuation`, `AngleAttenuation`, `AudioInteractionGroup`; `AudioListener:GetAudibilityFor(emitter)` | [V] | Interaction groups let one player hear things the other can't (private hallucinations). `GetAudibilityFor` lets the client measure whether a cue was actually audible |
| Effects: AudioEqualizer, AudioCompressor, AudioReverb, AudioFilter (FilterType, Frequency, Q, Gain) | [V] | Mix buses with compressors; low-pass filter for "through the wall" fallback |
| AudioFader, AudioPitchShifter, AudioDistortion, AudioEcho, AudioChorus, AudioFlanger, AudioTremolo | [V\*] | Used for entity voice processing. Confirm each class exists before use |
| **Acoustic Simulation**: `SoundService.AcousticSimulationEnabled`, per-emitter/listener `AcousticSimulationEnabled`, `BasePart.AudioCanCollide`, `PhysicalProperties.AcousticAbsorption`. Occlusion, diffraction and reverb from geometry. Client-side; may reduce accuracy or switch off to protect frame rate. Not supported on legacy `Sound` | [V] (full release 2026-09-22) | Signature sound feature: footsteps behind a closed door really sound behind a closed door. Must have a fallback (raycast + AudioFilter) because it can auto-disable |
| Proximity voice can route through AudioDeviceInput → AudioEmitter | [V\*] | Co-op voice is spatial and occluded for free. Entity never imitates voice |

### 3.3 Networking, streaming, security

| Finding | Label | Consequence |
|---|---|---|
| StreamingEnabled is on by default and can't be toggled by script. `ModelStreamingMode`: Nonatomic (default), Atomic, Persistent, PersistentPerPlayer | [V] | Rooms are Atomic models. Event props a client must touch instantly are Persistent |
| `StreamingMinRadius` default 64, `StreamingTargetRadius` default 1024; `Player:RequestStreamAroundAsync()` prefetches | [V] | Interiors are small; prefetch the next area on checkpoint/elevator transitions |
| Clients must tolerate streaming: WaitForChild on Atomic models, `PersistentLoaded` for Persistent ones | [V] | Client controllers bind to rooms through a tag/streaming-safe registry, never hard paths |
| Don't replicate per-frame data that doesn't need it; tween on clients, not the server | [V] | Echo playback is sent once as a compressed path and played client-side |
| `UnreliableRemoteEvent` for lossy high-frequency data | [V\*] | Used only for cosmetic sync (e.g. other players' flashlight aim) |
| Server authority: clients can't be trusted for positions, inventory or objective state | [R] | Every Remote validates type, range, cooldown and distance server-side |
| Parallel Luau (Actors) available for CPU-heavy work | [V\*] | Only if wear-map or perception profiling shows it's needed |

### 3.4 AI and pathfinding

| Finding | Label | Consequence |
|---|---|---|
| `PathfindingService:CreatePath` with AgentRadius/Height/CanJump/CanClimb, WaypointSpacing, `Costs`; `PathfindingModifier` (labels, costs, PassThrough); `PathfindingLink`; `Path.Blocked` | [V] | Costs table can make "unworn" regions effectively impassable for the entity: this is how the signature mechanic plugs into the engine |
| Limits: 3,000 stud straight-line distance, 20,000 node budget | [V] | Fine for interiors. We still keep a hand-authored room graph for high-level routing |

### 3.5 Tooling

| Finding | Label | Consequence |
|---|---|---|
| Studio has a built-in MCP server with Claude Code quick-connect; tools for scripts, asset search/insert, mesh/material generation, running Luau, playtest, screenshots, console, simulated input | [V] | World-building, lighting and playtesting can be done by Claude in a session on the owner's computer |
| Studio Script Sync (full release, June 2026) syncs Script/LocalScript/ModuleScript/Folder trees to disk both ways, with conflict dialogs | [V] | Low-friction way to get our files into Studio |
| Rojo remains the file-first build tool; Script Sync is interop | [V] | Recommendation in Master Plan §G |

### 3.6 Assets and licensing

| Finding | Label | Consequence |
|---|---|---|
| Creator Store assets are Open Use or Restricted; a Restricted asset won't load without permission | [V] | Only Open Use or self-uploaded assets go in the game |
| Free models can carry malicious scripts; Studio lets you disable scripts in an inserted model | [V] | Every inserted model is stripped of scripts and audited before it enters the place |
| CC0 PBR texture libraries (Poly Haven, ambientCG) | [V\*] | Source of materials for MaterialVariants. Still re-check each asset's licence page at download |

### 3.7 Policy and safety

| Finding | Label | Consequence |
|---|---|---|
| Maturity labels: Minimal, Mild ("mild fear-based content"), Moderate ("moderate fear-based content", light realistic blood), Restricted (18+ ID-verified) | [V] | Target **Moderate**. No blood, no gore, no disfigurement needed |
| Questionnaire must reflect the most intense content a player can encounter | [V] | Fill it in after the slice so it reflects the real scares |
| Thumbnails/ads, voice chat rules, photosensitivity | [A] | Re-check Community Standards and ad policy in Phase G. Keep thumbnails non-graphic and avoid strobe effects regardless (accessibility) |

---

## 4. Important horror design findings

| # | Finding | Source / label | How we use it |
|---|---|---|---|
| H1 | Fear comes from anticipation; the threat is strongest before it's fully seen | Widely documented; Alien: Isolation analysis | Audio before visuals; the entity's body is shown rarely and briefly |
| H2 | Pacing needs a cycle: build-up, sustained peak, fade, relax. Constant intensity numbs players | L4D Director (Valve 2009) | Director state machine with enforced relax windows |
| H3 | A director that knows where the player is, steering an entity that doesn't, feels smart and fair | Alien: Isolation two-brain design | Director gives the Lodger "hints" when tension is too low; never teleports it into view |
| H4 | A "menace gauge" that forces the threat to back off after sustained pressure prevents frustration | Alien: Isolation | Lodger retreats when a player's stress stays high too long |
| H5 | Players accept a cheating AI if the cheating feels like intention, not unfairness | Game Studies, Švelch | Every Lodger appearance must be explainable by its rule after the fact |
| H6 | Rule-learning is a retention engine; each entity in Doors/Pressure teaches one readable rule with an audio tell | Doors, Pressure | One central rule, learned through play, plus a few sub-rules |
| H7 | Spot-the-difference horror works because the player's memory becomes the weak point, but it is now a crowded format | The Exit 8 and Roblox clones | We use the *player's own trail* as the thing that changes, not arbitrary props |
| H8 | "Nothing happens" moments make real events land harder | General practice; L4D relax phase | Director schedules silence windows and fake setups with no payoff |
| H9 | Co-op makes horror less scary unless players are separated or can't trust each other | Common finding across co-op horror (Lethal Company, Phasmophobia) [R] | Echoes of teammates make the question "is that really them?" part of the mechanic |
| H10 | Session length on Roblox is short; chapters with checkpoints beat one long run | Doors door-count structure, Roblox norms [A] | Three chapters, each 12–20 minutes, saved progress |

---

## 5. Competitor findings

| Title | Core horror mechanic | Strongest element | Weakness | What we learn | Avoid copying |
|---|---|---|---|---|---|
| **DOORS** | Room-by-room progression past entities with distinct audio tells | Each entity = one readable rule + a sound | Procedural rooms get predictable; horror fades into "learn the patterns" | Audio tells and learnable rules drive retention | Hiding in closets, lights-flicker-means-rush |
| **Pressure** | Doors-style deep-sea facility, lockers, many entities | Strong audio and setting identity | Very busy; many entities dilute fear | A setting with its own fiction sells it | Locker-hiding loop, entity roster bloat |
| **The Mimic** | Chapter-based story horror, Japanese folklore | Story chapters, strong set pieces | Leans on loud jumpscares and flashing lights | Chapters with authored set pieces keep people returning | Loud stings as the main scare |
| **Forsaken / Violence District** | Asymmetric killer vs survivors | Social chaos, high CCU | Chase-focused; tension replaced by action | High replay comes from player-vs-player variance | Making the entity a chase machine |
| **99 Nights in the Forest** | Long-duration survival with an unseen watcher | Slow dread, threat you rarely see | Horror becomes background to crafting | Dread works when the threat is mostly implied | Survival-crafting loop |
| **3008** | Infinite store; peaceful days, dangerous nights | Scheduled danger creates anticipation | Not actually frightening after a few nights | Players love knowable danger windows | Infinite procedural space |
| **Anomaly / shift games** (Exit 8-likes on Roblox) | Spot what changed, report it | Memory as the weak point | Format is now saturated; low stakes | Subtle change is powerful when it matters | Report-the-anomaly loop |
| **Demonology** | Ghost investigation with tools | Tools make the player active | Investigation loop is Phasmophobia's | Diegetic tools beat HUD markers | Evidence-checklist loop |

Overused Roblox horror patterns to avoid: lockers/closets as the main defence, lights flicker = monster coming, 1-hit chase entities, loud sting jumpscares, faceless tall figures, backrooms aesthetics, report-the-anomaly.

---

## 6. Problems with the initial concept

| Original element | Problem | Evidence | Verdict |
|---|---|---|---|
| "Don't Turn Around" as the rule | Look-away rules are a staple (Doors' Screech/Eyes, Weeping-Angel games). In first-person you turn constantly, so the rule is either unenforceable or frustrating | H6, competitor matrix | **Replace the rule**; keep the phrase as a twist (in our game you *must* turn around) |
| "Spaces subtly change" as the core | Lands in the saturated anomaly genre; changes feel arbitrary if they have no cause the player can learn | H7 | **Keep, but give change a cause**: the building changes where you have been |
| Abandoned residential complex | Fine. Repeating identical floors and units make change readable and suit modular kits | Kit pipeline, H7 | **Keep**, make it specific (a 1970s housing block emptied for demolition) |
| Missing family member | Generic but gives emotional stakes | — | **Keep**, give it a voice (the brother's tape memos) |
| 1–4 co-op | Co-op weakens fear unless it creates distrust | H9 | **Keep as optional**, solo is the intended first play; co-op gets distrust through echoes |
| "Terrifying entity introduced later" | Undefined; risk of generic monster | Brief §17 | **Define it through the mechanic** (below) |
| Multiple endings | Good if earned by skill, not by random rolls | — | **Keep 3 endings**, one secret ending earned by mastering the mechanic |

---

## 7. Improved concept (summary — full version in the Master Plan)

**Working title: AFTER YOU** (alternative: keep *Don't Turn Around*).

You go into Wren House, a 1970s housing block emptied for demolition, to find your older brother Theo, its night caretaker, who stopped answering. The building keeps a memory of everyone who walks through it. Your own footsteps scuff the dust; a while later the building plays them back. You hear yourself walk past a door you walked past three minutes ago. You see your own flashlight sweep a corridor you already left.

Something lives in those memories. **The Lodger can only travel where someone has already walked.** Fresh dust is safe. Every room you revisit becomes a road for it. Backtracking is the danger. Safe rooms stop being safe the more you use them. In co-op, a teammate's echo walks past you and you can't immediately tell if it is them.

---

## 8. Assumptions log (Phase A)

| ID | Assumption | How we'll check |
|---|---|---|
| A1 | Players will notice and understand echoes without a tutorial popup | Greybox playtest, 5+ fresh players, ask them to describe the rule afterwards |
| A2 | Acoustic Simulation is affordable on low-end mobile, or degrades gracefully | MicroProfiler on a low-end Android device with 4 emitters + simulation on |
| A3 | Footprint decals (pooled, client-side, ~300 max) are cheap enough | Frame time with 300 decals on Low tier |
| A4 | Moderate maturity is the right label | Answer the questionnaire against the vertical slice |
| A5 | Mesh tri cap ~20k and texture cap 1024² | Check in the 3D importer |
| A6 | AudioFader/PitchShifter/Distortion/Echo exist as named | **Confirmed 2026-10-05 in Studio 0.741.19: 43/43 API checks passed** (all 19 audio/remote/pathfinding classes, LightingStyle + AcousticSimulationEnabled script-writable, rbxasset footstep loads in AudioPlayer, collision groups at runtime). Note: AudioEmitter Occlusion/Diffraction/ReverbEnabled are Enum.SimulationMode, not booleans |
