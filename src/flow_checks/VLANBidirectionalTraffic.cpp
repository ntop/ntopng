/*
 *
 * (C) 2013-23 - ntop.org
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
#include "flow_checks_includes.h"

/* ***************************************************** */

VLANBidirectionalTraffic::VLANBidirectionalTraffic() : FlowCheck(ntopng_edition_community,
								 true /* Packet Interfaces only */,
								 true /* Exclude for nEdge */,
								 false /* Only for nEdge */,
								 true /* has_protocol_detected */,
								 false /* has_periodic_update */,
								 false /* has_flow_end */) {
  vlans = new (std::nothrow) Bitmask(4096);
};

/* ***************************************************** */

VLANBidirectionalTraffic::~VLANBidirectionalTraffic() {
  if(vlans) delete vlans;
};

/* ***************************************************** */

void VLANBidirectionalTraffic::checkBidirectionalTraffic(Flow *f) {
  if(!f) return;

  if(isServerNotLocal(f)) {
    /* alert should not be triggered for flow with local server (except multicast and broadcast) */
    VLANid vlan_id = f->get_vlan_id();

    if(checkVLAN(vlan_id)) {
      /* the flow vlan_id must be one of the vlans set up by the user  */

      if(f->get_bytes_cli2srv() > 0 && f->get_bytes_srv2cli() > 0) {
	/* the flow is bidirectional */
	FlowAlertType alert_type = VLANBidirectionalTrafficAlert::getClassType();
	u_int8_t c_score, s_score;
	risk_percentage cli_score_pctg = CLIENT_HIGH_RISK_PERCENTAGE;

	computeCliSrvScore(alert_type, cli_score_pctg, &c_score, &s_score);

	f->triggerAlertAsync(alert_type, c_score, s_score);
      }
    }
  }
}

/* ***************************************************** */

void VLANBidirectionalTraffic::protocolDetected(Flow *f) {
  checkBidirectionalTraffic(f);
}

/* ***************************************************** */

FlowAlert *VLANBidirectionalTraffic::buildAlert(Flow *f) {
  return(new VLANBidirectionalTrafficAlert(this, f));
}

/* ***************************************************** */

bool VLANBidirectionalTraffic::loadConfiguration(json_object *config) {
  FlowCheck::loadConfiguration(config); /* Parse parameters in common */
  json_object *whitelist_json, *whitelisted_domain_json;

  if(vlans != NULL) {
    vlans->clear_all_bits();

    if(json_object_object_get_ex(config, "items", &whitelist_json)) {
      for(u_int i = 0; i < (u_int)json_object_array_length(whitelist_json); i++) {
	u_int16_t vlan_id = (u_int16_t) -1;

	whitelisted_domain_json = json_object_array_get_idx(whitelist_json, i);
	vlan_id = (u_int16_t)json_object_get_int(whitelisted_domain_json);

	if(vlan_id != (u_int16_t)-1) {
	  if(!vlans->is_set_bit(vlan_id)) {
	    vlans->set_bit(vlan_id);
	  }
	}
      }
    }
  }

  return(true);
}

/* ***************************************************** */

bool VLANBidirectionalTraffic::checkVLAN(VLANid vlan_id) {
  return(vlans ? vlans->is_set_bit(vlan_id) : false);
}

/* ***************************************************** */

bool VLANBidirectionalTraffic::isServerNotLocal(Flow *f) {
  const IpAddress* srv_ip = f->get_srv_ip_addr();

  if(srv_ip == NULL)
    return(false);
  else
    return((srv_ip->isLocalHost() || srv_ip->isBroadMulticastAddress()) ? false : true);
}
