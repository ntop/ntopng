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

#ifndef WIN32

#include "ntop_includes.h"

#define TRACE_PING_DROPS

/* #define TRACE_PING */

/*
  Usage example (minute.lua):
  
  local use_ipv4 = true  
  ntop.pingHost(ntop.resolveHost("dns.ntop.org", use_ipv4), not(use_ipv4), true)
  ntop.pingHost("192.168.1.1", not(use_ipv4), true)
  ntop.pingHost("192.168.1.2", not(use_ipv4), true)
  tprint(ntop.collectPingResults(true))
*/

/* ****************************************** */

static void* pollerFctn(void* ptr) {
  ContinuousPing *cp = (ContinuousPing*)ptr;

  Utils::setThreadName("ContinuousPingLoop");

  while(!ntop->getGlobals()->isShutdown())
    cp->runPingCampaign();

#ifdef TRACE_PING
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Leaving %s()", __FUNCTION__);
#endif

  return(NULL);
}

/* ***************************************** */

ContinuousPing::ContinuousPing() {
  try {
    pinger = new Ping();

    if(pinger)
      pthread_create(&poller, NULL, pollerFctn, (void*)this);
  } catch(...) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to crete continuous pinger");
    pinger = NULL;
  }
}

/* ***************************************** */

ContinuousPing::~ContinuousPing() {
  for(std::map<std::string,ContinuousPingStats*>::iterator it=v4_results.begin(); it!=v4_results.end(); ++it)
    delete it->second;

  for(std::map<std::string,ContinuousPingStats*>::iterator it=v6_results.begin(); it!=v6_results.end(); ++it)
    delete it->second;

  delete pinger;
}

/* ***************************************** */

/* Add a new host or refresh the existing one */
void ContinuousPing::ping(char *_addr, bool use_v6) {
  std::string key = std::string(_addr);
  std::map<std::string,ContinuousPingStats*>::iterator it;

  m.lock(__FILE__, __LINE__);

  if(!use_v6) {
    it = v4_results.find(key);

    if(it != v4_results.end()) {
      /* Already present */
      it->second->heartbeat();
    } else
      v4_results[key] = new ContinuousPingStats();
  } else {
    it = v6_results.find(key);

    if(it != v6_results.end()) {
      /* Already present */
      it->second->heartbeat();
    } else
      v6_results[key] = new ContinuousPingStats();
  }

  m.unlock(__FILE__, __LINE__);
}

/* ***************************************** */

void ContinuousPing::pingAll() {
  m.lock(__FILE__, __LINE__);

  for(std::map<std::string,ContinuousPingStats*>::iterator it=v4_results.begin(); it!=v4_results.end(); ++it)
    pinger->ping((char*)it->first.c_str(), false);

  for(std::map<std::string,ContinuousPingStats*>::iterator it=v6_results.begin(); it!=v6_results.end(); ++it)
    pinger->ping((char*)it->first.c_str(), true);

  m.unlock(__FILE__, __LINE__);
}

/* ***************************************** */

void ContinuousPing::readPingResults() {
  m.lock(__FILE__, __LINE__);

  for(std::map<std::string,ContinuousPingStats*>::iterator it=v4_results.begin(); it!=v4_results.end(); ++it) {
    float f = pinger->getRTT(it->first.c_str());

#ifdef TRACE_PING
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s() [IPv4] %s=%f", __FUNCTION__, it->first.c_str(), f);
#endif

    if(f != -1)
      it->second->update(f);
    else {
      it->second->incSent();
#ifdef TRACE_PING_DROPS
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[IPv4] Missing ping response for %s", it->first.c_str());
#endif
    }
  }

  for(std::map<std::string,ContinuousPingStats*>::iterator it=v6_results.begin(); it!=v6_results.end(); ++it) {
    float f = pinger->getRTT(it->first.c_str());

#ifdef TRACE_PING
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s() [IPv6] %s=%f", __FUNCTION__, it->first.c_str(), f);
#endif
   
    if(f != -1)
      it->second->update(f);
    else {
      it->second->incSent();
#ifdef TRACE_PING_DROPS
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[IPv6] Missing ping response for %s", it->first.c_str());
#endif
    }
  }

  m.unlock(__FILE__, __LINE__);
}

/* ***************************************** */

void ContinuousPing::collectResponses(lua_State* vm) {
  float min_rtt, max_rtt; /* Future use */
  lua_newtable(vm);

  m.lock(__FILE__, __LINE__);

  for(std::map<std::string,ContinuousPingStats*>::iterator it=v4_results.begin(); it!=v4_results.end(); ++it) {
    if(it->first.c_str()[0]) {
      lua_newtable(vm);

      lua_push_float_table_entry(vm, "response_rate", it->second->getSuccessRate(&min_rtt, &max_rtt));
      lua_push_float_table_entry(vm, "min_rtt", min_rtt);
      lua_push_float_table_entry(vm, "max_rtt", max_rtt);

      lua_pushstring(vm, it->first.c_str());
      lua_insert(vm, -2);
      lua_settable(vm, -3);

      it->second->reset();
    }
  }

  for(std::map<std::string,ContinuousPingStats*>::iterator it=v6_results.begin(); it!=v6_results.end(); ++it) {
    if(it->first.c_str()[0]) {
      lua_newtable(vm);

      lua_push_float_table_entry(vm, "response_rate", it->second->getSuccessRate(&min_rtt, &max_rtt));
      lua_push_float_table_entry(vm, "min_rtt", min_rtt);
      lua_push_float_table_entry(vm, "max_rtt", max_rtt);

      lua_pushstring(vm, it->first.c_str());
      lua_insert(vm, -2);
      lua_settable(vm, -3);

      it->second->reset();
    }
  }

  m.unlock(__FILE__, __LINE__);
}

/* ***************************************** */

void ContinuousPing::runPingCampaign() {
  if(ntop->isStarted() && (v4_results.size() || v6_results.size())) {
#ifdef TRACE_PING
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Starting ping campaign");
#endif

    pinger->cleanup();
    pingAll();
    pinger->pollResults(2);
    readPingResults();
  }

  sleep(1);
}

#endif /* WIN32 */
