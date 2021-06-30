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

#ifndef _HOST_ALERT_H_
#define _HOST_ALERT_H_

#include "ntop_includes.h"

class HostCheck;

class HostAlert {
 private:
  Host *host;
  bool released; /* to be released */
  bool expiring; /* engaged, under re-evaluation */
  HostCheckID check_id;
  std::string check_name;
  time_t engage_time;
  time_t release_time;
  risk_percentage cli_pctg; /* The fraction of total risk that goes to the client */
  bool is_attacker, is_victim; /* Whether the host of this alert is considered to be an attacker o a victim */
  /* 
     Adds to the passed `serializer` (generated with `getAlertSerializer`) information specific to this alert
   */
  virtual ndpi_serializer* getAlertJSON(ndpi_serializer* serializer)  { return serializer; }  

 public:
  HostAlert(HostCheck *c, Host *h, risk_percentage _cli_pctg);
  virtual ~HostAlert();

  inline u_int8_t getCliScore() const { return (cli_pctg * getAlertScore()) / 100; }
  inline u_int8_t getSrvScore() const { return (getAlertScore() - getCliScore());  }
  /*
    An alert is assumed to be client if the client score is positive and greater than the server score.
    Similarly, it is assumed to be server when the server score is positive and greater than the client score.
   */
  inline bool isClient()   const { return getCliScore() > 0 && getCliScore() > getSrvScore(); }
  inline bool isServer()   const { return getSrvScore() > 0 && getSrvScore() > getCliScore(); }

  inline void setAttacker()      { is_attacker = true; }
  inline void setVictim()        { is_victim = true;   }
  inline bool isAttacker() const { return is_attacker; }
  inline bool isVictim()   const { return is_victim;   }

  virtual HostAlertType getAlertType()  const = 0;
  virtual u_int8_t      getAlertScore() const { return SCORE_LEVEL_NOTICE; };

  /* Alert automatically released when the condition is no longer satisfied. */
  virtual bool hasAutoRelease()  { return true; }

  inline Host *getHost() const                  { return(host);          }
  inline HostCheckID getCheckType() const { return(check_id);   }
  inline std::string getCheckName() const    { return(check_name); }

  inline void setEngaged()       { expiring = released = false; }

  inline void setExpiring()      { expiring = true; }
  inline bool isExpired()        { return expiring; }

  inline void release()          { released = true; release_time = time(NULL); }
  inline bool isReleased()       { return released; }

  inline time_t getEngageTime()  { return engage_time;  }
  inline time_t getReleaseTime() { return release_time; }

  inline bool equals(HostAlertType type) { return getAlertType().id == type.id; }

  /* Generates the JSON alert serializer with base information and per-check information gathered with `getAlertJSON`.
   *  NOTE: memory must be freed by the caller. */
  ndpi_serializer* getSerializedAlert();
};

#endif /* _HOST_ALERT_H_ */
