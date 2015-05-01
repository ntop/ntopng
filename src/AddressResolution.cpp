/*
 *
 * (C) 2013-15 - ntop.org
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

#include "third-party/patricia/patricia.c"

/* **************************************** */

AddressResolution::AddressResolution() {
  num_resolved_addresses = num_resolved_fails = 0, num_local_networks = 0;
  ptree = New_Patricia(128);
  memset(local_networks, 0, sizeof(local_networks));
}

/* *********************************************** */

static int fill_prefix_v4(prefix_t *p, struct in_addr *a, int b, int mb) {
  do {
    if(b < 0 || b > mb)
      return(-1);

    memcpy(&p->add.sin, a, (mb+7)/8);
    p->family = AF_INET;
    p->bitlen = b;
    p->ref_count = 0;
  } while (0);

  return(0);
}

/* ******************************************* */

static int fill_prefix_v6(prefix_t *prefix, struct in6_addr *addr, int bits, int maxbits) {
  if(bits < 0 || bits > maxbits)
    return -1;

  memcpy(&prefix->add.sin6, addr, (maxbits + 7) / 8);
  prefix->family = AF_INET6;
  prefix->bitlen = bits;
  prefix->ref_count = 0;

  return 0;
}

/* ******************************************* */

static patricia_node_t* add_to_ptree(patricia_tree_t *tree, int family, void *addr, int bits) {
  prefix_t prefix;
  patricia_node_t *node;

  if(family == AF_INET)
    fill_prefix_v4(&prefix, (struct in_addr*)addr, bits, tree->maxbits);
  else
    fill_prefix_v6(&prefix, (struct in6_addr*)addr, bits, tree->maxbits);

  node = patricia_lookup(tree, &prefix);

  return(node);
}

/* ******************************************* */

#if 0
static int remove_from_ptree(patricia_tree_t *tree, int family, void *addr, int bits) {
  prefix_t prefix;
  patricia_node_t *node;
  int rc;

  if(family == AF_INET)
    fill_prefix_v4(&prefix, (struct in_addr*)addr, bits, tree->maxbits);
  else
    fill_prefix_v6(&prefix, (struct in6_addr*)addr, bits, tree->maxbits);

  node = patricia_lookup(tree, &prefix);

  if((patricia_node_t *)0 != node) {
    rc = 0;
  } else {
    rc = -1;
  }

  return(rc);
}
#endif

/* ******************************************* */

patricia_node_t* ptree_match(patricia_tree_t *tree, int family, void *addr, int bits) {
  prefix_t prefix;

  if(family == AF_INET)
    fill_prefix_v4(&prefix, (struct in_addr*)addr, bits, tree->maxbits);
  else
    fill_prefix_v6(&prefix, (struct in6_addr*)addr, bits, tree->maxbits);

  return(patricia_search_best(tree, &prefix));
}

/* ******************************************* */

patricia_node_t* ptree_add_rule(patricia_tree_t *ptree, char *line) {
  char *ip, *bits;
  struct in_addr addr4;
  struct in6_addr addr6;
  patricia_node_t *node = NULL;

  ip = line;
  bits  = strchr(line, '/');
  if(bits == NULL)
    bits = (char*)"/32";
  else
    bits[0] = '\0';

  bits++;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Rule %s/%s", ip, bits);

  if(strchr(ip, ':') != NULL) { /* IPv6 */
    if(inet_pton(AF_INET6, ip, &addr6) == 1)
      node = add_to_ptree(ptree, AF_INET6, &addr6, atoi(bits));
    else
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Error parsing IPv6 %s\n", ip);
  } else { /* IPv4 */
    /* inet_aton(ip, &addr4) fails parsing subnets */
    int num_octets;
    u_int ip4_0 = 0, ip4_1 = 0, ip4_2 = 0, ip4_3 = 0;
    u_char *ip4 = (u_char *) &addr4;

    if((num_octets = sscanf(ip, "%u.%u.%u.%u", &ip4_0, &ip4_1, &ip4_2, &ip4_3)) >= 1) {
      int num_bits = atoi(bits);

      ip4[0] = ip4_0, ip4[1] = ip4_1, ip4[2] = ip4_2, ip4[3] = ip4_3;

      if(num_bits > 32) num_bits = 32;

      if(num_octets * 8 < num_bits)
	ntop->getTrace()->traceEvent(TRACE_INFO, "Found IP smaller than netmask [%s]", line);

      //addr4.s_addr = ntohl(addr4.s_addr);
      node = add_to_ptree(ptree, AF_INET, &addr4, num_bits);
    } else {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Error parsing IPv4 %s\n", ip);
    }
  }

  return(node);
}

/* ******************************************* */

void AddressResolution::addLocalNetwork(char *_net) {
  patricia_node_t *node;
  char *net = strdup(_net);

  if(num_local_networks >= CONST_MAX_NUM_NETWORKS) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Too many networks defined: ignored %s", _net);
    free(net);
    return;
  }

  node = ptree_add_rule(ptree, _net);

  if(node) {
    local_networks[num_local_networks] = net;
    node->user_data = num_local_networks;
    num_local_networks++;
  }
}

/* ******************************************* */

/* Format: 131.114.21.0/24,10.0.0.0/255.0.0.0 */
void AddressResolution::setLocalNetworks(char *rule) {
  char *net = strtok(rule, ",");

  while(net != NULL) {
    addLocalNetwork(net);
    net = strtok(NULL, ",");
  }
}

/* ******************************************* */

int16_t AddressResolution::findAddress(int family, void *addr) {
  patricia_node_t *node = ptree_match(ptree, family, addr, (family == AF_INET) ? 32 : 128);

  if(node == NULL)
    return(-1);
  else
    return(node->user_data);
}

