/*
 *
 * (C) 2013-18 - ntop.org
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
  char errbuf[PCAP_ERRBUF_SIZE];
  iface = _iface;

  char *ifname  = iface->altDiscoverableName();
  if(ifname == NULL)
    ifname = iface->get_name();

#if ! defined(__arm__)
  if((pd = pcap_open_live(ifname, 128 /* snaplen */, 0 /* no promisc */, 5, errbuf)) == NULL) {
#else
  /* pcap_next can really block a lot if we do not activate immediate mode! See https://github.com/mfontanini/libtins/issues/180 */
  if(((pd = pcap_create(ifname, errbuf)) == NULL) ||
		(pcap_set_timeout(pd, 5) != 0) ||
		(pcap_set_snaplen(pd, 128) != 0) ||
		(pcap_set_immediate_mode(pd, 1) != 0) || /* enable immediate mode */
		(pcap_activate(pd) != 0)) {
#endif
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to create pcap socket on %s [%d/%s]", ifname, errno, strerror(errno));
	udp_sock = -1;
	throw("Unable to start network discovery");
  } else {
    const char* bpfFilter = "arp && arp[6:2] = 2";  // arp[x:y] - from byte 6 for 2 bytes (arp.opcode == 2 -> reply)
    struct bpf_program fcode;

    /* Set ARP filter */
    if(pcap_compile(pd, &fcode, bpfFilter, 1, 0xFFFFFF00) == 0)
      pcap_setfilter(pd, &fcode);
  }

  if ((udp_sock = socket(AF_INET, SOCK_DGRAM, 0)) != -1) {
	  int rc;

	  errno = 0;
	  rc = Utils::bindSockToDevice(udp_sock, AF_INET, ifname);

	  if ((rc < 0) && (errno != 0)) {
		  ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to bind socket to %s [%d/%s]",
			  ifname, errno, strerror(errno));
	  }
  }
  else
	  throw("Unable to start network discovery");
}

/* ******************************* */

NetworkDiscovery::~NetworkDiscovery() {
  if(pd)             pcap_close(pd);
  if(udp_sock != -1) close(udp_sock);
}

/* ******************************************* */

u_int32_t NetworkDiscovery::wrapsum(u_int32_t sum) {
  sum = ~sum & 0xFFFF;
  return(htons(sum));
}
/* ******************************* */

u_int16_t NetworkDiscovery::in_cksum(u_int8_t *buf, u_int16_t buf_len, u_int32_t sum) {
  u_int i;

  for(i = 0; i < (buf_len & ~1U); i += 2) {
    sum += (u_int16_t)ntohs(*((u_int16_t *)(buf + i)));
    if(sum > 0xFFFF) sum -= 0xFFFF;
  }

  if(i < buf_len) {
    sum += buf[i] << 8;
    if(sum > 0xFFFF) sum -= 0xFFFF;
  }

  return sum;
}

/* ******************************* */

