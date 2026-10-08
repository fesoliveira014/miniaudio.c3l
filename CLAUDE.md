# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

C3 bindings for [miniaudio](https://github.com/mackron/miniaudio) (single-header C audio library,
public domain or MIT-0), packaged as a C3 library (`.c3l`), not a standalone program.

- `manifest.json` provides the `miniaudio` package for the `ma` module. `"sources": [ "src/**" ]`
  replaces the default scan of the package root: a `.c3` left at the root is silently not compiled.
  `"c-sources": [ "csrc/miniaudio.c" ]` compiles the implementation with the consumer's C compiler
  on every target; there is no native archive.
- `src/ma.c3i` is the raw layer: types and every bound C function as `extern fn ... @cname(...)`.
  `src/ma.c3` is the idiomatic layer: `check`, `stride` and layout `$assert`s.
- `csrc/miniaudio.c` is the one implementation unit. It sets the `MA_*` defines, includes
  stb_vorbis as a header, then miniaudio, then stb_vorbis again, and defines the `c3ma_*` shims
  (object sizes and alignment, engine, decoder and audio buffer initializers).
- `vendor/miniaudio/` is the upstream repository as a git submodule, pinned to a release tag.
  Read the real declaration in `vendor/miniaudio/miniaudio.h` before writing or changing any C3
  declaration; a wrong field or parameter type is a silent cross-ABI memory bug.
- `test/` is a standalone consumer project. `test/libs/miniaudio.c3l` is a symlink to the
  repository root because c3c resolves a dependency as `<search-path>/<name>.c3l`.
  `cd test && c3c test` compiles the binding and runs `src/smoke.c3`.

## Authoring rules

- Invoke the `c3-expert`, `c3-style` and `c3-bindings` skills before writing, editing or
  reviewing any C3 or diagnosing a c3c error. C3 is 0.8.3 here and pre-1.0.
- Do not run `c3fmt`. Hand-format: K&R braces, four spaces.
- Docstrings on every public wrapper in `src/ma.c3` (raw externs carry none): one summary line,
  `@param` for pointers and any parameter its name does not explain. No narration.
- No development vocabulary in code: no ticket references, plan steps or milestone names.

## Binding conventions

- The `ma_` prefix is the module name, never part of an identifier: `ma::sound_start`, not
  `ma::ma_sound_start`. Functions `snake_case`, types `PascalCase`, constants and enum values
  `SCREAMING_SNAKE_CASE`, fields `snake_case`. No `@builtin`.
- `Engine`, `Sound`, `Decoder` and `AudioBuffer` are opaque (`typedef ... = void`). Callers
  allocate them with the sizes from the `c3ma_*_size` shims; sizes depend on the `MA_*` defines
  and the miniaudio version, so no size is hard-coded in C3.
- Config structs are built in C shims. Do not mirror them in C3.
- `ma_bool32` is `Bool32` (`uint`), never C3 `bool`. The shims take a C `bool` where the
  parameter is a C3 `bool`.
- Bind only the surface the add-on uses. Every `MA_*` define is fixed by `csrc/miniaudio.c`;
  changing one changes struct layouts and every size.
- After a miniaudio upgrade, re-read the header for each bound declaration and the struct
  layout of `AllocationCallbacks`.

## Verification

```sh
c3c compile-only --no-obj src/*.c3i src/*.c3 && rm -rf obj
cd test && c3c test
```