/* **************************************** */

void free_ptree_data(void *data) { ; }

/* **************************************** */

AddressResolution::~AddressResolution() {
#if 0
  void *res;

  pthread_join(resolveThreadLoop, &res);
#endif

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Address resolution stats [%u resolved][%u failures]",
			       num_resolved_addresses, num_resolved_fails);

  if(ptree) Destroy_Patricia(ptree, free_ptree_data);

  for(int i=0; i<num_local_networks; i++)
    free(local_networks[i]);
}

/* ***************************************** */

void AddressResolution::resolveHostName(char *_numeric_ip, char *symbolic, u_int symbolic_len) {
  char rsp[128], query[64], *at, *numeric_ip;
  u_int numeric_ip_len;

  snprintf(query, sizeof(query), "%s", _numeric_ip);
  if((at = strchr(query, '@')) != '\0') at[0] = '\0';
  numeric_ip = query;
  numeric_ip_len = strlen(numeric_ip)-1;

  if((symbolic != NULL) && (symbolic_len > 0)) symbolic[0] = '\0';
  if((numeric_ip == NULL) || (numeric_ip[0] == '\0')) return;

  if(ntop->getRedis()->getAddress(numeric_ip, rsp, sizeof(rsp), false) < 0) {
    char hostname[NI_MAXHOST];
    struct sockaddr *sa;
    struct sockaddr_in in4;
    struct sockaddr_in6 in6;
    int rc, len;

    /* Check if this is a symbolic IP */
    if(!isdigit(numeric_ip[numeric_ip_len])) {
      /* This is a symbolic IP -> numeric IP */
      struct hostent *h;

      m.lock(__FILE__, __LINE__);
      h = gethostbyname((const char*)numeric_ip); /* Non reentrant call */

      if(symbolic && h) snprintf(symbolic, symbolic_len, "%s",  h->h_name);
      ntop->getRedis()->setResolvedAddress(numeric_ip, h ? h->h_name : (char*)"");
      num_resolved_addresses++;
      m.unlock(__FILE__, __LINE__);
      return;
    }

    if(strchr(numeric_ip, ':') != NULL) {
      struct in6_addr addr6;

      if(inet_pton(AF_INET6, numeric_ip, &addr6) == 1) {
	memset(&in6, 0, sizeof(struct sockaddr_in6));

	in6.sin6_family = AF_INET6, inet_pton(AF_INET6, numeric_ip, &in6.sin6_addr);
	len = sizeof(struct sockaddr_in6), sa = (struct sockaddr*)&in6;
      } else {
	ntop->getTrace()->traceEvent(TRACE_INFO, "Invalid IPv6 address to resolve '%s': already symbolic?", numeric_ip);
	return; /* Invalid format */
      }
    } else {
      u_int ip4_0 = 0, ip4_1 = 0, ip4_2 = 0, ip4_3 = 0;

      if(sscanf(numeric_ip, "%u.%u.%u.%u", &ip4_0, &ip4_1, &ip4_2, &ip4_3) == 4) {
	in4.sin_family = AF_INET, in4.sin_addr.s_addr = inet_addr(numeric_ip);
	len = sizeof(struct sockaddr_in), sa = (struct sockaddr*)&in4;
      } else  {
	ntop->getTrace()->traceEvent(TRACE_INFO, "Invalid IPv4 address to resolve '%s': already symbolic?", numeric_ip);
	return; /* Invalid format */
      }
    }

    if((rc = getnameinfo(sa, len, hostname, sizeof(hostname), NULL, 0, NI_NAMEREQD)) == 0) {
      ntop->getRedis()->setResolvedAddress(numeric_ip, hostname);
      if((symbolic != NULL) && (symbolic_len > 0)) snprintf(symbolic, symbolic_len, "%s", hostname);
      ntop->getTrace()->traceEvent(TRACE_INFO, "Resolved %s to %s", numeric_ip, hostname);
      m.lock(__FILE__, __LINE__);
      num_resolved_addresses++;
      m.unlock(__FILE__, __LINE__);
    } else {
      m.lock(__FILE__, __LINE__);
      num_resolved_fails++;
      m.unlock(__FILE__, __LINE__);
      ntop->getTrace()->traceEvent(TRACE_INFO, "Error resolution failure for %s [%d/%s/%s]",
				   numeric_ip, rc, gai_strerror(rc), strerror(errno));
      ntop->getRedis()->setResolvedAddress(numeric_ip, numeric_ip); /* So we avoid to continuously resolver the same address */
    }
  } else {
    if((symbolic != NULL) && (symbolic_len > 0)) snprintf(symbolic, symbolic_len, "%s", rsp);
  }
}

/* **************************************************** */

static void* resolveLoop(void* ptr) {
  AddressResolution *a = (AddressResolution*)ptr;
  Redis *r = ntop->getRedis();

  while(!ntop->getGlobals()->isShutdown()) {
    char numeric_ip[64];
    int rc = r->popHostToResolve(numeric_ip, sizeof(numeric_ip));

    if(rc == 0) {
      if(numeric_ip[0] != '\0')
	a->resolveHostName(numeric_ip);
    } else
      sleep(1);
  }

  return(NULL);
}

/* **************************************************** */

void AddressResolution::startResolveAddressLoop() {
  if(ntop->getPrefs()->is_dns_resolution_enabled()) {
    for(int i=0; i<CONST_NUM_RESOLVERS; i++)
      pthread_create(&resolveThreadLoop, NULL, resolveLoop, (void*)this);
  }
}

