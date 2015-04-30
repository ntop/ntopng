/*
 * tclrrd.c -- A TCL interpreter extension to access the RRD library.
 *
 * Copyright (c) 1999,2000 Frank Strauss, Technical University of Braunschweig.
 *
 * Thread-safe code copyright (c) 2005 Oleg Derevenetz, CenterTelecom Voronezh ISP.
 *
 * See the file "COPYING" for information on usage and redistribution
 * of this file, and for a DISCLAIMER OF ALL WARRANTIES.
 *
 * $Id$
 */



#include <errno.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <tcl.h>
#include <stdlib.h>
#include "../../src/rrd_tool.h"
#include "../../src/rrd_format.h"

/* support pre-8.4 tcl */

#ifndef CONST84
#   define CONST84
#endif

extern int Tclrrd_Init(
    Tcl_Interp *interp);
extern int Tclrrd_SafeInit(
    Tcl_Interp *interp);


/*
 * some rrd_XXX() and new thread-safe versions of Rrd_XXX()
 * functions might modify the argv strings passed to it.
 * Hence, we need to do some preparation before
 * calling the rrd library functions.
 */
static char **getopt_init(
    int argc,
    CONST84 char *argv[])
{
    char    **argv2;
    int       i;

    argv2 = calloc(argc, sizeof(char *));
    for (i = 0; i < argc; i++) {
        argv2[i] = strdup(argv[i]);
    }
    return argv2;
}

static void getopt_cleanup(
    int argc,
    char **argv2)
{
    int       i;

    for (i = 0; i < argc; i++) {
        if (argv2[i] != NULL) {
            free(argv2[i]);
        }
    }
    free(argv2);
}

static void getopt_free_element(
    char *argv2[],
    int argn)
{
    if (argv2[argn] != NULL) {
        free(argv2[argn]);
        argv2[argn] = NULL;
    }
}

static void getopt_squieeze(
    int *argc,
    char *argv2[])
{
    int       i, null_i = 0, argc_tmp = *argc;

    for (i = 0; i < argc_tmp; i++) {
        if (argv2[i] == NULL) {
            (*argc)--;
        } else {
            argv2[null_i++] = argv2[i];
        }
    }
}



