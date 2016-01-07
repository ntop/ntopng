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

#ifndef _RUNTIME_PREFS_H_
#define _RUNTIME_PREFS_H_

#include "ntop_includes.h"

/** @defgroup Preferences Preferences
 * Ntopng preferences
 */


/** @class RuntimePrefs
 *  @brief Implement the user runtime preference for ntopng.
 *
 *  @ingroup Preferences
 *
 */
class RuntimePrefs {
 public:
  /**
   * @brief A Constructor.
   * @details Creating a new Runtime preference instance.
   *
   * @return A new instance of RuntimePrefs.
   */
  RuntimePrefs();

   /**
   * @brief Set alert syslog preference.
   * @details Enable or disable the preference and save it in Redis.
   *
   * @param enable Preference boolean value.
   */
  void set_alerts_syslog(bool enable);

#ifdef NTOPNG_PRO
  /**
   * @brief Set alert nagios preference.
   * @details Enable or disable the preference and save it in Redis.
   *
   * @param enable Preference boolean value.
   */
  void set_alerts_nagios(bool enable);

   /**
   * @brief Get the alert nagios preference.
   * @details Read for Redis the preference, if it doesn't exist
   * the preference will be set to default value (FALSE).
   * @return The preference boolean value
   */
  bool are_alerts_nagios_enable();
#endif

  /**
   * @brief Set nbox integrations preference.
   * @details Enable or disable the preference and save it in Redis.
   *
   * @param enable Preference boolean value.
   */
  void set_nbox_integration(bool enable);

   /**
   * @brief Get the nbox integration preference.
   * @details Read for Redis the preference, if it doesn't exist
   * the preference will be set to default value (FALSE).
   * @return The preference boolean value
   */
  bool is_nbox_integration_enabled();

  /**
   * @brief Get the alert syslog preference.
   * @details Read for Redis the preference, if it doesn't exist
   * the preference will be set to default value (TRUE).
   * @return The preference boolean value
   */
  bool are_alerts_syslog_enable();

  /**
   * @brief Set the local hosts rrd creation preference.
   * @details Enable or disable the preference and save it in Redis.
   *
   * @param enable Preference boolean value.
   */
  void set_local_hosts_rrd_creation(bool enable);
  /**
   * @brief Get the local hosts rrd creation preference.
   * @details Read for Redis the preference, if it doesn't exist
   * the preference will be set to default value (true).
   * @return The preference boolean value
   */
  bool are_local_hosts_rrd_created();
  /**
   * @brief Set the hosts ndpi rrd creation preference.
   * @details Enable or disable the preference and save it in Redis.
   *
   * @param enable Preference boolean value.
   */
  void set_hosts_ndpi_rrd_creation(bool enable);
  /**
   * @brief Get the hosts ndpi rrd creation preference.
   * @details Read for Redis the preference, if it doesn't exist
   * the preference will be set to default value (true).
   * @return The preference boolean value
   */
  bool are_hosts_ndpi_rrd_created();
  /**
   * @brief Set the throughput unit preference.
   * @details Save the unit preference in Redis. The preference will be
   * set to "bps" if @ref use_bps is true otherwise to "pps".
   *
   * @param use_bps Preference boolean value.
   */
  /**
   * @brief Set the hosts categories rrd creation preference.
   * @details Enable or disable the preference and save it in Redis.
   *
   * @param enable Preference boolean value.
   */
  void set_hosts_categories_rrd_creation(bool enable);
  /**
   * @brief Get the hosts categories rrd creation preference.
   * @details Read for Redis the preference, if it doesn't exist
   * the preference will be set to default value (true).
   * @return The preference boolean value
   */
  bool are_hosts_categories_rrd_created();
  /**
   * @brief Set the throughput unit preference.
   * @details Save the unit preference in Redis. The preference will be
   * set to "bps" if @ref use_bps is true otherwise to "pps".
   *
   * @param use_bps Preference boolean value.
   */
  void set_throughput_unit(bool use_bps);
};

#endif /* _RUNTIME_PREFS_H_ */
