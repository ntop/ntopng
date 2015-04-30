/* $Id$
 * Substantial penalty for early withdrawal.
 */

#include <unistd.h>
#include <ruby.h>
#include <math.h>
#include "../../src/rrd_tool.h"

typedef struct string_arr_t {
    int       len;
    char    **strings;
} string_arr;

VALUE     mRRD;
VALUE     rb_eRRDError;

typedef int (
    *RRDFUNC) (
    int argc,
    char **argv);

typedef rrd_info_t *(
    *RRDINFOFUNC) (
    int argc,
    char **argv);

#define RRD_CHECK_ERROR  \
    if (rrd_test_error()) \
      rb_raise(rb_eRRDError, "%s", rrd_get_error()); \
    rrd_clear_error();

string_arr string_arr_new(
    VALUE rb_strings)
{
    string_arr a;
    char      buf[64];
    int       i;

    Check_Type(rb_strings, T_ARRAY);
    a.len = RARRAY_LEN(rb_strings) + 1;

    a.strings = malloc(a.len * sizeof(char *));
    a.strings[0] = "dummy"; /* first element is a dummy element */

    for (i = 0; i < a.len - 1; i++) {
        VALUE     v = rb_ary_entry(rb_strings, i);

        switch (TYPE(v)) {
        case T_STRING:
            a.strings[i + 1] = strdup(StringValuePtr(v));
            break;
        case T_FIXNUM:
            snprintf(buf, 63, "%ld", (long)FIX2INT(v));
            a.strings[i + 1] = strdup(buf);
            break;
        default:
            rb_raise(rb_eTypeError,
                     "invalid argument - %s, expected T_STRING or T_FIXNUM on index %ld",
                     rb_class2name(CLASS_OF(v)), (long)i);
            break;
        }
    }

    return a;
}

void string_arr_delete(
    string_arr a)
{
    int       i;

    /* skip dummy first entry */
    for (i = 1; i < a.len; i++) {
        free(a.strings[i]);
    }

    free(a.strings);
}

void reset_rrd_state(
    )
{
    optind = 0;
    opterr = 0;
    rrd_clear_error();
}

/* Simple Calls */

VALUE rrd_call(
    RRDFUNC func,
    VALUE args)
{
    string_arr a;

    a = string_arr_new(args);
    reset_rrd_state();
    func(a.len, a.strings);
    string_arr_delete(a);

    RRD_CHECK_ERROR return Qnil;
}

VALUE rb_rrd_create(
    VALUE self,
    VALUE args)
{
    return rrd_call(rrd_create, args);
}

VALUE rb_rrd_dump(
    VALUE self,
    VALUE args)
{
    return rrd_call(rrd_dump, args);
}

VALUE rb_rrd_resize(
    VALUE self,
    VALUE args)
{
    return rrd_call(rrd_resize, args);
}

VALUE rb_rrd_restore(
    VALUE self,
    VALUE args)
{
    return rrd_call(rrd_restore, args);
}

VALUE rb_rrd_tune(
    VALUE self,
    VALUE args)
{
    return rrd_call(rrd_tune, args);
}

VALUE rb_rrd_update(
    VALUE self,
    VALUE args)
{
    return rrd_call(rrd_update, args);
}

VALUE rb_rrd_flushcached(
    VALUE self,
    VALUE args)
{
    return rrd_call(rrd_flushcached, args);
}


/* Calls Returning Data via the Info Interface */

VALUE rb_rrd_infocall(
    RRDINFOFUNC func,
    VALUE args)
{
    string_arr a;
    rrd_info_t *p, *data;
    VALUE     result;

    a = string_arr_new(args);
    reset_rrd_state();
    data = func(a.len, a.strings);
    string_arr_delete(a);

    RRD_CHECK_ERROR result = rb_hash_new();

    p = data;
    while (data) {
        VALUE     key = rb_str_new2(data->key);

        switch (data->type) {
        case RD_I_VAL:
            if (isnan(data->value.u_val)) {
                rb_hash_aset(result, key, Qnil);
            } else {
                rb_hash_aset(result, key, rb_float_new(data->value.u_val));
            }
            break;
        case RD_I_CNT:
            rb_hash_aset(result, key, INT2FIX(data->value.u_cnt));
            break;
        case RD_I_STR:
            rb_hash_aset(result, key, rb_str_new2(data->value.u_str));
            break;
        case RD_I_INT:
            rb_hash_aset(result, key, INT2FIX(data->value.u_int));
            break;
        case RD_I_BLO:
            rb_hash_aset(result, key,
                         rb_str_new((char *)data->value.u_blo.ptr,
                                    data->value.u_blo.size));
            break;
        }
        data = data->next;
    }
    rrd_info_free(p);
    return result;
}

VALUE rb_rrd_info(
    VALUE self,
    VALUE args)
{
    return rb_rrd_infocall(rrd_info, args);
}

VALUE rb_rrd_updatev(
    VALUE self,
    VALUE args)
{
    return rb_rrd_infocall(rrd_update_v, args);
}

VALUE rb_rrd_graphv(
    VALUE self,
    VALUE args)
{
    return rb_rrd_infocall(rrd_graph_v, args);
}


/* Other Calls */

