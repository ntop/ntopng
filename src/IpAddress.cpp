/*
 *
 * (C) 2013-16 - ntop.org
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

/* ******************************************* */

IpAddress::IpAddress() {
  ip_key = 0;
  memset(&addr, 0, sizeof(addr));
  compute_key();
}

/* ******************************************* */

void IpAddress::set(char *sym_addr) {
  if(strchr(sym_addr, '.')) {
    addr.ipVersion = 4, addr.localHost = 0, addr.ipType.ipv4 = inet_addr(sym_addr);
  } else {
    if(inet_pton(AF_INET6, sym_addr, &addr.ipType.ipv6) <= 0) {
      /* We failed */
      addr.ipVersion = 4, addr.localHost = 0, addr.ipType.ipv4 = 0;
    } else {
      addr.ipVersion = 6, addr.localHost = 0;
    }
  }

  compute_key();
}

/* ******************************************* */

bool IpAddress::isEmpty() {
  if((addr.ipVersion == 0)
     || ((addr.ipVersion == 4) && (addr.ipType.ipv4 == 0))) {
    return true;
  }else if(addr.ipVersion == 6) {
    struct ndpi_in6_addr empty_ipv6;
    memset(&empty_ipv6, 0, sizeof(empty_ipv6));
    return memcmp((void*)&empty_ipv6, (void*)&addr.ipType.ipv6, sizeof(empty_ipv6)) == 0 ? true : false;
  }
  return false;
}

/* ******************************************* */

void IpAddress::checkIP() {
  u_int32_t a;

  addr.privateIP = false; /* Default */

  if(addr.ipVersion != 4) return;

  /*
    RFC 1918 - Private Address Space

    The Internet Assigned Numbers Authority (IANA) has reserved the
    following three blocks of the IP address space for private internets:

    10.0.0.0        -   10.255.255.255  (10/8 prefix)
    172.16.0.0      -   172.31.255.255  (172.16/12 prefix)
    192.168.0.0     -   192.168.255.255 (192.168/16 prefix)
  */
  a = ntohl(addr.ipType.ipv4);

  if(((a & 0xFF000000) == 0x0A000000 /* 10.0.0.0/8 */)
     || ((a & 0xFFF00000) == 0xAC100000 /* 172.16.0.0/12 */)
     || ((a & 0xFFFF0000) == 0xC0A80000 /* 192.168.0.0/16 */)
     || ((a & 0xFF000000) == 0x7F000000 /* 127.0.0.0/8 */)
     )
    addr.privateIP = true;
  else if((a & 0xF0000000) == 0xE0000000 /* 224.0.0.0/4 */)
    addr.multicastIP = true;
  else if((a == 0xFFFFFFFF) || (a == 0))
    addr.broadcastIP = true;
}

/* ******************************************* */

int IpAddress::compare(IpAddress *ip) {
  if(ip == NULL) return(-1);

  if(addr.ipVersion < ip->addr.ipVersion) return(-1); else if(addr.ipVersion > ip->addr.ipVersion) return(1);

  if(addr.ipVersion == 4) {
#if 0
    u_int32_t a = ntohl(ip->addr.ipType.ipv4);
    u_int32_t b = ntohl(addr.ipType.ipv4);

    if(a < b) return(1); else if(b < a) return(-1); else return(0);
#else
    return(memcmp(&ip->addr.ipType.ipv4, &addr.ipType.ipv4, sizeof(u_int32_t)));
#endif
  } else
    return(memcmp(&addr.ipType.ipv6, &ip->addr.ipType.ipv6, sizeof(struct ndpi_in6_addr)));
}

/* ******************************************* */

bool IpAddress::isLocalInterfaceAddress() {
  bool systemHost;

  if(addr.ipVersion == 4) {
    ip_key = ntohl(addr.ipType.ipv4);

    systemHost = ntop->isLocalInterfaceAddress(AF_INET, &addr.ipType.ipv4);
  } else if(addr.ipVersion == 6) {
    u_int32_t key = 0;

    for(u_int32_t i=0; i<4; i++)
      key += addr.ipType.ipv6.u6_addr.u6_addr32[i];

    ip_key = key;

    systemHost = ntop->isLocalInterfaceAddress(AF_INET6, &addr.ipType.ipv6);
  } else
    systemHost = false;

  return(systemHost);
}

/* ******************************************* */

void IpAddress::compute_key() {
  if(ip_key != 0) return; /* Already computed */

  checkIP();

  if(addr.ipVersion == 4) {
    ip_key = ntohl(addr.ipType.ipv4);
  } else if(addr.ipVersion == 6) {
    ip_key = 0;

    for(u_int32_t i=0; i<4; i++)
      ip_key += addr.ipType.ipv6.u6_addr.u6_addr32[i];
  }
}

