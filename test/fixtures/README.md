# Fixtures

`tone.wav` is a 0.25 s, 440 Hz, mono, 48 kHz, 16-bit PCM sine at half amplitude (12000 frames).
`generate.py` writes it with the Python standard library only.

The other fixtures are encoded from it with ffmpeg 6 or later, with `-map_metadata -1` and bitexact
flags so the encode is repeatable:

```sh
python3 generate.py
common="-v error -y -i tone.wav -map_metadata -1 -fflags +bitexact -flags:a +bitexact"
ffmpeg $common -c:a flac tone.flac
ffmpeg $common -c:a libmp3lame -b:a 128k tone.mp3
ffmpeg $common -c:a libvorbis -q:a 4 tone.ogg
```

The tests embed the files at compile time. Each decodes to 12000 frames at 48 kHz mono; the MP3 check
allows two granules (2304 frames) for encoder delay and padding.
