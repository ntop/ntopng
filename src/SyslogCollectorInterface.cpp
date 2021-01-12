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

#include "ntop_includes.h"

#ifndef HAVE_NEDGE

/* **************************************************** */

bool SyslogCollectorInterface::openSocket(syslog_socket *ss, const char *server_address, int server_port, int protocol) {
  struct sockaddr_in listen_addr;
  int reuse = 1;

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Starting %s syslog collector on %s:%d", 
    protocol == SOCK_DGRAM ? "UDP" : "TCP", server_address, server_port);

  ss->sock = socket(AF_INET, protocol, 0);

  if(ss->sock < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "socket error");
    return false;
  }

  /* Allow to re-bind in case previous instance died */ 
  if(setsockopt(ss->sock, SOL_SOCKET, SO_REUSEADDR,
#ifdef WIN32
  (const char*)
#endif
	  &reuse, sizeof(reuse)) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "setsockopt error");
    return false;
  }
  
  memset(&listen_addr, 0, sizeof(listen_addr));

  listen_addr.sin_family = AF_INET;
  listen_addr.sin_addr.s_addr = inet_addr(server_address);
  listen_addr.sin_port = htons(server_port);
 
  if(::bind(ss->sock, (struct sockaddr *) &listen_addr, sizeof(struct sockaddr)) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "bind error");
    return false;
  }

  if (protocol == SOCK_STREAM) { 
    if(listen(ss->sock, MAX_SYSLOG_SUBSCRIBERS) != 0) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "listen error");
      return false;
    }

    memset(tcp_connections, 0, sizeof(tcp_connections));
  }

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Accepting %s connections on %s:%d",
    protocol == SOCK_DGRAM ? "UDP" : "TCP", server_address, server_port);

  return true;
}

/* **************************************************** */

void SyslogCollectorInterface::closeSocket(syslog_socket *ss, int protocol) {
  close(ss->sock);

  if (protocol == SOCK_STREAM) { 
    for(int i = 0; i < MAX_SYSLOG_SUBSCRIBERS; ++i)
      if(tcp_connections[i].socket != 0)
        close(tcp_connections[i].socket);
  }
}

/* **************************************************** */

SyslogCollectorInterface::SyslogCollectorInterface(const char *_endpoint) : SyslogParserInterface(_endpoint) {
  char *tmp, *pos, *port, *address, *protocol;
  const char *server_address;
  int server_port;

  udp_socket.enable = true;
  tcp_socket.enable = true;

  endpoint = strdup(_endpoint);

  if(endpoint == NULL) 
    throw("memory allocation error");

  tmp = strdup(_endpoint);

  if(tmp == NULL)
    throw("memory allocation error");

  /* 
   * Interface name format:
   * syslog://<ip>:<port>[@{udp,tcp}]
   */

  if(strncmp(tmp, (char*) "syslog://", 9) == 0) {
    address = &tmp[9];
  } else {
    address = tmp;
  }

  pos = strchr(address, '@');

  if (pos != NULL) {
    pos[0] = '\0';
    pos++;
    protocol = pos;

    if (strcmp(protocol, "udp") == 0)
      tcp_socket.enable = false;
    else if (strcmp(protocol, "tcp") == 0)
      udp_socket.enable = false;
  }

  port = strchr(address, ':');

  if(port != NULL) {
    port[0] = '\0';
    port++;
    server_port = atoi(port);
  } else {
    throw("bad tcp bind address format"); 
  }
  
  if (strcmp(address, "*") == 0) {
    /* any address */
    server_address = "0.0.0.0";
  } else {
    server_address = address;
  }

  if (udp_socket.enable)
    if (!openSocket(&udp_socket, server_address, server_port, SOCK_DGRAM))
      throw("Error opening socket");

  if (tcp_socket.enable)
    if (!openSocket(&tcp_socket, server_address, server_port, SOCK_STREAM))
      throw("Error opening socket");

  free(tmp);
}

/* **************************************************** */

SyslogCollectorInterface::~SyslogCollectorInterface() {
  if (udp_socket.enable)
    closeSocket(&udp_socket, SOCK_DGRAM);

  if (tcp_socket.enable)
    closeSocket(&tcp_socket, SOCK_STREAM);

  free(endpoint);
}

/* **************************************************** */

