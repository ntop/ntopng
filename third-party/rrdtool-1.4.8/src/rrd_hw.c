/*****************************************************************************
 * RRDtool 1.4.8  Copyright by Tobi Oetiker, 1997-2013
 *****************************************************************************
 * rrd_hw.c : Support for Holt-Winters Smoothing/ Aberrant Behavior Detection
 *****************************************************************************
 * Initial version by Jake Brutlag, WebTV Networks, 5/1/00
 *****************************************************************************/

#include <stdlib.h>

#include "rrd_tool.h"
#include "rrd_hw.h"
#include "rrd_hw_math.h"
#include "rrd_hw_update.h"

#define hw_dep_idx(rrd, rra_idx) rrd->rra_def[rra_idx].par[RRA_dependent_rra_idx].u_cnt

/* #define DEBUG */

/* private functions */
static unsigned long MyMod(
    signed long val,
    unsigned long mod);

int lookup_seasonal(
    rrd_t *rrd,
    unsigned long rra_idx,
    unsigned long rra_start,
    rrd_file_t *rrd_file,
    unsigned long offset,
    rrd_value_t **seasonal_coef)
{
    unsigned long pos_tmp;

    /* rra_ptr[].cur_row points to the rra row to be written; this function
     * reads cur_row + offset */
    unsigned long row_idx = rrd->rra_ptr[rra_idx].cur_row + offset;

    /* handle wrap around */
    if (row_idx >= rrd->rra_def[rra_idx].row_cnt)
        row_idx = row_idx % (rrd->rra_def[rra_idx].row_cnt);

    /* rra_start points to the appropriate rra block in the file */
    /* compute the pointer to the appropriate location in the file */
    pos_tmp =
        rra_start +
        (row_idx) * (rrd->stat_head->ds_cnt) * sizeof(rrd_value_t);

    /* allocate memory if need be */
    if (*seasonal_coef == NULL)
        *seasonal_coef =
            (rrd_value_t *) malloc((rrd->stat_head->ds_cnt) *
                                   sizeof(rrd_value_t));
    if (*seasonal_coef == NULL) {
        rrd_set_error("memory allocation failure: seasonal coef");
        return -1;
    }

    if (!rrd_seek(rrd_file, pos_tmp, SEEK_SET)) {
        if (rrd_read
            (rrd_file, *seasonal_coef,
             sizeof(rrd_value_t) * rrd->stat_head->ds_cnt)
            == (ssize_t) (sizeof(rrd_value_t) * rrd->stat_head->ds_cnt)) {
            /* success! */
            /* we can safely ignore the rule requiring a seek operation between read
             * and write, because this read moves the file pointer to somewhere
             * in the file other than the next write location.
             * */
            return 0;
        } else {
            rrd_set_error("read operation failed in lookup_seasonal(): %lu\n",
                          pos_tmp);
        }
    } else {
        rrd_set_error("seek operation failed in lookup_seasonal(): %lu\n",
                      pos_tmp);
    }

    return -1;
}

/* For the specified CDP prep area and the FAILURES RRA,
 * erase all history of past violations.
 */
void erase_violations(
    rrd_t *rrd,
    unsigned long cdp_idx,
    unsigned long rra_idx)
{
    unsigned short i;
    char     *violations_array;

    /* check that rra_idx is a CF_FAILURES array */
    if (cf_conv(rrd->rra_def[rra_idx].cf_nam) != CF_FAILURES) {
#ifdef DEBUG
        fprintf(stderr, "erase_violations called for non-FAILURES RRA: %s\n",
                rrd->rra_def[rra_idx].cf_nam);
#endif
        return;
    }
#ifdef DEBUG
    fprintf(stderr, "scratch buffer before erase:\n");
    for (i = 0; i < MAX_CDP_PAR_EN; i++) {
        fprintf(stderr, "%lu ", rrd->cdp_prep[cdp_idx].scratch[i].u_cnt);
    }
    fprintf(stderr, "\n");
#endif

    /* WARNING: an array of longs on disk is treated as an array of chars
     * in memory. */
    violations_array = (char *) ((void *) rrd->cdp_prep[cdp_idx].scratch);
    /* erase everything in the part of the CDP scratch array that will be
     * used to store violations for the current window */
    for (i = rrd->rra_def[rra_idx].par[RRA_window_len].u_cnt; i > 0; i--) {
        violations_array[i - 1] = 0;
    }
#ifdef DEBUG
    fprintf(stderr, "scratch buffer after erase:\n");
    for (i = 0; i < MAX_CDP_PAR_EN; i++) {
        fprintf(stderr, "%lu ", rrd->cdp_prep[cdp_idx].scratch[i].u_cnt);
    }
    fprintf(stderr, "\n");
#endif
}

