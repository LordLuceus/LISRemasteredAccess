# Changelog

Player-facing changes, newest first.

## 2026-10-25

### Menus
- The arrow keys now move through menus like W, A, S and D. Before, they did
  nothing there.
- The Episodes screen reads the episode and the highlighted option, for example
  "Episode 2: Out of Time, Continue", and announces the new episode as you switch.
  It no longer wrongly says "Click To Start" when opened.
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
