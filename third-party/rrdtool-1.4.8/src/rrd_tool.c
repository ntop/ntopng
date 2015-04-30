/*****************************************************************************
 * RRDtool 1.4.8  Copyright by Tobi Oetiker, 1997-2013
 *****************************************************************************
 * rrd_tool.c  Startup wrapper
 *****************************************************************************/

#if defined(WIN32) && !defined(__CYGWIN__) && !defined(__CYGWIN32__) && !defined(HAVE_CONFIG_H)
#include "../win32/config.h"
#include <stdlib.h>
#include <sys/stat.h>
#include <io.h>
#include <fcntl.h>
#else
#ifdef HAVE_CONFIG_H
#include "../rrd_config.h"
#endif
#endif

#include "rrd_tool.h"
#include "rrd_xport.h"
#include "rrd_i18n.h"

#include <locale.h>


void      PrintUsage(
    char *cmd);
int       CountArgs(
    char *aLine);
int       CreateArgs(
    char *,
    char *,
    char **);
int       HandleInputLine(
    int,
    char **,
    FILE *);
int       RemoteMode = 0;
int       ChangeRoot = 0;

#define TRUE		1
#define FALSE		0
#define MAX_LENGTH	10000


void PrintUsage(
    char *cmd)
{

    const char *help_main =
        N_("RRDtool %s"
           "  Copyright 1997-2013 by Tobias Oetiker <tobi@oetiker.ch>\n"
           "               Compiled %s %s\n\n"
           "Usage: rrdtool [options] command command_options\n");

    const char *help_list =
        N_
        ("Valid commands: create, update, updatev, graph, graphv,  dump, restore,\n"
         "\t\tlast, lastupdate, first, info, fetch, tune,\n"
         "\t\tresize, xport, flushcached\n");

    const char *help_listremote =
        N_("Valid remote commands: quit, ls, cd, mkdir, pwd\n");


    const char *help_create =
        N_("* create - create a new RRD\n\n"
           "\trrdtool create filename [--start|-b start time]\n"
           "\t\t[--step|-s step]\n"
           "\t\t[--no-overwrite|-O]\n"
           "\t\t[DS:ds-name:DST:dst arguments]\n"
           "\t\t[RRA:CF:cf arguments]\n");

    const char *help_dump =
        N_("* dump - dump an RRD to XML\n\n"
           "\trrdtool dump filename.rrd >filename.xml\n");

    const char *help_info =
        N_("* info - returns the configuration and status of the RRD\n\n"
           "\trrdtool info filename.rrd\n");

    const char *help_restore =
        N_("* restore - restore an RRD file from its XML form\n\n"
           "\trrdtool restore [--range-check|-r] [--force-overwrite|-f] filename.xml filename.rrd\n");

    const char *help_last =
        N_("* last - show last update time for RRD\n\n"
           "\trrdtool last filename.rrd\n");

    const char *help_lastupdate =
        N_("* lastupdate - returns the most recent datum stored for\n"
           "  each DS in an RRD\n\n" "\trrdtool lastupdate filename.rrd\n");

    const char *help_first =
        N_("* first - show first update time for RRA within an RRD\n\n"
           "\trrdtool first filename.rrd [--rraindex number]\n");

    const char *help_update =
        N_("* update - update an RRD\n\n"
           "\trrdtool update filename\n"
           "\t\t[--template|-t ds-name:ds-name:...]\n"
	   "\t\t[--daemon <address>]\n"
           "\t\ttime|N:value[:value...]\n\n"
           "\t\tat-time@value[:value...]\n\n"
           "\t\t[ time:value[:value...] ..]\n");

    const char *help_updatev =
        N_("* updatev - a verbose version of update\n"
           "\treturns information about values, RRAs, and datasources updated\n\n"
           "\trrdtool updatev filename\n"
           "\t\t[--template|-t ds-name:ds-name:...]\n"
           "\t\ttime|N:value[:value...]\n\n"
           "\t\tat-time@value[:value...]\n\n"
           "\t\t[ time:value[:value...] ..]\n");

    const char *help_fetch =
        N_("* fetch - fetch data out of an RRD\n\n"
           "\trrdtool fetch filename.rrd CF\n"
           "\t\t[-r|--resolution resolution]\n"
           "\t\t[-s|--start start] [-e|--end end]\n"
	   "\t\t[--daemon <address>]\n");

    const char *help_flushcached =
        N_("* flushcached - flush cached data out to an RRD file\n\n"
           "\trrdtool flushcached filename.rrd\n"
	   "\t\t[--daemon <address>]\n");

/* break up very large strings (help_graph, help_tune) for ISO C89 compliance*/

    const char *help_graph0 =
        N_("* graph - generate a graph from one or several RRD\n\n"
           "\trrdtool graph filename [-s|--start seconds] [-e|--end seconds]\n");
    const char *help_graphv0 =
        N_("* graphv - generate a graph from one or several RRD\n"
           "           with meta data printed before the graph\n\n"
           "\trrdtool graphv filename [-s|--start seconds] [-e|--end seconds]\n");
    const char *help_graph1 =
        N_("\t\t[-x|--x-grid x-axis grid and label]\n"
           "\t\t[-Y|--alt-y-grid] [--full-size-mode]\n"
           "\t\t[-y|--y-grid y-axis grid and label]\n"
           "\t\t[-v|--vertical-label string] [-w|--width pixels]\n"
           "\t\t[--right-axis scale:shift] [--right-axis-label label]\n"
           "\t\t[--right-axis-format format]\n"
           "\t\t[-h|--height pixels] [-o|--logarithmic]\n"
           "\t\t[-u|--upper-limit value] [-z|--lazy]\n"
           "\t\t[-l|--lower-limit value] [-r|--rigid]\n"
           "\t\t[-g|--no-legend] [--daemon <address>]\n"
           "\t\t[-F|--force-rules-legend]\n" "\t\t[-j|--only-graph]\n");
    const char *help_graph2 =
        N_("\t\t[-n|--font FONTTAG:size:font]\n"
           "\t\t[-m|--zoom factor]\n"
           "\t\t[-A|--alt-autoscale]\n"
           "\t\t[-M|--alt-autoscale-max]\n"
           "\t\t[-G|--graph-render-mode {normal,mono}]\n"
           "\t\t[-R|--font-render-mode {normal,light,mono}]\n"
           "\t\t[-B|--font-smoothing-threshold size]\n"
           "\t\t[-T|--tabwidth width]\n"
           "\t\t[-E|--slope-mode]\n"
           "\t\t[-P|--pango-markup]\n"
           "\t\t[-N|--no-gridfit]\n"
           "\t\t[-X|--units-exponent value]\n"
           "\t\t[-L|--units-length value]\n"
           "\t\t[-S|--step seconds]\n"
           "\t\t[-f|--imginfo printfstr]\n"
           "\t\t[-a|--imgformat PNG]\n"
           "\t\t[-c|--color COLORTAG#rrggbb[aa]]\n"
           "\t\t[--border width\n"
           "\t\t[-t|--title string]\n"
           "\t\t[-W|--watermark string]\n"
           "\t\t[DEF:vname=rrd:ds-name:CF]\n");
    const char *help_graph3 =
        N_("\t\t[CDEF:vname=rpn-expression]\n"
           "\t\t[VDEF:vdefname=rpn-expression]\n"
           "\t\t[PRINT:vdefname:format]\n"
           "\t\t[GPRINT:vdefname:format]\n" "\t\t[COMMENT:text]\n"
           "\t\t[SHIFT:vname:offset]\n"
           "\t\t[TEXTALIGN:{left|right|justified|center}]\n"
           "\t\t[TICK:vname#rrggbb[aa][:[fraction][:legend]]]\n"
           "\t\t[HRULE:value#rrggbb[aa][:legend]]\n"
           "\t\t[VRULE:value#rrggbb[aa][:legend]]\n"
           "\t\t[LINE[width]:vname[#rrggbb[aa][:[legend][:STACK]]]]\n"
           "\t\t[AREA:vname[#rrggbb[aa][:[legend][:STACK]]]]\n"
           "\t\t[PRINT:vname:CF:format] (deprecated)\n"
           "\t\t[GPRINT:vname:CF:format] (deprecated)\n"
           "\t\t[STACK:vname[#rrggbb[aa][:legend]]] (deprecated)\n");
    const char *help_tune1 =
        N_(" * tune -  Modify some basic properties of an RRD\n\n"
           "\trrdtool tune filename\n"
           "\t\t[--heartbeat|-h ds-name:heartbeat]\n"
           "\t\t[--data-source-type|-d ds-name:DST]\n"
           "\t\t[--data-source-rename|-r old-name:new-name]\n"
           "\t\t[--minimum|-i ds-name:min] [--maximum|-a ds-name:max]\n"
           "\t\t[--deltapos scale-value] [--deltaneg scale-value]\n"
           "\t\t[--failure-threshold integer]\n"
           "\t\t[--window-length integer]\n"
           "\t\t[--alpha adaptation-parameter]\n");
    const char *help_tune2 =
        N_("\t\t[--beta adaptation-parameter]\n"
           "\t\t[--gamma adaptation-parameter]\n"
           "\t\t[--gamma-deviation adaptation-parameter]\n"
           "\t\t[--aberrant-reset ds-name]\n");
    const char *help_resize =
        N_
        (" * resize - alter the length of one of the RRAs in an RRD\n\n"
         "\trrdtool resize filename rranum GROW|SHRINK rows\n");
    const char *help_xport =
        N_("* xport - generate XML dump from one or several RRD\n\n"
           "\trrdtool xport [-s|--start seconds] [-e|--end seconds]\n"
           "\t\t[-m|--maxrows rows]\n" "\t\t[--step seconds]\n"
           "\t\t[--enumds] [--json]\n" "\t\t[DEF:vname=rrd:ds-name:CF]\n"
           "\t\t[CDEF:vname=rpn-expression]\n"
           "\t\t[XPORT:vname:legend]\n");
    const char *help_quit =
        N_(" * quit - closing a session in remote mode\n\n"
           "\trrdtool quit\n");
    const char *help_ls =
        N_(" * ls - lists all *.rrd files in current directory\n\n"
           "\trrdtool ls\n");
    const char *help_cd =
        N_(" * cd - changes the current directory\n\n"
           "\trrdtool cd new directory\n");
    const char *help_mkdir =
        N_(" * mkdir - creates a new directory\n\n"
           "\trrdtool mkdir newdirectoryname\n");
    const char *help_pwd =
        N_(" * pwd - returns the current working directory\n\n"
           "\trrdtool pwd\n");
    const char *help_lic =
        N_("RRDtool is distributed under the Terms of the GNU General\n"
           "Public License Version 2. (www.gnu.org/copyleft/gpl.html)\n\n"
           "For more information read the RRD manpages\n");
    enum { C_NONE, C_CREATE, C_DUMP, C_INFO, C_RESTORE, C_LAST,
        C_LASTUPDATE, C_FIRST, C_UPDATE, C_FETCH, C_GRAPH, C_GRAPHV,
        C_TUNE,
        C_RESIZE, C_XPORT, C_QUIT, C_LS, C_CD, C_MKDIR, C_PWD,
        C_UPDATEV, C_FLUSHCACHED
    };
    int       help_cmd = C_NONE;

    if (cmd) {
        if (!strcmp(cmd, "create"))
            help_cmd = C_CREATE;
        else if (!strcmp(cmd, "dump"))
            help_cmd = C_DUMP;
        else if (!strcmp(cmd, "info"))
            help_cmd = C_INFO;
        else if (!strcmp(cmd, "restore"))
            help_cmd = C_RESTORE;
        else if (!strcmp(cmd, "last"))
            help_cmd = C_LAST;
        else if (!strcmp(cmd, "lastupdate"))
            help_cmd = C_LASTUPDATE;
        else if (!strcmp(cmd, "first"))
            help_cmd = C_FIRST;
        else if (!strcmp(cmd, "update"))
            help_cmd = C_UPDATE;
        else if (!strcmp(cmd, "updatev"))
            help_cmd = C_UPDATEV;
        else if (!strcmp(cmd, "fetch"))
            help_cmd = C_FETCH;
        else if (!strcmp(cmd, "flushcached"))
            help_cmd = C_FLUSHCACHED;
        else if (!strcmp(cmd, "graph"))
            help_cmd = C_GRAPH;
        else if (!strcmp(cmd, "graphv"))
            help_cmd = C_GRAPHV;
        else if (!strcmp(cmd, "tune"))
            help_cmd = C_TUNE;
        else if (!strcmp(cmd, "resize"))
            help_cmd = C_RESIZE;
        else if (!strcmp(cmd, "xport"))
            help_cmd = C_XPORT;
        else if (!strcmp(cmd, "quit"))
            help_cmd = C_QUIT;
        else if (!strcmp(cmd, "ls"))
            help_cmd = C_LS;
        else if (!strcmp(cmd, "cd"))
            help_cmd = C_CD;
        else if (!strcmp(cmd, "mkdir"))
            help_cmd = C_MKDIR;
        else if (!strcmp(cmd, "pwd"))
            help_cmd = C_PWD;
    }
    fprintf(stdout, _(help_main), PACKAGE_VERSION, __DATE__, __TIME__);
    fflush(stdout);
    switch (help_cmd) {
    case C_NONE:
        puts(_(help_list));
        if (RemoteMode) {
            puts(_(help_listremote));
        }
        break;
    case C_CREATE:
        puts(_(help_create));
        break;
    case C_DUMP:
        puts(_(help_dump));
        break;
    case C_INFO:
        puts(_(help_info));
        break;
    case C_RESTORE:
        puts(_(help_restore));
        break;
    case C_LAST:
        puts(_(help_last));
        break;
    case C_LASTUPDATE:
        puts(_(help_lastupdate));
        break;
    case C_FIRST:
        puts(_(help_first));
        break;
    case C_UPDATE:
        puts(_(help_update));
        break;
    case C_UPDATEV:
        puts(_(help_updatev));
        break;
    case C_FETCH:
        puts(_(help_fetch));
        break;
    case C_FLUSHCACHED:
        puts(_(help_flushcached));
        break;
    case C_GRAPH:
        puts(_(help_graph0));
        puts(_(help_graph1));
        puts(_(help_graph2));
        puts(_(help_graph3));
        break;
    case C_GRAPHV:
        puts(_(help_graphv0));
        puts(_(help_graph1));
        puts(_(help_graph2));
        puts(_(help_graph3));
        break;
    case C_TUNE:
        puts(_(help_tune1));
        puts(_(help_tune2));
        break;
    case C_RESIZE:
        puts(_(help_resize));
        break;
    case C_XPORT:
        puts(_(help_xport));
        break;
    case C_QUIT:
        puts(_(help_quit));
        break;
    case C_LS:
        puts(_(help_ls));
        break;
    case C_CD:
        puts(_(help_cd));
        break;
    case C_MKDIR:
        puts(_(help_mkdir));
        break;
    case C_PWD:
        puts(_(help_pwd));
        break;
    }
    puts(_(help_lic));
}

