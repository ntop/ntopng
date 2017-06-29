/*
 *
 * (C) 2013-17 - ntop.org
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

/* ******************************* */

NetworkDiscovery::NetworkDiscovery(NetworkInterface *iface) {
  if((sock = socket(AF_INET, SOCK_DGRAM, 0)) != -1) {
    int rc = Utils::bindSockToDevice(sock, AF_INET, iface->get_name());
    
    if(rc < 0) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to bind socket to %s [%d/%s]",
				   iface->get_name(), errno, strerror(errno));    
      close(sock);
      sock = -1;
      throw("Unable to start network discovery");
    }
  }
}

/* ******************************* */

NetworkDiscovery::~NetworkDiscovery() {
  if(sock != -1) close(sock);
}

/* ******************************* */

void NetworkDiscovery::discover(lua_State* vm, u_int timeout) {
  struct sockaddr_in sin;
  socklen_t sin_len = sizeof(struct sockaddr_in);
  char msg[1024];

  lua_newtable(vm);
  
  if(sock == -1) return;

  if(timeout < 1) timeout = 1;
  
  sin.sin_addr.s_addr = inet_addr("239.255.255.250"),
    sin.sin_family = AF_INET, sin.sin_port  = htons(1900);

  /*
    ssdp:all : to search all UPnP devices
    upnp:rootdevice: only root devices . Embedded devices will not respond
    uuid:device-uuid: search a device by vendor supplied unique id
    urn:schemas-upnp-org:device:deviceType- version: locates all devices of a given type
    urn:schemas-upnp-org:service:serviceType- version: locate service of a given type
  */
  snprintf(msg, sizeof(msg),
	   "M-SEARCH * HTTP/1.1\r\n"
	   "HOST: 239.255.255.250:1900\r\n"
	   "MAN: \"ssdp:discover\"\r\n" /* Discover all devices */
	   "ST: upnp:rootdevice\r\n" /* Search Target */
	   "USER-AGENT: ntop %s v.%s\r\n"
	   "MX: 3\r\n" /* Maximum wait time (sec) */
	   "\r\n",
	   PACKAGE_MACHINE, PACKAGE_VERSION);

  if(sendto(sock, msg, strlen(msg), 0, (struct sockaddr *)&sin, sin_len) < 0)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Send error [%d/%s]", errno, strerror(errno));    
  else {
    struct timeval tv = { timeout /* sec */, 0 };
    fd_set fdset;
    
    FD_ZERO(&fdset);
    FD_SET(sock, &fdset);
    
    while(select(sock + 1, &fdset, NULL, NULL, &tv) > 0) {
      struct sockaddr_in from;
      socklen_t s;
      int len = recvfrom(sock, (char*)msg, sizeof(msg), 0, (struct sockaddr*)&from, &s);
      
      if(len > 0) {
	char src[32], *host = Utils::intoaV4(ntohl(from.sin_addr.s_addr), src, sizeof(src));
	char *line, *tmp;
	  
	msg[len] = '\0';

	// ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s] %s", host, msg);
	
	line = strtok_r(msg, "\n", &tmp); /* HTTP/1.1 200 OK */

	if(line) {
	  while((line = strtok_r(NULL, "\r", &tmp)) != NULL) {
	    if(strncasecmp(line, "Location:", 9) == 0) {
	      // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s] %s", host, &line[10]);
	      lua_push_str_table_entry(vm, &line[10], host);
	    }
	  }	 
	}
      }
    }            
  }  
}
