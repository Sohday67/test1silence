/*
 * SSVoiceBoostState.h
 * SkipSilenceYT
 *
 * Public layout for the silence-detection + voice-boost state.
 * Field order, types, and offsets mirror the `voice_boost_t` struct
 * recovered from the Overcast binary's @encode string. See
 * OvercastAnalysis.md §3.5.
 */

#ifndef SS_VOICE_BOOST_STATE_H
#define SS_VOICE_BOOST_STATE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Recovered @encode:
 *   ^{voice_boost_t=IIBBBBBBBffq^{?}^{?}^{?}^{?}^{?}^{?}^{?}^{?}ffiB^^{?}i}
 *
 * Decoded:
 *   I  = uint32_t
 *   B  = BOOL / uint8_t
 *   f  = float
 *   q  = int64_t
 *   ^{?} = opaque pointer
 *   ^^{?} = opaque pointer-to-pointer
 *   i  = int32_t
 */
typedef struct SSVoiceBoostState {
    uint32_t  sample_rate;                 /* offset 0x00 */
    uint32_t  channels;                    /* offset 0x04 */
    uint8_t   use_smart_speed;             /* offset 0x08 */
    uint8_t   use_smart_speed_music_detection; /* 0x09 */
    uint8_t   skip_silences;               /* offset 0x0A */
    uint8_t   use_voice_boost;             /* offset 0x0B */
    uint8_t   is_smart_speed_bypassed;     /* offset 0x0C */
    uint8_t   is_analyzing;                /* offset 0x0D */
    uint8_t   has_wait_for_render_silence_semaphore; /* 0x0E */
    uint8_t   _pad0;                       /* offset 0x0F (alignment) */
    float     loudness_target_lufs;        /* offset 0x10 */
    float     target_lufs;                 /* offset 0x14 */
    int64_t   timeline_silence_skipped_samples; /* offset 0x18 */
    void     *circular_buffer;             /* offset 0x20 - TPCircularBuffer* */
    void     *lookahead_buffer;            /* offset 0x28 */
    void     *scratch_buffer;              /* offset 0x30 */
    void     *lufs_filter_state;           /* offset 0x38 - SSLUFSState* */
    void     *lufs_window;                 /* offset 0x40 */
    void     *render_context;              /* offset 0x48 - AudioConverterRef */
    void     *streamer_ref;                /* offset 0x50 */
    void     *voice_boost_assertion_handler; /* offset 0x58 */
    float     average_lufs;                /* offset 0x60 */
    float     peak_lufs;                   /* offset 0x64 */
    int32_t   premeasured_average_lufs;    /* offset 0x68 */
    uint8_t   premeasured_available;       /* offset 0x6C */
    uint8_t   _pad1[3];                    /* offset 0x6D (alignment) */
    int64_t  *timeline_silence_skipped_array; /* offset 0x70 - 256-entry ring */
    int32_t   timeline_index;              /* offset 0x78 */
} SSVoiceBoostState;

/* Initialize a freshly allocated state. */
void ss_voice_boost_state_init(SSVoiceBoostState *st,
                               uint32_t sample_rate,
                               uint32_t channels);

/* Clear external pointers (does NOT free sub-objects; their owners do that). */
void ss_voice_boost_state_free(SSVoiceBoostState *st);

#ifdef __cplusplus
}
#endif

#endif /* SS_VOICE_BOOST_STATE_H */