/*
   Code portions courtesy of Andrea Zerbinati <zeran23@gmail.com>
   and Luca Peretti <lucaperetti.lp@gmail.com>
*/
void NetworkDiscovery::arpScan(lua_State* vm) {
  bpf_u_int32 netp, maskp;
  u_int32_t first_ip, last_ip, host_ip, sender_ip;
  char macbuf[32], ipbuf[32], mdnsbuf[256];
  u_char mdnsreply[1500];
  const u_int max_num_ips = 1024;
  struct arp_packet arp, *reply;
  fd_set rset;
  struct timeval tv;
  struct pcap_pkthdr h;
  int mdns_sock, max_sock = 0;
  ndpi_dns_packet_header *dns_h;
  u_int dns_query_len;
  struct sockaddr_in mdns_dest;
  int fd = -1;
  char *ifname  = iface->altDiscoverableName();

#ifndef WIN32
  fd = pcap_get_selectable_fd(pd);
#endif

  if(ifname == NULL)
    ifname = iface->get_name();

  if(!pd) return;
  sender_ip = Utils::readIPv4(ifname);

  lua_newtable(vm);

  iface->getIPv4Address(&netp, &maskp);

  /* Purge existing packets */

  while(!ntop->getGlobals()->isShutdown()) {
    fd_set rset;
    struct timeval tv;
    
    FD_ZERO(&rset);
    FD_SET(fd, &rset);
    
    tv.tv_sec = 0, tv.tv_usec = 0;
    if(select(fd + 1, &rset, NULL, NULL, &tv) > 0)
      pcap_next(pd, &h);
    else
      break;
  }
  
  if(ntop->getGlobals()->isShutdown()) return;

  if((mdns_sock = socket(AF_INET, SOCK_DGRAM, 0)) == -1)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to create MDNS socket");
  else {
    const char* anyservices = "_services._dns-sd._udp.local";
    u_int last_dot = 0;
    char *queries;

    if(mdns_sock > max_sock) max_sock = mdns_sock;
    dns_h = (struct ndpi_dns_packet_header*)mdnsbuf;
    dns_h->tr_id = 0;
    dns_h->flags = 0 /* query */;
    dns_h->num_queries = htons(1);
    dns_h->num_answers = 0;
    dns_h->authority_rrs = 0;
    dns_h->additional_rrs = 0;
    queries = &mdnsbuf[sizeof(struct ndpi_dns_packet_header)];

    dns_h->tr_id = htons(0);

    for(dns_query_len=0; anyservices[dns_query_len] != '\0'; dns_query_len++) {
      if(anyservices[dns_query_len] == '.') {
	queries[last_dot] = dns_query_len-last_dot;
	last_dot = dns_query_len+1;
      } else
	queries[dns_query_len+1] = anyservices[dns_query_len];
    }

    dns_query_len++;
    queries[last_dot] = dns_query_len-last_dot-1;
    queries[dns_query_len++] = '\0';

    queries[dns_query_len++] = 0x00; queries[dns_query_len++] = 0x0C; /* PTR */
    queries[dns_query_len++] = 0x00; queries[dns_query_len++] = 0x01; /* IN */
    dns_query_len += sizeof(struct ndpi_dns_packet_header);
  }

  if(ntop->getGlobals()->isShutdown()) return;

  netp = ntohl(netp), maskp = ntohl(maskp);
  first_ip = netp & maskp, last_ip = netp + (~maskp);
  first_ip++, last_ip--;

  if((last_ip - first_ip) > max_num_ips)
    last_ip = first_ip + max_num_ips;

  Utils::readMac(ifname, arp.arph.arp_sha);

  memset(arp.dst_mac, 0xFF, sizeof(arp.dst_mac));
  memcpy(arp.src_mac, arp.arph.arp_sha, sizeof(arp.src_mac));
  arp.proto  = htons(0x0806 /* ARP */);
  arp.arph.ar_hrd = htons(1);
  arp.arph.ar_pro = htons(0x0800);
  arp.arph.ar_hln = 6;
  arp.arph.ar_pln = 4;
  arp.arph.ar_op = htons(1 /* ARP Request */);
  arp.arph.arp_spa = sender_ip;
  memset(arp.arph.arp_tha, 0, sizeof(arp.arph.arp_tha));

  /* Let's add myself */
  lua_push_str_table_entry(vm,
			   Utils::formatMac(arp.arph.arp_sha, macbuf, sizeof(macbuf)),
			   Utils::intoaV4(ntohl(arp.arph.arp_spa), ipbuf, sizeof(ipbuf)));

  mdns_dest.sin_family = AF_INET, mdns_dest.sin_port = htons(5353);

  for(int num_runs=0; num_runs<2; num_runs++) {
    for(host_ip = first_ip; host_ip <last_ip; host_ip++) {
      int sel_rc = 0;

      arp.arph.arp_tpa = ntohl(host_ip);

      if(arp.arph.arp_tpa == arp.arph.arp_spa)
	continue; /* I know myself already */

      // Inject packet
      if(pcap_sendpacket(pd, (const u_char*)&arp, sizeof(arp)) == -1)
	break;

      FD_ZERO(&rset);

      if(fd != -1) {
	FD_SET(fd, &rset);
	if(fd > max_sock) max_sock = fd;
      }
      if(mdns_sock != -1) FD_SET(mdns_sock, &rset);

      tv.tv_sec = 0, tv.tv_usec = 0; /* Don't wait at all */

      if(max_sock != 0)
	sel_rc = select(max_sock + 1, &rset, NULL, NULL, &tv);

      if((fd == -1) || FD_ISSET(fd, &rset))
	reply = (struct arp_packet*)pcap_next(pd, &h);
      else
	reply = NULL;

      if(reply) {
	lua_push_str_table_entry(vm,
				 Utils::formatMac(reply->arph.arp_sha, macbuf, sizeof(macbuf)),
				 Utils::intoaV4(ntohl(reply->arph.arp_spa), ipbuf, sizeof(ipbuf)));

	ntop->getTrace()->traceEvent(TRACE_INFO, "Received ARP reply from %s",
				     Utils::intoaV4(ntohl(reply->arph.arp_spa), ipbuf, sizeof(ipbuf)));

	if(mdns_sock != -1) {
	  mdns_dest.sin_addr.s_addr = reply->arph.arp_spa, dns_h->tr_id++;
	  if(sendto(mdns_sock, mdnsbuf, dns_query_len, 0, (struct sockaddr *)&mdns_dest, sizeof(struct sockaddr_in)) < 0)
	    ntop->getTrace()->traceEvent(TRACE_ERROR, "MDNS Send error [%d/%s]", errno, strerror(errno));
	}
      }

      if((sel_rc > 0) && FD_ISSET(mdns_sock, &rset)) {
	struct sockaddr_in from;
	socklen_t from_len = sizeof(from);
	int len = recvfrom(mdns_sock, (char*)mdnsreply, sizeof(mdnsreply), 0, (struct sockaddr *)&from, &from_len);

	if(len > 0) {
	  char outbuf[1024];

	  dissectMDNS(mdnsreply, len, outbuf, sizeof(outbuf));

	  if(outbuf[0] != '\0')
	    lua_push_str_table_entry(vm,
				     Utils::intoaV4(ntohl(from.sin_addr.s_addr), ipbuf, sizeof(ipbuf)),
				     outbuf);
	}
      }

      _usleep(1000); /* Avoid flooding */
    }
  }

  /* Query myself mith MDNS */
  mdns_dest.sin_addr.s_addr = sender_ip, dns_h->tr_id++;
  errno = 0;
  if((sendto(mdns_sock, mdnsbuf, dns_query_len, 0, (struct sockaddr *)&mdns_dest, sizeof(struct sockaddr_in)) < 0) && (errno != 0))
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Send error [%d/%s]", errno, strerror(errno));

  /* Final rush */
  while(true) {
    if(fd != -1) {
      fd_set rset;
      struct timeval tv;
      
      FD_ZERO(&rset);
      FD_SET(fd, &rset);
      
      tv.tv_sec = 0, tv.tv_usec = 0;
      if(select(fd + 1, &rset, NULL, NULL, &tv) <= 0)
	break;
    }

    if((reply = (struct arp_packet*)pcap_next(pd, &h)) != NULL) {
      lua_push_str_table_entry(vm,
			       Utils::formatMac(reply->arph.arp_sha, macbuf, sizeof(macbuf)),
			       Utils::intoaV4(ntohl(reply->arph.arp_spa), ipbuf, sizeof(ipbuf)));

      ntop->getTrace()->traceEvent(TRACE_INFO, "Received ARP reply from %s",
				   Utils::intoaV4(ntohl(reply->arph.arp_spa), ipbuf, sizeof(ipbuf)));
      mdns_dest.sin_addr.s_addr = reply->arph.arp_spa, dns_h->tr_id++;
      if(sendto(mdns_sock, mdnsbuf, dns_query_len, 0, (struct sockaddr *)&mdns_dest, sizeof(struct sockaddr_in)) < 0)
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Send error [%d/%s]", errno, strerror(errno));
    } else
      break;
  }

  if(mdns_sock != -1) {
    while(true) {
      FD_ZERO(&rset);
      FD_SET(mdns_sock, &rset);

      tv.tv_sec = 1, tv.tv_usec = 0;
      if(select(max_sock + 1, &rset, NULL, NULL, &tv) > 0) {
	struct sockaddr_in from;
	socklen_t from_len = sizeof(from);
	int len = recvfrom(mdns_sock, (char*)mdnsreply, sizeof(mdnsreply), 0, (struct sockaddr *)&from, &from_len);

	if(len > 0) {
	  char outbuf[1024];

	  dissectMDNS(mdnsreply, len, outbuf, sizeof(outbuf));
	  lua_push_str_table_entry(vm,
				   Utils::intoaV4(ntohl(from.sin_addr.s_addr), ipbuf, sizeof(ipbuf)),
				   outbuf);
	}
      } else
	break;
    }

    closesocket(mdns_sock);
  }
}

