# LIS Remastered Access (early development)

A screen-reader accessibility mod for *Life is Strange Remastered*, ported from
LISAccess for the original game. The remaster's own navigation system makes
reliable automatic walking possible, which the original never achieved.

**Current state: early.** Speech and braille work in-game, and the title screen
and main menu are narrated. There is no object scanner, dialogue reading or
general autowalk yet.

## Playing with the mod

Launch the game from Steam as usual. Once the mod is installed it is active on
every launch. It only reads the screen: it never moves Max, loads scenes or
writes to your saves.

- At the title screen it says **Click To Start** once the game accepts a key.
- In the main menu and settings it reads the highlighted option as you move.
  Menus move with **W** and **S** (or the D-pad or left stick); the arrow keys
  do nothing there.
- Settings read their name and current value, such as "Vsync, On" or
  "Master, 80 percent". Changing a value with **A** and **D** reads just the
  new value. **Enter** on Gamma opens the gamma screen, which reads the game's
  instruction and the current level.
- Saved games read each slot's name, episode, chapter and date, or "New game".
- Confirmation dialogs read their question and how to answer, such as "Quit the
  game? Enter to confirm, Escape to cancel" (A and B on a controller).
- **Home** rereads what is on screen now, for example the current countdown.

Not narrated yet: episode and chapter selection, Extras, the keybinding editor
and the pause menu.


## Planned order

1. Foundation: speech and braille, keys, localisation. *(Speech, braille and localisation done; controller bindings pending.)*
2. Menus: title screen, main menu, settings, saved games and confirmations *(done)*; episode selection, Extras and the pause menu next.
3. Object scanner and autowalk, using the game's own interaction list and
   navigation, with automatic detours around closed doors.
4. Dialogue choices and prompts.
5. Journal, text messages, rewind and the remaining features.

## Speech and braille

Announcements go through Prism from inside the game, using NVDA, JAWS or another
running screen reader, with Windows speech as the fallback. Braille is sent to
the reader's braille display where it supports one. Text is spoken literally.
Screen-reader calls run on their own thread, so a stalled reader cannot freeze
the game.

## Development launcher

This is for testing, not for playing. It loads a test scene directly in a
throwaway copy of your saves.

Close the remaster, then run `Start-NavigationPrototype.cmd`. Choose the house
or the junkyard with the arrow keys, optionally check **Run the short navigation
test**, then choose **Start isolated test**. Steam must be available.

Each launch copies your current saves and settings into a fresh throwaway profile
under `artifacts/`, and checks afterward that your real saves are unchanged.
Keep the launcher window open while playing; it runs those checks, and it speaks
announcements itself only if the in-game speech module failed to load.

| Key | Action |
| --- | --- |
| Home | Repeat the last announcement. |
| F8 | Cancel the pending or running navigation test. |
| F10 | Return to the main menu through the game's own function. |

After the **Main menu** announcement, use Alt+F4 to exit. Closing directly from
a loaded scene can trigger the game's existing shutdown crash; returning to the
menu first avoids it. That is a workaround, not a fix.

## Building and deploying

Requirements: Visual Studio 2022 (C++ build tools), CMake 3.24 or later, Python 3.

```
cmake -S native -B artifacts/build-native -G "Visual Studio 17 2022" -A x64
cmake --build artifacts/build-native --config Release
artifacts\build-native\Release\speech_smoke.exe --quiet
python scripts\deploy_probe.py
```

The smoke test checks Prism's backends and literal SAPI text without speaking.
Deployment copies `src/` and the speech DLL into the game's UE4SS Mods folder.
It requires the game to be closed, verifies every installed file's hash before
replacing it, and removes installed modules whose source was renamed or deleted.

## Localisation and key names

The game's own labels are already translated by the game. The mod's own
announcements live in `src/lang/en.lua`. To translate them,
copy it to `src/lang/<code>.lua` (for example `fr.lua`, or `pt_br.lua` for pt-BR)
and translate the values, keeping the keys and `{placeholders}`. The mod follows
the game's language setting: it tries the exact language, then the base
language, then English, so a partial translation still works. A missing
English string is spoken as a marked placeholder and logged, never guessed.

Key names in announcements are filled in when spoken, for the input device the
game says is in use: a connected but unused controller still gives keyboard
names. Controller bindings for the mod's commands are not assigned yet.

Offline tests for this logic, which need no game:

```
artifacts\lua-5.4.7\lua54.exe tests\lua\run.lua
```

The installation is pinned to Steam build 11330282 and experimental UE4SS
3.0.1-1181-g83330635, with a measured virtual-table correction in
`compatibility/VTableLayout.ini`. The speech module links against that exact
loader's exported functions. It is not a general installer.

To uninstall, close the game and run `scripts/rollback_ue4ss.ps1`. It checks
hashes before changing anything and never restores old saves.

## Layout

- `src/`: the Lua side, installed as the UE4SS mod `LISRemasteredAccess`.
  - `main.lua`: entry point. `core/`: speech, localisation, key names.
  - `lang/`: announcement catalogs. `nav/`: autowalk and door-aware routing.
  - `dev/`: read-only development probes, not player features.
- `tests/lua/`: offline tests for game-independent logic.
- `native/`: the C++ speech and braille module. `third_party/ue4ss/` holds the
  loader's Lua headers at the pinned commit, with their licences and hashes.
- `scripts/`: launcher, deployment, test runner, rollback and log tools.
- `NAVIGATION_FEASIBILITY.md`: the evidence behind choosing the remaster.
- `CHANGELOG.md`: player-facing changes.

Private game data, test profiles, logs, downloaded tools and build output live
in `artifacts/` and are excluded from Git. This is not a redistributable release.