/* Smooth a periodic array with a moving average: equal weights and
 * length = 5% of the period. */
int apply_smoother(
    rrd_t *rrd,
    unsigned long rra_idx,
    unsigned long rra_start,
    rrd_file_t *rrd_file)
{
    unsigned long i, j, k;
    unsigned long totalbytes;
    rrd_value_t *rrd_values;
    unsigned long row_length = rrd->stat_head->ds_cnt;
    unsigned long row_count = rrd->rra_def[rra_idx].row_cnt;
    unsigned long offset;
    FIFOqueue **buffers;
    rrd_value_t *working_average;
    rrd_value_t *baseline;

    if (atoi(rrd->stat_head->version) >= 4) {
        offset = floor(rrd->rra_def[rra_idx].
                       par[RRA_seasonal_smoothing_window].
                       u_val / 2 * row_count);
    } else {
        offset = floor(0.05 / 2 * row_count);
    }

    if (offset == 0)
        return 0;       /* no smoothing */

    /* allocate memory */
    totalbytes = sizeof(rrd_value_t) * row_length * row_count;
    rrd_values = (rrd_value_t *) malloc(totalbytes);
    if (rrd_values == NULL) {
        rrd_set_error("apply smoother: memory allocation failure");
        return -1;
    }

    /* rra_start is at the beginning of this rra */
    if (rrd_seek(rrd_file, rra_start, SEEK_SET)) {
        rrd_set_error("seek to rra %d failed", rra_start);
        free(rrd_values);
        return -1;
    }

    /* could read all data in a single block, but we need to
     * check for NA values */
    for (i = 0; i < row_count; ++i) {
        for (j = 0; j < row_length; ++j) {
            if (rrd_read
                (rrd_file, &(rrd_values[i * row_length + j]),
                 sizeof(rrd_value_t) * 1)
                != (ssize_t) (sizeof(rrd_value_t) * 1)) {
                rrd_set_error("reading value failed: %s",
                              rrd_strerror(errno));
            }
            if (isnan(rrd_values[i * row_length + j])) {
                /* can't apply smoothing, still uninitialized values */
#ifdef DEBUG
                fprintf(stderr,
                        "apply_smoother: NA detected in seasonal array: %ld %ld\n",
                        i, j);
#endif
                free(rrd_values);
                return 0;
            }
        }
    }

    /* allocate queues, one for each data source */
    buffers = (FIFOqueue **) malloc(sizeof(FIFOqueue *) * row_length);
    for (i = 0; i < row_length; ++i) {
        queue_alloc(&(buffers[i]), 2 * offset + 1);
    }
    /* need working average initialized to 0 */
    working_average = (rrd_value_t *) calloc(row_length, sizeof(rrd_value_t));
    baseline = (rrd_value_t *) calloc(row_length, sizeof(rrd_value_t));

    /* compute sums of the first 2*offset terms */
    for (i = 0; i < 2 * offset; ++i) {
        k = MyMod(i - offset, row_count);
        for (j = 0; j < row_length; ++j) {
            queue_push(buffers[j], rrd_values[k * row_length + j]);
            working_average[j] += rrd_values[k * row_length + j];
        }
    }

    /* compute moving averages */
    for (i = offset; i < row_count + offset; ++i) {
        for (j = 0; j < row_length; ++j) {
            k = MyMod(i, row_count);
            /* add a term to the sum */
            working_average[j] += rrd_values[k * row_length + j];
            queue_push(buffers[j], rrd_values[k * row_length + j]);

            /* reset k to be the center of the window */
            k = MyMod(i - offset, row_count);
            /* overwrite rdd_values entry, the old value is already
             * saved in buffers */
            rrd_values[k * row_length + j] =
                working_average[j] / (2 * offset + 1);
            baseline[j] += rrd_values[k * row_length + j];

            /* remove a term from the sum */
            working_average[j] -= queue_pop(buffers[j]);
        }
    }

    for (i = 0; i < row_length; ++i) {
        queue_dealloc(buffers[i]);
        baseline[i] /= row_count;
    }
    free(buffers);
    free(working_average);

    if (cf_conv(rrd->rra_def[rra_idx].cf_nam) == CF_SEASONAL) {
        rrd_value_t (
    *init_seasonality) (
    rrd_value_t seasonal_coef,
    rrd_value_t intercept);

        switch (cf_conv(rrd->rra_def[hw_dep_idx(rrd, rra_idx)].cf_nam)) {
        case CF_HWPREDICT:
            init_seasonality = hw_additive_init_seasonality;
            break;
        case CF_MHWPREDICT:
            init_seasonality = hw_multiplicative_init_seasonality;
            break;
        default:
            rrd_set_error("apply smoother: SEASONAL rra doesn't have "
                          "valid dependency: %s",
                          rrd->rra_def[hw_dep_idx(rrd, rra_idx)].cf_nam);
            return -1;
        }

        for (j = 0; j < row_length; ++j) {
            for (i = 0; i < row_count; ++i) {
                rrd_values[i * row_length + j] =
                    init_seasonality(rrd_values[i * row_length + j],
                                     baseline[j]);
            }
            /* update the baseline coefficient,
             * first, compute the cdp_index. */
            offset = hw_dep_idx(rrd, rra_idx) * row_length + j;
            (rrd->cdp_prep[offset]).scratch[CDP_hw_intercept].u_val +=
                baseline[j];
        }
        /* flush cdp to disk */
        if (rrd_seek(rrd_file, sizeof(stat_head_t) +
                     rrd->stat_head->ds_cnt * sizeof(ds_def_t) +
                     rrd->stat_head->rra_cnt * sizeof(rra_def_t) +
                     sizeof(live_head_t) +
                     rrd->stat_head->ds_cnt * sizeof(pdp_prep_t), SEEK_SET)) {
            rrd_set_error("apply_smoother: seek to cdp_prep failed");
            free(rrd_values);
            return -1;
        }
        if (rrd_write(rrd_file, rrd->cdp_prep,
                      sizeof(cdp_prep_t) *
                      (rrd->stat_head->rra_cnt) * rrd->stat_head->ds_cnt)
            != (ssize_t) (sizeof(cdp_prep_t) * (rrd->stat_head->rra_cnt) *
                          (rrd->stat_head->ds_cnt))) {
            rrd_set_error("apply_smoother: cdp_prep write failed");
            free(rrd_values);
            return -1;
        }
    }

    /* endif CF_SEASONAL */
    /* flush updated values to disk */
    if (rrd_seek(rrd_file, rra_start, SEEK_SET)) {
        rrd_set_error("apply_smoother: seek to pos %d failed", rra_start);
        free(rrd_values);
        return -1;
    }
    /* write as a single block */
    if (rrd_write
        (rrd_file, rrd_values, sizeof(rrd_value_t) * row_length * row_count)
        != (ssize_t) (sizeof(rrd_value_t) * row_length * row_count)) {
        rrd_set_error("apply_smoother: write failed to %lu", rra_start);
        free(rrd_values);
        return -1;
    }

    free(rrd_values);
    free(baseline);
    return 0;
}

