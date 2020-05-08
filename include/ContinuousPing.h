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

#ifndef _CONTINUOUS_PING_H_
#define _CONTINUOUS_PING_H_

#ifndef WIN32

/* ***************************************** */

class ContinuousPing {
 private:
  std::map<std::string /* IP */, ContinuousPingStats* /* stats */> v4_results, v6_results;
  std::vector<std::string /* IP */> inactiveHostsV4, inactiveHostsV6;
  std::map<std::string /* IP */, bool> v4_pinged, v6_pinged;
  Ping *pinger;
  pthread_t poller;
  Mutex m;

  void pingAll();
  void readPingResults();
  void cleanupInactiveHosts();
  void collectProtoResponse(lua_State* vm, std::map<std::string,ContinuousPingStats*> *w);

 public:
  ContinuousPing();
  ~ContinuousPing();

  void runPingCampaign();
  void ping(char *_addr, bool use_v6);
  void pollResults();
  void collectResponses(lua_State* vm, bool v6);
};

#endif /* WIN32    */
#endif /* _CONTINUOUS_PING_H_ */