static char *fgetslong(
    char **aLinePtr,
    FILE * stream)
{
    char     *linebuf;
    size_t    bufsize = MAX_LENGTH;
    int       eolpos = 0;

    if (feof(stream))
        return *aLinePtr = 0;
    if (!(linebuf = malloc(bufsize))) {
        perror("fgetslong: malloc");
        exit(1);
    }
    linebuf[0] = '\0';
    while (fgets(linebuf + eolpos, MAX_LENGTH, stream)) {
        eolpos += strlen(linebuf + eolpos);
        if (linebuf[eolpos - 1] == '\n')
            return *aLinePtr = linebuf;
        bufsize += MAX_LENGTH;
        if (!(linebuf = realloc(linebuf, bufsize))) {
            free(linebuf);
            perror("fgetslong: realloc");
            exit(1);
        }
    }
    if (linebuf[0]){
        return  *aLinePtr = linebuf;
    }
    free(linebuf);
    return *aLinePtr = 0;
}

int main(
    int argc,
    char *argv[])
{
    char    **myargv;
    char     *aLine;
    char     *firstdir = "";

#ifdef MUST_DISABLE_SIGFPE
    signal(SIGFPE, SIG_IGN);
#endif
#ifdef MUST_DISABLE_FPMASK
    fpsetmask(0);
#endif

    /* initialize locale settings
       according to localeconv(3) */       
    setlocale(LC_ALL, "");

#if defined(WIN32) && !defined(__CYGWIN__)
    setmode(fileno(stdout), O_BINARY);
    setmode(fileno(stdin), O_BINARY);
#endif


#if defined(HAVE_LIBINTL_H) && defined(BUILD_LIBINTL)
    bindtextdomain(GETTEXT_PACKAGE, LOCALEDIR);
    textdomain(GETTEXT_PACKAGE);
#endif
    if (argc == 1) {
        PrintUsage("");
        return 0;
    }

    if (((argc == 2) || (argc == 3)) && !strcmp("-", argv[1])) {
#if HAVE_GETRUSAGE
        struct rusage myusage;
        struct timeval starttime;
        struct timeval currenttime;

        gettimeofday(&starttime, NULL);
#endif
        RemoteMode = 1;
        if ((argc == 3) && strcmp("", argv[2])) {

            if (
#ifdef HAVE_GETUID
                   getuid()
#else
                   1
#endif
                   == 0) {

#ifdef HAVE_CHROOT
                if (chroot(argv[2]) != 0){
                    fprintf(stderr, "ERROR: chroot %s: %s\n", argv[2],rrd_strerror(errno));
                    exit(errno);
                }
                ChangeRoot = 1;
                firstdir = "/";
#else
                fprintf(stderr,
                        "ERROR: change root is not supported by your OS "
                        "or at least by this copy of rrdtool\n");
                exit(1);
#endif
            } else {
                firstdir = argv[2];
            }
        }
        if (strcmp(firstdir, "")) {
            if (chdir(firstdir) != 0){
                fprintf(stderr, "ERROR: chdir %s %s\n", firstdir,rrd_strerror(errno));
                exit(errno);
            }
        }

        while (fgetslong(&aLine, stdin)) {
            char *aLineOrig = aLine;
            if ((argc = CountArgs(aLine)) == 0) {
                free(aLine);
                printf("ERROR: not enough arguments\n");
                continue;                
            }
            if ((myargv = (char **) malloc((argc + 1) *
                                           sizeof(char *))) == NULL) {
                perror("malloc");
                exit(1);
            }
            if ((argc = CreateArgs(argv[0], aLine, myargv)) < 0) {
                printf("ERROR: creating arguments\n");
            } else {
                if ( HandleInputLine(argc, myargv, stdout) == 0 ){
#if HAVE_GETRUSAGE
                    getrusage(RUSAGE_SELF, &myusage);
                    gettimeofday(&currenttime, NULL);
                    printf("OK u:%1.2f s:%1.2f r:%1.2f\n",
                           (double) myusage.ru_utime.tv_sec +
                           (double) myusage.ru_utime.tv_usec / 1000000.0,
                           (double) myusage.ru_stime.tv_sec +
                           (double) myusage.ru_stime.tv_usec / 1000000.0,
                           (double) (currenttime.tv_sec - starttime.tv_sec)
                           + (double) (currenttime.tv_usec -
                                       starttime.tv_usec)
                           / 1000000.0);
#else
                    printf("OK\n");
#endif
                }
            }
            fflush(stdout); /* this is important for pipes to work */
            free(myargv);
            free(aLineOrig);
        }
    } else if (argc == 2) {
        PrintUsage(argv[1]);
        exit(0);
    } else if (argc == 3 && !strcmp(argv[1], "help")) {
        PrintUsage(argv[2]);
        exit(0);
    } else {
        exit(HandleInputLine(argc, argv, stderr));
    }
    return 0;
}

