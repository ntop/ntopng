/*****************************************************************************
 * RRDtool 1.4.8  Copyright by Tobi Oetiker, 1997-2013
 *                Copyright by Florian Forster, 2008
 *****************************************************************************
 * rrd_update.c  RRD Update Function
 *****************************************************************************
 * $Id$
 *****************************************************************************/

#include "rrd_tool.h"

#if defined(_WIN32) && !defined(__CYGWIN__) && !defined(__CYGWIN32__)
#include <sys/locking.h>
#include <sys/stat.h>
#include <io.h>
#endif

#include <locale.h>

#include "rrd_hw.h"
#include "rrd_rpncalc.h"

#include "rrd_is_thread_safe.h"
#include "unused.h"

#include "rrd_client.h"

#if defined(_WIN32) && !defined(__CYGWIN__) && !defined(__CYGWIN32__)
/*
 * WIN32 does not have gettimeofday	and struct timeval. This is a quick and dirty
 * replacement.
 */
#include <sys/timeb.h>

#ifndef __MINGW32__
struct timeval {
    time_t    tv_sec;   /* seconds */
    long      tv_usec;  /* microseconds */
};
#endif

struct __timezone {
    int       tz_minuteswest;   /* minutes W of Greenwich */
    int       tz_dsttime;   /* type of dst correction */
};

static int gettimeofday(
    struct timeval *t,
    struct __timezone *tz)
{

    struct _timeb current_time;

    _ftime(&current_time);

    t->tv_sec = current_time.time;
    t->tv_usec = current_time.millitm * 1000;

    return 0;
}

#endif

/* FUNCTION PROTOTYPES */

int       rrd_update_r(
    const char *filename,
    const char *tmplt,
    int argc,
    const char **argv);
int       _rrd_update(
    const char *filename,
    const char *tmplt,
    int argc,
    const char **argv,
    rrd_info_t *);

static int allocate_data_structures(
    rrd_t *rrd,
    char ***updvals,
    rrd_value_t **pdp_temp,
    const char *tmplt,
    long **tmpl_idx,
    unsigned long *tmpl_cnt,
    unsigned long **rra_step_cnt,
    unsigned long **skip_update,
    rrd_value_t **pdp_new);

static int parse_template(
    rrd_t *rrd,
    const char *tmplt,
    unsigned long *tmpl_cnt,
    long *tmpl_idx);

static int process_arg(
    char *step_start,
    rrd_t *rrd,
    rrd_file_t *rrd_file,
    unsigned long rra_begin,
    time_t *current_time,
    unsigned long *current_time_usec,
    rrd_value_t *pdp_temp,
    rrd_value_t *pdp_new,
    unsigned long *rra_step_cnt,
    char **updvals,
    long *tmpl_idx,
    unsigned long tmpl_cnt,
    rrd_info_t ** pcdp_summary,
    int version,
    unsigned long *skip_update,
    int *schedule_smooth);

static int parse_ds(
    rrd_t *rrd,
    char **updvals,
    long *tmpl_idx,
    char *input,
    unsigned long tmpl_cnt,
    time_t *current_time,
    unsigned long *current_time_usec,
    int version);

static int get_time_from_reading(
    rrd_t *rrd,
    char timesyntax,
    char **updvals,
    time_t *current_time,
    unsigned long *current_time_usec,
    int version);

static int update_pdp_prep(
    rrd_t *rrd,
    char **updvals,
    rrd_value_t *pdp_new,
    double interval);

static int calculate_elapsed_steps(
    rrd_t *rrd,
    unsigned long current_time,
    unsigned long current_time_usec,
    double interval,
    double *pre_int,
    double *post_int,
    unsigned long *proc_pdp_cnt);

static void simple_update(
    rrd_t *rrd,
    double interval,
    rrd_value_t *pdp_new);

static int process_all_pdp_st(
    rrd_t *rrd,
    double interval,
    double pre_int,
    double post_int,
    unsigned long elapsed_pdp_st,
    rrd_value_t *pdp_new,
    rrd_value_t *pdp_temp);

static int process_pdp_st(
    rrd_t *rrd,
    unsigned long ds_idx,
    double interval,
    double pre_int,
    double post_int,
    long diff_pdp_st,
    rrd_value_t *pdp_new,
    rrd_value_t *pdp_temp);

static int update_all_cdp_prep(
    rrd_t *rrd,
    unsigned long *rra_step_cnt,
    unsigned long rra_begin,
    rrd_file_t *rrd_file,
    unsigned long elapsed_pdp_st,
    unsigned long proc_pdp_cnt,
    rrd_value_t **last_seasonal_coef,
    rrd_value_t **seasonal_coef,
    rrd_value_t *pdp_temp,
    unsigned long *skip_update,
    int *schedule_smooth);

static int do_schedule_smooth(
    rrd_t *rrd,
    unsigned long rra_idx,
    unsigned long elapsed_pdp_st);

static int update_cdp_prep(
    rrd_t *rrd,
    unsigned long elapsed_pdp_st,
    unsigned long start_pdp_offset,
    unsigned long *rra_step_cnt,
    int rra_idx,
    rrd_value_t *pdp_temp,
    rrd_value_t *last_seasonal_coef,
    rrd_value_t *seasonal_coef,
    int current_cf);

static void update_cdp(
    unival *scratch,
    int current_cf,
    rrd_value_t pdp_temp_val,
    unsigned long rra_step_cnt,
    unsigned long elapsed_pdp_st,
    unsigned long start_pdp_offset,
    unsigned long pdp_cnt,
    rrd_value_t xff,
    int i,
    int ii);

static void initialize_cdp_val(
    unival *scratch,
    int current_cf,
    rrd_value_t pdp_temp_val,
    unsigned long start_pdp_offset,
    unsigned long pdp_cnt);

static void reset_cdp(
    rrd_t *rrd,
    unsigned long elapsed_pdp_st,
    rrd_value_t *pdp_temp,
    rrd_value_t *last_seasonal_coef,
    rrd_value_t *seasonal_coef,
    int rra_idx,
    int ds_idx,
    int cdp_idx,
    enum cf_en current_cf);

static rrd_value_t initialize_carry_over(
    rrd_value_t pdp_temp_val,
    int         current_cf,
    unsigned long elapsed_pdp_st,
    unsigned long start_pdp_offset,
    unsigned long pdp_cnt);

static rrd_value_t calculate_cdp_val(
    rrd_value_t cdp_val,
    rrd_value_t pdp_temp_val,
    unsigned long elapsed_pdp_st,
    int current_cf,
    int i,
    int ii);

static int update_aberrant_cdps(
    rrd_t *rrd,
    rrd_file_t *rrd_file,
    unsigned long rra_begin,
    unsigned long elapsed_pdp_st,
    rrd_value_t *pdp_temp,
    rrd_value_t **seasonal_coef);

static int write_to_rras(
    rrd_t *rrd,
    rrd_file_t *rrd_file,
    unsigned long *rra_step_cnt,
    unsigned long rra_begin,
    time_t current_time,
    unsigned long *skip_update,
    rrd_info_t ** pcdp_summary);

static int write_RRA_row(
    rrd_file_t *rrd_file,
    rrd_t *rrd,
    unsigned long rra_idx,
    unsigned short CDP_scratch_idx,
    rrd_info_t ** pcdp_summary,
    time_t rra_time);

static int smooth_all_rras(
    rrd_t *rrd,
    rrd_file_t *rrd_file,
    unsigned long rra_begin);

#ifndef HAVE_MMAP
static int write_changes_to_disk(
    rrd_t *rrd,
    rrd_file_t *rrd_file,
    int version);
#endif

/*
 * normalize time as returned by gettimeofday. usec part must
 * be always >= 0
 */
static void normalize_time(
    struct timeval *t)
{
    if (t->tv_usec < 0) {
        t->tv_sec--;
        t->tv_usec += 1e6L;
    }
}

/*
 * Sets current_time and current_time_usec based on the current time.
 * current_time_usec is set to 0 if the version number is 1 or 2.
 */
static void initialize_time(
    time_t *current_time,
    unsigned long *current_time_usec,
    int version)
{
    struct timeval tmp_time;    /* used for time conversion */

    gettimeofday(&tmp_time, 0);
    normalize_time(&tmp_time);
    *current_time = tmp_time.tv_sec;
    if (version >= 3) {
        *current_time_usec = tmp_time.tv_usec;
    } else {
        *current_time_usec = 0;
    }
}

#define IFDNAN(X,Y) (isnan(X) ? (Y) : (X));

