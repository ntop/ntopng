/*
 *
 * (C) 2013-23 - ntop.org
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

#ifndef _ADDRESS_RESOLUTION_H_
#define _ADDRESS_RESOLUTION_H_

#include "ntop_includes.h"

class AddressResolution {
  int num_resolvers;
  u_int32_t num_resolved_addresses, num_resolved_fails;
  pthread_t *resolveThreadLoop;
  Mutex m;

 public:
  AddressResolution(int num_resolvers);
  ~AddressResolution();

  void startResolveAddressLoop();
  void resolveHostName(const char *numeric_ip, char *rsp = NULL,
                       u_int rsp_len = 0);
  bool resolveHost(const char *host, char *rsp, u_int rsp_len, bool v4);
};

#endif /* _ADDRESS_RESOLUTION_H_ */
