/*
 *
 * (C) 2013-19 - ntop.org
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

/*
   This is a C++ implementation of the reference python implementation

   https://github.com/corelight/community-id-spec/blob/master/community-id.py
 */


/* **************************************************** */

ssize_t CommunityIdFlowHash::buf_copy(u_int8_t * const dst, const void * const src, ssize_t len) {
  if(!dst || !len)
    return 0;

  if(src)
    memcpy(dst, src, len);
  else
    memset(dst, 0, len);

  return len;
}

/* **************************************************** */

/*
  https://github.com/corelight/community-id-spec/blob/bda913f617389df07cdaa23606e11bbd318e265c/community-id.py#L56
*/
u_int8_t CommunityIdFlowHash::icmp_type_to_code_v4(u_int8_t icmp_type, u_int8_t icmp_code, bool * const is_one_way) {
  *is_one_way = false;

  switch(icmp_type) {
  case ICMP_ECHO:
    return ICMP_ECHOREPLY;
  case ICMP_ECHOREPLY:
    return ICMP_ECHO;
  case ICMP_TIMESTAMP:
    return ICMP_TIMESTAMPREPLY;
  case ICMP_TIMESTAMPREPLY:
    return ICMP_TIMESTAMP;
  case ICMP_INFO_REQUEST:
    return ICMP_INFO_REPLY;
  case ICMP_INFO_REPLY:
    return ICMP_INFO_REQUEST;
  case ICMP_ROUTERSOLICIT:
    return ICMP_ROUTERADVERT;
  case ICMP_ROUTERADVERT:
    return ICMP_ROUTERSOLICIT;
  case ICMP_MASKREQ:
    return ICMP_MASKREPLY;
  case ICMP_MASKREPLY:
    return ICMP_MASKREQ;
  default:
    *is_one_way = true;
    return icmp_code;
  }
}

/* **************************************************** */

/*
  https://github.com/corelight/community-id-spec/blob/bda913f617389df07cdaa23606e11bbd318e265c/community-id.py#L83
*/
u_int8_t CommunityIdFlowHash::icmp_type_to_code_v6(u_int8_t icmp_type, u_int8_t icmp_code, bool * const is_one_way) {
  *is_one_way = false;

  switch(icmp_type) {
  case ICMP6_ECHO_REQUEST:
    return ICMP6_ECHO_REPLY;
  case ICMP6_ECHO_REPLY:
    return ICMP6_ECHO_REQUEST;
  case ND_ROUTER_SOLICIT:
    return ND_ROUTER_ADVERT;
  case ND_ROUTER_ADVERT:
    return ND_ROUTER_SOLICIT;
  case ND_NEIGHBOR_SOLICIT:
    return ND_NEIGHBOR_ADVERT;
  case ND_NEIGHBOR_ADVERT:
    return ND_NEIGHBOR_SOLICIT;
  case MLD_LISTENER_QUERY:
    return MLD_LISTENER_REPORT;
  case MLD_LISTENER_REPORT:
    return MLD_LISTENER_QUERY;
  case ICMP6_WRUREQUEST:
    return ICMP6_WRUREPLY;
  case ICMP6_WRUREPLY:
    return ICMP6_WRUREQUEST;
  // Home Agent Address Discovery Request Message and reply
  case 144:
    return 145;
  case 145:
    return 144;

  default:
    *is_one_way = true;
    return icmp_code;
  }
}

/* **************************************************** */

/*
  https://github.com/corelight/community-id-spec/blob/bda913f617389df07cdaa23606e11bbd318e265c/community-id.py#L164
*/
bool CommunityIdFlowHash::is_less_than(const IpAddress * const ip1, const IpAddress * const ip2, u_int16_t p1, u_int16_t p2) {
  int comp;

  comp = ip1->compare(ip2);


  return comp < 0 || (comp == 0 && p1 < p2);
}

/* **************************************************** */

/*
  The community id hash doesn't have the definition of client and server, it just sorts IP addresses
  and ports to make sure the smaller ip address is the first. This performs this check and
  possibly swap client ip and port.
*/
void CommunityIdFlowHash::check_peers(IpAddress ** const ip1, IpAddress ** const ip2, u_int16_t * const p1, u_int16_t * const p2, bool is_icmp_one_way) {
  IpAddress *tmp_ip;
  u_int16_t tmp_port;

  if(is_icmp_one_way || is_less_than(*ip1, *ip2, *p1, *p2))
    ;
  else {
    tmp_ip = *ip1, tmp_port = *p1;
    *ip1 = *ip2, *p1 = *p2;
    *ip2 = tmp_ip, *p2 = tmp_port;
  }
}

/* **************************************************** */