/* Thread-safe version */
static int Rrd_Create(
    ClientData __attribute__((unused)) clientData,
    Tcl_Interp *interp,
    int argc,
    CONST84 char *argv[])
{
    int       argv_i;
    char    **argv2;
    char     *parsetime_error = NULL;
    time_t    last_up = time(NULL) - 10;
    long int  long_tmp;
    unsigned long int pdp_step = 300;
    rrd_time_value_t last_up_tv;

    argv2 = getopt_init(argc, argv);

    for (argv_i = 1; argv_i < argc; argv_i++) {
        if (!strcmp(argv2[argv_i], "--start") || !strcmp(argv2[argv_i], "-b")) {
            if (argv_i++ >= argc) {
                Tcl_AppendResult(interp, "RRD Error: option '",
                                 argv2[argv_i - 1], "' needs an argument",
                                 (char *) NULL);
                getopt_cleanup(argc, argv2);
                return TCL_ERROR;
            }
            if ((parsetime_error = rrd_parsetime(argv2[argv_i], &last_up_tv))) {
                Tcl_AppendResult(interp, "RRD Error: invalid time format: '",
                                 argv2[argv_i], "'", (char *) NULL);
                getopt_cleanup(argc, argv2);
                return TCL_ERROR;
            }
            if (last_up_tv.type == RELATIVE_TO_END_TIME ||
                last_up_tv.type == RELATIVE_TO_START_TIME) {
                Tcl_AppendResult(interp,
                                 "RRD Error: specifying time relative to the 'start' ",
                                 "or 'end' makes no sense here",
                                 (char *) NULL);
                getopt_cleanup(argc, argv2);
                return TCL_ERROR;
            }
            last_up = mktime(&last_up_tv.tm) +last_up_tv.offset;
            if (last_up < 3600 * 24 * 365 * 10) {
                Tcl_AppendResult(interp,
                                 "RRD Error: the first entry to the RRD should be after 1980",
                                 (char *) NULL);
                getopt_cleanup(argc, argv2);
                return TCL_ERROR;
            }
            getopt_free_element(argv2, argv_i - 1);
            getopt_free_element(argv2, argv_i);
        } else if (!strcmp(argv2[argv_i], "--step")
                   || !strcmp(argv2[argv_i], "-s")) {
            if (argv_i++ >= argc) {
                Tcl_AppendResult(interp, "RRD Error: option '",
                                 argv2[argv_i - 1], "' needs an argument",
                                 (char *) NULL);
                getopt_cleanup(argc, argv2);
                return TCL_ERROR;
            }
            long_tmp = atol(argv2[argv_i]);
            if (long_tmp < 1) {
                Tcl_AppendResult(interp,
                                 "RRD Error: step size should be no less than one second",
                                 (char *) NULL);
                getopt_cleanup(argc, argv2);
                return TCL_ERROR;
            }
            pdp_step = long_tmp;
            getopt_free_element(argv2, argv_i - 1);
            getopt_free_element(argv2, argv_i);
        } else if (!strcmp(argv2[argv_i], "--")) {
            getopt_free_element(argv2, argv_i);
            break;
        } else if (argv2[argv_i][0] == '-') {
            Tcl_AppendResult(interp, "RRD Error: unknown option '",
                             argv2[argv_i], "'", (char *) NULL);
            getopt_cleanup(argc, argv2);
            return TCL_ERROR;
        }
    }

    getopt_squieeze(&argc, argv2);

    if (argc < 2) {
        Tcl_AppendResult(interp, "RRD Error: needs rrd filename",
                         (char *) NULL);
        getopt_cleanup(argc, argv2);
        return TCL_ERROR;
    }

    rrd_create_r(argv2[1], pdp_step, last_up, argc - 2,
                 (const char **)argv2 + 2);

    getopt_cleanup(argc, argv2);

    if (rrd_test_error()) {
        Tcl_AppendResult(interp, "RRD Error: ",
                         rrd_get_error(), (char *) NULL);
        rrd_clear_error();
        return TCL_ERROR;
    }

    return TCL_OK;
}



/* Thread-safe version */
static int Rrd_Dump(
    ClientData __attribute__((unused)) clientData,
    Tcl_Interp *interp,
    int argc,
    CONST84 char *argv[])
{
    if (argc < 2) {
        Tcl_AppendResult(interp, "RRD Error: needs rrd filename",
                         (char *) NULL);
        return TCL_ERROR;
    }

    rrd_dump_r(argv[1], NULL);

    /* NOTE: rrd_dump() writes to stdout. No interaction with TCL. */

    if (rrd_test_error()) {
        Tcl_AppendResult(interp, "RRD Error: ",
                         rrd_get_error(), (char *) NULL);
        rrd_clear_error();
        return TCL_ERROR;
    }

    return TCL_OK;
}

/* Thread-safe version */
static int Rrd_Flushcached(
    ClientData __attribute__((unused)) clientData,
    Tcl_Interp *interp,
    int argc,
    CONST84 char *argv[])
{
    if (argc < 2) {
        Tcl_AppendResult(interp, "RRD Error: needs rrd filename",
                         (char *) NULL);
        return TCL_ERROR;
    }

    rrd_flushcached(argc, (char**)argv);

    if (rrd_test_error()) {
        Tcl_AppendResult(interp, "RRD Error: ",
                         rrd_get_error(), (char *) NULL);
        rrd_clear_error();
        return TCL_ERROR;
    }

    return TCL_OK;
}


