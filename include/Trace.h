/*
 *
 * (C) 2013-18 - ntop.org
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

#ifndef _TRACE_H_
#define _TRACE_H_

#include "ntop_includes.h"

#define TRACE_LEVEL_ERROR     0
#define TRACE_LEVEL_WARNING   1
#define TRACE_LEVEL_NORMAL    2
#define TRACE_LEVEL_INFO      3
#define TRACE_LEVEL_DEBUG     6
#define TRACE_LEVEL_TRACE     9

#define TRACE_ERROR     TRACE_LEVEL_ERROR, __FILE__, __LINE__
#define TRACE_WARNING   TRACE_LEVEL_WARNING, __FILE__, __LINE__
#define TRACE_NORMAL    TRACE_LEVEL_NORMAL, __FILE__, __LINE__
#define TRACE_INFO      TRACE_LEVEL_INFO, __FILE__, __LINE__
#define TRACE_DEBUG     TRACE_LEVEL_DEBUG, __FILE__, __LINE__
#define TRACE_TRACE     TRACE_LEVEL_TRACE, __FILE__, __LINE__

#define MAX_TRACE_LEVEL 9
#define TRACE_DEBUGGING MAX_TRACE_LEVEL

class Mutex; /* Forward */
class Redis;

/* ******************************* */

class Trace {
 private:
  char *logFile;
  FILE *logFd;
  Redis *traceRedis;
  int numLogLines;
  volatile u_int8_t traceLevel;
  Mutex rotate_mutex;
  void open_log();
#ifdef WIN32
  void AddToMessageLog(LPTSTR lpszMsg);
#endif

 public:
  Trace();
  ~Trace();

  void init();
  void initRedis(const char *redis_host, const char *redis_password,
		 u_int16_t redis_port, u_int8_t _redis_db_id);
  void rotate_logs(bool forceRotation);
  void set_log_file(const char *log_file);
  void set_trace_level(u_int8_t id);
  inline u_int8_t get_trace_level() { return(traceLevel); };
  void traceEvent(int eventTraceLevel, const char* file, const int line, const char * format, ...);
};


#endif /* _TRACE_H_ */
