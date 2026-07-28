# Future project ideas

Personal side-project ideas that touch this machine, not committed work and not
part of igor-desktop's actual description. Unlike the rest of `docs/`, this
file is speculative and will age: feasibility notes below are dated because
things like GPU driver support and the local-LLM tooling landscape move fast.

## Long-term aspiration: a coherent, lean app suite instead of KDE/GNOME apps

The motivation behind forking Dolphin and KeePassXC (below) instead of just
theming them: KDE and GNOME are large enough that they necessarily move
slowly and carry a lot of framework weight, where Hyprland's own ecosystem -
and projects like [DankMaterialShell/danklinux](https://github.com/AvengeMedia/DankMaterialShell)
(a complete Quickshell-based desktop shell replacing waybar, swaylock,
swayidle, mako, fuzzel, and polkit all at once, with matugen for
wallpaper-based auto-theming) - moves faster and stays lean. That project is
a real existence-proof that a from-scratch, QtQuick-first, no-KDE/GNOME-
framework-baggage desktop is buildable at real scale, not just in theory -
worth studying directly (including its matugen-based theming approach) as a
model for extending one coherent design language across more of your own
apps, the way this repo's own bar/lockscreen/launcher already share one.

One correction to the file-manager idea below: Kirigami (KDE's QtQuick
component set, used by index-fm) is still a KDE Frameworks dependency - it
doesn't actually dodge the "big, slow-moving framework" concern, just moves
it from QWidgets to QML. Plain QtQuick/Qt Quick Controls with no Kirigami,
the same foundation Quickshell itself is built on, is the framework-choice
that's actually aligned with wanting something lean.

Worth being honest about scope: macOS's coherence comes from one company
controlling one toolkit (AppKit/SwiftUI) that nearly every app, first- and
third-party, opts into. That's not reproducible system-wide on Linux even in
principle - Firefox, Steam, and every Electron app will never match a custom
design language, regardless of what happens to Dolphin and KeePassXC. What
*is* reproducible is a coherent suite of the apps you actually build
yourself (shell, file manager, a secret-vault UI) sharing one deliberate
design language - a real, bounded goal, just a much bigger one than "fix the
bugs," and one where "very long shot" is a fair way to describe it if
pursued to its full ambition.

Priority order, per your own call: fixing the confirmed bugs and improving
Nix/home-manager integration first (scoped, achievable, detailed in each
idea below); a from-scratch coherent UI/UX matching the rest of the shell is
the long-shot stretch goal after that, not a prerequisite to the first part.

## Custom file manager, registered as the portal's FileChooser backend

Build a GUI file manager and register it as the
`org.freedesktop.impl.portal.FileChooser` backend, replacing Dolphin/KDE's
portal (currently `xdg.portal.config.hyprland."org.freedesktop.impl.portal.FileChooser"
= [ "kde" ];` in `configuration.nix`).

**Feasibility: medium.** Two genuinely separate halves:

- The file manager itself (browse, open, basic file operations) is
  approachable, and since this repo already leans on Qt/QML for Quickshell's
  bar/lockscreen/launcher, building it in QML reuses skills already exercised
  here rather than starting a new toolkit from zero.
- The portal backend is the harder half: `org.freedesktop.impl.portal.FileChooser`
  is a documented but non-trivial D-Bus interface (OpenFile/SaveFile/SaveFiles,
  parent-window handle passing, the `org.freedesktop.impl.portal.Request`
  lifecycle for returning results). Existing backends
  (xdg-desktop-portal-gtk/-kde/-hyprland) are real, multi-thousand-line
  codebases, though a minimal version with no thumbnails/search/recent-files
  would be much smaller.

**LLM help: high**, specifically for the portal-interface half - the D-Bus
interface is public and well-documented, something an LLM can scaffold
directly (Rust+zbus, or Qt/QML+QtDBus) and help debug against
`busctl introspect`/`gdbus call`. The file-manager-app half is more
conventional app-building work any LLM assists with equally.

**Where it'd plug in:** swap `"kde"` for the new backend's name in that same
`xdg.portal.config` line once it works.

**Alternative: fork an existing file manager instead of writing one from
scratch.** Changes the shape of the work:

- Visual fit doesn't actually require QtQuick/QML - Dolphin already looks
  right today purely because `qt.style`/`qt.platformTheme` in
  `configuration.nix` theme *any* Qt6 app, QWidgets included. Forking a
  lightweight QWidgets file manager and just packaging it would likely
  already look consistent with no reskin work at all. QtQuick/QML only
  matters here if the goal is the tech stack itself (matching Quickshell,
  easier to hand-customize later) - worth being clear with yourself on which
  of those two you actually want before picking a project to fork.
- If QtQuick/QML specifically is the goal (e.g. for the coherent-design-
  language aspiration in the section above), prefer plain QtQuick/Qt Quick
  Controls with no Kirigami, matching Quickshell's own foundation - see that
  section for why. [KDE's index-fm](https://github.com/KDE/index-fm) (Kirigami/QtQuick,
  actively maintained, runs on Plasma Mobile/desktop/Android) is a
  functioning QtQuick file manager to study or crib from, but its Kirigami
  dependency cuts against the "lean, no big-framework baggage" goal, and
  it's touch/mobile-first, so it'd need real UX rework for mouse-and-keyboard
  use regardless, not just a reskin.
- "Fixing issues found" doesn't apply retroactively here - no existing file
  manager has been used and found lacking this session (Dolphin's problem
  was OS-level theming, already fixed separately). Whatever bugs a fork
  needs fixing would only surface after using it day-to-day.
- Nix support: forking means packaging your own fork rather than upstream's
  package - ordinary Nix packaging work either way (`callPackage`'d
  qt6.mkDerivation or similar). The KDE Frameworks 6 app ecosystem is
  already well-represented in nixpkgs (`kdePackages.*`), so a lot of the
  build-dependency plumbing is already proven to work in this exact setup.

## Secret Service provider that reads/writes a KeePass vault directly

Replace KeePassXC's role as Secret Service provider - the thing this repo's
VS Code secret-storage debugging (2026-07) was actually about - with a custom
`org.freedesktop.Secret.Service` implementation reading/writing the same
`.kdbx` file.

**Feasibility: medium**, and easier than it sounds if built on an existing
library rather than from scratch:

- The Secret Service D-Bus interface (Service/Collection/Item/Session) is
  small and well-documented: a handful of methods (OpenSession, SearchItems,
  Unlock/Lock, GetSecrets).
- The hard part is the KDBX file format itself (AES/ChaCha20 encryption,
  Argon2/AES-KDF key derivation, protected in-memory fields) - writing that
  from scratch dwarfs everything else combined. Mature libraries already do
  this (Python's `pykeepass`, Rust's `keepass-rs`), turning the real project
  into "a D-Bus service that calls into an existing KDBX library."

**Worth being upfront about:** KeePassXC has years of hardening on this exact
attack surface (memory locking so secrets don't get swapped to disk, secure
wiping, core-dump protection) that a hobby implementation won't match on day
one. Worth building for the learning value and to dodge the Secret Service
"remember" bug specifically (see below), going in aware it starts out less
battle-tested than what it replaces.

**LLM help: high** - D-Bus service boilerplate glued to a library like
pykeepass is exactly the well-documented-protocol-plus-library-glue work an
LLM handles well.

**Where it'd plug in:** a `systemd.user.services` entry in `home.nix`, same
pattern as `quickshell-lock`/`quickshell-launcher` already there.
KeePassXC's own Secret Service integration would need to be disabled so the
two don't fight over the same D-Bus name.

**Context for "why bother" if curious later:** KeePassXC's Secret Service
"remember this app" checkbox is a confirmed, long-standing upstream bug
(GitHub issues #7464, #7623, #8784, #11773, #11844 - still open as of
2026-07), so every fresh app launch re-prompts for access. Tolerable in
practice, but the itch behind this idea.

**Alternative: fork KeePassXC itself instead of writing a new provider.**
Maps more directly onto "fix the issues found" than a from-scratch provider
does, since those issues live in KeePassXC's own D-Bus-facing code:

- The "remember" bug and the confusing global-toggle-vs-per-database-exposure
  split (both hit directly this session) are specific, scoped things to
  patch, separate from KeePassXC's vault-editing GUI - fixing them shouldn't
  need touching the rest of the app. A well-scoped fix might even be worth
  upstreaming given how long these have stayed open, rather than maintaining
  a permanent personal fork.
- Visual fit (QtQuick/QML/Qt6): KeePassXC's UI is QWidgets, and - same point
  as the file-manager idea above - it already inherits this repo's Qt
  theming automatically, no reskin needed for basic consistency. A full QML
  rewrite of KeePassXC's UI (vault tree, entry editor, browser integration,
  autotype, all deeply tied to QWidgets today) is a much bigger, largely
  separate undertaking from the D-Bus fixes above, and belongs with the
  coherent-design-language aspiration at the top of this file rather than
  with "fix the bugs" - per your own priority order, patch the D-Bus code
  first and treat reskinning as the later, optional stretch goal, not
  something to bundle into the same pass.
