/*****************************************************************************
 * RRDtool 1.4.8  Copyright by Tobi Oetiker, 1997-2013
 *****************************************************************************
 * rrd_dump  Display a RRD
 *****************************************************************************
 * $Id$
 * $Log$
 * Revision 1.7  2004/05/25 20:53:21  oetiker
 * prevent small leak when resources are exhausted -- Mike Slifcak
 *
 * Revision 1.6  2004/05/25 20:51:49  oetiker
 * Update displayed copyright messages to be consistent. -- Mike Slifcak
 *
 * Revision 1.5  2003/02/13 07:05:27  oetiker
 * Find attached the patch I promised to send to you. Please note that there
 * are three new source files (src/rrd_is_thread_safe.h, src/rrd_thread_safe.c
 * and src/rrd_not_thread_safe.c) and the introduction of librrd_th. This
 * library is identical to librrd, but it contains support code for per-thread
 * global variables currently used for error information only. This is similar
 * to how errno per-thread variables are implemented.  librrd_th must be linked
 * alongside of libpthred
 *
 * There is also a new file "THREADS", holding some documentation.
 *
 * -- Peter Stamfest <peter@stamfest.at>
 *
 * Revision 1.4  2002/02/01 20:34:49  oetiker
 * fixed version number and date/time
 *
 * Revision 1.3  2001/03/10 23:54:39  oetiker
 * Support for COMPUTE data sources (CDEF data sources). Removes the RPN
 * parser and calculator from rrd_graph and puts then in a new file,
 * rrd_rpncalc.c. Changes to core files rrd_create and rrd_update. Some
 * clean-up of aberrant behavior stuff, including a bug fix.
 * Documentation update (rrdcreate.pod, rrdupdate.pod). Change xml format.
 * -- Jake Brutlag <jakeb@corp.webtv.net>
 *
 * Revision 1.2  2001/03/04 13:01:55  oetiker
 *
 * Revision 1.1.1.1  2001/02/25 22:25:05  oetiker
 * checkin
 *
 *****************************************************************************/
#include "rrd_tool.h"
#include "rrd_rpncalc.h"
#include "rrd_client.h"

#include <locale.h>

#if !(defined(NETWARE) || defined(WIN32))
extern char *tzname[2];
#endif

//Local prototypes
size_t rrd_dump_opt_cb_fileout(
    const void *data,
    size_t len,
    void *user);

int rrd_dump_opt_r(
    const char *filename,
    char *outname,
    int opt_noheader);

int rrd_dump_cb_r(
    const char *filename,
    int opt_header,
    rrd_output_callback_t cb,
    void *user)
{
    unsigned int i, ii, ix, iii = 0;
    time_t    now;
    char      somestring[255];
    rrd_value_t my_cdp;
    off_t     rra_base, rra_start, rra_next;
    rrd_file_t *rrd_file;
    rrd_t     rrd;
    rrd_value_t value;
    struct tm tm;
    char *old_locale = "";

//These two macros are local defines to clean up visible code from its redndancy
//and make it easier to read.
#define CB_PUTS(str)                                            \
    cb((str), strlen((str)), user)
#define CB_FMTS(...) do {                                       \
    char buffer[256];                                           \
    snprintf (buffer, sizeof(buffer), __VA_ARGS__);             \
    CB_PUTS (buffer);                                           \
    } while (0)
//These macros are to be undefined at the end of this function

    //Check if we got a (valid) callback method
    if (!cb) {
        return (-1);
    }

    rrd_init(&rrd);

    rrd_file = rrd_open(filename, &rrd, RRD_READONLY | RRD_READAHEAD);
    if (rrd_file == NULL) {
        rrd_free(&rrd);
        return (-1);
    }

    old_locale = setlocale(LC_NUMERIC, NULL);
    setlocale(LC_NUMERIC, "C");


    if (opt_header == 1) {
        CB_PUTS("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n");
        CB_PUTS("<!DOCTYPE rrd SYSTEM \"http://oss.oetiker.ch/rrdtool/rrdtool.dtd\">\n");
        CB_PUTS("<!-- Round Robin Database Dump -->\n");
        CB_PUTS("<rrd>\n");
    } else if (opt_header == 2) {
        CB_PUTS("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n");
        CB_PUTS("<!-- Round Robin Database Dump -->\n");
        CB_PUTS("<rrd xmlns=\"http://oss.oetiker.ch/rrdtool/rrdtool-dump.xml\" "
                "xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\n");
        CB_PUTS("\txsi:schemaLocation=\"http://oss.oetiker.ch/rrdtool/rrdtool-dump.xml "
                "http://oss.oetiker.ch/rrdtool/rrdtool-dump.xsd\">\n");
    } else {
        CB_PUTS("<!-- Round Robin Database Dump -->\n");
        CB_PUTS("<rrd>\n");
    }

    if (atoi(rrd.stat_head->version) <= 3) {
        CB_FMTS("\t<version>%s</version>\n", RRD_VERSION3);
    } else {
        CB_FMTS("\t<version>%s</version>\n", RRD_VERSION);
    }
    
    CB_FMTS("\t<step>%lu</step> <!-- Seconds -->\n",
        rrd.stat_head->pdp_step);