/* HandleInputLine is NOT thread safe - due to readdir issues,
   resolving them portably is not really simple. */
int HandleInputLine(
    int argc,
    char **argv,
    FILE * out)
{
#if defined(HAVE_OPENDIR) && defined (HAVE_READDIR)
    DIR      *curdir;   /* to read current dir with ls */
    struct dirent *dent;
#endif
#if defined(HAVE_SYS_STAT_H)
    struct stat st;
#endif

    /* Reset errno to 0 before we start.
     */
    if (RemoteMode) {
        if (argc > 1 && strcmp("quit", argv[1]) == 0) {
            if (argc != 2) {
                printf("ERROR: invalid parameter count for quit\n");
                return (1);
            }
            exit(0);
        }
#if defined(HAVE_OPENDIR) && defined(HAVE_READDIR) && defined(HAVE_CHDIR)
        if (argc > 1 && strcmp("cd", argv[1]) == 0) {
            if (argc != 3) {
                printf("ERROR: invalid parameter count for cd\n");
                return (1);
            }
#if ! defined(HAVE_CHROOT) || ! defined(HAVE_GETUID)
            if (getuid() == 0 && !ChangeRoot) {
                printf
                    ("ERROR: chdir security problem - rrdtool is running as "
                     "root but not chroot!\n");
                return (1);
            }
#endif
            if (chdir(argv[2]) != 0){
                printf("ERROR: chdir %s %s\n", argv[2], rrd_strerror(errno));
                return (1);
            }
            return (0);
        }
        if (argc > 1 && strcmp("pwd", argv[1]) == 0) {
            char     *cwd;      /* To hold current working dir on call to pwd */
            if (argc != 2) {
                printf("ERROR: invalid parameter count for pwd\n");
                return (1);
            }
            cwd = getcwd(NULL, MAXPATH);
            if (cwd == NULL) {
                printf("ERROR: getcwd %s\n", rrd_strerror(errno));
                return (1);
            }
            printf("%s\n", cwd);
            free(cwd);
            return (0);
        }
        if (argc > 1 && strcmp("mkdir", argv[1]) == 0) {
            if (argc != 3) {
                printf("ERROR: invalid parameter count for mkdir\n");
                return (1);
            }
#if ! defined(HAVE_CHROOT) || ! defined(HAVE_GETUID)
            if (getuid() == 0 && !ChangeRoot) {
                printf
                    ("ERROR: mkdir security problem - rrdtool is running as "
                     "root but not chroot!\n");
                return (1);
            }
#endif
            if(mkdir(argv[2], 0777)!=0){
                printf("ERROR: mkdir %s: %s\n", argv[2],rrd_strerror(errno));
                return (1);
            }
            return (0);
        }
        if (argc > 1 && strcmp("ls", argv[1]) == 0) {
            if (argc != 2) {
                printf("ERROR: invalid parameter count for ls\n");
                return (1);
            }
            if ((curdir = opendir(".")) != NULL) {
                while ((dent = readdir(curdir)) != NULL) {
                    if (!stat(dent->d_name, &st)) {
                        if (S_ISDIR(st.st_mode)) {
                            printf("d %s\n", dent->d_name);
                        }
                        if (strlen(dent->d_name) > 4 && S_ISREG(st.st_mode)) {
                            if (!strcmp
                                (dent->d_name + NAMLEN(dent) - 4, ".rrd")
                                || !strcmp(dent->d_name + NAMLEN(dent) - 4,
                                           ".RRD")) {
                                printf("- %s\n", dent->d_name);
                            }
                        }
                    }
                }
                closedir(curdir);
            } else {
                printf("ERROR: opendir .: %s\n", rrd_strerror(errno));
                return (errno);
            }
            return (0);
        }
#endif                          /* opendir and readdir */

    }
    if (argc < 3
        || strcmp("help", argv[1]) == 0
        || strcmp("--help", argv[1]) == 0
        || strcmp("-help", argv[1]) == 0
        || strcmp("-?", argv[1]) == 0 || strcmp("-h", argv[1]) == 0) {
        PrintUsage("");
        return 0;
    }

    if (strcmp("create", argv[1]) == 0)
        rrd_create(argc - 1, &argv[1]);
    else if (strcmp("dump", argv[1]) == 0)
        rrd_dump(argc - 1, &argv[1]);
    else if (strcmp("info", argv[1]) == 0 || strcmp("updatev", argv[1]) == 0) {
        rrd_info_t *data;

        if (strcmp("info", argv[1]) == 0)

            data = rrd_info(argc - 1, &argv[1]);
        else
            data = rrd_update_v(argc - 1, &argv[1]);
        rrd_info_print(data);
        rrd_info_free(data);
    }

    else if (strcmp("--version", argv[1]) == 0 ||
             strcmp("version", argv[1]) == 0 ||
             strcmp("v", argv[1]) == 0 ||
             strcmp("-v", argv[1]) == 0 || strcmp("-version", argv[1]) == 0)
        printf("RRDtool " PACKAGE_VERSION
               "  Copyright by Tobi Oetiker, 1997-2008 (%f)\n",
               rrd_version());
    else if (strcmp("restore", argv[1]) == 0)
        rrd_restore(argc - 1, &argv[1]);
    else if (strcmp("resize", argv[1]) == 0)
        rrd_resize(argc - 1, &argv[1]);
    else if (strcmp("last", argv[1]) == 0)
        printf("%ld\n", rrd_last(argc - 1, &argv[1]));
    else if (strcmp("lastupdate", argv[1]) == 0) {
        rrd_lastupdate(argc - 1, &argv[1]);
    } else if (strcmp("first", argv[1]) == 0)
        printf("%ld\n", rrd_first(argc - 1, &argv[1]));
    else if (strcmp("update", argv[1]) == 0)
        rrd_update(argc - 1, &argv[1]);
    else if (strcmp("fetch", argv[1]) == 0) {
        time_t    start, end, ti;
        unsigned long step, ds_cnt, i, ii;
        rrd_value_t *data, *datai;
        char    **ds_namv;

        if (rrd_fetch
            (argc - 1, &argv[1], &start, &end, &step, &ds_cnt, &ds_namv,
             &data) == 0) {
            datai = data;
            printf("           ");
            for (i = 0; i < ds_cnt; i++)
                printf("%20s", ds_namv[i]);
            printf("\n\n");
            for (ti = start + step; ti <= end; ti += step) {
                printf("%10lu:", ti);
                for (ii = 0; ii < ds_cnt; ii++)
                    printf(" %0.10e", *(datai++));
                printf("\n");
            }
            for (i = 0; i < ds_cnt; i++)
                free(ds_namv[i]);
            free(ds_namv);
            free(data);
        }
    } else if (strcmp("xport", argv[1]) == 0) {
#ifdef HAVE_RRD_GRAPH
        int       xxsize;
        unsigned long int j = 0;
        time_t    start, end, ti;
        unsigned long step, col_cnt, row_cnt;
        rrd_value_t *data, *ptr;
        char    **legend_v;
        int       enumds = 0;
        int       json = 0;
        int       i;
        size_t    vtag_s = strlen(COL_DATA_TAG) + 10;
        char     *vtag = malloc(vtag_s);

        for (i = 2; i < argc; i++) {
            if (strcmp("--enumds", argv[i]) == 0)
                enumds = 1;
            if (strcmp("--json", argv[i]) == 0)
                json = 1;
        }

        if (rrd_xport
            (argc - 1, &argv[1], &xxsize, &start, &end, &step, &col_cnt,
             &legend_v, &data) == 0) {
            char *old_locale = setlocale(LC_NUMERIC,NULL);
            setlocale(LC_NUMERIC, "C");
            row_cnt = (end - start) / step;
            ptr = data;
            if (json == 0){
                printf("<?xml version=\"1.0\" encoding=\"%s\"?>\n\n",
                    XML_ENCODING);
                printf("<%s>\n", ROOT_TAG);
                printf("  <%s>\n", META_TAG);
            }
            else {
                printf("{ about: 'RRDtool xport JSON output',\n  meta: {\n");
            }


#define pXJV(indent,fmt,tag,value) \
            if (json) { \
               printf(indent "\"%s\": " fmt ",\n",tag,value); \
            } else { \
               printf(indent "<%s>" fmt "</%s>\n",tag,value,tag); \
            }
        
            pXJV("    ","%lld",META_START_TAG,(long long int) start + step);
            pXJV("    ","%lu", META_STEP_TAG, step);
            pXJV("    ","%lld",META_END_TAG,(long long int) start + step);
            if (! json){
                    pXJV("    ","%lu", META_ROWS_TAG, row_cnt);
                    pXJV("    ","%lu", META_COLS_TAG, col_cnt);
            }
             
            if (json){
                printf("    \"%s\": [\n", LEGEND_TAG);
            }
            else {
                printf("    <%s>\n", LEGEND_TAG);
            }
            for (j = 0; j < col_cnt; j++) {
                char     *entry = NULL;
                entry = legend_v[j];
                if (json){
                    printf("      '%s'", entry);
                    if (j < col_cnt -1){
                        printf(",");
                    }
                    printf("\n");
                }
                else {
                    printf("      <%s>%s</%s>\n", LEGEND_ENTRY_TAG, entry,
                       LEGEND_ENTRY_TAG);
                }
                free(entry);
            }
            free(legend_v);
            if (json){
                printf("          ]\n     },\n");
            }
            else {
                printf("    </%s>\n", LEGEND_TAG);
                printf("  </%s>\n", META_TAG);
            }
            
            if (json){
                printf("  \"%s\": [\n",DATA_TAG);
            } else {
                printf("  <%s>\n", DATA_TAG);
            }
            for (ti = start + step; ti <= end; ti += step) {
                if (json){
                    printf("    [ ");
                }
                else {
                    printf("    <%s>", DATA_ROW_TAG);
                    printf("<%s>%lld</%s>", COL_TIME_TAG, (long long int)ti, COL_TIME_TAG);
                }
                for (j = 0; j < col_cnt; j++) {
                    rrd_value_t newval = DNAN;
                    newval = *ptr;
                    if (json){
                        if (isnan(newval)){
                            printf("null");                        
                        } else {
                            printf("%0.10e",newval);
                        }
                        if (j < col_cnt -1){
                            printf(", ");
                        }
                    }
                    else {
                        if (enumds == 1)
                            snprintf(vtag, vtag_s, "%s%lu", COL_DATA_TAG, j);
                        else
                           snprintf(vtag, vtag_s, "%s", COL_DATA_TAG);
                        if (isnan(newval)) {
                           printf("<%s>NaN</%s>", vtag, vtag);
                        } else {
                           printf("<%s>%0.10e</%s>", vtag, newval, vtag);
                        };
                    }
                    ptr++;
                }                
                if (json){
                    printf(ti < end ? " ],\n" : "  ]\n");
                }
                else {                
                    printf("</%s>\n", DATA_ROW_TAG);
                }
            }
            free(data);
            if (json){
                printf("  ]\n}\n");
            }
            else {
                printf("  </%s>\n", DATA_TAG);
                printf("</%s>\n", ROOT_TAG);
            }
            setlocale(LC_NUMERIC, old_locale);
        }
        free(vtag);
#else
        rrd_set_error("the instance of rrdtool has been compiled without graphics");
#endif
    } else if (strcmp("graph", argv[1]) == 0) {
#ifdef HAVE_RRD_GRAPH
        char    **calcpr;

#ifdef notused /*XXX*/
        const char *imgfile = argv[2];  /* rrd_graph changes argv pointer */
#endif
        int       xsize, ysize;
        double    ymin, ymax;
        int       i;
        int       tostdout = (strcmp(argv[2], "-") == 0);
        int       imginfo = 0;

        for (i = 2; i < argc; i++) {
            if (strcmp(argv[i], "--imginfo") == 0
                || strcmp(argv[i], "-f") == 0) {
                imginfo = 1;
                break;
            }
        }
        if (rrd_graph
            (argc - 1, &argv[1], &calcpr, &xsize, &ysize, NULL, &ymin,
             &ymax) == 0) {
            if (!tostdout && !imginfo)
                printf("%dx%d\n", xsize, ysize);
            if (calcpr) {
                for (i = 0; calcpr[i]; i++) {
                    if (!tostdout)
                        printf("%s\n", calcpr[i]);
                    free(calcpr[i]);
                }
                free(calcpr);
            }
        }

#else
       rrd_set_error("the instance of rrdtool has been compiled without graphics");
#endif
    } else if (strcmp("graphv", argv[1]) == 0) {
#ifdef HAVE_RRD_GRAPH
        rrd_info_t *grinfo = NULL;  /* 1 to distinguish it from the NULL that rrd_graph sends in */

        grinfo = rrd_graph_v(argc - 1, &argv[1]);
        if (grinfo) {
            rrd_info_print(grinfo);
            rrd_info_free(grinfo);
        }
#else
       rrd_set_error("the instance of rrdtool has been compiled without graphics");
#endif
    } else if (strcmp("tune", argv[1]) == 0)
        rrd_tune(argc - 1, &argv[1]);
#ifndef WIN32
    else if (strcmp("flushcached", argv[1]) == 0)
        rrd_flushcached(argc - 1, &argv[1]);
#endif
    else {
        rrd_set_error("unknown function '%s'", argv[1]);
    }
    if (rrd_test_error()) {
        fprintf(out, "ERROR: %s\n", rrd_get_error());
        rrd_clear_error();
        return 1;
    }
    return (0);
}

