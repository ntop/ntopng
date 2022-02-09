/*
 *
 * (C) 2013-22 - ntop.org
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
#include "../include/ThreadPoolTest.h"
namespace ntoptesting {
  static void* doTestRun(void* ptr)  {
  Utils::setThreadName("TrPoolWorker");

    ((ThreadPool*)ptr)->run();
  return(NULL);
}

TEST_F(ThreadPoolTest, ShouldRunAPoolAndTerminateInALoop) {
    ThreadPool pool;
    void *res;
    pthread_t new_thread;
    for (int i = 0; i < 1000; i++) {
      int status = pthread_create(&new_thread, NULL, doTestRun, (void*)&pool);
      EXPECT_EQ(0, status);
      pool.shutdown();
      EXPECT_TRUE(pool.isTerminating());
      pthread_join(new_thread, &res);
    }
}
TEST_F(ThreadPoolTest, ShouldWorkWhenAffinityIsNotCorrect) {
  char *affinity = static_cast<char *>(calloc(4, sizeof(char)));
  strcpy(affinity, "AS*");
  void *res ;
  pthread_t new_thread;
    
  ThreadPool pool(affinity);
  int status = pthread_create(&new_thread, NULL, doTestRun, (void*)&pool);
  EXPECT_EQ(0, status);
  pool.shutdown();
  EXPECT_TRUE(pool.isTerminating());
  pthread_join(new_thread, &res);
  free(affinity);
}


} // namespace ntoptesting