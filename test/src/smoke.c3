module miniaudio_smoke;

import ma;
import std::math;

const char[*] WAV = $embed("../fixtures/tone.wav");
const char[*] FLAC = $embed("../fixtures/tone.flac");
const char[*] MP3 = $embed("../fixtures/tone.mp3");
const char[*] OGG = $embed("../fixtures/tone.ogg");

const uint SAMPLE_RATE = 48000;
const uint ENGINE_CHANNELS = 2;
const ulong FIXTURE_FRAMES = 12000;
const ulong MP3_FRAME_TOLERANCE = 2304; // two MPEG-1 Layer III granules of encoder delay and padding
const ulong READ_BATCH_FRAMES = 1024;
const float AUDIBLE_PEAK = 0.1f;

fn char[] allocate_object(usz size) {
    char[] storage = mem::new_array(char, (sz)ma::stride(size));
    assert((uptr)storage.ptr % ma::object_alignment() == 0);
    return storage;
}

fn ulong decode_all(char[] bytes, ulong* reported_length, uint* channels, uint* sample_rate) {
    char[] storage = allocate_object(ma::decoder_size());
    defer free(storage);
    ma::Decoder* decoder = (ma::Decoder*)storage.ptr;
    assert(ma::decoder_init_memory(bytes.ptr, bytes.len, null, decoder) == ma::SUCCESS);
    defer ma::decoder_uninit(decoder);

    ma::Format format;
    assert(ma::decoder_get_data_format(decoder, &format, channels, sample_rate, null, 0) == ma::SUCCESS);
    assert(format == ma::Format.F32);
    assert(ma::decoder_get_length_in_pcm_frames(decoder, reported_length) == ma::SUCCESS);

    float[] frames = mem::new_array(float, READ_BATCH_FRAMES * *channels);
    defer free(frames);
    ulong total;
    while (true) {
        ulong read;
        ma::Result result = ma::decoder_read_pcm_frames(decoder, frames.ptr, READ_BATCH_FRAMES, &read);
        total += read;
        if (result != ma::SUCCESS || read == 0) break;
    }
    return total;
}

fn void expect_fixture(char[] bytes, ulong tolerance) {
    ulong reported_length;
    uint channels;
    uint sample_rate;
    ulong decoded = decode_all(bytes, &reported_length, &channels, &sample_rate);
    assert(channels == 1);
    assert(sample_rate == SAMPLE_RATE);
    ulong low = FIXTURE_FRAMES - tolerance;
    ulong high = FIXTURE_FRAMES + tolerance;
    assert(decoded >= low && decoded <= high, "decoded %d frames", decoded);
    assert(reported_length >= low && reported_length <= high, "reported %d frames", reported_length);
}

fn void test_size_shims_report_object_sizes() @test {
    assert(ma::engine_size() > 0);
    assert(ma::sound_size() > 0);
    assert(ma::decoder_size() > 0);
    assert(ma::audio_buffer_size() > 0);
    assert(ma::object_alignment() >= 8);
    assert(ma::stride(ma::sound_size()) % ma::object_alignment() == 0);
}

fn void test_wav_decodes_to_known_length() @test {
    expect_fixture(WAV[..], 0);
}

fn void test_flac_decodes_to_known_length() @test {
    expect_fixture(FLAC[..], 0);
}

fn void test_ogg_decodes_to_known_length() @test {
    expect_fixture(OGG[..], 0);
}

fn void test_mp3_decodes_within_encoder_padding() @test {
    expect_fixture(MP3[..], MP3_FRAME_TOLERANCE);
}

fn void test_engine_without_device_mixes_a_decoded_sound() @test {
    char[] engine_storage = allocate_object(ma::engine_size());
    defer free(engine_storage);
    ma::Engine* engine = (ma::Engine*)engine_storage.ptr;
    assert(ma::engine_init(engine, ENGINE_CHANNELS, SAMPLE_RATE, true, null) == ma::SUCCESS);
    defer ma::engine_uninit(engine);
    assert(ma::engine_get_channels(engine) == ENGINE_CHANNELS);
    assert(ma::engine_get_sample_rate(engine) == SAMPLE_RATE);

    char[] decoder_storage = allocate_object(ma::decoder_size());
    defer free(decoder_storage);
    ma::Decoder* decoder = (ma::Decoder*)decoder_storage.ptr;
    assert(ma::decoder_init_memory(WAV[..].ptr, WAV.len, null, decoder) == ma::SUCCESS);
    defer ma::decoder_uninit(decoder);

    char[] sound_storage = allocate_object(ma::sound_size());
    defer free(sound_storage);
    ma::Sound* sound = (ma::Sound*)sound_storage.ptr;
    assert(ma::sound_init_from_data_source(
        engine: engine,
        data_source: decoder,
        flags: 0,
        group: null,
        sound: sound,
    ) == ma::SUCCESS);
    defer ma::sound_uninit(sound);
    assert(ma::sound_start(sound) == ma::SUCCESS);

    float[] frames = mem::new_array(float, READ_BATCH_FRAMES * ENGINE_CHANNELS);
    defer free(frames);
    ulong read;
    assert(ma::engine_read_pcm_frames(engine, frames.ptr, READ_BATCH_FRAMES, &read) == ma::SUCCESS);
    assert(read == READ_BATCH_FRAMES);
    float peak;
    foreach (sample : frames) peak = math::max(peak, math::abs(sample));
    assert(peak > AUDIBLE_PEAK, "peak %f", peak);
}

