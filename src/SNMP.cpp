/*
 *
 * (C) 2013-20 - ntop.org
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

#ifndef HAVE_NEDGE

/* Code needed by both implementations for batch mode */ 
extern "C" {
#include "../third-party/snmp/snmp.c"
#include "../third-party/snmp/asn1.c"
#include "../third-party/snmp/net.c"
};

#ifdef HAVE_LIBSNMP

/* ******************************* */
/* ******************************* */

/* http://www.net-snmp.org/docs/README.thread.html */

void SNMP::handle_async_response(struct snmp_pdu *pdu) {
  netsnmp_variable_list *vp = pdu->variables;
  bool table_added = false;

  while(vp != NULL) {
    /* OID */
    char rsp_oid[128];
    int offset = 0;
    
    for(u_int i=0; i<vp->name_length; i++) {
      int rc = snprintf(&rsp_oid[offset], sizeof(rsp_oid)-offset, "%s%d", (offset > 0) ? "." : "", (int)vp->name_loc[i]);
      
      if(rc > 0) offset += rc; else break;
    }

    if(!table_added)
      lua_newtable(vm), table_added = true;
    
    switch(vp->type) {
    case ASN_INTEGER:
    case ASN_UNSIGNED:
    case ASN_TIMETICKS:
    case ASN_COUNTER:
      // ntop->getTrace()->traceEvent(TRACE_WARNING, "%s = %d", rsp_oid, vp->val.integer);
      lua_push_int32_table_entry(vm, rsp_oid, (u_int32_t)*vp->val.integer);
      break;
      
    case ASN_OCTET_STR:
      {
      // ntop->getTrace()->traceEvent(TRACE_WARNING, "%s = %s", rsp_oid, vp->val.string);
	char buf[512];
	u_int len = min(sizeof(buf)-1, vp->val_len);
	
	strncpy(buf, (const char*)vp->val.string, len);
	buf[len] = '\0';
	
	lua_push_str_table_entry(vm, rsp_oid, buf);
      }
      break;

    case ASN_OBJECT_ID:
      {
	char response[128];
	int rsp_offset = 0;
	
	for(u_int i=0; i<vp->val_len/8; i++) {
	  int rc = snprintf(&response[rsp_offset], sizeof(response)-rsp_offset,
			    "%s%d", (rsp_offset > 0) ? "." : "", (int)vp->val.objid[i]);
	  
	  if(rc > 0) rsp_offset += rc; else break;
	}
	
	lua_push_str_table_entry(vm, rsp_oid, response);
      }
      break;

    default:
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Missing %d type handler", vp->type);
    }
    
    vp = vp->next_variable;
  } /* while */
}

/* ******************************* */

int asynch_response(int operation, struct snmp_session *sp, int reqid,
		    struct snmp_pdu *pdu, void *magic) {
  SNMP *s = (SNMP*)magic;

  if(operation == NETSNMP_CALLBACK_OP_RECEIVED_MESSAGE)
    s->handle_async_response(pdu);
     
  return(0);
}

/* ******************************* */
  
void SNMP::send_snmp_request_netsnmp(char *agent_host, char *community, bool isGetNext,
				     char *_oid[SNMP_MAX_NUM_OIDS], u_int version) {
  int rc;
  struct snmp_pdu *pdu;

  /* Initialize the session */
  snmp_sess_init(&session);
  session.peername = agent_host;

  /* set the SNMP version number */
  session.version = (version == 0) ? SNMP_VERSION_1 : SNMP_VERSION_2c;

  /* set the SNMP community name used for authentication */
  session.community = (u_char*)community;
  session.community_len = strlen(community);
  session.callback = asynch_response;
  session.callback_magic = this;
  
  /* Open the session */
  session_ptr = snmp_sess_open(&session);

  /* Create the PDU */
  if((pdu = snmp_pdu_create(isGetNext ? SNMP_MSG_GETNEXT : SNMP_MSG_GET)) == NULL) {
    // snmp_sess_close(ss);
    ntop->getTrace()->traceEvent(TRACE_WARNING, "SNMP PDU create error");
    return;
  }

  for(u_int i=0; i<SNMP_MAX_NUM_OIDS; i++) {
    if(_oid[i] != NULL) {
      size_t name_length = MAX_OID_LEN;
      oid name[MAX_OID_LEN];

      if(snmp_parse_oid(_oid[i], name, &name_length))
	snmp_add_null_var(pdu, name, name_length);
    } else
      break;
  }

  /* Send the request */
  if((rc = snmp_sess_send(session_ptr, pdu)) == 0) {
    snmp_perror("snmp_sess_send");
    ntop->getTrace()->traceEvent(TRACE_WARNING, "SNMP send error [rc: %d]", rc);
  }

  snmp_free_pdu(pdu);
  pdu = NULL;
}

