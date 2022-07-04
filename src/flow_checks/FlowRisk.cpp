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
#include "flow_checks_includes.h"

/* ***************************************************** */

/* NOTE: keep in sync with ParserInterface::processFlow() */
bool FlowRisk::ignoreRisk(Flow *f, ndpi_risk_enum r) {
  switch(r) {
  case NDPI_TLS_SELFSIGNED_CERTIFICATE:
    {
      ndpi_risk_params params[] = {
	{ NDPI_PARAM_ISSUER_DN, f->getTLSCertificateIssuerDN() }
      };
      
      if(ndpi_check_flow_risk_exceptions(f->getInterface()->get_ndpi_struct(), 1, params))
	return(true);
    }
    break;

  case NDPI_SUSPICIOUS_DGA_DOMAIN:
    {
      ndpi_risk_params params[] = {
	{ NDPI_PARAM_HOSTNAME, f->getDGADomain() }
      };
      
      if(ndpi_check_flow_risk_exceptions(f->getInterface()->get_ndpi_struct(), 1, params))
	return(true);
    }
    break;
    
  default:
    break;
  }
  
  return(false);
}

/* ***************************************************** */

void FlowRisk::protocolDetected(Flow *f) {
  ndpi_risk_enum r = handledRisk();
  
  if(f->hasRisk(r)) {
    u_int16_t cli_score, srv_score;
    ndpi_risk risk_bitmap;

    /* Check exceptions for ZMQ-delivered flows */
    if(f->getInterface()->get_type() == CONST_INTERFACE_TYPE_ZMQ) {
      if(ignoreRisk(f, r))
	return;
    }
    
    risk_bitmap = 0;
    NDPI_SET_BIT(risk_bitmap, r);

    ndpi_risk2score(risk_bitmap, &cli_score, &srv_score);

    f->triggerAlertAsync(getAlertType(), cli_score, srv_score);
  }
}

/* ***************************************************** */