/* ******************************************* */

char* IpAddress::print(char *str, u_int str_len, u_int8_t bitmask) {
  return(intoa(str, str_len, bitmask));
}

/* ******************************************* */

bool IpAddress::isLocalHost(int16_t *network_id) {
  if(addr.ipVersion == 4) {
    u_int32_t v = /* htonl */(addr.ipType.ipv4);

    return(ntop->isLocalAddress(AF_INET, (void*)&v, network_id));
  } else {
    return(ntop->isLocalAddress(AF_INET6, (void*)&addr.ipType.ipv6, network_id));
  }
}

/* ******************************************* */

void* IpAddress::findAddress(AddressTree *ptree) {
  if(ptree == NULL)
    return(NULL);
  else {
    void *ret;

    if(addr.ipVersion == 4)
      ret = Utils::ptree_match(ptree->getTree(true), AF_INET, &addr.ipType.ipv4, 32);
    else
      ret = Utils::ptree_match(ptree->getTree(false), AF_INET6, (void*)&addr.ipType.ipv6, 128);

    return(ret);
  }
}

/* ******************************************* */

char* IpAddress::serialize() {
  json_object *my_object = getJSONObject();
  char *rsp = strdup(json_object_to_json_string(my_object));

  /* Free memory */
  json_object_put(my_object);

  return(rsp);
}

/* ******************************************* */

void IpAddress::deserialize(json_object *o) {
  json_object *obj;

  if(!o) return;

  /* Reset all */
  memset(&addr, 0, sizeof(addr));

  if(json_object_object_get_ex(o, "ipVersion", &obj))
    addr.ipVersion = json_object_get_int(obj);

  if(json_object_object_get_ex(o, "localHost", &obj))
    addr.localHost = json_object_get_boolean(obj);

  if(json_object_object_get_ex(o, "ip", &obj))
    set((char*)json_object_get_string(obj));
}

/* ******************************************* */

json_object* IpAddress::getJSONObject() {
  json_object *my_object;
  char buf[64];

  my_object = json_object_new_object();

  json_object_object_add(my_object, "ipVersion", json_object_new_int(addr.ipVersion));
  json_object_object_add(my_object, "localHost", json_object_new_boolean(addr.localHost));
  json_object_object_add(my_object, "ip", json_object_new_string(print(buf, sizeof(buf))));

  return(my_object);
}

/* ******************************************* */

/**
 * @brief Check if the host matches the specifed host tree
 *
 * @param ptree     The hosts allowed to be accessed.
 * @return true if the host matches the ptre, false otherwise.
 */
bool IpAddress::match(AddressTree *tree) {
  if(tree == NULL)
    return(true);
  else {
    patricia_tree_t *ptree = tree->getTree((addr.ipVersion == 4) ? true : false);
    patricia_node_t *node;
    
    if(ptree == NULL) return(true);
    
    if(addr.ipVersion == 4)
      node = Utils::ptree_match(ptree, AF_INET, (void*)&addr.ipType.ipv4, 32);
    else
      node = Utils::ptree_match(ptree, AF_INET6, (void*)&addr.ipType.ipv6, 128);
    
    return((node == NULL) ? false : true);
  }
}

/* ****************************** */

char* IpAddress::intoa(char* buf, u_short bufLen, u_int8_t bitmask) {
  if((addr.ipVersion == 4) || (addr.ipVersion == 0 /* Misconfigured */)) {
    bitmask = bitmask <= 32 ? bitmask : 32;
    u_int32_t a = ntohl(addr.ipType.ipv4);

    if(bitmask > 0) {
      /* bitmask 0 here causes integer overflow */
      u_int32_t netmask = ~((1 << (32 - bitmask)) - 1);
      a &= netmask;
    } else {
      /* bitmask is 0 */
      a = 0;
    }

    return(Utils::intoaV4(a, buf, bufLen));
  } else {
    bitmask = bitmask <= 128 ? bitmask : 128;
    return(Utils::intoaV6(addr.ipType.ipv6, bitmask, buf, bufLen));
  }
}
/* ****************************** */

void IpAddress::dump() {
  int16_t network_id;
  char buf[48];
  const char *local, *system;

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "-------------------- [ Local ]");
  local  =  isLocalHost(&network_id)  ? "Yes" : "No";
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "-------------------- [ System ]");
  system =  isLocalInterfaceAddress() ? "Yes" : "No";
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "--------------------");
  
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s [Local: %s][SystemHost: %s]",
			       print(buf, sizeof(buf)), local, system);
}
