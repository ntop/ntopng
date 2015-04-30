/*
 * Lua bindings for RRDTool
 *
 * This software is licensed to the public under the Free Software
 * Foundation's GNU GPL, version 2 or later. You may obtain a copy
 * of the GPL by visiting the Free Software Foundations web site at
 * www.fsf.org, and a copy is included in this distribution.
 *
 * Copyright 2008 Fidelis Assis, all rights reserved.
 *
 */

#include <ctype.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <math.h>
#include <errno.h>
#include <dirent.h>
#include <inttypes.h>

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "../../src/rrd_tool.h"

#ifdef LUA50
#ifdef HAVE_COMPAT51
#include "compat-5.1.h"
#else
#include "compat-5.1r5/compat-5.1.h"
#endif
#endif

extern void rrd_freemem(void *mem);

extern int luaopen_rrd (lua_State * L);
typedef int (*RRD_FUNCTION)(int, char **);
typedef rrd_info_t *(RRD_FUNCTION_V)(int, char **);

/**********************************************************/

static void reset_rrd_state(void)
{
    optind = 0;
    opterr = 0;
    rrd_clear_error();
}

static char **make_argv(const char *cmd, lua_State * L)
{
  char **argv;
  int i;
  int argc = lua_gettop(L) + 1;

  if (!(argv = calloc(argc, sizeof (char *)))) 
    /* raise an error and never return */
    luaL_error(L, "Can't allocate memory for arguments array", cmd);

  /* fprintf(stderr, "Args:\n"); */
  argv[0] = (char *) cmd; /* Dummy arg. Cast to (char *) because rrd */
                          /* functions don't expect (const * char)   */
  /* fprintf(stderr, "%s\n", argv[0]); */
  for (i=1; i<argc; i++) {
    /* accepts string or number */
    if (lua_isstring(L, i) || lua_isnumber(L, i)) {
      if (!(argv[i] = lua_tostring (L, i))) {
        /* raise an error and never return */
        luaL_error(L, "%s - error duplicating string area for arg #%d",
                   cmd, i);
      }
    } else {
      /* raise an error and never return */
      luaL_error(L, "Invalid arg #%d to %s: args must be strings or numbers",
                 i, cmd);
    }
    /* fprintf(stderr, "%s\n", argv[i]); */
  }
  return argv;
}

static int
rrd_common_call (lua_State *L, const char *cmd, RRD_FUNCTION rrd_function)
{
  char **argv;
  int argc = lua_gettop(L) + 1;

  argv = make_argv(cmd, L);
  reset_rrd_state();
  rrd_function(argc, argv);
  free(argv);
  if (rrd_test_error()) luaL_error(L, rrd_get_error());
  return 0;
}

#if defined(DINF)
static int
lua_rrd_infocall(lua_State *L, const char *cmd, RRD_FUNCTION_V rrd_function)
{
  char **argv;
  rrd_info_t *p, *data;
  int argc = lua_gettop(L) + 1;

  argv = make_argv(cmd, L);
  reset_rrd_state();
  data = rrd_function(argc, argv);
  free(argv);
  if (rrd_test_error()) luaL_error(L, rrd_get_error());

  lua_newtable(L);
  p = data;
  while (data) {
    lua_pushstring(L, data->key);
    switch (data->type) {
      case RD_I_CNT:
        if (isnan(data->value.u_val)) {
          lua_pushnil(L); 
        } else {
          lua_pushnumber(L, (lua_Number) data->value.u_val);
        }
        lua_rawset(L, -3);
        break;
      case RD_I_VAL:
        lua_pushnumber(L, (lua_Number) data->value.u_val);
        lua_rawset(L, -3);
        break;
      case RD_I_STR:
        lua_pushstring(L, data->value.u_str);
        lua_rawset(L, -3);
        break;
      case RD_I_BLO:
        lua_pushlstring(L, (const char *) data->value.u_blo.ptr,
                        data->value.u_blo.size);
        lua_rawset(L, -3);
        break;
      default:
        rrd_info_free(p); 
        return luaL_error(L, "Wrong data type to info call");
        break;
    }
    data = data->next;
  }
  rrd_info_free(p); 
  return 1;
}
#endif

/**********************************************************/

static int
lua_rrd_create (lua_State * L)
{
  rrd_common_call(L, "create", rrd_create);
  return 0;
}

static int
lua_rrd_dump (lua_State * L)
{
  rrd_common_call(L, "dump", rrd_dump);
  return 0;
}

static int
lua_rrd_resize (lua_State * L)
{
  rrd_common_call(L, "resize", rrd_resize);
  return 0;
}

static int
lua_rrd_restore (lua_State * L)
{
  rrd_common_call(L, "restore", rrd_restore);
  return 0;
}

static int
lua_rrd_tune (lua_State * L)
{
  rrd_common_call(L, "tune", rrd_tune);
  return 0;
}

static int
lua_rrd_update (lua_State * L)
{
  rrd_common_call(L, "update", rrd_update);
  return 0;
}

