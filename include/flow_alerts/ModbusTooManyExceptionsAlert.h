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

#ifndef _MODBUS_TOO_MANY_EXCEPTIONS_ALERT_H_
#define _MODBUS_TOO_MANY_EXCEPTIONS_ALERT_H_

#include "ntop_includes.h"

class ModbusTooManyExceptionsAlert : public FlowAlert {
 private:
  u_int32_t num_exceptions;

  ndpi_serializer* getAlertJSON(ndpi_serializer* serializer);

 public:
  static FlowAlertType getClassType() {
    return {flow_alert_modbus_too_many_exceptions, alert_category_security};
  }
  static u_int8_t getDefaultScore() { return SCORE_LEVEL_ERROR; };

  ModbusTooManyExceptionsAlert(FlowCheck* c, Flow* f, u_int32_t _num_exceptions) : FlowAlert(c, f) {
    num_exceptions = _num_exceptions;
  };
  ~ModbusTooManyExceptionsAlert(){};

  bool autoAck() const { return false; };
  
  FlowAlertType getAlertType() const { return getClassType(); }
};

#endif /* _MODBUS_TOO_MANY_EXCEPTIONS_ALERT_H_ */
