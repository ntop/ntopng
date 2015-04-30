/*****************************************************************************
 * RRDtool 1.4.8  Copyright by Tobi Oetiker, 1997-2013
 *****************************************************************************
 * rrd_fetch.c  read date from an rrd to use for further processing
 *****************************************************************************
 * $Id$
 * $Log$
 * Revision 1.8  2004/05/18 18:53:03  oetiker
 * big spell checking patch -- slif@bellsouth.net
 *
 * Revision 1.7  2003/11/11 19:46:21  oetiker
 * replaced time_value with rrd_time_value as MacOS X introduced a struct of that name in their standard headers
 *
 * Revision 1.6  2003/01/16 23:27:54  oetiker
 * fix border condition in rra selection of rrd_fetch
 * -- Stanislav Sinyagin <ssinyagin@yahoo.com>
 *
 * Revision 1.5  2002/06/23 22:29:40  alex
 * Added "step=1800" and such to "DEF"
 * Cleaned some of the signed vs. unsigned problems
 *
 * Revision 1.4  2002/02/01 20:34:49  oetiker
 * fixed version number and date/time
 *
 * Revision 1.3  2001/12/24 06:51:49  alex
 * A patch of size 44Kbytes... in short:
 *
 * Found and repaired the off-by-one error in rrd_fetch_fn().
 * As a result I had to remove the hacks in rrd_fetch_fn(),
 * rrd_tool.c, vdef_calc(), data_calc(), data_proc() and
 * reduce_data().  There may be other places which I didn't
 * find so be careful.
 *
 * Enhanced debugging in rrd_fetch_fn(), it shows the RRA selection
 * process.
 *
 * Added the ability to print VDEF timestamps.  At the moment it
 * is a hack, I needed it now to fix the off-by-one error.
 * If the format string is "%c" (and nothing else!), the time
 * will be printed by both ctime() and as a long int.
 *
 * Moved some code around (slightly altering it) from rrd_graph()
 *   initializing     now in rrd_graph_init()
 *   options parsing  now in rrd_graph_options()
 *   script parsing   now in rrd_graph_script()
 *
 * Revision 1.2  2001/12/17 12:48:43  oetiker
 * fix overflow error ...
 *
 * Revision 1.1.1.1  2001/02/25 22:25:05  oetiker
 * checkin
 *
 *****************************************************************************/

#include "rrd_tool.h"
#include "rrd_client.h"

#include "rrd_is_thread_safe.h"
/* #define DEBUG */

int rrd_fetch(
    int argc,
    char **argv,
    time_t *start,
    time_t *end,        /* which time frame do you want ?
                         * will be changed to represent reality */
    unsigned long *step,    /* which stepsize do you want? 
                             * will be changed to represent reality */
    unsigned long *ds_cnt,  /* number of data sources in file */
    char ***ds_namv,    /* names of data sources */
    rrd_value_t **data)
{                       /* two dimensional array containing the data */
    long      step_tmp = 1;
    time_t    start_tmp = 0, end_tmp = 0;
    const char *cf;
    char *opt_daemon = NULL;
    int status;

    rrd_time_value_t start_tv, end_tv;
    char     *parsetime_error = NULL;
    struct option long_options[] = {
        {"resolution", required_argument, 0, 'r'},
        {"start", required_argument, 0, 's'},
        {"end", required_argument, 0, 'e'},
        {"daemon", required_argument, 0, 'd'},
        {0, 0, 0, 0}
    };

    optind = 0;
    opterr = 0;         /* initialize getopt */

    /* init start and end time */
    rrd_parsetime("end-24h", &start_tv);
    rrd_parsetime("now", &end_tv);

    while (1) {
        int       option_index = 0;
        int       opt;

        opt = getopt_long(argc, argv, "r:s:e:d:", long_options, &option_index);

        if (opt == EOF)
            break;

        switch (opt) {
        case 's':
            if ((parsetime_error = rrd_parsetime(optarg, &start_tv))) {
                rrd_set_error("start time: %s", parsetime_error);
                return -1;
            }
            break;
        case 'e':
            if ((parsetime_error = rrd_parsetime(optarg, &end_tv))) {
                rrd_set_error("end time: %s", parsetime_error);
                return -1;
            }
            break;
        case 'r':
            step_tmp = atol(optarg);
            break;

        case 'd':
            if (opt_daemon != NULL)
                    free (opt_daemon);
            opt_daemon = strdup (optarg);
            if (opt_daemon == NULL)
            {
                rrd_set_error ("strdup failed.");
                return (-1);
            }
            break;

        case '?':
            rrd_set_error("unknown option '-%c'", optopt);
            return (-1);
        }
    }


    if (rrd_proc_start_end(&start_tv, &end_tv, &start_tmp, &end_tmp) == -1) {
        return -1;
    }


    if (start_tmp < 3600 * 24 * 365 * 10) {
        rrd_set_error("the first entry to fetch should be after 1980");
        return (-1);
    }

    if (end_tmp < start_tmp) {
        rrd_set_error("start (%ld) should be less than end (%ld)", start_tmp,
                      end_tmp);
        return (-1);
    }

    *start = start_tmp;
    *end = end_tmp;

    if (step_tmp < 1) {
        rrd_set_error("step must be >= 1 second");
        return -1;
    }
    *step = step_tmp;

    if (optind + 1 >= argc) {
        rrd_set_error("Usage: rrdtool %s <file> <CF> [options]", argv[0]);
        return -1;
    }

    status = rrdc_flush_if_daemon(opt_daemon, argv[optind]);
    if (opt_daemon) free (opt_daemon);
    if (status) return (-1);

    cf = argv[optind + 1];

    status = rrd_fetch_r(argv[optind], cf, start, end, step,
            ds_cnt, ds_namv, data);
    if (status != 0)
        return (-1);
    return (0);
}

