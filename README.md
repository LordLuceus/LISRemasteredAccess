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
  Menus move with **W** and **S**, the arrow keys, the D-pad or the left stick.
- Settings read their name and current value, such as "Vsync, On" or
  "Master, 80 percent". Changing a value with **A** and **D** reads just the
  new value. **Enter** on Gamma opens the gamma screen, which reads the game's
  instruction and the current level.
- The Episodes screen reads the episode and the highlighted option, and the new
  episode as you switch with **A** and **D** or the arrows.
- Saved games read each slot's name, episode, chapter and date, or "New game".
- Confirmation dialogs read their question and how to answer, such as "Quit the
  game? Enter to confirm, Escape to cancel" (A and B on a controller).
- **Home** rereads what is on screen now, for example the current countdown.

## In play: the scanner

The scanner lists the objects you can interact with, plus a scene's goal where
the game has nothing to interact with (the opening nightmare's lighthouse),
nearest first. It follows the story: objects appear when the game makes them
available, not before. Exits are listed too, named after the game's own prompt
("Go To The Main Campus, exit"): walk to one with Shift+Home. When you step into
it the mod reads the game's prompt with the key to press ("Go To The Main
Campus, Space"); press Space, or A on a controller, to leave.

Max's thoughts and objectives ("I need to get Victoria out of my way") are read
when they change.

| Keyboard | Controller | Action |
| --- | --- | --- |
| Page Down / Page Up | D-pad right / left | Next / previous object (hold to repeat) |
| Home | D-pad up | Describe the selected object again, with fresh distance and direction |
| Ctrl+Home | Hold left-stick click, then D-pad right | Repeat the last announcement |
| Shift+Home | D-pad down | Walk to the selected object; press again to stop |
| F | Left-stick click | Turn toward the selected object |
| 1 to 4 | Face buttons | Answer a dialogue choice, or use the focused object's actions, as announced |
| F1 | Hold left-stick click, then D-pad up | Help: the mod's keys for your device |
| F2 | Hold left-stick click, then D-pad left | Play the next sound cue and say what it means |

An object is read with its distance, direction from where you are facing, height
when it is more than 1.5 metres above or below, and its place in the list, for
example "Mail, 1.5 metres, ahead, 3 of 38". Objects with the same name get
letters ("Door, A", "Door, B") that stay with the object as you move. The
selection stays on the same object when the order changes.

The controller commands work only in play, so the D-pad still works normally in
menus.

### Autowalk

Shift+Home (or D-pad down) walks Max to the selected object, using the game's own
paths and the spot the game expects you to stand at. If the direct way crosses a
closed door, it goes around through an open one and tells you so. It says when it
starts and when you arrive. Moving yourself (W, A, S, D, the arrow keys or the
left stick) or pressing Shift+Home again stops it. It also stops if something
blocks the way or the game takes over, and tells you which.

Some places have no walking paths from the game, such as most of the
Dormitories lawn. There the mod works out its own way around obstacles, which
can take a moment: you hear "Finding a way to" and the name. If it says "No
route" where you know you can walk, try again from a few steps away or from
another object; please report it, as the log records why. Places the story
hasn't opened yet also say "No route".

In the opening nightmare, select the Lighthouse and walk to it: the scene goes on
when you reach it.

### The cliff nightmare (end of Episode 1)

This scene has no walking paths and only one object, the newspaper at the end,
so the scanner offers a single entry instead: **Guide**. It always points at your
next step along the doe's route, and walking to it with Shift+Home carries on by
itself from step to step ("Next: follow the doe, step 3 of 14"). The newspaper is
listed on its own once you reach it.

- **Hazards** are announced as they happen: falling rocks, the falling tree,
  rolling logs and the lighthouse. If one catches you, the guide says
  "Caught" and tells you to rewind; rewinding back to an earlier step puts the
  guide back on that step.
- **The logs:** the guide takes you into the shelter and waits there. When it
  says the logs have passed, start it again.
- **The lighthouse:** the guide waits for the tree to fall, then goes. You will
  probably be caught at the hole the first time. Hold rewind (R, or the left
  trigger) when the guide says so, and let go when it says "Let go"; the game
  puts you back before the tree, and the guide walks again by itself. If you are
  caught again close to the newspaper, rewind and let go when told once more.
  Running makes no difference here.
- At the newspaper the guide says so: read it to finish the episode.

### When the game takes over

A soft descending tone plays when a cutscene takes control of Max, and an
ascending one when you get control back. While the game has control, the scanner
and autowalk do nothing. Ctrl+Home still repeats the last announcement.

### Facing and interacting

F (or clicking the left stick) turns the camera toward the selected object. It
corrects its aim a few times, as the camera moves, until the game focuses the
object or about two and a half seconds pass.

Whenever the game focuses an object, whether you faced it, walked up to it or
aimed yourself, the mod says its name and the actions the game offers, with the
keys for them: "Journal. 1, Look, 2, Read." on the keyboard, or "Journal. Y, Look,
A, Read." on a controller. Press the number (or face button) to do it. The same
object is not announced again for three seconds.

If facing ends with "Not focused", the game is not offering that object right
now. It can be too low for the camera to reach, or not available yet in the
story: in the opening classroom, the other objects on your desk only open up
after you look at the photo.

### Dialogue choices

When answers appear in a conversation, the mod reads them with their keys:
"Choose: 1, You're asking me?, 2, I did know..." Major choices start with "Major
choice". Press the number to answer; Ctrl+Home repeats the list. On a controller
the face button for each answer is named instead, and pressing it works as usual.

### Tutorial prompts

When the game shows a tutorial prompt, the mod reads it once, without cutting
off other speech; Ctrl+Home repeats it. On a controller the button pictures are
named ("Use the left stick to move", "Hold the left trigger to rewind").

The classroom prompts that tell you to hold the mouse button and drag towards an
action are replaced with the mod's own steps: select the photo (or the camera)
with Page Up or Page Down, press F to face it, then press the announced key for
Look (or Take Selfie). On a controller they use the D-pad, the left-stick click
and the announced button.

### Close-ups

When you look at a letter, poster or notice board, the mod reads the game's
text version of it straight away; you don't need the game's Read button. Things
without a text version, such as photos, say "No text version." Pages are read
as you turn them, with the page number at the end when there is more than one.
Ctrl+Home (on a controller, hold the left-stick click and press D-pad right)
repeats it.

### The journal

Open the journal as usual (Tab or J, or View on a controller) and switch tabs
with Q and E (the shoulder buttons). Each tab announces its name and its first
item. Then:

| Keyboard | Controller | Action |
| --- | --- | --- |
| Up / Down | D-pad up / down | Previous / next item (hold to repeat) |
| Ctrl+Home | Hold left-stick click, then D-pad right | Repeat the last announcement |

- **Diary:** one paragraph at a time, in reading order, then the current
  objective. The page number is read when you change page. Backing out of the
  diary opens the list of days, read as you move.
- **Characters:** the highlighted character as you move through them. A profile
  reads one paragraph at a time. The picker is a grid that can skip people when
  moved by key; open any profile and use Left and Right to go through the rest.
- **Messages:** each contact, with how many messages are unread. A conversation
  starts at the latest message ("Kate, 09/25 10:51 am: Hey Max u around?") and
  Up goes back through older ones. New messages are announced as they arrive.
- **Photos and Places** have nothing to read yet.

On the keyboard the game uses Escape both for Back and for the pause menu, so
leaving a page with Escape can open the pause menu instead; B on a controller
always goes back.

The pause menu, its settings and its confirmations read the same way.

Not narrated yet: Extras and the keybinding editor. In play, nothing beyond the
pause menu is narrated yet.


## Planned order

1. Foundation: speech and braille, keys, localisation. *(Speech, braille and localisation done; controller bindings pending.)*
2. Menus: title screen, main menu, settings, saved games and confirmations *(done)*; pause menu *(done)*; Extras and the keybinding editor later.
3. Object scanner and autowalk, using the game's own interaction list and
   navigation, with automatic detours around closed doors.
4. Dialogue choices and prompts.
5. Journal and text messages *(done)*; rewind and the remaining features.

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
