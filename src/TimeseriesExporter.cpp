/*
 *
 * (C) 2018-21 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#include "ntop_includes.h"

/* ******************************************************* */

TimeseriesExporter::TimeseriesExporter(NetworkInterface *_if) {
  iface = _if;
}

/* ******************************************************* */

TimeseriesExporter::~TimeseriesExporter() {
}

/* ******************************************************* */

bool TimeseriesExporter::is_table_empty(lua_State *L, int index) {
  lua_pushnil(L);
  
  if(lua_next(L, index)) {
    lua_pop(L, 1);
    return(false);
  }

  return(true);
}

/* ******************************************************* */

/* NOTE: outbuf and unescaped buffers must not overlap.
   Need to escape spaces at least.

   See https://docs.influxdata.com/influxdb/v1.7/write_protocols/line_protocol_tutorial/#special-characters
*/
int TimeseriesExporter::escape_spaces(char *buf, int buf_len, const char *unescaped) {
  int cur_len = 0;

  while(*unescaped) {
    if(cur_len >= buf_len - 2)
      goto influx_escape_char_err;

    switch(*unescaped) {
    case ' ':
      *buf++ = '\\';
      cur_len++;
      /* No break */
    default:
      *buf++ = *unescaped++;
      cur_len++;
      break;
    }
  }

  *buf = '\0';
  return cur_len;

 influx_escape_char_err:
  *(buf - cur_len) = '\0';
  return -1;
}

/* ******************************************************* */

int TimeseriesExporter::line_protocol_concat_table_fields(lua_State *L, int index, char *buf, int buf_len,
							  int (*escape_fn)(char *outbuf, int outlen, const char *orig)) {
  bool first = true;
  char val_buf[128];
  int cur_buf_len = 0, n;
  bool write_ok;

  // table traversal from https://www.lua.org/ftp/refman-5.0.pdf
  lua_pushnil(L);

  while(lua_next(L, index) != 0) {
    write_ok = false;

    if(escape_fn)
      n = escape_fn(val_buf, sizeof(val_buf), lua_tostring(L, -1));
    else
      n = snprintf(val_buf, sizeof(val_buf), "%s", lua_tostring(L, -1));

    if(n > 0 && n < (int)sizeof(val_buf)) {
      n = snprintf(buf + cur_buf_len, buf_len - cur_buf_len,
		   "%s%s=%s", first ? "" : ",", lua_tostring(L, -2), val_buf);

      if(n > 0 && n < buf_len - cur_buf_len) {
	write_ok = true;
	cur_buf_len += n;
	if(first) first = false;
      }
    }

    lua_pop(L, 1);
    if(!write_ok)
      goto line_protocol_concat_table_fields_err;
  }

  return cur_buf_len;

 line_protocol_concat_table_fields_err:
  if(buf_len)
    buf[0] = '\0';

  return -1;
}

/* ******************************************************* */

int TimeseriesExporter::line_protocol_write_line(lua_State* vm,
						 char *dst_line,
						 int dst_line_len,
						 int (*escape_fn)(char *outbuf, int outlen, const char *orig)) {
  char *schema;
  time_t tstamp;
  int cur_line_len = 0, n;

  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return -1;
  schema = (char*)lua_tostring(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) return -1;
  tstamp = (time_t)lua_tonumber(vm, 2);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TTABLE) != CONST_LUA_OK)  return -1;
  if(ntop_lua_check(vm, __FUNCTION__, 4, LUA_TTABLE) != CONST_LUA_OK)  return -1;

  /* A line of the protocol is: "iface:traffic,ifid=0 bytes=0 1539358699\n" */

  /* measurement name (with a comma if no tags are found) */
  n = snprintf(dst_line, dst_line_len, is_table_empty(vm, 3) ? "%s" : "%s,", schema);
  if(n < 0 || n >= dst_line_len) goto line_protocol_write_line_err; else cur_line_len += n;

  /* tags */
  n = line_protocol_concat_table_fields(vm, 3, dst_line + cur_line_len, dst_line_len - cur_line_len, escape_fn); // tags
  if(n < 0 || n >= dst_line_len - cur_line_len) goto line_protocol_write_line_err; else cur_line_len += n;

  /* space to separate tags and metrics */
  n = snprintf(dst_line + cur_line_len, dst_line_len - cur_line_len, " ");
  if(n < 0 || n >= dst_line_len - cur_line_len) goto line_protocol_write_line_err; else cur_line_len += n;

  /* metrics */
  n = line_protocol_concat_table_fields(vm, 4, dst_line + cur_line_len, dst_line_len - cur_line_len, escape_fn); // metrics
  if(n < 0 || n >= dst_line_len - cur_line_len) goto line_protocol_write_line_err; else cur_line_len += n;

  /* timestamp (in seconds, not nanoseconds) and a \n */
  n = snprintf(dst_line + cur_line_len, dst_line_len - cur_line_len, " %lu\n", tstamp);
  if(n < 0 || n >= dst_line_len - cur_line_len) goto line_protocol_write_line_err; else cur_line_len += n;

  return cur_line_len;

 line_protocol_write_line_err:
  if(dst_line_len)
    dst_line[0] = '\0';

  return -1;
}
