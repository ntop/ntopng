/*
 *
 * (C) 2013-18 - ntop.org
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

#ifndef _GENERIC_HASH_H_
#define _GENERIC_HASH_H_

#include "ntop_includes.h"

/** @defgroup MonitoringData Monitoring Data
 * This is the group that contains all classes and datastructures that handle monitoring data.
 */

/** @class GenericHash
 *  @brief Base hash class.
 *  @details Defined the base hash class for ntopng.
 *
 *  @ingroup MonitoringData
 *
 */
class GenericHash {
 protected:
  GenericHashEntry **table; /**< Entry table. It is used for maintain an update history.*/
  char *name;
  u_int32_t num_hashes; /**< Number of hash.*/
  u_int32_t current_size; /**< Current size of hash (including idle or ready-to-purge elements).*/
  u_int32_t max_hash_size; /**< Max size of hash.*/
  Mutex **locks, purgeLock;
  NetworkInterface *iface; /**< Pointer of network interface for this generic hash.*/
  u_int last_purged_hash; /**< Index of last purged hash.*/
  u_int purge_step;
  
 public:
  /**
   * @brief A Constructor
   * @details Creating a new GenericHash.
   *
   * @param _iface Network interface pointer for the new hash.
   * @param _num_hashes Number of hashes.
   * @param _max_hash_size Max size of new hash.
   * @param _name Hash name (debug)
   * @return A new Instance of GenericHash.
   */
  GenericHash(NetworkInterface *_iface, u_int _num_hashes,
	      u_int _max_hash_size, const char *_name);

  /**
   * @brief A Destructor
   */
  virtual ~GenericHash();
  /**
   * @brief Get number of entries.
   * @details Inline method.
   *
   * @return Current size of hash.
   */
  inline u_int32_t getNumEntries() { return(current_size); };
  /**
   * @brief Add new entry to generic hash.
   * @details If current_size < max_hash_size, this method calculate a new hash key for the new entry, add it and update the current_size value.
   *
   * @param h Pointer of new entry to add.
   * @return True if the entry has been added successfully,
   *         False otherwise.
   *
   */
  bool add(GenericHashEntry *h);
  /**
   * @brief Remove entry from generic hash
   * @details Check if the entry is present inside the hash, remove it and update the hash.
   *
   * @param h Pointer of entry to remove.
   * @return True if the entry has been remove successfully,
   *         False otherwise.
   * @warning GenericHashEntry* memory is NOT freed.
   */
  bool remove(GenericHashEntry *h);
  /**
   * @brief generic walker for the hash.
   * @details This method uses the walker function to compare each elements of the hash with the user data.
   *
   * @param begin_slot begin hash slot. Use 0 to walk all slots
   * @param walk_all true = walk all hash, false, walk only one (non NULL) slot
   * @param walker A pointer to the comparison function.
   * @param user_data Value to be compared with the values of hash.
   */
  bool walk(u_int32_t *begin_slot, bool walk_all,
	    bool (*walker)(GenericHashEntry *h, void *user_data, bool *entryMatched), void *user_data);

  /**
   * @brief Purge idle hash entries.
   *
   * @return Numbers of purged entry, 0 otherwise.
   */
  u_int purgeIdle();

  /**
   * @brief Purge all hash entries.
   *
   */
  void cleanup();

  /**
   * @brief Return the network interface instance associated with the hash.
   * @details Inline method.
   *
   * @return Pointer of network interface instance.
   */
  inline NetworkInterface* getInterface() { return(iface); };
  /**
   * @brief Find an entry by key value.
   *
   * @param key Key value to be found in the hash.
   * @return Pointer of entry that matches with the key parameter, NULL if there isn't entry with the key parameter or if the hash is empty.
   */
  GenericHashEntry* findByKey(u_int32_t key);

  /**
   * @brief Check whether the hash has empty space
   *
   * @return true if there is space left, or false if the hash is full
   */
  inline bool hasEmptyRoom() { return((current_size < max_hash_size) ? true : false); };
  inline u_int32_t getCurrentSize() { return current_size;}

  inline void disablePurge() { /* purgeLock.lock(__FILE__, __LINE__);   */ }
  inline void enablePurge()  { /* purgeLock.unlock(__FILE__, __LINE__); */ }
};

#endif /* _GENERIC_HASH_H_ */
