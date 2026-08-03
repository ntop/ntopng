/*
 *
 * (C) 2019-26 - ntop.org
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

// #define SYSLOG_DEBUG

/* **************************************************** */

SyslogParserInterface::SyslogParserInterface(const char* endpoint,
                                             const char* custom_interface_type)
    : ParserInterface(endpoint, custom_interface_type) {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  le = NULL;
  producers_reload_requested = true;
}

/* **************************************************** */

void SyslogParserInterface::startPacketPolling() {
  /* Allocate the SyslogLuaEngine only after the scripts have been loaded */
  le = new (std::nothrow) SyslogLuaEngine(this);

  ParserInterface::
      startPacketPolling(); /* -> NetworkInterface::startPacketPolling(); */
}

/* **************************************************** */

SyslogParserInterface::~SyslogParserInterface() {
  if (le) delete le;
}

/* **************************************************** */

/*
 * Check if log line is in RFC 5424 format
 * <PRIO>VERSION TIMESTAMP HOSTNAME APP-NAME PROCID MSGID [STRUCTURED-DATA] CONTENT
 * Example:
 * <13>1 2026-08-03T15:09:00+02:00 suricata suricata - - CONTENT
 */
bool SyslogParserInterface::isRFC5424Header(const char* log_line) {
  const char *v = log_line, *ts, *ts_end;

  if (*v < '0' || *v > '9') return false;

  while (*v >= '0' && *v <= '9') v++;
  if (v == log_line || *v != ' ') return false;

  ts = v + 1;
  ts_end = strchr(ts, ' ');
  if (ts_end == NULL) return false;

  /* Timestamp (either "-" or RFC 3339 time) */
  if (ts_end == ts + 1 && ts[0] == '-') return true;
  if (memchr(ts, 'T', ts_end - ts) != NULL) return true;

  return false;
}

/* **************************************************** */

/*
 * Parse RFC 5424 header, assuming <PRIO> has already been stripped by the caller.
 */
bool SyslogParserInterface::parseRFC5424Header(char* log_line, char** device, char** application, char** content) {
  char* tmp;

  /* Version */
  tmp = strchr(log_line, ' ');
  if (tmp == NULL) return false;
  log_line = tmp + 1;

  /* Timestamp */
  tmp = strchr(log_line, ' ');
  if (tmp == NULL) return false;
  log_line = tmp + 1;

  /* Hostname */
  tmp = strchr(log_line, ' ');
  if (tmp == NULL) return false;
  tmp[0] = '\0';
  *device = (strcmp(log_line, "-") == 0) ? NULL : log_line;
  log_line = tmp + 1;

  /* Application */
  tmp = strchr(log_line, ' ');
  if (tmp == NULL) return false;
  tmp[0] = '\0';
  *application = (strcmp(log_line, "-") == 0) ? NULL : log_line;
  log_line = tmp + 1;

  /* Proc ID */
  tmp = strchr(log_line, ' ');
  if (tmp == NULL) return false;
  log_line = tmp + 1;

  /* Msg ID */
  tmp = strchr(log_line, ' ');
  if (tmp == NULL) return false;
  log_line = tmp + 1;

  if (log_line[0] == '-' && (log_line[1] == ' ' || log_line[1] == '\0')) {
    log_line++;

    if (log_line[0] != ' ') return false;
    log_line++;
  } else if (log_line[0] == '[') {
    bool in_quotes = false;

    tmp = log_line;
    while (*tmp != '\0') {
      if (*tmp == '\\' && in_quotes && tmp[1] != '\0') {
        tmp += 2;
        continue;
      } else if (*tmp == '"') {
        in_quotes = !in_quotes;
      } else if (*tmp == ']' && !in_quotes) {
        tmp++;
        if (*tmp == '[') continue;
        break;
      }

      tmp++;
    }

    if (tmp[0] != ' ') return false;
    log_line = tmp + 1;
  }

  /* Skip optional */
  if ((u_char)log_line[0] == 0xEF && (u_char)log_line[1] == 0xBB &&
      (u_char)log_line[2] == 0xBF)
    log_line += 3;

  *content = log_line;

  return true;
}

/* **************************************************** */

u_int8_t SyslogParserInterface::parseLog(char* log_line, char* client_ip) {
  const char* producer_name = NULL;
  char *prio = NULL, *parsed_client_ip = NULL, *device = NULL,
       *application = NULL, *content = NULL;
  char* tmp;
  u_int32_t num_total_events = 0, num_malformed = 0;

  if (producers_reload_requested) {
    doProducersMappingUpdate();
    producers_reload_requested = false;
  }

  /* Event parsing */

  if (log_line == NULL || strlen(log_line) == 0) goto exit;

#ifdef SYSLOG_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[SYSLOG] Raw message: %s",
                               log_line);
