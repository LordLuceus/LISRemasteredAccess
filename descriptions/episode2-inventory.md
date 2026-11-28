# Episode 2 description inventory

[Authoring index](README.md)

The original offline census used the installed Steam remaster and source
baseline `e97ea7d` on 2026-11-23. The coverage notes below include subsequent
authoring and disposable-profile checks.

The [scene coverage ledger](episode2-coverage.md) records the current scene, choice, room and movie authoring.

## Workload

The previous uncommitted Episode 2 movie/in-engine draft was withdrawn after
review found substantial gaps and weak descriptions. It is not the starting
standard or evidence of completed scene coverage. The committed close-ups,
world-object descriptions, journal photos and shooting-miss descriptions remain.
The next scene pass should follow [Coverage and quality](coverage.md), including
choice framing and room context. Existing private captures can aid research,
but do not inherit the rejected draft's completeness or quality claims.

| Category | Count | Meaning |
| --- | --- | --- |
| Close-up pictures | 95 | Unique Episode02 ShowPicture texture-package paths; pages/state variants, not 95 interactions or pixel-unique images |
| World Looks | 144 targets / 172 branches | Enabled non-picture, non-generic-Matinee Look actions across 15 streamed maps |
| Story movies | 8 clips | Includes alternate outcomes; about 8 minutes 30 seconds across all alternatives, not one playthrough |
| Other movies | 2 clips | One recap and one teaser; 10 non-Switch identities in total |
| Camera-bearing in-engine timelines | 326 | Of 686 Matinee timelines in 126 logical maps; 320 have enabled authored camera-cut targets |

The camera count includes brief Looks, conversations, transitions and alternate
branches, not 320 long cutscenes. Six other director-bearing timelines have no
enabled authored cut in the census. Missing serialized duration is not proof
of zero length. Scene reachability and the number of useful narration beats
require content review.

The 95 picture assets divide into 49 dorm-interior, 2 outside-dorm, 16 diner,
7 junkyard and 21 later-school candidates. Eight additional Switch movie files
were excluded as platform counterparts; identical frames were not established.

The English close-up catalogue now covers all 95 exported texture paths
(94 distinct PNGs). The five native picture layers reference 94 of the paths.
The diner parking lot newspaper has the same artwork as the referenced diner
newspaper. Max's laptop has a conditional profile page tied to the Episode 1
Victoria picture choice. English voice delays use the picture actions' cue
timers and English audio-event durations. In-game page transitions, conditional
playback and narration timing still need live checks.

The English world catalogue covers all 144 authored targets and 172 Look branches;
these counts do not establish that every target is available to the player.
Two junkyard bottles share one Look fact, so the catalogue binds 171 distinct
facts. Each bottle can be selected separately for a manual read. The art
classroom's Everyday Heroes poster has a literal space before `_Look01` in
its fact name. Keep that space when matching the shipped action.
[Episode 2 catalogue](../src/descriptions/episode2_world_objects.lua)

The diner target named `Diary_5` binds to the plated breakfast mesh, but was
unavailable at the sampled chapter start. The authored roof target
`LiSInteractionActor_LD2_1` attaches to Kate's character; it is not selectable
in the scanner, which is unavailable during the roof dialogue. Its catalogue
entry is not evidence of usable manual narration. Coverage of conditional Looks
uses game assets and action definitions alongside the live checks described in
the [world object guide](world-objects.md#episode-2-captures).

The scene pass also routes 36 camera-Look branches through the quiet world reader, including the first Look at Lisa and two copies of the discarded restaurant sign. This adds 35 target instances to that reader. Its original world-Look census above still describes only the 172 ordinary Look branches.

Separate Episode 2 descriptions include the journal's 10 paired photos
(20 captions) and two junkyard shooting-miss beats.

## How the numbers were obtained

1. Deduplicate logical Episode02 map paths across the installed pak indexes.
   All 119 duplicate map copies were separately checked byte-identical.
2. Inspect all 126 maps, including numbered LD variants and non-LD maps. Associate
   director tracks with their owning Matinee actor; distinguish enabled authored
   camera cuts from empty/disabled tracks and non-camera timelines.
3. Inspect typed `LiSInteractionActor` properties in all 15 interaction-bearing
   maps. Of 299 actors, there are 280 enabled Look branches: 72 picture-mode,
   36 generic-Matinee and 172 remaining world Looks. The world filter is
   `bEnabled`, `ACTION_LOOK`, not `bShowPicture`, and subtype not
   `ACTIONSUBTYPE_GENERIC_MATINEE`; it retains one zen-sequence branch.
   The same rule reproduces Episode 1's 232 targets / 320 branches.
4. Count unique `.uasset` paths under
   `LiS/Content/Packages/ShowPicture/Episode02/` and confirm against a fresh pak
   listing. Consult [Close-ups](closeups.md) for exported-image/reference review.
5. Enumerate installed `Content/Movies/Episode02/` and measure actual files with
   `ffprobe`; separate story, recap, teaser and platform variants.

On the original working checkout, detailed receipts and filtered action data
are under `artifacts/episode2-description-census/`: `REPORT.md`, `summary.json`,
`maps.json`, `scenes.json`, `world-looks.json` and `duplicate-verification.json`.
These are **ignored local evidence**, not prerequisites secretly bundled with
this guide. Full-map JSON exports were pruned after retaining compact evidence.
A fresh clone must regenerate source inventories using the installed game and
the tracked extraction tools; do not invent missing observations from this
summary or assume another agent's private files exist.
