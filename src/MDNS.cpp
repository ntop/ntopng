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

static void* resolverCheckFctn(void* ptr) {
  MDNS *m = (MDNS*)ptr;

  m->initializeResolver();
  return(NULL);
}

/* ******************************* */

MDNS::MDNS(NetworkInterface *iface) {
  pthread_t resolverCheck;
  
  if(((udp_sock = socket(AF_INET, SOCK_DGRAM, 0)) == -1)
     || ((batch_udp_sock = socket(AF_INET, SOCK_DGRAM, 0)) == -1))
    throw("Unable to create socket");

  /* Multicast group is 224.0.0.251 */
  gatewayIPv4 = Utils::findInterfaceGatewayIPv4(iface->get_name());

  pthread_create(&resolverCheck, NULL, resolverCheckFctn, (void*)this);
}

/* ******************************* */

MDNS::~MDNS() {
  if(udp_sock != -1)       close(udp_sock);
  if(batch_udp_sock != -1) close(batch_udp_sock);
}

/* ******************************* */

void MDNS::initializeResolver() {
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

u_int16_t MDNS::buildMDNSRequest(char *query, u_int8_t query_type,
				 char *mdnsbuf, u_int mdnsbuf_len,
				 u_int16_t tid) {
  u_int16_t last_dot = 0, dns_query_len;
  struct ndpi_dns_packet_header *dns_h = (struct ndpi_dns_packet_header*)mdnsbuf;
  char *queries;
  
  dns_h->tr_id = tid;
  dns_h->flags = 0 /* query */;
  dns_h->num_queries = htons(1);
  dns_h->num_answers = 0;
  dns_h->authority_rrs = 0;
  dns_h->additional_rrs = 0;
  queries = &mdnsbuf[sizeof(struct ndpi_dns_packet_header)];

  mdnsbuf_len -= sizeof(struct ndpi_dns_packet_header) + 4;

  for(dns_query_len=0; (dns_query_len < mdnsbuf_len)
	&& (query[dns_query_len] != '\0'); dns_query_len++) {
    if(query[dns_query_len] == '.') {
      queries[last_dot] = dns_query_len-last_dot;
      last_dot = dns_query_len+1;
    } else
      queries[dns_query_len+1] = query[dns_query_len];
  }

  dns_query_len++;
  queries[last_dot] = dns_query_len-last_dot-1;
  queries[dns_query_len++] = '\0';

  queries[dns_query_len++] = 0x00; queries[dns_query_len++] = query_type;
  queries[dns_query_len++] = 0x00; queries[dns_query_len++] = 0x01; /* IN */
  dns_query_len += sizeof(struct ndpi_dns_packet_header);

  sentAnyQuery = (query_type == 0xFF) ? true : false;
  return(dns_query_len);
}

/* ******************************* */

u_int16_t MDNS::prepareIPv4ResolveQuery(u_int32_t ipv4addr /* network byte order */,
					char *mdnsbuf, u_int mdnsbuf_len,
					u_int16_t tid) {
  char query[64], addrbuf[32];

  /*
    dig +short @224.0.0.251 -p 5353 -t PTR 20.2.168.192.in-addr.arpa
  */
  snprintf(query, sizeof(query), "%s.in-addr.arpa",
	   Utils::intoaV4(ipv4addr, addrbuf, sizeof(addrbuf)));
  
  return(buildMDNSRequest(query, 0x0C /* PTR */, mdnsbuf, mdnsbuf_len, tid));
}

/* ******************************* */

bool MDNS::sendAnyQuery(char *targetIPv4, char *query) {
  char mdnsbuf[512];
  u_int16_t len = buildMDNSRequest(query, 0xFF /* ANY */, mdnsbuf, sizeof(mdnsbuf), 0);
  struct sockaddr_in dest;

  /* dig @192.168.2.38 -p 5353 -t any _sftp-ssh._tcp.local */
  
  dest.sin_family = AF_INET, dest.sin_port = htons(5353), dest.sin_addr.s_addr = inet_addr(targetIPv4);
  if(sendto(batch_udp_sock, mdnsbuf, len, 0, (struct sockaddr *)&dest, sizeof(struct sockaddr_in)) < 0) {
    return(false);
  }
 
  return(true);
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

char* MDNS::decodeAnyResponse(char *mdnsbuf, u_int mdnsbuf_len,
			      char *buf, u_int buf_len) {
  struct ndpi_dns_packet_header *dns_h = (struct ndpi_dns_packet_header*)mdnsbuf;
  u_int offset = 0, i, idx, to_skip;
  u_char *queries = (u_char*)&mdnsbuf[sizeof(struct ndpi_dns_packet_header)];

  mdnsbuf_len -= sizeof(struct ndpi_dns_packet_header);
  
  /* Skip queries */
  to_skip = ntohs(dns_h->num_queries);
  for(i=0, idx=0; (i<to_skip) && (offset < (u_int)mdnsbuf_len); ) {
    if(queries[offset] != 0) {
      offset++, idx++;
      continue;
    } else {
      offset += 4, idx = 0;
      i++; /* Found one query */
    }
  }

  offset++;
  
  /* Skip replies */
  to_skip = ntohs(dns_h->num_answers);
  for(i=0, idx=0; (i<to_skip) && (offset < (u_int)mdnsbuf_len); ) {
    u_int16_t len;
  
    offset += 10;
    
    len = ntohs(*(u_int16_t*)&queries[offset]);
    offset += len + 2;
    
    i++; /* Found one reply */
  }

  to_skip = ntohs(dns_h->additional_rrs);
  for(i=0, idx=0; (i<to_skip) && (offset < (u_int)mdnsbuf_len); ) {
    u_int16_t len, qtype;

    if(queries[offset] != 0xC0) {
      while((offset < (u_int)mdnsbuf_len) && (queries[offset] != 0xC0))
	offset++;
    }
    
    qtype = ntohs(*(u_int16_t*)&queries[offset+2]);
  
    len = ntohs(*(u_int16_t*)&queries[offset+10]);
    offset += 12;

    if(qtype == 0x10) {
      int j;

      for(j=0; (j<len)  && (offset < (u_int)mdnsbuf_len); j++) {
	if(queries[offset+j] < 32) {
	  if(idx > 0) buf[idx++] = ';';
	} else
	  buf[idx++] = queries[offset+j];
      }

      if(idx > 0) {
	buf[idx] = '\0';
	ntop->getTrace()->traceEvent(TRACE_INFO, "[TXT] %s", buf);
	break;
      }
    }
    
    offset += len;
    
    i++; /* Found one reply */
  }

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
	if(!sentAnyQuery)
	  decodePTRResponse(mdnsbuf, (u_int)len, buf, buf_len, &resolved_ip);
	else
	  decodeAnyResponse(mdnsbuf, (u_int)len, buf, buf_len);
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
  char mdnsbuf[512], src[32];
  u_int16_t tid = ipv4addr & 0xFFFF;
  struct sockaddr_in mdns_dest, nbns_dest;
  u_int8_t nbns_discover[] = {0x12, 0x34, /* Transaction ID: 0x1234 */
			      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x20, 0x43, 0x4b, 0x41,
			      0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
			      0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x00, 0x00, 0x21,
			      0x00, 0x01 };

  if((ipv4addr == 0) || (ipv4addr = 0xFFFFFFFF))
    return(false);

  dns_query_len = prepareIPv4ResolveQuery(ipv4addr, mdnsbuf, sizeof(mdnsbuf), tid);

  mdns_dest.sin_family = AF_INET, mdns_dest.sin_port = htons(5353), mdns_dest.sin_addr.s_addr = ipv4addr;
  if(sendto(batch_udp_sock, mdnsbuf, dns_query_len, 0, (struct sockaddr *)&mdns_dest, sizeof(struct sockaddr_in)) < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Send error %s [%d/%s]", Utils::intoaV4(ntohl(ipv4addr), src, sizeof(src)), errno, strerror(errno));
    return(false);
  }

  if(alsoUseGatewayDNS && (gatewayIPv4 != 0)) {
    mdns_dest.sin_family = AF_INET, mdns_dest.sin_port = htons(53), mdns_dest.sin_addr.s_addr = gatewayIPv4;
    if(sendto(batch_udp_sock, mdnsbuf, dns_query_len, 0, (struct sockaddr *)&mdns_dest, sizeof(struct sockaddr_in)) < 0) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Send error %s [%d/%s]", Utils::intoaV4(ntohl(gatewayIPv4), src, sizeof(src)), errno, strerror(errno));
      return(false);
    }
  }
  
  nbns_dest.sin_family = AF_INET, nbns_dest.sin_port = htons(137), nbns_dest.sin_addr.s_addr = ipv4addr;
  if(sendto(batch_udp_sock, (const char*)nbns_discover, sizeof(nbns_discover), 0, (struct sockaddr *)&nbns_dest, sizeof(struct sockaddr_in)) < 0)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Send error %s [%d/%s]", Utils::intoaV4(ntohl(ipv4addr), src, sizeof(src)), errno, strerror(errno));

  return(true);
}

/* ******************************* */

void MDNS::fetchResolveResponses(lua_State* vm, int32_t timeout_sec) {
  char src[32], buf[128];
  u_int16_t onethreeseven = ntohs(137);
    
  lua_newtable(vm);

  while(true) {
    fd_set rset;
    struct timeval tv;

    FD_ZERO(&rset);
    FD_SET(batch_udp_sock, &rset);

    tv.tv_sec = timeout_sec, tv.tv_usec = 0;

    if(select(batch_udp_sock + 1, &rset, NULL, NULL, &tv) > 0) {
      struct sockaddr_in from;
      char mdnsbuf[512];
      socklen_t from_len = sizeof(from);
      int len = recvfrom(batch_udp_sock, mdnsbuf, sizeof(mdnsbuf), 0, (struct sockaddr *)&from, &from_len);

      if(len > 0) {	 
	if(from.sin_port == onethreeseven) {
	  /* NetBIOS */
	  decodeNetBIOS((u_char*)mdnsbuf, len, buf, sizeof(buf));
	  lua_push_str_table_entry(vm, Utils::intoaV4(ntohl(from.sin_addr.s_addr),
						      src, sizeof(src)), buf);
	} else {
	  struct ndpi_dns_packet_header *dns_h = (struct ndpi_dns_packet_header*)mdnsbuf;

	  if(ntohs(dns_h->num_answers) > 0) {
	    u_int32_t resolved_ip;
	    char *dot;
	    
	    if(!sentAnyQuery)
	      decodePTRResponse(mdnsbuf, (u_int)len, buf, sizeof(buf), &resolved_ip);
	    else
	      decodeAnyResponse(mdnsbuf, (u_int)len, buf, sizeof(buf)), resolved_ip = 0;
	    
	    if(resolved_ip == 0)
	      resolved_ip = ntohl(from.sin_addr.s_addr);
	    
	    if((dot = strchr(buf, '.')) != NULL)
	      dot[0] = '\0';
	    
	    lua_push_str_table_entry(vm, Utils::intoaV4(resolved_ip, src, sizeof(src)), buf);
	  }
	}
      }
    } else
      break;
  }

  if(gatewayIPv4 != 0)
    lua_push_str_table_entry(vm, "gateway.local", Utils::intoaV4(ntohl(gatewayIPv4), src, sizeof(src)));
}

/* ******************************* */
  
/*
  Ok I know this is not a MDNS packet but it is convenient to combine
  MDNS with NetBIOS address resolution
*/
char* MDNS::decodeNetBIOS(u_char *buf, u_int buf_len,
			  char *out, u_int out_len) {
  struct netbios_header {
    u_int16_t transaction_id, flags, questions, answer_rrs, authority_rrs, additional_rrs;
  };
  struct netbios_header *h = (struct netbios_header*)buf;
  u_int16_t i16;
  u_int offset;
  
  out[0] = '\0';

  if((buf_len < sizeof(struct netbios_header)+32 /* Just to be safe */)
     || (ntohs(h->transaction_id) != 0x1234)
     || ((ntohs(h->flags) & 0x8000) == 0 /* Not a reply */)
     || (ntohs(h->questions)  != 0)
     || (ntohs(h->answer_rrs) == 0)
     )
    return(out);

  offset = sizeof(struct netbios_header);
  offset += buf[offset] + 2; /* Skip name */

  if(offset > buf_len) return(out);
  i16 = ntohs(*((u_int16_t*)&buf[offset])); /* Type */
  if(i16 != 0x21) /* NBSTAT */ return(out); else offset += 2;

  offset += 8; /* Skip class, TTL and data len */
  if(offset > buf_len) return(out);

  if(buf[offset] == 0) /* Number of names */ return(out); else offset += 1;
  if((u_int)(offset+16) > buf_len) return(out);

  strncpy(out, (char*)&buf[offset], 16);

  for(i16=15; i16>0; i16--)
    if((out[i16] == ' ') || (out[i16] == 0x0))
      out[i16] = '\0';
    else
      break;

  return(out);
}