rrd_info_t *rrd_update_v(
    int argc,
    char **argv)
{
    char     *tmplt = NULL;
    rrd_info_t *result = NULL;
    rrd_infoval_t rc;
    char *opt_daemon = NULL;
    struct option long_options[] = {
        {"template", required_argument, 0, 't'},
        {0, 0, 0, 0}
    };

    rc.u_int = -1;
    optind = 0;
    opterr = 0;         /* initialize getopt */

    while (1) {
        int       option_index = 0;
        int       opt;

        opt = getopt_long(argc, argv, "t:", long_options, &option_index);

        if (opt == EOF)
            break;

        switch (opt) {
        case 't':
            tmplt = optarg;
            break;

        case '?':
            rrd_set_error("unknown option '%s'", argv[optind - 1]);
            goto end_tag;
        }
    }

    opt_daemon = getenv (ENV_RRDCACHED_ADDRESS);
    if (opt_daemon != NULL) {
        rrd_set_error ("The \"%s\" environment variable is defined, "
                "but \"%s\" cannot work with rrdcached. Either unset "
                "the environment variable or use \"update\" instead.",
                ENV_RRDCACHED_ADDRESS, argv[0]);
        goto end_tag;
    }

    /* need at least 2 arguments: filename, data. */
    if (argc - optind < 2) {
        rrd_set_error("Not enough arguments");
        goto end_tag;
    }
    rc.u_int = 0;
    result = rrd_info_push(NULL, sprintf_alloc("return_value"), RD_I_INT, rc);
    rc.u_int = _rrd_update(argv[optind], tmplt,
                           argc - optind - 1,
                           (const char **) (argv + optind + 1), result);
    result->value.u_int = rc.u_int;
  end_tag:
    return result;
}

int rrd_update(
    int argc,
    char **argv)
{
    struct option long_options[] = {
        {"template", required_argument, 0, 't'},
        {"daemon",   required_argument, 0, 'd'},
        {0, 0, 0, 0}
    };
    int       option_index = 0;
    int       opt;
    char     *tmplt = NULL;
    int       rc = -1;
    char     *opt_daemon = NULL;

    optind = 0;
    opterr = 0;         /* initialize getopt */

    while (1) {
        opt = getopt_long(argc, argv, "t:d:", long_options, &option_index);

        if (opt == EOF)
            break;

        switch (opt) {
        case 't':
            tmplt = strdup(optarg);
            break;

        case 'd':
            if (opt_daemon != NULL)
                free (opt_daemon);
            opt_daemon = strdup (optarg);
            if (opt_daemon == NULL)
            {
                rrd_set_error("strdup failed.");
                goto out;
            }
            break;

        case '?':
            rrd_set_error("unknown option '%s'", argv[optind - 1]);
            goto out;
        }
    }

    /* need at least 2 arguments: filename, data. */
    if (argc - optind < 2) {
        rrd_set_error("Not enough arguments");
        goto out;
    }

    {   /* try to connect to rrdcached */
        int status = rrdc_connect(opt_daemon);
        if (status != 0) {
             rc = status;
             goto out;
        }
    }

    if ((tmplt != NULL) && rrdc_is_connected(opt_daemon))
    {
        rrd_set_error("The caching daemon cannot be used together with "
                "templates yet.");
        goto out;
    }

    if (! rrdc_is_connected(opt_daemon))
    {
      rc = rrd_update_r(argv[optind], tmplt,
                        argc - optind - 1, (const char **) (argv + optind + 1));
    }
    else /* we are connected */
    {
        rc = rrdc_update (argv[optind], /* file */
                          argc - optind - 1, /* values_num */
                          (const char *const *) (argv + optind + 1)); /* values */
        if (rc > 0)
            rrd_set_error("Failed sending the values to rrdcached: %s",
                          rrd_strerror (rc));
    }

  out:
    if (tmplt != NULL)
    {
        free(tmplt);
        tmplt = NULL;
    }
    if (opt_daemon != NULL)
    {
        free (opt_daemon);
        opt_daemon = NULL;
    }
    return rc;
}

int rrd_update_r(
    const char *filename,
    const char *tmplt,
    int argc,
    const char **argv)
{
    return _rrd_update(filename, tmplt, argc, argv, NULL);
}

int _rrd_update(
    const char *filename,
    const char *tmplt,
    int argc,
    const char **argv,
    rrd_info_t * pcdp_summary)
{

    int       arg_i = 2;

    unsigned long rra_begin;    /* byte pointer to the rra
                                 * area in the rrd file.  this
                                 * pointer never changes value */
    rrd_value_t *pdp_new;   /* prepare the incoming data to be added 
                             * to the existing entry */
    rrd_value_t *pdp_temp;  /* prepare the pdp values to be added 
                             * to the cdp values */

    long     *tmpl_idx; /* index representing the settings
                         * transported by the tmplt index */
    unsigned long tmpl_cnt = 2; /* time and data */
    rrd_t     rrd;
    time_t    current_time = 0;
    unsigned long current_time_usec = 0;    /* microseconds part of current time */
    char    **updvals;
    int       schedule_smooth = 0;

    /* number of elapsed PDP steps since last update */
    unsigned long *rra_step_cnt = NULL;

    int       version;  /* rrd version */
    rrd_file_t *rrd_file;
    char     *arg_copy; /* for processing the argv */
    unsigned long *skip_update; /* RRAs to advance but not write */

    /* need at least 1 arguments: data. */
    if (argc < 1) {
        rrd_set_error("Not enough arguments");
        goto err_out;
    }

    rrd_init(&rrd);
    if ((rrd_file = rrd_open(filename, &rrd, RRD_READWRITE)) == NULL) {
        goto err_free;
    }
    /* We are now at the beginning of the rra's */
    rra_begin = rrd_file->header_len;

    version = atoi(rrd.stat_head->version);

    initialize_time(&current_time, &current_time_usec, version);

    /* get exclusive lock to whole file.
     * lock gets removed when we close the file.
     */
    if (rrd_lock(rrd_file) != 0) {
        rrd_set_error("could not lock RRD");
        goto err_close;
    }

    if (allocate_data_structures(&rrd, &updvals,
                                 &pdp_temp, tmplt, &tmpl_idx, &tmpl_cnt,
                                 &rra_step_cnt, &skip_update,
                                 &pdp_new) == -1) {
        goto err_close;
    }

    /* loop through the arguments. */
    for (arg_i = 0; arg_i < argc; arg_i++) {
        if ((arg_copy = strdup(argv[arg_i])) == NULL) {
            rrd_set_error("failed duplication argv entry");
            break;
        }
        if (process_arg(arg_copy, &rrd, rrd_file, rra_begin,
                        &current_time, &current_time_usec, pdp_temp, pdp_new,
                        rra_step_cnt, updvals, tmpl_idx, tmpl_cnt,
                        &pcdp_summary, version, skip_update,
                        &schedule_smooth) == -1) {
            if (rrd_test_error()) { /* Should have error string always here */
                char     *save_error;

                /* Prepend file name to error message */
                if ((save_error = strdup(rrd_get_error())) != NULL) {
                    rrd_set_error("%s: %s", filename, save_error);
                    free(save_error);
                }
            }
            free(arg_copy);
            break;
        }
        free(arg_copy);
    }

    free(rra_step_cnt);

    /* if we got here and if there is an error and if the file has not been
     * written to, then close things up and return. */
    if (rrd_test_error()) {
        goto err_free_structures;
    }
#ifndef HAVE_MMAP
    if (write_changes_to_disk(&rrd, rrd_file, version) == -1) {
        goto err_free_structures;
    }
#endif

    /* calling the smoothing code here guarantees at most one smoothing
     * operation per rrd_update call. Unfortunately, it is possible with bulk
     * updates, or a long-delayed update for smoothing to occur off-schedule.
     * This really isn't critical except during the burn-in cycles. */
    if (schedule_smooth) {
        smooth_all_rras(&rrd, rrd_file, rra_begin);
    }

/*    rrd_dontneed(rrd_file,&rrd); */
    rrd_free(&rrd);
    rrd_close(rrd_file);

    free(pdp_new);
    free(tmpl_idx);
    free(pdp_temp);
    free(skip_update);
    free(updvals);
    return 0;

  err_free_structures:
    free(pdp_new);
    free(tmpl_idx);
    free(pdp_temp);
    free(skip_update);
    free(updvals);
  err_close:
    rrd_close(rrd_file);
  err_free:
    rrd_free(&rrd);
  err_out:
    return -1;
}

/*
 * Allocate some important arrays used, and initialize the template.
 *
 * When it returns, either all of the structures are allocated
 * or none of them are.
 *
 * Returns 0 on success, -1 on error.
 */
