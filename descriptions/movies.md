# Movie descriptions

[Authoring index](README.md) · [In-engine scenes](scenes.md)

Use this category only for story movies played by the game's existing movie
player. A filename alone does not establish that the player supports its clock.
The native adapter in [native.lua](../src/cutscenes/native.lua) and its compiled
helper already handle the supported path; content work must not bypass it.

## Content and timing

- Bundled prose: `src/cutscenes/tracks/en/episode01/*.mp4.ad.srt`.
- Bundled dialogue protection: [tracks/dialogue.lua](../src/cutscenes/tracks/dialogue.lua).
- Loading, identity and caching: [tracks.lua](../src/cutscenes/tracks.lua).
- Parsing/scheduling: [track.lua](../src/cutscenes/track.lua).
- Runtime ownership and rereading: [runtime.lua](../src/cutscenes/runtime.lua).

For another movie, create the lower-case language/episode/movie identity path,
for example `tracks/en/episode02/<actual-movie-filename>.mp4.ad.srt`. The loader
derives it from the native movie URL; do not invent a filename from a story label.
It recognizes Episode01 through Episode05 and uses the selected text language,
without silently applying English timing over another language's dialogue.

SRT files are UTF-8, numbered consecutively from 1, with non-overlapping start/end
times and plain prose. End times are the last opportunity to **start** a cue,
not its estimated speech duration. Leave enough room for the spoken sentence.
See [the accepted ending track](../src/cutscenes/tracks/en/episode01/bik_e1_7a_snowing.mp4.ad.srt)
for the format; do not rewrite its accepted anonymous identities.

The separate dialogue table uses keys such as
`en/episode01/bik_e1_7a_snowing.mp4` (no `.ad.srt`) and pairs of protected seconds.
Measure voiced intervals and margins in the matching language. Protection can
stop a long readout when dialogue resumes, even after its start window. Add the
appropriate table entry with a new bundled track; merely adding SRT prose does
not establish safe speech timing. Existing intervals must survive relocations
unchanged.

User overrides under `Scripts/cutscenes/overrides/` take precedence. They own
their timing and do not inherit the bundled dialogue table. An empty override
disables that movie's descriptions. Never overwrite those files during authoring
or deployment. Restart after editing cached tracks.

## Evidence and workflow

1. Inventory the installed `Content/Movies/EpisodeNN` files. Separate story clips,
   branch alternatives, recap/teaser clips and platform/language variants. Do not
   count Switch counterparts as extra Windows scenes or assume identical frames.
2. Inspect the footage and shipped subtitle/audio timing offline. The game's
   movie audio can be driven separately; silence in an MP4 is not proof that the
   game is silent there. Record source identity, language, cue times and review
   notes privately. No full movie copies belong in the repository or package.
3. Write concise descriptions in actual gaps, respecting who has been introduced.
   Review the text and how long it takes to speak, including rereading.
4. Add SRT and dialogue metadata. Exercise parsing, malformed input, language/path
   selection, cache/restart, override precedence and speech protection offline.
5. With separate launch permission, test through the **real story action** using
   the established isolated-profile procedure. Never call `D9PlayGameVideo`
   directly to test a track: bypassing its owner has caused a native crash.

## Checks and packaging

Run the [common checks](README.md#verification-and-handoff). Movie-specific tests
are `tests/lua/cutscenes.lua` and `tests/test_cutscene_tracks.py`; update their
reviewed inventory/duration expectations when deliberately adding a track, not
to hide accidental omissions. Verify slow speech, pause/focus, rewind where
applicable, Home/controller rereading and leaving the movie.

The source packaging collector includes valid bundled track paths but excludes
overrides. Inspect `scripts/deployment_inventory.py` and `scripts/deploy_probe.py`
when extending required inputs; their existing Episode 1 baseline must not be
removed. Verify the resulting deployed/packaged track and metadata bytes. A
green parser test is not native playback verification, and building an SRT does
not authorize a new release or replacing a previously shared ZIP.
