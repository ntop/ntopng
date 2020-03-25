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
  log_producer = NULL;
  le = new SyslogLuaEngine(this);
}

/* **************************************************** */

SyslogParserInterface::~SyslogParserInterface() {
  if (le)
    delete le;
  if (log_producer)
    free(log_producer);
}

/* **************************************************** */

void SyslogParserInterface::setLogProducer(char *name) {
  if (log_producer) {
    free(log_producer);
    log_producer = NULL;
  }

  if (name)
    log_producer = strdup(name);
}

/* **************************************************** */

u_int8_t SyslogParserInterface::parseLog(char *log_line) {
  char *tmp, *content, *application = NULL;
  int num_flows = 0;

#ifdef SYSLOG_DEBUG
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "[SYSLOG] Raw message: %s", log_line);
#endif

  /*
   * Extracting application name and message content from the syslog message.
   * Expected Format:
   * TIMESTAMP DEVICE APPLICATION[PID]: CONTENT
   */
  tmp = strstr(log_line, "]: ");
  if(tmp != NULL) {
    tmp[1] = '\0';
    content = &tmp[3];

    tmp = strrchr(log_line, '[');
    if(tmp != NULL) {
      tmp[0] = '\0';

      tmp = strrchr(log_line, ' ');
      if(tmp != NULL) {
        application = &tmp[1];
      }
    }
  }

  /* If the log format has not been recognize, checking for a hint
   * in the interface name (syslog://<producer>@<ip>:<port>) */
  if (application == NULL) {
    if (log_producer != NULL) {
      application = log_producer;
      content = log_line;
    } else {
      return 0; /* unexpected format and no hint for the producer */
    }
  }

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