static int allocate_data_structures(
    rrd_t *rrd,
    char ***updvals,
    rrd_value_t **pdp_temp,
    const char *tmplt,
    long **tmpl_idx,
    unsigned long *tmpl_cnt,
    unsigned long **rra_step_cnt,
    unsigned long **skip_update,
    rrd_value_t **pdp_new)
{
    unsigned  i, ii;
    if ((*updvals = (char **) malloc(sizeof(char *)
                                     * (rrd->stat_head->ds_cnt + 1))) == NULL) {
        rrd_set_error("allocating updvals pointer array.");
        return -1;
    }
    if ((*pdp_temp = (rrd_value_t *) malloc(sizeof(rrd_value_t)
                                            * rrd->stat_head->ds_cnt)) ==
        NULL) {
        rrd_set_error("allocating pdp_temp.");
        goto err_free_updvals;
    }
    if ((*skip_update = (unsigned long *) malloc(sizeof(unsigned long)
                                                 *
                                                 rrd->stat_head->rra_cnt)) ==
        NULL) {
        rrd_set_error("allocating skip_update.");
        goto err_free_pdp_temp;
    }
    if ((*tmpl_idx = (long *) malloc(sizeof(unsigned long)
                                     * (rrd->stat_head->ds_cnt + 1))) == NULL) {
        rrd_set_error("allocating tmpl_idx.");
        goto err_free_skip_update;
    }
    if ((*rra_step_cnt = (unsigned long *) malloc(sizeof(unsigned long)
                                                  *
                                                  (rrd->stat_head->
                                                   rra_cnt))) == NULL) {
        rrd_set_error("allocating rra_step_cnt.");
        goto err_free_tmpl_idx;
    }

    /* initialize tmplt redirector */
    /* default config example (assume DS 1 is a CDEF DS)
       tmpl_idx[0] -> 0; (time)
       tmpl_idx[1] -> 1; (DS 0)
       tmpl_idx[2] -> 3; (DS 2)
       tmpl_idx[3] -> 4; (DS 3) */
    (*tmpl_idx)[0] = 0; /* time */
    for (i = 1, ii = 1; i <= rrd->stat_head->ds_cnt; i++) {
        if (dst_conv(rrd->ds_def[i - 1].dst) != DST_CDEF)
            (*tmpl_idx)[ii++] = i;
    }
    *tmpl_cnt = ii;

    if (tmplt != NULL) {
        if (parse_template(rrd, tmplt, tmpl_cnt, *tmpl_idx) == -1) {
            goto err_free_rra_step_cnt;
        }
    }

    if ((*pdp_new = (rrd_value_t *) malloc(sizeof(rrd_value_t)
                                           * rrd->stat_head->ds_cnt)) == NULL) {
        rrd_set_error("allocating pdp_new.");
        goto err_free_rra_step_cnt;
    }

    return 0;

  err_free_rra_step_cnt:
    free(*rra_step_cnt);
  err_free_tmpl_idx:
    free(*tmpl_idx);
  err_free_skip_update:
    free(*skip_update);
  err_free_pdp_temp:
    free(*pdp_temp);
  err_free_updvals:
    free(*updvals);
    return -1;
}

/*
 * Parses tmplt and puts an ordered list of DS's into tmpl_idx.
 *
 * Returns 0 on success.
 */
static int parse_template(
    rrd_t *rrd,
    const char *tmplt,
    unsigned long *tmpl_cnt,
    long *tmpl_idx)
{
    char     *dsname, *tmplt_copy;
    unsigned int tmpl_len, i;
    int       ret = 0;

    *tmpl_cnt = 1;      /* the first entry is the time */

    /* we should work on a writeable copy here */
    if ((tmplt_copy = strdup(tmplt)) == NULL) {
        rrd_set_error("error copying tmplt '%s'", tmplt);
        ret = -1;
        goto out;
    }

    dsname = tmplt_copy;
    tmpl_len = strlen(tmplt_copy);
    for (i = 0; i <= tmpl_len; i++) {
        if (tmplt_copy[i] == ':' || tmplt_copy[i] == '\0') {
            tmplt_copy[i] = '\0';
            if (*tmpl_cnt > rrd->stat_head->ds_cnt) {
                rrd_set_error("tmplt contains more DS definitions than RRD");
                ret = -1;
                goto out_free_tmpl_copy;
            }
            if ((tmpl_idx[(*tmpl_cnt)++] = ds_match(rrd, dsname) + 1) == 0) {
                rrd_set_error("unknown DS name '%s'", dsname);
                ret = -1;
                goto out_free_tmpl_copy;
            }
            /* go to the next entry on the tmplt_copy */
            if (i < tmpl_len)
                dsname = &tmplt_copy[i + 1];
        }
    }
  out_free_tmpl_copy:
    free(tmplt_copy);
  out:
    return ret;
}

/*
 * Parse an update string, updates the primary data points (PDPs)
 * and consolidated data points (CDPs), and writes changes to the RRAs.
 *
 * Returns 0 on success, -1 on error.
 */
static int process_arg(
    char *step_start,
    rrd_t *rrd,
    rrd_file_t *rrd_file,
    unsigned long rra_begin,
    time_t *current_time,
    unsigned long *current_time_usec,
    rrd_value_t *pdp_temp,
    rrd_value_t *pdp_new,
    unsigned long *rra_step_cnt,
    char **updvals,
    long *tmpl_idx,
    unsigned long tmpl_cnt,
    rrd_info_t ** pcdp_summary,
    int version,
    unsigned long *skip_update,
    int *schedule_smooth)
{
    rrd_value_t *seasonal_coef = NULL, *last_seasonal_coef = NULL;

    /* a vector of future Holt-Winters seasonal coefs */
    unsigned long elapsed_pdp_st;

    double    interval, pre_int, post_int;  /* interval between this and
                                             * the last run */
    unsigned long proc_pdp_cnt;

    if (parse_ds(rrd, updvals, tmpl_idx, step_start, tmpl_cnt,
                 current_time, current_time_usec, version) == -1) {
        return -1;
    }

    interval = (double) (*current_time - rrd->live_head->last_up)
        + (double) ((long) *current_time_usec -
                    (long) rrd->live_head->last_up_usec) / 1e6f;

    /* process the data sources and update the pdp_prep 
     * area accordingly */
    if (update_pdp_prep(rrd, updvals, pdp_new, interval) == -1) {
        return -1;
    }

    elapsed_pdp_st = calculate_elapsed_steps(rrd,
                                             *current_time,
                                             *current_time_usec, interval,
                                             &pre_int, &post_int,
                                             &proc_pdp_cnt);

    /* has a pdp_st moment occurred since the last run ? */
    if (elapsed_pdp_st == 0) {
        /* no we have not passed a pdp_st moment. therefore update is simple */
        simple_update(rrd, interval, pdp_new);
    } else {
        /* an pdp_st has occurred. */
        if (process_all_pdp_st(rrd, interval,
                               pre_int, post_int,
                               elapsed_pdp_st, pdp_new, pdp_temp) == -1) {
            return -1;
        }
        if (update_all_cdp_prep(rrd, rra_step_cnt,
                                rra_begin, rrd_file,
                                elapsed_pdp_st,
                                proc_pdp_cnt,
                                &last_seasonal_coef,
                                &seasonal_coef,
                                pdp_temp,
                                skip_update, schedule_smooth) == -1) {
            goto err_free_coefficients;
        }
        if (update_aberrant_cdps(rrd, rrd_file, rra_begin,
                                 elapsed_pdp_st, pdp_temp,
                                 &seasonal_coef) == -1) {
            goto err_free_coefficients;
        }
        if (write_to_rras(rrd, rrd_file, rra_step_cnt, rra_begin,
                          *current_time, skip_update,
                          pcdp_summary) == -1) {
            goto err_free_coefficients;
        }
    }                   /* endif a pdp_st has occurred */
    rrd->live_head->last_up = *current_time;
    rrd->live_head->last_up_usec = *current_time_usec;

    if (version < 3) {
        *rrd->legacy_last_up = rrd->live_head->last_up;
    }
    free(seasonal_coef);
    free(last_seasonal_coef);
    return 0;

  err_free_coefficients:
    free(seasonal_coef);
    free(last_seasonal_coef);
    return -1;
}

/*
 * Parse a DS string (time + colon-separated values), storing the
 * results in current_time, current_time_usec, and updvals.
 *
 * Returns 0 on success, -1 on error.
 */
static int parse_ds(
    rrd_t *rrd,
    char **updvals,
    long *tmpl_idx,
    char *input,
    unsigned long tmpl_cnt,
    time_t *current_time,
    unsigned long *current_time_usec,
    int version)
{
    char     *p;
    unsigned long i;
    char      timesyntax;

    updvals[0] = input;
    /* initialize all ds input to unknown except the first one
       which has always got to be set */
    for (i = 1; i <= rrd->stat_head->ds_cnt; i++)
        updvals[i] = "U";

    /* separate all ds elements; first must be examined separately
       due to alternate time syntax */
    if ((p = strchr(input, '@')) != NULL) {
        timesyntax = '@';
    } else if ((p = strchr(input, ':')) != NULL) {
        timesyntax = ':';
    } else {
        rrd_set_error("expected timestamp not found in data source from %s",
                      input);
        return -1;
    }
    *p = '\0';
    i = 1;
    updvals[tmpl_idx[i++]] = p + 1;
    while (*(++p)) {
        if (*p == ':') {
            *p = '\0';
            if (i < tmpl_cnt) {
                updvals[tmpl_idx[i++]] = p + 1;
            }
            else {
                rrd_set_error("found extra data on update argument: %s",p+1);
                return -1;
            }                
        }
    }

    if (i != tmpl_cnt) {
        rrd_set_error("expected %lu data source readings (got %lu) from %s",
                      tmpl_cnt - 1, i - 1, input);
        return -1;
    }

    if (get_time_from_reading(rrd, timesyntax, updvals,
                              current_time, current_time_usec,
                              version) == -1) {
        return -1;
    }
    return 0;
}

/*
 * Parse the time in a DS string, store it in current_time and 
 * current_time_usec and verify that it's later than the last
 * update for this DS.
 *
 * Returns 0 on success, -1 on error.
 */
