# miniaudio.c3l

C3 bindings for [miniaudio](https://github.com/mackron/miniaudio), a single-file C audio library by
David Reid. Module `ma`, package `miniaudio`, C3 0.8.3, miniaudio `0.11.25` at
`9634bedb5b5a2ca38c1ee7108a9358a4e233f14d`.

The binding covers the engine, sounds, sound groups, memory decoders and audio buffers. It is
thin: `src/ma.c3i` declares the bound functions with `@cname`, and `src/ma.c3` adds a result
check and a table stride helper.

## Using it

Add the repository as a git submodule (with `--recursive`, for `vendor/miniaudio`) into the
directory your project searches for libraries, then name `miniaudio` as a dependency:

```json
{
  "dependency-search-paths": [ "lib" ],
  "dependencies": [ "miniaudio" ]
}
```

`csrc/miniaudio.c` compiles through the package's `c-sources` on `linux-x64` and `windows-x64`.
Linux links `dl`, `pthread` and `m`. Windows links nothing: miniaudio loads the system audio DLLs
at run time, and the target sets `"wincrt": "static"`.

## Build defines

`csrc/miniaudio.c` defines these before the implementation. Struct layouts depend on them, so
they are fixed by the package:

| Define | Effect |
| --- | --- |
| `MA_NO_RESOURCE_MANAGER` | No resource manager and no job thread; sounds come from data sources |
| `MA_NO_ENCODING` | No WAV encoder |
| `MA_NO_GENERATION` | No waveform or noise generators |
| `MA_ENGINE_MAX_LISTENERS 1` | One listener |

Decoders: WAV, FLAC and MP3 (built in) and Ogg Vorbis (`extras/stb_vorbis.c`, included in the
same translation unit). Decoded output is `f32`.

## Objects are opaque

`Engine`, `Sound` (also `SoundGroup`), `Decoder` and `AudioBuffer` are opaque in C3. They cross
the API by pointer only, must not move or be copied, and the caller allocates their storage.
Query the run-time size from the package, so a version or define change cannot desync C3:

| Shim | Returns |
| --- | --- |
| `ma::engine_size()` | `sizeof(ma_engine)` |
| `ma::sound_size()` | `sizeof(ma_sound)`, also the group size |
| `ma::decoder_size()` | `sizeof(ma_decoder)` |
| `ma::audio_buffer_size()` | `sizeof(ma_audio_buffer)` |
| `ma::object_alignment()` | The largest alignment of the four |
| `ma::stride(size)` | `size` rounded up to the alignment, for tables |

Allocate storage aligned to `ma::object_alignment()`.

Configs are built in C, so C3 mirrors no config struct:

| Shim | Does |
| --- | --- |
| `ma::engine_init(engine, channels, sample_rate, no_device, callbacks)` | Initializes an engine; `no_device` needs no thread |
| `ma::decoder_init_memory(bytes, length, callbacks, decoder)` | Decodes to `f32` at the source channels and rate; `bytes` must outlive the decoder |
| `ma::audio_buffer_init(frames, frame_count, channels, sample_rate, callbacks, buffer)` | References `f32` frames and sets the sample rate explicitly |

Pass `null` callbacks for the default allocator. `ma::AllocationCallbacks` mirrors
`ma_allocation_callbacks` (32 bytes, pinned with `$assert`).

## Example

```c3
import ma;

fn void play(char[] encoded) {
    char[] engine_storage = mem::new_array(char, (sz)ma::stride(ma::engine_size()));
    char[] decoder_storage = mem::new_array(char, (sz)ma::stride(ma::decoder_size()));
    char[] sound_storage = mem::new_array(char, (sz)ma::stride(ma::sound_size()));
    ma::Engine* engine = (ma::Engine*)engine_storage.ptr;
    ma::Decoder* decoder = (ma::Decoder*)decoder_storage.ptr;
    ma::Sound* sound = (ma::Sound*)sound_storage.ptr;

    ma::check(ma::engine_init(engine, 2, 48000, true, null))!!;
    ma::check(ma::decoder_init_memory(encoded.ptr, encoded.len, null, decoder))!!;
    ma::check(ma::sound_init_from_data_source(engine, decoder, 0, null, sound))!!;
    ma::check(ma::sound_start(sound))!!;

    float[] frames = mem::new_array(float, 1024 * 2);
    ulong read;
    ma::check(ma::engine_read_pcm_frames(engine, frames.ptr, 1024, &read))!!;
}
```

With `no_device` the engine runs no thread and no device: audio advances only inside
`engine_read_pcm_frames`, on the calling thread. Uninitialize sounds before the engine, and
the decoder after its sound.

## Tests

```sh
c3c compile-only --no-obj src/*.c3i src/*.c3 && rm -rf obj
cd test && c3c test
```

The tests decode WAV, FLAC, MP3 and Ogg fixtures and mix a sound through a no-device engine.
`test/fixtures/README.md` lists the encode commands.

## Licence

The binding is MIT No Attribution (`LICENSE`). miniaudio and stb_vorbis keep their own
public-domain/MIT-0 and MIT choices; see `NOTICE`.
