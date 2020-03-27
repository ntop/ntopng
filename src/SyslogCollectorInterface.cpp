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

#include "ntop_includes.h"

#ifndef HAVE_NEDGE

/* **************************************************** */

SyslogCollectorInterface::SyslogCollectorInterface(const char *_endpoint) : SyslogParserInterface(_endpoint) {
  char *tmp, *pos, *port, *server_address, *producer, *protocol;
  int server_port;
  int reuse = 1;
  int i;

  use_udp = false;

  endpoint = strdup(_endpoint);

  if(endpoint == NULL) 
    throw("memory allocation error");

  tmp = strdup(_endpoint);

  if(tmp == NULL)
    throw("memory allocation error");

  /* 
   * Interface name format:
   * syslog://[<producer>[:udp]@]<ip>:<port>
   */

  if(strncmp(tmp, (char*) "syslog://", 9) == 0) {
    server_address = &tmp[9];
  } else {
    server_address = tmp;
  }

  pos = strchr(server_address, '@');

  if (pos != NULL) {
    producer = server_address;
    pos[0] = '\0';
    pos++;
    server_address = pos;

    pos = strchr(producer, ':');

    if (pos != NULL) {
      pos[0] = '\0';
      pos++;
      protocol = pos;

      if (strcmp(protocol, "udp") == 0)
        use_udp = true;
    }

    setLogProducer(producer);
  }

  port = strchr(server_address, ':');

  if(port != NULL) {
    port[0] = '\0';
    port++;
    server_port = atoi(port);
  } else {
    throw("bad tcp bind address format"); 
  }
  
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Starting %s collector on %s:%d", 
    use_udp ? "UDP" : "TCP", server_address, server_port);

  listen_sock = socket(AF_INET, use_udp ? SOCK_DGRAM : SOCK_STREAM, 0);

  if(listen_sock < 0)
    throw("socket error");

  /* Allow to re-bind in case previous instance died */ 
  if(setsockopt(listen_sock, SOL_SOCKET, SO_REUSEADDR,
#ifdef WIN32
  (const char*)
#endif
	  &reuse, sizeof(reuse)) != 0)
    throw("setsockopt error");
  
  memset(&listen_addr, 0, sizeof(listen_addr));

  listen_addr.sin_family = AF_INET;
  listen_addr.sin_addr.s_addr = inet_addr(server_address);
  listen_addr.sin_port = htons(server_port);
 
  if(bind(listen_sock, (struct sockaddr *) &listen_addr, sizeof(struct sockaddr)) != 0)
    throw("bind error");

  if (!use_udp) { 
    if(listen(listen_sock, MAX_SYSLOG_SUBSCRIBERS) != 0)
      throw("listen error");
  }

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Accepting connections on %s:%d",
    server_address, server_port);

  for(i = 0; i < MAX_SYSLOG_SUBSCRIBERS; ++i)
    connections[i].socket = 0;

  free(tmp);
}

/* **************************************************** */

SyslogCollectorInterface::~SyslogCollectorInterface() {
  
  close(listen_sock);

  for(int i = 0; i < MAX_SYSLOG_SUBSCRIBERS; ++i)
    if(connections[i].socket != 0)
      close(connections[i].socket);

  free(endpoint);
}

/* **************************************************** */

int SyslogCollectorInterface::initFDSets(fd_set *read_fds, fd_set *write_fds, fd_set *except_fds) {
  int i;
  
  FD_ZERO(read_fds);
  FD_ZERO(write_fds);
  FD_ZERO(except_fds);

  FD_SET(listen_sock, read_fds);
  FD_SET(listen_sock, except_fds);

  for(i = 0; i < MAX_SYSLOG_SUBSCRIBERS; ++i) {
    if(connections[i].socket != 0) {
      FD_SET(connections[i].socket, read_fds);
      FD_SET(connections[i].socket, except_fds);
    }
  }
 
  return 0;
}  

/* **************************************************** */