static int get_time_from_reading(
    rrd_t *rrd,
    char timesyntax,
    char **updvals,
    time_t *current_time,
    unsigned long *current_time_usec,
    int version)
{
    double    tmp;
    char     *parsetime_error = NULL;
    char     *old_locale;
    rrd_time_value_t ds_tv;
    struct timeval tmp_time;    /* used for time conversion */

    /* get the time from the reading ... handle N */
    if (timesyntax == '@') {    /* at-style */
        if ((parsetime_error = rrd_parsetime(updvals[0], &ds_tv))) {
            rrd_set_error("ds time: %s: %s", updvals[0], parsetime_error);
            return -1;
        }
        if (ds_tv.type == RELATIVE_TO_END_TIME ||
            ds_tv.type == RELATIVE_TO_START_TIME) {
            rrd_set_error("specifying time relative to the 'start' "
                          "or 'end' makes no sense here: %s", updvals[0]);
            return -1;
        }
        *current_time = mktime(&ds_tv.tm) +ds_tv.offset;
        *current_time_usec = 0; /* FIXME: how to handle usecs here ? */
    } else if (strcmp(updvals[0], "N") == 0) {
        gettimeofday(&tmp_time, 0);
        normalize_time(&tmp_time);
        *current_time = tmp_time.tv_sec;
        *current_time_usec = tmp_time.tv_usec;
    } else {
        old_locale = setlocale(LC_NUMERIC, NULL);
        setlocale(LC_NUMERIC, "C");
        errno = 0;
        tmp = strtod(updvals[0], 0);
        if (errno > 0) {
            rrd_set_error("converting '%s' to float: %s",
                updvals[0], rrd_strerror(errno));
            return -1;
        };
        setlocale(LC_NUMERIC, old_locale);
        if (tmp < 0.0){
            gettimeofday(&tmp_time, 0);
            tmp = (double)tmp_time.tv_sec + (double)tmp_time.tv_usec * 1e-6f + tmp;
        }

        *current_time = floor(tmp);
        *current_time_usec = (long) ((tmp - (double) *current_time) * 1e6f);
    }
    /* dont do any correction for old version RRDs */
    if (version < 3)
        *current_time_usec = 0;

    if (*current_time < rrd->live_head->last_up ||
        (*current_time == rrd->live_head->last_up &&
         (long) *current_time_usec <= (long) rrd->live_head->last_up_usec)) {
        rrd_set_error("illegal attempt to update using time %ld when "
                      "last update time is %ld (minimum one second step)",
                      *current_time, rrd->live_head->last_up);
        return -1;
    }
    return 0;
}

/*
 * Update pdp_new by interpreting the updvals according to the DS type
 * (COUNTER, GAUGE, etc.).
 *
 * Returns 0 on success, -1 on error.
 */
static int update_pdp_prep(
    rrd_t *rrd,
    char **updvals,
    rrd_value_t *pdp_new,
    double interval)
{
    unsigned long ds_idx;
    int       ii;
    char     *endptr;   /* used in the conversion */
    double    rate;
    char     *old_locale;
    enum dst_en dst_idx;

    for (ds_idx = 0; ds_idx < rrd->stat_head->ds_cnt; ds_idx++) {
        dst_idx = dst_conv(rrd->ds_def[ds_idx].dst);

        /* make sure we do not build diffs with old last_ds values */
        if (rrd->ds_def[ds_idx].par[DS_mrhb_cnt].u_cnt < interval) {
            strncpy(rrd->pdp_prep[ds_idx].last_ds, "U", LAST_DS_LEN - 1);
            rrd->pdp_prep[ds_idx].last_ds[LAST_DS_LEN - 1] = '\0';
        }

        /* NOTE: DST_CDEF should never enter this if block, because
         * updvals[ds_idx+1][0] is initialized to 'U'; unless the caller
         * accidently specified a value for the DST_CDEF. To handle this case,
         * an extra check is required. */

        if ((updvals[ds_idx + 1][0] != 'U') &&
            (dst_idx != DST_CDEF) &&
            rrd->ds_def[ds_idx].par[DS_mrhb_cnt].u_cnt >= interval) {
            rate = DNAN;

            /* pdp_new contains rate * time ... eg the bytes transferred during
             * the interval. Doing it this way saves a lot of math operations
             */
            switch (dst_idx) {
            case DST_COUNTER:
            case DST_DERIVE:
                /* Check if this is a valid integer. `U' is already handled in
                 * another branch. */
                for (ii = 0; updvals[ds_idx + 1][ii] != 0; ii++) {
                    if ((ii == 0) && (dst_idx == DST_DERIVE)
                            && (updvals[ds_idx + 1][ii] == '-'))
                        continue;

                    if ((updvals[ds_idx + 1][ii] < '0')
                            || (updvals[ds_idx + 1][ii] > '9')) {
                        rrd_set_error("not a simple %s integer: '%s'",
                                (dst_idx == DST_DERIVE) ? "signed" : "unsigned",
                                updvals[ds_idx + 1]);
                        return -1;
                    }
                } /* for (ii = 0; updvals[ds_idx + 1][ii] != 0; ii++) */

                if (rrd->pdp_prep[ds_idx].last_ds[0] != 'U') {
                    pdp_new[ds_idx] =
                        rrd_diff(updvals[ds_idx + 1],
                                 rrd->pdp_prep[ds_idx].last_ds);
                    if (dst_idx == DST_COUNTER) {
                        /* simple overflow catcher. This will fail
                         * terribly for non 32 or 64 bit counters
                         * ... are there any others in SNMP land?
                         */
                        if (pdp_new[ds_idx] < (double) 0.0)
                            pdp_new[ds_idx] += (double) 4294967296.0;   /* 2^32 */
                        if (pdp_new[ds_idx] < (double) 0.0)
                            pdp_new[ds_idx] += (double) 18446744069414584320.0; /* 2^64-2^32 */
                    }
                    rate = pdp_new[ds_idx] / interval;
                } else {
                    pdp_new[ds_idx] = DNAN;
                }
                break;
            case DST_ABSOLUTE:
                old_locale = setlocale(LC_NUMERIC, NULL);
                setlocale(LC_NUMERIC, "C");
                errno = 0;
                pdp_new[ds_idx] = strtod(updvals[ds_idx + 1], &endptr);
                if (errno > 0) {
                    rrd_set_error("converting '%s' to float: %s",
                                  updvals[ds_idx + 1], rrd_strerror(errno));
                    return -1;
                };
                setlocale(LC_NUMERIC, old_locale);
                if (endptr[0] != '\0') {
                    rrd_set_error
                        ("conversion of '%s' to float not complete: tail '%s'",
                         updvals[ds_idx + 1], endptr);
                    return -1;
                }
                rate = pdp_new[ds_idx] / interval;
                break;
            case DST_GAUGE:
                old_locale = setlocale(LC_NUMERIC, NULL);
                setlocale(LC_NUMERIC, "C");
                errno = 0;
                pdp_new[ds_idx] =
                    strtod(updvals[ds_idx + 1], &endptr) * interval;
                if (errno) {
                    rrd_set_error("converting '%s' to float: %s",
                                  updvals[ds_idx + 1], rrd_strerror(errno));
                    return -1;
                };
                setlocale(LC_NUMERIC, old_locale);
                if (endptr[0] != '\0') {
                    rrd_set_error
                        ("conversion of '%s' to float not complete: tail '%s'",
                         updvals[ds_idx + 1], endptr);
                    return -1;
                }
                rate = pdp_new[ds_idx] / interval;
                break;
            default:
                rrd_set_error("rrd contains unknown DS type : '%s'",
                              rrd->ds_def[ds_idx].dst);
                return -1;
            }
            /* break out of this for loop if the error string is set */
            if (rrd_test_error()) {
                return -1;
            }
            /* make sure pdp_temp is neither too large or too small
             * if any of these occur it becomes unknown ...
             * sorry folks ... */
            if (!isnan(rate) &&
                ((!isnan(rrd->ds_def[ds_idx].par[DS_max_val].u_val) &&
                  rate > rrd->ds_def[ds_idx].par[DS_max_val].u_val) ||
                 (!isnan(rrd->ds_def[ds_idx].par[DS_min_val].u_val) &&
                  rate < rrd->ds_def[ds_idx].par[DS_min_val].u_val))) {
                pdp_new[ds_idx] = DNAN;
            }
        } else {
            /* no news is news all the same */
            pdp_new[ds_idx] = DNAN;
        }


        /* make a copy of the command line argument for the next run */
#ifdef DEBUG
        fprintf(stderr, "prep ds[%lu]\t"
                "last_arg '%s'\t"
                "this_arg '%s'\t"
                "pdp_new %10.2f\n",
                ds_idx, rrd->pdp_prep[ds_idx].last_ds, updvals[ds_idx + 1],
                pdp_new[ds_idx]);
#endif
        strncpy(rrd->pdp_prep[ds_idx].last_ds, updvals[ds_idx + 1],
                LAST_DS_LEN - 1);
        rrd->pdp_prep[ds_idx].last_ds[LAST_DS_LEN - 1] = '\0';
    }
    return 0;
}

/*
 * How many PDP steps have elapsed since the last update? Returns the answer,
 * and stores the time between the last update and the last PDP in pre_time,
 * and the time between the last PDP and the current time in post_int.
 */