/* ******************************* */

u_int16_t NetworkDiscovery::buildMDNSDiscoveryDatagram(const char *query,
						       u_int32_t sender_ip, u_int8_t *sender_mac,
						       char *pbuf, u_int pbuf_len) {
  struct ndpi_ethhdr *eth = (struct ndpi_ethhdr*)pbuf;
  struct ndpi_iphdr *iph = (struct ndpi_iphdr *)(&pbuf[sizeof(struct ndpi_ethhdr)]);
  struct ndpi_udphdr *udph = (struct ndpi_udphdr *)&pbuf[sizeof(struct ndpi_ethhdr) +sizeof(struct ndpi_iphdr)];
  u_int last_dot = 0, dns_query_len, tot_len;
  struct ndpi_dns_packet_header *dns_h;
  char *queries, *data;
  const u_int8_t multicast_mac[] = { 0x01, 0x00, 0x5E, 0x00, 0x00, 0xFB };
  u_int16_t dns_request_id = time(NULL) & 0xFFFF;

  memset(pbuf, 0, pbuf_len);

  memcpy(eth->h_dest, multicast_mac, sizeof(struct ndpi_ethhdr));
  memcpy(eth->h_source, sender_mac, sizeof(struct ndpi_ethhdr));
  eth->h_proto = htons(0x0800);

  data = &pbuf[sizeof(struct ndpi_ethhdr) + sizeof(struct ndpi_iphdr) + sizeof(struct ndpi_udphdr)];
  dns_h = (struct ndpi_dns_packet_header*)data;
  dns_h->tr_id = 0;
  dns_h->flags = 0 /* query */;
  dns_h->num_queries = htons(1);
  dns_h->num_answers = 0;
  dns_h->authority_rrs = 0;
  dns_h->additional_rrs = 0; // htons(1);
  queries = &data[sizeof(struct ndpi_dns_packet_header)];

  dns_h->tr_id = htons(dns_request_id);

  for(dns_query_len=0; query[dns_query_len] != '\0'; dns_query_len++) {
    if(query[dns_query_len] == '.') {
      queries[last_dot] = dns_query_len-last_dot;
      last_dot = dns_query_len+1;
    } else
      queries[dns_query_len+1] = query[dns_query_len];
  }

  dns_query_len++;
  queries[last_dot] = dns_query_len-last_dot-1;
  queries[dns_query_len++] = '\0';

  queries[dns_query_len++] = 0x00; queries[dns_query_len++] = 0x0C; /* PTR */
  queries[dns_query_len++] = 0x00; queries[dns_query_len++] = 0x01; /* IN */
  dns_query_len += sizeof(struct ndpi_dns_packet_header);

  // Fill in the IP Header
  iph->ihl = 5;
  iph->version = 4;
  iph->tos = 0;
  iph->tot_len = sizeof(struct ndpi_iphdr) + sizeof (struct ndpi_udphdr) + dns_query_len;
  iph->id = htons(dns_request_id); //Id of this packet
  iph->frag_off = htons(0);
  iph->ttl = 255;
  iph->protocol = IPPROTO_UDP;
  iph->saddr = sender_ip;
  iph->daddr = inet_addr("224.0.0.251");

  // UDP header
  udph->source = htons(5353);
  udph->dest = htons(5353);
  udph->len = htons(8 + dns_query_len); //tcp header size
  udph->check = 0; //leave in_cksum 0 now, filled later by pseudo header

  tot_len = iph->tot_len + sizeof(struct ndpi_ethhdr);
  iph->tot_len = htons(iph->tot_len);

  iph->check = wrapsum(in_cksum((u_int8_t *)iph, sizeof(struct ndpi_iphdr), 0));

  udph->check = wrapsum(in_cksum((unsigned char *)udph, sizeof(struct ndpi_udphdr),
				 in_cksum((unsigned char *)data, dns_query_len,
					  in_cksum((unsigned char *)&iph->saddr,
						   2*sizeof(iph->saddr),
						   IPPROTO_UDP + ntohs(udph->len)))));

  return(tot_len);
}

