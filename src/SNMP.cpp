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

/* ******************************* */

SNMPSession::SNMPSession() {
  session_ptr = NULL;
}

/* ******************************* */

SNMPSession::~SNMPSession() {
  if(session_ptr)
    snmp_sess_close(session_ptr);
}

/* ******************************* */

SNMP::SNMP() {
  batch_mode = false;
#ifdef HAVE_LIBSNMP
  init_snmp("ntopng");
#endif
}

/* ******************************* */

SNMP::~SNMP() {
  for(unsigned int i=0; i<sessions.size(); i++)
    delete sessions.at(i);
}

/* ******************************* */

/* http://www.net-snmp.org/docs/README.thread.html */

void SNMP::handle_async_response(struct snmp_pdu *pdu, const char *agent_ip) {
  netsnmp_variable_list *vp = pdu->variables;
  bool table_added = false;

  while(vp != NULL) {
    /* OID */
    char rsp_oid[128], buf[128];
    int offset = 0;

    switch(vp->type) {
    case SNMP_NOSUCHOBJECT:
    case SNMP_NOSUCHINSTANCE:
    case SNMP_ENDOFMIBVIEW:
      vp = vp->next_variable;
      continue; /* Error found */
      break;
    }

    if(batch_mode)
      snprintf(rsp_oid, sizeof(rsp_oid), "%s", agent_ip);
    else {
      for(u_int i=0; i<vp->name_length; i++) {
	int rc = snprintf(&rsp_oid[offset], sizeof(rsp_oid)-offset, "%s%d", (offset > 0) ? "." : "", (int)vp->name_loc[i]);

	if(rc > 0) offset += rc; else break;
      }
    }

    if(!table_added)
      lua_newtable(vm), table_added = true;


    switch(vp->type) {
    case ASN_INTEGER:
      /* case ASN_GAUGE: */ /* Alias of ASN_INTEGER */
#ifdef NATIVE_TYPE
      lua_push_int32_table_entry(vm, rsp_oid, (long)*vp->val.integer);
#else
      snprintf(buf, sizeof(buf), "%ld", (long)*vp->val.integer);
      lua_push_str_table_entry(vm, rsp_oid, buf);
#endif
      break;

    case ASN_UNSIGNED:
    case ASN_TIMETICKS:
    case ASN_COUNTER:
      // ntop->getTrace()->traceEvent(TRACE_WARNING, "%s = %d", rsp_oid, vp->val.integer);
#ifdef NATIVE_TYPE
      lua_push_uint32_table_entry(vm, rsp_oid, (u_int32_t)*vp->val.integer);
#else
      snprintf(buf, sizeof(buf), "%u", (u_int32_t)*vp->val.integer);
      lua_push_str_table_entry(vm, rsp_oid, buf);
#endif
      break;

    case ASN_COUNTER64:
      {
	u_int64_t v = (vp->val.counter64->high << 32) + vp->val.counter64->low;

#ifdef NATIVE_TYPE
	lua_push_uint32_table_entry(vm, rsp_oid, v);
#else
	snprintf(buf, sizeof(buf), "%llu", (long long unsigned int)v);
	lua_push_str_table_entry(vm, rsp_oid, buf);
#endif
      }
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

    case ASN_NULL:
      lua_push_nil_table_entry(vm, rsp_oid);
      break;
      
    default:
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Missing %d type handler [agent: %s]",
				   vp->type, agent_ip);
    }

    vp = vp->next_variable;
  } /* while */

  if(!table_added)
    lua_pushnil(vm);
}

/* ******************************* */

int asynch_response(int operation, struct snmp_session *sp, int reqid,
		    struct snmp_pdu *pdu, void *magic) {
  SNMP *s = (SNMP*)magic;

  if(operation == NETSNMP_CALLBACK_OP_RECEIVED_MESSAGE) {   
    if(pdu->command == SNMP_MSG_RESPONSE) {
      sockaddr_in *sa = (sockaddr_in*)pdu->transport_data;
      char buf[32], *peer = sp->peername;

      if(peer == NULL) {
	if(sa->sin_family == 2) /* IPv4 */
	  peer = Utils::intoaV4(ntohl(sa->sin_addr.s_addr), buf, sizeof(buf));
	else
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "Missing IPv6 support");	
      }
      
      s->handle_async_response(pdu, peer);
    }
  }

  return(0);
}

/* ******************************* */

/* See https://raw.githubusercontent.com/winlibs/net-snmp/master/snmplib/snmp_client.c */

