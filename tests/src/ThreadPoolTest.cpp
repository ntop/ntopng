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
#include "../include/ScopedThreadPool.h"
#include "../include/ThreadPoolTest.h"

namespace ntoptesting {

static void *doTestRun(void *ptr) {
  Utils::setThreadName("TrTestPoolWorker0");

  ((ThreadPool *)ptr)->run();
  return (NULL);
}

TEST_F(ThreadPoolTest, ShouldRunAPoolAndTerminateInALoop) {
  ThreadPool pool;
  void *res;
  pthread_t new_thread;
  for (int i = 0; i < 1000; i++) {
    int status = pthread_create(&new_thread, NULL, doTestRun, (void *)&pool);
    EXPECT_EQ(0, status);
    pool.shutdown();
    EXPECT_TRUE(pool.isTerminating());
    pthread_join(new_thread, &res);
  }
}

TEST_F(ThreadPoolTest, ShouldPoolScheduleACorrectActivity) {
  bool delayedActivity = false;
  u_int32_t periodicitySeconds = 0;
  u_int32_t maxDurationsSeconds = 0;
  bool alignToLocalTime = false;
  bool excludeViewedInterfaces = false;
  bool excludePcap = false;
  ScopedThreadPool scopedPool;
  const char *script = "/usr/bin/pwd";
  // check if it's started
  EXPECT_EQ(true, scopedPool.IsActive());
  
  ThreadedActivity *activity = new ThreadedActivity(script,
    delayedActivity,
    periodicitySeconds,
    maxDurationsSeconds,
    alignToLocalTime,
    excludeViewedInterfaces,
    excludePcap,
    scopedPool.GetPool());
  
  for (int i = 0; i < 10; i++) {
    activity->schedule(time(NULL));
  }
  scopedPool.WaitFor(5);

  delete activity;
}

TEST_F(ThreadPoolTest, ShouldWorkWhenAffinityIsNotCorrect) {
  char *affinity = static_cast<char *>(calloc(4, sizeof(char)));
  strcpy(affinity, "AS*");
  void *res;
  pthread_t new_thread;
  ThreadPool pool(affinity);
  int status = pthread_create(&new_thread, NULL, doTestRun, (void *)&pool);
  EXPECT_EQ(0, status);
  pool.shutdown();
  EXPECT_TRUE(pool.isTerminating());
  pthread_join(new_thread, &res);
  free(affinity);
}

} // namespace ntoptesting