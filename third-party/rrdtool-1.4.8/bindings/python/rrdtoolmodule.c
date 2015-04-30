/*
 * rrdtoolmodule.c
 *
 * RRDTool Python binding
 *
 * Author  : Hye-Shik Chang <perky@fallin.lv>
 * Date    : $Date: 2003/02/22 07:41:19 $
 * Created : 23 May 2002
 *
 * $Revision: 1.14 $
 *
 *  ==========================================================================
 *  This file is part of py-rrdtool.
 *
 *  py-rrdtool is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as published
 *  by the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  py-rrdtool is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with Foobar; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#ifdef UNUSED
#elif defined(__GNUC__)
# define UNUSED(x) x __attribute__((unused))
#elif defined(__LCLINT__)
# define UNUSED(x) /*@unused@*/ x
#else
# define UNUSED(x) x
#endif


#include "../../rrd_config.h"
static const char *__version__ = PACKAGE_VERSION;

#include "Python.h"
#include "../../src/rrd_tool.h"
//#include "rrd.h"
//#include "rrd_extra.h"

static PyObject *ErrorObject;
extern int optind;
extern int opterr;

/* forward declaration to keep compiler happy */
void      initrrdtool(
    void);

static int create_args(
    char *command,
    PyObject * args,
    int *argc,
    char ***argv)
{
    PyObject *o, *lo;
    int       args_count,
              argv_count,
              element_count,
              i, j;

    args_count = PyTuple_Size(args);
    element_count = 0;
    for (i = 0; i < args_count; i++) {
        o = PyTuple_GET_ITEM(args, i);
        if (PyString_Check(o))
            element_count++;
        else if (PyList_CheckExact(o))
                element_count += PyList_Size(o);
             else {
                 PyErr_Format(PyExc_TypeError, "argument %d must be string or list of strings", i);
                 return -1;
             }
    }
   
    *argv = PyMem_New(char *,
                      element_count + 1);

    if (*argv == NULL)
        return -1;

    argv_count = 0;
    for (i = 0; i < args_count; i++) {
        o = PyTuple_GET_ITEM(args, i);
        if (PyString_Check(o)) {
            argv_count++;
            (*argv)[argv_count] = PyString_AS_STRING(o);
        } else if (PyList_CheckExact(o))
                   for (j = 0; j < PyList_Size(o); j++) {
                       lo = PyList_GetItem(o, j);
                       if (PyString_Check(lo)) {
                           argv_count++;
                           (*argv)[argv_count] = PyString_AS_STRING(lo);
                       } else {
                             PyMem_Del(*argv);
                             PyErr_Format(PyExc_TypeError, "element %d in argument %d must be string", j, i);
                             return -1;
                       }
                   }
               else {
                   PyMem_Del(*argv);
                   PyErr_Format(PyExc_TypeError, "argument %d must be string or list of strings", i);
                   return -1;
               }
    }

    (*argv)[0] = command;
    *argc = element_count + 1;

    /* reset getopt state */
    opterr = optind = 0;

    return 0;
}

static void destroy_args(
    char ***argv)
{
    PyMem_Del(*argv);
    *argv = NULL;
}

static char PyRRD_create__doc__[] =
    "create(args..): Set up a new Round Robin Database\n\
    create filename [--start|-b start time] \
[--step|-s step] [DS:ds-name:DST:heartbeat:min:max] \
[RRA:CF:xff:steps:rows]";

static PyObject *PyRRD_create(
    PyObject UNUSED(*self),
    PyObject * args)
{
    PyObject *r;
    char    **argv;
    int       argc;

    if (create_args("create", args, &argc, &argv) < 0)
        return NULL;

    if (rrd_create(argc, argv) == -1) {
        PyErr_SetString(ErrorObject, rrd_get_error());
        rrd_clear_error();
        r = NULL;
    } else {
        Py_INCREF(Py_None);
        r = Py_None;
    }

    destroy_args(&argv);
    return r;
}

static char PyRRD_update__doc__[] =
    "update(args..): Store a new set of values into the rrd\n"
    "    update filename [--template|-t ds-name[:ds-name]...] "
    "N|timestamp:value[:value...] [timestamp:value[:value...] ...]";

static PyObject *PyRRD_update(
    PyObject UNUSED(*self),
    PyObject * args)
{
    PyObject *r;
    char    **argv;
    int       argc;

    if (create_args("update", args, &argc, &argv) < 0)
        return NULL;

    if (rrd_update(argc, argv) == -1) {
        PyErr_SetString(ErrorObject, rrd_get_error());
        rrd_clear_error();
        r = NULL;
    } else {
        Py_INCREF(Py_None);
        r = Py_None;
    }

    destroy_args(&argv);
    return r;
}