static int calculate_elapsed_steps(
    rrd_t *rrd,
    unsigned long current_time,
    unsigned long current_time_usec,
    double interval,
    double *pre_int,
    double *post_int,
    unsigned long *proc_pdp_cnt)
{
    unsigned long proc_pdp_st;  /* which pdp_st was the last to be processed */
    unsigned long occu_pdp_st;  /* when was the pdp_st before the last update
                                 * time */
    unsigned long proc_pdp_age; /* how old was the data in the pdp prep area 
                                 * when it was last updated */
    unsigned long occu_pdp_age; /* how long ago was the last pdp_step time */

    /* when was the current pdp started */
    proc_pdp_age = rrd->live_head->last_up % rrd->stat_head->pdp_step;
    proc_pdp_st = rrd->live_head->last_up - proc_pdp_age;

    /* when did the last pdp_st occur */
    occu_pdp_age = current_time % rrd->stat_head->pdp_step;
    occu_pdp_st = current_time - occu_pdp_age;

    if (occu_pdp_st > proc_pdp_st) {
        /* OK we passed the pdp_st moment */
        *pre_int = (long) occu_pdp_st - rrd->live_head->last_up;    /* how much of the input data
                                                                     * occurred before the latest
                                                                     * pdp_st moment*/
        *pre_int -= ((double) rrd->live_head->last_up_usec) / 1e6f; /* adjust usecs */
        *post_int = occu_pdp_age;   /* how much after it */
        *post_int += ((double) current_time_usec) / 1e6f;   /* adjust usecs */
    } else {
        *pre_int = interval;
        *post_int = 0;
    }

    *proc_pdp_cnt = proc_pdp_st / rrd->stat_head->pdp_step;

#ifdef DEBUG
    printf("proc_pdp_age %lu\t"
           "proc_pdp_st %lu\t"
           "occu_pfp_age %lu\t"
           "occu_pdp_st %lu\t"
           "int %lf\t"
           "pre_int %lf\t"
           "post_int %lf\n", proc_pdp_age, proc_pdp_st,
           occu_pdp_age, occu_pdp_st, interval, *pre_int, *post_int);
#endif

    /* compute the number of elapsed pdp_st moments */
    return (occu_pdp_st - proc_pdp_st) / rrd->stat_head->pdp_step;
}

/*
 * Increment the PDP values by the values in pdp_new, or else initialize them.
 */
static void simple_update(
    rrd_t *rrd,
    double interval,
    rrd_value_t *pdp_new)
{
    int       i;

    for (i = 0; i < (signed) rrd->stat_head->ds_cnt; i++) {
        if (isnan(pdp_new[i])) {
            /* this is not really accurate if we use subsecond data arrival time
               should have thought of it when going subsecond resolution ...
               sorry next format change we will have it! */
            rrd->pdp_prep[i].scratch[PDP_unkn_sec_cnt].u_cnt +=
                floor(interval);
        } else {
            if (isnan(rrd->pdp_prep[i].scratch[PDP_val].u_val)) {
                rrd->pdp_prep[i].scratch[PDP_val].u_val = pdp_new[i];
            } else {
                rrd->pdp_prep[i].scratch[PDP_val].u_val += pdp_new[i];
            }
        }
#ifdef DEBUG
        fprintf(stderr,
                "NO PDP  ds[%i]\t"
                "value %10.2f\t"
                "unkn_sec %5lu\n",
                i,
                rrd->pdp_prep[i].scratch[PDP_val].u_val,
                rrd->pdp_prep[i].scratch[PDP_unkn_sec_cnt].u_cnt);
#endif
    }
}

/*
 * Call process_pdp_st for each DS.
 *
 * Returns 0 on success, -1 on error.
 */
static int process_all_pdp_st(
    rrd_t *rrd,
    double interval,
    double pre_int,
    double post_int,
    unsigned long elapsed_pdp_st,
    rrd_value_t *pdp_new,
    rrd_value_t *pdp_temp)
{
    unsigned long ds_idx;

    /* in pdp_prep[].scratch[PDP_val].u_val we have collected
       rate*seconds which occurred up to the last run.
       pdp_new[] contains rate*seconds from the latest run.
       pdp_temp[] will contain the rate for cdp */

    for (ds_idx = 0; ds_idx < rrd->stat_head->ds_cnt; ds_idx++) {
        if (process_pdp_st(rrd, ds_idx, interval, pre_int, post_int,
                           elapsed_pdp_st * rrd->stat_head->pdp_step,
                           pdp_new, pdp_temp) == -1) {
            return -1;
        }
#ifdef DEBUG
        fprintf(stderr, "PDP UPD ds[%lu]\t"
                "elapsed_pdp_st %lu\t"
                "pdp_temp %10.2f\t"
                "new_prep %10.2f\t"
                "new_unkn_sec %5lu\n",
                ds_idx,
                elapsed_pdp_st,
                pdp_temp[ds_idx],
                rrd->pdp_prep[ds_idx].scratch[PDP_val].u_val,
                rrd->pdp_prep[ds_idx].scratch[PDP_unkn_sec_cnt].u_cnt);
#endif
    }
    return 0;
}

/*
 * Process an update that occurs after one of the PDP moments.
 * Increments the PDP value, sets NAN if time greater than the
 * heartbeats have elapsed, processes CDEFs.
 *
 * Returns 0 on success, -1 on error.
 */
static int process_pdp_st(
    rrd_t *rrd,
    unsigned long ds_idx,
    double interval,
    double pre_int,
    double post_int,
    long diff_pdp_st,   /* number of seconds in full steps passed since last update */
    rrd_value_t *pdp_new,
    rrd_value_t *pdp_temp)
{
    int       i;

    /* update pdp_prep to the current pdp_st. */
    double    pre_unknown = 0.0;
    unival   *scratch = rrd->pdp_prep[ds_idx].scratch;
    unsigned long mrhb = rrd->ds_def[ds_idx].par[DS_mrhb_cnt].u_cnt;

    rpnstack_t rpnstack;    /* used for COMPUTE DS */

    rpnstack_init(&rpnstack);


    if (isnan(pdp_new[ds_idx])) {
        /* a final bit of unknown to be added before calculation
           we use a temporary variable for this so that we
           don't have to turn integer lines before using the value */
        pre_unknown = pre_int;
    } else {
        if (isnan(scratch[PDP_val].u_val)) {
            scratch[PDP_val].u_val = 0;
        }
        scratch[PDP_val].u_val += pdp_new[ds_idx] / interval * pre_int;
    }

    /* if too much of the pdp_prep is unknown we dump it */
    /* if the interval is larger thatn mrhb we get NAN */
    if ((interval > mrhb) ||
        (rrd->stat_head->pdp_step / 2.0 <
         (signed) scratch[PDP_unkn_sec_cnt].u_cnt)) {
        pdp_temp[ds_idx] = DNAN;
    } else {
        pdp_temp[ds_idx] = scratch[PDP_val].u_val /
            ((double) (diff_pdp_st - scratch[PDP_unkn_sec_cnt].u_cnt) -
             pre_unknown);
    }

    /* process CDEF data sources; remember each CDEF DS can
     * only reference other DS with a lower index number */
    if (dst_conv(rrd->ds_def[ds_idx].dst) == DST_CDEF) {
        rpnp_t   *rpnp;

        rpnp =
            rpn_expand((rpn_cdefds_t *) &(rrd->ds_def[ds_idx].par[DS_cdef]));
        if(rpnp == NULL) {
          rpnstack_free(&rpnstack);
          return -1;
        }
        /* substitute data values for OP_VARIABLE nodes */
        for (i = 0; rpnp[i].op != OP_END; i++) {
            if (rpnp[i].op == OP_VARIABLE) {
                rpnp[i].op = OP_NUMBER;
                rpnp[i].val = pdp_temp[rpnp[i].ptr];
            }
        }
        /* run the rpn calculator */
        if (rpn_calc(rpnp, &rpnstack, 0, pdp_temp, ds_idx) == -1) {
            free(rpnp);
            rpnstack_free(&rpnstack);
            return -1;
        }
        free(rpnp);
    }

    /* make pdp_prep ready for the next run */
    if (isnan(pdp_new[ds_idx])) {
        /* this is not realy accurate if we use subsecond data arival time
           should have thought of it when going subsecond resolution ...
           sorry next format change we will have it! */
        scratch[PDP_unkn_sec_cnt].u_cnt = floor(post_int);
        scratch[PDP_val].u_val = DNAN;
    } else {
        scratch[PDP_unkn_sec_cnt].u_cnt = 0;
        scratch[PDP_val].u_val = pdp_new[ds_idx] / interval * post_int;
    }
    rpnstack_free(&rpnstack);
    return 0;
}

/*
 * Iterate over all the RRAs for a given DS and:
 * 1. Decide whether to schedule a smooth later
 * 2. Decide whether to skip updating SEASONAL and DEVSEASONAL
 * 3. Update the CDP
 *
 * Returns 0 on success, -1 on error
 */
