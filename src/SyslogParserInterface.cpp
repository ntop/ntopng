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
  le = NULL;
  producers_reload_requested = true;
}

/* **************************************************** */

void SyslogParserInterface::startPacketPolling() {
  /* Allocate the SyslogLuaEngine only after the plugins have been loaded */
  le = new SyslogLuaEngine(this);

  ParserInterface::startPacketPolling(); /* -> NetworkInterface::startPacketPolling(); */
}

/* **************************************************** */

SyslogParserInterface::~SyslogParserInterface() {
  if (le)
    delete le;
}

/* **************************************************** */

u_int8_t SyslogParserInterface::parseLog(char *log_line, char *client_ip) {
  const char *producer_name = NULL;
  char *prio = NULL, *parsed_client_ip = NULL, *device = NULL, *application = NULL, *content = NULL;
  char *tmp;

  if (producers_reload_requested) {
    doProducersMappingUpdate();
    producers_reload_requested = false;
  }

  if (log_line == NULL || strlen(log_line) == 0)
    return 0;

#ifdef SYSLOG_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[SYSLOG] Raw message: %s", log_line);
#endif

  /*
   * Supported Log Format ({} are used to indicate optional items)
   * {TIMESTAMP;HOST; }<PRIO>{TIMESTAMP DEVICE} APPLICATION{[PID]}{: }CONTENT
   */

  /* Look for <PRIO> */
  prio = strchr(log_line, '<');
  if (prio == NULL)
    return 0;

  if (prio != log_line) { /* Parse TIMESTAMP;HOST; <PRIO> */
    prio[0] = '\0';

    parsed_client_ip = strchr(log_line, ';');
    if(parsed_client_ip != NULL) {
      parsed_client_ip++;
      tmp = strchr(parsed_client_ip, ';');
      if (tmp != NULL)
        tmp[0] = '\0';
    } 
  }

  prio++;
  log_line = strchr(prio, '>');
  if (log_line == NULL)
    return 0;

  log_line[0] = '\0';
  log_line++;

  if (strncmp(log_line, "date=", 5) == 0) { /* Parse custom Fortinet format */
    content = log_line;
  } else if ((tmp = strstr(log_line, "]: ")) != NULL) { /* Parse APPLICATION[PID]: */
    content = &tmp[3];
    tmp[1] = '\0';
    tmp = strrchr(log_line, '[');
    if(tmp != NULL) {
      tmp[0] = '\0';

      /* Parse APPLICATION */
      tmp = strrchr(log_line, ' ');
      if(tmp != NULL) {
        tmp[0] = '\0';
        application = &tmp[1];
 
        /* Parse DEVICE */
        tmp = strrchr(log_line, ' ');
        if(tmp != NULL)
          device = &tmp[1];
      }
    }
  } else if ((tmp = strstr(log_line, ": ")) != NULL) { /* Parse APPLICATION: */
    content = &tmp[2];
    tmp[0] = '\0';

    tmp = strrchr(log_line, ' ');
    if(tmp != NULL) {
      tmp[0] = '\0';

      /* Parse DEVICE */
      tmp = strrchr(log_line, ' ');
      if(tmp != NULL)
        device = &tmp[1];
    }
  } else { /* Ignore ':' as last resort  */
    content = log_line;
  }
 
  if (producer_name == NULL && parsed_client_ip != NULL)
    producer_name = getProducerName(parsed_client_ip);

  if (producer_name == NULL && device != NULL)
    producer_name = getProducerName(device);

  if (producer_name == NULL && client_ip != NULL)
    producer_name = getProducerName(client_ip);

  if (producer_name == NULL && application != NULL)
    producer_name = application;

  if (producer_name == NULL)
    producer_name = getProducerName("*");

  if (producer_name == NULL)
    return 0;

#ifdef SYSLOG_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[SYSLOG] Application: %s Message: %s",
    producer_name, content);
#endif

  if (le) le->handleEvent(producer_name, content);

  return 0;
}

/* **************************************************** */

void SyslogParserInterface::lua(lua_State* vm) {
  NetworkInterface::lua(vm);
}

/* **************************************************** */

void SyslogParserInterface::addProducerMapping(const char *host, const char *producer) {
  string host_ip(host);
  string producer_name(producer);
  producers_map_t::iterator it;

  if((it = producers_map.find(host_ip)) == producers_map.end())
    producers_map.insert(make_pair(host_ip, producer_name));
  else
    it->second = producer_name;
}

/* **************************************************** */

void SyslogParserInterface::doProducersMappingUpdate() {
  char key[64];
  char **keys, **values;
  int rc;

  producers_map.clear();

  snprintf(key, sizeof(key), SYSLOG_PRODUCERS_MAP_KEY, get_id()); 

  rc = ntop->getRedis()->hashGetAll(key, &keys, &values);

  if (rc > 0) {
    for (int i = 0; i < rc; i++) {
      if (keys[i] && values[i]) {
        ntop->getTrace()->traceEvent(TRACE_INFO, "Adding syslog producer %s (%s)", keys[i], values[i]);
        addProducerMapping(keys[i], values[i]);
      }

      if(values[i]) free(values[i]);
      if(keys[i]) free(keys[i]);
    }

    free(keys);
    free(values);
  }
}

/* **************************************************** */

const char *SyslogParserInterface::getProducerName(const char *host) {
  string host_ip(host);
  producers_map_t::const_iterator it;

  if((it = producers_map.find(host_ip)) != producers_map.end())
    return it->second.c_str();

  return NULL;
}

/* **************************************************** */

#endif
