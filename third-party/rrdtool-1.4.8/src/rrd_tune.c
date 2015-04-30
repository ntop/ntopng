/*****************************************************************************
 * RRDtool 1.4.8  Copyright by Tobi Oetiker, 1997-2013
 *****************************************************************************
 * change header parameters of an rrd
 *****************************************************************************
 * $Id$
 * $Log$
 * Revision 1.6  2004/05/26 22:11:12  oetiker
 * reduce compiler warnings. Many small fixes. -- Mike Slifcak <slif@bellsouth.net>
 *
 * Revision 1.5  2002/02/01 20:34:49  oetiker
 * fixed version number and date/time
 *
 * Revision 1.4  2001/08/22 22:29:07  jake
 * Contents of this patch:
 * (1) Adds/revises documentation for rrd tune in rrd_tool.c and pod files.
 * (2) Moves some initialization code from rrd_create.c to rrd_hw.c.
 * (3) Adds another pass to smoothing for SEASONAL and DEVSEASONAL RRAs.
 * This pass computes the coefficients as deviations from an average; the
 * average is added the baseline coefficient of HWPREDICT. Statistical texts
 * suggest this to preserve algorithm stability. It will not invalidate
 * RRD files created and smoothed with the old code.
 * (4) Adds the aberrant-reset flag to rrd tune. This operation, which is
 * specified for a single data source, causes the holt-winters algorithm to
 * forget everthing it has learned and start over.
 * (5) Fixes a few out-of-date code comments.
 *
 * Revision 1.3  2001/03/07 21:21:54  oetiker
 * complete rewrite of rrdgraph documentation. This also includs info
 * on upcomming/planned changes to the rrdgraph interface and functionality
 * -- Alex van den Bogaerdt <alex@slot.hollandcasino.nl>
 *
 * Revision 1.2  2001/03/04 13:01:55  oetiker
 * Aberrant Behavior Detection support. A brief overview added to rrdtool.pod.
 * Major updates to rrd_update.c, rrd_create.c. Minor update to other core files.
 * This is backwards compatible! But new files using the Aberrant stuff are not readable
 * by old rrdtool versions. See http://cricket.sourceforge.net/aberrant/rrd_hw.htm
 * -- Jake Brutlag <jakeb@corp.webtv.net>
 *
 *****************************************************************************/

#include <stdlib.h>
#include <locale.h>

#include "rrd_tool.h"
#include "rrd_rpncalc.h"
#include "rrd_hw.h"

int       set_hwarg(
    rrd_t *rrd,
    enum cf_en cf,
    enum rra_par_en rra_par,
    char *arg);
int       set_deltaarg(
    rrd_t *rrd,
    enum rra_par_en rra_par,
    char *arg);
int       set_windowarg(
    rrd_t *rrd,
    enum rra_par_en,
    char *arg);

int set_hwsmootharg(
    rrd_t *rrd,
    enum cf_en cf,
    enum rra_par_en rra_par,
    char *arg);

