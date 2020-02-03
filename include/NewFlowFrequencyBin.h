/*
 *
 * (C) 2020 - ntop.org
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

#ifndef _NEW_FLOW_FREQUENCY_BIN_H_
#define _NEW_FLOW_FREQUENCY_BIN_H_

#include "ntop_includes.h"

class NewFlowFrequencyBin : public Bin {
  u_int32_t lastFlowCreationEpoch;

 public:
  NewFlowFrequencyBin() { lastFlowCreationEpoch = 0; }

  inline void incFrequency(u_int32_t epoch) {
    if(lastFlowCreationEpoch != 0) {
      incBin(epoch - lastFlowCreationEpoch);
    }

    lastFlowCreationEpoch = epoch;
  }
};

#endif /* _NEW_FLOW_FREQUENCY_BIN_H_ */
