# Episode 1 world object descriptions

Use this guide for **Look** interactions that leave the object in the world while Max comments. The English catalogue currently covers Kate’s and Brooke’s slates in the girls’ dorm hallway. Brooke is the example for a fixed inscription. Kate is the example for an object whose appearance changes with a choice or rewind. [Runtime catalogue](../src/descriptions/world_looks.lua)

## Find and describe an object

1. Work one room at a time in a disposable profile. Select the object in the scanner, face it, and use the game’s Look action. Record the controller’s world, the actor’s streamed sublevel, its full instance name, and the Look fact that changes in that branch. Several dorm boards appear simply as “Slate,” and scanner letters and positions can change.
2. Capture what the player actually sees before interacting and after any change. Transcribe legible writing and describe the visual detail that gives the action meaning. For example, reading the insult on Kate’s board explains why Max would erase it. Cross-reference the scene and dialogue with the wiki, and use the remaster capture for exact wording, appearance and timing. [Episode 1 transcript](https://life-is-strange.fandom.com/wiki/Episode_1:_Chrysalis_-_Script)
3. Check existing coverage. Picture pages use the texture catalogue, timed camera shots use the scene catalogue, and some scanner entries already have a Home description. The scanner gives existing room-object text precedence on reread, so check for duplicate or conflicting captions before adding an entry. [Picture authoring](README.md) · [Timed scenes](../src/cutscenes/episode1.lua) · [Room and scanner details](../src/descriptions/episode1_rooms.lua)

## Register both ways to hear it

In `src/descriptions/world_looks.lua`, define the entry once with its observed `facts` and a `description(read)` function. For changing objects, read the current story fact each time and return no caption when the state is unknown. Register the same entry in both tables:

| Table | Working example | What it enables |
| --- | --- | --- |
| `objects` | `objects.E1_3C_Corridor_LD.LiSInteractionActor_KateSlate_3` | Home or D-pad up on the selected actor |
| `worlds` | `worlds.E1_3C` includes `kate` | Automatic narration when a Look fact changes from false to true |

A completed Look fact can stay true. Loading that state is silent, and players can request another read with Home. Automatic and manual descriptions, including repeats, wait for all game voices and active subtitles to clear. An unreadable playback state also waits. Use the existing reader so rewinding, changing selection, or leaving a world cannot release an obsolete readout. [Playback check](../src/dialogue/playback.lua) · [Scanner integration](../src/scanner/scanner.lua)

## Verify timing and coverage

For an action that changes an object, compare the fact transition with the animation itself. Kate’s `E1_3C_MIN_KateSlate` changes as Max starts wiping the board. `KateSlate_Interact01_Triggered` arrives about eight seconds later, near the consequences notice. Draw uses the first transition, waits if someone is speaking, and holds the HUD notice behind the pending description. The local reference capture is `artifacts/profile-probe-episode1-dormstory-20261121-184912/UE4SS.log`.

Extend the world Look regression tests and run `lua tests/lua/run.lua` from the repo root. Deploy with the game closed using `python scripts/deploy_probe.py`. In a disposable run, check first Look, Home before Look, a request during another speaker’s line, and the changed and rewound states where applicable. For the next handoff, record which room, actor, state and input you verified, with the capture or log timestamp. [Regression tests](../tests/lua/world_looks.lua)
