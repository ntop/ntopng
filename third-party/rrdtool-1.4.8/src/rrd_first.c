/*****************************************************************************
 * RRDtool 1.4.8  Copyright by Tobi Oetiker, 1997-2013
 *****************************************************************************
 * rrd_first Return
 *****************************************************************************
 * Initial version by Burton Strauss, ntopSupport.com - 3/2005
 *****************************************************************************/

#include <stdlib.h>
#include "rrd_tool.h"


time_t rrd_first(
    int argc,
    char **argv)
{
    int       target_rraindex = 0;
    char     *endptr;
    struct option long_options[] = {
        {"rraindex", required_argument, 0, 129},
        {0, 0, 0, 0}
    };

    optind = 0;
    opterr = 0;         /* initialize getopt */

    while (1) {
        int       option_index = 0;
        int       opt;

        opt = getopt_long(argc, argv, "", long_options, &option_index);

        if (opt == EOF)
            break;

        switch (opt) {
        case 129:
            target_rraindex = strtol(optarg, &endptr, 0);
            if (target_rraindex < 0) {
                rrd_set_error("invalid rraindex number");
                return (-1);
            }
            break;
        default:
            rrd_set_error("usage rrdtool %s [--rraindex number] file.rrd",
                          argv[0]);
            return (-1);
        }
    }

    if (optind >= argc) {
        rrd_set_error("not enough arguments");
        return -1;
    }

    return (rrd_first_r(argv[optind], target_rraindex));
}


time_t rrd_first_r(
    const char *filename,
    const int rraindex)
{
    off_t     rra_start, timer;
    time_t    then = -1;
    rrd_t     rrd;
    rrd_file_t *rrd_file;

    rrd_init(&rrd);
    rrd_file = rrd_open(filename, &rrd, RRD_READONLY);
    if (rrd_file == NULL) {
        goto err_free;
    }

    if ((rraindex < 0) || (rraindex >= (int) rrd.stat_head->rra_cnt)) {
        rrd_set_error("invalid rraindex number");
        goto err_close;
    }

    rra_start = rrd_file->header_len;
    rrd_seek(rrd_file,
             (rra_start +
              (rrd.rra_ptr[rraindex].cur_row + 1) *
              rrd.stat_head->ds_cnt * sizeof(rrd_value_t)), SEEK_SET);
    timer = -(long)(rrd.rra_def[rraindex].row_cnt - 1);
    if (rrd.rra_ptr[rraindex].cur_row + 1 > rrd.rra_def[rraindex].row_cnt) {
        rrd_seek(rrd_file, rra_start, SEEK_SET);
    }
    then = (rrd.live_head->last_up -
            rrd.live_head->last_up %
            (rrd.rra_def[rraindex].pdp_cnt * rrd.stat_head->pdp_step)) +
        (timer * rrd.rra_def[rraindex].pdp_cnt * rrd.stat_head->pdp_step);
  err_close:
    rrd_close(rrd_file);
  err_free:
    rrd_free(&rrd);
    return (then);
}