#ifdef HAVE_STRFTIME
    localtime_r(&rrd.live_head->last_up, &tm);
    strftime(somestring, 255, "%Y-%m-%d %H:%M:%S %Z", &tm);
#else
# error "Need strftime"
#endif
    CB_FMTS("\t<lastupdate>%lld</lastupdate> <!-- %s -->\n\n",
        (long long) rrd.live_head->last_up, somestring);
    for (i = 0; i < rrd.stat_head->ds_cnt; i++) {
        CB_PUTS("\t<ds>\n");

        CB_FMTS("\t\t<name> %s </name>\n", rrd.ds_def[i].ds_nam);

        CB_FMTS("\t\t<type> %s </type>\n", rrd.ds_def[i].dst);

        if (dst_conv(rrd.ds_def[i].dst) != DST_CDEF) {
            CB_FMTS("\t\t<minimal_heartbeat>%lu</minimal_heartbeat>\n",
                    rrd.ds_def[i].par[DS_mrhb_cnt].u_cnt);

            if (isnan(rrd.ds_def[i].par[DS_min_val].u_val)) {
                CB_PUTS("\t\t<min>NaN</min>\n");
            } else {
                CB_FMTS("\t\t<min>%0.10e</min>\n",
                    rrd.ds_def[i].par[DS_min_val].u_val);
            }
            
            if (isnan(rrd.ds_def[i].par[DS_max_val].u_val)) {
                CB_PUTS("\t\t<max>NaN</max>\n");
            } else {
                CB_FMTS("\t\t<max>%0.10e</max>\n",
                    rrd.ds_def[i].par[DS_max_val].u_val);
            }
        } else {        /* DST_CDEF */
            char     *str = NULL;

            rpn_compact2str((rpn_cdefds_t *) &(rrd.ds_def[i].par[DS_cdef]),
                rrd.ds_def, &str);

            //Splitting into 3 writes to avoid allocating memory
            //This is better compared to snprintf as str may be of arbitrary size
            CB_PUTS("\t\t<cdef> ");
            CB_PUTS(str);
            CB_PUTS(" </cdef>\n");

            free(str);
        }

        CB_PUTS("\n\t\t<!-- PDP Status -->\n");
        CB_FMTS("\t\t<last_ds>%s</last_ds>\n",
            rrd.pdp_prep[i].last_ds);

        if (isnan(rrd.pdp_prep[i].scratch[PDP_val].u_val)) {
            CB_PUTS("\t\t<value>NaN</value>\n");
        } else {
            CB_FMTS("\t\t<value>%0.10e</value>\n",
                rrd.pdp_prep[i].scratch[PDP_val].u_val);
        }

        CB_FMTS("\t\t<unknown_sec> %lu </unknown_sec>\n",
            rrd.pdp_prep[i].scratch[PDP_unkn_sec_cnt].u_cnt);

        CB_PUTS("\t</ds>\n\n");
    }

    CB_PUTS("\t<!-- Round Robin Archives -->\n");

    rra_base = rrd_file->header_len;
    rra_next = rra_base;

    for (i = 0; i < rrd.stat_head->rra_cnt; i++) {

        long      timer = 0;

        rra_start = rra_next;
        rra_next += (rrd.stat_head->ds_cnt
                     * rrd.rra_def[i].row_cnt * sizeof(rrd_value_t));

        CB_PUTS("\t<rra>\n");

        CB_FMTS("\t\t<cf>%s</cf>\n", rrd.rra_def[i].cf_nam);

        CB_FMTS("\t\t<pdp_per_row>%lu</pdp_per_row> <!-- %lu seconds -->\n\n",
            rrd.rra_def[i].pdp_cnt, 
            rrd.rra_def[i].pdp_cnt * rrd.stat_head->pdp_step);

        /* support for RRA parameters */
        CB_PUTS("\t\t<params>\n");

        switch (cf_conv(rrd.rra_def[i].cf_nam)) {
        case CF_HWPREDICT:
        case CF_MHWPREDICT:
            CB_FMTS("\t\t<hw_alpha>%0.10e</hw_alpha>\n",
                rrd.rra_def[i].par[RRA_hw_alpha].u_val);

            CB_FMTS("\t\t<hw_beta>%0.10e</hw_beta>\n",
                rrd.rra_def[i].par[RRA_hw_beta].u_val);

            CB_FMTS("\t\t<dependent_rra_idx>%lu</dependent_rra_idx>\n",
                rrd.rra_def[i].par[RRA_dependent_rra_idx].u_cnt);
            break;
        case CF_SEASONAL:
        case CF_DEVSEASONAL:
            CB_FMTS("\t\t<seasonal_gamma>%0.10e</seasonal_gamma>\n",
                rrd.rra_def[i].par[RRA_seasonal_gamma].u_val);

            CB_FMTS("\t\t<seasonal_smooth_idx>%lu</seasonal_smooth_idx>\n",
                rrd.rra_def[i].par[RRA_seasonal_smooth_idx].u_cnt);

            if (atoi(rrd.stat_head->version) >= 4) {
                CB_FMTS("\t\t<smoothing_window>%0.10e</smoothing_window>\n",
                    rrd.rra_def[i].par[RRA_seasonal_smoothing_window].u_val);
            }

            CB_FMTS("\t\t<dependent_rra_idx>%lu</dependent_rra_idx>\n",
                rrd.rra_def[i].par[RRA_dependent_rra_idx].u_cnt);
            break;
        case CF_FAILURES:
            CB_FMTS("\t\t<delta_pos>%0.10e</delta_pos>\n",
                rrd.rra_def[i].par[RRA_delta_pos].u_val);

            CB_FMTS("\t\t<delta_neg>%0.10e</delta_neg>\n",
                rrd.rra_def[i].par[RRA_delta_neg].u_val);

            CB_FMTS("\t\t<window_len>%lu</window_len>\n",
                rrd.rra_def[i].par[RRA_window_len].u_cnt);

            CB_FMTS("\t\t<failure_threshold>%lu</failure_threshold>\n",
                rrd.rra_def[i].par[RRA_failure_threshold].u_cnt);

            /* fall thru */
        case CF_DEVPREDICT:
            CB_FMTS("\t\t<dependent_rra_idx>%lu</dependent_rra_idx>\n",
                rrd.rra_def[i].par[RRA_dependent_rra_idx].u_cnt);
            break;
        case CF_AVERAGE:
        case CF_MAXIMUM:
        case CF_MINIMUM:
        case CF_LAST:
        default:
            CB_FMTS("\t\t<xff>%0.10e</xff>\n",
                rrd.rra_def[i].par[RRA_cdp_xff_val].u_val);
            break;
        }

        CB_PUTS("\t\t</params>\n");
        CB_PUTS("\t\t<cdp_prep>\n");

        for (ii = 0; ii < rrd.stat_head->ds_cnt; ii++) {
            unsigned long ivalue;

            CB_PUTS("\t\t\t<ds>\n");
            /* support for exporting all CDP parameters */
            /* parameters common to all CFs */
            /* primary_val and secondary_val do not need to be saved between updates
             * so strictly speaking they could be omitted.
             * However, they can be useful for diagnostic purposes, so are included here. */
            value = rrd.cdp_prep[i * rrd.stat_head->ds_cnt + ii].
                scratch[CDP_primary_val].u_val;
            if (isnan(value)) {
                CB_PUTS("\t\t\t<primary_value>NaN</primary_value>\n");
            } else {
                CB_FMTS("\t\t\t<primary_value>%0.10e</primary_value>\n", value);
            }

            value = rrd.cdp_prep[i * rrd.stat_head->ds_cnt + ii].
                scratch[CDP_secondary_val].u_val;
            if (isnan(value)) {
                CB_PUTS("\t\t\t<secondary_value>NaN</secondary_value>\n");
            } else {
                CB_FMTS("\t\t\t<secondary_value>%0.10e</secondary_value>\n", value);
            }

            switch (cf_conv(rrd.rra_def[i].cf_nam)) {
            case CF_HWPREDICT:
            case CF_MHWPREDICT:
                value = rrd.cdp_prep[i * rrd.stat_head->ds_cnt + ii].
                    scratch[CDP_hw_intercept].u_val;
                if (isnan(value)) {
                    CB_PUTS("\t\t\t<intercept>NaN</intercept>\n");
                } else {
                    CB_FMTS("\t\t\t<intercept>%0.10e</intercept>\n", value);
                }

                value = rrd.cdp_prep[i * rrd.stat_head->ds_cnt + ii].
                    scratch[CDP_hw_last_intercept].u_val;
                if (isnan(value)) {
                    CB_PUTS("\t\t\t<last_intercept>NaN</last_intercept>\n");
                } else {
                    CB_FMTS("\t\t\t<last_intercept>%0.10e</last_intercept>\n", value);
                }

                value = rrd.cdp_prep[i * rrd.stat_head->ds_cnt + ii].
                    scratch[CDP_hw_slope].u_val;
                if (isnan(value)) {
                    CB_PUTS("\t\t\t<slope>NaN</slope>\n");
                } else {
                    CB_FMTS("\t\t\t<slope>%0.10e</slope>\n", value);
                }

                value = rrd.cdp_prep[i * rrd.stat_head->ds_cnt + ii].
                    scratch[CDP_hw_last_slope].u_val;
                if (isnan(value)) {
                    CB_PUTS("\t\t\t<last_slope>NaN</last_slope>\n");
                } else {
                    CB_FMTS("\t\t\t<last_slope>%0.10e</last_slope>\n", value);
                }

                ivalue = rrd.cdp_prep[i * rrd.stat_head->ds_cnt + ii].
                    scratch[CDP_null_count].u_cnt;
                CB_FMTS("\t\t\t<nan_count>%lu</nan_count>\n", ivalue);

                ivalue = rrd.cdp_prep[i * rrd.stat_head->ds_cnt + ii].
                    scratch[CDP_last_null_count].u_cnt;
                CB_FMTS("\t\t\t<last_nan_count>%lu</last_nan_count>\n", ivalue);
                break;
            case CF_SEASONAL:
            case CF_DEVSEASONAL:
                value = rrd.cdp_prep[i * rrd.stat_head->ds_cnt + ii].
                    scratch[CDP_hw_seasonal].u_val;
                if (isnan(value)) {
                    CB_PUTS("\t\t\t<seasonal>NaN</seasonal>\n");
                } else {
                    CB_FMTS("\t\t\t<seasonal>%0.10e</seasonal>\n", value);
                }

                value = rrd.cdp_prep[i * rrd.stat_head->ds_cnt + ii].
                    scratch[CDP_hw_last_seasonal].u_val;
                if (isnan(value)) {
                    CB_PUTS("\t\t\t<last_seasonal>NaN</last_seasonal>\n");
                } else {
                    CB_FMTS("\t\t\t<last_seasonal>%0.10e</last_seasonal>\n", value);
                }

                ivalue = rrd.cdp_prep[i * rrd.stat_head->ds_cnt + ii].
                    scratch[CDP_init_seasonal].u_cnt;
                CB_FMTS("\t\t\t<init_flag>%lu</init_flag>\n", ivalue);
                break;
            case CF_DEVPREDICT:
                break;
            case CF_FAILURES:
            {
                unsigned short vidx;
                char *violations_array = (char *) ((void *)
                    rrd.cdp_prep[i * rrd.stat_head->ds_cnt + ii].scratch);
                CB_PUTS("\t\t\t<history>");
                for (vidx = 0;
                    vidx < rrd.rra_def[i].par[RRA_window_len].u_cnt;
                    ++vidx) {
                    CB_FMTS("%d", violations_array[vidx]);
                }
                CB_PUTS("</history>\n");
            }
                break;
            case CF_AVERAGE:
            case CF_MAXIMUM:
            case CF_MINIMUM:
            case CF_LAST:
            default:
                value = rrd.cdp_prep[i * rrd.stat_head->ds_cnt + ii].scratch[CDP_val].u_val;
                if (isnan(value)) {
                    CB_PUTS("\t\t\t<value>NaN</value>\n");
                } else {
                    CB_FMTS("\t\t\t<value>%0.10e</value>\n", value);
                }

                CB_FMTS("\t\t\t<unknown_datapoints>%lu</unknown_datapoints>\n",
                    rrd.cdp_prep[i * rrd.stat_head->ds_cnt + ii].
                        scratch[CDP_unkn_pdp_cnt].u_cnt);
                break;
            }
            CB_PUTS("\t\t\t</ds>\n");
        }
        CB_PUTS("\t\t</cdp_prep>\n");

        CB_PUTS("\t\t<database>\n");
        rrd_seek(rrd_file, (rra_start + (rrd.rra_ptr[i].cur_row + 1)
                            * rrd.stat_head->ds_cnt
                            * sizeof(rrd_value_t)), SEEK_SET);
        timer = -(long)(rrd.rra_def[i].row_cnt - 1);
        ii = rrd.rra_ptr[i].cur_row;
        for (ix = 0; ix < rrd.rra_def[i].row_cnt; ix++) {
            ii++;
            if (ii >= rrd.rra_def[i].row_cnt) {
                rrd_seek(rrd_file, rra_start, SEEK_SET);
                ii = 0; /* wrap if max row cnt is reached */
            }
            now = (rrd.live_head->last_up
                   - rrd.live_head->last_up
                   % (rrd.rra_def[i].pdp_cnt * rrd.stat_head->pdp_step))
                + (timer * rrd.rra_def[i].pdp_cnt * rrd.stat_head->pdp_step);

            timer++;
#if HAVE_STRFTIME
            localtime_r(&now, &tm);
            strftime(somestring, 255, "%Y-%m-%d %H:%M:%S %Z", &tm);
#else
# error "Need strftime"
#endif
            CB_FMTS("\t\t\t<!-- %s / %lld --> <row>",  somestring, (long long) now);
            for (iii = 0; iii < rrd.stat_head->ds_cnt; iii++) {
                rrd_read(rrd_file, &my_cdp, sizeof(rrd_value_t) * 1);
                if (isnan(my_cdp)) {
                    CB_PUTS("<v>NaN</v>");
                } else {
                    CB_FMTS("<v>%0.10e</v>", my_cdp);
                }
            }
            CB_PUTS("</row>\n");
        }
        CB_PUTS("\t\t</database>\n\t</rra>\n");
    }

    CB_PUTS("</rrd>\n");

    rrd_free(&rrd);

    setlocale(LC_NUMERIC, old_locale);

    return rrd_close(rrd_file);

