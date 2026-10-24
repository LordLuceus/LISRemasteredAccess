# Navigation feasibility — investigation in progress

Scope: Life is Strange Remastered, Steam build 11330282, UE4 4.23.1.
This report records the navigation feasibility work that led to the decision
(25 October 2026) to port the full mod to the remaster. Native queries and
bounded traversals in both scenes are proven. One named bottle has physical
arrival plus native focus/actionability, and the garage route is chosen
automatically around a story-locked door. Broad navigation coverage is not yet
proven; the remaining tests below now belong to the port.

## Concrete advantage: baked navigation data

All six installed pak indexes were inventoried. A bounded inspection parsed
70 map copies (63 unique paths), including the previously troublesome locations.
Actual persistent-level exports resolve to `RecastNavMesh` and
`NavMeshBoundsVolume`. They are instantiated actors, not class defaults or
static-mesh collision helpers.

| Persistent map | Location | Recast actor payload | Bounds actors |
| --- | --- | ---: | ---: |
| E1_5A | Chloe's upstairs rooms | 9,734 bytes | 1 |
| E1_5B | Garage, downstairs and garden | 22,870 bytes | 2 |
| E2_3A | Junkyard | 266,266 bytes | 1 |
| E1_2A | School artifact control | 33,065 bytes | 1 |
| E2_3B | Railroad | 56,110 bytes | 1 |

Their nonempty payloads contain plausible Detour v7 tile headers. The junkyard
persistent-map copies in chunks 1 and 2 are byte-identical, so this observation
does not depend on assuming their mount priority.

This is evidence of a potentially useful native pathfinding foundation. It
does **not** establish that the mesh covers the garage doorway or every junkyard
interaction, that its agent dimensions match Max, or that its runtime filters
respect current doors and scripted obstacles. Tile-header candidates are not a
validated connectivity graph. The school is an artifact-positive control, not
a completed runtime traversal.

## UE4SS installation and compatibility

The installation retains per-file rollback manifests and profile backups.
Bundled sample mods and the graphical console are disabled. The current pinned
loader is experimental **3.0.1-1181-g83330635**. The probe is dormant without an
explicit disposable-profile request. An authorized request can use native scene
entry, native path queries and an optionally selected bounded movement test.
It does not activate interactions, reset progress, generate random facts or
rebuild navigation data.

