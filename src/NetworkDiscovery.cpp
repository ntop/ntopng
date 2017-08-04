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

NetworkDiscovery::NetworkDiscovery(NetworkInterface *_iface) {
  iface = _iface;

  if((sock = socket(AF_INET, SOCK_DGRAM, 0)) != -1) {
#if 0
    int rc = Utils::bindSockToDevice(sock, AF_INET, iface->get_name());

    if(rc < 0) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to bind socket to %s [%d/%s]",
				   iface->get_name(), errno, strerror(errno));
      close(sock);
      sock = -1;
      throw("Unable to start network discovery");
    }
#endif
  }
}

/* ******************************* */

NetworkDiscovery::~NetworkDiscovery() {
  if(sock != -1) close(sock);
}

/* ******************************* */

/*
   Code portions courtesy of Andrea Zerbinati <zeran23@gmail.com>
   and Luca Peretti <lucaperetti.lp@gmail.com>
*/
void NetworkDiscovery::arpScan(lua_State* vm) {
  bpf_u_int32 maskp, netp;
  u_int32_t first_ip, last_ip, host_ip;
  pcap_t *pd;
  char errbuf[PCAP_ERRBUF_SIZE], macbuf[32], ipbuf[32];
  const u_int max_num_ips = 1024;
  struct arp_packet arp, *reply;
  const char* bpfFilter = "arp && arp[6:2] = 2";  // arp[x:y] - from byte 6 for 2 bytes (arp.opcode == 2 -> reply)
  struct bpf_program fcode;
  int fd;
  fd_set rset;
  struct timeval tv;
  struct pcap_pkthdr h;

  lua_newtable(vm);

  if(pcap_lookupnet(iface->get_name(), &netp, &maskp, errbuf) == -1) {
    /* Np IP/mask: can't do much then */
    return;
  }

  netp = ntohl(netp), maskp = ntohl(maskp);
  first_ip = netp & maskp, last_ip = netp + (~maskp);
  first_ip++, last_ip--;

  if((last_ip - first_ip) > max_num_ips)
    last_ip = first_ip + max_num_ips;

  if((pd = pcap_open_live(iface->get_name(), 128 /* snaplen */,
			  0 /* no promisc */,
			  500, errbuf)) == NULL) {
    return;
  }

  /* Set ARP filter */
  if(pcap_compile(pd, &fcode, bpfFilter, 1, 0xFFFFFF00) == 0)
    pcap_setfilter(pd, &fcode);

  fd = pcap_get_selectable_fd(pd);

  Utils::readMac(iface->get_name(), arp.arp_sha);

  memset(arp.dst_mac, 0xFF, sizeof(arp.dst_mac));
  memcpy(arp.src_mac, arp.arp_sha, sizeof(arp.src_mac));
  arp.proto  = htons(0x0806 /* ARP */);
  arp.ar_hrd = htons(1);
  arp.ar_pro = htons(0x0800);
  arp.ar_hln = 6;
  arp.ar_pln = 4;
  arp.ar_op = htons(1 /* ARP Request */);
  arp.arp_spa = Utils::readIPv4(iface->get_name());
  memset(arp.arp_tha, 0, sizeof(arp.arp_tha));

  /* Let's add myself */
  lua_push_str_table_entry(vm,
			   Utils::formatMac(arp.arp_sha, macbuf, sizeof(macbuf)),
			   Utils::intoaV4(ntohl(arp.arp_spa), ipbuf, sizeof(ipbuf)));

  for(int num_runs=0; num_runs<2; num_runs++) {
    for(host_ip = first_ip; host_ip <last_ip; host_ip++) {
      arp.arp_tpa = ntohl(host_ip);

      if(arp.arp_tpa == arp.arp_spa)
	continue; /* I know myself already */

      // Inject packet
      if(pcap_inject(pd, &arp, sizeof(arp)) == -1)
	break;

      FD_ZERO(&rset);
      FD_SET(fd, &rset);

      tv.tv_sec = 0, tv.tv_usec = 0; /* Don't wait at all */

      if(select(fd + 1, &rset, NULL, NULL, &tv) > 0) {
	reply = (struct arp_packet*)pcap_next(pd, &h);

	lua_push_str_table_entry(vm,
				 Utils::formatMac(reply->arp_sha, macbuf, sizeof(macbuf)),
				 Utils::intoaV4(ntohl(reply->arp_spa), ipbuf, sizeof(ipbuf)));
      } else
	_usleep(1000); /* Avoid flooding */
    }
  }
  
  /* Final rush */
  while((reply = (struct arp_packet*)pcap_next(pd, &h)) != NULL) {
    lua_push_str_table_entry(vm,
			     Utils::formatMac(reply->arp_sha, macbuf, sizeof(macbuf)),
			     Utils::intoaV4(ntohl(reply->arp_spa), ipbuf, sizeof(ipbuf)));
  }

  pcap_close(pd);
}