/* ******************************************* */

int SNMP::snmp_read_response(lua_State* _vm, u_int timeout) {
  bool add_nil = true;
  
  if(session_ptr) {
    int numfds;
    fd_set fdset;
    struct timeval tvp;
    int count, block;
    
    numfds = 0;
    FD_ZERO(&fdset);
    tvp.tv_sec = timeout, tvp.tv_usec = 0;
    
    snmp_sess_select_info(session_ptr, &numfds, &fdset, &tvp, &block);
    count = select(numfds, &fdset, NULL, NULL, &tvp);
    if(count > 0) {
      vm = _vm, add_sender_ip = false;
      snmp_sess_read(session_ptr, &fdset); /* Will trigger asynch_response() */
      add_nil = false;
    }
  }

  if(add_nil) lua_pushnil(vm);

  return(CONST_LUA_OK);
}

/* ******************************* */
/* ******************************* */

#else

/* ******************************* */
/* ******************************* */

/* Self-contained SNMP implementation */

/* ******************************************* */

int SNMP::snmp_read_response(lua_State* vm, u_int timeout) {
  int i = 0;

  if(ntop->getGlobals()->isShutdown()
     || input_timeout(udp_sock, timeout) == 0) {
    /* Timeout or shutdown in progress */
    lua_pushnil(vm);
  } else {
    char buf[BUFLEN];
    SNMPMessage *message;
    char *sender_host, *oid_str,  *value_str;
    int sender_port, added = 0, len;

    /* This receive doesn't block */
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
      lua_pushnil(vm);
  }

  return(CONST_LUA_OK);
}

/* ******************************* */
/* ******************************* */

#endif /* HAVE_LIBSNMP */

/* Common code */

/* ******************************* */

SNMP::SNMP() {
  char version[4] = { '\0' };

#ifdef HAVE_LIBSNMP
  init_snmp("ntopng");
  ss = NULL;
#endif

  ntop->getRedis()->get((char*)CONST_RUNTIME_PREFS_SNMP_PROTO_VERSION, version, sizeof(version));

  if((udp_sock = socket(AF_INET, SOCK_DGRAM, 0)) < 0)
    throw("Unable to start network discovery");

  Utils::maximizeSocketBuffer(udp_sock, true /* RX */, 2 /* MB */);
  snmp_version = atoi(version);
  if(snmp_version > 1 /* v2c */) snmp_version = 1;
  request_id = rand(); // Avoid overlaps with coroutines
}

/* ******************************* */

SNMP::~SNMP() {
  if(udp_sock != -1) closesocket(udp_sock);
}

/* ******************************************* */

int SNMP::get(lua_State* vm, bool skip_first_param) {
  return(snmp_get_fctn(vm, false, skip_first_param));
}

/* ******************************************* */

int SNMP::getnext(lua_State* vm, bool skip_first_param) {
  return(snmp_get_fctn(vm, true, skip_first_param));
}

/* ******************************************* */

