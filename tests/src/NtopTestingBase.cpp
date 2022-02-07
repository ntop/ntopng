#include "../include/NtopTestingBase.h"

NtopTestingBase::NtopTestingBase() {
        const char* appName = "ntopng";
        ntop_ = std::unique_ptr<Ntop>(new Ntop(appName)); 
        pref_ = new Prefs(ntop_.get()); 
        InitializePreferences();
        ntop_->registerPrefs(pref_, false);
}

Prefs* NtopTestingBase::GetPreferences() const {
    return pref_;
}
void NtopTestingBase::InitializePreferences() {
        const char* appDir = "/tmp";
        char* dataDirectory = static_cast<char*>(malloc(strlen(appDir)+1));
        char* scriptDirectory = static_cast<char*>(malloc(strlen(appDir)+1));
        strcpy(dataDirectory, appDir);
        dataDirectory[sizeof(dataDirectory)-1]='\0';
        strcpy(scriptDirectory, appDir);
        scriptDirectory[sizeof(scriptDirectory)-1]='\0';
        pref_->set_data_dir(dataDirectory);
        pref_->set_callback_dir(scriptDirectory);
}