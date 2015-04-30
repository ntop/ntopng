/*
 *
 * (C) 2013-15 - ntop.org
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

#ifndef _HISTORICAL_INTERFACE_H_
#define _HISTORICAL_INTERFACE_H_

#include "ntop_includes.h"

class HistoricalInterface : public ParserInterface {
 private:
  u_int32_t num_historicals,     /*< Number of historical files loaded*/
              num_query_error,     /*< Number of query error*/
              num_open_error,      /*< Number of error while opening a files*/
              num_missing_file ;   /*< Number of missing files*/

  int interface_id;         /*< Interface index of the current data*/
  time_t from_epoch;            /*< From epoch of the current data*/
  time_t to_epoch;                /*< To Epoch of the current data*/
  bool on_load;                     /*< Set on true when loading historical data, false otherwise*/

  /**
   * @brief Callback for the sqlite_exe
   * @details For each flows read on the DB call @ParserInterface::parse_flows,
   *                in order to inject the flow into the Interface.
   *
   * @param data
   * @param argc Number of columns in the result.
   * @param argv An array of pointers to strings, one for each column.
   * @param azColName An array of pointers to strings where each entry represents the name of corresponding result column.
   * @return non-zero in case of error, zero otherwise.
   */
  static int sqlite_callback(void *data, int argc, char **argv, char **azColName);
  /**
   * @brief Rest all statistic information of historical interface instance.
   * @details Reset information of current data and the counter of error and loaded files.
   */
  void resetStats();

 public:
  /**
   * @brief Constructor
   * @details Create a new instance and set @ref purge_idle_flows_hosts to false in order to show all the flows.
   *
   * @param _endpoint Interface name.
   */
  HistoricalInterface(const char *_endpoint);

  /**
   * @brief Get interface type
   * @return sqlite
   */
  inline const char* get_type()         { return(CONST_INTERFACE_TYPE_SQLITE);      };
  /**
   * @brief Check if ndpi is enable for this interface
   * @return True if ndpi is enable, false otherwise.
   */
  inline bool is_ndpi_enabled()         { return(false);      };
  /**
   * @brief Check if the loading process running
   * @return True if is running, false otherwise.
   */
   inline bool is_on_load()         { return(on_load);      };
  /**
   * @brief Set current interface index
   *
   * @param p_id Interface index
   */
  inline void setDataIntrefaceId(int p_id) { interface_id = p_id; };
  /**
   * @brief Set current from epoch
   * @details Epoch of first loaded files.
   *
   * @param p_epoch Epoch time
   */
  inline void setFromEpoch(time_t p_epoch) { from_epoch = p_epoch; };
  /**
   * @brief Set current to epoch
   * @details Epoch of last loaded files.
   *
   * @param p_epoch Epoch time
   */
  inline void setToEpoch(time_t p_epoch) { to_epoch = p_epoch; };

  /**
   * @brief Get current interface index.
   * @return Data interface index if set, otherwise return zero.
   */
  inline int getDataInterfaceId() { return interface_id;};
  /**
   * @brief Get from epoch
   * @details Epoch of first loaded files.]
   * @return Epoch time if set, zero otherwise.
   */
  inline time_t getFromEpoch() { return from_epoch;};
  /**
   * @brief Get to epoch
   * @details Epoch of last loaded files.
   * @return Epoch time if set, zero otherwise.
   */
  inline time_t getToEpoch() { return to_epoch;};

  /**
   * @brief Get number of open error
   * @return Number of errors encountered while opening files.
   */
  inline u_int32_t getOpenError() { return num_open_error;};
  /**
   * @brief Get number of query error
   * @return Number of errors encountered during the execution of the query.
   */
  inline u_int32_t getQueryError() { return num_query_error;};
  /**
   * @brief Get number of missing error
   * @return Number of missing files.
   */
  inline u_int32_t getMissingFiles() { return num_missing_file;};
  /**
   * @brief Get total number of file inside the interval
   * @return Number of files.
   */
  inline u_int32_t getNumFiles() { return num_historicals;};

  /**
   * @brief Load historical data
   * @details Check if the file exists and then load flows from it.
   *
   * @param p_file_name Path to the historical data file
   * @return CONST_HISTORICAL_OK in case of success, CONST_HISTORICAL_FILE_ERROR or CONST_HISTORICAL_OPEN_ERROR in case of error.
   */
  int loadData(char * p_file_name);
  /**
   * @brief Load historical data
   * @details Loop on the interval, with step of 5 minute. For each step make a correct file path and the load flows form it.
   *                Until an error occurs.
   *
   * @return CONST_HISTORICAL_OK.
   */
  int loadData();
  /**
   * @brief Start loading historical data process
   * @details Cleanup the interface, set on true @ref on_load and initialize the interval values.
   *
   * @param p_from_epoch Epoch time
   * @param p_to_epoch Epoch time
   * @param p_interface_id Index of the interface from which you want to load the data
   */
  void startLoadData(time_t  p_from_epoch, time_t p_to_epoch, int p_interface_id);
  /**
   * @brief Get Number of dropped packets
   * @return Zero
   */
  inline u_int getNumDroppedPackets()   { return 0; };
  /**
   * @brief For this interface is impossible set packet filter.
   * @return False
   */
  bool set_packet_filter(char *filter);

  /**
   * @brief Shutdown the interface
   * @details Reset the stats and cleanup the interface.
   */
  void shutdown();
  /**
   * @brief Cleanup
   * @details Remove all information about flows, hosts and reset the interface stats.
   */
  void cleanup();
};

#endif /* _HISTORICAL_INTERFACE_H_ */