int rrd_tune(
    int argc,
    char **argv)
{
    rrd_t     rrd;
    int       matches;
    int       optcnt = 0;
    long      ds;
    char      ds_nam[DS_NAM_SIZE];
    char      ds_new[DS_NAM_SIZE];
    long      heartbeat;
    double    min;
    double    max;
    char      dst[DST_SIZE];
    rrd_file_t *rrd_file;
    struct option long_options[] = {
        {"heartbeat", required_argument, 0, 'h'},
        {"minimum", required_argument, 0, 'i'},
        {"maximum", required_argument, 0, 'a'},
        {"data-source-type", required_argument, 0, 'd'},
        {"data-source-rename", required_argument, 0, 'r'},
        /* added parameter tuning options for aberrant behavior detection */
        {"deltapos", required_argument, 0, 'p'},
        {"deltaneg", required_argument, 0, 'n'},
        {"window-length", required_argument, 0, 'w'},
        {"failure-threshold", required_argument, 0, 'f'},
        {"alpha", required_argument, 0, 'x'},
        {"beta", required_argument, 0, 'y'},
        {"gamma", required_argument, 0, 'z'},
        {"gamma-deviation", required_argument, 0, 'v'},
        {"smoothing-window", required_argument, 0, 's'},
        {"smoothing-window-deviation", required_argument, 0, 'S'},
        {"aberrant-reset", required_argument, 0, 'b'},
        {0, 0, 0, 0}
    };

    optind = 0;
    opterr = 0;         /* initialize getopt */


    rrd_init(&rrd);
    rrd_file = rrd_open(argv[1], &rrd, RRD_READWRITE);
    if (rrd_file == NULL) {
        rrd_free(&rrd);
        return -1;
    }

    while (1) {
        int       option_index = 0;
        int       opt;
        char     *old_locale = "";

        opt = getopt_long(argc, argv, "h:i:a:d:r:p:n:w:f:x:y:z:v:b:",
                          long_options, &option_index);
        if (opt == EOF)
            break;

        optcnt++;
        switch (opt) {
        case 'h':
            old_locale = setlocale(LC_NUMERIC, NULL);
            setlocale(LC_NUMERIC, "C");
            if ((matches =
                 sscanf(optarg, DS_NAM_FMT ":%ld", ds_nam,
                        &heartbeat)) != 2) {
                rrd_set_error("invalid arguments for heartbeat");
                rrd_free(&rrd);
                rrd_close(rrd_file);
                setlocale(LC_NUMERIC, old_locale);
                return -1;
            }
            setlocale(LC_NUMERIC, old_locale);
            if ((ds = ds_match(&rrd, ds_nam)) == -1) {
                rrd_free(&rrd);
                rrd_close(rrd_file);
                return -1;
            }
            rrd.ds_def[ds].par[DS_mrhb_cnt].u_cnt = heartbeat;
            break;

        case 'i':
            old_locale = setlocale(LC_NUMERIC, NULL);
            setlocale(LC_NUMERIC, "C");
            if ((matches =
                 sscanf(optarg, DS_NAM_FMT ":%lf", ds_nam, &min)) < 1) {
                rrd_set_error("invalid arguments for minimum ds value");
                rrd_free(&rrd);
                rrd_close(rrd_file);
                setlocale(LC_NUMERIC, old_locale);
                return -1;
            }
            setlocale(LC_NUMERIC, old_locale);
            if ((ds = ds_match(&rrd, ds_nam)) == -1) {
                rrd_free(&rrd);
                rrd_close(rrd_file);
                return -1;
            }

            if (matches == 1)
                min = DNAN;
            rrd.ds_def[ds].par[DS_min_val].u_val = min;
            break;

        case 'a':
            old_locale = setlocale(LC_NUMERIC, NULL);
            setlocale(LC_NUMERIC, "C");
            if ((matches =
                 sscanf(optarg, DS_NAM_FMT ":%lf", ds_nam, &max)) < 1) {
                rrd_set_error("invalid arguments for maximum ds value");
                rrd_free(&rrd);
                rrd_close(rrd_file);
                setlocale(LC_NUMERIC, old_locale);
                return -1;
            }
            setlocale(LC_NUMERIC, old_locale);
            if ((ds = ds_match(&rrd, ds_nam)) == -1) {
                rrd_free(&rrd);
                rrd_close(rrd_file);
                return -1;
            }
            if (matches == 1)
                max = DNAN;
            rrd.ds_def[ds].par[DS_max_val].u_val = max;
            break;

        case 'd':
            if ((matches =
                 sscanf(optarg, DS_NAM_FMT ":" DST_FMT, ds_nam, dst)) != 2) {
                rrd_set_error("invalid arguments for data source type");
                rrd_free(&rrd);
                rrd_close(rrd_file);
                return -1;
            }
            if ((ds = ds_match(&rrd, ds_nam)) == -1) {
                rrd_free(&rrd);
                rrd_close(rrd_file);
                return -1;
            }
            if ((int) dst_conv(dst) == -1) {
                rrd_free(&rrd);
                rrd_close(rrd_file);
                return -1;
            }
            /* only reset when something is changed */
            if (strncmp(rrd.ds_def[ds].dst, dst, DST_SIZE - 1) != 0) {
                strncpy(rrd.ds_def[ds].dst, dst, DST_SIZE - 1);
                rrd.ds_def[ds].dst[DST_SIZE - 1] = '\0';

                rrd.pdp_prep[ds].last_ds[0] = 'U';
                rrd.pdp_prep[ds].last_ds[1] = 'N';
                rrd.pdp_prep[ds].last_ds[2] = 'K';
                rrd.pdp_prep[ds].last_ds[3] = 'N';
                rrd.pdp_prep[ds].last_ds[4] = '\0';
            }
            break;
        case 'r':
            if ((matches =
                 sscanf(optarg, DS_NAM_FMT ":" DS_NAM_FMT, ds_nam,
                        ds_new)) != 2) {
                rrd_set_error("invalid arguments for data source type");
                rrd_free(&rrd);
                rrd_close(rrd_file);
                return -1;
            }
            if ((ds = ds_match(&rrd, ds_nam)) == -1) {
                rrd_free(&rrd);
                rrd_close(rrd_file);
                return -1;
            }
            strncpy(rrd.ds_def[ds].ds_nam, ds_new, DS_NAM_SIZE - 1);
            rrd.ds_def[ds].ds_nam[DS_NAM_SIZE - 1] = '\0';
            break;
        case 'p':
            if (set_deltaarg(&rrd, RRA_delta_pos, optarg)) {
                rrd_free(&rrd);
                return -1;
            }
            break;
        case 'n':
            if (set_deltaarg(&rrd, RRA_delta_neg, optarg)) {
                rrd_free(&rrd);
                return -1;
            }
            break;
        case 'f':
            if (set_windowarg(&rrd, RRA_failure_threshold, optarg)) {
                rrd_free(&rrd);
                return -1;
            }
            break;
        case 'w':
            if (set_windowarg(&rrd, RRA_window_len, optarg)) {
                rrd_free(&rrd);
                return -1;
            }
            break;
        case 'x':
            if (set_hwarg(&rrd, CF_HWPREDICT, RRA_hw_alpha, optarg)) {
                if (set_hwarg(&rrd, CF_MHWPREDICT, RRA_hw_alpha, optarg)) {
                    rrd_free(&rrd);
                    return -1;
                }
                rrd_clear_error();
            }
            break;
        case 'y':
            if (set_hwarg(&rrd, CF_HWPREDICT, RRA_hw_beta, optarg)) {
                if (set_hwarg(&rrd, CF_MHWPREDICT, RRA_hw_beta, optarg)) {
                    rrd_free(&rrd);
                    return -1;
                }
                rrd_clear_error();
            }
            break;
        case 'z':
            if (set_hwarg(&rrd, CF_SEASONAL, RRA_seasonal_gamma, optarg)) {
                rrd_free(&rrd);
                return -1;
            }
            break;
        case 'v':
            if (set_hwarg(&rrd, CF_DEVSEASONAL, RRA_seasonal_gamma, optarg)) {
                rrd_free(&rrd);
                return -1;
            }
            break;
        case 'b':
            if (sscanf(optarg, DS_NAM_FMT, ds_nam) != 1) {
                rrd_set_error("invalid argument for aberrant-reset");
                rrd_free(&rrd);
                rrd_close(rrd_file);
                return -1;
            }
            if ((ds = ds_match(&rrd, ds_nam)) == -1) {
                /* ds_match handles it own errors */
                rrd_free(&rrd);
                rrd_close(rrd_file);
                return -1;
            }
            reset_aberrant_coefficients(&rrd, rrd_file, (unsigned long) ds);
            if (rrd_test_error()) {
                rrd_free(&rrd);
                rrd_close(rrd_file);
                return -1;
            }
            break;
        case 's':
            strcpy(rrd.stat_head->version, RRD_VERSION);    /* smoothing_window causes Version 4 */
            if (set_hwsmootharg
                (&rrd, CF_SEASONAL, RRA_seasonal_smoothing_window, optarg)) {
                rrd_free(&rrd);
                return -1;
            }
            break;
        case 'S':
            strcpy(rrd.stat_head->version, RRD_VERSION);    /* smoothing_window causes Version 4 */
            if (set_hwsmootharg
                (&rrd, CF_DEVSEASONAL, RRA_seasonal_smoothing_window,
                 optarg)) {
                rrd_free(&rrd);
                return -1;
            }
            break;
        case '?':
            if (optopt != 0)
                rrd_set_error("unknown option '%c'", optopt);
            else
                rrd_set_error("unknown option '%s'", argv[optind - 1]);
            rrd_free(&rrd);
            rrd_close(rrd_file);
            return -1;
        }
    }
    if (optcnt > 0) {
        rrd_seek(rrd_file, 0, SEEK_SET);
        rrd_write(rrd_file, rrd.stat_head, sizeof(stat_head_t) * 1);
        rrd_write(rrd_file, rrd.ds_def,
                  sizeof(ds_def_t) * rrd.stat_head->ds_cnt);
        /* need to write rra_defs for RRA parameter changes */
        rrd_write(rrd_file, rrd.rra_def,
                  sizeof(rra_def_t) * rrd.stat_head->rra_cnt);
    } else {
        int       i;

        for (i = 0; i < (int) rrd.stat_head->ds_cnt; i++)
            if (dst_conv(rrd.ds_def[i].dst) != DST_CDEF) {
                printf("DS[%s] typ: %s\thbt: %ld\tmin: %1.4f\tmax: %1.4f\n",
                       rrd.ds_def[i].ds_nam,
                       rrd.ds_def[i].dst,
                       rrd.ds_def[i].par[DS_mrhb_cnt].u_cnt,
                       rrd.ds_def[i].par[DS_min_val].u_val,
                       rrd.ds_def[i].par[DS_max_val].u_val);
            } else {
                char     *buffer = NULL;

                rpn_compact2str((rpn_cdefds_t *) &
                                (rrd.ds_def[i].par[DS_cdef]), rrd.ds_def,
                                &buffer);
                printf("DS[%s] typ: %s\tcdef: %s\n", rrd.ds_def[i].ds_nam,
                       rrd.ds_def[i].dst, buffer);
                free(buffer);
            }
    }
    rrd_close(rrd_file);
    rrd_free(&rrd);
    return 0;
}

