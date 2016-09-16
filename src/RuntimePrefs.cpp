/*
 *
 * (C) 2013-16 - ntop.org
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

/* ******************************************* */

RuntimePrefs::RuntimePrefs() {
  /* Force preferences creation */
  are_local_hosts_rrd_created();
  are_hosts_ndpi_rrd_created();
  are_hosts_categories_rrd_created();
  is_nbox_integration_enabled();

  if(are_alerts_syslog_enabled())
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Dumping alerts into syslog");
#ifdef NTOPNG_PRO
  if(are_alerts_nagios_enabled())
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Sending alerts to nagios");
#endif
}

/* ******************************************* */

void RuntimePrefs::set_alerts_syslog(bool enable) {
  ntop->getRedis()->set((char*)CONST_RUNTIME_PREFS_ALERT_SYSLOG,
			enable ? (char*)"1" : (char*)"0", 0);
}

/* ******************************************* */

#ifdef NTOPNG_PRO
void RuntimePrefs::set_alerts_nagios(bool enable) {
  ntop->getRedis()->set((char*)CONST_RUNTIME_PREFS_ALERT_NAGIOS,
			enable ? (char*)"1" : (char*)"0", 0);
}
#endif

/* ******************************************* */

void RuntimePrefs::set_nbox_integration(bool enable) {
  ntop->getRedis()->set((char*)CONST_RUNTIME_PREFS_NBOX_INTEGRATION,
			enable ? (char*)"1" : (char*)"0", 0);
}

/* ******************************************* */

bool RuntimePrefs::are_alerts_syslog_enabled() {
  char rsp[32];

  if(ntop->getRedis()->get((char*)CONST_RUNTIME_PREFS_ALERT_SYSLOG,
			   rsp, sizeof(rsp)) < 0) {
    set_alerts_syslog(true);
    return(true);
  } else
    return((strcmp(rsp, "1") == 0) ? true : false);
}

/* ******************************************* */

bool RuntimePrefs::are_probing_alerts_enabled() {
  char rsp[32];

  if(ntop->getRedis()->get((char*)CONST_RUNTIME_PREFS_ALERT_PROBING,
			   rsp, sizeof(rsp)) < 0) {
    return(true);
  } else
    return((strcmp(rsp, "1") == 0) ? true : false);
}

/* ******************************************* */

#ifdef NTOPNG_PRO
bool RuntimePrefs::are_alerts_nagios_enabled() {
  char rsp[32];

  if(ntop->getRedis()->get((char*)CONST_RUNTIME_PREFS_ALERT_NAGIOS,
			   rsp, sizeof(rsp)) < 0) {
    set_alerts_nagios(false);
    return(false);
  } else
    return((strcmp(rsp, "1") == 0) ? true : false);
}
#endif

/* ******************************************* */

bool RuntimePrefs::is_nbox_integration_enabled() {
  char rsp[32];

  if(ntop->getRedis()->get((char*)CONST_RUNTIME_PREFS_NBOX_INTEGRATION,
			   rsp, sizeof(rsp)) < 0) {
    set_nbox_integration(false);
    return(false);
  } else
    return((strcmp(rsp, "1") == 0) ? true : false);
}

/* ******************************************* */

void RuntimePrefs::set_local_hosts_rrd_creation(bool enable) {
  ntop->getRedis()->set((char*)CONST_RUNTIME_PREFS_HOST_RRD_CREATION,
			enable ? (char*)"1" : (char*)"0", 0);
}

/* ******************************************* */

bool RuntimePrefs::are_local_hosts_rrd_created() {
  char rsp[32];

  if(ntop->getRedis()->get((char*)CONST_RUNTIME_PREFS_HOST_RRD_CREATION,
			   rsp, sizeof(rsp)) < 0) {
    set_local_hosts_rrd_creation(true);
    return(true);
  } else
    return((strcmp(rsp, "1") == 0) ? true : false);
}

/* ******************************************* */

void RuntimePrefs::set_hosts_ndpi_rrd_creation(bool enable) {
  ntop->getRedis()->set((char*)CONST_RUNTIME_PREFS_HOST_NDPI_RRD_CREATION,
			enable ? (char*)"1" : (char*)"0", 0);
}

/* ******************************************* */

bool RuntimePrefs::are_hosts_ndpi_rrd_created() {
  char rsp[32];

  if(ntop->getRedis()->get((char*)CONST_RUNTIME_PREFS_HOST_NDPI_RRD_CREATION,
			   rsp, sizeof(rsp)) < 0) {
    set_hosts_ndpi_rrd_creation(false); /* Just to save space */
    return(true);
  } else
    return((strcmp(rsp, "1") == 0) ? true : false);
}

/* ******************************************* */

void RuntimePrefs::set_hosts_activity_rrd_creation(bool enable) {
  ntop->getRedis()->set((char*)CONST_RUNTIME_PREFS_HOST_ACTIVITY_RRD_CREATION,
			enable ? (char*)"1" : (char*)"0", 0);
}

/* ******************************************* */

bool RuntimePrefs::are_hosts_activity_rrd_created() {
  char rsp[32];

  if(ntop->getRedis()->get((char*)CONST_RUNTIME_PREFS_HOST_ACTIVITY_RRD_CREATION,
			   rsp, sizeof(rsp)) < 0) {
    set_hosts_ndpi_rrd_creation(false);
    return(false);
  } else
    return((strcmp(rsp, "1") == 0) ? true : false);
}

/* ******************************************* */

void RuntimePrefs::set_hosts_categories_rrd_creation(bool enable) {
  ntop->getRedis()->set((char*)CONST_RUNTIME_PREFS_HOST_CATE_RRD_CREATION,
			enable ? (char*)"1" : (char*)"0", 0);
}

/* ******************************************* */

bool RuntimePrefs::are_hosts_categories_rrd_created() {
  char rsp[64];

  if(ntop->getRedis()->get((char*)CONST_RUNTIME_PREFS_HOST_CATE_RRD_CREATION,
			   rsp, sizeof(rsp)) < 0) {
    set_hosts_categories_rrd_creation(false); /* Just to save space */
    return(true);
  } else
    return((strcmp(rsp, "1") == 0) ? true : false);
}

/* ******************************************* */

#ifdef NOTUSED
void RuntimePrefs::set_throughput_unit(bool use_bps) {
  ntop->getRedis()->set((char*)CONST_RUNTIME_PREFS_THPT_CONTENT,
			use_bps ? (char*)"bps" : (char*)"pps", 0);
}
#endif

