#include "../include/PingTest.h"

namespace ntoptesting {
void PingTest::GetAllInterfacesName() {
  struct if_nameindex *if_nidxs, *intf;

  if_nidxs = if_nameindex();
  if (if_nidxs != NULL) {
    for (intf = if_nidxs; intf->if_index != 0 || intf->if_name != NULL;
         intf++) {
      std::string tmp(intf->if_name);
      interface_names_.push_back(tmp);
    }
    if_freenameindex(if_nidxs);
  }
}
} // namespace ntoptesting