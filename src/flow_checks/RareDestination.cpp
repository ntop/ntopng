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

u_int32_t RareDestination::getDestinationHash(Flow *f, u_int8_t *destType) {

  u_int32_t hash = 0;

  if (f->isLocalToLocal()) {

    *destType = 0;  // local destination
    LocalHost *ldest = (LocalHost*)f->get_srv_host();

    if (!ldest->isLocalUnicastHost() && ldest->isDHCPHost()) {
      Mac *mac = ldest->getMac();
      hash = mac ? mac->key() : 0;
    }
    else if (ldest->isIPv6() || ldest->isIPv4()) {
      hash =  ldest->get_ip()->key();
    }

  }
  else if (f->isLocalToRemote()) {
    *destType = 1;  // remote destination
    hash = Utils::hashString(f->getFlowServerInfo());
  }

  return hash;
}

/* ***************************************************** */

void RareDestination::protocolDetected(Flow *f) {

  bool is_rare_destination = false;

  if(f->get_cli_host()->isLocalHost() && (f->getFlowServerInfo() != NULL || !f->get_srv_ip_addr()->isEmpty()) ) {

    time_t t_now = time(NULL);
    NetworkInterface *iface = f->getInterface();

    u_int8_t destType;
    u_int32_t hash = getDestinationHash(f, &destType);
    if(hash == 0) return;

    /* initial training */
    if (iface->getRareDestInitialTraining()) {

      destType == 0 ? iface->setLocalRareDestBitmap(hash) : iface->setRemoteRareDestBitmap(hash);

      if (!iface->getRareDestTrainingStartTime())
        iface->setRareDestTrainingStartTime(t_now);

      else if (t_now - iface->getRareDestTrainingStartTime() >= RARE_DEST_TRAINING_DURATION)
        iface->endRareDestInitialTraining(t_now);
      
      return;
    }

    /* check if background training has to start */
    if (!iface->getRareDestTraining() &&
        t_now - iface->getRareDestTrainingEndTime() >= RARE_DEST_TRAINING_GAP) {
      iface->startRareDestTraining(t_now);
    }

    /* background training */
    if (iface->getRareDestTraining()) {
      destType == 0 ? iface->setLocalRareDestBitmap_BG(hash) : iface->setRemoteRareDestBitmap_BG(hash);

      /* check if background training has to end */
      if (t_now - iface->getRareDestTrainingStartTime() >= RARE_DEST_TRAINING_DURATION) {
        iface->endRareDestTraining(t_now);
        iface->swapRareDestBitmaps();
      }
    }
      
    /* update bitmap */
    if (destType == 0 && !iface->isSetLocalRareDestBitmap(hash)) {
      is_rare_destination = true;
      iface->setLocalRareDestBitmap(hash);
    }

    else if (destType == 1 && !iface->isSetRemoteRareDestBitmap(hash)) {
      is_rare_destination = true;
      iface->setRemoteRareDestBitmap(hash);
    }
  }

  if (is_rare_destination) {
    FlowAlertType alert_type = RareDestinationAlert::getClassType();
    u_int8_t c_score, s_score;
    risk_percentage cli_score_pctg = CLIENT_FAIR_RISK_PERCENTAGE;

    computeCliSrvScore(alert_type, cli_score_pctg, &c_score, &s_score);

    f->triggerAlertAsync(alert_type, c_score, s_score);
  }
}

/* ***************************************************** */

FlowAlert *RareDestination::buildAlert(Flow *f) {
  return new RareDestinationAlert(this, f);
}

/* ***************************************************** */
