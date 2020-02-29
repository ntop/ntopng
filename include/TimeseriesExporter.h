/*
 *
 * (C) 2020 - ntop.org
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

#ifndef _TS_EXPORTER_H_
#define _TS_EXPORTER_H_

#include "ntop_includes.h"

class TimeseriesExporter {
 private:
  static bool is_table_empty(lua_State *L, int index);
  static int line_protocol_concat_table_fields(lua_State *L, int index, char *buf, int buf_len,
					       int (*escape_fn)(char *outbuf, int outlen, const char *orig));
 protected:
  NetworkInterface *iface;

  static int escape_spaces(char *buf, int buf_len, const char *unescaped);

  public:
  TimeseriesExporter(NetworkInterface *_if);
  virtual ~TimeseriesExporter();

  static int line_protocol_write_line(lua_State* vm, char *dst_line, int dst_line_len,
				      int (*escape_fn)(char *outbuf, int outlen, const char *orig));

  virtual bool  enqueueData(lua_State* vm, bool do_lock = true) = 0;
  virtual char* dequeueData() = 0;
  virtual void flush() = 0;
};

#endif /* _TS_EXPORTER_H_ */