static char PyRRD_fetch__doc__[] =
    "fetch(args..): fetch data from an rrd.\n"
    "    fetch filename CF [--resolution|-r resolution] "
    "[--start|-s start] [--end|-e end]";

static PyObject *PyRRD_fetch(
    PyObject UNUSED(*self),
    PyObject * args)
{
    PyObject *r;
    rrd_value_t *data, *datai;
    unsigned long step, ds_cnt;
    time_t    start, end;
    int       argc;
    char    **argv, **ds_namv;

    if (create_args("fetch", args, &argc, &argv) < 0)
        return NULL;

    if (rrd_fetch(argc, argv, &start, &end, &step,
                  &ds_cnt, &ds_namv, &data) == -1) {
        PyErr_SetString(ErrorObject, rrd_get_error());
        rrd_clear_error();
        r = NULL;
    } else {
        /* Return :
           ((start, end, step), (name1, name2, ...), [(data1, data2, ..), ...]) */
        PyObject *range_tup, *dsnam_tup, *data_list, *t;
        unsigned long i, j, row;
        rrd_value_t dv;

        row = (end - start) / step;

        r = PyTuple_New(3);
        range_tup = PyTuple_New(3);
        dsnam_tup = PyTuple_New(ds_cnt);
        data_list = PyList_New(row);
        PyTuple_SET_ITEM(r, 0, range_tup);
        PyTuple_SET_ITEM(r, 1, dsnam_tup);
        PyTuple_SET_ITEM(r, 2, data_list);

        datai = data;

        PyTuple_SET_ITEM(range_tup, 0, PyInt_FromLong((long) start));
        PyTuple_SET_ITEM(range_tup, 1, PyInt_FromLong((long) end));
        PyTuple_SET_ITEM(range_tup, 2, PyInt_FromLong((long) step));

        for (i = 0; i < ds_cnt; i++)
            PyTuple_SET_ITEM(dsnam_tup, i, PyString_FromString(ds_namv[i]));

        for (i = 0; i < row; i++) {
            t = PyTuple_New(ds_cnt);
            PyList_SET_ITEM(data_list, i, t);

            for (j = 0; j < ds_cnt; j++) {
                dv = *(datai++);
                if (isnan(dv)) {
                    PyTuple_SET_ITEM(t, j, Py_None);
                    Py_INCREF(Py_None);
                } else {
                    PyTuple_SET_ITEM(t, j, PyFloat_FromDouble((double) dv));
                }
            }
        }

        for (i = 0; i < ds_cnt; i++)
            rrd_freemem(ds_namv[i]);
        rrd_freemem(ds_namv);   /* rrdtool don't use PyMem_Malloc :) */
        rrd_freemem(data);
    }

    destroy_args(&argv);
    return r;
}

static char PyRRD_graph__doc__[] =
    "graph(args..): Create a graph based on data from one or several RRD\n"
    "    graph filename [-s|--start seconds] "
    "[-e|--end seconds] [-x|--x-grid x-axis grid and label] "
    "[-y|--y-grid y-axis grid and label] [--alt-y-grid] [--alt-y-mrtg] "
    "[--alt-autoscale] [--alt-autoscale-max] [--units-exponent] value "
    "[-v|--vertical-label text] [-w|--width pixels] [-h|--height pixels] "
    "[-i|--interlaced] "
    "[-f|--imginfo formatstring] [-a|--imgformat GIF|PNG|GD] "
    "[-B|--background value] [-O|--overlay value] "
    "[-U|--unit value] [-z|--lazy] [-o|--logarithmic] "
    "[-u|--upper-limit value] [-l|--lower-limit value] "
    "[-g|--no-legend] [-r|--rigid] [--step value] "
    "[-b|--base value] [-c|--color COLORTAG#rrggbb] "
    "[-t|--title title] [DEF:vname=rrd:ds-name:CF] "
    "[CDEF:vname=rpn-expression] [PRINT:vname:CF:format] "
    "[GPRINT:vname:CF:format] [COMMENT:text] "
    "[HRULE:value#rrggbb[:legend]] [VRULE:time#rrggbb[:legend]] "
    "[LINE{1|2|3}:vname[#rrggbb[:legend]]] "
    "[AREA:vname[#rrggbb[:legend]]] " "[STACK:vname[#rrggbb[:legend]]]";

