/*
 *
 * (C) 2019-23 - ntop.org
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

#ifndef _PING_H_
#define _PING_H_

#ifndef WIN32

class Ping {
 private:
  u_int16_t ping_id;
  int sd, sd6;
  u_int8_t cnt;
  bool running;
  pthread_t resultPoller;
  char *ifname;
  Mutex m;
  std::map<std::string /* IP */, float /* RTT */> results_v4, results_v6;
  std::map<std::string /* IP */, bool> pinged_v4, pinged_v6;

  u_int16_t checksum(void *b, int len);
  void setOpts(int fd);
  void handleICMPResponse(unsigned char *buf, u_int buf_len, struct in_addr *ip,
                          struct in6_addr *ip6);

 public:
  Ping(char *ifname);
  ~Ping();

  int ping(char *_addr, bool use_v6);
  void pollResults();
  void collectResponses(lua_State *vm, bool v6);
  float getRTT(std::string who, bool v6);
  void start();
  void cleanup();
};

#endif /* WIN32    */
#endif /* _PING_H_ */