int SNMP::snmp_get_fctn(lua_State* vm, bool isGetNext, bool skip_first_param) {
  char *agent_host, *community;
  u_int timeout = 5, version = snmp_version, oid_idx = 0, idx = skip_first_param ? 2 : 1;
  char *oid[SNMP_MAX_NUM_OIDS] = { NULL };

  if(ntop_lua_check(vm, __FUNCTION__, idx, LUA_TSTRING) != CONST_LUA_OK)  return(CONST_LUA_ERROR);
  agent_host = (char*)lua_tostring(vm, idx++);

  if(ntop_lua_check(vm, __FUNCTION__, idx, LUA_TSTRING) != CONST_LUA_OK)  return(CONST_LUA_ERROR);
  community = (char*)lua_tostring(vm, idx++);

  if(ntop_lua_check(vm, __FUNCTION__, idx, LUA_TNUMBER) != CONST_LUA_OK)  return(CONST_LUA_ERROR);
  timeout = min(timeout, (u_int)lua_tointeger(vm, idx));
  idx++; // Do not out idx++ above as min is a #define and on some platforms it will increase idx twice

  if(ntop_lua_check(vm, __FUNCTION__, idx, LUA_TNUMBER) != CONST_LUA_OK)  return(CONST_LUA_ERROR);
  version = (u_int)lua_tointeger(vm, idx++);

  /* Add additional/optional OIDs */
  while((oid_idx < SNMP_MAX_NUM_OIDS) && (lua_type(vm, idx) == LUA_TSTRING)) {
    oid[oid_idx++] = (char*)lua_tostring(vm, idx);
    idx++;
  }

  if(oid_idx == 0) {
    /* Missing OIDs */
    return(CONST_LUA_ERROR);
  }

  send_snmp_request(agent_host, community, isGetNext, oid, version,
		    skip_first_param /* batch mode */);

  if(skip_first_param)
    return(CONST_LUA_OK); /* This is an async call */
  else
    return(snmp_read_response(vm, timeout));
}

/* ******************************************* */

void SNMP::send_snmp_request(char *agent_host, char *community, bool isGetNext,
			     char *oid[SNMP_MAX_NUM_OIDS], u_int version,
			     bool batch_mode) {
#ifdef HAVE_LIBSNMP
  if(!batch_mode) {
    /* NET-SNMP does not support batch mode */
    send_snmp_request_netsnmp(agent_host, community, isGetNext, oid, version);
    return;
  }
#endif
  
  u_int agent_port = 161;
  int i = 0;
  SNMPMessage *message;
  int len;
  u_char buf[1500];
  int operation = isGetNext ? NTOP_SNMP_GETNEXT_REQUEST_TYPE : NTOP_SNMP_GET_REQUEST_TYPE;

  if((message = snmp_create_message())) {
    snmp_set_version(message, version);
    snmp_set_community(message, community);
    snmp_set_pdu_type(message, operation);
    snmp_set_request_id(message, request_id++);
    snmp_set_error(message, 0);
    snmp_set_error_index(message, 0);

    for(i=0; i<SNMP_MAX_NUM_OIDS; i++) {
      if(oid[i] != NULL)
	snmp_add_varbind_null(message, oid[i]);
      else
	break;
    }

    len = snmp_message_length(message);
    snmp_render_message(message, buf);
    snmp_destroy_message(message);
    free(message); /* malloc'd by snmp_create_message */

    send_udp_datagram(buf, len, udp_sock, agent_host, agent_port);
  }
}

/* ******************************************* */

 void SNMP::snmp_fetch_responses(lua_State* vm, u_int sec_timeout, bool add_sender_ip) {
   int i = 0;

   if(ntop->getGlobals()->isShutdown()
      || input_timeout(udp_sock, sec_timeout) == 0) {
     /* Timeout or shutdown in progress */
   } else {
     char buf[BUFLEN];
     SNMPMessage *message;
     char *sender_host, *oid_str, *value_str = NULL;
     int sender_port, len;

     len = receive_udp_datagram(buf, BUFLEN, udp_sock, &sender_host, &sender_port);

     if((message = snmp_parse_message(buf, len))) {
       bool table_added = false;

       i = 0;

       while(snmp_get_varbind_as_string(message, i, &oid_str, NULL, &value_str)) {
	 if(value_str /* && (value_str[0] != '\0') */) {
	   if(!table_added)
	     lua_newtable(vm), table_added = true;

	   if(add_sender_ip /* Used in batch mode */) {
	     /*
	       The key is the IP address as this is used when contacting multiple
	       hosts so we need to know who has sent back the response
	     */
	     lua_push_str_table_entry(vm, sender_host /* Sender IP */, value_str);
	   } else
	     lua_push_str_table_entry(vm, oid_str, value_str);

	   free(value_str), value_str = NULL; /* malloc'd by snmp_get_varbind_as_string */
	 }

	 i++;
       } /* while */

       snmp_destroy_message(message);
       free(message); /* malloc'd by snmp_parse_message */
       if(table_added)
	 return;
     }
   }

   lua_pushnil(vm);
 }



#endif /* HAVE_NEDGE */
