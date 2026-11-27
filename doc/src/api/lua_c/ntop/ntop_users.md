---
title: "Users API"
description: "The Users API provides utility functions to manage ntopng system users."
outline: [2, 3]
lastUpdated: 2018-06-15T15:52:05+02:00
---
# Users API {#users-api}

The Users API provides utility functions to manage ntopng system users.

### `ntop.getUsers()` {#ntop-getusers}

Get ntopng users information.

**Returns**: ntopng users information.

### `ntop.addUser(string username, string full_name, string password, string host_role, string allowed_networks, string allowed_interface, string host_pool_id=nil, string language=nil)` {#ntop-adduser}

Add a new ntopng user.

**Parameters**

- `username`: the user name to add.
- `full_name`: a descriptive user name.
- `password`: the user password.
- `host_role`: the user group, should be "unprivileged" or "administrator".
- `allowed_networks`: comma separated list of allowed networks for the user. Use "0.0.0.0/0,::/0" for all networks.
- `allowed_interface`: the only network interface name that this user case see.
- `host_pool_id`: this can be used to create a Captive Portal user.
- `language`: user language code.

**Returns**: true on success, false otherwise.

### `ntop.deleteUser(string username)` {#ntop-deleteuser}

Delete a ntopng user.

**Parameters**

- `username`: the user to delete.

**Returns**: true on success, false otherwise.

### `ntop.getAllowedNetworks()` {#ntop-getallowednetworks}

Get a string representing the networks the current ntopng user is allowed to see.

**Returns**: allowed networks string.

### `ntop.resetUserPassword(string who, string username, string old_password, string new_password)` {#ntop-resetuserpassword}

Reset a ntopng user password.

**Parameters**

- `who`: the ntopng user who is requesting the reset.
- `username`: the user for the password reset.
- `old_password`: the old user password.
- `new_password`: the new user password.

**Returns**: true on success, false otherwise.

::: info
the administrator can reset the password regardless of the old_password value.
:::

### `ntop.changeUserRole(string username, string user_role)` {#ntop-changeuserrole}

Change the group of a ntopng user.

**Parameters**

- `username`: the target user.
- `user_role`: the new group, should be "unprivileged" or "administrator".

**Returns**: true on success, false otherwise.

### `ntop.changeAllowedNets(string username, string allowed_networks)` {#ntop-changeallowednets}

Change the allowed networks of a ntopng user.

**Parameters**

- `username`: the target user.
- `allowed_networks`: the new allowed networks.

**Returns**: true on success, false otherwise.

### `ntop.changeAllowedIfname(string username, string allowed_ifname)` {#ntop-changeallowedifname}

Change the allowed interface name of a ntopng user.

**Parameters**

- `username`: the target user.
- `allowed_ifname`: the new allowed interface name for the user.

**Returns**: true on success, false otherwise.

### `ntop.changeUserLanguage(string username, string language)` {#ntop-changeuserlanguage}

Change the GUI language of a ntopng user.

**Parameters**

- `username`: the target user.
- `language`: the new language code.

**Returns**: true on success, false otherwise.

### `ntop.changeUserHostPool(string username, int host_pool_id)` {#ntop-changeuserhostpool}

Change the host pool a ntopng user.

**Parameters**

- `username`: the target user.
- `host_pool_id`: the new host pool ID.

**Returns**: true on success, false otherwise.

### `ntop.isAllowedInterface(int ifid)` {#ntop-isallowedinterface}

Check if the provided interface is allowed for the current user

**Parameters**

- `ifid`: the interface ID to check

**Returns**: true if the interface is allowed, false otherwise.

### `ntop.isAllowedNetwork(string network)` {#ntop-isallowednetwork}

Check if the provided network is allowed for the current user

**Parameters**

- `network`: the network CIDR to check

**Returns**: true if the network is allowed, false otherwise.

### `ntop.getNologinUser()` {#ntop-getnologinuser}

Get the user name for the "nologin" user.

**Returns**: the nologin user name

### `ntop.isAdministrator()` {#ntop-isadministrator}

Check if the current user is an administrator.

**Returns**: true if the user is administrator, false otherwise.

### `ntop.isLoginDisabled()` {#ntop-islogindisabled}

Check if login to the ntopng GUI is disabled.

**Returns**: true if the login is disabled, false otherwise.

### `ntop.isLoginBlacklisted()` {#ntop-isloginblacklisted}

Check if the login for the seccion is blacklisted.

**Returns**: true if the login is blacklisted, false otherwise.

::: info
An IP address can get blacklisted when too many unsuccesful login attempts are performed.
:::