The upstream [remaster compatibility report](https://github.com/UE4SS-RE/RE-UE4SS/issues/1428)
identifies `HookInitGameState` as problematic. Disabling that alone did not
prevent this installation's startup crash. Disabling all hooks listed in the
sample INI and the UObject-array cache also failed with the same crash stack.

The v3.0.1 source revealed another hook, `HookLoadMap`, which defaults to true
but is omitted from the supplied INI. Adding `HookLoadMap = 0` to the minimal
configuration allowed a 65-second input-free startup check followed by normal
window closure and exit code zero. This is a bounded startup result, not a
general stability guarantee. Two subsequent checks, restoring the default
script-processing hooks and adding reflection inspection, also closed normally
with exit code zero. Lifecycle/console hooks remain disabled.

The running game resolved all four of these reflected functions:

- `NavigationSystemV1:FindPathToLocationSynchronously`
- `NavigationSystemV1:K2_ProjectPointToNavigation`
- `NavigationPath:IsValid`
- `NavigationPath:IsPartial`

The original callbacks did not dispatch. The pinned experimental loader provides
an explicit EngineTick route, which has executed reliably in the controlled
trials. Native dispatch additionally needed a measured vtable correction: stock
UObject ProcessEvent slot 66 points at an empty stub in this executable; the
real dispatcher is slot 67, RVA `0xa51940`. The stock UE4.23 template plus an
unknown extra slot before PostSaveRoot aligns ProcessEvent, GetWorld and the
observed downstream calls. The added function's identity is not claimed.

Native arithmetic, both Boolean results, vector input/output and the exact
sandbox saved-directory getter pass. The full virtual table is not exhaustively
validated. Key callbacks use `RegisterKeyBindAsync` followed by explicit
EngineTick dispatch for Unreal calls. Both synchronous and asynchronous keyboard
registration invoke Lua directly in this pinned source; the earlier attribution
of the key-test failure to the disabled ProcessEvent dispatcher was incorrect.
An independent key test then verified actual Home repeat, F8 pending-test
cancellation and F10 menu entry. The revised injector supplied Home's extended
flag, a longer hold and checked modifier state; the earlier failures do not
establish which of those test conditions was responsible.

## Direct scene access and runtime evidence

Shipped episode definitions and menu bytecode supply these literal title keys:

- House/downstairs/garage: `$GT_Menus_Journal_Episode1Sub10`, map `E1_5B`.
- Junkyard: `$GT_Menus_Journal_Episode2Sub6`, map `E2_3A`.

`GetSubEpisodeLevel` confirms the mapping before
`LoadSubEpisode(title, 0)`, matching the shipped collector/debug-collector call.
The native return value is false even when the correct world and controlled Max
load successfully; actual world/player state confirms travel. The debug menu's
progress-clearing and random-fact routines are not invoked.

Both worlds expose a registered Recast actor. From captured Max capsule-bottom
positions, the house returned six complete sample paths, five with bends; the
junkyard returned eleven complete paths, three with bends. Both rejected the
off-mesh projection and path control. Native `NavigationPath:IsValid` is invoked
explicitly to avoid the Lua wrapper's same-named UObject-validity method.

Max's physical capsule has radius 21 and height 168; the baked agent has radius
22 and height 144. This is a real clearance limitation, not proof that a given
failure is caused by height.

The native movement helper physically followed the house's eight-point test
route twice, reaching a 30-unit horizontal test region in about six seconds.
This is not a named garage-doorway or interaction-arrival test. Early junkyard
requests created no movement path; its opening Matinee retained Max via a
movement track. The prototype waits for that ownership to end, rather than
overriding the game's control. After that ownership cleared, the junkyard's
native five-point path was created and Max physically reached its test region
in about six seconds. Both scenes therefore have a completed bounded physical
route. The later named-target results below extend this evidence, without
establishing general coverage or successful interaction activation.

The native saved-directory getter resolves each explicit `-UserDir` sandbox.
Existing real save/config hashes and the real file inventory remained unchanged
across these trials. Every launch uses a fresh clone, so no test progress needs
to replace the real profile.

Directly closing loaded scenes reproduces the pre-loader vanilla shutdown stack
(first game frame `+0x65e367`). Calling native `ExitToMainMenu` with
`FName("WhatIf_Menu")` before closing has produced exit zero repeatedly. This is
a verified workaround, not a fix for the underlying game crash.

Without an explicit profile request, the prototype is dormant; UE4SS stays installed.
To remove it, close the game and run `scripts/rollback_ue4ss.ps1`. The rollback
checks all owned file hashes before acting, restores any pre-existing files,
and deliberately does not restore old saves. Generated logs/cache are retained.

## Named-target trials

The shipped tool and bottle records explicitly reference `TapToMoveActor`
approach dummies. The experimental target probe resolves these through the
controller's own `LiSInteractionComponent.RegisteredActors`, rather than using
object centres. An important discovery: streamed interaction actors report
their streamed world, not the controller's persistent world. A strict equality
filter discarded all 38 house interactions; native registration provides the
working membership test without map-name allowlists.

| Trial | Observed result |
| --- | --- |
| Garage tools, authored approach | Complete six-point path, about 12.4 metres. Physical walking stalls near the entrance; the no-progress stop fires. No usable arrival. |
| Garage tools, via the doorway beside the couch | Three complete native legs (about 10.6, 1.6 and 3.7 metres). Physical arrival on every leg, about 12 seconds in total, finishing at the tools' authored approach point. Max then speaks the game's own garage line ("I should be able to find the tools I need here"), confirming entry independently of our coordinates. |
| Junkyard bottle, authored approach | Complete two-point path, about 5.5 metres. Physical arrival in roughly 3.5 seconds. Arrival alone does not establish native focus/actionability. |
| Same bottle, standard controller rotation | The game overwrites the requested rotation. No native focus. |
| Same bottle, active camera's one-shot request | Camera turns; with Max stationary, the target enters the native inner actionable list and becomes `ActorInteractionFocused`. Look/Take actions are enabled. No interaction was activated. |

The successful facing experiment uses the *active* `TP_Walk_Manual_C` behaviour,
derived from `CBA_3RD_Basic`, through its `NextWantedCameraRotationForced`,
`WantNextCameraRotationRemainingTick` and `bWantNextCameraRotationForced`
request fields. This is a tested experimental mechanism for this camera mode,
not a general camera API. `SetControlRotation` alone is insufficient. The
interaction component's cached `LastViewRotation` stayed zero even while its
native focus changed; actual camera-manager getters supplied the measured view.

### Failed-route control and limits

At the tools stall, a short sweep along the next path segment finds the garage
threshold mesh (`ST_Furn_Threshold01`) as a mutually blocking contact. Harmless
lighting, audio and trigger volumes are excluded by checking both components'
live collision responses and movement-ignore lists. The same threshold contact
appears with diagnostic half-heights 84 and 72, so that contact does not establish
the known agent-height mismatch as the cause.

These queries do **not** model the character's step-up or depenetration logic,
and only inventory static/dynamic object channels. A contact ahead is not proof
that the character cannot step over it. The player capsule reports a `Custom`
profile, which cannot safely be reused as a named trace profile. The corrected
diagnostic uses object candidates followed by live mutual-response checks;
earlier wrapper/profile attempts are not collision evidence. The probes did not
edit the capsule, mesh, collision responses or story facts; normal scene loading
and gameplay can still change the disposable profile's state.

A separate normal-movement-input control also makes zero progress toward that
next corner over roughly three seconds. Its positive control moves 25.2 cm
back toward previously traversed floor using the same input primitive. The
movement component reports a 25 cm maximum step height. This establishes a
real locomotion obstruction in that direction, not merely a failed AI-follow
request. It does not prove the entire doorway is impassable or rule out a
different approach; the exact step-up/clearance cause remains unresolved.

**Cause of the stall, from the geometry inventory:** the failing path's corners
(60,0 then 65,35) cross wall `ST_Walls_GarageDoor01` at y≈14. The only door
there is `SkeletalMeshActorMAT_2` (centre 47,14), the hall-to-garage door. The
shipped story locks it from the living-room side. The baked navigation mesh
treats that doorway as open, so the native shortest path runs into a closed
door. This is the closed-door case, not a step-height or capsule-height
limit. The 32 cm descent through the couch-side doorway (`ST_Stairs_128x32`)
was walked without difficulty.

**Automatic detour (`door_probe.lua`, session `profile-probe-garage-auto-door-3`).**
With only the tools' approach point as the goal, the planner finds doorways
from `ST_Walls_*Door*` meshes, merging two-sided walls into 12 doorways. It
judges each one with a capsule sweep: Max's real radius and height, raised by
his 25 cm step height so thresholds don't count, and counting only hits where
both components block each other. Results: the hall door is blocked by its own
door mesh, `SkeletalMeshActorMAT_2`. The couch doorway and one living-room
doorway are open. Three other closed doors (sliding/garden/side garage) are
blocked. Four upstairs doorways are *unprojected* (no walkable mesh at the
test points) and are treated as unknown, not open.

The direct native path crosses the blocked hall door, so the planner tries
both directions through each open doorway and rejects any leg that crosses a
blocked one. That rejection mattered: one of the two couch-doorway orders sent
its first leg back through the hall door. It chose the couch doorway (about 15.5 m).
Max physically completed all three legs and arrived. No door state was
read or changed; the door fact was not used.

Limits: doorway detection depends on this game's wall-mesh naming;
doors between unloaded or upstairs areas are not judged; a doorway that is
open but too narrow off-axis is not modelled; and the planner only uses one
detour doorway per route.

**Door and action conditions (read-only, `action_probe.lua`).** The hall door
is two interaction proxies on one mesh: `Door02_5` (hall side, approach
62,-58) and `Door01_4` (garage side, approach 50,105). Door02's Interact sets
`E1_5B_Garage_Door_Tested`; Door01's two Interact actions both set
`E1_5B_Garage_Door_Opened`, one requiring Tested true and one Tested false.
Native `LiSPlayerController:IsFactActive` reports Opened false in the fresh
scene, as expected. Every fact queried so far read false, so the query still
lacks a positive control.

The junkyard plank has no angle restriction on the object or on any action.
Its Move action (`Interact01`, label `$GT_Sensen_Action_Move`) requires
`E2_3A_Junkyard_LD_BoatBottle` true and `E2_3A_Junkyard_LD_AfterBottles_Checkpoint`
false. Look requires the checkpoint false and Move not yet triggered.
BoatBottle most likely means the bottle on the boat has been picked up, so this
is ordinary story gating and needs no navigation work. Object-level angle limits do exist elsewhere:
`Bottle01_0` 180°, `Bottle02_5` 120°, `Bottle07_7` 270°.

All completed named-target sessions returned through the native menu, exited
zero, and preserved real save/config hashes and the file inventory. Closed-door
and changed scripted-obstacle states have **not** yet been exercised.

## Remaining navigation tests

These were the decision tests for the port. The port is now approved; they
remain open as part of building the scanner and autowalk.

1. Game-thread dispatch, basic native calls and registered Recast data are now
   established in both target worlds, with the compatibility caveats above.
2. Done for the garage: autowalk now chooses the couch doorway itself. Next,
   test the planner on other routes and multi-door detours, and re-plan when a
   door opens.
3. Extend the bottle's native focus/actionability result to other targets and
   actual activation, then test closed doors and changed scripted obstacles.

Outcome: navigation on the remaster is far more workable than on the original,
which was the reason for trying it. The full port was approved on that basis.
Optional photo collectables are deferred until the scanner exists.

## Local evidence and reproducibility

- `artifacts/pak-nav-audit/AUDIT.txt`: exact member paths, reader assumptions,
  structural checks, per-package hashes and extraction limits.
- `artifacts/pak-nav-audit/nav-actors.json`: resolved exports and payload hashes.
- `artifacts/ue4ss-install/installation/manifest.json`: installed files and
  retained pre-install profile hashes. Do not rerun the installer over it.
- `artifacts/menu-probe*`: distinct owned startup trials and logs.
- `artifacts/retired-probes/`: the one-off diagnostic probes and scripts that
  produced some of this evidence (stable-loader installer, vtable capture,
  interaction/geometry/collision/movement-input probes). Not part of the mod.
- `artifacts/profile-probe-*/UE4SS.log` and `result.json`: isolated native controls,
  scene entries, route results, actual movement and shutdown/profile checks.
- `artifacts/profile-probe-junkyard-cinematic-wait`: complete native path and
  physical arrival after respecting the opening cinematic.
- `artifacts/profile-probe-key-input-observation`: all three physical key
  callbacks, repeat content, pending cancellation, native menu and clean exit.
- `artifacts/profile-probe-tools-authored-arrival` and
  `artifacts/profile-probe-tools-blocker-identity`: the stalled named route,
  actual path corners and filtered collision candidates.
- `artifacts/profile-probe-bottle-authored-arrival` and
  `artifacts/profile-probe-bottle-native-camera`: matching arrival tests before
  and after using the active game's camera request, including native focus.
- `artifacts/profile-probe-tools-input-positive-control`: zero forward progress
  versus 25.2 cm of return movement, without relocation or collision edits.
- `scripts/summarize_target_trials.py`: repeatable log/profile-result summary;
  `--self-test` checks that path validity, arrival, focus and activation remain
  distinct. It deliberately does not produce an overall PASS.
- `artifacts/profile-probe-vtable`: owner-bound read-only table capture and
  bounded disassembly; `compatibility/VTableLayout.ini` is the generated override.
- `artifacts/scene-access-research`: tagged episode data and menu-call operands.
- Native PE resource evidence:
  `ev_7034245c033294347b01788ae3b040b31de862f40e0a88eb5f5ac66a8bb3b0ac`.
  Executable SHA-256:
  `c141ab07aa9b7f77adde733fc0481042fe3e63724639701322e659d611519cf2`.

Game payloads, profiles, local paths and downloaded tools remain ignored private
artifacts. No game package or executable has been patched. Initial unsandboxed
startup checks updated `Analytics.sav`; subsequent scene/navigation trials use
verified disposable profiles. Nothing here authorizes altering the real story
save or expanding into a full accessibility port.