static int update_all_cdp_prep(
    rrd_t *rrd,
    unsigned long *rra_step_cnt,
    unsigned long rra_begin,
    rrd_file_t *rrd_file,
    unsigned long elapsed_pdp_st,
    unsigned long proc_pdp_cnt,
    rrd_value_t **last_seasonal_coef,
    rrd_value_t **seasonal_coef,
    rrd_value_t *pdp_temp,
    unsigned long *skip_update,
    int *schedule_smooth)
{
    unsigned long rra_idx;

    /* index into the CDP scratch array */
    enum cf_en current_cf;
    unsigned long rra_start;

    /* number of rows to be updated in an RRA for a data value. */
    unsigned long start_pdp_offset;

    rra_start = rra_begin;
    for (rra_idx = 0; rra_idx < rrd->stat_head->rra_cnt; rra_idx++) {
        current_cf = cf_conv(rrd->rra_def[rra_idx].cf_nam);
        start_pdp_offset =
            rrd->rra_def[rra_idx].pdp_cnt -
            proc_pdp_cnt % rrd->rra_def[rra_idx].pdp_cnt;
        skip_update[rra_idx] = 0;
        if (start_pdp_offset <= elapsed_pdp_st) {
            rra_step_cnt[rra_idx] = (elapsed_pdp_st - start_pdp_offset) /
                rrd->rra_def[rra_idx].pdp_cnt + 1;
        } else {
            rra_step_cnt[rra_idx] = 0;
        }

        if (current_cf == CF_SEASONAL || current_cf == CF_DEVSEASONAL) {
            /* If this is a bulk update, we need to skip ahead in the seasonal arrays
             * so that they will be correct for the next observed value; note that for
             * the bulk update itself, no update will occur to DEVSEASONAL or SEASONAL;
             * futhermore, HWPREDICT and DEVPREDICT will be set to DNAN. */
            if (rra_step_cnt[rra_idx] > 1) {
                skip_update[rra_idx] = 1;
                lookup_seasonal(rrd, rra_idx, rra_start, rrd_file,
                                elapsed_pdp_st, last_seasonal_coef);
                lookup_seasonal(rrd, rra_idx, rra_start, rrd_file,
                                elapsed_pdp_st + 1, seasonal_coef);
            }
            /* periodically run a smoother for seasonal effects */
            if (do_schedule_smooth(rrd, rra_idx, elapsed_pdp_st)) {
#ifdef DEBUG
                fprintf(stderr,
                        "schedule_smooth: cur_row %lu, elapsed_pdp_st %lu, smooth idx %lu\n",
                        rrd->rra_ptr[rra_idx].cur_row, elapsed_pdp_st,
                        rrd->rra_def[rra_idx].par[RRA_seasonal_smooth_idx].
                        u_cnt);
#endif
                *schedule_smooth = 1;
            }
        }
        if (rrd_test_error())
            return -1;

        if (update_cdp_prep
            (rrd, elapsed_pdp_st, start_pdp_offset, rra_step_cnt, rra_idx,
             pdp_temp, *last_seasonal_coef, *seasonal_coef,
             current_cf) == -1) {
            return -1;
        }
        rra_start +=
            rrd->rra_def[rra_idx].row_cnt * rrd->stat_head->ds_cnt *
            sizeof(rrd_value_t);
    }
    return 0;
}

/* 
 * Are we due for a smooth? Also increments our position in the burn-in cycle.
 */
static int do_schedule_smooth(
    rrd_t *rrd,
    unsigned long rra_idx,
    unsigned long elapsed_pdp_st)
{
    unsigned long cdp_idx = rra_idx * (rrd->stat_head->ds_cnt);
    unsigned long cur_row = rrd->rra_ptr[rra_idx].cur_row;
    unsigned long row_cnt = rrd->rra_def[rra_idx].row_cnt;
    unsigned long seasonal_smooth_idx =
        rrd->rra_def[rra_idx].par[RRA_seasonal_smooth_idx].u_cnt;
    unsigned long *init_seasonal =
        &(rrd->cdp_prep[cdp_idx].scratch[CDP_init_seasonal].u_cnt);

    /* Need to use first cdp parameter buffer to track burnin (burnin requires
     * a specific smoothing schedule).  The CDP_init_seasonal parameter is
     * really an RRA level, not a data source within RRA level parameter, but
     * the rra_def is read only for rrd_update (not flushed to disk). */
    if (*init_seasonal > BURNIN_CYCLES) {
        /* someone has no doubt invented a trick to deal with this wrap around,
         * but at least this code is clear. */
        if (seasonal_smooth_idx > cur_row) {
            /* here elapsed_pdp_st = rra_step_cnt[rra_idx] because of 1-1 mapping
             * between PDP and CDP */
            return (cur_row + elapsed_pdp_st >= seasonal_smooth_idx);
        }
        /* can't rely on negative numbers because we are working with
         * unsigned values */
        return (cur_row + elapsed_pdp_st >= row_cnt
                && cur_row + elapsed_pdp_st >= row_cnt + seasonal_smooth_idx);
    }
    /* mark off one of the burn-in cycles */
    return (cur_row + elapsed_pdp_st >= row_cnt && ++(*init_seasonal));
}

/*
 * For a given RRA, iterate over the data sources and call the appropriate
 * consolidation function.
 *
 * Returns 0 on success, -1 on error.
 */
static int update_cdp_prep(
    rrd_t *rrd,
    unsigned long elapsed_pdp_st,
    unsigned long start_pdp_offset,
    unsigned long *rra_step_cnt,
    int rra_idx,
    rrd_value_t *pdp_temp,
    rrd_value_t *last_seasonal_coef,
    rrd_value_t *seasonal_coef,
    int current_cf)
{
    unsigned long ds_idx, cdp_idx;

    /* update CDP_PREP areas */
    /* loop over data soures within each RRA */
    for (ds_idx = 0; ds_idx < rrd->stat_head->ds_cnt; ds_idx++) {

        cdp_idx = rra_idx * rrd->stat_head->ds_cnt + ds_idx;

        if (rrd->rra_def[rra_idx].pdp_cnt > 1) {
            update_cdp(rrd->cdp_prep[cdp_idx].scratch, current_cf,
                       pdp_temp[ds_idx], rra_step_cnt[rra_idx],
                       elapsed_pdp_st, start_pdp_offset,
                       rrd->rra_def[rra_idx].pdp_cnt,
                       rrd->rra_def[rra_idx].par[RRA_cdp_xff_val].u_val,
                       rra_idx, ds_idx);
        } else {
            /* Nothing to consolidate if there's one PDP per CDP. However, if
             * we've missed some PDPs, let's update null counters etc. */
            if (elapsed_pdp_st > 2) {
                reset_cdp(rrd, elapsed_pdp_st, pdp_temp, last_seasonal_coef,
                          seasonal_coef, rra_idx, ds_idx, cdp_idx,
                          (enum cf_en)current_cf);
            }
        }

        if (rrd_test_error())
            return -1;
    }                   /* endif data sources loop */
    return 0;
}

/*
 * Given the new reading (pdp_temp_val), update or initialize the CDP value,
 * primary value, secondary value, and # of unknowns.
 */
static void update_cdp(
    unival *scratch,
    int current_cf,
    rrd_value_t pdp_temp_val,
    unsigned long rra_step_cnt,
    unsigned long elapsed_pdp_st,
    unsigned long start_pdp_offset,
    unsigned long pdp_cnt,
    rrd_value_t xff,
    int i,
    int ii)
{
    /* shorthand variables */
    rrd_value_t *cdp_val = &scratch[CDP_val].u_val;
    rrd_value_t *cdp_primary_val = &scratch[CDP_primary_val].u_val;
    rrd_value_t *cdp_secondary_val = &scratch[CDP_secondary_val].u_val;
    unsigned long *cdp_unkn_pdp_cnt = &scratch[CDP_unkn_pdp_cnt].u_cnt;

    if (rra_step_cnt) {
        /* If we are in this block, as least 1 CDP value will be written to
         * disk, this is the CDP_primary_val entry. If more than 1 value needs
         * to be written, then the "fill in" value is the CDP_secondary_val
         * entry. */
        if (isnan(pdp_temp_val)) {
            *cdp_unkn_pdp_cnt += start_pdp_offset;
            *cdp_secondary_val = DNAN;
        } else {
            /* CDP_secondary value is the RRA "fill in" value for intermediary
             * CDP data entries. No matter the CF, the value is the same because
             * the average, max, min, and last of a list of identical values is
             * the same, namely, the value itself. */
            *cdp_secondary_val = pdp_temp_val;
        }

        if (*cdp_unkn_pdp_cnt > pdp_cnt * xff) {
            *cdp_primary_val = DNAN;
        } else {
            initialize_cdp_val(scratch, current_cf, pdp_temp_val,
                               start_pdp_offset, pdp_cnt);
        }
        *cdp_val =
            initialize_carry_over(pdp_temp_val,current_cf,
                                  elapsed_pdp_st,
                                  start_pdp_offset, pdp_cnt);
               /* endif meets xff value requirement for a valid value */
        /* initialize carry over CDP_unkn_pdp_cnt, this must after CDP_primary_val
         * is set because CDP_unkn_pdp_cnt is required to compute that value. */
        if (isnan(pdp_temp_val))
            *cdp_unkn_pdp_cnt = (elapsed_pdp_st - start_pdp_offset) % pdp_cnt;
        else
            *cdp_unkn_pdp_cnt = 0;
    } else {            /* rra_step_cnt[i]  == 0 */

#ifdef DEBUG
        if (isnan(*cdp_val)) {
            fprintf(stderr, "schedule CDP_val update, RRA %d DS %d, DNAN\n",
                    i, ii);
        } else {
            fprintf(stderr, "schedule CDP_val update, RRA %d DS %d, %10.2f\n",
                    i, ii, *cdp_val);
        }
#endif
        if (isnan(pdp_temp_val)) {
            *cdp_unkn_pdp_cnt += elapsed_pdp_st;
        } else {
            *cdp_val =
                calculate_cdp_val(*cdp_val, pdp_temp_val, elapsed_pdp_st,
                                  current_cf, i, ii);
        }
    }
}