void SNMP::send_snmpv1v2c_request(char *agent_host, char *community,
				  snmp_pdu_primitive pduType,
				  u_int version,
				  char *_oid[SNMP_MAX_NUM_OIDS],
				  bool _batch_mode) {
  int rc, pdu_type;
  struct snmp_pdu *pdu;
  SNMPSession *snmpSession;
  bool initSession = false;

  batch_mode = _batch_mode;

  if(batch_mode) {
  create_snmp_session:
    try {
      snmpSession = new SNMPSession;
      sessions.push_back(snmpSession);
      initSession = true;
    } catch(std::bad_alloc& ba) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to allocate SNMP session");
      return;
    }
  } else {
    if(sessions.size() == 0) {
      goto create_snmp_session;
    } else {
      snmpSession = sessions.at(0);
    }
  }

  /* Initialize the session */
  if(initSession) {
    snmp_sess_init(&snmpSession->session);
    snmpSession->session.peername = agent_host;

    /* set the SNMP version number */
    snmpSession->session.version = (version == 0) ? SNMP_VERSION_1 : SNMP_VERSION_2c;

    /* set the SNMP community name used for authentication */
    snmpSession->session.community = (u_char*)community;
    snmpSession->session.community_len = strlen(community);
    snmpSession->session.callback = asynch_response;
    snmpSession->session.callback_magic = this;

    /* Open the session */
    snmpSession->session_ptr = snmp_sess_open(&snmpSession->session);
  }

  /* Create the PDU */
  switch(pduType) {
  case snmp_get_pdu:
    pdu_type = SNMP_MSG_GET;
    break;
  case snmp_get_next_pdu:
    pdu_type = SNMP_MSG_GETNEXT;
    break;
  case snmp_get_bulk_pdu:
    pdu_type = (version == 0 /* SNMPv1 */) ? SNMP_MSG_GETNEXT : SNMP_MSG_GETBULK;
    break;
  case snmp_set_pdu:
    pdu_type = SNMP_MSG_SET;
    break;
  }

  if((pdu = snmp_pdu_create(pdu_type)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "SNMP PDU create error");
    return;
  }

  if(pdu_type == SNMP_MSG_GETBULK) {
    pdu->non_repeaters   = 0;  /* GET      */
    pdu->max_repetitions = 10; /* GET-NEXT */
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
  if((rc = snmp_sess_send(snmpSession->session_ptr, pdu)) == 0) {
    snmp_free_pdu(pdu);
    snmp_perror("snmp_sess_send");
    ntop->getTrace()->traceEvent(TRACE_WARNING, "SNMP send error [rc: %d]", rc);
  }

  //snmp_free_pdu(pdu); /* TODO: this is apparently freed when we close the session */
}

/* ******************************************* */

void SNMP::send_snmpv3_request(char *agent_host,
			       char *level,
			       char *username,
			       char *auth_protocol,
			       char *auth_passphrase,
			       char *privacy_protocol,
			       char *privacy_passphrase,
			       snmp_pdu_primitive pduType,
			       char *oid[SNMP_MAX_NUM_OIDS],
			       bool _batch_mode) {
  send_snmp_request(agent_host,
		    2 /* SNMPv3 */,
		    NULL,
		    level,
		    username,
		    auth_protocol,
		    auth_passphrase,
		    privacy_protocol,
		    privacy_passphrase,
		    pduType,
		    oid,
		    _batch_mode);
}

/* ******************************************* */