/* Reset aberrant behavior model coefficients, including intercept, slope,
 * seasonal, and seasonal deviation for the specified data source. */
void reset_aberrant_coefficients(
    rrd_t *rrd,
    rrd_file_t *rrd_file,
    unsigned long ds_idx)
{
    unsigned long cdp_idx, rra_idx, i;
    unsigned long cdp_start, rra_start;
    rrd_value_t nan_buffer = DNAN;

    /* compute the offset for the cdp area */
    cdp_start = sizeof(stat_head_t) +
        rrd->stat_head->ds_cnt * sizeof(ds_def_t) +
        rrd->stat_head->rra_cnt * sizeof(rra_def_t) +
        sizeof(live_head_t) + rrd->stat_head->ds_cnt * sizeof(pdp_prep_t);
    /* compute the offset for the first rra */
    rra_start = cdp_start +
        (rrd->stat_head->ds_cnt) * (rrd->stat_head->rra_cnt) *
        sizeof(cdp_prep_t) + rrd->stat_head->rra_cnt * sizeof(rra_ptr_t);

    /* loop over the RRAs */
    for (rra_idx = 0; rra_idx < rrd->stat_head->rra_cnt; rra_idx++) {
        cdp_idx = rra_idx * (rrd->stat_head->ds_cnt) + ds_idx;
        switch (cf_conv(rrd->rra_def[rra_idx].cf_nam)) {
        case CF_HWPREDICT:
        case CF_MHWPREDICT:
            init_hwpredict_cdp(&(rrd->cdp_prep[cdp_idx]));
            break;
        case CF_SEASONAL:
        case CF_DEVSEASONAL:
            /* don't use init_seasonal because it will reset burn-in, which
             * means different data sources will be calling for the smoother
             * at different times. */
            rrd->cdp_prep[cdp_idx].scratch[CDP_hw_seasonal].u_val = DNAN;
            rrd->cdp_prep[cdp_idx].scratch[CDP_hw_last_seasonal].u_val = DNAN;
            /* move to first entry of data source for this rra */
            rrd_seek(rrd_file, rra_start + ds_idx * sizeof(rrd_value_t),
                     SEEK_SET);
            /* entries for the same data source are not contiguous, 
             * temporal entries are contiguous */
            for (i = 0; i < rrd->rra_def[rra_idx].row_cnt; ++i) {
                if (rrd_write(rrd_file, &nan_buffer, sizeof(rrd_value_t) * 1)
                    != sizeof(rrd_value_t) * 1) {
                    rrd_set_error
                        ("reset_aberrant_coefficients: write failed data source %lu rra %s",
                         ds_idx, rrd->rra_def[rra_idx].cf_nam);
                    return;
                }
                rrd_seek(rrd_file, (rrd->stat_head->ds_cnt - 1) *
                         sizeof(rrd_value_t), SEEK_CUR);
            }
            break;
        case CF_FAILURES:
            erase_violations(rrd, cdp_idx, rra_idx);
            break;
        default:
            break;
        }
        /* move offset to the next rra */
        rra_start += rrd->rra_def[rra_idx].row_cnt * rrd->stat_head->ds_cnt *
            sizeof(rrd_value_t);
    }
    rrd_seek(rrd_file, cdp_start, SEEK_SET);
    if (rrd_write(rrd_file, rrd->cdp_prep,
                  sizeof(cdp_prep_t) *
                  (rrd->stat_head->rra_cnt) * rrd->stat_head->ds_cnt)
        != (ssize_t) (sizeof(cdp_prep_t) * (rrd->stat_head->rra_cnt) *
                      (rrd->stat_head->ds_cnt))) {
        rrd_set_error("reset_aberrant_coefficients: cdp_prep write failed");
    }
}

