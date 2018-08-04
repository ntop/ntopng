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

#ifndef _GENERIC_HASH_ENTRY_H_
#define _GENERIC_HASH_ENTRY_H_

#include "ntop_includes.h"

/** @class GenericHashEntry
 *  @brief Base hash entry class.
 *  @details Defined the base hash entry class for ntopng.
 *
 *  @ingroup MonitoringData
 *
 */
class GenericHashEntry {
 private:
  GenericHashEntry *hash_next; /**< Pointer of next hash entry.*/

 protected:
  u_int32_t num_uses;  /* Don't use 16 bits as we might run out of space on large networks with MACs, VLANs etc. */
  bool will_be_purged; /**< Mark this host as candidate for purging. */
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
  inline time_t get_first_seen()     { return(first_seen); };
  /**
   * @brief Get the last seen time.
   * @details Inline method.
   * 
   * @return Time of last seen.
   */
  inline time_t get_last_seen()       { return(last_seen); };
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
  inline void set_next(GenericHashEntry *n) { hash_next = n;     };
  void updateSeen();
  void updateSeen(time_t _last_seen);
  bool equal(GenericHashEntry *b)         { return((this == b) ? true : false); };  
  inline NetworkInterface* getInterface() { return(iface);                      };
  virtual bool idle();
  virtual void set_to_purge()          { will_be_purged = true;  };
  virtual void housekeep()             { return;                 };
  inline bool is_ready_to_be_purged()  { return(will_be_purged); };
  inline u_int get_duration()          { return((u_int)(1+last_seen-first_seen)); };
  virtual u_int32_t key()              { return(0);         };  
  virtual char* get_string_key(char *buf, u_int buf_len) { buf[0] = '\0'; return(buf); };
  void incUses()                       { num_uses++;      }
  void decUses()                       { num_uses--;      }
  u_int16_t getUses()                  { return num_uses; }
};

#endif /* _GENERIC_HASH_ENTRY_H_ */
