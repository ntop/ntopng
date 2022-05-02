/*
 *
 * (C) 2013-22 - ntop.org
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

/* **************************************************** */

FlowAlert::FlowAlert(FlowCheck *c, Flow *f) {
  flow = f;
  cli_attacker = srv_attacker = false;
  cli_victim = srv_victim = false;
  if (c) check_name = c->getName();
}

/* **************************************************** */

FlowAlert::~FlowAlert() {
}

/* ***************************************************** */

ndpi_serializer* FlowAlert::getSerializedAlert() {
  ndpi_serializer *serializer;

  serializer = (ndpi_serializer *) malloc(sizeof(ndpi_serializer));
  
  if(serializer == NULL)
    return NULL;

  if(ndpi_init_serializer(serializer, ndpi_serialization_format_json) == -1) {
    free(serializer);
    return NULL;
  }

  /* Add here global check information, common to any alerted flow */

  /* Guys used to link the alert back to the active flow */
  ndpi_serialize_string_uint64(serializer, "ntopng.key", flow->key());
  ndpi_serialize_string_uint64(serializer, "hash_entry_id", flow->get_hash_entry_id());

  /* Add information relative to this check */
  ndpi_serialize_start_of_block(serializer, "alert_generation");
  ndpi_serialize_string_string(serializer, "script_key", getCheckName().c_str());
  ndpi_serialize_string_string(serializer, "subdir", "flow");
  ndpi_serialize_end_of_block(serializer);

  /* Flow info */
  char buf[64];
  char *info = flow->getFlowInfo(buf, sizeof(buf), false);
  u_int16_t l7proto = flow->getLowerProtocol();

  ndpi_serialize_string_string(serializer, "info", info ? info : "");
  
  ndpi_serialize_start_of_block(serializer, "proto"); /* proto block */
  
  /* Adding protocol info; switch the lower application protocol */
  switch(l7proto) {
    case NDPI_PROTOCOL_DNS:
      ndpi_serialize_start_of_block(serializer, "dns");
      flow->getDNSInfo(serializer);
      ndpi_serialize_end_of_block(serializer);
      break;
  
    case NDPI_PROTOCOL_HTTP:
    case NDPI_PROTOCOL_HTTP_PROXY:
      ndpi_serialize_start_of_block(serializer, "http");
      flow->getHTTPInfo(serializer);
      ndpi_serialize_end_of_block(serializer);
      break;
  
    case NDPI_PROTOCOL_TLS:
    case NDPI_PROTOCOL_MAIL_IMAPS:
    case NDPI_PROTOCOL_MAIL_SMTPS:
    case NDPI_PROTOCOL_MAIL_POPS:
    case NDPI_PROTOCOL_QUIC:
      ndpi_serialize_start_of_block(serializer, "tls");
      flow->getTLSInfo(serializer);
      ndpi_serialize_end_of_block(serializer);
      break; 

    case NDPI_PROTOCOL_IP_ICMP:
    case NDPI_PROTOCOL_IP_ICMPV6:
      ndpi_serialize_start_of_block(serializer, "icmp");
      flow->getICMPInfo(serializer);
      ndpi_serialize_end_of_block(serializer);
      break;

    case NDPI_PROTOCOL_MDNS:
      ndpi_serialize_start_of_block(serializer, "mdns");
      flow->getMDNSInfo(serializer);
      ndpi_serialize_end_of_block(serializer);
      break;
    
    case NDPI_PROTOCOL_NETBIOS:
      ndpi_serialize_start_of_block(serializer, "netbios");
      flow->getNetBiosInfo(serializer);
      ndpi_serialize_end_of_block(serializer);
      break;
    
    case NDPI_PROTOCOL_SSH:
      ndpi_serialize_start_of_block(serializer, "ssh");
      flow->getSSHInfo(serializer);
      ndpi_serialize_end_of_block(serializer);
      break;
  }

  if(flow->getErrorCode() != 0)
    ndpi_serialize_string_uint32(serializer, "l7_error_code", flow->getErrorCode());

  ndpi_serialize_end_of_block(serializer); /* proto block */

  /* This call adds check-specific information to the serializer */
  getAlertJSON(serializer);

  return serializer;
}