/*
 * Set the CDP_primary_val and CDP_val to the appropriate initial value based
 * on the type of consolidation function.
 */
static void initialize_cdp_val(
    unival *scratch,
    int current_cf,
    rrd_value_t pdp_temp_val,
    unsigned long start_pdp_offset,
    unsigned long pdp_cnt)
{
    rrd_value_t cum_val, cur_val;

    switch (current_cf) {
    case CF_AVERAGE:
        cum_val = IFDNAN(scratch[CDP_val].u_val, 0.0);
        cur_val = IFDNAN(pdp_temp_val, 0.0);
        scratch[CDP_primary_val].u_val =
            (cum_val + cur_val * start_pdp_offset) /
            (pdp_cnt - scratch[CDP_unkn_pdp_cnt].u_cnt);
        break;
    case CF_MAXIMUM: 
        cum_val = IFDNAN(scratch[CDP_val].u_val, -DINF);
        cur_val = IFDNAN(pdp_temp_val, -DINF);

#if 0
#ifdef DEBUG
        if (isnan(scratch[CDP_val].u_val) && isnan(pdp_temp)) {
            fprintf(stderr,
                    "RRA %lu, DS %lu, both CDP_val and pdp_temp are DNAN!",
                    i, ii);
            exit(-1);
        }
#endif
#endif
        if (cur_val > cum_val)
            scratch[CDP_primary_val].u_val = cur_val;
        else
            scratch[CDP_primary_val].u_val = cum_val;
        break;
    case CF_MINIMUM:
        cum_val = IFDNAN(scratch[CDP_val].u_val, DINF);
        cur_val = IFDNAN(pdp_temp_val, DINF);
#if 0
#ifdef DEBUG
        if (isnan(scratch[CDP_val].u_val) && isnan(pdp_temp)) {
            fprintf(stderr,
                    "RRA %lu, DS %lu, both CDP_val and pdp_temp are DNAN!", i,
                    ii);
            exit(-1);
        }
#endif
#endif
        if (cur_val < cum_val)
            scratch[CDP_primary_val].u_val = cur_val;
        else
            scratch[CDP_primary_val].u_val = cum_val;
        break;
    case CF_LAST:
    default:
        scratch[CDP_primary_val].u_val = pdp_temp_val;
        break;
    }
}

/*
 * Update the consolidation function for Holt-Winters functions as
 * well as other functions that don't actually consolidate multiple
 * PDPs.
 */
static void reset_cdp(
    rrd_t *rrd,
    unsigned long elapsed_pdp_st,
    rrd_value_t *pdp_temp,
    rrd_value_t *last_seasonal_coef,
    rrd_value_t *seasonal_coef,
    int rra_idx,
    int ds_idx,
    int cdp_idx,
    enum cf_en current_cf)
{
    unival   *scratch = rrd->cdp_prep[cdp_idx].scratch;

    switch (current_cf) {
    case CF_AVERAGE:
    default:
        scratch[CDP_primary_val].u_val = pdp_temp[ds_idx];
        scratch[CDP_secondary_val].u_val = pdp_temp[ds_idx];
        break;
    case CF_SEASONAL:
    case CF_DEVSEASONAL:
        /* need to update cached seasonal values, so they are consistent
         * with the bulk update */
        /* WARNING: code relies on the fact that CDP_hw_last_seasonal and
         * CDP_last_deviation are the same. */
        scratch[CDP_hw_last_seasonal].u_val = last_seasonal_coef[ds_idx];
        scratch[CDP_hw_seasonal].u_val = seasonal_coef[ds_idx];
        break;
    case CF_HWPREDICT:
    case CF_MHWPREDICT:
        /* need to update the null_count and last_null_count.
         * even do this for non-DNAN pdp_temp because the
         * algorithm is not learning from batch updates. */
        scratch[CDP_null_count].u_cnt += elapsed_pdp_st;
        scratch[CDP_last_null_count].u_cnt += elapsed_pdp_st - 1;
        /* fall through */
    case CF_DEVPREDICT:
        scratch[CDP_primary_val].u_val = DNAN;
        scratch[CDP_secondary_val].u_val = DNAN;
        break;
    case CF_FAILURES:
        /* do not count missed bulk values as failures */
        scratch[CDP_primary_val].u_val = 0;
        scratch[CDP_secondary_val].u_val = 0;
        /* need to reset violations buffer.
         * could do this more carefully, but for now, just
         * assume a bulk update wipes away all violations. */
        erase_violations(rrd, cdp_idx, rra_idx);
        break;
    }
}

static rrd_value_t initialize_carry_over(
    rrd_value_t pdp_temp_val,
    int current_cf,
    unsigned long elapsed_pdp_st,
    unsigned long start_pdp_offset,
    unsigned long pdp_cnt)
{
    unsigned long pdp_into_cdp_cnt = ((elapsed_pdp_st - start_pdp_offset) % pdp_cnt);
    if ( pdp_into_cdp_cnt == 0 || isnan(pdp_temp_val)){
        switch (current_cf) {
        case CF_MAXIMUM:
            return -DINF;
        case CF_MINIMUM:
            return DINF;
        case CF_AVERAGE:
            return 0;
        default:
            return DNAN;
        }        
    } 
    else {
        switch (current_cf) {
        case CF_AVERAGE:
            return pdp_temp_val *  pdp_into_cdp_cnt ;
        default:
            return pdp_temp_val;
        }        
    }        
}

/*
 * Update or initialize a CDP value based on the consolidation
 * function.
 *
 * Returns the new value.
 */
static rrd_value_t calculate_cdp_val(
    rrd_value_t cdp_val,
    rrd_value_t pdp_temp_val,
    unsigned long elapsed_pdp_st,
    int current_cf,
#ifdef DEBUG
    int i,
    int ii
#else
    int UNUSED(i),
    int UNUSED(ii)
#endif
    )
{
    if (isnan(cdp_val)) {
        if (current_cf == CF_AVERAGE) {
            pdp_temp_val *= elapsed_pdp_st;
        }
#ifdef DEBUG
        fprintf(stderr, "Initialize CDP_val for RRA %d DS %d: %10.2f\n",
                i, ii, pdp_temp_val);
#endif
        return pdp_temp_val;
    }
    if (current_cf == CF_AVERAGE)
        return cdp_val + pdp_temp_val * elapsed_pdp_st;
    if (current_cf == CF_MINIMUM)
        return (pdp_temp_val < cdp_val) ? pdp_temp_val : cdp_val;
    if (current_cf == CF_MAXIMUM)
        return (pdp_temp_val > cdp_val) ? pdp_temp_val : cdp_val;

    return pdp_temp_val;
}

/*
 * For each RRA, update the seasonal values and then call update_aberrant_CF
 * for each data source.
 *
 * Return 0 on success, -1 on error.
 */
static int update_aberrant_cdps(
    rrd_t *rrd,
    rrd_file_t *rrd_file,
    unsigned long rra_begin,
    unsigned long elapsed_pdp_st,
    rrd_value_t *pdp_temp,
    rrd_value_t **seasonal_coef)
{
    unsigned long rra_idx, ds_idx, j;

    /* number of PDP steps since the last update that
     * are assigned to the first CDP to be generated
     * since the last update. */
    unsigned short scratch_idx;
    unsigned long rra_start;
    enum cf_en current_cf;

    /* this loop is only entered if elapsed_pdp_st < 3 */
    for (j = elapsed_pdp_st, scratch_idx = CDP_primary_val;
         j > 0 && j < 3; j--, scratch_idx = CDP_secondary_val) {
        rra_start = rra_begin;
        for (rra_idx = 0; rra_idx < rrd->stat_head->rra_cnt; rra_idx++) {
            if (rrd->rra_def[rra_idx].pdp_cnt == 1) {
                current_cf = cf_conv(rrd->rra_def[rra_idx].cf_nam);
                if (current_cf == CF_SEASONAL || current_cf == CF_DEVSEASONAL) {
                    if (scratch_idx == CDP_primary_val) {
                        lookup_seasonal(rrd, rra_idx, rra_start, rrd_file,
                                        elapsed_pdp_st + 1, seasonal_coef);
                    } else {
                        lookup_seasonal(rrd, rra_idx, rra_start, rrd_file,
                                        elapsed_pdp_st + 2, seasonal_coef);
                    }
                }
                if (rrd_test_error())
                    return -1;
                /* loop over data soures within each RRA */
                for (ds_idx = 0; ds_idx < rrd->stat_head->ds_cnt; ds_idx++) {
                    update_aberrant_CF(rrd, pdp_temp[ds_idx], current_cf,
                                       rra_idx * (rrd->stat_head->ds_cnt) +
                                       ds_idx, rra_idx, ds_idx, scratch_idx,
                                       *seasonal_coef);
                }
            }
            rra_start += rrd->rra_def[rra_idx].row_cnt
                * rrd->stat_head->ds_cnt * sizeof(rrd_value_t);
        }
    }
    return 0;
}

