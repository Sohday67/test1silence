/*
 * SSVoiceBoostState.c
 * SkipSilenceYT
 *
 * This file declares and initializes a state struct whose layout
 * matches the `voice_boost_t` struct recovered from the Overcast
 * binary's `@encode` string:
 *
 *   ^{voice_boost_t=IIBBBBBBBffq^{?}^{?}^{?}^{?}^{?}^{?}^{?}^{?}ffiB^^{?}i}
 *
 * See OvercastAnalysis.md §3.5 for the recovered field map. The
 * field order, types, and offsets are preserved verbatim so that
 * any disassembly comparison against the original Overcast binary
 * lines up.
 *
 * No code from the Overcast binary is included; only the layout
 * (which is not copyrightable) is reproduced for interoperability.
 */

#include "SSVoiceBoostState.h"
#include <stdlib.h>
#include <string.h>

void ss_voice_boost_state_init(SSVoiceBoostState *st,
                               uint32_t sample_rate,
                               uint32_t channels) {
    if (!st) return;
    memset(st, 0, sizeof(*st));
    st->sample_rate = sample_rate;
    st->channels = channels;
    st->use_smart_speed = 0;
    st->use_smart_speed_music_detection = 0;
    st->skip_silences = 0;
    st->use_voice_boost = 0;
    st->is_smart_speed_bypassed = 0;
    st->is_analyzing = 0;
    st->has_wait_for_render_silence_semaphore = 0;

    /* Defaults recovered from Overcast's settings panel strings:
     *   - "loudnessTargetLUFS" is in whole LUFS. -23 LUFS is broadcast
     *     standard (EBU R128), which Overcast uses as the absolute
     *     fallback when no program-average has been measured yet.
     *   - "targetLUFS" is the Voice Boost target. -16 LUFS is the
     *     mobile / podcast loudness target.
     */
    st->loudness_target_lufs = -23.0f;
    st->target_lufs = -16.0f;
    st->timeline_silence_skipped_samples = 0;

    st->circular_buffer = NULL;       /* TPCircularBuffer (allocated at runtime) */
    st->lookahead_buffer = NULL;
    st->scratch_buffer = NULL;
    st->lufs_filter_state = NULL;     /* SSLUFSState* */
    st->lufs_window = NULL;           /* 400 ms window accumulator */
    st->render_context = NULL;        /* AudioConverterRef */
    st->streamer_ref = NULL;
    st->voice_boost_assertion_handler = NULL;

    st->average_lufs = -70.0f;        /* silence floor before first measurement */
    st->peak_lufs = -70.0f;
    st->premeasured_average_lufs = 0; /* int32 representation, BS.1770 fixed-point */
    st->premeasured_available = 0;
    st->timeline_silence_skipped_array = NULL;
    st->timeline_index = 0;
}

void ss_voice_boost_state_free(SSVoiceBoostState *st) {
    if (!st) return;
    /* Caller-owned sub-objects (LUFS state, buffers, converter) are
     * released by their owners; here we only clear pointers. */
    st->circular_buffer = NULL;
    st->lookahead_buffer = NULL;
    st->scratch_buffer = NULL;
    st->lufs_filter_state = NULL;
    st->lufs_window = NULL;
    st->render_context = NULL;
    st->streamer_ref = NULL;
    st->voice_boost_assertion_handler = NULL;
    st->timeline_silence_skipped_array = NULL;
}
