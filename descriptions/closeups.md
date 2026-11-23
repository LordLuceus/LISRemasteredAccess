# Picture-description content

[Authoring index](README.md)

For Look actions that keep the object in the game world, see the [world object authoring guide](world-objects.md).

`episode1.en.json` is the current editable source for reviewed English captions.
Use `episode2.en.json`, and so on, for later episodes; use the actual language
code for translations. The default compiler combines all
`descriptions/episode[1-5].*.json` sources and rejects duplicate asset/language
identities across files. Journal captions are separate and excluded from that
pattern. Never replace the runtime catalogue with only the new episode.
`src/descriptions/data.lua` is generated runtime data. Do not hand-edit it.
The runtime catalogue accepts full texture object paths, not display names,
widget addresses or image basenames. Each translation has its own language and
review status; missing translations fall back to reviewed English.

These are visual descriptions, **not replacements for the game's text versions**.
Each record includes the caption, asset ID, language, review status and
the SHA-256 of the original authoring PNG. The optional `voice_delay` gives
the number of seconds to wait before automatically describing that page in
the matching game language. It includes any delay before the recorded line
starts, the duration of the line and a margin before narration. The source excludes draft
transcriptions, private filesystem paths and extracted game artwork. The first
eleven captions have independent image review. The English catalogue now covers
110 extracted close-ups. In-game checks are ongoing.

After reviewing a new caption against its actual exported image, add its record
and run from the repository root:

```powershell
python scripts/compile_descriptions.py
python -m unittest discover -s tests -p test_compile_descriptions.py
```

`--check` verifies that generated data matches the source without rewriting it.
For private authoring verification, pass `--inventory` pointing to the exporter's
manifest. This checks each referenced PNG's bytes against both hashes. Optional
`--coverage` writes the exact missing-asset list; it does not claim that unlisted
in-game close-ups are covered. The compiler refuses drafts, duplicate IDs within
a language, provenance mismatches and extra private fields. Keep unfinished
drafts outside the reviewed source file.

Runtime integration uses `descriptions.picture.request(page)` for contextual Home/
D-pad-Up rereading and `automatic(page)` for a newly observed picture-mode page.
Each queues a scalar
intent; only the picture view's own Tick reads the currently displayed texture
and resolves its caption. Closed/replaced/stopped views invalidate the request.
Native mode comes from `CanvasPanel_Read:IsVisible()`, matching the shipped Read
and Back handlers. Text presence is availability, not mode: picture-mode speech
appends "Has text version", and native text is spoken on entering Read mode.
The existing native reader remains responsible for text, coordinated by
`descriptions.reader`. Automatic requests recheck the mode before speaking; if it
cannot be established, the previously working native text path remains available.
`poll()` handles expiry
without touching engine objects, and `install()` is retried after class loads.
Disposable-profile playback verified that the description for each of the three
pages on Max's laptop started after her subtitle cleared. F5 has been removed. Home and
D-pad up follow the current mode; literal repeat remains separate, as do the
scanner's ordinary readout and native left/right paging.

## Extract and review a new episode

The checked-in [exporter](../scripts/export_closeups.py) inventories the episode's
ShowPicture folder and decodes original textures with
[CUE4Parse](../tools/closeup-export/Program.cs). It requires .NET 10, an existing
compatible CUE4Parse/Conversion/SkiaSharp/Newtonsoft dependency directory, and
`AnimExtract.runtimeconfig.json` plus `AnimExtract.deps.json` in that directory.
Those locally built dependencies are **not bundled in the repository**. Inspect
the project references in `tools/closeup-export/CloseupExport.csproj`; do not
silently download arbitrary replacements or assume a sibling worktree exists.

Run `python scripts/export_closeups.py --help` for the input flags. Supply the
installed game's Paks directory, a directory of current `*.index.txt` pak member
lists, the verified dependency directory, a new ignored output directory and
`--episode Episode02` (or the intended episode). `--inspect-list` optionally
supplies a bounded newline-delimited list of package members whose serialized
references should also be inspected. This is offline work, not a game launch.

The output manifest records canonical texture identities, PNG hashes and export
status. Check failures; do not count a failed export as reviewed. Compare the
native ShowPicture definitions and actual displayed page order to identify
aliases, reused earlier-episode textures and conditional pages. Folder inventory
alone is not runtime coverage. Review the actual image before writing its text,
and verify any text already available through the native Read mode.

Add reviewed records to `descriptions/episode2.en.json`, preserving the schema
shown in `episode1.en.json`. Run the default compiler to merge **all** episodes.
For source-image coverage, select only the records corresponding to that export:
use `--records` with `--inventory` and an explicit scratch `--output` under
`artifacts/`; then run the default compiler for the shipping aggregate. Do not
run a one-episode compile into `src/descriptions/data.lua` by mistake.

An explicit `--records` accepts one or more source files and replaces the default
selection; it does not append to an existing Lua output. Duplicate asset/language
pairs across episodes are rejected. Keep a shared asset in one source, not two.