int SyslogCollectorInterface::handleNewConnection() {
  char client_ipv4_str[INET_ADDRSTRLEN];
  struct sockaddr_in client_addr;
  socklen_t client_len = sizeof(client_addr);
  int new_client_sock;
  int i;

  memset(&client_addr, 0, sizeof(client_addr));

  new_client_sock = accept(listen_sock, (struct sockaddr *) &client_addr, &client_len);

  if(new_client_sock < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "accept() failure");
    return -1;
  }
  
  inet_ntop(AF_INET, &client_addr.sin_addr, client_ipv4_str, INET_ADDRSTRLEN);
  
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Incoming connection from %s:%d", client_ipv4_str, client_addr.sin_port);
  
  for(i = 0; i < MAX_SYSLOG_SUBSCRIBERS; ++i) {
    if(connections[i].socket == 0) {
      connections[i].socket = new_client_sock;
      connections[i].address = client_addr;
      return 0;
    }
  }
  
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Too many connections. Closing connection from %s:%d", 
    client_ipv4_str, client_addr.sin_port);

  close(new_client_sock);

  return -1;
}

/* **************************************************** */

char *SyslogCollectorInterface::clientAddr2Str(syslog_client *client, char *buff) {
  char client_ipv4_str[INET_ADDRSTRLEN];

  inet_ntop(AF_INET, &client->address.sin_addr, client_ipv4_str, INET_ADDRSTRLEN);

  sprintf(buff, "%s:%d", client_ipv4_str, client->address.sin_port);
  
  return buff;
}

/* **************************************************** */

void SyslogCollectorInterface::closeConnection(syslog_client *client) {
  char buff[INET_ADDRSTRLEN + 10];

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Closing client socket for %s\n", 
    clientAddr2Str(client, buff));
  
  close(client->socket);
  client->socket = 0;
}

/* **************************************************** */

int SyslogCollectorInterface::receive(int socket) {
  char buffer[8192];
  int len, received_total = 0;
  int buffer_size = sizeof(buffer) - 1;
  char *line, *pos;

  do {
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
      received_total += len;
      buffer[len] = '\0';
      line = strtok_r(buffer, "\n", &pos);
      while (line) {
        recvStats.num_flows += parseLog(line);
        line = strtok_r(NULL, "\n", &pos);
      }
    }

  } while (len > 0);
  
  ntop->getTrace()->traceEvent(TRACE_INFO, "Total received bytes: %u", received_total);

  return 0;
}

/* **************************************************** */

int SyslogCollectorInterface::receiveFromClient(syslog_client *client) {
  char buff[INET_ADDRSTRLEN + 10];

  ntop->getTrace()->traceEvent(TRACE_INFO, "Trying to receive from %s", 
    clientAddr2Str(client, buff));

  return receive(client->socket);
}

/* **************************************************** */

void SyslogCollectorInterface::collect_flows() {
  u_int32_t max_num_polls_before_purge = MAX_SYSLOG_POLLS_BEFORE_PURGE;
  fd_set read_fds, write_fds, except_fds;
  struct timeval timeout;
  time_t now, next_purge_idle = time(NULL) + FLOW_PURGE_FREQUENCY;;
  int high_sock = listen_sock;
  int i, rc;

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Collecting flows on %s", ifname);

  while (isRunning()) {
    while(idle()) {
      purgeIdle(time(NULL));
      sleep(1);
      if(ntop->getGlobals()->isShutdown()) return;
    }

    initFDSets(&read_fds, &write_fds, &except_fds);

    high_sock = listen_sock;
    for(i = 0; i < MAX_SYSLOG_SUBSCRIBERS; i++) {
      if(connections[i].socket > high_sock)
        high_sock = connections[i].socket;
    }

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
          
      if(FD_ISSET(listen_sock, &read_fds)) {
        if (use_udp) {
          if(receive(listen_sock) != 0) {
            ntop->getTrace()->traceEvent(TRACE_ERROR, "Error receiving from socket fd");
            continue;
          }
        } else {
          handleNewConnection();
        }
      }
        
      if(FD_ISSET(listen_sock, &except_fds))
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Exception on listen socket fd");      
      
      if (!use_udp) {
        for(i = 0; i < MAX_SYSLOG_SUBSCRIBERS; ++i) {
          if(connections[i].socket != 0 && FD_ISSET(connections[i].socket, &read_fds)) {
            if(receiveFromClient(&connections[i]) != 0) {
              closeConnection(&connections[i]);
              continue;
            }
          }
  
          if(connections[i].socket != 0 && FD_ISSET(connections[i].socket, &except_fds)) {
            ntop->getTrace()->traceEvent(TRACE_ERROR, "Exception on client fd");
            closeConnection(&connections[i]);
            continue;
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

  iface->collect_flows();

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

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "flows", recvStats.num_flows);
  lua_pushstring(vm, "syslogRecvStats");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

#endif