- License: dual GPL-2/GPL-3 ([keepassxreboot/keepassxc](https://github.com/keepassxreboot/keepassxc)) -
  forking and modifying is unambiguously permitted.
- Nix support improvement: the concrete gap this repo already hit is in
  `home.nix`'s own comment on why `programs.keepassxc.settings` is left
  empty - declaring it links `keepassxc.ini` read-only, which stops
  KeePassXC's own "remember the last database for autostart" behavior from
  working. A fork could read Secret Service configuration from an
  additional, separately-managed source (an env var, a supplementary file)
  so home-manager could declare it without that trade-off - a small,
  targeted improvement specific to the actual friction hit here, much more
  tractable than a UI rewrite.
- LLM help here is somewhat different in kind from a from-scratch project:
  as useful for orienting inside an existing, unfamiliar C++/Qt codebase
  (finding the relevant Secret Service source and existing patterns before
  patching) as for writing new code.

## Local LLM serving VS Code Copilot instead of the hosted service

**Feasibility: high, and easier than expected for the integration half
specifically.** As of VS Code's 2026-06-18 release, Copilot Chat's model
picker has a built-in "Manage Models" flow with Ollama as a first-party
provider - no extension, no GitHub sign-in required. So the "integrate
Copilot" part is now close to: run Ollama, pull a model, pick it from the
model picker. (Continue.dev, long the standard third-party option for this,
was acquired and effectively frozen as of 2026-06 - not worth building
around now that native support exists anyway.)

The real remaining work is the local-model-serving side:

- **Hardware risk, worth re-checking before relying on this:** the RX 9070 XT
  (RDNA4, gfx1201) only got *official* ROCm support in ROCm 7.2
  (2026-03) - before that it needed `HSA_OVERRIDE_GFX_VERSION` workarounds.
  That's recent enough that it's worth confirming the actual ollama/ROCm
  package versions in use are new enough. NixOS: `services.ollama.package =
  pkgs.ollama-rocm;` (the older `services.ollama.acceleration` option is
  deprecated); `services.ollama.rocmOverrideGfx` is the escape hatch if GPU
  detection still misbehaves. llama.cpp's Vulkan backend is a fallback that
  sidesteps ROCm entirely if it keeps giving trouble - Mesa RADV already
  works for Hyprland's own rendering on this GPU.

**Which actual model** (the RX 9070 XT's 16GB VRAM is the real constraint
here - not every model that tops a benchmark is one you can run):

- **Qwen** - `Qwen3-Coder-30B-A3B` is the practical pick for this hardware:
  a mixture-of-experts model, 30B total parameters but only ~3B active per
  token, so it needs VRAM like a 30B model (a tight but plausible fit in
  16GB at Q4-ish quantization, possibly wanting a slightly lower quant or a
  trimmed context window to leave headroom) while running about as fast as
  a 3B one. If that MoE memory footprint is inconvenient, the previous-gen
  `Qwen2.5-Coder` line (7B/14B/32B, dense, Apache 2.0) sizes more
  predictably - 14B at Q4 is a comfortable fit.
  - Qwen publishes this model as two *official* safetensors releases -
    `-Instruct` (BF16, ~62GB, the reference release) and `-Instruct-FP8`
    (~31GB, block-quantized FP8) - neither is meant for Ollama/llama.cpp:
    the FP8 card only lists Transformers/vLLM/SGLang as supported engines,
    and the base card itself points to its GGUF derivatives instead of
    suggesting you run it directly. For this hardware's actual toolchain,
    go straight to a GGUF quantization, e.g.
    [unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF](https://huggingface.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF)
    (Q4_K_M/IQ4_XS to start, Q3 if that doesn't leave enough headroom for
    context) - there's also a pre-packaged community Ollama tag,
    `renchris/qwen3-coder:30b-gguf-unsloth`, if you'd rather not handle GGUF
    files yourself. The FP8 release itself only became a genuinely good fit
    for this GPU once FP8 MoE support for gfx1201 merged into vLLM mainline
    (2026-04) - worth revisiting if a future vLLM-based setup is ever on the
    table, but orthogonal to the Ollama/llama.cpp path above.
- **DeepSeek** - skip the actual DeepSeek-V3/R1 flagship models entirely;
  even quantized aggressively they need 80GB+ of VRAM, nowhere close to
  fitting one consumer GPU. The practical local DeepSeek picks are
  different, smaller releases: `DeepSeek-Coder-V2-Lite` (16B, MoE with
  ~2.4B active, purpose-built for code, a comfortable ~12GB fit) and the
  `DeepSeek-R1-Distill` line (reasoning-focused rather than coding-specific,
  MIT-licensed, 14B is comfortable, 32B is a tight fit like the Qwen3-Coder
  MoE above).
- **Gemma** - not a coding specialist family, but a solid general-purpose
  option if you'd rather have one model that also handles non-coding tasks
  well (it's multimodal). `Gemma 3`/`Gemma 4` in the 12B range is a
  comfortable ~10GB fit; the 27B/31B range is a tight fit at 16GB, similar
  to the models above.
- **What's not locally feasible despite topping the leaderboards:** GLM-5.x
  and Kimi K2.x currently rank at or near the top for agentic coding
  benchmarks, but they're 700B-1T parameter MoE models - even the most
  aggressive community quantizations need 150-350GB, or heavy CPU-offload
  rigs with hundreds of GB of system RAM. Worth knowing they exist and lead
  the benchmarks, but they're not a fit for a single desktop GPU.

Given all that, `Qwen3-Coder-30B-A3B` (or `Qwen2.5-Coder-14B` if the MoE
footprint is annoying to fit) is the sensible starting point for coding
specifically on this hardware.

**Navigating the rest of Hugging Face's model space** (this genuinely can't
be reduced to a fixed list - it changes monthly): for agentic coding
specifically, rank candidates by SWE-bench Verified score (measures
resolving real GitHub issues through a multi-turn tool loop, the metric
current comparisons actually use, rather than older single-shot benchmarks
like HumanEval). For a runnable version of whatever model you land on,
search for a GGUF quantization from Unsloth or bartowski - they're the
community's go-to for turning a fresh research release into something
Ollama/llama.cpp can actually load, usually within days of release.
r/LocalLLaMA is the most current source for "what's actually good this
month" given the pace here; Ollama's own library (ollama.com/library)
covers the popular, already-packaged options with sane default
quantizations if you'd rather not hunt.

**Other local-model runtimes besides Ollama** (2026 landscape):

- **LM Studio** - `pkgs.lmstudio` is packaged in nixpkgs. GUI-first (model
  browser, chat interface, no terminal needed), trading away Ollama's
  one-click simplicity for a friendlier way to discover/compare models.
  Also natively wired into VS Code's Copilot Chat model picker as of the
  same 2026 updates, via "Other Models" → custom endpoint at
  `http://localhost:1234/v1` (there's also a dedicated "LM Studio for
  Copilot Chat" extension for tighter integration).
- **llama.cpp directly** - `pkgs.llama-cpp` (nixpkgs build flags:
  `rocmSupport`, following the global `nixpkgs.config.rocmSupport`; `vulkanSupport`,
  off by default, needs `pkgs.llama-cpp.override { vulkanSupport = true; }`).
  Worth naming specifically because current tool comparisons rate llama.cpp
  as having the best ROCm support of this group - both Ollama and LM Studio
  wrap it internally anyway, so running its own `llama-server` (which also
  speaks the OpenAI-compatible API VS Code's custom-endpoint option expects)
  trades a rawer, CLI-only experience for the most direct path to whatever
  ROCm/Vulkan support actually exists for gfx1201 at any given time.
- **What to skip:** vLLM, SGLang, and TensorRT-LLM are built for
  multi-user serving throughput - no benefit over the above for a single
  desktop.

**LLM help: high** for the NixOS packaging side (`services.ollama`, picking
the right package variant/GPU flags) - directly in this repo's own idiom.

**Where it'd plug in:** `services.ollama` in `configuration.nix`, fully
declarative like everything else here.