/* set FDs and returns the max sock */
int SyslogCollectorInterface::initFDSetsSocket(syslog_socket *ss, 
    fd_set *read_fds, fd_set *write_fds, fd_set *except_fds, int protocol) {
  int high_sock = ss->sock;

  FD_SET(ss->sock, read_fds);
  FD_SET(ss->sock, except_fds);

  if (protocol == SOCK_STREAM) {
    for(int i = 0; i < MAX_SYSLOG_SUBSCRIBERS; ++i) {
      if(tcp_connections[i].socket != 0) {
        FD_SET(tcp_connections[i].socket, read_fds);
        FD_SET(tcp_connections[i].socket, except_fds);
        if(tcp_connections[i].socket > high_sock)
           high_sock = tcp_connections[i].socket;
      }
    }
  }

  return high_sock;
}

/* **************************************************** */

/* set FDs and returns the max sock */
int SyslogCollectorInterface::initFDSets(fd_set *read_fds, fd_set *write_fds, fd_set *except_fds) {
  int high_sock = 0;

  FD_ZERO(read_fds);
  FD_ZERO(write_fds);
  FD_ZERO(except_fds);

  if (udp_socket.enable) {
    high_sock = initFDSetsSocket(&udp_socket, read_fds, write_fds, except_fds, SOCK_DGRAM);
  }

  if (tcp_socket.enable) {
    int sock = initFDSetsSocket(&tcp_socket, read_fds, write_fds, except_fds, SOCK_STREAM);
    if (sock > high_sock)
      high_sock = sock;
  }

  return high_sock;
}  

/* **************************************************** */

int SyslogCollectorInterface::handleNewConnection() {
  char client_ipv4_str[INET_ADDRSTRLEN];
  struct sockaddr_in client_addr;
  socklen_t client_len = sizeof(client_addr);
  int new_client_sock;
  int i;

  memset(&client_addr, 0, sizeof(client_addr));

  new_client_sock = accept(tcp_socket.sock, (struct sockaddr *) &client_addr, &client_len);

  if(new_client_sock < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "accept() failure");
    return -1;
  }
  
  inet_ntop(AF_INET, &client_addr.sin_addr, client_ipv4_str, INET_ADDRSTRLEN);
  
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Incoming connection from %s:%d", client_ipv4_str, client_addr.sin_port);
  
  for(i = 0; i < MAX_SYSLOG_SUBSCRIBERS; ++i) {
    if(tcp_connections[i].socket == 0) {
      tcp_connections[i].socket = new_client_sock;
      tcp_connections[i].address = client_addr;
      snprintf(tcp_connections[i].ip_str, sizeof(tcp_connections[i].ip_str), "%s", client_ipv4_str);
      return 0;
    }
  }
  
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Too many connections. Closing connection from %s:%d", 
    client_ipv4_str, client_addr.sin_port);

  close(new_client_sock);

  return -1;
}

/* **************************************************** */

void SyslogCollectorInterface::closeConnection(syslog_client *client) {

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Closing client socket for %s:%d\n", 
    client->ip_str, client->address.sin_port);
  
  close(client->socket);
  client->socket = 0;
}

/* **************************************************** */

int SyslogCollectorInterface::receive(int socket, char *client_ip, bool use_recvfrom) {
  char buffer[8192];
  int len, received_total = 0;
  int buffer_size = sizeof(buffer) - 1;
  char *line, *pos;
  struct sockaddr_in client_addr;
  socklen_t client_addr_len = sizeof(client_addr);
  char ip_str[INET_ADDRSTRLEN];

  do {

    if (use_recvfrom)
      len = recvfrom(socket,
#ifndef WIN32
      (void *)
#endif
          buffer, buffer_size,
#ifndef WIN32
        MSG_DONTWAIT
#else
        0
#endif
        , (struct sockaddr *) &client_addr, &client_addr_len);
    else
      len = recv(socket, (char *) buffer, buffer_size, 
#ifndef WIN32
        MSG_DONTWAIT
#else
	0
#endif
      );

    if(len < 0) {
      if(errno == EAGAIN || errno == EWOULDBLOCK) {
        ntop->getTrace()->traceEvent(TRACE_INFO, "Client is not ready");
        break;
      } else {
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Client error");
        return -1;
      }

    } else if(len == 0) {
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Client shutdown");
      return -1;

    } else if(len > 0) {
      if (client_ip == NULL && use_recvfrom) {
        inet_ntop(AF_INET, &client_addr.sin_addr, ip_str, sizeof(ip_str));
        client_ip = ip_str;      
      }
      received_total += len;
      buffer[len] = '\0';
      line = strtok_r(buffer, "\n", &pos);
      while (line) {
        recvStats.num_flows += parseLog(line, client_ip);
        line = strtok_r(NULL, "\n", &pos);
      }
    }

  } while (len > 0);
  
  ntop->getTrace()->traceEvent(TRACE_INFO, "Total received bytes: %u", received_total);

  return 0;
}

