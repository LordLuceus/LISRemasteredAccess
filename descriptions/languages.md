# Language files and hand-editing descriptions

[Authoring index](README.md) · [In-engine scenes](scenes.md)

## Find the text, not the loader

[`src/lang/en.lua`](../src/lang/en.lua) is the English catalogue's index. It lists
the modules to load and returns the same flat key-to-string table the readers
already use. Edit the listed modules, not this index, to change wording:

- [`interface/`](../src/lang/en/interface/) contains menus, navigation, scanner,
  readers, help and other announcements, separated by feature.
- [`scenes/episode1/`](../src/lang/en/scenes/episode1/) contains Episode 1 narration,
  grouped by location, including the classroom and choice-camera descriptions.
- [`scenes/episode2/`](../src/lang/en/scenes/episode2/) contains Episode 2 narration,
  currently only the accepted junkyard shooting descriptions. Add other location
  modules when their replacement descriptions are authored and reviewed.

Each file is an ordinary Lua table of stable keys and editable string values.
The scene timing catalogue refers to those exact keys. For example, a window
whose key is `scene_e1_1a_clifffuture_introstorm_1` gets its wording from the
Episode 1 `s01_nightmare.lua` file. Searching that key under `src/lang/en/` finds the
authoring entry without searching unrelated interface messages.

Keep the key unchanged when rewriting the value. Save UTF-8, preserve every
`{placeholder}`, and keep quotes and Lua string syntax valid. English prose can
use a long string such as `[[The sign reads "Missing."]]` when that is clearer
than escaping quotation marks. Preserve terminal punctuation. A longer line
still needs room in its existing narration window: changing wording is not
permission to change cue timing or interrupt game dialogue.

## Add a module or a key

Add new keys to the matching topic or location file. New modules must be listed
in the language's index; a file on disk alone is not registered. The shared
[`lang.catalog`](../src/lang/catalog.lua) loader rejects duplicate keys across
modules, non-string entries and invalid module results instead of silently
overwriting text. A missing listed module is an error, not an untranslated key.

Within a Lua table, do not write the same key twice: Lua evaluates the table
before the merger sees it, so the later value would replace the first.

## Start a partial translation

For French, create `src/lang/fr.lua` with only the modules you are providing:

```lua
return require("lang.catalog").load("fr", {
    "interface.menus",
})
```

Create `src/lang/fr/interface/menus.lua` and return a table of translated keys.
Use the corresponding English topic file as your template, keeping the original
keys and placeholders. You may include only the keys you have translated. Do
not list missing modules in `fr.lua`: omit those index entries until the files
exist. For a complete translation, copy the English folder and index, rename
them to your language code, and change the loader's code from `en` to that code.
Regional codes use underscores in filenames, for example `pt_br.lua` and
`pt_br/` for the game's `pt-BR` setting.

The existing lookup rules remain:

1. Select the exact game-language catalogue if it loads successfully.
2. Otherwise try its base-language catalogue, then English.
3. A key absent from the selected catalogue falls back to English. It does not
   cascade through a second, base-language catalogue for individual missing keys.

Existing single-file translations returning a flat table still work. Module
files are a convenience for authoring, not a new required translation format.
An invalid translation catalogue currently falls through the same language
selection path as an unavailable one, so validate it offline before installation.

## Description categories and playback limits

This split relocates the strings that used to be in `lang/en.lua`; it does not
move every description in the project into the language folder:

- World-object captions remain in the episode world catalogues, including their
  state-dependent definitions. Room/scanner prose has its existing catalogue.
- Close-up pictures and journal photos retain their JSON authoring sources.
- Movie narration retains its language-specific subtitle tracks.
- The small inline action descriptions remain beside their native actor bindings
  in the scene catalogues.

Follow the [authoring index](README.md) for those locations. Existing language
gates, English-only narration paths, voice protection and cue times are unchanged.
Translating a scene string does not by itself make that scene available in another
language. Enabling that requires its own language-specific dialogue/timing review;
do not remove a playback gate merely to make a translated line audible.

## Check before installing

Run the ordinary Lua and Python suites from the repository root:

```powershell
lua tests/lua/run.lua
python -m unittest discover -s tests
```

Use Lua 5.4; see the [tool-path guidance](README.md#verification-and-handoff).
The catalogue regression compares the split English text with the integration
fixture (committed content plus the separately recorded later wording edit,
excluding the rejected Episode 2 scene draft), checks merging errors and
exercises partial-translation fallback.
That fixture is historical test data, not an authoring source. If you intentionally
change a preserved caption, review and update its expected test value explicitly;
do not regenerate the fixture merely to silence a failure.

New Lua files are included recursively by deployment. Release packaging includes
tracked source files, so add new modules to version control before packaging.
Keep the index and its modules together: copying only the small `en.lua` loader
into an older installation is not a complete update. No game launch is needed
to check syntax, catalogue loading or exact text preservation.
