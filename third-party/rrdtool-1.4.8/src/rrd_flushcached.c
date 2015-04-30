/**
 * RRDTool - src/rrd_flushcached.c
 * Copyright (C) 2008 Florian octo Forster
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; only version 2 of the License is applicable.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
 *
 * Authors:
 *   Florian octo Forster <octo at verplant.org>
 **/

#include "rrd_tool.h"
#include "rrd_client.h"

int rrd_flushcached (int argc, char **argv)
{
    char *opt_daemon = NULL;
    int status;
    int i;

    /* initialize getopt */
    optind = 0;
    opterr = 0;

    while (42)
    {
        int opt;
        static struct option long_options[] =
        {
            {"daemon", required_argument, 0, 'd'},
            {0, 0, 0, 0}
        };

        opt = getopt_long(argc, argv, "d:", long_options, NULL);

        if (opt == -1)
            break;

        switch (opt)
        {
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
        }
    } /* while (42) */

    if ((argc - optind) < 1)
    {
        rrd_set_error ("Usage: rrdtool %s [--daemon <addr>] <file> [<file> ...]", argv[0]);
        return (-1);
    }

    /* try to connect to rrdcached */
    status = rrdc_connect(opt_daemon);
    if (status != 0) goto out;

    if (! rrdc_is_connected(opt_daemon))
    {
        rrd_set_error ("Daemon address unknown. Please use the \"--daemon\" "
                "option to set an address on the command line or set the "
                "\"%s\" environment variable.",
                ENV_RRDCACHED_ADDRESS);
        status = -1;
        goto out;
    }

    status = 0;
    for (i = optind; i < argc; i++)
    {
        status = rrdc_flush(argv[i]);
        if (status)
        {
            char *error;
            int   remaining;

            error     = strdup(rrd_get_error());
            remaining = argc - optind - 1;

            rrd_set_error("Flushing of file \"%s\" failed: %s. Skipping "
                    "remaining %i file%s.", argv[i],
                    ((! error) || (*error == '\0')) ? "unknown error" : error,
                    remaining, (remaining == 1) ? "" : "s");
            free(error);
            break;
        }
    }

out:
    if (opt_daemon) free(opt_daemon);

    return status;
} /* int rrd_flush */

/*
 * vim: set sw=4 sts=4 et fdm=marker :
 */
