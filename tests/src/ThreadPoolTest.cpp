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
#include "../include/ScopedThreadPool.h"
namespace ntoptesting {

static void *doTestRun(void *ptr) {
  Utils::setThreadName("TrTestPoolWorker0");

  ((ThreadPool *)ptr)->run();
  return (NULL);
}
void ThreadPoolTest::CreateScript(const std::string &path,
                                  const std::string &base, int i) const {
  std::ofstream out(path.c_str(), ios::trunc | ios::out);
  out << "#!/bin/bash"; 
  out << std::string("echo ");
  out << base;
  out << i;
  out << std::string(" >> ");
  out << path;
}
void ThreadPoolTest::PopulateScripts(std::vector<std::string> &scripts,
                                     int max) const {
  std::string base("/tmp/activity");
  for (int i = 0; i < max; i++) {
    std::ostringstream ostr;
    ostr << base;
    ostr << i;
    ostr << ".sh";
    CreateScript(ostr.str(), base, i);
  }
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
  
  bool delayed_activity = false;
  u_int32_t periodicity_seconds = 0;
  u_int32_t max_durations_seconds = 0;
  bool align_to_localtime = false;
  bool exclude_viewed_interfaces = false;
  bool exclude_pcap = false;
  // check if it's started
  EXPECT_EQ(true, scoped_pool_.IsActive());
  std::vector<ThreadedActivity*> activites;
  activites.resize(10);
  std::vector<std::string> script_names;
  
  PopulateScripts(script_names, MaxScripts);
  
  for (int i = 0; i < MaxScripts; i++) {
    ThreadedActivity *activity = new ThreadedActivity(
        script_names[i].c_str(), delayed_activity, periodicity_seconds,
        max_durations_seconds, align_to_localtime, exclude_viewed_interfaces,
        exclude_pcap, scoped_pool_.GetPool());
    activites.push_back(activity);q
  }
  for (int i = 0; i < MaxScripts; i++) {
    activites[i]->schedule(time(NULL));
  }
  scoped_pool_.WaitFor(5);
  for (int i = 0; i < MaxScripts; i++) {
    delete activites[i];
  }
  activites.clear();
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