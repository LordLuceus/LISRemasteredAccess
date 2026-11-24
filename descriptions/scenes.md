# In-engine scene descriptions

[Authoring index](README.md) · [Movies](movies.md) · [World objects](world-objects.md)

## Choose the mechanism after identifying the event

Start with the episode's narrative inventory and the
[coverage standard](coverage.md), not a list of Matinee names. Timed scenes and
action beats live in [`episode1.lua`](../src/cutscenes/episode1.lua); choice
framing and room context use the separate mechanisms below. The classroom is
part of that episode catalogue, not a separate content system.

## Timed scenes and action beats

The episode catalogue's three forms preserve different timing needs:

- **`timelines`** maps exact Matinee actor names to `length`, narration `windows`
  and optional `loop`/`after_first_loop` fields. Each window is
  `{start, finish, localization_key}`. Edit the corresponding key under
  [`src/lang/en/scenes/episode1/`](../src/lang/en/scenes/episode1/), grouped by
  location. Add another episode's modules through the small
  [language index](../src/lang/en.lua); see [Language files](languages.md).
- **`groups`** holds linked multi-actor policies with `level`, `order` and
  `stages`. A stage has its exact actor, length, explicit protected dialogue
  intervals and cue records `{start, finish, key}`. `groups.classroom` includes
  the introduction, its continuation and the return visit.
- **`actions`** maps exact actor names to short English one-shot descriptions.
  These are small environmental beats outside the timed catalogue, not a
  substitute for timed dialogue protection. The five existing texts are kept
  verbatim; do not move a timed scene into this form to avoid measuring it.

The classroom was the first implementation. It needs linked stages because
the continuation and Jefferson's lesson can run concurrently, and a readout can
survive the relevant segment transition. The lesson is **not** a substitute
clock. Its explicit Max speech bounds intentionally permit some lecture overlap.
That requires a different data shape, not a different content file or reader.

## Dialogue-choice framing

[`cutscenes/dialogue.lua`](../src/cutscenes/dialogue.lua) registers the visual
context of reply prompts. This is not the dialogue-option reader. The current
Episode 1 text is in [choices.lua](../src/lang/en/scenes/episode1/choices.lua).
[`main.lua`](../src/main.lua) calls `dialogue_scene.key` and handles queued choice
narration, repetition and cancellation when the prompt changes.

Each registration binds a world and one or more complete English answer sets to
a text key. Answer order is sorted because it can change on rewind; the same
labels in a different world must not identify the wrong scene. Capture the real
prompt and visual context, including conditional alternatives. Never invent an
answer set to make a fixture pass or describe the outcome before it is chosen.
The current lookup is English-only.

For another episode, add its verified registrations and text keys to this route
(or a deliberately tested generalisation of it). Adding only Matinee windows
does not cover these stationary choice shots. Exercise the registered lookup
and its `main.lua` consumer, with reordered answers, wrong-world decoys, changing
prompts, rewind and repeat. Existing choice checks are in
[`tests/lua/run.lua`](../tests/lua/run.lua).

## Room context

[`descriptions/episode1_rooms.lua`](../src/descriptions/episode1_rooms.lua) provides
setting text for scanner room identities. The room-change block in
[`main.lua`](../src/main.lua) currently imports that table directly. It waits for
a stable playable-room reading and avoids competing with scenes, movies and
choices; preserve those boundaries. Room names alone are not setting descriptions.

Inventory the new episode's playable locations and meaningful changed settings.
Creating an `episode2_rooms.lua` file alone will not load it: explicitly extend
the consumer or introduce a shared catalogue loader with preservation tests.
Verify actual scanner room identities and entry behaviour; a volume or authored
actor existing in a map does not prove that the player can enter or select it.
Reuse accepted setting details without repeating them before every object.

## Register another episode