VALUE rb_rrd_fetch(
    VALUE self,
    VALUE args)
{
    string_arr a;
    unsigned long i, j, k, step, ds_cnt;
    rrd_value_t *raw_data;
    char    **raw_names;
    VALUE     data, names, result;
    time_t    start, end;

    a = string_arr_new(args);
    reset_rrd_state();
    rrd_fetch(a.len, a.strings, &start, &end, &step, &ds_cnt, &raw_names,
              &raw_data);
    string_arr_delete(a);

    RRD_CHECK_ERROR names = rb_ary_new();

    for (i = 0; i < ds_cnt; i++) {
        rb_ary_push(names, rb_str_new2(raw_names[i]));
        rrd_freemem(raw_names[i]);
    }
    rrd_freemem(raw_names);

    k = 0;
    data = rb_ary_new();
    for (i = start; i <= end; i += step) {
        VALUE     line = rb_ary_new2(ds_cnt);

        for (j = 0; j < ds_cnt; j++) {
            rb_ary_store(line, j, rb_float_new(raw_data[k]));
            k++;
        }
        rb_ary_push(data, line);
    }
    rrd_freemem(raw_data);

    result = rb_ary_new2(5);
    rb_ary_store(result, 0, INT2NUM(start));
    rb_ary_store(result, 1, INT2NUM(end));
    rb_ary_store(result, 2, names);
    rb_ary_store(result, 3, data);
    rb_ary_store(result, 4, INT2FIX(step));
    return result;
}

VALUE rb_rrd_graph(
    VALUE self,
    VALUE args)
{
    string_arr a;
    char    **calcpr, **p;
    VALUE     result, print_results;
    int       xsize, ysize;
    double    ymin, ymax;

    a = string_arr_new(args);
    reset_rrd_state();
    rrd_graph(a.len, a.strings, &calcpr, &xsize, &ysize, NULL, &ymin, &ymax);
    string_arr_delete(a);

    RRD_CHECK_ERROR result = rb_ary_new2(3);

    print_results = rb_ary_new();
    p = calcpr;
    for (p = calcpr; p && *p; p++) {
        rb_ary_push(print_results, rb_str_new2(*p));
        rrd_freemem(*p);
    }
    rrd_freemem(calcpr);
    rb_ary_store(result, 0, print_results);
    rb_ary_store(result, 1, INT2FIX(xsize));
    rb_ary_store(result, 2, INT2FIX(ysize));
    return result;
}


VALUE rb_rrd_last(
    VALUE self,
    VALUE args)
{
    string_arr a;
    time_t    last;

    a = string_arr_new(args);
    reset_rrd_state();
    last = rrd_last(a.len, a.strings);
    string_arr_delete(a);

    RRD_CHECK_ERROR
        return rb_funcall(rb_cTime, rb_intern("at"), 1, UINT2NUM(last));
}

VALUE rb_rrd_xport(
    VALUE self,
    VALUE args)
{
    string_arr a;
    unsigned long i, j, k, step, col_cnt;
    int xxsize;
    rrd_value_t *data;
    char **legend_v;
    VALUE legend, result, rdata;
    time_t start, end;

    a = string_arr_new(args);
    reset_rrd_state();
    rrd_xport(a.len, a.strings, &xxsize, &start, &end, &step, &col_cnt, &legend_v, &data);
    string_arr_delete(a);

    RRD_CHECK_ERROR;
            
    legend = rb_ary_new();
    for (i = 0; i < col_cnt; i++) {
        rb_ary_push(legend, rb_str_new2(legend_v[i]));
        free(legend_v[i]);
    }
    free(legend_v);

    k = 0;
    rdata = rb_ary_new();
    for (i = start; i <= end; i += step) {
        VALUE line = rb_ary_new2(col_cnt);
        for (j = 0; j < col_cnt; j++) {
            rb_ary_store(line, j, rb_float_new(data[k]));
            k++;
        }
        rb_ary_push(rdata, line);
    }
    free(data);

    result = rb_ary_new2(6);
    rb_ary_store(result, 0, INT2FIX(start));
    rb_ary_store(result, 1, INT2FIX(end));
    rb_ary_store(result, 2, INT2FIX(step));
    rb_ary_store(result, 3, INT2FIX(col_cnt));
    rb_ary_store(result, 4, legend);
    rb_ary_store(result, 5, rdata);
    return result;
}

void Init_RRD(
    )
{
    mRRD = rb_define_module("RRD");
    rb_eRRDError = rb_define_class("RRDError", rb_eStandardError);

    rb_define_module_function(mRRD, "create", rb_rrd_create, -2);
    rb_define_module_function(mRRD, "dump", rb_rrd_dump, -2);
    rb_define_module_function(mRRD, "fetch", rb_rrd_fetch, -2);
    rb_define_module_function(mRRD, "graph", rb_rrd_graph, -2);
    rb_define_module_function(mRRD, "last", rb_rrd_last, -2);
    rb_define_module_function(mRRD, "resize", rb_rrd_resize, -2);
    rb_define_module_function(mRRD, "restore", rb_rrd_restore, -2);
    rb_define_module_function(mRRD, "tune", rb_rrd_tune, -2);
    rb_define_module_function(mRRD, "update", rb_rrd_update, -2);
    rb_define_module_function(mRRD, "flushcached", rb_rrd_flushcached, -2);
    rb_define_module_function(mRRD, "info", rb_rrd_info, -2);
    rb_define_module_function(mRRD, "updatev", rb_rrd_updatev, -2);
    rb_define_module_function(mRRD, "graphv", rb_rrd_graphv, -2);
    rb_define_module_function(mRRD, "xport", rb_rrd_xport, -2);
}
