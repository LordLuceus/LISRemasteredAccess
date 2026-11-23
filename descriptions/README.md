# Description authoring

Start here when adding, reviewing or reorganizing descriptions. This is a
**source-checkout developer guide**, not another player manual. The player's
[README](../README.md) documents controls and currently supported content.

## Choose the category by what the game does

1. **Close-up picture:** the native picture viewer displays a texture, often
   with multiple pages and a separate Read mode. Follow [Close-ups](closeups.md).
2. **World object:** Look leaves the object in the world while Max comments;
   scanner selection can also request its description. Follow
   [World objects](world-objects.md).
3. **Movie:** the game plays a pre-rendered MP4 through its story movie player.
   Follow [Movies](movies.md).
4. **In-engine scene:** a Matinee camera sequence, conversation, transition or
   short environmental beat plays in the engine. Follow [Scenes](scenes.md).

Classify **each action branch**, not just each object. A first Look can use a
camera, a later Look can remain in the world, and another action can open a
picture. Do not create competing descriptions for the same moment.

[Journal photos](journal-photos.md) use a separate image catalogue, not the
close-up viewer. [Room/scanner descriptions](../src/descriptions/episode1_rooms.lua)
are another existing source: reuse their wording when a world Look describes
the same object, rather than inventing conflicting versions.

## Authoring locations

| Category | Edit | Runtime integration |
| --- | --- | --- |
| Close-ups | `descriptions/episodeN.language.json` | `scripts/compile_descriptions.py` builds `src/descriptions/data.lua` |
| World Looks | `src/descriptions/episode1_world_objects.lua`: fixed and changing-state definitions | `src/descriptions/world_catalogues.lua` registers catalogues; `world_looks.lua` handles state and speech |
| Movies | `src/cutscenes/tracks/language/episodeNN/movie.mp4.ad.srt`; dialogue intervals in `src/cutscenes/tracks/dialogue.lua` | `src/cutscenes/tracks.lua` loads content; `runtime.lua` owns playback |
| In-engine scenes | `src/cutscenes/episode1.lua`: `timelines`, `groups`, `actions`; timed text in `src/lang/en.lua` | `src/cutscenes/registry.lua`, `scene.lua`, `scene_policy.lua`, `actions.lua` |
| Journal photos | `descriptions/journal_photos.en.json`; slot identities in `journal_photo_slots.json` | Separate generated catalogues and `src/hud/journal_photos.lua` |

`N`, `NN` and `language` are naming conventions, not literal filenames. Current
general authored content is Episode 1, with close-ups also available for
Episode 2. The [Episode 2 inventory](episode2-inventory.md) records the measured
workload and the scope of offline close-up verification.
Registration instructions are in each category guide; creating a file does not
necessarily register it.

## Rules shared by every category

Read [Evidence and live-test boundaries](evidence.md) before extracting packages
or planning a live capture. It distinguishes tracked tools from local-only
dependencies and research caches.

- Use the [Life is Strange Wiki](https://life-is-strange.fandom.com/wiki/Life_is_Strange_Wiki)
  as a reference for episode transcripts, scene context, characters, objects
  and alternate branches. See [how to use the wiki](evidence.md#wiki-reference)
  alongside remaster evidence; it is useful across all description categories.
- Describe observed frames or exported artwork. Asset names and scripts can
  identify a subject or branch but are not evidence of what is visible.
- Respect what the player knows **at that moment**. A canonical name is still a
  spoiler before introduction. Preserve accepted anonymous descriptions, such
  as the man and dog in Episode 1's ending. Do not rewrite accepted neighbouring
  prose while extending another episode.
- Preserve existing descriptions, cue times, dialogue protection, rereading,
  language gates, rewind handling and speech ownership during refactors.
- Review images and captures yourself; never ask the user to inspect them
  visually. Give them the proposed text and any uncertainty to judge.
- Keep narration concise and leave room for game dialogue. Verify timing
  against actual playback and the selected language, not animation names or
  wall time. A missing subtitle alone does not establish silence.
- Keep extracted game assets, captures, saves, private paths and drafts under
  ignored `artifacts/`. Track reviewed prose, identifiers, hashes, tooling and
  small reports. Remove regenerable bulk when no longer needed, preserving
  necessary evidence and rollback receipts.
- Ask before **any game launch**, including isolated-profile tests. A previous
  task's permission does not authorize this task. Offline checks need no launch.
- Before approved live work, recover the proven profile-isolation, entry and
  shutdown procedure. Do not invoke story movies directly: their owning game
  action must exist. Return through native menus to the main-menu world before
  exiting a loaded scene; direct close is known to crash. If the safe procedure
  is unavailable, stop at offline checks rather than improvise on real saves.

## Verification and handoff

From the repository root, run the category's checks, then:

```powershell
python -m unittest discover -s tests
lua tests/lua/run.lua
python scripts/compile_descriptions.py --check
python scripts/compile_descriptions.py --records descriptions/journal_photos.en.json --output src/descriptions/journal_photos_data.lua --check
python scripts/compile_photo_slots.py --check
```

Use Lua **5.4**. If it is not on PATH, locate an existing executable and use its
explicit path. The Windows lexical test defaults to
`artifacts/lua-5.4.7/luac54.exe`; set `LIS_LUAC` to an existing Lua 5.4 compiler
when testing a worktree without that local tool directory. The guides and tests
are tracked; private captures and built tools may not exist in a fresh clone.
Do not claim live verification from a fake-controller test or inventory count.

Preservation fixtures pin accepted content and compiled policy data. Do not
regenerate them merely to make a refactor pass. Review intentional prose/timing
changes before updating their expectations. Update the player README/changelog
for player-facing changes; internal relocation is not a new narration feature.

Report the branch, tests, outstanding live checks and whether anything was
installed or packaged. A clean worktree is not integration into the primary
checkout. Never overwrite a distributed ZIP silently. Private memory and ignored
artifacts are not substitutes for this tracked guide.
