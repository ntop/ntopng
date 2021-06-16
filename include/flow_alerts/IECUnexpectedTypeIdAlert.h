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

#ifndef _IEC_UNEXPECTED_TYPE_ID_ALERT_H_
#define _IEC_UNEXPECTED_TYPE_ID_ALERT_H_

#include "ntop_includes.h"

class IECUnexpectedTypeIdAlert : public FlowAlert {
 private:
  u_int16_t asdu;
  u_int8_t type_id;
  u_int8_t cause_tx;
  u_int8_t negative;

  ndpi_serializer* getAlertJSON(ndpi_serializer* serializer);

 public:
  static FlowAlertType getClassType() { return { flow_alert_iec_unexpected_type_id, alert_category_security }; }
  static u_int8_t      getDefaultScore() { return SCORE_LEVEL_NOTICE; };

  IECUnexpectedTypeIdAlert(FlowCheck *c, Flow *f, u_int8_t _type_id, u_int16_t _asdu, u_int8_t _cause_tx, u_int8_t _negative) : FlowAlert(c, f) { 
    type_id = _type_id;
    asdu = _asdu;
    cause_tx = _cause_tx;
    negative  = _negative;
  };
  ~IECUnexpectedTypeIdAlert() { };

  FlowAlertType getAlertType() const { return getClassType(); }
};

#endif /* _IEC_UNEXPECTED_TYPE_ID_ALERT_H_ */
