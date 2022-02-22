#include "ScopedThreadPool.h"

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
bool ScopedThreadPool::IsActive() const { return is_active_; }
void ScopedThreadPool::Shutdown() { pool_->shutdown(); }
void ScopedThreadPool::Run() {
  int status = pthread_create(&run_thread_, NULL, doTestRun, (void *)&pool_);
  is_active_ = (status == 0);
}
ThreadPool *ScopedThreadPool::GetPool() const { return pool_; }
void ScopedThreadPool::WaitFor(int seconds) { sleep(seconds); }
ScopedThreadPool::~ScopedThreadPool() {
  void *res;
  delete pool_;
  pthread_join(run_thread_, &res);
}
} // namespace ntoptesting