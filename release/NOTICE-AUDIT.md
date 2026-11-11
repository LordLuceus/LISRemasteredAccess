# Tester-package dependency notice audit

Audited against UE4SS commit `8333063595fa3c49ad307f3b0f732accbb760d25`, its
`UE4SS/xmake.lua`, `deps/xmake.lua`, first-party target definitions, custom
third-party package recipes and `deps/first/patternsleuth_bind/Cargo.lock`.
The binary is the unmodified, SHA-256-pinned upstream release, not a local rebuild.

The catalog supplements the supplied UE4SS MIT notice with:

- The upstream first-party notices and embedded Droid/Roboto font notices.
- Lua's notice from its pinned header, separate from the LuaRaw wrapper notice.
- fmt, ImGui, ImGuiColorTextEdit, IconFontCppHeaders, GLFW, GLAD/Khronos, Glaze,
  PolyHook, Zydis, Zycore, asmjit, asmtk and Tracy, including the inline LZ4 and
  rpmalloc notices in Tracy's client source files.
- All 73 registry packages from the loader binding's 76-package Cargo lockfile,
  including optional or other-platform dependencies conservatively. Their crates
  are verified against Cargo's checksums. iced-x86's crate omits its notice file;
  its MIT text is fetched from the precise commit in its `.cargo_vcs_info.json`.
- PatternSleuth's recorded `MIT OR Apache-2.0` declaration and the Apache-2.0 text
  (that alternative is selected for this distribution). Its root does not contain
  standalone licence files. The declaration and authors are retained verbatim.

Two limitations must not be disguised as reproducible upstream build provenance:

- The upstream UEPseudo first-party submodule URL is not publicly available. No
  private SDK source is bundled or separately relicensed. Distribution relies on
  the MIT grant accompanying the unmodified UE4SS binary for UE4SS's own code.
- The upstream IconFontCppHeaders and ImGuiColorTextEdit recipes use moving branch
  references. The captured notices are checksum-locked here; this does not prove
  the exact original source revision used to build those parts of upstream UE4SS.

Prism is handled separately: its pinned upstream source, complete modified SAPI
translation unit, build substitution recipe, MPL text and all upstream notices
accompany the binary. The mod's processed sound cues follow the existing policy:
complete-mod archives only, no standalone sample distribution or raw PCM.

`scripts/release_notices.py` stages the catalog and verifies every input hash.
A missing catalog, incomplete review or changed notice input blocks packaging.
It reads archive members in memory and does not extract or execute dependency code.
When changing the loader version, repeat this inventory audit; do not merely flip
the reviewed flag or reuse this catalog for a different binary.
