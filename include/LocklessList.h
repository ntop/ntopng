/*
 *
 * (C) 2014-18 - ntop.org
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

#ifndef _LOCKLESS_LIST_H_
#define _LOCKLESS_LIST_H_

#include "ntop_includes.h"

/* 
 * Wait-Free Single-Producer Single-Consumer list
 * Lock is used in the Multi-Producer case only
 */

typedef struct lockless_list_item {
  struct lockless_list_item *next;
  void *value;
} lockless_list_item_t;

class LocklessList {
 private:

  Mutex *m;
  struct {
    lockless_list_item_t *head; /* producer */
    u_char __cacheline_padding_0[64-sizeof(lockless_list_item_t *)];
    lockless_list_item_t *tail; /* consumer */
    u_char __cacheline_padding_1[64-sizeof(lockless_list_item_t *)];
  } l;


 public:

  LocklessList(bool multi_producer) {
    lockless_list_item_t *i = (lockless_list_item_t *) calloc(1, sizeof(lockless_list_item_t));
    if (i == NULL) throw 1;

    i->next = NULL;
    l.tail = l.head = i;

    if (multi_producer)
      m = new Mutex();
    else
      m = NULL;
  }
  
  ~LocklessList() {
    lockless_list_item_t *i;

    /* Note: all the items should be removed from the list before deleting it,
     * as the list itself is generic and it cannot delete i->'value' */
    while (dequeue(&i))
      free(i);

    free(l.tail);

    if(m) delete m; 
  }

  inline void enqueue(lockless_list_item_t *i) {
    if(m) m->lock(__FILE__, __LINE__);

    i->next = NULL;

    //gcc_mb();

    l.head->next = i;
    l.head = i;

    if(m) m->unlock(__FILE__, __LINE__);
  }

  inline int dequeue(lockless_list_item_t **i) {
    if (l.tail->next != NULL) {

      //gcc_mb();

      l.tail->value = l.tail->next->value;
      l.tail->next->value = NULL; /* useless - safety */
      (*i) = l.tail;
      l.tail = l.tail->next;
      (*i)->next = NULL; /* useless - safety */
      return 1;
    }

    return 0;
  }

  inline int empty() {
    return l.tail->next == NULL;
  }

  /* The functions below are not lock less - to be used only in case of single thread */

  inline lockless_list_item_t *getFirst() {
    return l.tail;
  }

  inline lockless_list_item_t *getNext(lockless_list_item_t *i) {
    return i->next;
  }

};

#endif /* _LOCKLESS_LIST_H_ */

