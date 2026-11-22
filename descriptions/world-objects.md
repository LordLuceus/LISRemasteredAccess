# Episode 1 world object descriptions

Use this guide for **Look** interactions that leave the object in the world while Max comments. Brooke’s dorm slate is an example of a fixed inscription. Kate’s and Max’s slates and the dusty RV window change when Max draws on them or rewinds. [Fixed descriptions](../src/descriptions/episode1_world_objects.lua) · [Runtime catalogue and changing objects](../src/descriptions/world_looks.lua)

## Find and describe an object

1. Work one room at a time in a disposable profile. Select the object in the scanner, face it, and use the game’s Look action. Record the controller’s world, the actor’s streamed sublevel, its full instance name, and the Look fact that changes in that branch. Several dorm boards appear simply as “Slate,” and scanner letters and positions can change.
2. Capture what the player actually sees before interacting and after any change. Transcribe legible writing and describe the visual detail that gives the action meaning. For example, reading the insult on Kate’s board explains why Max would erase it. Cross-reference the scene and dialogue with the wiki, and use the remaster capture for exact wording, appearance and timing. [Episode 1 transcript](https://life-is-strange.fandom.com/wiki/Episode_1:_Chrysalis_-_Script)
3. Check existing coverage. Picture pages use the texture catalogue, timed camera shots use the scene catalogue, and some scanner entries already have a Home description. The scanner gives existing room-object text precedence on reread, so check for duplicate or conflicting captions before adding an entry. [Picture authoring](README.md) · [Timed scenes](../src/cutscenes/episode1.lua) · [Room and scanner details](../src/descriptions/episode1_rooms.lua)

## Register both ways to hear it

For a fixed object, add its full scanner instance name, Look facts and spoken text under its streamed room in `episode1_world_objects.lua`. If several instances share the same facts and caption, list the additional full actor names as the fourth field on that row. For a changing object, use `register` in `world_looks.lua` with its observed `facts` and a `description(read)` function. Read the current story fact each time and return no caption when the state is unknown. Registration connects both ways to hear the same entry.

| Table | Working example | What it enables |
| --- | --- | --- |
| `objects` | `objects.E1_3C_Corridor_LD.LiSInteractionActor_KateSlate_3` | Home or D-pad up on the selected actor |
| `worlds` | `worlds.E1_3C` includes `kate` | Automatic narration when a Look fact changes from false to true |

A completed Look fact can stay true. Loading that state is silent, and players can request another read with Home. Automatic and manual descriptions, including repeats, wait for all game voices and active subtitles to clear. An unreadable playback state also waits. Use the existing reader so rewinding, changing selection, or leaving a world cannot release an obsolete readout. [Playback check](../src/dialogue/playback.lua) · [Scanner integration](../src/scanner/scanner.lua)

## Verify timing and coverage

The Episode 1 level data contains 320 enabled, non-picture Look definitions on 232 actors across 18 streamed rooms once camera-sequence branches are excluded. The same actor can use a camera on its first Look and stay in the world on a later Look. The classroom pencil case and the garage tool case both do this. Check each action branch when comparing the world and timed catalogues.

For an action that changes an object, compare the fact transition with the animation itself. Kate’s `E1_3C_MIN_KateSlate` changes as Max starts wiping the board. `KateSlate_Interact01_Triggered` arrives about eight seconds later, near the consequences notice. Draw uses the first transition, waits if someone is speaking, and holds the HUD notice behind the pending description. The local reference capture is `artifacts/profile-probe-episode1-dormstory-20261121-184912/UE4SS.log`.

Extend the world Look regression tests and run `lua tests/lua/run.lua` from the repo root. Deploy with the game closed using `python scripts/deploy_probe.py`. In a disposable run, check first Look, Home before Look, a request during another speaker’s line, and the changed and rewound states where applicable. For the next handoff, record which room, actor, state and input you verified, with the capture or log timestamp. [Regression tests](../tests/lua/world_looks.lua)

## Capture notes

Times below are local timestamps in the corresponding disposable profile’s `UE4SS.log`. The matching images are in its `frames` directory.

| Room and capture under `artifacts/` | What to check |
| --- | --- |
| Girls’ dorm hall, `profile-probe-episode1-dormstory-20261121-190949` | Room 219 is blank on Look at 19:10:42. Draw at 19:10:49 writes Max’s name and face. Look at 19:10:58 takes the second branch. Dana, Juliet, Stella, Taylor and Victoria follow in order from 19:11:16 through 19:12:18. |
| Parking lot, `profile-probe-world-e1-3d-campuspark-ld-20261121-195811` | The dusty RV window takes Look01 at 19:59:43. The dog is on the asphalt beside it at 19:59:52. The bike rack graffiti and the vandalized parking space take separate Looks at 20:00:02 and 20:00:22. |
| Lighthouse, `profile-probe-world-e1-6a-cliffnow-ld-20261121-200044` | Home reads `Sign01_3` at 20:02:49 before Look. A second Home request at 20:02:52 waits until Max’s subtitle clears at 20:02:53 and speaks at 20:02:54. The haiku and childhood carving have separate actors and facts at 20:03:21 and 20:03:33. |
| Main campus, `profile-probe-world-e1-3a-campusa-ld-20261121-200347` | Brooke holds her controller at 20:04:34. The three outdoor photographs appear on separate displays from 20:07:07 to 20:07:28. |
| Dorm courtyard, `profile-probe-world-e1-3b-campusb-ld-20261121-200851` | The tree inscription faces the player at 20:10:44. The two recycling bins and four sprinkler heads can each be selected. Their copies share facts. |
| Chloe’s room, `profile-probe-world-e1-5a-chloeroom-ld-20261121-201256` | The blue drawers at 20:13:46, the high box at 20:13:55 and the desk at 20:14:40 have separate Look targets. |
| Max’s room, `profile-probe-world-e1-3c-maxroom-ld-20261121-201706` | Look at the photo wall at 20:20:40, the plant and tiny panda at 20:20:51 and the pennant at 20:21:23. |
| Living room and yard, `profile-probe-world-e1-5b-livingroom-ld-20261121-202200` and `profile-probe-world-e1-5b-garden-ld-20261121-202418` | The telephone’s lit indicator is visible at 20:22:44. At 20:25:03, the backyard drawing shows two girls holding hands under a rainbow. |
| Garage, `profile-probe-world-e1-5b-garage-ld-20261121-202538` | The laptop at 20:26:32, high files at 20:27:49 and food shelves at 20:28:00 are separate scanner targets. |
| Bathroom, `profile-probe-world-e1-5a-bathroom-ld-20261121-202935` | The drawer's dark-room Look leaves it closed. The frames at 20:30:35 and 20:30:38 show its front, not the contents revealed by the separate lit-room Search action. |
| Upstairs hall and bedroom, `profile-probe-world-e1-5a-corridor-ld-20261121-203111` and `profile-probe-world-e1-5a-parentsroom-ld-20261121-203235` | The media shelf takes Look at 20:32:10. The magazine beside the clock radio is visible at 20:34:18. The close view at 20:34:29 shows the necklace's bow ties and shells. |
| Dana's room and Victoria's room, `profile-probe-world-e1-3c-danaroom-ld-20261121-203504` and `profile-probe-world-e1-3c-vicroom-ld-20261121-203706` | Dana's cheerleading outfit is laid out on the pink couch at 20:36:00. Victoria's jewelry stand appears at 20:38:07 and her large fashion prints at 20:38:28. |
| School hallway, `profile-probe-world-e1-2a-corridor-ld-20261121-204413` and `profile-probe-world-e1-2a-corridor-ld-20261121-204646` | The party poster is visible at 20:45:44 and Max's red locker at 20:46:19. The second capture includes the anti-bullying posters, both trophy cases and the vending machines. The classroom-start checkpoint leaves the hallway students inactive. Their entries were checked against the character assets, dialogue and native Look definitions. |
| RV Draw and rewind, `profile-probe-state-e1-3d-campuspark-ld-20261121-210759` | Home speaks the dusty-window description at 21:08:38. After Draw, Home speaks the writing at 21:09:00. Rewind clears the drawing fact at 21:09:14, and the caption resolves to the dusty glass again at 21:09:26. |
| Room 219 Draw and rewind, `profile-probe-state-e1-3c-corridor-ld-20261121-210943` | Home is requested during “Hurry Courtney!” at 21:10:13. The first blank-board readout is heard at 21:10:34, after the students and Max finish speaking. Draw is used at 21:10:38. The signed board resolves at 21:10:49, and after rewind it resolves to the blank board at 21:11:20. |

The RV run at 21:07 verified the changed and rewound captions and reached the title screen. The game then exited with code `0xC0000005`. A repeat in `profile-probe-state-e1-3d-campuspark-ld-20261121-214107` exited cleanly after Draw. That probe ended before observing the changed fact or repeating the rewind. Both profiles left the player's saves intact.
