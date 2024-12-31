#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 username password"
    exit 1
fi

username=$1
password=$2

# calculate md5 hash of the password
hashed_password=$(echo -n "$password" | md5sum | cut -d' ' -f1)

# save hash to redis and update password changed flag
redis-cli set "ntopng.user.$username.password" "$hashed_password"
redis-cli set "ntopng.prefs.admin_password_changed" "1"

echo "Changed default password for user $username"