int set_hwarg(
    rrd_t *rrd,
    enum cf_en cf,
    enum rra_par_en rra_par,
    char *arg)
{
    double    param;
    unsigned long i;
    signed short rra_idx = -1;

    /* read the value */
    param = atof(arg);
    if (param <= 0.0 || param >= 1.0) {
        rrd_set_error("Holt-Winters parameter must be between 0 and 1");
        return -1;
    }
    /* does the appropriate RRA exist?  */
    for (i = 0; i < rrd->stat_head->rra_cnt; ++i) {
        if (cf_conv(rrd->rra_def[i].cf_nam) == cf) {
            rra_idx = i;
            break;
        }
    }
    if (rra_idx == -1) {
        rrd_set_error("Holt-Winters RRA does not exist in this RRD");
        return -1;
    }

    /* set the value */
    rrd->rra_def[rra_idx].par[rra_par].u_val = param;
    return 0;
}

int set_hwsmootharg(
    rrd_t *rrd,
    enum cf_en cf,
    enum rra_par_en rra_par,
    char *arg)
{
    double    param;
    unsigned long i;
    signed short rra_idx = -1;

    /* read the value */
    param = atof(arg);
    /* in order to avoid smoothing of SEASONAL or DEVSEASONAL, we need to 
     * the 0.0 value*/
    if (param < 0.0 || param > 1.0) {
        rrd_set_error("Holt-Winters parameter must be between 0 and 1");
        return -1;
    }
    /* does the appropriate RRA exist?  */
    for (i = 0; i < rrd->stat_head->rra_cnt; ++i) {
        if (cf_conv(rrd->rra_def[i].cf_nam) == cf) {
            rra_idx = i;
            break;
        }
    }
    if (rra_idx == -1) {
        rrd_set_error("Holt-Winters RRA does not exist in this RRD");
        return -1;
    }

    /* set the value */
    rrd->rra_def[rra_idx].par[rra_par].u_val = param;
    return 0;
}

