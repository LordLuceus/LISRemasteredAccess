# Episode coverage and description quality

[Authoring index](README.md) · [Scenes](scenes.md) · [Movies](movies.md)

## The goal is understandable events, not a catalogue count

An episode-wide scene-description request covers its meaningful visual story:
main sequences, optional conversations, reply-prompt framing, alternate outcomes,
room context, environmental actions and movies. Honour an explicitly narrower
request, but do not silently narrow a broad one to the easiest reader or to
examples listed in this guide. A missing mechanism is work to investigate, not
evidence that the corresponding scene needs no description.

Start from the episode in story order. Cross-reference the wiki transcript and
branches with the shipped game and actual footage. Then select the right runtime
mechanism for each event. Technical inventories help find missing material; they
are not a replacement for watching what happens or understanding its context.

## Keep a small coverage ledger

Use one concise, checked-in episode coverage note alongside the inventory, with
links to authored files and public references. Keep extracted assets, captures,
logs and detailed timing receipts under ignored `artifacts/`. Record:

- Scene or location, its narrative order, branch conditions and meaningful events.
- How each event is communicated: timed narration, choice framing, room context,
  movie track or an existing equivalent readout.
- Evidence and verification state: footage/context reviewed, offline checks,
  native playback observed, or still unverified. Staged previews are not normal
  gameplay and may omit actors, props or script-driven events.
- Remaining work, blockers, or a specific reason no extra narration is needed.

"Already conveyed by dialogue" should name the information and the audible line;
it must not conceal a meaningful silent reaction or the visual detail the player
needs for a puzzle. Repeated identical shots may share a description. Explain
shared coverage rather than padding the cue count. Branches need not each have
different prose when the relevant visual event is genuinely identical.

Do not mark an inaccessible or merely unobserved branch complete. Distinguish
unused authored data from a reachable scene: inspect native gates and actual
player control rather than manufacturing a selectable actor in a test.

## Describe the action and its significance

Identify the participants when the player knows them, what they do, what changes,
and relevant reactions or spatial relationships. Choose the visible information
that helps the player follow the scene. Body position, colours and props are
useful when they establish setting or matter to the event, not as substitutes
for the event itself.

For example, once footage and context establish that Wells is arguing with
Jefferson, describing that exchange communicates more than "Wells leans over a
silver car." Do not invent dialogue, motives or emotions, and do not reveal an
identity before its introduction. Review a sequence, not just an isolated frame:
movement and interaction can be the entire point.

Read visible writing verbatim: messages, signs, graffiti and URLs need their
actual content, not a paraphrase or merely a label such as "a link to the video".
Verify the wording against shipped text and readable frames or textures. Keep
the surrounding description separate from the quotation and preserve the
author's wording and punctuation. Do not guess at illegible text.

Establish where a new scene takes place before referring to a doorway, window
or other camera-relative detail. The listener does not already have the shot's
visual context; identify the setting rather than describing only the framing.

In a prediction puzzle, narrate the observable chain of events the player is
meant to notice. A caption about someone approaching a table does not cover a
later dropped glass or another character leaving. Describe events when they
happen; do not announce future events early or supply the correct answer as
instruction. Rewind/replay and alternate outcomes must retain that distinction.

Concision means removing redundancy while preserving information. Do not impose
an arbitrary one-cue-per-scene rule or stop at an episode cue quota. Compare a
proposed caption with the fuller scene context: what important information was
lost, and why is that omission acceptable? Apply the same check to movie montages.

## Timing and evidence remain part of quality

Use the game playback clock and measured language-specific speech intervals.
Leave enough time for the sentence to be spoken, not merely started. Prefer
gaps and respect existing speech ownership. The scene guide records accepted
overlap precedents; do not silently make them stricter or expand them universally.
If an important event cannot fit safely, investigate a suitable established
mechanism or report the specific timing blocker instead of replacing the event
with a trivial detail that happens to fit.

Judge narration duration against actual play and the player's speech settings.
A slow default-voice benchmark alone is not a reason to rewrite accepted prose
or block a landing. Keep successful playtest results authoritative and revisit
timing when a player reports a problem, rather than optimising speculatively.

Cross-reference the wiki for participants, event order and branches. Verify the
remaster's actual visuals and timing. Neither a plausible asset name nor a wiki
sentence alone proves how to narrate a particular shot. Preserve accepted
anonymous wording and the player's knowledge at that point in the story.

## When the request is complete

Before reporting an episode-wide task finished:

1. Reconcile the whole requested episode against the ledger, including choices,
   rooms, optional interactions, alternate outcomes and transitions between
   in-engine scenes and movies. No meaningful scene should disappear just because
   it uses a different reader or lies outside the easiest chapter-start capture.
2. Review each covered scene for its important events, not merely a nonempty
   caption list. Read the prose in story order and compare it with the verified
   context. A registered timeline containing one irrelevant sentence is a gap.
3. Check implementation and playback separately: identity/branch selection,
   timing, dialogue protection, repeat, rewind and cancellation. Record which
   native paths were actually exercised and which have only offline evidence.
4. Explain justified exclusions and unresolved blockers. Pending authoring or
   evidence work is not completed coverage. Continue independent work while a
   blocked branch awaits input, and report partial progress as partial progress.

Do not claim every native branch was played when it was not. Unexercised playback
can remain a disclosed verification limit; missing prose or unreviewed visual
content must not be hidden by passing tests. A time limit, session end or first
successful batch does not change the meaning of the user's original goal.

The automated suites prove properties such as valid keys, unchanged accepted
content and correct reader behaviour under fixtures. They cannot certify that
the player received the story's important visual information. That requires the
coverage and editorial review above, not a larger green test count.