void init_hwpredict_cdp(
    cdp_prep_t *cdp)
{
    cdp->scratch[CDP_hw_intercept].u_val = DNAN;
    cdp->scratch[CDP_hw_last_intercept].u_val = DNAN;
    cdp->scratch[CDP_hw_slope].u_val = DNAN;
    cdp->scratch[CDP_hw_last_slope].u_val = DNAN;
    cdp->scratch[CDP_null_count].u_cnt = 1;
    cdp->scratch[CDP_last_null_count].u_cnt = 1;
}

void init_seasonal_cdp(
    cdp_prep_t *cdp)
{
    cdp->scratch[CDP_hw_seasonal].u_val = DNAN;
    cdp->scratch[CDP_hw_last_seasonal].u_val = DNAN;
    cdp->scratch[CDP_init_seasonal].u_cnt = 1;
}

int update_aberrant_CF(
    rrd_t *rrd,
    rrd_value_t pdp_val,
    enum cf_en current_cf,
    unsigned long cdp_idx,
    unsigned long rra_idx,
    unsigned long ds_idx,
    unsigned short CDP_scratch_idx,
    rrd_value_t *seasonal_coef)
{
    static hw_functions_t hw_multiplicative_functions = {
        hw_multiplicative_calculate_prediction,
        hw_multiplicative_calculate_intercept,
        hw_calculate_slope,
        hw_multiplicative_calculate_seasonality,
        hw_multiplicative_init_seasonality,
        hw_calculate_seasonal_deviation,
        hw_init_seasonal_deviation,
        1.0             /* identity value */
    };

    static hw_functions_t hw_additive_functions = {
        hw_additive_calculate_prediction,
        hw_additive_calculate_intercept,
        hw_calculate_slope,
        hw_additive_calculate_seasonality,
        hw_additive_init_seasonality,
        hw_calculate_seasonal_deviation,
        hw_init_seasonal_deviation,
        0.0             /* identity value  */
    };

    rrd->cdp_prep[cdp_idx].scratch[CDP_scratch_idx].u_val = pdp_val;
    switch (current_cf) {
    case CF_HWPREDICT:
        return update_hwpredict(rrd, cdp_idx, rra_idx, ds_idx,
                                CDP_scratch_idx, &hw_additive_functions);
    case CF_MHWPREDICT:
        return update_hwpredict(rrd, cdp_idx, rra_idx, ds_idx,
                                CDP_scratch_idx,
                                &hw_multiplicative_functions);
    case CF_DEVPREDICT:
        return update_devpredict(rrd, cdp_idx, rra_idx, ds_idx,
                                 CDP_scratch_idx);
    case CF_SEASONAL:
        switch (cf_conv(rrd->rra_def[hw_dep_idx(rrd, rra_idx)].cf_nam)) {
        case CF_HWPREDICT:
            return update_seasonal(rrd, cdp_idx, rra_idx, ds_idx,
                                   CDP_scratch_idx, seasonal_coef,
                                   &hw_additive_functions);
        case CF_MHWPREDICT:
            return update_seasonal(rrd, cdp_idx, rra_idx, ds_idx,
                                   CDP_scratch_idx, seasonal_coef,
                                   &hw_multiplicative_functions);
        default:
            return -1;
        }
    case CF_DEVSEASONAL:
        switch (cf_conv(rrd->rra_def[hw_dep_idx(rrd, rra_idx)].cf_nam)) {
        case CF_HWPREDICT:
            return update_devseasonal(rrd, cdp_idx, rra_idx, ds_idx,
                                      CDP_scratch_idx, seasonal_coef,
                                      &hw_additive_functions);
        case CF_MHWPREDICT:
            return update_devseasonal(rrd, cdp_idx, rra_idx, ds_idx,
                                      CDP_scratch_idx, seasonal_coef,
                                      &hw_multiplicative_functions);
        default:
            return -1;
        }
    case CF_FAILURES:
        switch (cf_conv
                (rrd->rra_def[hw_dep_idx(rrd, hw_dep_idx(rrd, rra_idx))].
                 cf_nam)) {
        case CF_HWPREDICT:
            return update_failures(rrd, cdp_idx, rra_idx, ds_idx,
                                   CDP_scratch_idx, &hw_additive_functions);
        case CF_MHWPREDICT:
            return update_failures(rrd, cdp_idx, rra_idx, ds_idx,
                                   CDP_scratch_idx,
                                   &hw_multiplicative_functions);
        default:
            return -1;
        }
    case CF_AVERAGE:
    default:
        return 0;
    }
    return -1;
}