#endif

  /* Check if this is a clean JSON (no Syslog header) */
  if (log_line[0] == '{') {
    content = log_line;
    goto detect_producer;
  }

  /*
   * Supported RFC 3164 format:
   * {TIMESTAMP;HOST; }<PRIO>{TIMESTAMP DEVICE} APPLICATION{[PID]}{: }CONTENT
   * Example:
   * <128>Jan 11 09:57:56 dev-box suricata[3282]: [MESSAGE]
   *
   * Also supported RFC 5424:
   * <PRIO>VERSION TIMESTAMP HOSTNAME APP-NAME PROCID MSGID {STRUCTURED-DATA} CONTENT
   */

  /* Look for <PRIO> */
  prio = strchr(log_line, '<');
  if (prio == NULL) {
    num_malformed++;
    goto exit;
  }

  if (prio != log_line) { /* Parse TIMESTAMP;HOST; <PRIO> */
    prio[0] = '\0';

    parsed_client_ip = strchr(log_line, ';');
    if (parsed_client_ip != NULL) {
      parsed_client_ip++;
      tmp = strchr(parsed_client_ip, ';');
      if (tmp != NULL) tmp[0] = '\0';
    }
  }

  prio++;
  log_line = strchr(prio, '>');
  if (log_line == NULL) {
    num_malformed++;
    goto exit;
  }

  log_line[0] = '\0';
  log_line++;

  if (isRFC5424Header(log_line)) {
    /* Parse RFC 5424 format */
    if (!parseRFC5424Header(log_line, &device, &application, &content)) {
      num_malformed++;
      goto exit;
    }
  } else if (strncmp(log_line, "date=", 5) == 0) {
    /* Parse custom Fortinet format */
    producer_name = "fortinet"; /* fortinet detected */
    content = log_line;
  } else if ((tmp = strstr(log_line, "]: ")) != NULL) {
    /* Parse APPLICATION[PID]: */
    content = &tmp[3];
    tmp[1] = '\0';
    tmp = strrchr(log_line, '[');
    if (tmp != NULL) {
      tmp[0] = '\0';

      /* Parse APPLICATION */
      tmp = strrchr(log_line, ' ');
      if (tmp != NULL) {
        tmp[0] = '\0';
        application = &tmp[1];

        /* Parse DEVICE */
        tmp = strrchr(log_line, ' ');
        if (tmp != NULL) device = &tmp[1];
      }
    }
  } else if ((tmp = strstr(log_line, ": ")) != NULL) {
    /* Parse APPLICATION: */
    content = &tmp[2];
    tmp[0] = '\0';

    tmp = strrchr(log_line, ' ');
    if (tmp != NULL) {
      tmp[0] = '\0';

      /* Parse DEVICE */
      tmp = strrchr(log_line, ' ');
      if (tmp != NULL) device = &tmp[1];
    }
  } else { /* Ignore ':' as last resort  */
    content = log_line;
  }

  num_total_events++;

  /* Producer Lookup */

detect_producer:

  if (producer_name == NULL && parsed_client_ip != NULL) {
    Utils::stringtolower(parsed_client_ip); /* normalize */
    producer_name = getProducerName(parsed_client_ip);
  }

  if (producer_name == NULL && device != NULL) {
    Utils::stringtolower(device); /* normalize */
    producer_name = getProducerName(device);
  }

  if (producer_name == NULL && client_ip != NULL) {
    producer_name = getProducerName(client_ip);
  }

  if (producer_name == NULL && application != NULL) {
    Utils::stringtolower(application); /* normalize */
    producer_name = application;
  }

  if (producer_name == NULL) {
    producer_name = getProducerName("*");
  }

  if (producer_name == NULL) goto exit;

#ifdef SYSLOG_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
                               "[SYSLOG] Application: %s Message: %s",
                               producer_name, content);
#endif

  /* Dispatching */

  if (le)
    le->handleEvent(producer_name, content,
                    parsed_client_ip ? parsed_client_ip : client_ip,
                    prio ? atoi(prio) : 0);

exit:
  incSyslogStats(num_total_events, num_malformed, 0, 0, 0, 0, 0);
  return 0;
}

/* **************************************************** */

void SyslogParserInterface::lua(lua_State* vm, bool fullStats) {
  NetworkInterface::lua(vm, fullStats);
}

/* **************************************************** */

void SyslogParserInterface::addProducerMapping(const char* host,
                                               const char* producer) {
  string host_ip(host);
  string producer_name(producer);
  producers_map_t::iterator it;

  if ((it = producers_map.find(host_ip)) == producers_map.end())
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
        ntop->getTrace()->traceEvent(
            TRACE_INFO, "Adding syslog producer %s (%s)", keys[i], values[i]);
        Utils::stringtolower(keys[i]); /* normalize */
        addProducerMapping(keys[i], values[i]);
      }

      if (values[i]) free(values[i]);
      if (keys[i]) free(keys[i]);
    }

    free(keys);
    free(values);
  }
}

/* **************************************************** */

const char* SyslogParserInterface::getProducerName(const char* host) {
  string host_ip(host);
  producers_map_t::const_iterator it;

  if ((it = producers_map.find(host_ip)) != producers_map.end())
    return it->second.c_str();

  return NULL;
}

/* **************************************************** */

#endif
