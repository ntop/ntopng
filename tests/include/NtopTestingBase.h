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
    void InitializePreferences();
    std::unique_ptr<Ntop> ntop_;
    Prefs* pref_;
};
#endif
