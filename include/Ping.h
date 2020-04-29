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
  Mutex m;
  std::map<std::string /* IP */, float /* RTT */> results;
  
  u_int16_t checksum(void *b, int len);
  void setOpts(int fd);
  void handleICMPResponse(unsigned char *buf, u_int buf_len, struct in_addr *ip, struct in6_addr *ip6);
  
 public:
  Ping();
  ~Ping();

  int  ping(char *_addr, bool use_v6);
  void pollResults(u_int8_t max_wait_time_sec = 1);
  void collectResponses(lua_State* vm);
  float getRTT(std::string who);
  void cleanup();
};

#endif /* WIN32    */
#endif /* _PING_H_ */