/* Thread-safe version */
static int Rrd_Last(
    ClientData __attribute__((unused)) clientData,
    Tcl_Interp *interp,
    int argc,
    CONST84 char *argv[])
{
    time_t    t;

    if (argc < 2) {
        Tcl_AppendResult(interp, "RRD Error: needs rrd filename",
                         (char *) NULL);
        return TCL_ERROR;
    }

    t = rrd_last_r(argv[1]);

    if (rrd_test_error()) {
        Tcl_AppendResult(interp, "RRD Error: ",
                         rrd_get_error(), (char *) NULL);
        rrd_clear_error();
        return TCL_ERROR;
    }

    Tcl_SetIntObj(Tcl_GetObjResult(interp), t);

    return TCL_OK;
}



/* Thread-safe version */
static int Rrd_Update(
    ClientData __attribute__((unused)) clientData,
    Tcl_Interp *interp,
    int argc,
    CONST84 char *argv[])
{
    int       argv_i;
    char    **argv2, *template = NULL;

    argv2 = getopt_init(argc, argv);

    for (argv_i = 1; argv_i < argc; argv_i++) {
        if (!strcmp(argv2[argv_i], "--template")
            || !strcmp(argv2[argv_i], "-t")) {
            if (argv_i++ >= argc) {
                Tcl_AppendResult(interp, "RRD Error: option '",
                                 argv2[argv_i - 1], "' needs an argument",
                                 (char *) NULL);
                if (template != NULL) {
                    free(template);
                }
                getopt_cleanup(argc, argv2);
                return TCL_ERROR;
            }
            if (template != NULL) {
                free(template);
            }
            template = strdup(argv2[argv_i]);
            getopt_free_element(argv2, argv_i - 1);
            getopt_free_element(argv2, argv_i);
        } else if (!strcmp(argv2[argv_i], "--")) {
            getopt_free_element(argv2, argv_i);
            break;
        } else if (argv2[argv_i][0] == '-') {
            Tcl_AppendResult(interp, "RRD Error: unknown option '",
                             argv2[argv_i], "'", (char *) NULL);
            if (template != NULL) {
                free(template);
            }
            getopt_cleanup(argc, argv2);
            return TCL_ERROR;
        }
    }

    getopt_squieeze(&argc, argv2);

    if (argc < 2) {
        Tcl_AppendResult(interp, "RRD Error: needs rrd filename",
                         (char *) NULL);
        if (template != NULL) {
            free(template);
        }
        getopt_cleanup(argc, argv2);
        return TCL_ERROR;
    }

    rrd_update_r(argv2[1], template, argc - 2, (const char **)argv2 + 2);

    if (template != NULL) {
        free(template);
    }
    getopt_cleanup(argc, argv2);

    if (rrd_test_error()) {
        Tcl_AppendResult(interp, "RRD Error: ",
                         rrd_get_error(), (char *) NULL);
        rrd_clear_error();
        return TCL_ERROR;
    }

    return TCL_OK;
}

static int Rrd_Lastupdate(
    ClientData __attribute__((unused)) clientData,
    Tcl_Interp *interp,
    int argc,
    CONST84 char *argv[])
{
    time_t    last_update;
    char    **argv2;
    char    **ds_namv;
    char    **last_ds;
    char      s[30];
    Tcl_Obj  *listPtr;
    unsigned long ds_cnt, i;

    /* TODO: support for rrdcached */
    if (argc != 2) {
        Tcl_AppendResult(interp, "RRD Error: needs a single rrd filename",
                         (char *) NULL);
        return TCL_ERROR;
    }

    argv2 = getopt_init(argc, argv);
    if (rrd_lastupdate_r(argv2[1], &last_update,
                       &ds_cnt, &ds_namv, &last_ds) == 0) {
        listPtr = Tcl_GetObjResult(interp);
        for (i = 0; i < ds_cnt; i++) {
            sprintf(s, " %28s", ds_namv[i]);
            Tcl_ListObjAppendElement(interp, listPtr,
                                     Tcl_NewStringObj(s, -1));
            sprintf(s, "\n\n%10lu:", last_update);
            Tcl_ListObjAppendElement(interp, listPtr,
                                     Tcl_NewStringObj(s, -1));
            for (i = 0; i < ds_cnt; i++) {
                sprintf(s, " %s", last_ds[i]);
                Tcl_ListObjAppendElement(interp, listPtr,
                                         Tcl_NewStringObj(s, -1));
                free(last_ds[i]);
                free(ds_namv[i]);
            }
            sprintf(s, "\n");
            Tcl_ListObjAppendElement(interp, listPtr,
                                     Tcl_NewStringObj(s, -1));
            free(last_ds);
            free(ds_namv);
        }
    }
    return TCL_OK;
}

