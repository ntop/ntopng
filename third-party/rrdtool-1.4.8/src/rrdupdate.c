/*****************************************************************************
 * RRDtool 1.4.8  Copyright by Tobi Oetiker, 1997-2013
 *****************************************************************************
 * rrdupdate.c  Main program for the (standalone) rrdupdate utility
 *****************************************************************************
 * $Id$
 *****************************************************************************/

#if defined(_WIN32) && !defined(__CYGWIN__) && !defined(__CYGWIN32__) && !defined(HAVE_CONFIG_H)
#include "../win32/config.h"
#else
#ifdef HAVE_CONFIG_H
#include "../rrd_config.h"
#endif
#endif

#include "rrd.h"
#include "plbasename.h"

int main(
    int argc,
    char **argv)
{
    char *name=basename(argv[0]);
    rrd_info_t *info;

    if (!strcmp(name, "rrdcreate"))
        rrd_create(argc, argv);
    else if (!strcmp(name, "rrdinfo")) {
         info=rrd_info(argc, argv);
         rrd_info_print(info);
         rrd_info_free(info);
    }
    else
        rrd_update(argc, argv);

    if (rrd_test_error()) {
        printf("RRDtool " PACKAGE_VERSION
               "  Copyright by Tobi Oetiker, 1997-2010\n\n");
        if (!strcmp(name, "rrdcreate")) {
            printf("Usage: rrdcreate <filename>\n"
                   "\t\t\t[--start|-b start time]\n"
                   "\t\t\t[--step|-s step]\n"
                   "\t\t\t[--no-overwrite]\n"
                   "\t\t\t[DS:ds-name:DST:dst arguments]\n"
                   "\t\t\t[RRA:CF:cf arguments]\n\n");
	}
        else if (!strcmp(name, "rrdinfo")) {
            printf("Usage: rrdinfo <filename>\n");
        }
        else {
            printf("Usage: rrdupdate <filename>\n"
                   "\t\t\t[--template|-t ds-name[:ds-name]...]\n"
                   "\t\t\ttime|N:value[:value...]\n\n"
                   "\t\t\tat-time@value[:value...]\n\n"
                   "\t\t\t[ time:value[:value...] ..]\n\n");
        }

        printf("ERROR: %s\n", rrd_get_error());
        rrd_clear_error();
        return 1;
    }
    return 0;
}