/* ******************************* */

void NetworkDiscovery::dissectMDNS(u_char *buf, u_int buf_len,
				   char *out, u_int out_len) {
  ndpi_dns_packet_header *dns_h = (struct ndpi_dns_packet_header*)buf;
  u_int num_queries, num_answers, i, offset, idx;
  u_char *queries, rspbuf[64];

  out[0] = '\0';
  if(buf_len < sizeof(struct ndpi_dns_packet_header)) return;

  num_queries = ntohs(dns_h->num_queries), num_answers = ntohs(dns_h->num_answers);

  if(num_answers == 0) return;

  /* Skip queries */
  queries  = (u_char*)&buf[sizeof(struct ndpi_dns_packet_header)];
  buf_len -= sizeof(struct ndpi_dns_packet_header);

  for(i=0, offset=0; (i<num_queries) && (offset < (u_int)buf_len); ) {
    if(queries[offset] != 0) {
      offset++;
      continue;
    } else {
      offset += 4;
      i++; /* Found one query */
    }
  }

  offset += 1; /* Move to the first response byte */

  /* Decode replies */
  for(i=0; (i<num_answers) && (offset < (u_int)buf_len); ) {
    u_int16_t data_len;

    if(num_queries > 0)
      offset += 2 /* query */ + 2 /* type */ + 2 /* class */ + 4 /* TTL */;

    data_len = ntohs(*((u_int16_t*)&queries[offset]));

    if(data_len < buf_len) {
      u_int l;

      offset += 3;

      memset(rspbuf, 0, sizeof(rspbuf));

      for(idx = 0; idx<data_len; idx++, offset++) {
	if(queries[offset] < 32) {
	  rspbuf[idx] = '.';
	} else {
	  if(queries[offset] == 0xc0) {
	    u_int8_t new_offset = queries[offset+1];

	    offset++;
	    // ntop->getTrace()->traceEvent(TRACE_ERROR, "new_offset=%u", new_offset);

	    while((idx < sizeof(rspbuf)) && (buf[new_offset] != 0)){
	      if(buf[new_offset] < 32)
		rspbuf[idx] = '.';
	      else if(buf[new_offset] == 0xc0) {
		new_offset = buf[new_offset+1];
		continue;
	      } else
		rspbuf[idx] = buf[new_offset];

	      new_offset++, idx++;
	    }
	  } else
	    rspbuf[idx] = queries[offset];
	}
      }

      rspbuf[idx] = '\0';
      // ntop->getTrace()->traceEvent(TRACE_INFO, "%s", rspbuf);

      l = strlen(out);
      snprintf(&out[l], out_len-l, "%s%s",
	       (l > 0) ? ";" : "", rspbuf);
      i++;
    } else
      break;
  }
}

