# Changelog

## 2026-10-05
- Phase A–C delivered: research report, revised concept ("After You"), Master Implementation Plan (A–T), vertical slice spec, task breakdown.
- Decision: replace the "don't turn around" rule with Wear/Echoes/Lodger as the signature mechanic (see Master Plan §B, §D). Pending owner approval.
- Decision: use Unified Lighting (`LightingStyle = Realistic`), the object audio API with Acoustic Simulation, Rojo layout for code. Pending owner approval.

## 2026-10-05 (later)
- Owner approved M0-M1. Built the greybox prototype in `game/`: Rojo project, 11 server services, 11 client controllers, 10 data-driven horror events, 17 unit tests for pure logic, place file `AfterYou_Greybox.rbxlx`.
- Decision: the greybox map is generated from `Config/LevelLayout.luau` at server start, so layout changes are code changes and the place file can be rebuilt any time.
- Decision: wear reaches PathfindingService through one PathfindingModifier label per cell, priced 1 (worn) or math.huge (clean). Cell volumes use a "CellVolume" collision group so rays ignore them.
- API names checked against the Luau type definitions generated from Roblox's API dump (AudioFader, AudioFilter, AudioEmitter.SetDistanceAttenuation, LightingStyle, PrioritizeLightingQuality, AcousticSimulationEnabled, AudioCanCollide, UnreliableRemoteEvent, PathfindingModifier). Still to confirm in Studio (S5); script writes to LightingStyle/AcousticSimulationEnabled are wrapped in pcall until then.
- S5 done: all 43 API checks passed in Studio 0.741.19.7411056 (see research report A6). [V*] items used by the greybox are now verified.
