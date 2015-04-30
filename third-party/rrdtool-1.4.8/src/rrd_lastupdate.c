/*****************************************************************************
 * RRDtool 1.4.8  Copyright by Tobi Oetiker, 1997-2013
 *                Copyright by Florian Forster, 2008
 *****************************************************************************
 * rrd_lastupdate  Get the last datum entered for each DS
 *****************************************************************************/

#include "rrd_tool.h"
#include "rrd_rpncalc.h"
#include "rrd_client.h"
#include <stdarg.h>

int rrd_lastupdate (int argc, char **argv)
{
    time_t    last_update;
    char    **ds_names;
    char    **last_ds;
    unsigned long ds_count, i;
    int status;

    char *opt_daemon = NULL;

    optind = 0;
    opterr = 0;         /* initialize getopt */

    while (42) {
        int       opt;
        int       option_index = 0;
        static struct option long_options[] = {
            {"daemon", required_argument, 0, 'd'},
            {0, 0, 0, 0}
        };

        opt = getopt_long (argc, argv, "d:", long_options, &option_index);

        if (opt == EOF)
            break;

        switch (opt) {
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

        default:
            rrd_set_error ("Usage: rrdtool %s [--daemon <addr>] <file>",
                    argv[0]);
            return (-1);
            break;
        }
    }                   /* while (42) */

    if ((argc - optind) != 1) {
        rrd_set_error ("Usage: rrdtool %s [--daemon <addr>] <file>",
                argv[0]);
        return (-1);
    }

    status = rrdc_flush_if_daemon(opt_daemon, argv[optind]);
    if (opt_daemon) free (opt_daemon);
    if (status) return (-1);

    status = rrd_lastupdate_r (argv[optind],
            &last_update, &ds_count, &ds_names, &last_ds);
    if (status != 0)
        return (status);

    for (i = 0; i < ds_count; i++)
        printf(" %s", ds_names[i]);
    printf ("\n\n");

    printf ("%10lu:", last_update);
    for (i = 0; i < ds_count; i++) {
        printf(" %s", last_ds[i]);
        free(last_ds[i]);
        free(ds_names[i]);
    }
    printf("\n");

    free(last_ds);
    free(ds_names);

    return (0);
} /* int rrd_lastupdate */

int rrd_lastupdate_r(const char *filename,
        time_t *ret_last_update,
        unsigned long *ret_ds_count,
        char ***ret_ds_names,
        char ***ret_last_ds)
{
    unsigned long i = 0;
    rrd_t     rrd;
    rrd_file_t *rrd_file;

    rrd_init(&rrd);
    rrd_file = rrd_open(filename, &rrd, RRD_READONLY);
    if (rrd_file == NULL) {
        rrd_free(&rrd);
        return (-1);
    }

    *ret_last_update = rrd.live_head->last_up;
    *ret_ds_count = rrd.stat_head->ds_cnt;
    *ret_ds_names = (char **) malloc (rrd.stat_head->ds_cnt * sizeof(char *));
    if (*ret_ds_names == NULL) {
        rrd_set_error ("malloc fetch ret_ds_names array");
        rrd_close (rrd_file);
        rrd_free (&rrd);
        return (-1);
    }
    memset (*ret_ds_names, 0, rrd.stat_head->ds_cnt * sizeof(char *));

    *ret_last_ds = (char **) malloc (rrd.stat_head->ds_cnt * sizeof(char *));
    if (*ret_last_ds == NULL) {
        rrd_set_error ("malloc fetch ret_last_ds array");
        free (*ret_ds_names);
        *ret_ds_names = NULL;
        rrd_close (rrd_file);
        rrd_free (&rrd);
        return (-1);
    }
    memset (*ret_last_ds, 0, rrd.stat_head->ds_cnt * sizeof(char *));

    for (i = 0; i < rrd.stat_head->ds_cnt; i++) {
        (*ret_ds_names)[i] = sprintf_alloc("%s", rrd.ds_def[i].ds_nam);
        (*ret_last_ds)[i] = sprintf_alloc("%s", rrd.pdp_prep[i].last_ds);

        if (((*ret_ds_names)[i] == NULL) || ((*ret_last_ds)[i] == NULL))
            break;
    }

    /* Check if all names and values could be copied and free everything if
     * not. */
    if (i < rrd.stat_head->ds_cnt) {
        rrd_set_error ("sprintf_alloc failed");
        for (i = 0; i < rrd.stat_head->ds_cnt; i++) {
            if ((*ret_ds_names)[i] != NULL)
            {
                free ((*ret_ds_names)[i]);
                (*ret_ds_names)[i] = NULL;
            }
            if ((*ret_last_ds)[i] != NULL)
            {
                free ((*ret_last_ds)[i]);
                (*ret_last_ds)[i] = NULL;
            }
        }
        free (*ret_ds_names);
        *ret_ds_names = NULL;
        free (*ret_last_ds);
        *ret_last_ds = NULL;
        rrd_close (rrd_file);
        rrd_free (&rrd);
        return (-1);
    }

    rrd_free(&rrd);
    rrd_close(rrd_file);
    return (0);
} /* int rrd_lastupdate_r */
