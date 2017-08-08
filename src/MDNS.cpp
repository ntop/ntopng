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

MDNS::MDNS(NetworkInterface *iface) {
  if(((udp_sock = socket(AF_INET, SOCK_DGRAM, 0)) == -1)
     || ((batch_udp_sock = socket(AF_INET, SOCK_DGRAM, 0)) == -1))
    throw("Unable to create socket");

  /* Multicast group is 224.0.0.251 */
  gatewayIPv4 = Utils::findInterfaceGatewayIPv4(iface->get_name());

  if(gatewayIPv4) {
    /* Let's check if this resolver is active */
    u_int dns_query_len;
    char mdnsbuf[512];
    u_int16_t tid = gatewayIPv4 & 0xFFFF;
    struct sockaddr_in mdns_dest;
    
    dns_query_len = prepareIPv4ResolveQuery(gatewayIPv4, mdnsbuf, sizeof(mdnsbuf), tid);
    
    mdns_dest.sin_family = AF_INET, mdns_dest.sin_port = htons(53), mdns_dest.sin_addr.s_addr = gatewayIPv4;
    if(sendto(udp_sock, mdnsbuf, dns_query_len, 0, (struct sockaddr *)&mdns_dest, sizeof(struct sockaddr_in)) > 0) {
      fd_set rset;
      struct timeval tv;
      
      FD_ZERO(&rset);
      FD_SET(udp_sock, &rset);
      
      tv.tv_sec = 2, tv.tv_usec = 0;
      if(select(udp_sock + 1, &rset, NULL, NULL, &tv) > 0) {
	struct sockaddr_in from;
	socklen_t from_len = sizeof(from);
	int len = recvfrom(udp_sock, mdnsbuf, sizeof(mdnsbuf), 0, (struct sockaddr *)&from, &from_len);

	if(len > 0)
	  return; /* This is a valid resolver */
      }
    }   

    gatewayIPv4 = 0; /* Invalid */
  }
}

/* ******************************* */

MDNS::~MDNS() {
  if(udp_sock != -1)       close(udp_sock);
  if(batch_udp_sock != -1) close(batch_udp_sock);
}

/* ******************************* */

