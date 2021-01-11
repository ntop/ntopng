/*
 *
 * (C) 2013-21 - ntop.org
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

#ifndef HAVE_NEDGE

#ifndef WIN32

/* **************************************** */

SyslogDump::SyslogDump(NetworkInterface *_iface) : DB(_iface) {
  openlog(NULL        /* If ident is NULL, the program name is used */,
	  LOG_PID     /* Include PID with each message */
	  | LOG_CONS  /* Write directly to system console if there is an error while sending to system logger */,
	  LOG_DAEMON  /* System daemons without separate facility value */);
}

/* **************************************** */

SyslogDump::~SyslogDump() {
  closelog();
}

/* **************************************** */

bool SyslogDump::dumpFlow(time_t when, Flow *f, char *msg) {
  syslog(LOG_INFO, "%s", msg);

  /*
    syslog() returns void, always assumes success.
    In case of errors when sending to the logger, msg is printed directly to console
    as LOG_CONS is specified with openlog()
  */
  incNumExportedFlows();

  return(true); /* OK */
}

#endif /* WIN32 */
#endif
