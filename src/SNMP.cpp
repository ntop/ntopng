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

extern "C" {
#include "../third-party/snmp/snmp.c"
#include "../third-party/snmp/asn1.c"
#include "../third-party/snmp/net.c"
};

/* ******************************* */

SNMP::SNMP() {
  char version[4] = { '\0' };

  ntop->getRedis()->get((char*)CONST_RUNTIME_PREFS_SNMP_PROTO_VERSION, version, sizeof(version));

  if((udp_sock = socket(AF_INET, SOCK_DGRAM, 0)) < 0)
    throw("Unable to start network discovery");
  
  Utils::maximizeSocketBuffer(udp_sock, true /* RX */, 2 /* MB */);
  snmp_version = atoi(version);
  if(snmp_version > 1 /* v2c */) snmp_version = 1;
}

/* ******************************* */

SNMP::~SNMP() {
  if(udp_sock != -1) closesocket(udp_sock);
}

/* ******************************************* */

void SNMP::send_snmp_request(char *agent_host, char *community, bool isGetNext,
			     char *oid[SNMP_MAX_NUM_OIDS], u_int version) {
  u_int agent_port = 161, request_id = (u_int)time(NULL);
  int i = 0;
  SNMPMessage *message;
  int len;
  u_char buf[1500];
  int operation = isGetNext ? SNMP_GETNEXT_REQUEST_TYPE : SNMP_GET_REQUEST_TYPE;
  
  if((message = snmp_create_message())) {
    snmp_set_version(message, version);
    snmp_set_community(message, community);
    snmp_set_pdu_type(message, operation);
    snmp_set_request_id(message, request_id);
    snmp_set_error(message, 0);
    snmp_set_error_index(message, 0);

    for(i=0; i<SNMP_MAX_NUM_OIDS; i++) {
      if(oid[i] != NULL)
	snmp_add_varbind_null(message, oid[i]);
    }

    len = snmp_message_length(message);
    snmp_render_message(message, buf);
    snmp_destroy_message(message);
    free(message); /* malloc'd by snmp_create_message */

    send_udp_datagram(buf, len, udp_sock, agent_host, agent_port);
  }
}

/* ******************************************* */

int SNMP::snmp_read_response(lua_State* vm, u_int timeout) {
  int i = 0, rc = CONST_LUA_OK;
  
  if(input_timeout(udp_sock, timeout) == 0) {
    /* Timeout */

    rc = CONST_LUA_ERROR;
    lua_pushnil(vm);
  } else {
    char buf[BUFLEN];
    SNMPMessage *message;
    char *sender_host, *oid_str,  *value_str;
    int sender_port, added = 0, len;

    len = receive_udp_datagram(buf, BUFLEN, udp_sock, &sender_host, &sender_port);
    message = snmp_parse_message(buf, len);

    i = 0;
    while(snmp_get_varbind_as_string(message, i, &oid_str, NULL, &value_str)) {
      if(!added) lua_newtable(vm), added = 1;
      lua_push_str_table_entry(vm, oid_str, value_str);
      if(value_str) free(value_str), value_str = NULL;
      i++;
    }

    snmp_destroy_message(message);
    free(message); /* malloc'd by snmp_parse_message */

    if(!added)
      lua_pushnil(vm), rc = CONST_LUA_ERROR;    
  }

  return(rc);
}

/* ******************************************* */

int SNMP::snmp_get_fctn(lua_State* vm, bool isGetNext) {
  char *agent_host, *community;
  u_int timeout = 5, version = snmp_version, oid_idx = 0, i;
  char *oid[SNMP_MAX_NUM_OIDS] = { NULL };
    
  if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK)  return(CONST_LUA_ERROR);
  agent_host = (char*)lua_tostring(vm, 1);

  if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK)  return(CONST_LUA_ERROR);
  community = (char*)lua_tostring(vm, 2);

  if(ntop_lua_check(vm, __FUNCTION__, 3, LUA_TSTRING) != CONST_LUA_OK)  return(CONST_LUA_ERROR);
  oid[oid_idx++] = (char*)lua_tostring(vm, 3);

  i = 4;
  
  /* Optional timeout: take the minimum */
  if(lua_type(vm, 4) == LUA_TNUMBER)
    timeout = min(timeout, (u_int)lua_tointeger(vm, 4)), i++;

  /* Optional version */
  if(lua_type(vm, 5) == LUA_TNUMBER)
    version = (u_int)lua_tointeger(vm, 5), i++;

  /* Add additional OIDs */
  while((oid_idx < SNMP_MAX_NUM_OIDS) && (lua_type(vm, i) == LUA_TSTRING))
    oid[oid_idx++] = (char*)lua_tostring(vm, i), i++;  

  send_snmp_request(agent_host, community, isGetNext, oid, version);
  
  return(snmp_read_response(vm, timeout));
}

/* ******************************************* */

int SNMP::get(lua_State* vm)     { return(snmp_get_fctn(vm, false));  }

/* ******************************************* */

int SNMP::getnext(lua_State* vm) { return(snmp_get_fctn(vm, true));   }

/* ******************************************* */

void SNMP::snmp_fetch_responses(lua_State* vm) {
  int i = 0;

  lua_newtable(vm);

  while(true) {
    if(input_timeout(udp_sock, 0) == 0) {
      /* Timeout */
      break;
    } else {
      char buf[BUFLEN];
      SNMPMessage *message;
      char *sender_host, *oid_str, *value_str = NULL;
      int sender_port, len;

      len = receive_udp_datagram(buf, BUFLEN, udp_sock, &sender_host, &sender_port);
      if((message = snmp_parse_message(buf, len))) {

      i = 0;
      while(snmp_get_varbind_as_string(message, i, &oid_str, NULL, &value_str)) {
	if(value_str && (value_str[0] != '\0')) {
	  lua_push_str_table_entry(vm, sender_host /* Sender IP */, value_str);
	  free(value_str), value_str = NULL; /* malloc'd by snmp_get_varbind_as_string */
	}
	
	i++;
      }
    
      snmp_destroy_message(message);
      free(message); /* malloc'd by snmp_parse_message */
      }
    }
  }
}