/* ******************************* */

/*
   Example:
   dig +short @192.168.2.20 -p 5353 -t any _services._dns-sd._udp.local
*/
void NetworkDiscovery::discover(lua_State* vm, u_int timeout) {
  struct sockaddr_in sin;
  char msg[1024];
  u_int16_t ssdp_port = htons(1900);
  struct timeval tv = { (time_t)timeout /* sec */, 0 };
  fd_set fdset;

  char *ifname  = iface->altDiscoverableName();
  if(ifname == NULL)
    ifname = iface->get_name();

  lua_newtable(vm);

  if(!pd) return;
  if(udp_sock == -1) return;

  if(timeout < 1) timeout = 1;

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

  if(sendto(udp_sock, msg, strlen(msg), 0, (struct sockaddr *)&sin, sizeof(struct sockaddr_in)) < 0)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Send error [%d/%s]", errno, strerror(errno));

#ifdef MDNS_MULTICAST_DISCOVERY
  /* MDNS */
  {
    dump_mac_t sender_mac;
    const char *query_list[] = {
      "_sftp-ssh._tcp.local",
      "_homekit._tcp.local.",
      "_smb._tcp.local",
      "_afpovertcp._tcp.local",
      "_ssh._tcp.local",
      "_nfs._tcp.local",
      "_airplay._tcp.local",
      "_googlecast._tcp.local",
      NULL
    };
    int i;
    u_int32_t sender_ip = Utils::readIPv4(ifname);

    Utils::readMac(ifname, sender_mac);

    for(i=0; query_list[i] != NULL; i++) {
      u_int16_t len = buildMDNSDiscoveryDatagram(query_list[i], sender_ip, sender_mac, msg, sizeof(msg));

      if(pcap_sendpacket(pd, msg, len) == -1)
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Send error [%d/%s]", errno, strerror(errno));
      else
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Sent MDNS request [%s][len: %u]", query_list[i], len);
    }
  }
#endif /* MDNS_MULTICAST_DISCOVERY */

  /* Receive replies */
  FD_ZERO(&fdset);
  FD_SET(udp_sock, &fdset);

  while(select(udp_sock + 1, &fdset, NULL, NULL, &tv) > 0) {
    struct sockaddr_in from = { 0 };
    socklen_t s = sizeof(from);
    char ipbuf[32];
    int len = recvfrom(udp_sock, (char*)msg, sizeof(msg), 0, (sockaddr*)&from, &s);
    
    ntop->getTrace()->traceEvent(TRACE_INFO, "Received SSDP packet from %s:%u",
				 Utils::intoaV4(ntohl(from.sin_addr.s_addr), ipbuf, sizeof(ipbuf)),
				 ntohs(from.sin_port));

    if(len > 0) {
      char src[32], *host = Utils::intoaV4(ntohl(from.sin_addr.s_addr), src, sizeof(src));
      char *line, *tmp;

      msg[len] = '\0';

      // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[SSDP] %s", msg);

      line = strtok_r(msg, "\n", &tmp); /* HTTP/1.1 200 OK */

      if(line) {
	while((line = strtok_r(NULL, "\r", &tmp)) != NULL) {
	  while((line[0] == '\n') || (line[0] == '\r'))line++;
	  if(strncasecmp(line, "Location:", 9) == 0) {
	    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s] %s", host, &line[10]);
	    lua_push_str_table_entry(vm, &line[10], host);
	  }
	}
      }
    } else
      break;
  }
}
