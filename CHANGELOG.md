# Changelog

Player-facing changes, newest first.

## 2026-10-31

### In play
- Autowalk no longer walks into shut doors that have no named doorway, such
  as the locker-room doors at the pool: it says there is no route instead.
- Getting into the principal's office (Episode 3): the scanner has an entry
  "Other side of the principal's door" that walks Max through the blown door,
  and after the rewind the mod says "You can unlock the door now." when the
  door can be opened from the inside.

## 2026-10-29

### In play
- Autowalk reaches exits whose route stops just short of their centre, such as
  "Go To The Main Campus" outside the dorms in Episode 3.
- The game's save icon is announced: "Saving."
- Autowalk no longer refuses routes through open doorways that have a door
  standing in them, such as Dana's room in Episode 3.
- Autowalk to an object you can already use says "<object> is within reach."
  instead of looking for a route.
- Autowalk says "Arrived" when Max stops right against the object, instead of
  "Something is blocking the way".
- "Major choice" is said only for the game's real major choices, the ones with
  their own music. Small choices such as the jukebox tune, telling Chloe where
  to aim, and the railtracks wires are now read as ordinary choices.
- Helping Chloe aim at the first two bottles: right after she fires, the mod
  says where her shot went, so you can work out where to tell her to aim.
- Helping Chloe shoot in the junkyard: when you choose what she shoots, the
  scanner lists just the targets, and F turns the camera to the one you pick,
  so the keyboard works there too.

## 2026-10-28

### Menus
- The Choices screen (Extras > Choices, and after an episode) is read. Up and
  Down go through the decisions one at a time, each with its outcomes, the
  percentages shown and which one was yours. Space switches between World and
  Friends stats (Y on a controller); Left and Right switch between major and
  minor choices as before.

### In play
- Dialogue choices are read reliably and no longer crash the game. The old
  reader could crash during conversations and sometimes missed answer lists;
  the new one reads each list once, when all its answers are shown. Home now
  repeats the answers too.
- Max's thoughts no longer cut off what is being read, such as a list of
  answers; they are read straight after it.
- The butterfly and new-fact icons are announced: "This action will have
  consequences." and "You learned something useful."
- Object prompts are read even when the game is holding Max, such as the alarm
  at the start of Episode 2: "Cell Phone. 1, Snooze." The number keys work
  there too.
- The cliff nightmare at the end of Episode 1 can be played through. The
  scanner offers one entry, "Guide", which always points at the next step along
  the doe's route; walk to it with Shift+Home and it carries on from step to
  step. It warns you about each hazard, waits with you in the shelter while the
  logs roll past, and tells you when to rewind and when to let go at the
  lighthouse.
- Starting autowalk with Shift+Home says "Walking to" again. It had gone silent
  for every walk.

## 2026-10-27

### In play
- New text messages are announced as they arrive: "New message from Victoria."
  Read them in the journal's Messages tab.
- Prompts to stop an activity are read in full with their key, for example
  "Stop Playing, Space" (B on a controller), instead of just "Space".
- Max's thoughts and objectives are read when they change, for example "I need
  to get Victoria out of my way".
- Exit prompts are read when you walk into an exit, with the key to press:
  "Leave The Girls' Dormitories, Space" on the keyboard, or A on a controller.
- Autowalk works where the game has no walking paths of its own, such as most
  of the Dormitories lawn, where it used to say "No route" to the water pump,
  Samuel and others. It now finds its own way around obstacles; if that takes a
  moment you hear "Finding a way to Water Pump." It still says "No route" when
  the story hasn't opened the way yet.

## 2026-10-26

### In play
- The journal is read. On each tab you hear its name and the first item; Up and
  Down (the D-pad on a controller) read one item at a time, with "First item."
  and "Last item." at the ends; holding repeats. The diary reads one paragraph
  at a time in reading order, then the current objective, with the page number
  when you change page. Character profiles read their paragraphs in order.
  Messages read each contact with any unread count; a conversation starts at the
  latest message, and new messages are announced as they arrive.
- Known limit: the character picker and the photo episodes move around a grid
  the way the game does, which can skip people. Opening any profile and using
  Left and Right to go through the others reaches everyone.
- Letters, posters, notice boards and other close-ups are read when you look at
  them, using the game's own text version. Things without one, such as photos,
  say "No text version." Ctrl+Home repeats it.
- The controller's repeat, help and sound preview (hold the left-stick click)
  now also work while the game has control, for example in a close-up.
- Holding Page Down or Page Up on the keyboard now repeats, as it already did
  on the D-pad.
- Fixed: the game could crash during conversations, a few seconds after the
  answers on screen changed. If the answers ever stop being read, the next set
  is read as usual.
- Fixed: starting autowalk on the Main Campus crashed the game.
- Exits are on the scanner, for example "Go To The Main Campus, exit" in the
  corridor after the principal. Walk there with Shift+Home and use the game's
  interact key to leave.
- The scanner no longer lists things the story hasn't made available yet: the
  bathroom butterfly, cart and hammer, the students before they arrive, and the
  classroom desk items before you look at the photo. They appear when the game
  makes them available.
- Number keys now work on every object the face buttons do; the classroom door
  opens with 1.
- Fixed: a comma could be read after a sentence in dialogue choices ("I feel
  sick., B").
- Dialogue choices are read when they appear, with the key for each answer:
  numbers on the keyboard, the face buttons on a controller. Press the number to
  answer. Major choices are announced as such.
- The sound for getting control back is now the control-loss sound played
  backwards.
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
