# Changelog

Player-facing changes, newest first.

## 2026-10-26

### In play
- Tutorial prompts are read when they appear, and Ctrl+Home repeats them. The
  classroom prompts about dragging the mouse to look at the photo or take a
  selfie now describe the mod's keys instead. On a controller, prompts name the
  stick, trigger or bumper the game shows as a picture.

## 2026-10-25

### In play
- Facing: F (or the left-stick click) turns toward the selected object and
  corrects its aim until the game focuses it.
- Interactions: whenever the game focuses an object you hear its name and its
  actions, for example "Journal. 1, Look, 2, Read." Press 1 to 4 to use them, or
  the face buttons on a controller, which are named instead of numbers.
- F1 (hold the left-stick click and press D-pad up) gives help with the mod's
  keys for the device you are using.
- F2 (hold the left-stick click and press D-pad left) plays the next sound cue
  and says what it means.
- Fixed: the game could crash at random while the mod was running.
- Autowalk: Shift+Home (or D-pad down) walks to the selected object, going around
  closed doors, and says when you arrive. Moving yourself or pressing it again
  stops it. In the opening nightmare it takes you to the lighthouse.
- Soft tones play when a cutscene takes control and when you get it back. The
  scanner and autowalk wait while the game has control.
- Fixed: the game could crash during cutscenes.
- New scanner: Page Up and Page Down (or D-pad left and right) select objects you
  can interact with, nearest first, with distance, direction and height, for
  example "Mail, 1.5 metres, ahead, 3 of 38". In the opening nightmare it lists
  the lighthouse. Home (or D-pad up) describes the selected object again.
- Ctrl+Home repeats the last announcement (on a controller, hold the left-stick
  click and press D-pad right). Home now describes in play and still rereads
  menus.

### Menus
- The pause menu is narrated: its options, its settings screens and its
  confirmations, such as "All unsaved progress will be lost. Do you still want to
  exit? Enter to confirm, Escape to cancel".
- The arrow keys now move through menus like W, A, S and D. Before, they did
  nothing there.
- The Episodes screen reads the episode and the highlighted option, for example
  "Episode 2: Out of Time, Continue", and announces the new episode as you switch.
  It no longer wrongly says "Click To Start" when opened. Locked episodes say why,
  for example "Finish Previous Episode to Play".
- The chapter list (through Collectible Mode) reads the selected chapter and the
  number of photos collected there.
- The mod is now active on every normal Steam launch. Before, it only ran in
  development test sessions, so a normal launch gave the unmodded game.
- The title screen says "Click To Start" once the game accepts a key, and the
  main menu reads the highlighted option as you move with W and S.
- Settings read each row's name and current value, for example "Vsync, On" or
  "Master, 80 percent". They previously read as "Unlabelled option". Changing a
  value with A and D reads only the new value.
- The gamma screen (Enter on Gamma) reads the game's instruction, naming the
  stick on a controller, and the current level.
- Saved games read each slot's name, episode, chapter and date, or "New game".
- Confirmation dialogs, such as Exit and Apply Settings, read their question
  and how to answer: "Enter to confirm, Escape to cancel", or A and B on a
  controller. The Apply countdown is spoken once instead of every second.
- Home rereads what is on screen now, so it gives the current countdown.
- Game text no longer adds a stray comma after a full stop, and button icons in
  game text are spoken by name instead of being skipped.

### Foundation
- Speech and braille go through your screen reader (NVDA, JAWS and others),
  falling back to Windows speech.
- The mod follows the game's language for its own announcements, falling back
  to English, and names keys for the device you are using.
