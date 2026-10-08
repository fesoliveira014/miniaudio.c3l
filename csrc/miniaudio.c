#ifdef _MSC_VER
#define _CRT_SECURE_NO_WARNINGS
#endif

#include <stdbool.h>
#include <stddef.h>

#define MA_NO_RESOURCE_MANAGER
#define MA_NO_ENCODING
#define MA_NO_GENERATION
#define MA_ENGINE_MAX_LISTENERS 1

#ifdef _MSC_VER
#pragma warning(push)
#pragma warning(disable: 4245 4456 4457 4701)
#endif

#define STB_VORBIS_HEADER_ONLY
#include "../vendor/miniaudio/extras/stb_vorbis.c"

#define MINIAUDIO_IMPLEMENTATION
#include "../vendor/miniaudio/miniaudio.h"

#undef STB_VORBIS_HEADER_ONLY
#include "../vendor/miniaudio/extras/stb_vorbis.c"

#ifdef _MSC_VER
#pragma warning(pop)
#endif

#define C3MA_ALIGNMENT_OF(type) offsetof(struct { char padding; type value; }, value)

size_t c3ma_engine_size(void) {
    return sizeof(ma_engine);
}

size_t c3ma_sound_size(void) {
    return sizeof(ma_sound);
}

size_t c3ma_decoder_size(void) {
    return sizeof(ma_decoder);
}

size_t c3ma_audio_buffer_size(void) {
    return sizeof(ma_audio_buffer);
}

size_t c3ma_object_alignment(void) {
    size_t alignment = C3MA_ALIGNMENT_OF(ma_engine);
    if (C3MA_ALIGNMENT_OF(ma_sound) > alignment) {
        alignment = C3MA_ALIGNMENT_OF(ma_sound);
    }
    if (C3MA_ALIGNMENT_OF(ma_decoder) > alignment) {
        alignment = C3MA_ALIGNMENT_OF(ma_decoder);
    }
    if (C3MA_ALIGNMENT_OF(ma_audio_buffer) > alignment) {
        alignment = C3MA_ALIGNMENT_OF(ma_audio_buffer);
    }
    return alignment;
}

ma_result c3ma_engine_init(
    ma_engine* engine,
    ma_uint32 channels,
    ma_uint32 sample_rate,
    bool no_device,
    const ma_allocation_callbacks* callbacks
) {
    ma_engine_config config = ma_engine_config_init();
    config.channels = channels;
    config.sampleRate = sample_rate;
    config.noDevice = no_device ? MA_TRUE : MA_FALSE;
    if (callbacks != NULL) {
        config.allocationCallbacks = *callbacks;
    }
    return ma_engine_init(&config, engine);
}

ma_result c3ma_decoder_init_memory(
    const void* bytes,
    size_t length,
    const ma_allocation_callbacks* callbacks,
    ma_decoder* decoder
) {
    ma_decoder_config config = ma_decoder_config_init(ma_format_f32, 0, 0);
    if (callbacks != NULL) {
        config.allocationCallbacks = *callbacks;
    }
    return ma_decoder_init_memory(bytes, length, &config, decoder);
}

ma_result c3ma_audio_buffer_init(
    const float* frames,
    ma_uint64 frame_count,
    ma_uint32 channels,
    ma_uint32 sample_rate,
    const ma_allocation_callbacks* callbacks,
    ma_audio_buffer* buffer
) {
    ma_audio_buffer_config config = ma_audio_buffer_config_init(ma_format_f32, channels, frame_count, frames, callbacks);
    config.sampleRate = sample_rate;
    return ma_audio_buffer_init(&config, buffer);
}
