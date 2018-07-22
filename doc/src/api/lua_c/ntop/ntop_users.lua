--! @brief Get ntopng users information.
--! @return ntopng users information.
function ntop.getUsers()

--! @brief Add a new ntopng user.
--! @param username the user name to add.
--! @param full_name a descriptive user name.
--! @param password the user password.
--! @param host_role the user group, should be "unprivileged" or "administrator".
--! @param allowed_networks comma separated list of allowed networks for the user. Use "0.0.0.0/0,::/0" for all networks.
--! @param host_pool_id this can be used to create a Captive Portal user.
--! @param language user language code.
--! @return true on success, false otherwise.
function ntop.addUser(string username, string full_name, string password, string host_role, string allowed_networks, string allowed_interface, string host_pool_id=nil, string language=nil)

--! @brief Delete a ntopng user.
--! @param username the user to delete.
--! @return true on success, false otherwise.
function ntop.deleteUser(string username)

--! @brief Get the group of the current ntopng user.
--! @return the user group.
function ntop.getUserGroup()

--! @brief Get a string representing the networks the current ntopng user is allowed to see.
--! @return allowed networks string.
function ntop.getAllowedNetworks()

--! @brief Reset a ntopng user password.
--! @param who the ntopng user who is requesting the reset.
--! @param username the user for the password reset.
--! @param old_password the old user password.
--! @param new_password the new user password.
--! @note the administrator can reset the password regardless of the old_password value.
--! @return true on success, false otherwise.
function ntop.resetUserPassword(string who, string username, string old_password, string new_password)

--! @brief Change the group of a ntopng user.
--! @param username the target user.
--! @param user_role the new group, should be "unprivileged" or "administrator".
--! @return true on success, false otherwise.
function ntop.changeUserRole(string username, string user_role)

--! @brief Change the allowed networks of a ntopng user.
--! @param username the target user.
--! @param allowed_networks the new allowed networks.
--! @return true on success, false otherwise.
function ntop.changeAllowedNets(string username, string allowed_networks)

--! @brief Change the allowed interface name of a ntopng user.
--! @param username the target user.
--! @param allowed_ifname the new allowed interface name for the user.
--! @return true on success, false otherwise.
function ntop.changeAllowedIfname(string username, string allowed_ifname)

--! @brief Change the gui language of a ntopng user.
--! @param username the target user.
--! @param language the new language code.
--! @return true on success, false otherwise.
function ntop.changeUserLanguage(string username, string language)