static unsigned long MyMod(
    signed long val,
    unsigned long mod)
{
    unsigned long new_val;

    if (val < 0)
        new_val = ((unsigned long) abs(val)) % mod;
    else
        new_val = (val % mod);

    if (val < 0)
        return (mod - new_val);
    else
        return (new_val);
}

/* a standard fixed-capacity FIF0 queue implementation
 * No overflow checking is performed. */
int queue_alloc(
    FIFOqueue **q,
    int capacity)
{
    *q = (FIFOqueue *) malloc(sizeof(FIFOqueue));
    if (*q == NULL)
        return -1;
    (*q)->queue = (rrd_value_t *) malloc(sizeof(rrd_value_t) * capacity);
    if ((*q)->queue == NULL) {
        free(*q);
        return -1;
    }
    (*q)->capacity = capacity;
    (*q)->head = capacity;
    (*q)->tail = 0;
    return 0;
}

int queue_isempty(
    FIFOqueue *q)
{
    return (q->head % q->capacity == q->tail);
}

void queue_push(
    FIFOqueue *q,
    rrd_value_t value)
{
    q->queue[(q->tail)++] = value;
    q->tail = q->tail % q->capacity;
}

rrd_value_t queue_pop(
    FIFOqueue *q)
{
    q->head = q->head % q->capacity;
    return q->queue[(q->head)++];
}

void queue_dealloc(
    FIFOqueue *q)
{
    free(q->queue);
    free(q);
}
