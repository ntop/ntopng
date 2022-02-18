#include "../include/ScopedThreadPool.h"

namespace ntoptesting {

static void *doTestRun(void *ptr) {
  Utils::setThreadName("TrTestPoolWorker1");

  ((ThreadPool *)ptr)->run();
  return (NULL);
}

ScopedThreadPool::ScopedThreadPool() {
  pool_ = new ThreadPool();
  Run();
}
bool ScopedThreadPool::IsActive() const { return isActive_; }
void ScopedThreadPool::Shutdown() { pool_->shutdown(); }
void ScopedThreadPool::Run() {
  int status = pthread_create(&runThread_, NULL, doTestRun, (void *)&pool_);
  isActive_ = (status == 0);
}
ThreadPool *ScopedThreadPool::GetPool() const { return pool_; }
void ScopedThreadPool::WaitFor(int seconds) { sleep(seconds); }
ScopedThreadPool::~ScopedThreadPool() {
  void *res;
  delete pool_;
  pthread_join(runThread_, &res);
}
} // namespace ntoptesting