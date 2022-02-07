#ifndef _TEST_NTOP_TESTING_BASE_H_
#define _TEST_NTOP_TESTING_BASE_H_
#include "ntop_includes.h"
// rule of 0
class NtopTestingBase {
    public:
    NtopTestingBase();
    Prefs* GetPreferences() const;
    private:
    void InitializePreferences();
    Ntop* ntop_;
    Prefs* pref_;
};
#endif