/* **************************************************** */

int SyslogCollectorInterface::receiveFromClient(syslog_client *client) {

  ntop->getTrace()->traceEvent(TRACE_INFO, "Trying to receive from %s:%d", 
    client->ip_str, client->address.sin_port);

  return receive(client->socket, client->ip_str, false);
}

/* **************************************************** */

void SyslogCollectorInterface::collect_events() {
  u_int32_t max_num_polls_before_purge = MAX_SYSLOG_POLLS_BEFORE_PURGE;
  fd_set read_fds, write_fds, except_fds;
  struct timeval timeout;
  time_t now, next_purge_idle = time(NULL) + FLOW_PURGE_FREQUENCY;;
  int high_sock;
  int i, rc;

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Collecting events on %s", ifname);

  while (isRunning()) {
    while(idle()) {
      purgeIdle(time(NULL));
      sleep(1);
      if(ntop->getGlobals()->isShutdown()) return;
    }

    high_sock = initFDSets(&read_fds, &write_fds, &except_fds);

    timeout.tv_sec = MAX_SYSLOG_POLL_WAIT_MS/1000;
    timeout.tv_usec = (MAX_SYSLOG_POLL_WAIT_MS%1000)*1000;

    rc = select(high_sock + 1, &read_fds, &write_fds, &except_fds, &timeout);
 
    now = time(NULL);
    max_num_polls_before_purge--;
    if(rc == 0 || now >= next_purge_idle || max_num_polls_before_purge == 0) {
      purgeIdle(now);
      next_purge_idle = now + FLOW_PURGE_FREQUENCY;
      max_num_polls_before_purge = MAX_SYSLOG_POLLS_BEFORE_PURGE;
    }

    if(rc > 0) {
          
      if (udp_socket.enable){
        if (FD_ISSET(udp_socket.sock, &read_fds)) {
          if(receive(udp_socket.sock, NULL, true) != 0)
            ntop->getTrace()->traceEvent(TRACE_ERROR, "Error receiving from UDP socket fd");
        }

        if(FD_ISSET(udp_socket.sock, &except_fds))
          ntop->getTrace()->traceEvent(TRACE_ERROR, "Exception on listen UDP socket fd");
      }

      if (tcp_socket.enable) {
        if (FD_ISSET(tcp_socket.sock, &read_fds))
          handleNewConnection();
      
        if(FD_ISSET(tcp_socket.sock, &except_fds))
          ntop->getTrace()->traceEvent(TRACE_ERROR, "Exception on listen TCP socket fd");
      
        for(i = 0; i < MAX_SYSLOG_SUBSCRIBERS; ++i) {
          if(tcp_connections[i].socket != 0 && FD_ISSET(tcp_connections[i].socket, &read_fds)) {
            if(receiveFromClient(&tcp_connections[i]) != 0) {
              closeConnection(&tcp_connections[i]);
              continue;
            }
          }
  
          if(tcp_connections[i].socket != 0 && FD_ISSET(tcp_connections[i].socket, &except_fds)) {
            ntop->getTrace()->traceEvent(TRACE_ERROR, "Exception on TCP client fd");
            closeConnection(&tcp_connections[i]);
          }
        }
      }
    }
  }

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Flow collection is over.");
}

/* **************************************************** */

static void* messagePollLoop(void* ptr) {
  SyslogCollectorInterface *iface = (SyslogCollectorInterface*)ptr;

  /* Wait until the initialization completes */
  while(!iface->isRunning()) sleep(1);

  iface->collect_events();

  return(NULL);
}

/* **************************************************** */

void SyslogCollectorInterface::startPacketPolling() {
  pthread_create(&pollLoop, NULL, messagePollLoop, (void*)this);
  pollLoopCreated = true;

  SyslogParserInterface::startPacketPolling();
}

/* **************************************************** */

void SyslogCollectorInterface::shutdown() {
  void *res;

  if(running) {
    NetworkInterface::shutdown();
    pthread_join(pollLoop, &res);
  }
}

/* **************************************************** */

bool SyslogCollectorInterface::set_packet_filter(char *filter) {
  ntop->getTrace()->traceEvent(TRACE_ERROR,
			       "No filter can be set on a collector interface. Ignored %s", filter);
  return(false);
}

/* **************************************************** */

void SyslogCollectorInterface::lua(lua_State* vm) {
  SyslogParserInterface::lua(vm);

  lua_push_bool_table_entry(vm, "isSyslog", true);

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "flows", recvStats.num_flows);
  lua_pushstring(vm, "syslogRecvStats");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

#endif