//Undefining the previously defined shortcuts
//See start of this function
#undef CB_PUTS
#undef CB_FMTS
//End of macro undefining

}

size_t rrd_dump_opt_cb_fileout(
    const void *data,
    size_t len,
    void *user)
{
    return fwrite(data, 1, len, (FILE *)user);
}

int rrd_dump_opt_r(
    const char *filename,
    char *outname,
    int opt_noheader)
{
    FILE     *out_file;
    int       res;

    out_file = NULL;
    if (outname) {
        if (!(out_file = fopen(outname, "w"))) {
            return (-1);
        }
    } else {
        out_file = stdout;
    }

    res = rrd_dump_cb_r(filename, opt_noheader, rrd_dump_opt_cb_fileout, (void *)out_file);

    if (out_file != stdout) {
        fclose(out_file);
    }

    return res;
}

/* backward compatibility with 1.2.x */
int rrd_dump_r(
    const char *filename,
    char *outname)
{
    return rrd_dump_opt_r(filename, outname, 0);
}

int rrd_dump(
    int argc,
    char **argv)
{
    int       rc;
    /** 
     * 0 = no header
     * 1 = dtd header
     * 2 = xsd header
     */
    int       opt_header = 1;
    char     *opt_daemon = NULL;

    /* init rrd clean */

    optind = 0;
    opterr = 0;         /* initialize getopt */

    while (42) {/* ha ha */
        int       opt;
        int       option_index = 0;
        static struct option long_options[] = {
            {"daemon", required_argument, 0, 'd'},
            {"header", required_argument, 0, 'h'},
            {"no-header", no_argument, 0, 'n'},
            {0, 0, 0, 0}
        };

        opt = getopt_long(argc, argv, "d:h:n", long_options, &option_index);

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

        case 'n':
           opt_header = 0;
           break;

        case 'h':
	   if (strcmp(optarg, "dtd") == 0) {
	   	opt_header = 1;
	   } else if (strcmp(optarg, "xsd") == 0) {
	   	opt_header = 2;
	   } else if (strcmp(optarg, "none") == 0) {
	   	opt_header = 0;
	   }
	   break;

        default:
            rrd_set_error("usage rrdtool %s [--header|-h {none,xsd,dtd}] [--no-header]"
                          "file.rrd [file.xml]", argv[0]);
            return (-1);
            break;
        }
    }                   /* while (42) */

    if ((argc - optind) < 1 || (argc - optind) > 2) {
        rrd_set_error("usage rrdtool %s [--header|-h {none,xsd,dtd}] [--no-header]"
                      "file.rrd [file.xml]", argv[0]);
        return (-1);
    }

    rc = rrdc_flush_if_daemon(opt_daemon, argv[optind]);
    if (opt_daemon) free(opt_daemon);
    if (rc) return (rc);

    if ((argc - optind) == 2) {
        rc = rrd_dump_opt_r(argv[optind], argv[optind + 1], opt_header);
    } else {
        rc = rrd_dump_opt_r(argv[optind], NULL, opt_header);
    }

    return rc;
}