int set_deltaarg(
    rrd_t *rrd,
    enum rra_par_en rra_par,
    char *arg)
{
    rrd_value_t param;
    unsigned long i;
    signed short rra_idx = -1;

    param = atof(arg);
    if (param < 0.1) {
        rrd_set_error("Parameter specified is too small");
        return -1;
    }
    /* does the appropriate RRA exist?  */
    for (i = 0; i < rrd->stat_head->rra_cnt; ++i) {
        if (cf_conv(rrd->rra_def[i].cf_nam) == CF_FAILURES) {
            rra_idx = i;
            break;
        }
    }
    if (rra_idx == -1) {
        rrd_set_error("Failures RRA does not exist in this RRD");
        return -1;
    }

    /* set the value */
    rrd->rra_def[rra_idx].par[rra_par].u_val = param;
    return 0;
}

int set_windowarg(
    rrd_t *rrd,
    enum rra_par_en rra_par,
    char *arg)
{
    unsigned long param;
    unsigned long i, cdp_idx;
    signed short rra_idx = -1;

    /* read the value */
    param = atoi(arg);
    if (param < 1 || param > MAX_FAILURES_WINDOW_LEN) {
        rrd_set_error("Parameter must be between %d and %d",
                      1, MAX_FAILURES_WINDOW_LEN);
        return -1;
    }
    /* does the appropriate RRA exist?  */
    for (i = 0; i < rrd->stat_head->rra_cnt; ++i) {
        if (cf_conv(rrd->rra_def[i].cf_nam) == CF_FAILURES) {
            rra_idx = i;
            break;
        }
    }
    if (rra_idx == -1) {
        rrd_set_error("Failures RRA does not exist in this RRD");
        return -1;
    }

    /* set the value */
    rrd->rra_def[rra_idx].par[rra_par].u_cnt = param;

    /* erase existing violations */
    for (i = 0; i < rrd->stat_head->ds_cnt; i++) {
        cdp_idx = rra_idx * (rrd->stat_head->ds_cnt) + i;
        erase_violations(rrd, cdp_idx, rra_idx);
    }
    return 0;
}
