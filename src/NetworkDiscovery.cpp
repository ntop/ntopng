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
  char errbuf[PCAP_ERRBUF_SIZE];
  iface = _iface;

  if((udp_sock = socket(AF_INET, SOCK_DGRAM, 0)) != -1) {
    int rc = Utils::bindSockToDevice(udp_sock, AF_INET, iface->get_name());

    if(rc < 0) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to bind socket to %s [%d/%s]",
				   iface->get_name(), errno, strerror(errno));
      close(udp_sock);
      udp_sock = -1;
      throw("Unable to start network discovery");
    }
  }

  if((pd = pcap_open_live(iface->get_name(), 128 /* snaplen */, 0 /* no promisc */, 500, errbuf)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to create pcap socket [%d/%s]", errno, strerror(errno));
  } else {
    const char* bpfFilter = "arp && arp[6:2] = 2";  // arp[x:y] - from byte 6 for 2 bytes (arp.opcode == 2 -> reply)
    struct bpf_program fcode;

    /* Set ARP filter */
    if(pcap_compile(pd, &fcode, bpfFilter, 1, 0xFFFFFF00) == 0)
      pcap_setfilter(pd, &fcode);

    pd_fd = pcap_get_selectable_fd(pd);
  }
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
  bpf_u_int32 maskp, netp;
  u_int32_t first_ip, last_ip, host_ip, sender_ip = Utils::readIPv4(iface->get_name());
  char macbuf[32], ipbuf[32];
  const u_int max_num_ips = 1024;
  struct arp_packet arp, *reply;
  fd_set rset;
  struct timeval tv;
  struct pcap_pkthdr h;
  char errbuf[PCAP_ERRBUF_SIZE];

  lua_newtable(vm);

  if(!pd) return;

  if(pcap_lookupnet(iface->get_name(), &netp, &maskp, errbuf) == -1) {
    /* Np IP/mask: can't do much then */
    return;
  }

  netp = ntohl(netp), maskp = ntohl(maskp);
  first_ip = netp & maskp, last_ip = netp + (~maskp);
  first_ip++, last_ip--;

  if((last_ip - first_ip) > max_num_ips)
    last_ip = first_ip + max_num_ips;

  Utils::readMac(iface->get_name(), arp.arp_sha);

  memset(arp.dst_mac, 0xFF, sizeof(arp.dst_mac));
  memcpy(arp.src_mac, arp.arp_sha, sizeof(arp.src_mac));
  arp.proto  = htons(0x0806 /* ARP */);
  arp.ar_hrd = htons(1);
  arp.ar_pro = htons(0x0800);
  arp.ar_hln = 6;
  arp.ar_pln = 4;
  arp.ar_op = htons(1 /* ARP Request */);
  arp.arp_spa = sender_ip;
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
      FD_SET(pd_fd, &rset);

      tv.tv_sec = 0, tv.tv_usec = 0; /* Don't wait at all */

      if(select(pd_fd + 1, &rset, NULL, NULL, &tv) > 0) {
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
}

/* ******************************* */

unsigned short csum(unsigned short *buf, int nwords){
  unsigned long sum;
  for (sum = 0; nwords > 0; nwords--)
    sum += *buf++;
  sum = (sum >> 16) + (sum & 0xffff);
  sum += (sum >> 16);
  return ~sum;
}

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

/* dig +short @192.168.2.35 -p 5353 -t any _services._dns-sd._udp.local */
void NetworkDiscovery::discover(lua_State* vm, u_int timeout) {
  struct sockaddr_in sin;
  char msg[1024];
  u_int32_t sender_ip = Utils::readIPv4(iface->get_name());
  u_int16_t ssdp_port = htons(1900), i;
  struct timeval tv = { (time_t)timeout /* sec */, 0 };
  fd_set fdset;
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

  lua_newtable(vm);

  if(!pd) return;
  if(udp_sock == -1) return;

  if(timeout < 1) timeout = 1;

  /* SSDP */
  sin.sin_addr.s_addr = inet_addr("239.255.255.250"),
    sin.sin_family = AF_INET, sin.sin_port = ssdp_port;

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

  /* MDNS */
  {
    dump_mac_t sender_mac;

    Utils::readMac(iface->get_name(), sender_mac);

    for(i=0; query_list[i] != NULL; i++) {
      u_int16_t len = buildMDNSDiscoveryDatagram(query_list[i], sender_ip, sender_mac, msg, sizeof(msg));

      if(pcap_inject(pd, msg, len) == -1)
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Send error [%d/%s]", errno, strerror(errno));
      else
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Sent MDNS request [%s][len: %u]", query_list[i], len);
    }
  }

  /* Receive replies */
  FD_ZERO(&fdset);
  FD_SET(udp_sock, &fdset);

  while(select(udp_sock + 1, &fdset, NULL, NULL, &tv) > 0) {
    struct sockaddr_in from;
    socklen_t s;
    int len = recvfrom(udp_sock, (char*)msg, sizeof(msg), 0, (struct sockaddr*)&from, &s);

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Received packet from sport %u", ntohs(from.sin_port));

    if(len > 0) {
      char src[32], *host = Utils::intoaV4(ntohl(from.sin_addr.s_addr), src, sizeof(src));
      char *line, *tmp;

      msg[len] = '\0';

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
