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

#include "ntop_includes.h"

/* ******************************* */

Trace::Trace() {
  traceLevel = TRACE_LEVEL_NORMAL;
  logFile = NULL;
  logFd = NULL;
  traceRedis = NULL;

  open_log();
};

/* ******************************* */

Trace::~Trace() {
  if(logFd)      fclose(logFd);
  if(logFile)    free(logFile);
  if(traceRedis) delete traceRedis;
};

/* ******************************* */

void Trace::rotate_logs(bool forceRotation) {
  char buf1[MAX_PATH], buf2[MAX_PATH];
  const int max_num_lines = TRACES_PER_LOG_FILE_HIGH_WATERMARK;

  if(!logFd) return;
  else if((!forceRotation) && (numLogLines < max_num_lines)) return;

  fclose(logFd);
  logFd = NULL;

  for(int i = MAX_NUM_NTOPNG_LOG_FILES - 1; i >= 1; i--) {
    snprintf(buf1, sizeof(buf1), "%s.%u", logFile, i);
    snprintf(buf2, sizeof(buf2), "%s.%u", logFile, i + 1);

    if(Utils::file_exists(buf1))
      rename(buf1, buf2);
  } /* for */

  if(Utils::file_exists(logFile)) {
    snprintf(buf1, sizeof(buf1), "%s.1", logFile);
    rename(logFile, buf1);
  }

  open_log();
}

/* ******************************* */

void Trace::open_log() {
  if(logFile) {
    logFd = fopen(logFile, "a");

    if(!logFd)
      traceEvent(TRACE_ERROR, "Unable to create log %s", logFile);
    else
      chmod(logFile, CONST_DEFAULT_FILE_MODE);
	    
    numLogLines = 0;
  }
}

/* ******************************* */

void Trace::set_log_file(const char* log_file) {
  if(log_file && log_file[0] != '\0') {
    rotate_logs(true);
    if(logFile) free(logFile);
    logFile = strndup(log_file, MAX_PATH);
    open_log();
  }
}

/* ******************************* */

void Trace::set_trace_level(u_int8_t id) {
  if(id > MAX_TRACE_LEVEL) id = MAX_TRACE_LEVEL;

  traceLevel = id;
}

/* ******************************* */

void Trace::initRedis(const char *redis_host, const char *redis_password,
		      u_int16_t redis_port, u_int8_t _redis_db_id) {
  Utils::initRedis(&traceRedis, redis_host, redis_password,
		   redis_port, _redis_db_id);
}

/* ******************************* */

void Trace::traceEvent(int eventTraceLevel, const char* _file,
		       const int line, const char * format, ...) {
  va_list va_ap;
#ifndef WIN32
  struct tm result;
#endif

  if((eventTraceLevel <= traceLevel) && (traceLevel > 0)) {
    char buf[8192], out_buf[8192];
    char theDate[32], *file = (char*)_file;
    const char *extra_msg = "";
    time_t theTime = time(NULL);
#ifndef WIN32
    char *syslogMsg;
#endif
    char filebuf[MAX_PATH];
    const char *backslash = strrchr(_file,
#ifdef WIN32
				    '\\'
#else
				    '/'
#endif
				    );

    if(backslash != NULL) {
      snprintf(filebuf, sizeof(filebuf), "%s", &backslash[1]);
      file = (char*)filebuf;
    }

    va_start (va_ap, format);

    /* We have two paths - one if we're logging, one if we aren't
     *   Note that the no-log case is those systems which don't support it (WIN32),
     *                                those without the headers !defined(USE_SYSLOG)
     *                                those where it's parametrically off...
     */

    memset(buf, 0, sizeof(buf));
    strftime(theDate, 32, "%d/%b/%Y %H:%M:%S", localtime_r(&theTime, &result));

    vsnprintf(buf, sizeof(buf)-1, format, va_ap);

    if(eventTraceLevel == 0 /* TRACE_ERROR */)
      extra_msg = "ERROR: ";
    else if(eventTraceLevel == 1 /* TRACE_WARNING */)
      extra_msg = "WARNING: ";

    while(buf[strlen(buf)-1] == '\n') buf[strlen(buf)-1] = '\0';

    snprintf(out_buf, sizeof(out_buf), "%s [%s:%d] %s%s", theDate, file, line, extra_msg, buf);

    if(logFd) {
      rotate_mutex.lock(__FILE__, __LINE__); /* Need to lock as a rotation may be in progress */
      numLogLines++;
      fprintf(logFd, "%s\n", out_buf);
      fflush(logFd);
      rotate_logs(false);
      rotate_mutex.unlock(__FILE__, __LINE__);
    } else {
#ifdef WIN32
      AddToMessageLog(out_buf);
#else
      syslogMsg = &out_buf[strlen(theDate)+1];
      if(eventTraceLevel == 0 /* TRACE_ERROR */)
	syslog(LOG_ERR, "%s", syslogMsg);
      else if(eventTraceLevel == 1 /* TRACE_WARNING */)
	syslog(LOG_WARNING, "%s", syslogMsg);
#endif
    }

    printf("%s\n", out_buf);
    fflush(stdout);
    
    if(traceRedis)
      traceRedis->lpush(NTOPNG_TRACE, out_buf, MAX_NUM_NTOPNG_TRACES,
			false /* Do not re-trace errors, re-tracing would yield a deadlock */);
    
    va_end(va_ap);
  }
}

/* ******************************* */

#ifdef WIN32

/* service_win32.cpp */
extern "C" {
  extern short isWinNT();
  extern BOOL  bConsole;
};

/* ******************************* */

void Trace::AddToMessageLog(LPTSTR lpszMsg) {
  HANDLE  hEventSource;
  TCHAR	szMsg[4096];

#ifdef UNICODE
  LPCWSTR lpszStrings[1];
#else
  LPCSTR  lpszStrings[1];
#endif

  if(!isWinNT()) {
    char *msg = (char*)lpszMsg;
    printf("%s", msg);
    if(msg[strlen(msg)-1] != '\n')
      printf("\n");
    return;
  }

  if(!szMsg) {
    hEventSource = RegisterEventSource(NULL, TEXT(SZSERVICENAME));

    snprintf(szMsg, sizeof(szMsg), TEXT("%s: %s"), SZSERVICENAME, lpszMsg);

    lpszStrings[0] = szMsg;

    if (hEventSource != NULL) {
      ReportEvent(hEventSource,
		  EVENTLOG_INFORMATION_TYPE,
		  0,
		  EVENT_GENERIC_INFORMATION,
		  NULL,
		  1,
		  0,
		  lpszStrings,
		  NULL);

      DeregisterEventSource(hEventSource);
    }
  }
}

/* ******************************* */

#endif /* WIN32 */
