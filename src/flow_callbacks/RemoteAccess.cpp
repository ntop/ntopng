/*
 *
 * (C) 2013-21 - ntop.org
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
#include "flow_callbacks_includes.h"

/* ***************************************************** */

void RemoteAccess::protocolDetected(Flow *f) {
  Host *cli = f->get_cli_host(), *srv = f->get_srv_host();

  switch(f->get_protocol_category()) {
  case NDPI_PROTOCOL_CATEGORY_REMOTE_ACCESS:
  case NDPI_PROTOCOL_CATEGORY_VPN:
  case NDPI_PROTOCOL_CATEGORY_FILE_SHARING:
    if(cli) cli->incrRemoteAccess();
    if(srv) srv->incrRemoteAccess();

    break;
  default:
    ;
  }
}

/* ***************************************************** */

void RemoteAccess::flowEnd(Flow *f) {
  Host *cli = f->get_cli_host(), *srv = f->get_srv_host();
  u_int8_t c_score = 10, s_score = 10;
  
  switch(f->get_protocol_category()) {
  case NDPI_PROTOCOL_CATEGORY_REMOTE_ACCESS:
  case NDPI_PROTOCOL_CATEGORY_VPN:
  case NDPI_PROTOCOL_CATEGORY_FILE_SHARING:
    if(cli) cli->decrRemoteAccess();
    if(srv) srv->decrRemoteAccess();

    f->triggerAlertAsync(RemoteAccessAlert::getClassType(), getSeverity(), c_score, s_score);
    break;
  default:
    ;
  }
}

/* ***************************************************** */

FlowAlert *RemoteAccess::buildAlert(Flow *f) {
  return new RemoteAccessAlert(this, f);
}

/* ***************************************************** */