static PyObject *PyRRD_graph(
    PyObject UNUSED(*self),
    PyObject * args)
{
    PyObject *r;
    char    **argv, **calcpr;
    int       argc, xsize, ysize, i;
    double    ymin, ymax;

    if (create_args("graph", args, &argc, &argv) < 0)
        return NULL;

    if (rrd_graph(argc, argv, &calcpr, &xsize, &ysize, NULL, &ymin, &ymax) ==
        -1) {
        PyErr_SetString(ErrorObject, rrd_get_error());
        rrd_clear_error();
        r = NULL;
    } else {
        r = PyTuple_New(3);

        PyTuple_SET_ITEM(r, 0, PyInt_FromLong((long) xsize));
        PyTuple_SET_ITEM(r, 1, PyInt_FromLong((long) ysize));

        if (calcpr) {
            PyObject *e, *t;

            e = PyList_New(0);
            PyTuple_SET_ITEM(r, 2, e);

            for (i = 0; calcpr[i]; i++) {
                t = PyString_FromString(calcpr[i]);
                PyList_Append(e, t);
                Py_DECREF(t);
                rrd_freemem(calcpr[i]);
            }
            rrd_freemem(calcpr);
        } else {
            Py_INCREF(Py_None);
            PyTuple_SET_ITEM(r, 2, Py_None);
        }
    }

    destroy_args(&argv);
    return r;
}

static char PyRRD_tune__doc__[] =
    "tune(args...): Modify some basic properties of a Round Robin Database\n"
    "    tune filename [--heartbeat|-h ds-name:heartbeat] "
    "[--minimum|-i ds-name:min] [--maximum|-a ds-name:max] "
    "[--data-source-type|-d ds-name:DST] [--data-source-rename|-r old-name:new-name]";

static PyObject *PyRRD_tune(
    PyObject UNUSED(*self),
    PyObject * args)
{
    PyObject *r;
    char    **argv;
    int       argc;

    if (create_args("tune", args, &argc, &argv) < 0)
        return NULL;

    if (rrd_tune(argc, argv) == -1) {
        PyErr_SetString(ErrorObject, rrd_get_error());
        rrd_clear_error();
        r = NULL;
    } else {
        Py_INCREF(Py_None);
        r = Py_None;
    }

    destroy_args(&argv);
    return r;
}

static char PyRRD_first__doc__[] =
    "first(filename): Return the timestamp of the first data sample in an RRD";

static PyObject *PyRRD_first(
    PyObject UNUSED(*self),
    PyObject * args)
{
    PyObject *r;
    int       argc, ts;
    char    **argv;

    if (create_args("first", args, &argc, &argv) < 0)
        return NULL;

    if ((ts = rrd_first(argc, argv)) == -1) {
        PyErr_SetString(ErrorObject, rrd_get_error());
        rrd_clear_error();
        r = NULL;
    } else
        r = PyInt_FromLong((long) ts);

    destroy_args(&argv);
    return r;
}

static char PyRRD_last__doc__[] =
    "last(filename): Return the timestamp of the last data sample in an RRD";

static PyObject *PyRRD_last(
    PyObject UNUSED(*self),
    PyObject * args)
{
    PyObject *r;
    int       argc, ts;
    char    **argv;

    if (create_args("last", args, &argc, &argv) < 0)
        return NULL;

    if ((ts = rrd_last(argc, argv)) == -1) {
        PyErr_SetString(ErrorObject, rrd_get_error());
        rrd_clear_error();
        r = NULL;
    } else
        r = PyInt_FromLong((long) ts);

    destroy_args(&argv);
    return r;
}

static char PyRRD_resize__doc__[] =
    "resize(args...): alters the size of an RRA.\n"
    "    resize filename rra-num GROW|SHRINK rows";

static PyObject *PyRRD_resize(
    PyObject UNUSED(*self),
    PyObject * args)
{
    PyObject *r;
    char    **argv;
    int       argc, ts;

    if (create_args("resize", args, &argc, &argv) < 0)
        return NULL;

    if ((ts = rrd_resize(argc, argv)) == -1) {
        PyErr_SetString(ErrorObject, rrd_get_error());
        rrd_clear_error();
        r = NULL;
    } else {
        Py_INCREF(Py_None);
        r = Py_None;
    }

    destroy_args(&argv);
    return r;
}