Create `src/cutscenes/episode2.lua` with the same top-level `timelines`, `groups`
and `actions` sections (empty sections are allowed). Add its module to the
explicit list passed to `M.new` for `M.default` in
[`registry.lua`](../src/cutscenes/registry.lua). Keep the existing classroom
startup policy: adding content is not permission to change reader startup.
Do not create an unregistered file and assume it is discovered automatically.

The registry compiles timing policies and derives allowed levels from exact
registered actor identities. Duplicate actor registrations fail. The shared
[scene adapter](../src/cutscenes/scene.lua) still checks the active controller
world and streamed-level ownership; another loaded map's actor must not narrate.
Ambiguous concurrently active unrelated scenes fail closed. Only the declared
group shares a policy across its segments. [actions.lua](../src/cutscenes/actions.lua)
uses the same registration/ownership boundaries and retains its start-edge gate.

For ordinary timeline windows, the compiler preserves the existing rules:
the cue-start interval ends at the earlier of `start + 0.8` and `finish`;
the gaps outside narration windows are protected, including the final tail
through `length + 0.25`. Grouped stages instead carry their explicit onset and
protection intervals. These are not interchangeable formats. Do not round,
rescale or regenerate timings merely to simplify a refactor.

## Author from evidence

1. Inventory the episode's maps, including numbered LD variants and non-LD maps.
   Identify exact Matinee actors, director tracks, camera cuts, dialogue events
   and duration. A camera-track count is not a count of long story scenes or
   proof every branch is reachable. The [Episode2 census](episode2-inventory.md)
   states its scope and exclusions.
   Reconcile that technical inventory with the transcript, scene order, choices,
   rooms and optional branches. Events may span multiple actors or happen outside
   a camera sequence; a single actor may contain several important events.
2. Use actual frames/captures to identify the visual event. Animation starts can
   precede the visible action substantially; the classroom paper throw was an
   example. Verify the event, not just a plausible animation name.
3. Determine dialogue intervals from shipped voice metadata/audio and observed
   playback in the target language. Choose a gap long enough for the narration.
   State which exceptions are intentional and already accepted.
   Episode 1 has accepted brief overlap with other characters where necessary,
   while protecting Max's lines, as well as the classroom's explicit policy.
   Do not silently turn "prefer gaps" into "omit the event". Use an applicable
   accepted policy; if a new exception is needed, ask rather than weakening the
   runtime guards or leaving the missing event unreported.
4. Add actor definitions and text keys without changing existing ones. Keep
   alternate branches separate and preserve anonymous identities until their
   introduction. Never leak a future choice outcome through an earlier caption.
5. Test actual reader callbacks as well as pure policy helpers. With explicit
   launch permission, validate the relevant story branch and shutdown through
   the established isolated-profile procedure.

The runtime samples scalar playback state on the game thread. Do not traverse
`GroupInst` or `InterpTracks` live to reconstruct timing; use offline evidence.
Never replace the playback clock with elapsed wall time or remove existing
speech ownership, English-only timing or rewind/pause/focus guards.

## Verification

Run the [common checks](README.md#verification-and-handoff). Relevant tests include
`tests/lua/scene_descriptions.lua`, `scene_registry.lua`, `episode1_actions.lua`,
`restored_scene_beats.lua` and `main_descriptions.lua` under `tests/lua/`.
The existing test filename `episode1_actions.lua` describes its fixture scope;
the runtime adapter is now generic `cutscenes.actions`.

Preservation fixtures capture original authored data and the actual compiled
policies. They test exact keys, text, numbers, protections, loop flags, allowed
levels and shared group identity. Keep those independent of the refactored
compiler. Exercise first entry, continuation, later return, competing actors,
rewind, pauses, menus, focus changes, stale repeats and both input devices.
Adding Episode 2 must leave unregistered actors rejected and Episode 1 unchanged.
These tests do not determine whether a scene's prose explains its important events.
Apply the [editorial and completion checks](coverage.md) separately.
