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

MDNS::MDNS() {
  if((udp_sock = socket(AF_INET, SOCK_DGRAM, 0)) == -1)
    throw("Unable to create socket");      
}

/* ******************************* */

MDNS::~MDNS() {
  if(udp_sock != -1) close(udp_sock);
}

/* ******************************* */

char* MDNS::resolveIPv4(u_int32_t ipv4addr /* network byte order */,
			char *buf, u_int buf_len,
			u_int timeout_sec) {
  u_int last_dot = 0, dns_query_len, i;
  struct ndpi_dns_packet_header *dns_h;
  char *queries, mdnsbuf[512], query[64], addrbuf[32];
  u_int16_t tid = ipv4addr & 0xFFFF;
  struct sockaddr_in mdns_dest;
  
  buf[0] = '\0';
  snprintf(query, sizeof(query), "%s.in-addr.arpa",
	   Utils::intoaV4(ipv4addr, addrbuf, sizeof(addrbuf)));

  dns_h = (struct ndpi_dns_packet_header*)mdnsbuf;
  dns_h->tr_id = tid;
  dns_h->flags = 0 /* query */;
  dns_h->num_queries = htons(1);
  dns_h->num_answers = 0;
  dns_h->authority_rrs = 0;
  dns_h->additional_rrs = 0;
  queries = &mdnsbuf[sizeof(struct ndpi_dns_packet_header)];

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

  if(timeout_sec == 0) timeout_sec = 1;

  mdns_dest.sin_family = AF_INET, mdns_dest.sin_port = htons(5353), mdns_dest.sin_addr.s_addr = inet_addr("224.0.0.251");
  
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

      if((len > 0) && (dns_h->tr_id == tid) && (ntohs(dns_h->num_answers) > 0)) {
	/* Decode MDNS response */
	int to_skip = ntohs(dns_h->num_queries);
	int offset = 0, idx;

	len -= sizeof(struct ndpi_dns_packet_header);

	/* Skip queries */
	for(i=0; (i<to_skip) && (offset < len); ) {
	  if(queries[offset] != 0) {
	    offset++;
	    continue;
	  } else {
	    offset += 4;
	    i++; /* Found one query */
	  }
	}

	/* Time to decode response. We consider only the first one */
	offset += 14;

	for(idx=0; (offset < len) && (queries[offset] != '\0') && (idx < buf_len); offset++, idx++) {
	  if(queries[offset] < 32)
	    buf[idx] = '.';
	  else
	    buf[idx] = queries[offset];
	}

	/* As the response ends in ".local" let's cut it */
	if(idx > 6) idx -= 6;
	buf[idx] = '\0';
	
	break;
      }
    } else
      break;
  }
  
  return(buf);
}
