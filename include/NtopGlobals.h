/*
 *
 * (C) 2013-15 - ntop.org
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

#ifndef _NTOP_GLOBALS_H_
#define _NTOP_GLOBALS_H_

#include "ntop_includes.h"

class NtopGlobals {
  bool is_shutdown, do_decode_tunnels;
  time_t start_time;
  u_int ifMTU, snaplen;
  Trace *trace;
  u_int32_t detection_tick_resolution;
  Mutex *mutex;
  u_int16_t file_id;

 public:
  NtopGlobals();
  ~NtopGlobals();

  inline u_int getUptime()             { return((u_int)(time(NULL)-start_time+1)); };
  inline u_int getIfMTU()              { return(ifMTU);             };
  inline u_int getSnaplen()            { return(snaplen);           };
  inline Trace *getTrace()             { return(trace);             };
  inline bool  isShutdown()            { return(is_shutdown);       };
  inline bool  decode_tunnels()        { return(do_decode_tunnels); };
  inline void  shutdown()              { is_shutdown = true;        };
  inline u_int32_t get_detection_tick_resolution() { return(detection_tick_resolution); };
  char* get_temp_filename(char *buf, u_int buf_len);
};

#endif /* _NTOP_GLOBALS_H_ */
