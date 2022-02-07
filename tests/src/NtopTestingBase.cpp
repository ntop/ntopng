#include "../include/NtopTestingBase.h"

NtopTestingBase::NtopTestingBase() {
        const char* appName = "ntopng";
        const char* dataDirectory = "/tmp";
        ntop_ = std::make_unique<Ntop>(appName);
        pref_ = std::make_unique<Prefs>(ntop_.get()); 
        // ntop exists if doesn't find the data dir.
        // TODO: fix ntop data directory to a const char*
        pref_->set_data_dir(const_cast<char*>(dataDirectory));
        ntop_->registerPrefs(pref_.get(), false);
}
Prefs* NtopTestingBase::GetPreferences() const {
    return pref_.get();
}