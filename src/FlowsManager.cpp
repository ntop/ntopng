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
#include "FlowsManager.h"

/* **************************************** */

FlowsManager::FlowsManager(NetworkInterface *intf) {
  this->intf = intf;
}

/* **************************************** */

static bool flows_select_walker(GenericHashEntry *h, void *user_data) {
  struct flow_details_info *info = (struct flow_details_info*)user_data;
  Flow *flow = (Flow*)h;

  switch(info->field) {
  case FF_NONE:
    break;
  case FF_HOST:
    if((info->host != flow->get_cli_host())
       && (info->host != flow->get_srv_host()))
      return false;
    break;
  case FF_CLIHOST: 
    if (info->host != flow->get_cli_host())
      return false;
    break;
  case FF_SRVHOST: 
    if (info->host != flow->get_srv_host())
      return false;
    break;
  case FF_PROTOCOL: 
    if (info->protocol != flow->get_protocol())
      return false;
    break;
  case FF_NDPIPROTOCOL: 
    if (info->ndpi_protocol != flow->get_detected_protocol())
      return false;
    break;
  default: 
    ntop->getTrace()->traceEvent(TRACE_WARNING,
				 "Wrong value to flow selection (walker)");
    return true;
  }

  flow->lua(info->vm, info->allowed_hosts, false /* Minimum details */);

  info->count++;
  if (info->limit > 0 && info->count > info->limit)
    return true;

  return false; /* false = keep on walking */
}

/* **************************************** */

void FlowsManager::select(lua_State* vm,
                          patricia_tree_t *allowed_hosts,
                          enum flowsField field,
                          void *value,
                          void *auxiliary_value,
                          unsigned long limit) {
  struct flow_details_info info;
  char * host_ip;
  u_int vlan_id;

  memset(&info, 0, sizeof(info));
  info.vm = vm, info.allowed_hosts = allowed_hosts, info.field = field;

  switch(field) {
  case FF_NONE:
    break;

  case FF_HOST:
  case FF_CLIHOST:
  case FF_SRVHOST:
    host_ip = (char *)value;
    vlan_id = auxiliary_value ? *((u_int *)auxiliary_value) : 0;
    info.host = intf->getHost(host_ip, vlan_id);
    break;

  case FF_PROTOCOL:
    info.protocol = *((u_int8_t *)value);
    break;

  case FF_NDPIPROTOCOL: 
    info.ndpi_protocol = *((u_int16_t *)value);
    break;

  default:
    ntop->getTrace()->traceEvent(TRACE_WARNING,	"Wrong value to flow selection");
    return;
  }

  if((field != FF_HOST && field != FF_CLIHOST && field != FF_SRVHOST) ||
     (info.host != NULL && info.host->match(allowed_hosts)))
    intf->get_flows_hash()->walk(flows_select_walker, (void*)&info);
}

enum SQLfield { SF_NONE, SF_SELECT, SF_FROM, SF_WHERE, SF_AND, SF_LIMIT, SF_TOK };
#define BUFSIZE 20

int FlowsManager::retrieve(lua_State* vm, patricia_tree_t *allowed_hosts, char *SQL) {
  char *where;
  bool twhere = false;
  enum SQLfield previous = SF_NONE;
  char *tok = NULL;
  int toknum = 0, where_toknum = 0;

  enum flowsField field = FF_NONE;
  /* XXX unify types */
  char value[BUFSIZE];
  u_int8_t svalue;
  u_int16_t lvalue;
  u_int auxiliary_value;
  void *pvalue = NULL;
  void *pauxiliary_value = NULL;
  unsigned limit = 0;

  tok = strtok_r(SQL, " ", &where);
  while (tok != NULL) {
    /* First token: we must have SELECT */
    if (toknum == 0) {
      int selcmp = strncmp(tok, "SELECT", 6);
      if (previous != SF_NONE || selcmp != 0)
        return 1;
      if (selcmp == 0)
        previous = SF_SELECT;
      goto ahead;
    }

    /* Check if we are processing a keyword */
    if (strncmp(tok, "FROM", 4) == 0) {
      previous = SF_FROM;
      goto ahead;
    } else if (strncmp(tok, "WHERE", 5) == 0) {
      previous = SF_WHERE;
      twhere = true;
      goto ahead;
    } else if (strncmp(tok, "AND", 3) == 0) {
      previous = SF_AND;
      goto ahead;
    } else if (strncmp(tok, "LIMIT", 5) == 0) {
      previous = SF_LIMIT;
      goto ahead;
    }

    /* Else must be a token */
    switch(previous) {
    case SF_SELECT:
      /* XXX as of now we handle only selecting all */
      if (strncmp(tok, "*", 1) != 0)
        return 2;
      break;
    case SF_FROM:
      /* XXX implement aggregations */
      break;
    case SF_WHERE:
    case SF_AND:
      switch (where_toknum) {
      case 0:  /* must be a keyword */
        if (previous == SF_WHERE) {
          if (strncmp(tok, "host", 4) == 0) {
            field = FF_HOST;
          } else if (strncmp(tok, "clihost", 7) == 0)
            field = FF_CLIHOST;
          else if (strncmp(tok, "srvhost", 7) == 0)
            field = FF_SRVHOST;
          else if (strncmp(tok, "protocol", 8) == 0)
            field = FF_PROTOCOL;
          else if (strncmp(tok, "ndpiprotocol", 12) == 0)
            field = FF_NDPIPROTOCOL;
          else
            return 3;
        } else if (twhere == true) {
          if (strncmp(tok, "vlan", 4) != 0)
            return 3;
        }
        where_toknum++;
        break;
      case 1:
        /* XXX handle also other operators */
        if (strncmp(tok, "=", 1) != 0)
          return 2;
        where_toknum++;
        break;
      case 2:
        if (previous == SF_WHERE) {
          if (field == FF_HOST || field == FF_CLIHOST || field == FF_SRVHOST) {
            strncpy(value, tok, sizeof(value));
            pvalue = value;
          } else if (field == FF_PROTOCOL) {
            svalue = atoi(tok);
            pvalue = &svalue;
          } else if (field == FF_NDPIPROTOCOL) {
            lvalue = atoi(tok);
            pvalue = &lvalue;
          } else
            return 3;
        } else if (twhere == true) {
          /* Valid only if WHERE clause specified */
          auxiliary_value = atoi(tok);
          pauxiliary_value = &auxiliary_value;
        }
        where_toknum = 0;
        break;
      default:
        return 2;
      }
      break;
    case SF_LIMIT:
      limit = atoi(tok);
      break;
    default:
      return 2;
    }

ahead:
    tok = strtok_r(NULL, " ", &where);
    toknum++;
  }

  select(vm, allowed_hosts, field, pvalue, pauxiliary_value, limit);

  return 0;
}