static int Rrd_Fetch(
    ClientData __attribute__((unused)) clientData,
    Tcl_Interp *interp,
    int argc,
    CONST84 char *argv[])
{
    time_t    start, end, j;
    unsigned long step, ds_cnt, i, ii;
    rrd_value_t *data, *datai;
    char    **ds_namv;
    Tcl_Obj  *listPtr;
    char      s[30];
    char    **argv2;

    argv2 = getopt_init(argc, argv);
    if (rrd_fetch(argc, argv2, &start, &end, &step,
                  &ds_cnt, &ds_namv, &data) != -1) {
        datai = data;
        listPtr = Tcl_GetObjResult(interp);
        for (j = start; j <= end; j += step) {
            for (ii = 0; ii < ds_cnt; ii++) {
                sprintf(s, "%.2f", *(datai++));
                Tcl_ListObjAppendElement(interp, listPtr,
                                         Tcl_NewStringObj(s, -1));
            }
        }
        for (i = 0; i < ds_cnt; i++)
            free(ds_namv[i]);
        free(ds_namv);
        free(data);
    }
    getopt_cleanup(argc, argv2);

    if (rrd_test_error()) {
        Tcl_AppendResult(interp, "RRD Error: ",
                         rrd_get_error(), (char *) NULL);
        rrd_clear_error();
        return TCL_ERROR;
    }

    return TCL_OK;
}



static int Rrd_Graph(
    ClientData __attribute__((unused)) clientData,
    Tcl_Interp *interp,
    int argc,
    CONST84 char *argv[])
{
    Tcl_Channel channel;
    int       mode, fd2;
    ClientData fd1;
    FILE     *stream = NULL;
    char    **calcpr = NULL;
    int       rc, xsize, ysize;
    double    ymin, ymax;
    char      dimensions[50];
    char    **argv2;
    CONST84 char *save;

    /*
     * If the "filename" is a Tcl fileID, then arrange for rrd_graph() to write to
     * that file descriptor.  Will this work with windoze?  I have no idea.
     */
    if ((channel = Tcl_GetChannel(interp, argv[1], &mode)) != NULL) {
        /*
         * It >is< a Tcl fileID
         */
        if (!(mode & TCL_WRITABLE)) {
            Tcl_AppendResult(interp, "channel \"", argv[1],
                             "\" wasn't opened for writing", (char *) NULL);
            return TCL_ERROR;
        }
        /*
         * Must flush channel to make sure any buffered data is written before
         * rrd_graph() writes to the stream
         */
        if (Tcl_Flush(channel) != TCL_OK) {
            Tcl_AppendResult(interp, "flush failed for \"", argv[1], "\": ",
                             strerror(Tcl_GetErrno()), (char *) NULL);
            return TCL_ERROR;
        }
        if (Tcl_GetChannelHandle(channel, TCL_WRITABLE, &fd1) != TCL_OK) {
            Tcl_AppendResult(interp,
                             "cannot get file descriptor associated with \"",
                             argv[1], "\"", (char *) NULL);
            return TCL_ERROR;
        }
        /*
         * Must dup() file descriptor so we can fclose(stream), otherwise the fclose()
         * would close Tcl's file descriptor
         */
        if ((fd2 = dup((int)fd1)) == -1) {
            Tcl_AppendResult(interp,
                             "dup() failed for file descriptor associated with \"",
                             argv[1], "\": ", strerror(errno), (char *) NULL);
            return TCL_ERROR;
        }
        /*
         * rrd_graph() wants a FILE*
         */
        if ((stream = fdopen(fd2, "wb")) == NULL) {
            Tcl_AppendResult(interp,
                             "fdopen() failed for file descriptor associated with \"",
                             argv[1], "\": ", strerror(errno), (char *) NULL);
            close(fd2); /* plug potential file descriptor leak */
            return TCL_ERROR;
        }

        save = argv[1];
        argv[1] = "-";
        argv2 = getopt_init(argc, argv);
        argv[1] = save;
    } else {
        Tcl_ResetResult(interp);    /* clear error from Tcl_GetChannel() */
        argv2 = getopt_init(argc, argv);
    }

    rc = rrd_graph(argc, argv2, &calcpr, &xsize, &ysize, stream, &ymin,
                   &ymax);
    getopt_cleanup(argc, argv2);

    if (stream != NULL)
        fclose(stream); /* plug potential malloc & file descriptor leak */

    if (rc != -1) {
        sprintf(dimensions, "%d %d", xsize, ysize);
        Tcl_AppendResult(interp, dimensions, (char *) NULL);
        if (calcpr) {
#if 0
            int       i;

            for (i = 0; calcpr[i]; i++) {
                printf("%s\n", calcpr[i]);
                free(calcpr[i]);
            }
#endif
            free(calcpr);
        }
    }

    if (rrd_test_error()) {
        Tcl_AppendResult(interp, "RRD Error: ",
                         rrd_get_error(), (char *) NULL);
        rrd_clear_error();
        return TCL_ERROR;
    }

    return TCL_OK;
}



