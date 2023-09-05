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

u_int32_t RareDestination::getDestinationHash(Flow *f) {

  u_int32_t hash = 0;
  Host *dest = f->get_srv_host();

  if (f->isLocalToLocal()) {

    char buf[64];

    if (!dest->isMulticastHost() && dest->isDHCPHost()) {
      char *mac = dest->getMac()->print(buf,sizeof(buf));
      hash = Utils::hashString(mac);
    }
    else if (dest->isIPv6() || dest->isIPv4()) {
      char *ip = dest->get_ip()->print(buf,sizeof(buf));
      hash = Utils::hashString(ip);
    }

  }
  else if (f->isLocalToRemote()) {
    hash = Utils::hashString(f->getFlowServerInfo());
  }

  return hash;
}

/* ***************************************************** */

void RareDestination::protocolDetected(Flow *f) {

  bool is_rare_destination = false;

  if(f->getFlowServerInfo() != NULL && f->get_cli_host()->isLocalHost()) {
    
    LocalHost *cli_lhost = (LocalHost*)f->get_cli_host();
    
    time_t t_now = time(NULL);

    /* check if training has to start */
    if (!cli_lhost->getStartRareDestTraining()) {
      cli_lhost->startRareDestTraining();
      cli_lhost->setStartRareDestTraining(t_now);
    }

    u_int32_t hash = getDestinationHash(f);
    if(hash == 0) return;

    /* if training */
    if (cli_lhost->isTrainingRareDest()) {
      cli_lhost->setRareDestBitmap(hash);

      /* check if training has to end */
      if (t_now - cli_lhost->getStartRareDestTraining() >= 3600 /* RARE_DEST_DURATION_TRAINING */ ) {
        cli_lhost->stopRareDestTraining();
        cli_lhost->setLastRareDestTraining(t_now);
      }
      
      return;
    }

    /* check if training has to restart */
    time_t elapsedFromLastTraining = t_now - cli_lhost->getLastRareDestTraining();

    if (elapsedFromLastTraining >= 2*RARE_DEST_LAST_TRAINING_GAP ) {
      cli_lhost->clearRareDestBitmaps();
      cli_lhost->setStartRareDestTraining(0);

      return;
    }

    if ( elapsedFromLastTraining >= RARE_DEST_LAST_TRAINING_GAP ) {
      cli_lhost->updateRareDestBitmaps();
      cli_lhost->setStartRareDestTraining(0);
      return;
    }

    /* update */
    if (!cli_lhost->isSetRareDestBitmap(hash)){
      cli_lhost->setRareDestBitmap(hash);
      if (!cli_lhost->isSetRareDestLastBitmap(hash)) {
        is_rare_destination = true;
      }
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