static PyObject *PyDict_FromInfo(
    rrd_info_t * data)
{
    PyObject *r;

    r = PyDict_New();
    while (data) {
        PyObject *val = NULL;

        switch (data->type) {
        case RD_I_VAL:
            val = isnan(data->value.u_val)
                ? (Py_INCREF(Py_None), Py_None)
                : PyFloat_FromDouble(data->value.u_val);
            break;
        case RD_I_CNT:
            val = PyLong_FromUnsignedLong(data->value.u_cnt);
            break;
        case RD_I_INT:
            val = PyLong_FromLong(data->value.u_int);
            break;
        case RD_I_STR:
            val = PyString_FromString(data->value.u_str);
            break;
        case RD_I_BLO:
            val =
                PyString_FromStringAndSize((char *) data->value.u_blo.ptr,
                                           data->value.u_blo.size);
            break;
        }
        if (val) {
            PyDict_SetItemString(r, data->key, val);
            Py_DECREF(val);
        }
        data = data->next;
    }
    return r;
}

static char PyRRD_info__doc__[] =
    "info(filename): extract header information from an rrd";

static PyObject *PyRRD_info(
    PyObject UNUSED(*self),
    PyObject * args)
{
    PyObject *r;
    int       argc;
    char    **argv;
    rrd_info_t *data;

    if (create_args("info", args, &argc, &argv) < 0)
        return NULL;

    if ((data = rrd_info(argc, argv)) == NULL) {
        PyErr_SetString(ErrorObject, rrd_get_error());
        rrd_clear_error();
        r = NULL;
    } else {
        r = PyDict_FromInfo(data);
        rrd_info_free(data);
    }

    destroy_args(&argv);
    return r;
}

static char PyRRD_graphv__doc__[] =
    "graphv is called in the same manner as graph";

static PyObject *PyRRD_graphv(
    PyObject UNUSED(*self),
    PyObject * args)
{
    PyObject *r;
    int       argc;
    char    **argv;
    rrd_info_t *data;

    if (create_args("graphv", args, &argc, &argv) < 0)
        return NULL;

    if ((data = rrd_graph_v(argc, argv)) == NULL) {
        PyErr_SetString(ErrorObject, rrd_get_error());
        rrd_clear_error();
        r = NULL;
    } else {
        r = PyDict_FromInfo(data);
        rrd_info_free(data);
    }

    destroy_args(&argv);
    return r;
}

static char PyRRD_updatev__doc__[] =
    "updatev is called in the same manner as update";

static PyObject *PyRRD_updatev(
    PyObject UNUSED(*self),
    PyObject * args)
{
    PyObject *r;
    int       argc;
    char    **argv;
    rrd_info_t *data;

    if (create_args("updatev", args, &argc, &argv) < 0)
        return NULL;

    if ((data = rrd_update_v(argc, argv)) == NULL) {
        PyErr_SetString(ErrorObject, rrd_get_error());
        rrd_clear_error();
        r = NULL;
    } else {
        r = PyDict_FromInfo(data);
        rrd_info_free(data);
    }

    destroy_args(&argv);
    return r;
}

static char PyRRD_flushcached__doc__[] =
  "flush(args..): flush RRD files from memory\n"
  "   flush [--daemon address] file [file ...]";

static PyObject *PyRRD_flushcached(
    PyObject UNUSED(*self),
    PyObject * args)
{
    PyObject *r;
    int       argc;
    char    **argv;

    if (create_args("flushcached", args, &argc, &argv) < 0)
        return NULL;

    if (rrd_flushcached(argc, argv) != 0) {
        PyErr_SetString(ErrorObject, rrd_get_error());
        rrd_clear_error();
        r = NULL;
    } else {
        Py_INCREF(Py_None);
        r = Py_None;
    }

    destroy_args(&argv);
    return r;
}

static char PyRRD_xport__doc__[] =
    "xport(args..): dictionary representation of data stored in RRDs\n"
    "    [-s|--start seconds] [-e|--end seconds] [-m|--maxrows rows]"
    "[--step value] [--daemon address] [DEF:vname=rrd:ds-name:CF]"
    "[CDEF:vname=rpn-expression] [XPORT:vname[:legend]]";


