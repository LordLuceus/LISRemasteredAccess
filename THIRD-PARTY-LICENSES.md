# Third-party licences and source

This tester package contains the mod, its loader, native accessibility components
and processed sound cues. It does not contain the game, saves or extracted game
assets. Third-party licence texts accompany it in the `licenses` folder.

## UE4SS and the dialogue-property helper

The included loader is **UE4SS 3.0.1-1181-g83330635**, from
[the RE-UE4SS project](https://github.com/UE4SS-RE/RE-UE4SS), pinned to
[source revision 8333063595fa3c49ad307f3b0f732accbb760d25](https://github.com/UE4SS-RE/RE-UE4SS/tree/8333063595fa3c49ad307f3b0f732accbb760d25).
Its supplied MIT notice is included as `licenses/UE4SS.txt`.

The dialogue helper uses that loader's public LuaMadeSimple and LuaRaw declarations,
and fmt 11.2.0 headers. Their accompanying notices are included as
`LICENSE-LuaMadeSimple.txt`, `LICENSE-LuaRaw.txt` and `LICENSE-fmt.txt` in `licenses`.
They do not imply compatibility with a different UE4SS binary.

Lua's own MIT notice is included separately as `licenses/Lua.txt`; the LuaRaw
wrapper's notice does not replace it. The loader's embedded dependency notices
are under `licenses/UE4SS-dependencies/`, with a checksum-locked source catalog.
These include its C++ libraries, fonts and the Rust packages in its binding's
lockfile. Notices for optional or other-platform dependencies may be retained as
well; their presence does not mean a separate runtime is installed.

## Prism speech and braille

Prism is linked into the speech module under the **Mozilla Public License 2.0**.
The package includes its licence, upstream notice and dependency notices under
`licenses/Prism/`. The source is
[Prism revision c30d865faf9b4c38769cc58c2f33cbac78fba3ef](https://github.com/ethindp/prism/tree/c30d865faf9b4c38769cc58c2f33cbac78fba3ef).

The exact upstream source archive accompanies the binary as
`licenses/Prism-source.zip`. The complete modified SAPI source is
`licenses/prism-sapi.cpp`, alongside `prism-sapi-literal.cmake`, the recipe used
to substitute it during the build. The change prevents ordinary announcement text
from being interpreted as SAPI XML. These source files are available under MPL-2.0;
the archive and modified file allow recipients to inspect that covered source
without access to the mod's private repository.

Prism's notices cover simdutf (Apache-2.0), Moderncom (MIT), concurrentqueue
(the simplified BSD option), and dr_wav (the public-domain option selected by
Prism). Its upstream notice records permission to use the NVDA controller IDL and
generated RPC code under MPL-2.0; the original LGPL-2.1 text remains included for
attribution. The source archive also contains notices for other platform code,
including Djinni, that is not a separate Windows runtime in this package.

Microsoft's Windows and Visual C++ runtimes are prerequisites, not files supplied
by this ZIP. Screen-reader software is not bundled.

## Sound cues

The six processed WAV cues were generated with ElevenLabs and processed for this
mod. The return-of-control cue is the control-loss cue played backwards. These are
provider output, **not MIT-licensed source code or game audio**.

They are supplied only as part of this complete mod package for use with the mod,
not as a separate sound library or standalone sample download. Raw PCM and
generation credentials are not distributed. See
[ElevenLabs' creative terms](https://elevenlabs.io/creative-terms) for the provider's
terms, including the sound-effects provisions.