int CountArgs(
    char *aLine)
{
    int       i = 0;
    int       aCount = 0;
    int       inarg = 0;

    while (aLine[i] == ' ')
        i++;
    while (aLine[i] != 0) {
        if ((aLine[i] == ' ') && inarg) {
            inarg = 0;
        }
        if ((aLine[i] != ' ') && !inarg) {
            inarg = 1;
            aCount++;
        }
        i++;
    }
    return aCount;
}

/*
 * CreateArgs - take a string (aLine) and tokenize
 */
int CreateArgs(
    char *pName,
    char *aLine,
    char **argv)
{
    char     *getP, *putP;
    char    **pargv = argv;
    char      Quote = 0;
    int       inArg = 0;
    int       len;
    int       argc = 1;

    len = strlen(aLine);
    /* remove trailing space and newlines */
    while (len && aLine[len] <= ' ') {
        aLine[len] = 0;
        len--;
    }
    /* sikp leading blanks */
    while (*aLine && *aLine <= ' ')
        aLine++;
    pargv[0] = pName;
    argc = 1;
    getP = aLine;
    putP = aLine;
    while (*getP) {
        switch (*getP) {
        case ' ':
            if (Quote) {
                *(putP++) = *getP;
            } else if (inArg) {
                *(putP++) = 0;
                inArg = 0;
            }
            break;
        case '"':
        case '\'':
            if (Quote != 0) {
                if (Quote == *getP)
                    Quote = 0;
                else {
                    *(putP++) = *getP;
                }
            } else {
                if (!inArg) {
                    pargv[argc++] = putP;
                    inArg = 1;
                }
                Quote = *getP;
            }
            break;
        default:
            if (!inArg) {
                pargv[argc++] = putP;
                inArg = 1;
            }
            *(putP++) = *getP;
            break;
        }
        getP++;
    }

    *putP = '\0';
    if (Quote)
        return -1;
    else
        return argc;
}
