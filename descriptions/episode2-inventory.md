# Episode 2 description inventory

[Authoring index](README.md)

Offline census made on 2026-11-23 against the installed Steam remaster, with
source baseline `e97ea7d`. These are authoring candidates, **not a claim of
complete runtime coverage or completed descriptions**. No game was launched.

## Workload

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

Existing separate Episode 2 descriptions are the journal's 10 paired photos
(20 captions) and two junkyard shooting-miss beats. There are no general Episode 2
close-up/world/movie catalogues yet. Reused earlier-episode textures may resolve
through their existing captions; this census does not establish their use.

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
