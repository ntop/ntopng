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

#ifndef _SYSLOG_COLLECTOR_INTERFACE_H_
#define _SYSLOG_COLLECTOR_INTERFACE_H_

#include "ntop_includes.h"

#ifndef HAVE_NEDGE

class LuaEngine;

typedef struct {
  int socket;
  struct sockaddr_in address;
  char ip_str[INET_ADDRSTRLEN];
} syslog_client;

typedef struct {
  bool enable;
  struct sockaddr_in addr;
  int sock;
} syslog_socket;

class SyslogCollectorInterface : public SyslogParserInterface {
 private:
  char *endpoint;
  syslog_socket udp_socket;
  syslog_socket tcp_socket;
  syslog_client tcp_connections[MAX_SYSLOG_SUBSCRIBERS];

  struct {
    u_int32_t num_flows;
  } recvStats;

  bool openSocket(syslog_socket *ss, const char *server_address, int server_port, int protocol);
  void closeSocket(syslog_socket *ss, int protocol);
  int  initFDSetsSocket(syslog_socket *ss, fd_set *read_fds, fd_set *write_fds, fd_set *except_fds, int protocol);
  int  initFDSets(fd_set *read_fds, fd_set *write_fds, fd_set *except_fds);

 public:
  SyslogCollectorInterface(const char *_endpoint);
  ~SyslogCollectorInterface();

  int handleNewConnection();
  void closeConnection(syslog_client *client);
  int receiveFromClient(syslog_client *client);

  int receive(int socket, char *client_ip);

  inline const char* get_type()           { return(CONST_INTERFACE_TYPE_SYSLOG); };
  virtual InterfaceType getIfType() const { return(interface_type_SYSLOG); }
  inline char* getEndpoint(u_int8_t id)   { return(endpoint);   };
  virtual bool isPacketInterface() const  { return(false);      };
  void collect_events();

  void startPacketPolling();
  void shutdown();
  bool set_packet_filter(char *filter);
  virtual void lua(lua_State* vm);
};

#endif /* HAVE_NEDGE */

#endif /* _SYSLOG_COLLECTOR_INTERFACE_H_ */

