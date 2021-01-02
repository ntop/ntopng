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

#ifndef WIN32

#include "ntop_includes.h"

/* #define TRACE_PING_DROPS */

// #define TRACE_PING

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

  while((!ntop->getGlobals()->isShutdownRequested())
	&& (!ntop->getGlobals()->isShutdown()))
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

  pthread_join(poller, NULL);

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
#ifdef TRACE_PING
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Refreshing %s", _addr);
#endif
      it->second->heartbeat();
    } else {
      v4_results[key] = new (std::nothrow) ContinuousPingStats();
#ifdef TRACE_PING
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Adding host to ping %s", _addr);
#endif
    }
  } else {
    it = v6_results.find(key);

    if(it != v6_results.end()) {
      /* Already present */
#ifdef TRACE_PING
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Refreshing %s", _addr);
#endif
      it->second->heartbeat();
    } else {
      v6_results[key] = new (std::nothrow) ContinuousPingStats();
#ifdef TRACE_PING
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Adding host to ping %s", _addr);
#endif
    }
  }

  m.unlock(__FILE__, __LINE__);
}

/* ***************************************** */

void ContinuousPing::pingAll() {
  time_t last_beat, topurge = time(NULL) - 90 /* sec */;
  bool todiscard = false;

#ifdef TRACE_PING
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s()", __FUNCTION__);
#endif
  
  m.lock(__FILE__, __LINE__);

  pinger->cleanup();

  v4_pinged.clear(),
    v6_pinged.clear();
  
  for(std::map<std::string,ContinuousPingStats*>::iterator it=v4_results.begin(); it!=v4_results.end(); ++it) {
    pinger->ping((char*)it->first.c_str(), false);
    v4_pinged[it->first] = true;
    
    last_beat = it->second->getLastHeartbeat();

    if((last_beat > 0) && (last_beat < topurge))
      inactiveHostsV4.push_back(it->first), todiscard = true;

#ifdef TRACE_PING
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Pinging host %s [last: %d][diff: %d]",
				 (char*)it->first.c_str(), last_beat, last_beat-topurge);
#endif
  }

  for(std::map<std::string,ContinuousPingStats*>::iterator it=v6_results.begin(); it!=v6_results.end(); ++it) {
    pinger->ping((char*)it->first.c_str(), true);
    v6_pinged[it->first] = true;
    last_beat = it->second->getLastHeartbeat();

    if((last_beat > 0) && (last_beat < topurge))
      inactiveHostsV6.push_back(it->first), todiscard = true;;

#ifdef TRACE_PING
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Pinging host %s [last: %d][diff: %d]",
				 (char*)it->first.c_str(), last_beat, last_beat-topurge);
#endif
  }

  if(todiscard)
    cleanupInactiveHosts();
  
  m.unlock(__FILE__, __LINE__);
}

/* ***************************************** */

