/*
 * SSLUFS.h
 * SkipSilenceYT
 *
 * ITU-R BS.1770-4 LUFS measurement, ported algorithmically from
 * Overcast's `lufs_process_chunk` C function (see OvercastAnalysis.md).
 *
 * Public domain algorithm (international standard). This header and
 * its implementation are MIT-licensed.
 */

#ifndef SS_LUFS_H
#define SS_LUFS_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    double sample_rate;
    unsigned channels;

    /* K-weighting biquad coefficients: [b0, b1, b2, a1, a2]
     * a1 / a2 are negated so the difference equation is purely additive. */
    double stage1[5];  /* high-shelf pre-filter */
    double stage2[5];  /* high-pass (RLB) */

    /* Per-channel filter state (Direct Form I Transposed) */
    double stage1_z1[8][2];
    double stage2_z1[8][2];

    /* Per-channel BS.1770 weighting (1.0 / 1.0 / 1.0 / 1.41 / 1.41 / ...) */
    double channel_weight[8];

    /* Mean-square accumulator + frame counter for the current 400 ms block */
    double mean_square_acc[8];
    unsigned frames_since_last_block;

    /* Finalized block loudness in LUFS */
    double last_lufs;
} SSLUFSState;

/* Initialize a LUFS state for the given sample rate and channel count. */
void sslufs_init(SSLUFSState *st, double sample_rate, unsigned channels);

/* Process one chunk of planar float32 samples. */
void sslufs_process_chunk(SSLUFSState *st,
                          const float * const *channels_data,
                          unsigned channel_count,
                          unsigned frame_count);

/* Process one chunk of interleaved float32 samples. */
void sslufs_process_interleaved(SSLUFSState *st,
                                const float *samples,
                                unsigned channel_count,
                                unsigned frame_count);

/* Force-finalize the current 400 ms block and return its LUFS. */
double sslufs_finalize_block(SSLUFSState *st);

/* Return the last finalized block LUFS. */
double sslufs_current_lufs(const SSLUFSState *st);

#ifdef __cplusplus
}
#endif

#endif /* SS_LUFS_H */
