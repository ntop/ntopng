#ifndef _TEST_NTOP_TESTING_BASE_H_
#define _TEST_NTOP_TESTING_BASE_H_
#include "ntop_includes.h"
#include <memory>
// rule of 0
class NtopTestingBase {
    public:
    NtopTestingBase();
    Prefs* GetPreferences() const;
    private:
    std::unique_ptr<Ntop> ntop_;
    std::unique_ptr<Prefs> pref_;
};
#endif
