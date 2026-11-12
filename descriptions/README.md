# Picture-description content

`episode1.en.json` is the editable source for the reviewed English captions.
`src/descriptions/data.lua` is generated runtime data. Do not hand-edit it.
The runtime catalogue accepts full texture object paths, not display names,
widget addresses or image basenames. Each translation has its own language and
review status; missing translations fall back to reviewed English.

These are visual descriptions, **not replacements for the game's text versions**.
The source contains only approved prose, asset IDs, language, review status and
the SHA-256 of the original authoring PNG. It deliberately excludes draft
transcriptions, private filesystem paths and extracted game artwork. The first
eleven captions have independent image review; the remaining Episode 1 images
are not yet covered. Folder inventory is not proof of complete runtime coverage.

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
The mode-based interaction is playtest-accepted; wider coverage and multipage
behavior remain unverified. F5 has been removed. Home and
D-pad up follow the current mode; literal repeat remains separate, as do the
scanner's ordinary readout and native left/right paging.