void SNMP::send_snmp_request(char *agent_host,
			     u_int version,
			     char *community,
			     char *level,
			     char *username,
			     char *auth_protocol,
			     char *auth_passphrase,
			     char *privacy_protocol,
			     char *privacy_passphrase,
			     snmp_pdu_primitive pduType,
			     char *_oid[SNMP_MAX_NUM_OIDS],
			     bool _batch_mode) {
  int rc, pdu_type;
  struct snmp_pdu *pdu;
  SNMPSession *snmpSession;
  bool initSession = false;

  batch_mode = _batch_mode;

  if(batch_mode) {
  create_snmp_session:
    try {
      snmpSession = new SNMPSession;
      sessions.push_back(snmpSession);
      initSession = true;
    } catch(std::bad_alloc& ba) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to allocate SNMP session");
      return;
    }
  } else {
    if(sessions.size() == 0) {
      goto create_snmp_session;
    } else {
      snmpSession = sessions.at(0);
    }
  }

  /* Initialize the session */
  if(initSession) {
    snmp_sess_init(&snmpSession->session);
    snmpSession->session.peername = agent_host;

    if(version <= 1) {
      /* SNMP v1/v2c */
      snmpSession->session.version = (version == 0) ? SNMP_VERSION_1 : SNMP_VERSION_2c;

      /* set the SNMP community name used for authentication */
      snmpSession->session.community = (u_char*)community;
      snmpSession->session.community_len = strlen(community);
    } else {
      /* SNMP v3 */
      snmpSession->session.version  = SNMP_VERSION_3;
      snmpSession->session.peername = NULL;

      if(!strcmp(level, "noAuthNoPriv")) {
	snmpSession->session.securityLevel = SNMP_SEC_LEVEL_NOAUTH;
	username = NULL;
	auth_protocol = NULL;
	privacy_protocol = NULL;
      } else {
	/* set the SNMPv3 user name */
	if(username) {
	  snmpSession->session.securityName = strdup(username);
	  snmpSession->session.securityNameLen = strlen(snmpSession->session.securityName);
	} else {
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "SNMP PDU no username specified");	
	  return;
	}

	if((!strcmp(level, "authNoPriv")) || (!strcmp(level, "authPriv"))) {
	  snmpSession->session.securityLevel = SNMP_SEC_LEVEL_AUTHNOPRIV;
	
	  if(!strcmp(auth_protocol, "md5")) {
	    snmpSession->session.securityAuthProto = usmHMACMD5AuthProtocol;
	    snmpSession->session.securityAuthProtoLen = sizeof(usmHMACMD5AuthProtocol)/sizeof(oid);
	    snmpSession->session.securityAuthKeyLen = USM_AUTH_KU_LEN;
	  } else if(!strcmp(auth_protocol, "sha")) {
	    snmpSession->session.securityAuthProto = usmHMACSHA1AuthProtocol;
	    snmpSession->session.securityAuthProtoLen = sizeof(usmHMACSHA1AuthProtocol)/sizeof(oid);
	    snmpSession->session.securityAuthKeyLen = USM_AUTH_KU_LEN; /* CHECK */
	  } else {
	    ntop->getTrace()->traceEvent(TRACE_WARNING, "SNMP PDU invalid authentication protocol [%s]", auth_protocol);
	    return;
	  }

	  if(generate_Ku(snmpSession->session.securityAuthProto,
			 snmpSession->session.securityAuthProtoLen,
			 (u_char *)auth_passphrase, strlen(auth_passphrase),
			 snmpSession->session.securityAuthKey,
			 &snmpSession->session.securityAuthKeyLen) != SNMPERR_SUCCESS) {
	    ntop->getTrace()->traceEvent(TRACE_WARNING, "SNMP PDU authentication pass phrase error");
	    return;
	  }	
	
	  if(!strcmp(level, "authPriv")) {
	    /* TODO */
	  }
	}
      }
    }

    snmpSession->session.callback = asynch_response;
    snmpSession->session.callback_magic = this;

    /* Open the session */
    snmpSession->session_ptr = snmp_sess_open(&snmpSession->session);
  }

  /* Create the PDU */
  switch(pduType) {
  case snmp_get_pdu:
    pdu_type = SNMP_MSG_GET;
    break;
  case snmp_get_next_pdu:
    pdu_type = SNMP_MSG_GETNEXT;
    break;
  case snmp_get_bulk_pdu:
    pdu_type = (version == 0 /* SNMPv1 */) ? SNMP_MSG_GETNEXT : SNMP_MSG_GETBULK;
    break;
  case snmp_set_pdu:
    pdu_type = SNMP_MSG_SET;
    break;
  }

  if((pdu = snmp_pdu_create(pdu_type)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "SNMP PDU create error");
    return;
  }

  if(pdu_type == SNMP_MSG_GETBULK) {
    pdu->non_repeaters   = 0;  /* GET      */
    pdu->max_repetitions = 10; /* GET-NEXT */
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
  if((rc = snmp_sess_send(snmpSession->session_ptr, pdu)) == 0) {
    snmp_free_pdu(pdu);
    snmp_perror("snmp_sess_send");
    ntop->getTrace()->traceEvent(TRACE_WARNING, "SNMP send error [rc: %d]", rc);
  }

  //snmp_free_pdu(pdu); /* TODO: this is apparently freed when we close the session */
}

/* ******************************************* */