void ContinuousPing::readPingResults() {
  m.lock(__FILE__, __LINE__);

#ifdef TRACE_PING
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s()", __FUNCTION__);
#endif
  
  for(std::map<std::string,ContinuousPingStats*>::iterator it=v4_results.begin(); it!=v4_results.end(); ++it) {
    float f = pinger->getRTT(it->first.c_str(), false /* v6 */);

#ifdef TRACE_PING
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s() [IPv4] %s=%f", __FUNCTION__, it->first.c_str(), f);
#endif

    if(f != -1)
      it->second->update(f), v4_pinged.erase(it->first);
    else {
      it->second->incSent();
#ifdef TRACE_PING_DROPS
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[IPv4] Missing ping response for %s", it->first.c_str());
#endif
    }
  }

  for(std::map<std::string,ContinuousPingStats*>::iterator it=v6_results.begin(); it!=v6_results.end(); ++it) {
    float f = pinger->getRTT(it->first.c_str(), true /* v6 */);

#ifdef TRACE_PING
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s() [IPv6] %s=%f", __FUNCTION__, it->first.c_str(), f);
#endif

    if(f != -1)
      it->second->update(f), v6_pinged.erase(it->first);
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

void ContinuousPing::collectProtoResponse(lua_State* vm, std::map<std::string,ContinuousPingStats*> *w) {
  for(std::map<std::string,ContinuousPingStats*>::iterator it=w->begin(); it!=w->end(); ++it) {
    if(it->first.c_str()[0]) {
      float min_rtt, max_rtt, jitter, mean;
	
      lua_newtable(vm);

      lua_push_float_table_entry(vm, "response_rate",
				 it->second->getSuccessRate(&min_rtt, &max_rtt, &jitter, &mean));
      lua_push_float_table_entry(vm, "min_rtt",  min_rtt);
      lua_push_float_table_entry(vm, "max_rtt",  max_rtt);
      lua_push_float_table_entry(vm, "jitter",   jitter);
      lua_push_float_table_entry(vm, "mean",     mean);

      lua_pushstring(vm, it->first.c_str());
      lua_insert(vm, -2);
      lua_settable(vm, -3);

      it->second->reset();
    }
  }
}

/* ***************************************** */

void ContinuousPing::collectResponses(lua_State* vm, bool v6) {
  std::map<std::string /* IP */, bool> * pinged = v6 ? &v6_pinged : &v4_pinged;
  lua_newtable(vm);

  m.lock(__FILE__, __LINE__);

  collectProtoResponse(vm, v6 ? &v6_results : &v4_results);

  lua_newtable(vm);

  for(std::map<std::string,bool>::const_iterator it = pinged->begin(); it != pinged->end(); ++it) {
#ifdef TRACE_PING
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Missing ping response for %s", it->first.c_str());
#endif
    
    lua_push_bool_table_entry(vm, (const char*)it->first.c_str(), true); 
  }
  
  lua_pushstring(vm, "no_response");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  pinged->clear();

  m.unlock(__FILE__, __LINE__);
}

/* ***************************************** */

/*
  Discard hosts for which there is not recent hearthbeat
  as they have not been refreshed by the GUI and thus tha
  have been deleted
 */
void ContinuousPing::cleanupInactiveHosts() {
  std::vector<std::string>::iterator it;
  std::map<std::string /* IP */, ContinuousPingStats* /* stats */>::iterator it1;

  /* No Lock needed as this is called from a locked method */
  
  for(it = inactiveHostsV4.begin(); it != inactiveHostsV4.end(); ++it) {
#ifdef TRACE_PING
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[v4] Discarding host %s", it->c_str());
#endif
    
    if((it1 = v4_results.find(*it)) != v4_results.end()) {
      ContinuousPingStats *s = it1->second;

      delete s;
    }
    
    v4_results.erase(*it);
  }

  inactiveHostsV4.clear();

  for(it = inactiveHostsV6.begin(); it != inactiveHostsV6.end(); ++it) {
#ifdef TRACE_PING
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[v6] Discarding host %s", it->c_str());
#endif
    
    if((it1 = v6_results.find(*it)) != v6_results.end()) {
      ContinuousPingStats *s = it1->second;
      
      delete s;
    }
    
    v6_results.erase(*it);
  }

  inactiveHostsV6.clear();
}

/* ***************************************** */

void ContinuousPing::runPingCampaign() {
  if(v4_results.size() || v6_results.size()) {
#ifdef TRACE_PING
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Starting ping campaign");
#endif

    /* Send out pings... */
    pingAll();
    /* Allow a couple of seconds for results to come back... */
    sleep(2);
    /* Make sure there was no shutdown request signal during the sleep */
    if(ntop->getGlobals()->isShutdownRequested()) return;
    /* Collect ping results */
    readPingResults();
    sleep(1);
  } else {
    /* Nothing to do */
    sleep(5);
  }
}

#endif /* WIN32 */