u_int16_t MDNS::prepareIPv4ResolveQuery(u_int32_t ipv4addr /* network byte order */,
					char *mdnsbuf, u_int mdnsbuf_len,
					u_int16_t tid) {
  u_int16_t last_dot = 0, dns_query_len;
  struct ndpi_dns_packet_header *dns_h = (struct ndpi_dns_packet_header*)mdnsbuf;
  char *queries, query[64], addrbuf[32];

  /*
    dig +short @224.0.0.251 -p 5353 -t PTR 20.2.168.192.in-addr.arpa
  */
  snprintf(query, sizeof(query), "%s.in-addr.arpa",
	   Utils::intoaV4(ipv4addr, addrbuf, sizeof(addrbuf)));

  dns_h->tr_id = tid;
  dns_h->flags = 0 /* query */;
  dns_h->num_queries = htons(1);
  dns_h->num_answers = 0;
  dns_h->authority_rrs = 0;
  dns_h->additional_rrs = 0;
  queries = &mdnsbuf[sizeof(struct ndpi_dns_packet_header)];

  mdnsbuf_len -= sizeof(struct ndpi_dns_packet_header) + 4;

  for(dns_query_len=0; (query[dns_query_len] != '\0')
	&& (dns_query_len < mdnsbuf_len); dns_query_len++) {
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

  return(dns_query_len);
}

/* ******************************* */

char* MDNS::decodePTRResponse(char *mdnsbuf, u_int mdnsbuf_len,
			      char *buf, u_int buf_len,
			      u_int32_t *resolved_ip) {
  struct ndpi_dns_packet_header *dns_h = (struct ndpi_dns_packet_header*)mdnsbuf;
  u_int offset = 0, i, idx, to_skip = ntohs(dns_h->num_queries);
  char *queries = &mdnsbuf[sizeof(struct ndpi_dns_packet_header)];

  mdnsbuf_len -= sizeof(struct ndpi_dns_packet_header);
  *resolved_ip = 0;

  /* Skip queries */
  for(i=0, idx=0; (i<to_skip) && (offset < (u_int)mdnsbuf_len); ) {
    if(queries[offset] != 0) {
      if(queries[offset] < 32)
	buf[idx] = '.';
      else
	buf[idx] = queries[offset];

      offset++, idx++;
      continue;
    } else {
      if(i == 0) {
	int a, b, c, d;

	buf[idx] = '\0';

	if(sscanf(buf, ".%d.%d.%d.%d.", &a, &b, &c, &d) == 4)
	  *resolved_ip = ((d & 0xFF) << 24) + ((c & 0xFF) << 16) + ((b & 0xFF) << 8) + (a & 0xFF);
      }

      offset += 4, idx = 0;
      i++; /* Found one query */
    }
  }

  /* Time to decode response. We consider only the first one */
  offset += 14;

  for(idx=0; (offset < mdnsbuf_len) && (queries[offset] != '\0') && (idx < buf_len); offset++, idx++) {
    if(queries[offset] < 32)
      buf[idx] = '.';
    else
      buf[idx] = queries[offset];
  }

  /* As the response ends in ".local" let's cut it */
  if((idx > 6) && (strncmp(&buf[idx], ".local", 6) == 0))
    idx -= 6;

  buf[idx] = '\0';

  return(buf);
}

/* ******************************* */

char* MDNS::resolveIPv4(u_int32_t ipv4addr /* network byte order */,
			char *buf, u_int buf_len, u_int timeout_sec) {
  u_int dns_query_len;
  char mdnsbuf[512];
  u_int16_t tid = ipv4addr & 0xFFFF;
  struct sockaddr_in mdns_dest;

  buf[0] = '\0';
  dns_query_len = prepareIPv4ResolveQuery(ipv4addr, mdnsbuf, sizeof(mdnsbuf), tid);

  if(timeout_sec == 0) timeout_sec = 1;

  mdns_dest.sin_family = AF_INET, mdns_dest.sin_port = htons(5353), mdns_dest.sin_addr.s_addr = ipv4addr;
  if(sendto(udp_sock, mdnsbuf, dns_query_len, 0, (struct sockaddr *)&mdns_dest, sizeof(struct sockaddr_in)) < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Send error [%d/%s]", errno, strerror(errno));
    return(buf);
  }

  while(true) {
    fd_set rset;
    struct timeval tv;

    FD_ZERO(&rset);
    FD_SET(udp_sock, &rset);

    tv.tv_sec = timeout_sec, tv.tv_usec = 0;
    if(select(udp_sock + 1, &rset, NULL, NULL, &tv) > 0) {
      struct sockaddr_in from;
      socklen_t from_len = sizeof(from);
      int len = recvfrom(udp_sock, mdnsbuf, sizeof(mdnsbuf), 0, (struct sockaddr *)&from, &from_len);
      struct ndpi_dns_packet_header *dns_h = (struct ndpi_dns_packet_header*)mdnsbuf;
      u_int32_t resolved_ip;
      
      if((len > 0) && (dns_h->tr_id == tid) && (ntohs(dns_h->num_answers) > 0)) {
	decodePTRResponse(mdnsbuf, (u_int)len, buf, buf_len, &resolved_ip);
	break;
      }
    } else
      break;
  }

  return(buf);
}

/* ******************************* */

bool MDNS::queueResolveIPv4(u_int32_t ipv4addr, bool alsoUseGatewayDNS) {
  u_int dns_query_len;
  char mdnsbuf[512];
  u_int16_t tid = ipv4addr & 0xFFFF;
  struct sockaddr_in mdns_dest;

  dns_query_len = prepareIPv4ResolveQuery(ipv4addr, mdnsbuf, sizeof(mdnsbuf), tid);

  mdns_dest.sin_family = AF_INET, mdns_dest.sin_port = htons(5353), mdns_dest.sin_addr.s_addr = ipv4addr;
  if(sendto(batch_udp_sock, mdnsbuf, dns_query_len, 0, (struct sockaddr *)&mdns_dest, sizeof(struct sockaddr_in)) < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Send error [%d/%s]", errno, strerror(errno));
    return(false);
  }

  if(alsoUseGatewayDNS && (gatewayIPv4 != 0)) {
    mdns_dest.sin_family = AF_INET, mdns_dest.sin_port = htons(53), mdns_dest.sin_addr.s_addr = gatewayIPv4;
    if(sendto(batch_udp_sock, mdnsbuf, dns_query_len, 0, (struct sockaddr *)&mdns_dest, sizeof(struct sockaddr_in)) < 0) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Send error [%d/%s]", errno, strerror(errno));
      return(false);
    }
  }

  return(true);
}

/* ******************************* */

void MDNS::fetchResolveResponses(lua_State* vm, int32_t timeout_sec) {
  lua_newtable(vm);

  while(true) {
    fd_set rset;
    struct timeval tv;

    FD_ZERO(&rset);
    FD_SET(batch_udp_sock, &rset);

    tv.tv_sec = timeout_sec, tv.tv_usec = 0;

    if(select(batch_udp_sock + 1, &rset, NULL, NULL, &tv) > 0) {
      struct sockaddr_in from;
      char src[32], mdnsbuf[512], buf[128];
      socklen_t from_len = sizeof(from);
      int len = recvfrom(batch_udp_sock, mdnsbuf, sizeof(mdnsbuf), 0, (struct sockaddr *)&from, &from_len);
      struct ndpi_dns_packet_header *dns_h = (struct ndpi_dns_packet_header*)mdnsbuf;
      
      if((len > 0) && (ntohs(dns_h->num_answers) > 0)) {
	u_int32_t resolved_ip;
	char *dot;
	
	decodePTRResponse(mdnsbuf, (u_int)len, buf, sizeof(buf), &resolved_ip);

	if(resolved_ip == 0)
	  resolved_ip = ntohl(from.sin_addr.s_addr);

	if((dot = strchr(buf, '.')) != NULL)
	  dot[0] = '\0';
	
	lua_push_str_table_entry(vm, Utils::intoaV4(resolved_ip, src, sizeof(src)), buf);
      }
    } else
      break;
  }
}