/*
https://github.com/corelight/community-id-spec/blob/bda913f617389df07cdaa23606e11bbd318e265c/community-id.py#L285
*/
char * CommunityIdFlowHash::get_community_id_flow_hash(Flow * const f) {
  u_int8_t *comm_buf;
  u_int16_t comm_buf_len = 0;
  u_int32_t cli_ipv4, srv_ipv4;
  u_int16_t cli_port, srv_port;
  u_int8_t  l4_proto;
  u_int8_t icmp_type, icmp_code;
  u_int16_t icmp_echo_id;
  const u_int16_t comm_id_seed = htons(0);
  IpAddress *cli_ip, *srv_ip;
  bool icmp_one_way = false;
  uint32_t hash[STATE_LEN];
  char *community_id;

  if(!(comm_buf = (u_int8_t*)calloc(sizeof(*comm_buf),
				    2 /* Seed */
				    + 16 /* IPv6 src */ + 16 /* IPv6 dst */
				    + 1 /* L4 proto */ +  1 /* Pad */ + 2 /* Port src */ + 2 /* Port dst */))
     || !f
     || !f->get_cli_host() || !(cli_ip = f->get_cli_host()->get_ip())
     || !f->get_srv_host() || !(srv_ip = f->get_srv_host()->get_ip()))
    return NULL;

  l4_proto = f->get_protocol();

  /* Adjust the ports according to the specs */
  switch(l4_proto) {
  case IPPROTO_ICMP:
    f->getICMP(&icmp_type, &icmp_code, &icmp_echo_id);
    cli_port = icmp_type, srv_port = icmp_type_to_code_v4(icmp_type, icmp_code, &icmp_one_way);
    break;

  case IPPROTO_ICMPV6:
    f->getICMP(&icmp_type, &icmp_code, &icmp_echo_id);
    cli_port = icmp_type, srv_port = icmp_type_to_code_v6(icmp_type, icmp_code, &icmp_one_way);
    break;

  case IPPROTO_SCTP:
  case IPPROTO_UDP:
  case IPPROTO_TCP:
    cli_port = f->get_cli_port(), srv_port = f->get_srv_port();
    break;

  default:
    cli_port = srv_port = 0;
    break;
  }

  /* Check (and possibly swap) flow peers */
  check_peers(&cli_ip, &srv_ip, &cli_port, &srv_port, icmp_one_way);

  /* The seed */
  comm_buf_len = buf_copy(&comm_buf[comm_buf_len], &comm_buf_len, sizeof(comm_id_seed));

  /* Source and destination IPs */
  if(cli_ip->isIPv4()) {
    cli_ipv4 = cli_ip->get_ipv4(), srv_ipv4 = srv_ip->get_ipv4();
    comm_buf_len += buf_copy(&comm_buf[comm_buf_len], &cli_ipv4, sizeof(cli_ipv4));
    comm_buf_len += buf_copy(&comm_buf[comm_buf_len], &srv_ipv4, sizeof(srv_ipv4));
  } else {
    comm_buf_len += buf_copy(&comm_buf[comm_buf_len], cli_ip->get_ipv6(), sizeof(struct ndpi_in6_addr));
    comm_buf_len += buf_copy(&comm_buf[comm_buf_len], srv_ip->get_ipv6(), sizeof(struct ndpi_in6_addr));
  }

  /* L4 proto */
  comm_buf_len += buf_copy(&comm_buf[comm_buf_len], &l4_proto, sizeof(l4_proto));

  /* Pad */
  comm_buf_len += buf_copy(&comm_buf[comm_buf_len], NULL, 1);

  /* Source and destination ports */
  switch(l4_proto) {
  case IPPROTO_ICMP:
  case IPPROTO_ICMPV6:
  case IPPROTO_SCTP:
  case IPPROTO_UDP:
  case IPPROTO_TCP:
    cli_port = htons(cli_port), srv_port = htons(srv_port);
    comm_buf_len += buf_copy(&comm_buf[comm_buf_len], &cli_port, sizeof(cli_port));
    comm_buf_len += buf_copy(&comm_buf[comm_buf_len], &srv_port, sizeof(srv_port));
    break;
  }

  /* Compute the sha1 of the result */
  Utils::sha1_hash(comm_buf, comm_buf_len, hash);

  /* Finally the base64 encoding */

  /* First, we bring everything into network-byte-order */
  for(u_int i = 0; i < STATE_LEN; i++)
    hash[i] = htonl(hash[i]);

  /* Then, we do the actual base64-encoding */
  community_id = Utils::base64_encode((u_int8_t*)hash, sizeof(hash));

#ifdef TEST_COMMUNITY_ID_FLOW_HASH

  printf("[cli_port: %u][srv_port: %u][icmp_type: %u][icmp_code: %u]\n", ntohs(cli_port), ntohs(srv_port), icmp_type, icmp_code);

  printf("Hex output: ");
  for(int i = 0; i < comm_buf_len; i++)
    printf("%.2x ", comm_buf[i]);
  printf("\n");

  printf("Sha1 sum: ");
  for(int i = 0; i < STATE_LEN; i++)
    printf("%.2x ", ntohl(hash[i]));
  printf("\n");

  printf("Base64: %s\n", community_id);
#endif

  if(comm_buf)     free(comm_buf);

  return community_id;
}
