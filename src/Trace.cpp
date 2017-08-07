/*
 *
 * (C) 2013-17 - ntop.org
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
  logFileTracesCount = new int(0);
#ifndef WIN32
  logFileMsg = false;
  logFdShadow = NULL;
  logFileTracesCountShadow = NULL;
#endif
};

/* ******************************* */

Trace::~Trace() {
  if(logFd)                    fclose(logFd);
  if(logFile)                  free(logFile);
  if(logFileTracesCount)       delete logFileTracesCount;
#ifndef WIN32
  if(logFdShadow)              fclose(logFdShadow);
  if(logFileTracesCountShadow) delete logFileTracesCountShadow;
#endif
};

/* ******************************* */

void Trace::rotate_logs(bool force_rotation) {
  int rc;
  char buf1[MAX_PATH], buf2[MAX_PATH];

  if(!logFile
     || ((logFileTracesCount && *logFileTracesCount < TRACES_PER_LOG_FILE_HIGH_WATERMARK)
	 && !force_rotation))
    return;

#ifdef WIN32
  /* Unsafe to rename with an open file descriptor under WIN */
  rotate_mutex.lock(__FILE__, __LINE__);
  if(logFd) fclose(logFd), logFd = NULL;
  if(logFileTracesCount) *logFileTracesCount = 0;
#endif

  for(int i = MAX_NUM_NTOPNG_LOG_FILES - 1; i >= 1; i--) {
    snprintf(buf1, sizeof(buf1), "%s.%u", logFile, i);
    snprintf(buf2, sizeof(buf2), "%s.%u", logFile, i + 1);

    if(Utils::file_exists(buf1)) {
      if((rc = rename(buf1, buf2)))
#ifndef WIN32
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to rename file %s -> %s", logFile, buf1);
#else
	;
#endif
    }
  }

  if(Utils::file_exists(logFile)) {
    snprintf(buf1, sizeof(buf1), "%s.1", logFile);
    if((rc = rename(logFile, buf1)))
#ifndef WIN32
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Unable to rename file %s -> %s", logFile, buf1);
#else
      ;
#endif
  }

  /* It's safe to rename even if another thread is writing as the FS inode doesn't change */
#ifndef WIN32
  if(logFdShadow)              fclose(logFdShadow);
  if(logFileTracesCountShadow) delete logFileTracesCountShadow;

  logFdShadow = logFd;
  logFileTracesCountShadow = logFileTracesCount;

  logFileTracesCount = new int(0);
#endif
  logFd = fopen(logFile, "w");

#ifdef WIN32
  rotate_mutex.unlock(__FILE__, __LINE__);
#else
  if(!logFileMsg) {
    if(logFd)
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Logging into %s", logFile);
    else
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to create log %s", logFile);

    logFileMsg = true;
  }
#endif
}

/* ******************************* */

void Trace::set_log_file(const char* log_file) {
  if(log_file && log_file[0] != '\0') {
    if(logFile) free(logFile);
    logFile = strndup(log_file, MAX_PATH);
  }
}

/* ******************************* */

void Trace::set_trace_level(u_int8_t id) {
  if(id > MAX_TRACE_LEVEL) id = MAX_TRACE_LEVEL;

  traceLevel = id;
}

/* ******************************* */

void Trace::traceEvent(int eventTraceLevel, const char* _file,
		       const int line, const char * format, ...) {
  va_list va_ap;
  FILE *log_fd;
  int *count;
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

#ifdef WIN32
    rotate_mutex.lock(__FILE__, __LINE__); /* Need to lock as a rotation may be in progress */
#endif

    if((log_fd = logFd) && (count = logFileTracesCount)) {
      (*count)++;  /* Avoid locking even if there's some chance of simultaneous increments */
      fprintf(log_fd, "%s\n", out_buf);
      fflush(log_fd);
    }

#ifdef WIN32
    rotate_mutex.unlock(__FILE__, __LINE__);
#endif

    printf("%s\n", out_buf);
    fflush(stdout);

    if(ntop->getRedis())
      ntop->getRedis()->lpush(NTOPNG_TRACE, out_buf, MAX_NUM_NTOPNG_TRACES);


#ifndef WIN32
    syslogMsg = &out_buf[strlen(theDate)+1];
    if(eventTraceLevel == 0 /* TRACE_ERROR */)
      syslog(LOG_ERR, "%s", syslogMsg);
    else if(eventTraceLevel == 1 /* TRACE_WARNING */)
      syslog(LOG_WARNING, "%s", syslogMsg);
#endif

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

#if 0
VOID Trace::AddToMessageLog(LPTSTR lpszMsg) {
  HANDLE  hEventSource;
  TCHAR	szMsg[4096];

#ifdef UNICODE
  LPCWSTR  lpszStrings[1];
#else
  LPCSTR   lpszStrings[1];
#endif

  if(!isWinNT()) {
    char *msg = (char*)lpszMsg;
    printf("%s", msg);
    if(msg[strlen(msg)-1] != '\n')
      printf("\n");
    return;
  }

  if (!szMsg)
    {
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
#endif

/* ******************************* */

#endif /* WIN32 */
