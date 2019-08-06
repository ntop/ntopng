/*
 *
 * (C) 2013-19 - ntop.org
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

#ifndef _GENERIC_HASH_ENTRY_H_
#define _GENERIC_HASH_ENTRY_H_

#include "ntop_includes.h"

/** @class GenericHashEntry
 *  @brief Base hash entry class.
 *  @details Defined the base hash entry class for ntopng.
 *
 *  This class handle entries placed in hash tables built
 *  with class GenericHash.
 *
 *  GenericHashEntry has a lifecycle which is written into
 *  the enum HashEntryState and is implemented as a finite states
 *  machine. States are:
 *
 *  - hash_entry_state_active. This state is the default one which
 *  is set as soon as the GenericHashEntry is instantiated.
 *
 *  - hash_entry_state_idle. This state is set by method purgeIdle
 *  in class GenericHash and is used to explicitly mark the entry 
 *  as idle. NOTE that purgeIdle is always called inline, that is,
 *  in the thread which receives the incoming packets (or incoming
 *  flows). Once the entry has been marked as hash_entry_state_idle,
 *  the inline thread will not be able to fetch the entry again. Howevever,
 *  before deleting the entry, an extra transition is needed to make sure
 *  also a non-inline periodic thread has seen the entry.
 *
 *  - hash_entry_state_ready_to_be_purged. This state is set by
 *  non-inline periodic threads, generally from method updateStats,
 *  only after the inline thread has set state hash_entry_state_idle. This
 *  guarantees that also a non-inline thread has seen the entry before
 *  cleaning it up and freeing its memory. Once this state has been set,
 *  the inline-thread will perform the actual delete to free the memory.
 *
 *  The following diagram recaps the states transitions
 *
 *             ..new..
 *                |
 *                |
 *                v
 *      hash_entry_state_active
 *                |
 *                | [inline]
 *                v
 *      hash_entry_state_idle
 *                |
 *                | [non-inline]
 *                v
 *      hash_entry_state_ready_to_be_purged
 *                |
 *                |
 *                v
 *          ...deleted...
 *
 *  @ingroup MonitoringData
 *
 */
class GenericHashEntry {
 private:
  GenericHashEntry *hash_next; /**< Pointer of next hash entry.*/
  HashEntryState hash_entry_state;
  /**
   * @brief Set one of the states of the hash entry in its lifecycle.
   *
   * @param s A state of the enum HashEntryState
   */
  void set_state(HashEntryState s);
  
 protected:
  u_int32_t num_uses;  /* Don't use 16 bits as we might run out of space on large networks with MACs, VLANs etc. */
  time_t first_seen;   /**< Time of first seen. */
  time_t last_seen;    /**< Time of last seen. */
  NetworkInterface *iface; /**< Pointer of network interface. */
  virtual bool isIdle(u_int max_idleness);

 public:
  /**
    * @brief A Constructor
    * @details Creating a new GenericHashEntry.
    * 
    * @param _iface Network interface pointer for the new hash.
    * @return A new Instance of GenericHashEntry.
    */
  GenericHashEntry(NetworkInterface *_iface);
  /**
   * @brief A destructor.
   * @details Virtual method.
   * 
   * @return Delete the instance.
   */
  virtual ~GenericHashEntry();
  /**
   * @brief Get the first seen time.
   * @details Inline method.
   * 
   * @return Time of first seen.
   */
  inline time_t get_first_seen() const { return(first_seen); };
  /**
   * @brief Get the last seen time.
   * @details Inline method.
   * 
   * @return Time of last seen.
   */
  inline time_t get_last_seen()  const { return(last_seen); };
  /**
   * @brief Get the next hash entry.
   * @details Inline method.
   * 
   * @return Return the next hash entry.
   */
  inline GenericHashEntry* next()    { return(hash_next); };
  /**
   * @brief Set the next hash entry.
   * @details Inline method.
   * 
   * @param n Hash entry to set as next hash entry.
   */
  inline void set_next(GenericHashEntry *n) { hash_next = n;           };
  /**
   * @brief Set the hash entry state to idle. Must be called inline
   * with packets/flows processing.
   * 
   */
  virtual void set_hash_entry_state_idle() {
    set_state(hash_entry_state_idle);
  };
  /**
   * @brief Set the hash entry state to ready to be purged. Must be called NON-inline
   * with packets/flows processing.
   * @details Inline method.
   * 
   */
  inline void set_hash_entry_state_ready_to_be_purged() {
    set_state(hash_entry_state_ready_to_be_purged);
  };
  HashEntryState get_state();
  void updateSeen();
  void updateSeen(time_t _last_seen);
  bool equal(GenericHashEntry *b)         { return((this == b) ? true : false); };  
  inline NetworkInterface* getInterface() { return(iface);                      };
  virtual bool idle();
  virtual void housekeep(time_t t)     { return;                 };
  inline u_int get_duration()          { return((u_int)(1+last_seen-first_seen)); };
  virtual u_int32_t key()              { return(0);         };  
  virtual char* get_string_key(char *buf, u_int buf_len) const { buf[0] = '\0'; return(buf); };
  void incUses()                       { num_uses++;      }
  void decUses()                       { num_uses--;      }
  u_int16_t getUses()                  { return num_uses; }

  virtual void deserialize(json_object *obj);
  virtual void getJSONObject(json_object *obj, DetailsLevel details_level);
};

#endif /* _GENERIC_HASH_ENTRY_H_ */