void SNMP::send_snmp_set_request(char *agent_host, char *community,
				 snmp_pdu_primitive pduType,
				 u_int version,
				 char *_oid[SNMP_MAX_NUM_OIDS],
				 char value_types[SNMP_MAX_NUM_OIDS],
				 char *values[SNMP_MAX_NUM_OIDS]) {
  int rc;
  struct snmp_pdu *pdu;
  SNMPSession *snmpSession;
  bool initSession = false;

  batch_mode = false;

  if(batch_mode) {
  create_snmp_session:
    try {
      snmpSession = new SNMPSession;
      sessions.push_back(snmpSession);
      initSession = true;
    } catch(std::bad_alloc& ba) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to allocate SNMP session");
      return;
    }
  } else {
    if(sessions.size() == 0) {
      goto create_snmp_session;
    } else {
      snmpSession = sessions.at(0);
    }
  }

  /* Initialize the session */
  if(initSession) {
    snmp_sess_init(&snmpSession->session);
    snmpSession->session.peername = agent_host;

    /* set the SNMP version number */
    snmpSession->session.version = (version == 0) ? SNMP_VERSION_1 : SNMP_VERSION_2c;

    /* set the SNMP community name used for authentication */
    snmpSession->session.community = (u_char*)community;
    snmpSession->session.community_len = strlen(community);
    snmpSession->session.callback = asynch_response;
    snmpSession->session.callback_magic = this;

    /* Open the session */
    snmpSession->session_ptr = snmp_sess_open(&snmpSession->session);
  }

  /* Create the PDU */
  if((pdu = snmp_pdu_create(SNMP_MSG_SET)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "SNMP PDU create error");
    return;
  }

  for(u_int i=0; i<SNMP_MAX_NUM_OIDS; i++) {
    if(_oid[i] != NULL) {
      size_t name_length = MAX_OID_LEN;
      oid name[MAX_OID_LEN];

      if(snmp_parse_oid(_oid[i], name, &name_length))
	snmp_add_var(pdu, name, name_length, value_types[i], values[i]);
    } else
      break;
  }

  /* Send the request */
  if((rc = snmp_sess_send(snmpSession->session_ptr, pdu)) == 0) {
    snmp_free_pdu(pdu);
    snmp_perror("snmp_sess_send");
    ntop->getTrace()->traceEvent(TRACE_WARNING, "SNMP send error [rc: %d]", rc);
  }
}

/* ******************************************* */

void SNMP::snmp_fetch_responses(lua_State* _vm, u_int timeout) {
  bool add_nil = true;

  // ntop->getTrace()->traceEvent(TRACE_WARNING, "%s(%u)", __FUNCTION__, batch_mode ? 1 : 0);

  for(unsigned int i=0; i<sessions.size(); i++) {
    int numfds;
    fd_set fdset;
    struct timeval tvp;
    int count, block;
    SNMPSession *snmpSession = sessions.at(i);

    numfds = 0;
    FD_ZERO(&fdset);
    tvp.tv_sec = timeout, tvp.tv_usec = 0;

    snmp_sess_select_info(snmpSession->session_ptr, &numfds, &fdset, &tvp, &block);
    count = select(numfds, &fdset, NULL, NULL, &tvp);
    if(count > 0) {
      vm = _vm;
      snmp_sess_read(snmpSession->session_ptr, &fdset); /* Will trigger asynch_response() */
      add_nil = false;
    }
  }

  if(add_nil) lua_pushnil(_vm);
}

/* ******************************************* */