struct AllocationCounts {
    usz malloc_count;
    usz free_count;
    usz outstanding_bytes;
}

const usz HEADER_BYTES = 16; // keeps the returned block 16-byte aligned and stores its size

fn void* counted_malloc(usz size, void* user) {
    AllocationCounts* counts = (AllocationCounts*)user;
    char* block = (char*)mem::malloc((sz)(size + HEADER_BYTES));
    *(usz*)block = size;
    counts.malloc_count++;
    counts.outstanding_bytes += size;
    return block + HEADER_BYTES;
}

fn void counted_free(void* pointer, void* user) {
    if (!pointer) return;
    AllocationCounts* counts = (AllocationCounts*)user;
    char* block = (char*)pointer - HEADER_BYTES;
    counts.free_count++;
    counts.outstanding_bytes -= *(usz*)block;
    mem::free(block);
}

fn void* counted_realloc(void* pointer, usz size, void* user) {
    if (!pointer) return counted_malloc(size, user);
    AllocationCounts* counts = (AllocationCounts*)user;
    char* block = (char*)pointer - HEADER_BYTES;
    usz old_size = *(usz*)block;
    char* moved = (char*)mem::malloc((sz)(size + HEADER_BYTES));
    *(usz*)moved = size;
    mem::copy(moved + HEADER_BYTES, pointer, (sz)(old_size < size ? old_size : size));
    mem::free(block);
    counts.outstanding_bytes = counts.outstanding_bytes - old_size + size;
    return moved + HEADER_BYTES;
}

fn void test_allocation_callbacks_route_every_allocation() @test {
    AllocationCounts counts;
    ma::AllocationCallbacks callbacks = {
        .user = &counts,
        .on_malloc = &counted_malloc,
        .on_realloc = &counted_realloc,
        .on_free = &counted_free,
    };
    float peak;
    {
        char[] engine_storage = allocate_object(ma::engine_size());
        defer free(engine_storage);
        ma::Engine* engine = (ma::Engine*)engine_storage.ptr;
        assert(ma::engine_init(engine, ENGINE_CHANNELS, SAMPLE_RATE, true, &callbacks) == ma::SUCCESS);

        char[] decoder_storage = allocate_object(ma::decoder_size());
        defer free(decoder_storage);
        ma::Decoder* decoder = (ma::Decoder*)decoder_storage.ptr;
        assert(ma::decoder_init_memory(WAV[..].ptr, WAV.len, &callbacks, decoder) == ma::SUCCESS);

        char[] sound_storage = allocate_object(ma::sound_size());
        defer free(sound_storage);
        ma::Sound* sound = (ma::Sound*)sound_storage.ptr;
        assert(ma::sound_init_from_data_source(
            engine: engine,
            data_source: decoder,
            flags: 0,
            group: null,
            sound: sound,
        ) == ma::SUCCESS);
        assert(ma::sound_start(sound) == ma::SUCCESS);

        float[] frames = mem::new_array(float, READ_BATCH_FRAMES * ENGINE_CHANNELS);
        defer free(frames);
        ulong read;
        assert(ma::engine_read_pcm_frames(engine, frames.ptr, READ_BATCH_FRAMES, &read) == ma::SUCCESS);
        foreach (sample : frames) peak = math::max(peak, math::abs(sample));

        assert(counts.malloc_count > 0);
        ma::sound_uninit(sound);
        ma::decoder_uninit(decoder);
        ma::engine_uninit(engine);
    }
    assert(counts.outstanding_bytes == 0, "outstanding %d", counts.outstanding_bytes);
    assert(counts.free_count == counts.malloc_count, "malloc %d free %d", counts.malloc_count, counts.free_count);
    assert(peak > AUDIBLE_PEAK, "peak %f", peak);
}
