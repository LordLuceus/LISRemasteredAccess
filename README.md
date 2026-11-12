# LIS Remastered Access (early development)

A screen-reader accessibility mod for *Life is Strange Remastered*, ported from
LISAccess for the original game. Automatic walking builds on the remaster's
native navigation system.

**Current state: early.** Speech and braille, menu narration, the object scanner,
automatic walking, dialogue choices and the scene-specific assistance described
below are implemented. Coverage is still incomplete.

## Installing the tester package

This package is for the **Windows Steam version of Life is Strange Remastered**,
not the original Life is Strange or Before the Storm Remastered. It targets Steam
build **11330282**. Other stores, game builds and operating systems have not been
verified. Windows 10 or 11, 64-bit, is required. Install the current
[Microsoft Visual C++ x64 runtime](https://aka.ms/vs/17/release/vc_redist.x64.exe)
if it is not already installed.

1. Close the game and extract the ZIP to a temporary folder.
2. In Steam, open the game's Properties, Installed Files, then Browse. Open
   `LIS`, then `Binaries`, then `Win64`. This folder contains
   `LiS-Win64-Shipping.exe`.
3. **If `dwmapi.dll` or a folder named `ue4ss` already exists there, stop.** Ask the
   maintainer about updating or combining mods rather than overwriting another
   installation.
4. Copy **the contents of the package's `files` folder** into `Win64`: `dwmapi.dll`
   and the `ue4ss` folder. Do not copy the enclosing `files` folder itself.
5. Start your screen reader, then launch the game normally through Steam. Startup
   can take about a minute; the first menu announcement is **Click To Start**.

No development tools, Python or test launcher are needed to play. The package
does not include game assets and does not supply or replace save files.
The game continues to save your progress normally. Back up your own saves before
testing, especially if continuing an existing playthrough.

For a fresh installation made using these instructions, uninstall with the game
closed by removing the `dwmapi.dll` and `ue4ss` folder you copied. Do not remove
those if you subsequently added other mods to them; ask for help instead.

### What to test and report

Try menus, scanner navigation, interactions and repeated conversations using your
usual input device. Report the episode, scene, selected object or dialogue,
exact announcement, and keyboard or controller used. Include the package version
from `package-manifest.json`.

After a failure, copy `ue4ss/UE4SS.log` from the installation folder **before
launching the game again**. Send it privately to the maintainer: it can contain
local paths and dialogue spoilers. Do not post saves or crash dumps publicly.

Episodes 1–3 have been completed with the mod; early Episode 4 interactions have
also been tested. This is not a promise of full coverage through the ending.
See the limitations in the relevant sections below. The pool guard bypass is
**on by default**; F3 during his patrol lets you turn it off.

Third-party terms and source availability are described in
[Third-party licences](THIRD-PARTY-LICENSES.md). [The changelog](CHANGELOG.md)
records player-facing changes.

## Playing with the mod

Launch the game from Steam as usual. Once the mod is installed it is active on
every launch. Scanning and narration work alongside the game's normal controls;
automatic walking and interaction shortcuts act when requested. The game saves
normally; the mod does not edit your save files.

- At the title screen it says **Click To Start** once the game accepts a key.
- In the main menu and settings it reads the highlighted option as you move.
  Menus move with **W** and **S**, the arrow keys, the D-pad or the left stick.
- Settings read their name and current value, such as "Vsync, On" or
  "Master, 80 percent". Changing a value with **A** and **D** reads just the
  new value. **Enter** on Gamma opens the gamma screen, which reads the game's
  instruction and the current level.
- The Episodes screen reads the episode and the highlighted option, and the new
  episode as you switch with **A** and **D** or the arrows.
- Dialogue choices remain readable when you speak to someone again, with the
  buttons for your active input device. Home repeats the current choices. If a
  keyboard choice has changed before it can be selected, the reader asks you to
  listen to the current answers rather than choosing an old one.
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
| Home | D-pad up | Read the current close-up view again, or describe the selected world object with fresh distance and direction |
| Ctrl+Home | Hold left-stick click, then D-pad right | Repeat the last announcement |
| Shift+Home | D-pad down | Walk to the selected object; press again to stop |
| F | Left-stick click | Turn toward the selected object |
| 1 to 4 | Face buttons | Answer a dialogue choice, or use the focused object's actions, as announced |
| F1 | Hold left-stick click, then D-pad up | Help: the mod's keys for your device |
| F2 | Hold left-stick click, then D-pad left | Preview the control and pool-guard cues and say what they mean |
| F3 | Hold left-stick click, then D-pad down | During the pool guard's patrol (Episode 3): turn hiding from him on or off |
| F4 | Hold left-stick click, then click the right stick | Room filter on or off: off lists every object nearby, for a room the filter misses |

An object is read with its distance, direction from where you are facing, height
when it is more than 1.5 metres above or below, and its place in the list, for
example "Mail, 1.5 metres, ahead, 3 of 38". Objects with the same name get
letters ("Door, A", "Door, B") that stay with the object as you move. The
selection stays on the same object when the order changes.

Scanner movement commands work only in play; the D-pad navigates menus normally.
The left-stick chords for help, repeat and sound preview also work in menus and
cutscenes. These chords do not consume the buttons: the game may still move its
highlight or perform its usual action.

### Rooms

Indoors, the scanner lists only the room you are in, plus its exits and the
doors that lead out of it, including ones you have just come through, such as
the sliding door back in from the garden. A room reached through an open
connection can be listed as a way, such as "Way to the bathroom". A listed
door represents its own opening, not every entrance to that room. For example,
the garage's eastern entrance stays available while the hall door is locked.
Autowalk follows the chosen entrance rather than switching back to the hall.
Look and Test door entries remain available; their presence does not mean the
door is passable. Ways refresh
after movement or within a few seconds, including when none were found.
Arrival at a room way checks the actual room, not just distance to its doorway.
The garage entry, return and near-hall boundary were verified in game with the
filter on. Coverage still depends on the game's navigation and room geometry;
not every connection is guaranteed. Opening/closing-door transitions and
performance in larger scenes have not yet been verified.
The first time you use the scanner in a room, it tells you how many objects
there are in all when the filter is hiding some ("21 in all; F4 shows
them."). F4 (or hold the left stick and click the right stick) switches the
filter off and lists everything nearby; press it again to switch it back on. When you cross into another room the
mod says its name ("Corridor.", "Max's room."). Doors are named for the room
they lead to ("Science room door"). Places built as one open space, such as the
pool, the junkyard and the campus, are listed whole.

### Autowalk

Shift+Home (or D-pad down) walks Max to the selected object, using the game's own
paths and the spot the game expects you to stand at. If the direct way crosses a
closed door, it goes around through an open one and tells you so. It says when it
starts and when you arrive. Moving yourself (W, A, S, D, the arrow keys or the
left stick) or pressing Shift+Home again stops it. If it catches on a corner it
says "Trying again." and carries on; only when Max can't make progress does it
stop and say something is blocking the way. It also stops if the game takes
over, and tells you so.

Walking to an object stops once you are close enough to use it, which for
some objects is a long way off: the truck in the diner parking lot can be
photographed from over 20 metres away, so that is where autowalk takes you.
If even that can't be reached, autowalk says "No way to" the object, takes you
as close as you can get, and says how many metres away it still is.

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

### Helping Chloe shoot (Episode 2, junkyard)

For the first two bottles you tell Chloe where to aim after seeing her miss.
Right after she fires, the mod says where the shot went ("Chloe's shot went
wide, to the left of the bottle."); rewind and choose the direction. It does
not name the answer.

For the third and fourth bottles you choose what Chloe shoots by aiming the
camera at it. While you choose, the scanner lists only the things she can
shoot (the blue plank, monitors, barrel and rim; then the gas tank, bumper,
windshield and tire). Select one with Page Up or Page Down and press F to turn
the camera to it; the game then names it ("Rim. 1, Shoot.") and 1 shoots. The
mod does not say which one works.

### The principal's office (Episode 3)

After Chloe blows the office door, select "Other side of the principal's door"
in the scanner and autowalk: Max walks through the doorway. After you rewind,
the mod says "You can unlock the door now." when the door can be opened from
the inside; face the door with the scanner and F if its prompt does not come
up. Do not use the "other side" entry after the rewind: the door is closed
again.

### Hiding from the guard at the pool (Episode 3)

After you and Chloe leave the water, the scanner lists "Way to the hall".
Autowalk there: the mod says "Leave The Swimming Pool" with its key. Take it,
and the guard comes in and patrols the room.

By default the guard can't see you, so you can walk out once he has gone.
The mod says so when his patrol starts. This bypass applies to this pool patrol,
not to other dangers or later scenes.

To hide from him yourself, press F3 (or hold the left stick and press D-pad
down) during the patrol. Then:

- the "spotted" sound means his view will reach you within a few seconds;
- "Hiding spot" in the scanner is a place he won't see for the next ten
  seconds; autowalk there;
- the calmer "hidden" sound means you're out of his view again.

Press F3 again to stop him seeing you.

### Focusing a photo

Some scenes ask you to bring an old photo into focus (the first comes at the
end of Episode 3, in Max's room). The mod reads the game's instructions. There
are two pictures to focus, each with its own control: A and D (or the left
stick) for one, the left and right mouse buttons (or the right stick) for the
other. Each has its own tick: a soft wooden click slightly to the left for A
and D, a brighter metallic tick slightly to the right for the mouse buttons.
A tick speeds up as its picture sharpens, and is fastest at the sweet spot.
The controls turn round like a dial, so if the ticks slow down you have gone
past it. Stop each control at its fastest ticking.

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

### Garage combination lock

The garage padlock announces its displayed code when you open code entry.
Initially no wheel is selected; the mod says so rather than assuming the first.
After you select a wheel, its current value is followed by its position, for
example "0, digit 1 of 4." Changes are announced as you edit. Opening the lock
does not read instructions; press **F1** for lock help, using the active device.

| Keyboard | Action |
| --- | --- |
| A / D | Select the previous / next wheel; selection wraps at the ends |
| W / S | Change the selected digit |
| Home | Read the full entered code and current selection |
| Enter | Submit through the game's normal code check |
| Escape | Cancel and return to play |
| F1 | Read the lock's controls for the active device |

On a controller, use the **D-pad or left stick**: left/right selects a wheel,
and up/down changes its digit. **A** applies and **B** goes back. The existing
help command—hold left-stick click and press D-pad up—also reads lock help.
The game still receives that Up input and may change the digit. Its announcement
does not interrupt help; the reader keeps the updated value. Release Up before
resuming normal edits. Use F1 if you want help without sending Up to the game.

Use WASD here on keyboard, not the arrow keys. The game keeps its normal voiced feedback
for an incorrect code. Reopening starts with the game's fresh digits. The mod
neither reveals nor enters the solution, and the crowbar alternative is unchanged.

Keyboard editing, submission of an incorrect code, cancellation and reopening
have been tested in the game. Controller bindings above follow the player's
reported controls; mouse/controller operation and successful puzzle completion
have not been covered by the agent-run native tests.

### Dialogue choices

When answers appear in a conversation, the mod reads them with their keys:
"Choose: 1, You're asking me?, 2, I did know..." Major choices (the ones the
game marks with its own music) start with "Major choice". Each list is read once
after its updates settle. Press the number to answer; Home reads the current list,
while Ctrl+Home repeats the last announcement. On a controller the face button
for each answer is named instead, and pressing it works as usual.

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

When you open a picture, letter or other close-up, the mod first reads a visual
description when one is available. If the picture also has text, the announcement
ends with **Has text version.** Use the game's **Read** action—Enter on keyboard,
A on controller—to enter Read mode and hear that text. Escape or B returns to
the picture and its description. Pictures without text keep their automatic
descriptions; no extra description shortcut is needed.

**Home**, or **D-pad up**, rereads the current view: the description in picture
mode, the text in Read mode. **Ctrl+Home** (on a controller, hold the left-stick
click and press D-pad right) instead repeats the last announcement, including
help. F5 is no longer used. Page controls remain native, with page position spoken
last. F1 gives the controls without adding instructions to each opening readout.

**Picture descriptions are still in development.** The current English catalogue
covers only a small selection of Episode 1 pictures, not the whole episode. A
picture with neither text nor a description says so. Automatic and on-demand
descriptions work with either input device. D-pad left/right retain the game's
page controls; outside the viewer, D-pad up still reads the scanner selection.
Description-first reading, native Read mode and contextual rereading have been
tested in game. Wider picture coverage and multipage behavior remain unverified.

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

Coverage outside the screens described here is incomplete, including the
keybinding editor and other Extras screens. The Choices screen is covered below.


### The Choices screen

Extras > Choices (and the screen after an episode) compares your choices with
everyone else's. On opening, and whenever the episode, the page or the stats
change, the mod says where you are ("Chrysalis, Major choices, World stats"),
then the first decision.

| Keyboard | Controller | Action |
|---|---|---|
| Up / Down | D-pad up / down | Previous / next decision, with its outcomes and percentages |
| Left / Right | as in the game | Major / minor choices |
| Space | Y | Switch between World and Friends stats |
| Home | | Read the current decision again |

Each outcome is read with the percentage the game shows and "your choice" for
the one you picked. Friends stats come from Steam friends who have played; with
none, every outcome reads 0 percent.

## Known limitations

- Autowalk can fail around obstacles or in places the story has not opened.
  The room filter can miss connections; F4 exposes the full nearby scanner list.
- Photos and Places in the journal are not narrated. Character selection can
  skip grid entries; open a profile and use Left and Right as described above.
- Visual descriptions currently cover only a small selection of Episode 1
  close-ups, in English. Other pictures and cutscenes are not described.
  There is no full rewind-history reader; ordinary rewind controls still work.
- Controller names use Xbox/XInput button labels. Other controller layouts have
  not been verified.
- Coverage in later episodes is not yet fully tested. Please report inaccessible
  sequences rather than assuming every puzzle or timed event is supported.

## Speech and braille

Announcements go through Prism from inside the game, using NVDA, JAWS or another
running screen reader, with Windows speech as the fallback. Braille is sent to
the reader's braille display where it supports one. Text is spoken literally.
Screen-reader calls run on their own thread to avoid blocking the game while
speech is being delivered.

## Development launcher

**For source developers only; not included in the tester ZIP.** This loads a test scene directly in a
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

## For source developers: building and deploying

Requirements: Visual Studio 2022 (C++ build tools), CMake 3.24 or later, Python 3.

```
cmake -S native -B artifacts/build-native -G "Visual Studio 17 2022" -A x64
cmake --build artifacts/build-native --config Release
artifacts\build-native\Release\speech_smoke.exe --quiet
python scripts\deploy_probe.py
```

The smoke test checks Prism's backends and literal SAPI text without speaking.
Deployment copies `src/` and both native DLLs into the game's UE4SS Mods folder.
It requires the game to be closed, verifies every installed file's hash before
replacing it, and removes installed modules whose source was renamed or deleted.

### Packaging a tester build

`scripts/package_release.py` creates a full **fresh-install** tester ZIP without
touching the installed game or launching it. It uses the built Release DLLs, the
pinned upstream UE4SS ZIP, the six existing processed WAVs, and the pinned Prism
source archive. It does not generate new sounds or compile native code. The local
defaults match the paths used by the build and deployment tools above; individual
input paths can be overridden (see `--help`). For worktrees, `--inputs-root` can
point to the checkout holding these inputs.

Pandoc is required for packaging, not for playing. The script finds it on PATH or
in the normal Windows installation folders; `--pandoc` selects another location.
It generates accessible HTML from the Markdown, validates table headers and links,
and packages licences and the required Prism source alongside the mod.
The first preflight also downloads the checksum-locked public dependency notices
into `artifacts/release-notice-cache/`; later runs reuse that cache. A missing or
changed notice input stops packaging rather than silently omitting it.

After reviewing this README and confirming the release inputs, check them first,
then create the archive:

```powershell
python scripts/package_release.py --version test-2026-11-11 --preflight
python scripts/package_release.py --version test-2026-11-11
```

Use a new version label for a subsequent build. Packaging requires a clean source
tree and refuses to overwrite an existing archive. Output goes to
`artifacts/releases/` by default. `package-manifest.json` records the source commit,
input binary hashes and every supplied file; the adjacent verification report gives
the final ZIP's hash. No local installation manifest, saves, logs, raw PCM, debug
symbols, development probes or game assets are copied. A failed archive remains
marked `.partial`, never as a ready-to-share ZIP.

Offline packaging checks, including deliberately malformed inputs:

```powershell
python tests/test_release_package.py
```

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
names. The controller bindings are listed in the scanner and reader sections above.

Offline tests for this logic, which need no game:

```
artifacts\lua-5.4.7\lua54.exe tests\lua\run.lua
artifacts\lua-5.4.7\lua54.exe tests\lua\uncached_choices.lua
artifacts\lua-5.4.7\lua54.exe tests\lua\choice_startup.lua
```

The installation is pinned to Steam build 11330282 and experimental UE4SS
3.0.1-1181-g83330635, with a measured virtual-table correction in
`compatibility/VTableLayout.ini`. The speech module links against that exact
loader's exported functions. The separate `lisr_reflection.dll`, built by default
and included by deployment, reads dialogue properties through that same pinned
loader. It rejects other loader binaries; the existing reader remains the fallback
if the helper cannot load or read a view. Compatibility with other loader versions
has not been established. It is not a general installer. The loader's
UE4SS-settings.ini has every optional hook off except HookEngineTick,
HookProcessInternal, HookProcessLocalScriptFunction and
HookUObjectProcessEvent; the last three let the mod listen to the game's own
scripts, which the dialogue choice reader needs. HookLoadMap must stay off.

For a developer installation with its local installation manifest, close the game
and run `scripts/rollback_ue4ss.ps1`. It checks hashes before changing anything and
never restores old saves. Tester-package removal is described at the top of this guide.

## Layout

- `src/`: the Lua side, installed as the UE4SS mod `LISRemasteredAccess`.
  - `main.lua`: entry point. `core/`: speech, localisation, key names.
  - `lang/`: announcement catalogs. `nav/`: autowalk and door-aware routing.
  - `dev/`: read-only development probes, not player features.
- `tests/lua/`: offline tests for game-independent logic.
- `native/`: the C++ speech/braille and dialogue-property modules. `third_party/ue4ss/` holds the
  loader's Lua headers at the pinned commit, with their licences and hashes.
  `third_party/reflection-source.json` records the additional public declarations
  and pinned fmt headers; their MIT notice is in `third_party/LICENSE-fmt`.
- `scripts/`: launcher, deployment, test runner, rollback and log tools.
- `NAVIGATION_FEASIBILITY.md`: the evidence behind choosing the remaster.
- `CHANGELOG.md`: player-facing changes.

Private game data, test profiles, logs, downloaded tools and build output live
in `artifacts/` and are excluded from Git and tester packages.
