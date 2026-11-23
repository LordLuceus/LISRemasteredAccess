# Journal photo descriptions

[Authoring index](README.md) · [Close-ups](closeups.md)

This category already covers all five episodes' optional-photo pages. It is not
the world photo-taking interaction and not the native close-up picture viewer.

- Captions: `descriptions/journal_photos.en.json` (100 reviewed captions).
- Authored locked/unlocked identities: `descriptions/journal_photo_slots.json`
  (50 paired slots).
- Generated Lua: `src/descriptions/journal_photos_data.lua` and
  `src/hud/journal_photo_slots.lua`; never hand-edit either output.
- Official browsing order: `src/hud/journal_photo_order.lua`.
- Reader and identity gate: `src/hud/journal_photos.lua` and
  `src/hud/journal_photo_state.lua`.

Review each locked hint and unlocked photograph independently against its actual
image. Do not use the unlocked image or filename to reveal the answer in the
locked caption. Preserve exact episode/native-child/texture identity even when
changing player-facing order; visual collage order is not the official photo
numbering. The journal reader uses the currently displayed brush, not a guessed
story flag or chapter-select counter. Do not poll the native texture getter:
it also mutates a seen-list.

After intentional reviewed changes, regenerate explicitly:

```powershell
python scripts/compile_descriptions.py --records descriptions/journal_photos.en.json --output src/descriptions/journal_photos_data.lua
python scripts/compile_photo_slots.py
```

Add `--check` to each command for verification without rewriting. The slot
compiler's optional `--import-manifest` is for independently extracted typed
metadata; do not fabricate pairs from naming guesses. Run the common Python/Lua
suites; the journal tests cover all paired identities, ordering and actual
reader paths. Unknown or mismatched resources must remain unavailable rather
than revealing a hidden photograph.