/* 
 * Move sequentially through the file, writing one RRA at a time.  Note this
 * architecture divorces the computation of CDP with flushing updated RRA
 * entries to disk.
 *
 * Return 0 on success, -1 on error.
 */
static int write_to_rras(
    rrd_t *rrd,
    rrd_file_t *rrd_file,
    unsigned long *rra_step_cnt,
    unsigned long rra_begin,
    time_t current_time,
    unsigned long *skip_update,
    rrd_info_t ** pcdp_summary)
{
    unsigned long rra_idx;
    unsigned long rra_start;
    time_t    rra_time = 0; /* time of update for a RRA */

    unsigned long ds_cnt = rrd->stat_head->ds_cnt;
    
    /* Ready to write to disk */
    rra_start = rra_begin;

    for (rra_idx = 0; rra_idx < rrd->stat_head->rra_cnt; rra_idx++) {
        rra_def_t *rra_def = &rrd->rra_def[rra_idx];
        rra_ptr_t *rra_ptr = &rrd->rra_ptr[rra_idx];

        /* for cdp_prep */
        unsigned short scratch_idx;
        unsigned long step_subtract;

        for (scratch_idx = CDP_primary_val,
                 step_subtract = 1;
             rra_step_cnt[rra_idx] > 0;
             rra_step_cnt[rra_idx]--,
                 scratch_idx = CDP_secondary_val,
                 step_subtract = 2) {

            size_t rra_pos_new;
#ifdef DEBUG
            fprintf(stderr, "  -- RRA Preseek %ld\n", rrd_file->pos);
#endif
            /* increment, with wrap-around */
            if (++rra_ptr->cur_row >= rra_def->row_cnt)
              rra_ptr->cur_row = 0;

            /* we know what our position should be */
            rra_pos_new = rra_start
              + ds_cnt * rra_ptr->cur_row * sizeof(rrd_value_t);

            /* re-seek if the position is wrong or we wrapped around */
            if ((size_t)rra_pos_new != rrd_file->pos) {
                if (rrd_seek(rrd_file, rra_pos_new, SEEK_SET) != 0) {
                    rrd_set_error("seek error in rrd");
                    return -1;
                }
            }
#ifdef DEBUG
            fprintf(stderr, "  -- RRA Postseek %ld\n", rrd_file->pos);
#endif

            if (skip_update[rra_idx])
                continue;

            if (*pcdp_summary != NULL) {
                unsigned long step_time = rra_def->pdp_cnt * rrd->stat_head->pdp_step;

                rra_time = (current_time - current_time % step_time)
                    - ((rra_step_cnt[rra_idx] - step_subtract) * step_time);
            }

            if (write_RRA_row
                (rrd_file, rrd, rra_idx, scratch_idx,
                 pcdp_summary, rra_time) == -1)
                return -1;

            rrd_notify_row(rrd_file, rra_idx, rra_pos_new, rra_time);
        }

        rra_start += rra_def->row_cnt * ds_cnt * sizeof(rrd_value_t);
    } /* RRA LOOP */

    return 0;
}

/*
 * Write out one row of values (one value per DS) to the archive.
 *
 * Returns 0 on success, -1 on error.
 */
static int write_RRA_row(
    rrd_file_t *rrd_file,
    rrd_t *rrd,
    unsigned long rra_idx,
    unsigned short CDP_scratch_idx,
    rrd_info_t ** pcdp_summary,
    time_t rra_time)
{
    unsigned long ds_idx, cdp_idx;
    rrd_infoval_t iv;

    for (ds_idx = 0; ds_idx < rrd->stat_head->ds_cnt; ds_idx++) {
        /* compute the cdp index */
        cdp_idx = rra_idx * (rrd->stat_head->ds_cnt) + ds_idx;
#ifdef DEBUG
        fprintf(stderr, "  -- RRA WRITE VALUE %e, at %ld CF:%s\n",
                rrd->cdp_prep[cdp_idx].scratch[CDP_scratch_idx].u_val,
                rrd_file->pos, rrd->rra_def[rra_idx].cf_nam);
#endif
        if (*pcdp_summary != NULL) {
            iv.u_val = rrd->cdp_prep[cdp_idx].scratch[CDP_scratch_idx].u_val;
            /* append info to the return hash */
            *pcdp_summary = rrd_info_push(*pcdp_summary,
                                          sprintf_alloc
                                          ("[%lli]RRA[%s][%lu]DS[%s]", 
                                           (long long)rra_time,
                                           rrd->rra_def[rra_idx].cf_nam,
                                           rrd->rra_def[rra_idx].pdp_cnt,
                                           rrd->ds_def[ds_idx].ds_nam),
                                           RD_I_VAL, iv);
        }
        errno = 0;
        if (rrd_write(rrd_file,
                      &(rrd->cdp_prep[cdp_idx].scratch[CDP_scratch_idx].
                        u_val), sizeof(rrd_value_t)) != sizeof(rrd_value_t)) {
            rrd_set_error("writing rrd: %s", rrd_strerror(errno));
            return -1;
        }
    }
    return 0;
}

/*
 * Call apply_smoother for all DEVSEASONAL and SEASONAL RRAs.
 *
 * Returns 0 on success, -1 otherwise
 */
static int smooth_all_rras(
    rrd_t *rrd,
    rrd_file_t *rrd_file,
    unsigned long rra_begin)
{
    unsigned long rra_start = rra_begin;
    unsigned long rra_idx;

    for (rra_idx = 0; rra_idx < rrd->stat_head->rra_cnt; ++rra_idx) {
        if (cf_conv(rrd->rra_def[rra_idx].cf_nam) == CF_DEVSEASONAL ||
            cf_conv(rrd->rra_def[rra_idx].cf_nam) == CF_SEASONAL) {
#ifdef DEBUG
            fprintf(stderr, "Running smoother for rra %lu\n", rra_idx);
#endif
            apply_smoother(rrd, rra_idx, rra_start, rrd_file);
            if (rrd_test_error())
                return -1;
        }
        rra_start += rrd->rra_def[rra_idx].row_cnt
            * rrd->stat_head->ds_cnt * sizeof(rrd_value_t);
    }
    return 0;
}

#ifndef HAVE_MMAP
/*
 * Flush changes to disk (unless we're using mmap)
 *
 * Returns 0 on success, -1 otherwise
 */
static int write_changes_to_disk(
    rrd_t *rrd,
    rrd_file_t *rrd_file,
    int version)
{
    /* we just need to write back the live header portion now */
    if (rrd_seek(rrd_file, (sizeof(stat_head_t)
                            + sizeof(ds_def_t) * rrd->stat_head->ds_cnt
                            + sizeof(rra_def_t) * rrd->stat_head->rra_cnt),
                 SEEK_SET) != 0) {
        rrd_set_error("seek rrd for live header writeback");
        return -1;
    }
    if (version >= 3) {
        if (rrd_write(rrd_file, rrd->live_head,
                      sizeof(live_head_t) * 1) != sizeof(live_head_t) * 1) {
            rrd_set_error("rrd_write live_head to rrd");
            return -1;
        }
    } else {
        if (rrd_write(rrd_file, rrd->legacy_last_up,
                      sizeof(time_t) * 1) != sizeof(time_t) * 1) {
            rrd_set_error("rrd_write live_head to rrd");
            return -1;
        }
    }


    if (rrd_write(rrd_file, rrd->pdp_prep,
                  sizeof(pdp_prep_t) * rrd->stat_head->ds_cnt)
        != (ssize_t) (sizeof(pdp_prep_t) * rrd->stat_head->ds_cnt)) {
        rrd_set_error("rrd_write pdp_prep to rrd");
        return -1;
    }

    if (rrd_write(rrd_file, rrd->cdp_prep,
                  sizeof(cdp_prep_t) * rrd->stat_head->rra_cnt *
                  rrd->stat_head->ds_cnt)
        != (ssize_t) (sizeof(cdp_prep_t) * rrd->stat_head->rra_cnt *
                      rrd->stat_head->ds_cnt)) {

        rrd_set_error("rrd_write cdp_prep to rrd");
        return -1;
    }

    if (rrd_write(rrd_file, rrd->rra_ptr,
                  sizeof(rra_ptr_t) * rrd->stat_head->rra_cnt)
        != (ssize_t) (sizeof(rra_ptr_t) * rrd->stat_head->rra_cnt)) {
        rrd_set_error("rrd_write rra_ptr to rrd");
        return -1;
    }
    return 0;
}
#endif
