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

void RemoteToLocalInsecureProto::protocolDetected(Flow *f) {
  if(f->isRemoteToLocal()) {
    /* Remote to local */
    bool unsafe;
    u_int16_t c_score, s_score = 5;
    
    switch(f->get_protocol_breed()) {
    case NDPI_PROTOCOL_UNSAFE:
      unsafe = true;
      c_score = 50;
      break;

    case NDPI_PROTOCOL_POTENTIALLY_DANGEROUS:
      unsafe = true;
      c_score = 100;
      break;
      
    case NDPI_PROTOCOL_DANGEROUS:
      unsafe = true;
      c_score = SCORE_MAX_SCRIPT_VALUE;
      break;

    default:
      unsafe = false;
      break;
    }  

    if(!unsafe) {
      switch(f->get_protocol_category()) {
      case CUSTOM_CATEGORY_MALWARE:
      case CUSTOM_CATEGORY_BANNED_SITE:
	c_score = SCORE_MAX_SCRIPT_VALUE;
	unsafe = true;
	break;

      default:
	break;
      }
    }
  
    if(unsafe)
      f->triggerAlertAsync(RemoteToLocalInsecureProtoAlert::getClassType(), getSeverity(), c_score, s_score);
  }
}

/* ***************************************************** */

FlowAlert *RemoteToLocalInsecureProto::buildAlert(Flow *f) {
  return new RemoteToLocalInsecureProtoAlert(this, f, getSeverity());
}

/* ***************************************************** */
