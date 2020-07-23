/*
 *
 * (C) 2013-20 - ntop.org
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

class GenericHashEntry;

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
  GenericHashEntry **table; /**< Entry table. It is used for maintain an update history */
  char *name;
  u_int32_t num_hashes; /**< Number of hash */
  u_int32_t current_size; /**< Current size of hash (including idle or ready-to-purge elements) */
  u_int32_t max_hash_size; /**< Max size of hash */
  RwLock **locks;
  NetworkInterface *iface; /**< Pointer of network interface for this generic hash */
  u_int last_purged_hash; /**< Index of last purged hash */
  u_int last_entry_id; /**< An uniue identifier assigned to each entry in the hash table */
  u_int purge_step;
  u_int walk_idle_start_hash_id; /**< The id of the hash bucket from which to start walkIdle hash table walk */
  struct {
    u_int64_t num_idle_transitions;
    u_int64_t num_purged;
  } entry_state_transition_counters;

  vector<GenericHashEntry*> *idle_entries;             /**< Vector used by the offline thread in charge of deleting hash table entries */
  vector<GenericHashEntry*> *idle_entries_shadow;      /**< Vector prepared by the purgeIdle and periodically swapped to idle_entries */
  std::list<GenericHashEntry*> idle_entries_still_in_use; /**< Vector containing idle entries still in use (and thus not ready to be purged) */
  
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
   * @brief Get number of idle entries, that is, entries no longer in the hash table but still to be purged.
   * @details Inline method.
   *
   * @return The number of idle entries.
   */
  int32_t getNumIdleEntries() const;

  /**
   * @brief Add new entry to generic hash.
   * @details If current_size < max_hash_size, this method calculate a new hash key for the new entry, add it and update the current_size value.
   *
   * @param h Pointer of new entry to add.
   * @param h whether the bucket should be locked before addin the entry to the linked list.
   * @return True if the entry has been added successfully,
   *         False otherwise.
   *
   */
  bool add(GenericHashEntry *h, bool do_lock);

  /**
   * @brief Generic hash table walker
   * @details This method traverses all the non-idle entries of the hash table, calling
   *          the walker function on each of them. Function idle() is called for each entry
   *          to evaluate its state, determine if the entry is idle, and possibly call the walker.
   *
   * @param begin_slot begin hash slot. Use 0 to walk all slots
   * @param walk_all true = walk all hash, false, walk only one (non NULL) slot
   * @param walker A pointer to the comparison function.
   * @param user_data Value to be compared with the values of hash.
   */
  bool walk(u_int32_t *begin_slot, bool walk_all,
	    bool (*walker)(GenericHashEntry *h, void *user_data, bool *entryMatched), void *user_data);

  /**
   * @brief Hash table walker used only by an offline thread in charge of performing entries state changes
   * @details This method traverses all the entries of the hash table, including those that are idle
   *          and have been previously placed in the idle_entries vector, calling the walker function
   *          on each of them. Entries found in the idle_entries vector are deleted right after the call
   *          of the walker function against them.
   *          This method should only be called by an offline thread in charge of performing entries state changes (e.g., from
   *          protocol detected to activ) and operations associated to entries state changes (e.g., the
   *          call of a lua script against the entry).
   *
   * @param walker A pointer to the comparison function.
   * @param user_data Value to be compared with the values of hash.
   */
  virtual void walkAllStates(bool (*walker)(GenericHashEntry *h, void *user_data), void *user_data);

  /**
   * @brief Purge idle hash entries.
   *
   * @param force_idle Forcefully marks all hash_entry_state_active entries to
   * hash_entry_state_idle
   *
   * @return Numbers of purged entry, 0 otherwise.
   */
  u_int purgeIdle(bool force_idle);

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
   * @brief Return the name associated with the hash.
   * @details Inline method.
   *
   * @return Pointer to the name
   */
  inline const char* getName() const { return name; };

  /**
   * @brief Check whether the hash has empty space
   *
   * @return true if there is space left, or false if the hash is full
   */
  bool hasEmptyRoom();

  /**
   * @brief Populates a lua table with hash table stats, including
   * the state transitions
   *
   * @param vm A lua VM
   *
   * @return Current size of hash.
   */
  void lua(lua_State* vm);

};

#endif /* _GENERIC_HASH_H_ */