int rrd_fetch_r(
    const char *filename,   /* name of the rrd */
    const char *cf,     /* which consolidation function ? */
    time_t *start,
    time_t *end,        /* which time frame do you want ?
                         * will be changed to represent reality */
    unsigned long *step,    /* which stepsize do you want? 
                             * will be changed to represent reality */
    unsigned long *ds_cnt,  /* number of data sources in file */
    char ***ds_namv,    /* names of data_sources */
    rrd_value_t **data)
{                       /* two dimensional array containing the data */
    enum cf_en cf_idx;

    if ((int) (cf_idx = cf_conv(cf)) == -1) {
        return -1;
    }

    return (rrd_fetch_fn
            (filename, cf_idx, start, end, step, ds_cnt, ds_namv, data));
} /* int rrd_fetch_r */

int rrd_fetch_fn(
    const char *filename,   /* name of the rrd */
    enum cf_en cf_idx,  /* which consolidation function ? */
    time_t *start,
    time_t *end,        /* which time frame do you want ?
                         * will be changed to represent reality */
    unsigned long *step,    /* which stepsize do you want? 
                             * will be changed to represent reality */
    unsigned long *ds_cnt,  /* number of data sources in file */
    char ***ds_namv,    /* names of data_sources */
    rrd_value_t **data)
{                       /* two dimensional array containing the data */
    long      i, ii;
    time_t    cal_start, cal_end, rra_start_time, rra_end_time;
    long      best_full_rra = 0, best_part_rra = 0, chosen_rra =
        0, rra_pointer = 0;
    long      best_full_step_diff = 0, best_part_step_diff =
        0, tmp_step_diff = 0, tmp_match = 0, best_match = 0;
    long      full_match, rra_base;
    off_t     start_offset, end_offset;
    int       first_full = 1;
    int       first_part = 1;
    rrd_t     rrd;
    rrd_file_t *rrd_file;
    rrd_value_t *data_ptr;
    unsigned long rows;

#ifdef DEBUG
    fprintf(stderr, "Entered rrd_fetch_fn() searching for the best match\n");
    fprintf(stderr, "Looking for: start %10lu end %10lu step %5lu\n",
            *start, *end, *step);
#endif

#ifdef HAVE_LIBDBI
    /* handle libdbi datasources */
    if (strncmp("sql//",filename,5)==0) {
	return rrd_fetch_fn_libdbi(filename,cf_idx,start,end,step,ds_cnt,ds_namv,data);
    }
#endif

    rrd_init(&rrd);
    rrd_file = rrd_open(filename, &rrd, RRD_READONLY);
    if (rrd_file == NULL)
        goto err_free;

    /* when was the really last update of this file ? */

    if (((*ds_namv) =
         (char **) malloc(rrd.stat_head->ds_cnt * sizeof(char *))) == NULL) {
        rrd_set_error("malloc fetch ds_namv array");
        goto err_close;
    }

    for (i = 0; (unsigned long) i < rrd.stat_head->ds_cnt; i++) {
        if ((((*ds_namv)[i]) = (char*)malloc(sizeof(char) * DS_NAM_SIZE)) == NULL) {
            rrd_set_error("malloc fetch ds_namv entry");
            goto err_free_ds_namv;
        }
        strncpy((*ds_namv)[i], rrd.ds_def[i].ds_nam, DS_NAM_SIZE - 1);
        (*ds_namv)[i][DS_NAM_SIZE - 1] = '\0';

    }

    /* find the rra which best matches the requirements */
    for (i = 0; (unsigned) i < rrd.stat_head->rra_cnt; i++) {
        if (cf_conv(rrd.rra_def[i].cf_nam) == cf_idx) {

            cal_end = (rrd.live_head->last_up - (rrd.live_head->last_up
                                                 % (rrd.rra_def[i].pdp_cnt
                                                    *
                                                    rrd.stat_head->
                                                    pdp_step)));
            cal_start =
                (cal_end -
                 (rrd.rra_def[i].pdp_cnt * rrd.rra_def[i].row_cnt *
                  rrd.stat_head->pdp_step));

            full_match = *end - *start;
#ifdef DEBUG
            fprintf(stderr, "Considering: start %10lu end %10lu step %5lu ",
                    cal_start, cal_end,
                    rrd.stat_head->pdp_step * rrd.rra_def[i].pdp_cnt);
#endif
            /* we need step difference in either full or partial case */
            tmp_step_diff = labs(*step - (rrd.stat_head->pdp_step
                                          * rrd.rra_def[i].pdp_cnt));
            /* best full match */
            if (cal_start <= *start) {
                if (first_full || (tmp_step_diff < best_full_step_diff)) {
                    first_full = 0;
                    best_full_step_diff = tmp_step_diff;
                    best_full_rra = i;
#ifdef DEBUG
                    fprintf(stderr, "best full match so far\n");
                } else {
                    fprintf(stderr, "full match, not best\n");
#endif
                }

            } else {
                /* best partial match */
                tmp_match = full_match;
                if (cal_start > *start)
                    tmp_match -= (cal_start - *start);
                if (first_part ||
                    (best_match < tmp_match) ||
                    (best_match == tmp_match &&
                     tmp_step_diff < best_part_step_diff)) {
#ifdef DEBUG
                    fprintf(stderr, "best partial so far\n");
#endif
                    first_part = 0;
                    best_match = tmp_match;
                    best_part_step_diff = tmp_step_diff;
                    best_part_rra = i;
                } else {
#ifdef DEBUG
                    fprintf(stderr, "partial match, not best\n");
#endif
                }
            }
        }
    }

    /* lets see how the matching went. */
    if (first_full == 0)
        chosen_rra = best_full_rra;
    else if (first_part == 0)
        chosen_rra = best_part_rra;
    else {
        rrd_set_error
            ("the RRD does not contain an RRA matching the chosen CF");
        goto err_free_all_ds_namv;
    }

    /* set the wish parameters to their real values */
    *step = rrd.stat_head->pdp_step * rrd.rra_def[chosen_rra].pdp_cnt;
    *start -= (*start % *step);
    *end += (*step - *end % *step);
    rows = (*end - *start) / *step + 1;

#ifdef DEBUG
    fprintf(stderr,
            "We found:    start %10lu end %10lu step %5lu rows  %lu\n",
            *start, *end, *step, rows);
#endif

/* Start and end are now multiples of the step size.  The amount of
** steps we want is (end-start)/step and *not* an extra one.
** Reasoning:  if step is s and we want to graph from t to t+s,
** we need exactly ((t+s)-t)/s rows.  The row to collect from the
** database is the one with time stamp (t+s) which means t to t+s.
*/
    *ds_cnt = rrd.stat_head->ds_cnt;
    if (((*data) = (rrd_value_t*)malloc(*ds_cnt * rows * sizeof(rrd_value_t))) == NULL) {
        rrd_set_error("malloc fetch data area");
        goto err_free_all_ds_namv;
    }

    data_ptr = (*data);

    /* find base address of rra */
    rra_base = rrd_file->header_len;
    for (i = 0; i < chosen_rra; i++)
        rra_base += (*ds_cnt * rrd.rra_def[i].row_cnt * sizeof(rrd_value_t));

    /* find start and end offset */
    rra_end_time = (rrd.live_head->last_up
                    - (rrd.live_head->last_up % *step));
    rra_start_time = (rra_end_time
                      - (*step * (rrd.rra_def[chosen_rra].row_cnt - 1)));
    /* here's an error by one if we don't be careful */
    start_offset = ((long long) *start + (long long)*step - (long long)rra_start_time) / (long long) *step;
    end_offset = ((long long) rra_end_time - (long long)*end) / (long long) *step;
#ifdef DEBUG
    fprintf(stderr,
            "rra_start %lu, rra_end %lu, start_off %li, end_off %li\n",
            rra_start_time, rra_end_time, start_offset, end_offset);
#endif
    /* only seek if the start time is before the end time */
    if (*start <= rra_end_time && *end >= rra_start_time - (off_t)*step ){
        if (start_offset <= 0)
            rra_pointer = rrd.rra_ptr[chosen_rra].cur_row + 1;
        else
            rra_pointer = rrd.rra_ptr[chosen_rra].cur_row + 1 + start_offset;

        rra_pointer = rra_pointer % (signed) rrd.rra_def[chosen_rra].row_cnt;
         
        if (rrd_seek(rrd_file, (rra_base + (rra_pointer * (*ds_cnt)
                                        * sizeof(rrd_value_t))),
                 SEEK_SET) != 0) {
            rrd_set_error("seek error in RRA");
            goto err_free_data;
        }
#ifdef DEBUG
        fprintf(stderr, "First Seek: rra_base %lu rra_pointer %lu\n",
                rra_base, rra_pointer);
#endif
    }
    
    /* step trough the array */

    for (i = start_offset;
         i < (signed) rrd.rra_def[chosen_rra].row_cnt - end_offset; i++) {
        /* no valid data yet */
        if (i < 0) {
#ifdef DEBUG
            fprintf(stderr, "pre fetch %li -- ", i);
#endif
            for (ii = 0; (unsigned) ii < *ds_cnt; ii++) {
                *(data_ptr++) = DNAN;
#ifdef DEBUG
                fprintf(stderr, "%10.2f ", *(data_ptr - 1));
#endif
            }
        }
        /* past the valid data area */
        else if (i >= (signed) rrd.rra_def[chosen_rra].row_cnt) {
#ifdef DEBUG
            fprintf(stderr, "past fetch %li -- ", i);
#endif
            for (ii = 0; (unsigned) ii < *ds_cnt; ii++) {
                *(data_ptr++) = DNAN;
#ifdef DEBUG
                fprintf(stderr, "%10.2f ", *(data_ptr - 1));
#endif
            }
        } else {
            /* OK we are inside the valid area but the pointer has to 
             * be wrapped*/
            if (rra_pointer >= (signed) rrd.rra_def[chosen_rra].row_cnt) {
                rra_pointer -= rrd.rra_def[chosen_rra].row_cnt;
                if (rrd_seek(rrd_file, (rra_base + rra_pointer * (*ds_cnt)
                                        * sizeof(rrd_value_t)),
                             SEEK_SET) != 0) {
                    rrd_set_error("wrap seek in RRA did fail");
                    goto err_free_data;
                }
#ifdef DEBUG
                fprintf(stderr, "wrap seek ...\n");
#endif
            }

            if (rrd_read(rrd_file, data_ptr, sizeof(rrd_value_t) * (*ds_cnt))
                != (ssize_t) (sizeof(rrd_value_t) * (*ds_cnt))) {
                rrd_set_error("fetching cdp from rra");
                goto err_free_data;
            }
#ifdef DEBUG
            fprintf(stderr, "post fetch %li -- ", i);
            for (ii = 0; ii < *ds_cnt; ii++)
                fprintf(stderr, "%10.2f ", *(data_ptr + ii));
#endif
            data_ptr += *ds_cnt;
            rra_pointer++;
        }
#ifdef DEBUG
        fprintf(stderr, "\n");
#endif

    }

    rrd_close(rrd_file);
    rrd_free(&rrd);
    return (0);
  err_free_data:
    free(*data);
    *data = NULL;
  err_free_all_ds_namv:
    for (i = 0; (unsigned long) i < rrd.stat_head->ds_cnt; ++i)
        free((*ds_namv)[i]);
  err_free_ds_namv:
    free(*ds_namv);
  err_close:
    rrd_close(rrd_file);
  err_free:
    rrd_free(&rrd);
    return (-1);
}
