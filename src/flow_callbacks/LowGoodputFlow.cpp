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

void LowGoodputFlow::checkLowGoodput(Flow *f) {
  u_int16_t c_score = 10, s_score = 10;

  if(!f->isTCP())                 return; /* TCP only                      */
  if(!f->isThreeWayHandshakeOK()) return; /* Three way handshake completed */
  if(f->get_packets() <= 3)       return; /* Minimum number of packets     */
  if(f->get_goodput_ratio() > 60) return; /* Goodput less than 60%         */

  switch(f->get_detected_protocol().app_protocol) {
  case NDPI_PROTOCOL_MDNS:
  case NDPI_PROTOCOL_NTOP:
  case NDPI_PROTOCOL_SIGNAL:
  case NDPI_PROTOCOL_QQ:
  case NDPI_PROTOCOL_IRC:
  case NDPI_PROTOCOL_TELNET:
  case NDPI_PROTOCOL_SSH:
  case NDPI_PROTOCOL_WHATSAPP:
  case NDPI_PROTOCOL_WHATSAPP_CALL:
  case NDPI_PROTOCOL_WHATSAPP_FILES:
  case NDPI_PROTOCOL_TELEGRAM:
  case NDPI_PROTOCOL_KAKAOTALK:
  case NDPI_PROTOCOL_KAKAOTALK_VOICE:
  case NDPI_PROTOCOL_WECHAT:
    return; /* Exclusion list */
  default:
    break; /* Continue with the check */
  };

  f->triggerAlertAsync(LowGoodputFlowAlert::getClassType(), getSeverity(), c_score, s_score);
}

/* ***************************************************** */

void LowGoodputFlow::periodicUpdate(Flow *f) {
  checkLowGoodput(f);
}

/* ***************************************************** */

void LowGoodputFlow::flowEnd(Flow *f) {
  checkLowGoodput(f);
}

/* ***************************************************** */

FlowAlert *LowGoodputFlow::buildAlert(Flow *f) {
  return new LowGoodputFlowAlert(this, f);
}

/* ***************************************************** */