static int Rrd_Tune(
    ClientData __attribute__((unused)) clientData,
    Tcl_Interp *interp,
    int argc,
    CONST84 char *argv[])
{
    char    **argv2;

    argv2 = getopt_init(argc, argv);
    rrd_tune(argc, argv2);
    getopt_cleanup(argc, argv2);

    if (rrd_test_error()) {
        Tcl_AppendResult(interp, "RRD Error: ",
                         rrd_get_error(), (char *) NULL);
        rrd_clear_error();
        return TCL_ERROR;
    }

    return TCL_OK;
}



static int Rrd_Resize(
    ClientData __attribute__((unused)) clientData,
    Tcl_Interp *interp,
    int argc,
    CONST84 char *argv[])
{
    char    **argv2;

    argv2 = getopt_init(argc, argv);
    rrd_resize(argc, argv2);
    getopt_cleanup(argc, argv2);

    if (rrd_test_error()) {
        Tcl_AppendResult(interp, "RRD Error: ",
                         rrd_get_error(), (char *) NULL);
        rrd_clear_error();
        return TCL_ERROR;
    }

    return TCL_OK;
}



static int Rrd_Restore(
    ClientData __attribute__((unused)) clientData,
    Tcl_Interp *interp,
    int argc,
    CONST84 char *argv[])
{
    char    **argv2;

    argv2 = getopt_init(argc, argv);
    rrd_restore(argc, argv2);
    getopt_cleanup(argc, argv2);

    if (rrd_test_error()) {
        Tcl_AppendResult(interp, "RRD Error: ",
                         rrd_get_error(), (char *) NULL);
        rrd_clear_error();
        return TCL_ERROR;
    }

    return TCL_OK;
}



/*
 * The following structure defines the commands in the Rrd extension.
 */

typedef struct {
    char     *name;     /* Name of the command. */
    Tcl_CmdProc *proc;  /* Procedure for command. */
    int       hide;     /* Hide if safe interpreter */
} CmdInfo;

