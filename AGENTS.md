# Repository Guidelines

## Project structure

For any description work, read [Description authoring](descriptions/README.md)
first. It maps close-ups, world Looks, movies, in-engine scenes and journal photos
to their sources, registries, timing rules and checks. Do not infer a workflow
from an episode filename or rely on private agent memory. The classroom is a
linked group in the Episode 1 scene catalogue, not a separate content system.

UE4SS loads the mod through `src/main.lua`. Keep feature logic in the corresponding Lua directory, such as `src/scanner/`, `src/rewind/`, or `src/cutscenes/`. Put shared speech and input handling in `src/core/` and localized interface strings in `src/lang/`.

The Windows speech and reflection DLLs live in `native/src/`. Author close-up and journal photo descriptions in `descriptions/` and follow its README to regenerate the Lua data. Bundled movie descriptions live in `src/cutscenes/tracks/`. Cue audio lives in `assets/audio/`. Use `artifacts/` for local builds and playback captures.

## Build and run locally

From the repository root, use PowerShell with Visual Studio 2022 C++ build tools, CMake 3.24 or later, and Python 3.

```powershell
cmake -S native -B artifacts/build-native -G "Visual Studio 17 2022" -A x64
cmake --build artifacts/build-native --config Release
```

Generate the rewind sounds with `python scripts/generate_rewind_cues.py` only
when that work needs them. Deployment uses `python scripts/deploy_probe.py`
against the configured UE4SS installation and requires the game closed. It
checks DLL exports, tracks and all eight cue WAVs; a source edit is not proof
that its installed build has changed.

Ask the user before launching the game, including isolated-profile tests. Never
terminate their running game or alter real saves for a test. Recover the proven
profile/entry/shutdown procedure first; return to the native main-menu world
before closing a loaded scene. Keep console helpers hidden. Offline tests do
not require a game launch. Do not commit or publish without user authorization.

## Coding style and tests

Follow the surrounding four-space indentation. Use descriptive snake_case Lua module names and keep engine access separate from logic that can run offline. Keep native changes compatible with the C++23 build.

- Run `lua tests/lua/run.lua` with Lua 5.4. Register new feature checks in that runner.
- Run `python -m unittest discover -s tests` for tooling and deployment checks. Name Python test files `test_<feature>.py`.
- After native changes, run `ctest --test-dir artifacts/build-native -C Release --output-on-failure` for speech, reflection, rewind, and movie timing checks.

## Commits and pull requests

Use a lowercase type and an imperative subject, following recent history, for example `fix: preserve queued HUD notices across pause menus`. Use `feat:` for new behavior and `docs:` for documentation. In a pull request, describe what the player experiences and list the checks run. For cue timing or input regressions, include the scene, triggering action, and relevant log lines.
