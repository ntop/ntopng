/*
 *
 * (C) 2016 - ntop.org
 *
 *
 * This program is free software; you can addresstribute it and/or modify
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

#ifndef _FLASHSTART_H_
#define _FLASHSTART_H_

#include "ntop_includes.h"

struct category_mapping {
  char *name;   /* key */
  u_int8_t category; /* value */
  UT_hash_handle hh;         /* makes this structure hashable */
};

class Flashstart {
  int sock;
  struct sockaddr_in dnsServer[NUM_FLASHSTART_SERVERS];
  u_int32_t num_flashstart_categorizations, num_flashstart_fails;
  char *user, *pwd;
  u_int8_t dnsServerIdx;
  struct category_mapping *mapping;
  pthread_t flashstartThreadLoop;
  u_int8_t numCategories;

  void initMapping();
  void purgeMapping();
  void addMapping(const char *label, u_int8_t id);
  void queryFlashstart(char *symbolic_name);
  int parseDNSResponse(unsigned char *rsp, int rsp_len, struct sockaddr_in *from);
  u_int recvResponses(u_int msecTimeout);
  void queryDomain(int sock, char *domain, u_int queryId,
		   const struct sockaddr *to, socklen_t tolen);     
  void setCategory(NDPI_PROTOCOL_BITMASK *category, char *rsp);

 public:
  Flashstart(char *_user, char *_pwd);
  ~Flashstart();

  int findMapping(char *label);
  void startLoop();
  void* flashstartLoop(void* ptr);
  bool findCategory(char *name, NDPI_PROTOCOL_BITMASK *category, bool add_if_needed); 
  void dumpCategories(lua_State* vm, NDPI_PROTOCOL_BITMASK *category);
  void dumpCategories(NDPI_PROTOCOL_BITMASK *category, char *buf, u_int buf_len);
};

#endif /* _FLASHSTART_H_ */
