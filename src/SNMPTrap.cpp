/*
 *
 * (C) 2013-24 - ntop.org
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
 * Example for triggering traps for testing:
 * snmptrap -v 2c -c public 127.0.0.1 '' NET-SNMP-EXAMPLES-MIB::netSnmpExampleHeartbeatNotification netSnmpExampleHeartbeatRate i 60
 */

#ifdef HAVE_LIBSNMP

SNMPTrap::SNMPTrap() {
  if(trace_new_delete) ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);

  init_snmp("ntopng-snmp-trap");

  trap_transport = NULL;
  trap_session = NULL;
  trap_session_internal = NULL;
  trap_collection_running = false;

  initSession();
}

/* ******************************* */

SNMPTrap::~SNMPTrap() {
  stopTrapCollection();
  releaseSession();
}

/* ******************************* */

void SNMPTrap::handleTrap(struct snmp_pdu*pdu) {
#if 1
  for (netsnmp_variable_list *vars = pdu->variables; vars; vars = vars->next_variable) {
    char buf[1024];
    snprint_variable(buf, sizeof(buf), vars->name, vars->name_length, vars);
    printf("%s\n", buf);
  }
#else
  netsnmp_variable_list *variable;
  char oid[MAX_OID_LEN] = {'\0'};
  tree *mib;

  variable = pdu->variables;
  while (variable) {
    // Fill oid with an human readable oid
    if(snprint_objid(oid, sizeof(oid), variable->name_loc, variable->name_length))
        printf("oid: %s\n", oid);

    // Now let's figure out the mib
    mib = get_tree(variable->name_loc, variable->name_length, get_tree_head());
    while(mib && mib->next_peer)
      mib = mib->next_peer;
    printf("mib %s\n",mib->label);

    // Managed types being in netsnmp_vardata
    switch (variable->type) {
      case ASN_INTEGER:
        printf("integer: %ld\n", *variable->val.integer);
        break;
      case ASN_OCTET_STR:
        printf("string: %.*s\n", (int)variable->val_len, variable->val.string);
        break;
      case ASN_OBJECT_ID:
        printf("oid: ");
        for (size_t i = 0; i < variable->val_len / sizeof(oid); i++) {
          printf("%s%lu", i ? "." : "", variable->val.objid[i]);
        }
        printf("\n");
        break;
      case ASN_BIT_STR:
        printf("bit string: ");
        for (size_t i = 0; i < variable->val_len; i++) {
          printf("%02x ", variable->val.bitstring[i]);
        }
        printf("\n");
        break;
      case ASN_COUNTER64:
        printf("counter64 high: %lu\n", variable->val.counter64->high);
        printf("counter64 low: %lu\n", variable->val.counter64->low);
        break;
  #ifdef NETSNMP_WITH_OPAQUE_SPECIAL_TYPES
      case ASN_OPAQUE_FLOAT:
        printf("float: %f\n", *variable->val.floatVal);
        break;
      case ASN_OPAQUE_DOUBLE:
        printf("double: %f\n", *variable->val.doubleVal);
        break;
  #endif
      default:
        printf("Unmanaged ASN type: %u\n", variable->type);
        break;
    }

    // Move to the next variable
    variable = variable->next_variable;
  }
#endif
}

/* ******************************************* */

/* Callback printing traps */
int read_snmp_trap(int operation, struct snmp_session *sp, int reqid,
                   struct snmp_pdu *pdu, void *magic){
  SNMPTrap *s = (SNMPTrap *) magic;
  int ret = 0;
  switch (pdu->command){
    case SNMP_MSG_TRAP:
    case SNMP_MSG_TRAP2:
      ntop->getTrace()->traceEvent(TRACE_DEBUG,  "trap type %ld specific type %ld", pdu->trap_type, pdu->specific_type);
      //call SNMPTrap method to have reference to lua state
      s->handleTrap(pdu);
    break;
    default:
      ntop->getTrace()->traceEvent(TRACE_DEBUG, "Invalid operation %d",operation);
      ret = 1; 
    break;
  }
  return ret;
}

/* ******************************************* */

void SNMPTrap::trapCollection() {
  int timeout = 5;
  int numfds;
  fd_set fdset;
  struct timeval tvp;
  int count, block = 1;

  numfds = 0;
  tvp.tv_sec = timeout;
  tvp.tv_usec = 0;

  while(isTrapCollectionRunning()) {
    FD_ZERO(&fdset);
    snmp_select_info(&numfds, &fdset, &tvp, &block);
    count = select(numfds, &fdset, NULL, NULL, &tvp);

    //ntop->getTrace()->traceEvent(TRACE_NORMAL, "SNMP trap select count %d on %d fds", count, numfds);

    if(count > 0) 
      snmp_read(&fdset); // Cause read_snmp_trap callback execution

    if(tvp.tv_sec == 0)
      tvp.tv_sec = timeout;
  }

  trap_collection_running = false;
}

/* ******************************************* */

static void *trapLoop(void *ptr) {
  SNMPTrap *snmp = (SNMPTrap *) ptr;

  snmp->trapCollection();
  
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Terminated SNMP trap collection");

  return(NULL);
}

/* ******************************************* */
      
void SNMPTrap::startTrapCollection() {
  if (trap_collection_running)
    return; /* already running */

  trap_collection_running = true;

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Starting SNMP trap collection");

  pthread_create(&trap_loop, NULL, trapLoop, (void *)this);
}

/* ******************************************* */

void SNMPTrap::stopTrapCollection(){
  void *res;

  if (trap_collection_running) {
    trap_collection_running = false;

    pthread_join(trap_loop, &res);
  }
}

/* ******************************************* */

bool SNMPTrap::isTrapCollectionRunning() {
  return trap_collection_running && 
    !ntop->getGlobals()->isShutdownRequested() &&
    !ntop->getGlobals()->isShutdown();
}

/* ******************************* */

bool SNMPTrap::initSession() {
  trap_transport = netsnmp_transport_open_server("ntopng-snmp-trap", "udp:162");
  if(trap_transport == NULL){
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Failure opening snmp transport for traps\n");
    goto error;
  }

  // Trap session
  trap_session = new (std::nothrow) SNMPSession;
  if(trap_session == NULL){
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Failure creating trap session\n");
    goto error;
  }

  snmp_sess_init(&trap_session->session);
  trap_session->session.callback = read_snmp_trap;
  trap_session->session.callback_magic = (void *) this;
  trap_session->session.authenticator = NULL;

  trap_session_internal = snmp_add(&trap_session->session, trap_transport, NULL, NULL);
  if (trap_session_internal == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "adding snmp trap session failed\n");
    goto error;
  }

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "SNMP trap collector initialized");

  return true;

 error:
  releaseSession();
  return false;
}

/* ******************************* */

void SNMPTrap::releaseSession() {
  if(trap_session_internal) {
    netsnmp_free(trap_session_internal);
    trap_session_internal = NULL;
  }
  if(trap_session) {
    delete trap_session;
    trap_session = NULL;
  }
  if(trap_transport) {
    netsnmp_transport_free(trap_transport);
    trap_transport = NULL;
  }
}

/* ******************************************* */

#endif
