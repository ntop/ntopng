/*
 *
 * (C) 2013-15 - ntop.org
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

#ifdef HAVE_NETFILTER

#ifndef _NETFILTER_NETWORK_INTERFACE_H_
#define _NETFILTER_NETWORK_INTERFACE_H_

#include "ntop_includes.h"

class NetfilterHandler;

class NetfilterInterface : public NetworkInterface {
 private:
  int queueId;
  struct nfq_handle *nfHandle;
  struct nfq_q_handle *queueHandle;
  int nf_fd;

 public:
  NetfilterInterface(const char *name);
  ~NetfilterInterface();

  inline const char* get_type()                 { return(CONST_INTERFACE_TYPE_NETFILTER); };
  inline int get_fd()                           { return(nf_fd);                          };
  inline struct nfq_handle*   get_nfHandle()    { return(nfHandle);                       };
  inline struct nfq_q_handle* get_queueHandle() { return(queueHandle);                    };
  void startPacketPolling();
};

#endif /* _NETFILTER_NETWORK_INTERFACE_H_ */

#endif /* HAVE_NETFILTER */