static PyObject *PyRRD_xport(
    PyObject UNUSED(*self),
    PyObject * args)
{
    PyObject *r;
    int       argc, xsize;
    char    **argv, **legend_v;
    time_t    start, end;
    unsigned long step, col_cnt;
    rrd_value_t *data, *datai;

    if (create_args("xport", args, &argc, &argv) < 0)
        return NULL;

    if (rrd_xport(argc, argv, &xsize, &start, &end,
                  &step, &col_cnt, &legend_v, &data) == -1) {
        PyErr_SetString(ErrorObject, rrd_get_error());
        rrd_clear_error();
        r = NULL;
    } else {
        PyObject *meta_dict, *data_list, *legend_list, *t;
        unsigned long i, j;
        rrd_value_t dv;

        unsigned long row_cnt = ((end - start) / step) + 1;

        r = PyDict_New();
        meta_dict = PyDict_New();
        legend_list = PyList_New(col_cnt);
        data_list = PyList_New(row_cnt);
        PyDict_SetItem(r, PyString_FromString("meta"), meta_dict);
        PyDict_SetItem(r, PyString_FromString("data"), data_list);

        datai = data;

        PyDict_SetItem(meta_dict, PyString_FromString("start"), PyInt_FromLong((long) start));
        PyDict_SetItem(meta_dict, PyString_FromString("end"), PyInt_FromLong((long) end));
        PyDict_SetItem(meta_dict, PyString_FromString("step"), PyInt_FromLong((long) step));
        PyDict_SetItem(meta_dict, PyString_FromString("rows"), PyInt_FromLong((long) row_cnt));
        PyDict_SetItem(meta_dict, PyString_FromString("columns"), PyInt_FromLong((long) col_cnt));
        PyDict_SetItem(meta_dict, PyString_FromString("legend"), legend_list);

        for (i = 0; i < col_cnt; i++) {
            PyList_SET_ITEM(legend_list, i, PyString_FromString(legend_v[i]));
        }

        for (i = 0; i < row_cnt; i++) {
            t = PyTuple_New(col_cnt);
            PyList_SET_ITEM(data_list, i, t);

            for (j = 0; j < col_cnt; j++) {
                dv = *(datai++);
                if (isnan(dv)) {
                    PyTuple_SET_ITEM(t, j, Py_None);
                    Py_INCREF(Py_None);
                } else {
                    PyTuple_SET_ITEM(t, j, PyFloat_FromDouble((double) dv));
                }
            }
        }

        for (i = 0; i < col_cnt; i++) {
            rrd_freemem(legend_v[i]);
        }
        rrd_freemem(legend_v);
        rrd_freemem(data);
    }
    destroy_args(&argv);
    return r;
}

/* List of methods defined in the module */
#define meth(name, func, doc) {name, (PyCFunction)func, METH_VARARGS, doc}

static PyMethodDef _rrdtool_methods[] = {
    meth("create", PyRRD_create, PyRRD_create__doc__),
    meth("update", PyRRD_update, PyRRD_update__doc__),
    meth("fetch", PyRRD_fetch, PyRRD_fetch__doc__),
    meth("graph", PyRRD_graph, PyRRD_graph__doc__),
    meth("tune", PyRRD_tune, PyRRD_tune__doc__),
    meth("first", PyRRD_first, PyRRD_first__doc__),
    meth("last", PyRRD_last, PyRRD_last__doc__),
    meth("resize", PyRRD_resize, PyRRD_resize__doc__),
    meth("info", PyRRD_info, PyRRD_info__doc__),
    meth("graphv", PyRRD_graphv, PyRRD_graphv__doc__),
    meth("updatev", PyRRD_updatev, PyRRD_updatev__doc__),
    meth("flushcached", PyRRD_flushcached, PyRRD_flushcached__doc__),
    meth("xport", PyRRD_xport, PyRRD_xport__doc__),
    {NULL, NULL, 0, NULL}
};

#define SET_INTCONSTANT(dict, value) \
            t = PyInt_FromLong((long)value); \
            PyDict_SetItemString(dict, #value, t); \
            Py_DECREF(t);
#define SET_STRCONSTANT(dict, value) \
            t = PyString_FromString(value); \
            PyDict_SetItemString(dict, #value, t); \
            Py_DECREF(t);

/* Initialization function for the module */
void initrrdtool(
    void)
{
    PyObject *m, *d, *t;

    /* Create the module and add the functions */
    m = Py_InitModule("rrdtool", _rrdtool_methods);

    /* Add some symbolic constants to the module */
    d = PyModule_GetDict(m);

    SET_STRCONSTANT(d, __version__);
    ErrorObject = PyErr_NewException("rrdtool.error", NULL, NULL);
    PyDict_SetItemString(d, "error", ErrorObject);

    /* Check for errors */
    if (PyErr_Occurred())
        Py_FatalError("can't initialize the rrdtool module");
}

/*
 * $Id: _rrdtoolmodule.c,v 1.14 2003/02/22 07:41:19 perky Exp $
 * ex: ts=8 sts=4 et
 */
