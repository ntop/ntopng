/*
 *
 * (C) 2019 - ntop.org
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

//#define SYSLOG_DEBUG

/* **************************************************** */

SyslogParserInterface::SyslogParserInterface(const char *endpoint, const char *custom_interface_type) : ParserInterface(endpoint, custom_interface_type) {
  le = new SyslogLuaEngine(this);
}

/* **************************************************** */

SyslogParserInterface::~SyslogParserInterface() {
  if (le)
    delete le;
}

/* **************************************************** */

u_int8_t SyslogParserInterface::parseLog(char *log_line) {
  char *tmp, *content, *application;
  int num_flows = 0;

#ifdef SYSLOG_DEBUG
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "[SYSLOG] Raw message: %s", log_line);
#endif

  tmp = strstr(log_line, "]: ");
  if(tmp == NULL) return 0; /* unexpected format */
  tmp[1] = '\0';
  content = &tmp[3];

  tmp = strrchr(log_line, '[');
  if(tmp == NULL) return 0; /* unexpected format */
  tmp[0] = '\0';

  tmp = strrchr(log_line, ' ');
  if(tmp == NULL) return 0; /* unexpected format */
  application = &tmp[1];

#ifdef SYSLOG_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[SYSLOG] Application: %s Message: %s",
    application, content);
#endif

  if (le) le->handleEvent(application, content);

  return num_flows;
}

/* **************************************************** */

void SyslogParserInterface::lua(lua_State* vm) {
  NetworkInterface::lua(vm);
}

/* **************************************************** */

#endif