/* ******************************* */

void NetworkDiscovery::discover(lua_State* vm, u_int timeout) {
  struct sockaddr_in sin;
  char msg[1024], *queries;
  bool mdns_discovery = true;
  u_int16_t ssdp_port = htons(1900), mdns_port = htons(5353), i;
  struct timeval tv = { (time_t)timeout /* sec */, 0 };
  fd_set fdset;
  struct ndpi_dns_packet_header *dns_h;
  const char *query_list[] = {
    "_sftp-ssh._tcp.local",
    "_smb._tcp.local",
    "_afpovertcp._tcp.local",
    "_sftp-ssh._tcp.local",
    "_nfs._tcp.local",
    "_airplay._tcp.local",
    "_googlecast._tcp.local",
    NULL
  };
  const u_char additional_mdns[] = { 0x0, 0x0, 0x29, 0x05, 0xa0, 0x0, 0x0, 0x11, 0x94,
				     0x0, 0x12, 0x0, 0x04, 0x0, 0x0e,
				     0x0, 0x79, 0x26, 0x69, 0xf8, 0x58, 0x09, 0x51, 0x04, 0x69,
				     0xf8, 0x58, 0x09, 0x51
  };
    
  lua_newtable(vm);

  if(sock == -1) return;

  if(timeout < 1) timeout = 1;

  /* MDNS */
  memset(&sin, 0, sizeof(sin));
  sin.sin_family = AF_INET, sin.sin_addr.s_addr = htonl(INADDR_ANY), sin.sin_port = mdns_port;
  
  if(bind(sock, (struct sockaddr *)&sin, sizeof(struct sockaddr_in)) == -1) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to bind socket to port %d [%s]", ntohs(sin.sin_port), strerror(errno)); 
    mdns_discovery = false;
  }
  
  /* SSDP */
  sin.sin_addr.s_addr = inet_addr("239.255.255.250"), sin.sin_family = AF_INET, sin.sin_port = ssdp_port;

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

  if(sendto(sock, msg, strlen(msg), 0, (struct sockaddr *)&sin, sizeof(struct sockaddr_in)) < 0)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Send error [%d/%s]", errno, strerror(errno));

  /* MDNS */
  if(mdns_discovery) {
    sin.sin_addr.s_addr = inet_addr("224.0.0.251"), sin.sin_family = AF_INET, sin.sin_port = mdns_port;

    dns_h = (struct ndpi_dns_packet_header*)msg;
    dns_h->tr_id = 0;
    dns_h->flags = 0 /* query */;
    dns_h->num_queries = htons(1);
    dns_h->num_answers = 0;
    dns_h->authority_rrs = 0;
    dns_h->additional_rrs = htons(1);
    queries = &msg[sizeof(struct ndpi_dns_packet_header)];
  
    for(i=0; query_list[i] != NULL; i++) {
      const char *str = query_list[i];
      u_int last_dot = 0;
      int j;
    
      dns_h->tr_id = htons(i);
    
      for(j=1; str[j] != '\0'; j++) {
	if(str[j] == '.') {
	  queries[last_dot] = j-last_dot-1;
	  last_dot = j;
	} else
	  queries[j] = str[j];
      }

      queries[last_dot] = j-last_dot-1;
      queries[j++] = '\0';

      queries[j++] = 0x00; queries[j++] = 0x0C; /* PTR */
      queries[j++] = 0x80; queries[j++] = 0x01; /* IN */

      /* Append additional record */
      memcpy(&queries[j],  additional_mdns, sizeof(additional_mdns));    
      j += sizeof(struct ndpi_dns_packet_header) + sizeof(additional_mdns);

      if(sendto(sock, msg, j, 0, (struct sockaddr *)&sin, sizeof(struct sockaddr_in)) < 0)
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Send error [%d/%s]", errno, strerror(errno));
      else
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Sent MDNS request [%s][len: %u]",
				     str, j);
    }
  }

  /* Receive replies */
  FD_ZERO(&fdset);
  FD_SET(sock, &fdset);

  while(select(sock + 1, &fdset, NULL, NULL, &tv) > 0) {
    struct sockaddr_in from;
    socklen_t s;
    int len = recvfrom(sock, (char*)msg, sizeof(msg), 0, (struct sockaddr*)&from, &s);

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Received packet from sport %u", ntohs(from.sin_port));
      
    if(len > 0) {
      if(from.sin_port == ssdp_port) {
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
      } else if(from.sin_port == mdns_port) {
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Got reply !");	  
      }
    }
  }
}
