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

#define rareDestEpoch 100  /* placeholder value */

/* ***************************************************** */
/*
  ndpi_bitmap_xor(ndpi_bitmap*, ndpi_bitmap*) defined in ndpi_api.h
*/

void RareDestination::protocolDetected(Flow *f) {
  bool is_rare_destination = false;

  if(f->getFlowServerInfo() != NULL) 
  {
    time_t timeNow = time(nullptr);
    Host *cliHost = f->get_cli_host();
    ndpi_bitmap *bMap = cliHost->getBMap();
    ndpi_bitmap *bDirty = cliHost->getBDirty();

    if (!ndpi_bitmap_cardinality(bMap)) {
      cliHost->setOngoingRareDestTraining(true);
      cliHost->clearSeenRareDestTraining();
      cliHost->setStartRareDestTraining(timeNow);
    }
    if (cliHost->isOngoingRareDestTraining() && cliHost->getSeenRareDestTraining() >= cliHost->getToSeeRareDestTraining() && timeNow - cliHost->getStartRareDestTraining() >= cliHost->getDurationRareDestTraining())
      cliHost->setOngoingRareDestTraining(false);

    if (!cliHost->isOngoingRareDestTraining() && timeNow - cliHost->getRareDestLastEpoch() >= rareDestEpoch)
    {
      if (timeNow - cliHost->getRareDestLastEpoch() >= 2*rareDestEpoch)
      {
        ndpi_bitmap_clear(bMap);
        ndpi_bitmap_clear(bDirty);
      }
      else
      {
        ndpi_bitmap_xor(bDirty, bMap);  // updates BDirty
        ndpi_bitmap_and(bMap, bDirty); // makes BMap = BDirty
      }
      cliHost->setRareDestLastEpoch(timeNow);
    }

    u_int32_t hash = hashFun(f);  // Yuriy's job
    if (ndpi_bitmap_isset(bMap, hash)
      ndpi_bitmap_unset(bDirty, hash);
    else {
      ndpi_bitmap_set(bMap, hash);
      if (!cliHost->isOngoingRareDestTraining()) is_rare_destination = true;
      else cliHost->incrementSeenRareDestTrainig();
    }
  }
  
  if(is_rare_destination) {
    FlowAlertType alert_type = RareDestinationAlert::getClassType();
    u_int8_t c_score, s_score;
    risk_percentage cli_score_pctg = CLIENT_FAIR_RISK_PERCENTAGE; 
    
    computeCliSrvScore(alert_type, cli_score_pctg, &c_score, &s_score);
    
    f->triggerAlertAsync(alert_type, c_score, s_score);
  }
}

/* ***************************************************** */

FlowAlert* RareDestination::buildAlert(Flow *f) {
  return new RareDestinationAlert(this, f);
}

/* ***************************************************** */