static CmdInfo rrdCmds[] = {
    {"Rrd::create", Rrd_Create, 1}, /* Thread-safe version */
    {"Rrd::dump", Rrd_Dump, 0}, /* Thread-safe version */
    {"Rrd::flushcached", Rrd_Flushcached, 0},
    {"Rrd::last", Rrd_Last, 0}, /* Thread-safe version */
    {"Rrd::lastupdate", Rrd_Lastupdate, 0}, /* Thread-safe version */
    {"Rrd::update", Rrd_Update, 1}, /* Thread-safe version */
    {"Rrd::fetch", Rrd_Fetch, 0},
    {"Rrd::graph", Rrd_Graph, 1},   /* Due to RRD's API, a safe
                                       interpreter cannot create
                                       a graph since it writes to
                                       a filename supplied by the
                                       caller */
    {"Rrd::tune", Rrd_Tune, 1},
    {"Rrd::resize", Rrd_Resize, 1},
    {"Rrd::restore", Rrd_Restore, 1},
    {(char *) NULL, (Tcl_CmdProc *) NULL, 0}
};



static int init(
    Tcl_Interp *interp,
    int safe)
{
    CmdInfo  *cmdInfoPtr;
    Tcl_CmdInfo info;

    if (Tcl_InitStubs(interp, TCL_VERSION, 0) == NULL)
        return TCL_ERROR;

    if (Tcl_PkgRequire(interp, "Tcl", TCL_VERSION, 0) == NULL) {
        return TCL_ERROR;
    }

    /*
     * Why a global array?  In keeping with the Rrd:: namespace, why
     * not simply create a normal variable Rrd::version and set it?
     */
    Tcl_SetVar2(interp, "rrd", "version", VERSION, TCL_GLOBAL_ONLY);

    for (cmdInfoPtr = rrdCmds; cmdInfoPtr->name != NULL; cmdInfoPtr++) {
        /*
         * Check if the command already exists and return an error
         * to ensure we detect name clashes while loading the Rrd
         * extension.
         */
        if (Tcl_GetCommandInfo(interp, cmdInfoPtr->name, &info)) {
            Tcl_AppendResult(interp, "command \"", cmdInfoPtr->name,
                             "\" already exists", (char *) NULL);
            return TCL_ERROR;
        }
        if (safe && cmdInfoPtr->hide) {
#if 0
            /*
             * Turns out the one cannot hide a command in a namespace
             * due to a limitation of Tcl, one can only hide global
             * commands.  Thus, if we created the commands without
             * the Rrd:: namespace in a safe interpreter, then the
             * "unsafe" commands could be hidden -- which would allow
             * an owning interpreter either un-hiding them or doing
             * an "interp invokehidden".  If the Rrd:: namespace is
             * used, then it's still possible for the owning interpreter
             * to fake out the missing commands:
             *
             *   # Make all Rrd::* commands available in master interperter
             *   package require Rrd
             *   set safe [interp create -safe]
             *   # Make safe Rrd::* commands available in safe interperter
             *   interp invokehidden $safe -global load ./tclrrd1.2.11.so
             *   # Provide the safe interpreter with the missing commands
             *   $safe alias Rrd::update do_update $safe
             *   proc do_update {which_interp $args} {
             *     # Do some checking maybe...
             *       :
             *     return [eval Rrd::update $args]
             *   }
             *
             * Our solution for now is to just not create the "unsafe"
             * commands in a safe interpreter.
             */
            if (Tcl_HideCommand(interp, cmdInfoPtr->name, cmdInfoPtr->name) !=
                TCL_OK)
                return TCL_ERROR;
#endif
        } else
            Tcl_CreateCommand(interp, cmdInfoPtr->name, cmdInfoPtr->proc,
                              (ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);
    }

    if (Tcl_PkgProvide(interp, "Rrd", VERSION) != TCL_OK) {
        return TCL_ERROR;
    }

    return TCL_OK;
}

int Tclrrd_Init(
    Tcl_Interp *interp)
{
    return init(interp, 0);
}

/*
 * See the comments above and note how few commands are considered "safe"...
 * Using rrdtool in a safe interpreter has very limited functionality.  It's
 * tempting to just return TCL_ERROR and forget about it.
 */
int Tclrrd_SafeInit(
    Tcl_Interp *interp)
{
    return init(interp, 1);
}
