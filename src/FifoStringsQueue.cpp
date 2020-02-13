/*
 *
 * (C) 2014-20 - ntop.org
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

FifoStringsQueue::~FifoStringsQueue() {
  char *tmp;
  
  while ((tmp = dequeue()) != NULL)
    free(tmp);
}

/* ******************************************* */

/* NOTE: strdup is performed internally. */
bool FifoStringsQueue::enqueue(const char *item) {
  char *item_copy;
  bool rv = false;

  if (item == NULL)
    return rv;

  item_copy = strdup(item);
  if (item_copy != NULL) {

    rv = FifoQueue::enqueue((void*) item_copy);

    if (rv == false)
      free(item_copy);
  }

  return(rv);
}

/* ******************************************* */

/* NOTE: the caller should free the returned string */
char* FifoStringsQueue::dequeue() {
  return (char*) FifoQueue::dequeue();
}

/* make test_fifo_queue */
#ifdef TEST_FIFO_QUEUE

/* ******************************************* */

void run_test_fifo_order() {
  FifoStringsQueue q(5);
  const char *item1 = "ABCDEF";
  const char *item2 = "12345";

  assert(q.enqueue(item1) == true);
  assert(q.enqueue(item2) == true);
  assert(q.getLength() == 2);
  char *first = q.dequeue();
  char *last = q.dequeue();
  assert(!strcmp(first, item1));
  assert(!strcmp(last, item2));
  free(first);
  free(last);

  assert(q.dequeue() == NULL);
  assert(q.getLength() == 0);
}

/* ******************************************* */

void run_test_queue_full() {
  FifoStringsQueue q(1);
  const char *item1 = "ABCDEF";

  q.enqueue(item1);
  q.enqueue(item1);
  q.enqueue(item1);

  /* Check out valgrind --leak-check=full ./test_fifo_queue */
}

/* ******************************************* */

void run_test_leaks() {
  FifoStringsQueue q(1);
  const char *item1 = "ABCDEF";
  const char *item2 = "12345";

  assert(q.enqueue(NULL) == false);
  assert(q.enqueue(item1) == true);
  assert(q.enqueue(item2) == false);
  assert(q.getLength() == 1);
  char *item = q.dequeue();
  assert(!strcmp(item, item1));
  free(item);
}

/* ******************************************* */

int main() {
  ntop = new Ntop((char*)"test");

  run_test_fifo_order();
  run_test_queue_full();
  run_test_leaks();

  delete ntop;
}

#endif /* TEST_FIFO_QUEUE */
