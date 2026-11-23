# Offline evidence and live-test boundaries

[Authoring index](README.md)

This checkout contains extraction source, not the proprietary game assets or a
preconfigured analysis machine. Establish the installed game/build and available
tools before repeating old research. Do not interpret a missing ignored cache
as missing game content.

## Wiki reference

Use the [Life is Strange Wiki](https://life-is-strange.fandom.com/wiki/Life_is_Strange_Wiki)
alongside the shipped game data and captures. Episode transcripts, such as the
[Episode 1 script](https://life-is-strange.fandom.com/wiki/Episode_1:_Chrysalis_-_Script),
help establish scene order, dialogue, context and alternate outcomes. Character
and object pages can clarify details that are difficult to identify in a frame.
Record the relevant page in private review notes so another author can follow
the reasoning rather than rely on memory.

Cross-check the applicable story branch. The remaster's actual image and
playback remain authoritative for visible details and cue timing; a transcript
or an original-game screenshot does not establish either. Wiki pages can also
reveal later identities and events: use only what the player knows at the scene
being described. Research identifying a character is not permission to replace
an accepted anonymous caption with their name.

## Available source tools

- [export_closeups.py](../scripts/export_closeups.py): explicit-path episode
  texture inventory/export, image hashes, optional bounded package inspection.
  The [close-up guide](closeups.md#extract-and-review-a-new-episode) lists its
  external prerequisites and flags.
- [CloseupExport](../tools/closeup-export/Program.cs): CUE4Parse helper. Despite
  its name, `inspect: true` requests serialize package exports instead of
  decoding images, so it can inspect map actors and authored data definitions.
- [compile_descriptions.py](../scripts/compile_descriptions.py): reviewed-caption
  validation, aggregate output and optional source-image coverage verification.
  It does not discover game assets or author prose.
- [compile_photo_slots.py](../scripts/compile_photo_slots.py): journal-pair
  identity import/validation, not generic close-up extraction.

For property-only inspection, use the existing verified CUE4Parse dependency
directory and build `tools/closeup-export/CloseupExport.csproj` with `DependencyDir`
set to it. Put both intermediate and output directories under a new ignored
artifact directory, not the source tree. The exporter wrapper shows the exact
`dotnet build` and `dotnet exec` argument layout and environment settings. Its
regular mode also exports picture candidates, so use the helper directly when
only a small map/property inspection is needed.

The helper accepts three positional arguments: Paks directory, request JSON,
and output JSONL receipt. A bounded request list can look like this (create the
output directory first):

```json
[
  {
    "member": "LiS/Content/Maps/Episode02/Sequence01/E2_1A_MaxRoom_LD.umap",
    "output": "artifacts/episode2-evidence/max-room.json",
    "inspect": true
  }
]
```

Use the dependency directory's matching `AnimExtract.runtimeconfig.json` and
`AnimExtract.deps.json` with `dotnet exec`, as the wrapper does. Inspect **every**
receipt's `status` and error: the helper can record a per-package failure while
the process itself exits successfully. Preserve a compact source/hash inventory
and filtered evidence before pruning large regenerable full-map exports.

A pak member lister such as a locally available `repak` can generate the
`*.index.txt` inputs. Verify its installed CLI before calling it; use byte-safe
Python subprocess output for binary extraction rather than PowerShell text
redirection. `ffprobe` measures movie duration without playback. Existing local
native/Blueprint research scripts under `artifacts/` are not shipped tools:
inspect them before reuse, including their paths and any launch/write effects.

## What must be established, not guessed

- **Pictures:** native ShowPicture identity, ordered pages, actual texture,
  state variants, aliases and existing Read-mode text.
- **World Looks:** streamed map plus full actor identity, enabled action branches,
  picture/camera subtype, trigger and state facts, visible before/after result.
- **Movies:** actual URL/filename, story owner, language, video position and
  game-driven audio intervals. Do not assume the MP4's own audio is complete.
- **Scenes:** exact Matinee actor, director/camera tracks, branch ownership,
  measured visible event, voice intervals and actual playback position.

Static metadata is not proof that a branch is reachable, and screenshots alone
do not prove which fact or clock drives it. Record both when live work is needed.
Use the game data to decide what to inspect, not to invent unseen captions.

## Live work is separately authorized

Ask before launching or controlling the game. Review the selected test script
before running it; many scripts in `scripts/` send keys or launch profiles and
are not offline checks. Keep desktop helpers hidden and do not poll by spawning
visible consoles. Never ask the user to inspect frames visually.

Recover the successful entry and shutdown procedure from the current project's
test receipts. Validate that the selected disposable-profile launcher really
isolates or backs up/restores the **actual** save/config locations. Hash those
files before and after; an arbitrary command-line profile flag is not proof of
isolation. Existing `scripts/run_profile_probe.ps1` is a launcher to inspect,
not blanket authorization to execute it or evidence that every scene is safe.

Coordinate through the primary checkout's `artifacts/runtime/operator-owner`
claim before game control or deployment; use a unique owner identity and do not
take over an existing claim. `scripts/deploy_probe.py` already resolves that
canonical owner even when called from a worktree. It checks for a running game;
ask the user to close it instead of terminating it.

Return to the native main-menu world before exiting a loaded scene. Direct
closing and unowned direct movie playback have caused native crashes. If a
proven safe entry/exit route cannot be recovered, report the missing procedure
and stop at offline verification. Do not fabricate a confident live-test result.