int SNMP::snmp_read_response(lua_State* _vm, u_int timeout) {
  snmp_fetch_responses(_vm, timeout);
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

/* ******************************************* */

void SNMP::send_snmpv1v2c_request(char *agent_host, char *community,
				  snmp_pdu_primitive pduType,
				  u_int version,
				  char *oid[SNMP_MAX_NUM_OIDS],
				  bool _batch_mode) {
  send_snmp_request(agent_host,
		    version,
		    community,
		    NULL,
		    NULL,
		    NULL,
		    NULL,
		    NULL,
		    NULL,
		    pduType,
		    oid,
		    _batch_mode);
}

/* ******************************************* */

void SNMP::snmp_fetch_responses(lua_State* vm, u_int sec_timeout) {
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

	   if(batch_mode /* Used in batch mode */) {
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

/* ******************************* */

SNMP::SNMP() {
  char version[4] = { '\0' };

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

/* ******************************* */
/* ******************************* */

#endif /* HAVE_LIBSNMP */

/* Common code */

/* ******************************************* */

int SNMP::get(lua_State* vm, bool skip_first_param) {
  return(snmp_get_fctn(vm, snmp_get_pdu, skip_first_param, false));
}

/* ******************************************* */

int SNMP::getnext(lua_State* vm, bool skip_first_param) {
  return(snmp_get_fctn(vm, snmp_get_next_pdu, skip_first_param, false));
}

/* ******************************************* */

int SNMP::getnextbulk(lua_State* vm, bool skip_first_param) {
  return(snmp_get_fctn(vm,
#ifdef HAVE_LIBSNMP
		       snmp_get_bulk_pdu /* GET-BULK (next only) */,
#else
		       snmp_get_next_pdu /* GET-NEXT (no bulk) */,
#endif
		       skip_first_param, false));
}

/* ******************************************* */
 
int SNMP::set(lua_State* vm, bool skip_first_param) {
#ifdef HAVE_LIBSNMP
  return(snmp_get_fctn(vm, snmp_set_pdu, skip_first_param, false));
#else
  return(-1);
#endif
}

/* ******************************************* */

int SNMP::snmp_get_fctn(lua_State* vm, snmp_pdu_primitive pduType, bool skip_first_param, bool _batch_mode) {
  char *agent_host, *community;
  u_int timeout = 5, version = snmp_version, oid_idx = 0, idx = skip_first_param ? 2 : 1;
  char *oid[SNMP_MAX_NUM_OIDS] = { NULL }, value_types[SNMP_MAX_NUM_OIDS] = { '\0' }, *values[SNMP_MAX_NUM_OIDS] = { NULL };

  if(ntop_lua_check(vm, __FUNCTION__, idx, LUA_TSTRING) != CONST_LUA_OK)  return(CONST_LUA_ERROR);
  agent_host = (char*)lua_tostring(vm, idx++);

  if(ntop_lua_check(vm, __FUNCTION__, idx, LUA_TSTRING) != CONST_LUA_OK)  return(CONST_LUA_ERROR);
  community = (char*)lua_tostring(vm, idx++);

  if(ntop_lua_check(vm, __FUNCTION__, idx, LUA_TNUMBER) != CONST_LUA_OK)  return(CONST_LUA_ERROR);
  timeout = min(timeout, (u_int)lua_tointeger(vm, idx));
  idx++; // Do not out idx++ above as min is a #define and on some platforms it will increase idx twice

  if(ntop_lua_check(vm, __FUNCTION__, idx, LUA_TNUMBER) != CONST_LUA_OK)  return(CONST_LUA_ERROR);
  version = (u_int)lua_tointeger(vm, idx++);

  /* Add OIDs */
  while((oid_idx < SNMP_MAX_NUM_OIDS) && (lua_type(vm, idx) == LUA_TSTRING)) {
    if(pduType == snmp_set_pdu) {
      /* SET */
      oid[oid_idx] = (char*)lua_tostring(vm, idx);


      /* Types
	 i: INTEGER, u: unsigned INTEGER, t: TIMETICKS, a: IPADDRESS
	 o: OBJID, s: STRING, x: HEX STRING, d: DECIMAL STRING
	 U: unsigned int64, I: signed int64, F: float, D: double
      */
      if(lua_type(vm, idx+1) != LUA_TSTRING) return(CONST_LUA_ERROR);
      value_types[oid_idx] = ((char*)lua_tostring(vm, idx+1))[0];

      if(lua_type(vm, idx+2) != LUA_TSTRING) return(CONST_LUA_ERROR);
      values[oid_idx] = (char*)lua_tostring(vm, idx+2);

      oid_idx += 3, idx += 3;
    } else {
      oid[oid_idx++] = (char*)lua_tostring(vm, idx);
      idx++;
    }
  }

  if(oid_idx == 0) {
    /* Missing OIDs */
    return(CONST_LUA_ERROR);
  }

  if(pduType == snmp_set_pdu) {
    /* SET */
#ifdef HAVE_LIBSNMP
    send_snmp_set_request(agent_host, community, pduType, version, oid, value_types, values);
#else
    return(CONST_LUA_ERROR); /* not supported */
#endif
  } else {
    send_snmpv1v2c_request(agent_host, community, pduType, version, oid, _batch_mode);
  }

  if(skip_first_param)
    return(CONST_LUA_OK); /* This is an async call */
  else
    return(snmp_read_response(vm, timeout));
}




#endif /* HAVE_NEDGE */
