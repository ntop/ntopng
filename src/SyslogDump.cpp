/*
 *
 * (C) 2013-20 - ntop.org
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

/* **************************************** */

SyslogDump::SyslogDump(NetworkInterface *_iface) : DB(_iface) {
  openlog("ntopng", LOG_PID, LOG_DAEMON);
}

/* **************************************** */

SyslogDump::~SyslogDump() {
  closelog();
}

/* **************************************** */

bool SyslogDump::dumpFlow(time_t when, Flow *f, char *msg) {
  syslog(LOG_INFO, "%s", msg);
  return(true); /* OK */
}


#endif
