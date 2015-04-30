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

#include "ntop_includes.h"

/* ******************************* */

Trace::Trace() {
  traceLevel = TRACE_LEVEL_NORMAL;
};

/* ******************************* */

Trace::~Trace() {
};

/* ******************************* */

void Trace::set_trace_level(u_int8_t id) {
  if(id > MAX_TRACE_LEVEL) id = MAX_TRACE_LEVEL;

  traceLevel = id;
}

/* ******************************* */

void Trace::traceEvent(int eventTraceLevel, const char* _file,
		       const int line, const char * format, ...) {
  va_list va_ap;
#ifndef WIN32
  struct tm result;
#endif

  if(eventTraceLevel <= traceLevel) {
    char buf[8192], out_buf[8192];
    char theDate[32], *file = (char*)_file;
    const char *extra_msg = "";
    time_t theTime = time(NULL);
    char *syslogMsg;
#ifdef WIN32
    char filebuf[MAX_PATH];
    const char *backslash = strrchr(_file, '\\');

    if(backslash != NULL) {
      snprintf(filebuf, sizeof(filebuf), "%s", &backslash[1]);
      file = (char*)filebuf;
    } 
#endif

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

    // trace_mutex.lock();
    snprintf(out_buf, sizeof(out_buf), "%s [%s:%d] %s%s", theDate, file, line, extra_msg, buf);

    if(ntop && ntop->getPrefs() && ntop->getPrefs()->get_log_fd()) {
      fprintf(ntop->getPrefs()->get_log_fd(), "%s\n", out_buf);
      fflush(ntop->getPrefs()->get_log_fd());
    }

    printf("%s\n", out_buf);
    fflush(stdout);

    // trace_mutex.unlock();

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