static int
lua_rrd_fetch (lua_State * L)
{
  int argc = lua_gettop(L) + 1;
  char **argv = make_argv("fetch", L);
  unsigned long i, j, step, ds_cnt;
  rrd_value_t *data, *p;
  char    **names;
  time_t  t, start, end;

  reset_rrd_state();
  rrd_fetch(argc, argv, &start, &end, &step, &ds_cnt, &names, &data);
  free(argv);
  if (rrd_test_error()) luaL_error(L, rrd_get_error());

  lua_pushnumber(L, (lua_Number) start);
  lua_pushnumber(L, (lua_Number) step);
  /* fprintf(stderr, "%lu, %lu, %lu, %lu\n", start, end, step, num_points); */

  /* create the ds names array */
  lua_newtable(L);
  for (i=0; i<ds_cnt; i++) {
    lua_pushstring(L, names[i]);
    lua_rawseti(L, -2, i+1);
    rrd_freemem(names[i]);
  }
  rrd_freemem(names);

  /* create the data points array */
  lua_newtable(L);
  p = data;
  for (t=start, i=0; t<end; t+=step, i++) {
    lua_newtable(L);
    for (j=0; j<ds_cnt; j++) {
      /*fprintf(stderr, "Point #%lu\n", j+1); */
      lua_pushnumber(L, (lua_Number) *p++);
      lua_rawseti(L, -2, j+1);
    }
    lua_rawseti(L, -2, i+1);
  }
  rrd_freemem(data);

  /* return the end as the last value */
  lua_pushnumber(L, (lua_Number) end);

  return 5;
}

static int
lua_rrd_first (lua_State * L)
{
  time_t first;
  int argc = lua_gettop(L) + 1;
  char **argv = make_argv("first", L);
  reset_rrd_state();
  first = rrd_first(argc, argv);
  free(argv);
  if (rrd_test_error()) luaL_error(L, rrd_get_error());
  lua_pushnumber(L, (lua_Number) first);
  return 1;
}

static int
lua_rrd_last (lua_State * L)
{
  time_t last;
  int argc = lua_gettop(L) + 1;
  char **argv = make_argv("last", L);
  reset_rrd_state();
  last = rrd_last(argc, argv);
  free(argv);
  if (rrd_test_error()) luaL_error(L, rrd_get_error());
  lua_pushnumber(L, (lua_Number) last);
  return 1;
}

static int
lua_rrd_graph (lua_State * L)
{
  int argc = lua_gettop(L) + 1;
  char **argv = make_argv("last", L);
  char **calcpr;
  int i, xsize, ysize;
  double ymin, ymax;

  reset_rrd_state();
  rrd_graph(argc, argv, &calcpr, &xsize, &ysize, NULL, &ymin, &ymax);
  free(argv);
  if (rrd_test_error()) luaL_error(L, rrd_get_error());
  lua_pushnumber(L, (lua_Number) xsize);
  lua_pushnumber(L, (lua_Number) ysize);
  lua_newtable(L);
  for (i = 0; calcpr && calcpr[i]; i++) {
      lua_pushstring(L, calcpr[i]);
      lua_rawseti(L, -2, i+1);
      rrd_freemem(calcpr[i]);
  }
  rrd_freemem(calcpr);
  return 3;
}

static int
lua_rrd_flushcached(lua_State *L)
{
  return rrd_common_call(L, "flushcached", rrd_flushcached);
}

#if defined(DINF)
static int
lua_rrd_info (lua_State * L)
{
  return lua_rrd_infocall(L, "info", rrd_info);
}

static int
lua_rrd_graphv (lua_State * L)
{
  return lua_rrd_infocall(L, "graphv", rrd_graph_v);
}

static int
lua_rrd_updatev (lua_State * L)
{
  return lua_rrd_infocall(L, "updatev", rrd_update_v);
}
#endif

/**********************************************************/

/*
** Assumes the table is on top of the stack.
*/
static void
set_info (lua_State * L)
{
  lua_pushliteral (L, "_COPYRIGHT");
  lua_pushliteral (L, "Copyright (C) 2008 Fidelis Assis");
  lua_settable (L, -3);
  lua_pushliteral (L, "_DESCRIPTION");
  lua_pushliteral (L, "RRD-lua is a Lua binding for RRDTool.");
  lua_settable (L, -3);
  lua_pushliteral (L, "_NAME");
  lua_pushliteral (L, "RRD-Lua");
  lua_settable (L, -3);
  lua_pushliteral (L, "_VERSION");
  lua_pushliteral (L, LIB_VERSION);
  lua_settable (L, -3);
}

/**********************************************************/

static const struct luaL_reg rrd[] = {
  {"create", lua_rrd_create},
  {"dump", lua_rrd_dump},
  {"fetch", lua_rrd_fetch},
  {"first", lua_rrd_first},
  {"graph", lua_rrd_graph},
  {"last", lua_rrd_last},
  {"resize", lua_rrd_resize},
  {"restore", lua_rrd_restore},
  {"tune", lua_rrd_tune},
  {"update", lua_rrd_update},
  {"flushcached", lua_rrd_flushcached},
#if defined(DINF)
  {"info", lua_rrd_info},
  {"updatev", lua_rrd_updatev},
  {"graphv", lua_rrd_graphv},
#endif
  {NULL, NULL}
};


/*
** Open RRD library
*/
int
luaopen_rrd (lua_State * L)
{
#if defined LUA50
  /* luaL_module is defined in compat-5.1.c */
  luaL_module (L, "rrd", rrd, 0);
#else
  luaL_register (L, "rrd", rrd);
#endif
  set_info (L);
  return 1;
}
