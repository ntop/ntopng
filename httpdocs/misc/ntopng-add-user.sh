#!/bin/bash

###!/usr/bin/env BASH

REDIS_HOSTNAME="127.0.0.1"
REDIS_PORT="6379"
REDIS_DB="0"
REDIS_PREFIX="ntopng.user."  #keep this in synch with ntop_defines.h

NTOPNG_ALLOWED_NETWORKS="0.0.0.0/0,::/0"
NTOPNG_ALLOWED_IFNAME=""
NTOPNG_USER_ROLE="standard"
NTOPNG_USERNAME=""
NTOPNG_FULLNAME=""
NTOPNG_PASSWORD=""
NTOPNG_PASSWORD_MD5=""

function send_redis_cmd {
    redis-cli -h $REDIS_HOSTNAME -p $REDIS_PORT -n $REDIS_DB $@
}

function is_ipv4 {
    local ip=$1
    local ret=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
	OIFS=$IFS
	IFS='.'
	ip=($ip)
	IFS=$OIFS
	[[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
		 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
	ret=$?
    fi

    return $ret
}

function is_ipv6 {
    local ip=$1
    local ret=1
    
    if [[ $ip =~ ^.*:.*$ ]]; then
	ret=0 #TODO: make ipv6 check less naive
    fi
    
    return $ret
}
function validate_allowed_networks {
    local ret=0
    # validate network masks for the allowed networks
    local allowed_nets=${NTOPNG_ALLOWED_NETWORKS//,/$'\n'}
    for network in $allowed_nets
    do
	local netmask=${network##*/}
	local ipaddr=${network%/*}
	if is_ipv4 $ipaddr && [ $netmask -le "32" ]
	then
	    continue
	elif is_ipv6 $ipaddr && [ $netmask -le "128" ]
	then
	    continue
	else
	    echo "unable to validate allowed network $network"
	    ret=1
	    break
	fi
    done
    return $ret
}

function validate_user_role {
    local role="$NTOPNG_USER_ROLE"
    if [[ $role == "standard" || $role == "administrator" ]]
    then
	return 0
    fi
    echo "unknown role specified: use either standard or administrator"
    return 1
}

function validate_allowed_ifname {
    if [[ $NTOPNG_ALLOWED_IFNAME == "" ]]
    then
	# ok, don't want to specify an interface
	return 0
    fi
    local ifname_exists=$(send_redis_cmd hget ntopng.prefs.iface_id $NTOPNG_ALLOWED_IFNAME)
    if [[ $ifname_exists == "" ]]
    then
	echo "allowed interface specified does not exists"
	return 1
    fi
    return 0
}

function validate_username {
    if [[ $NTOPNG_USERNAME == "" ]]
    then
	# don't allow empty usernames
	return 1
    fi
    local username_exists=$(send_redis_cmd "get ${REDIS_PREFIX}${NTOPNG_USERNAME}.group")
    if [[ $username_exists != "" ]]
    then
	echo "specified username already exists"
	return 1
    fi
    return 0
}

function password_md5 {
    #make sure the md5 utility works as expected
    local admin_md5=`echo -n admin | md5sum | cut -c 1-32`
    if [[ $admin_md5 != "21232f297a57a5a743894a0e4a801fc3" ]]
    then
	echo "md5sum not working as expected"
	return 1
    fi
    NTOPNG_PASSWORD_MD5=`echo -n $NTOPNG_PASSWORD | md5sum | cut -c 1-32`
    return 0
}

function print_usage {
    echo -e "\nCommand line utility to add ntopng users\n"
    echo -e "Usage: $0 [-h redis_hostname] [-p redis_port] [-n redis_db] [-t allowed_networks] [-i allowed_ifname] [-r role] username password fullname"
}

while getopts "h:p:n:t:i:r:" opt; do
    case "$opt" in
	h)
	    REDIS_HOSTNAME="$OPTARG"
	    ;;
	p)
	    REDIS_PORT="$OPTARG"
	    ;;
	n)
	    REDIS_DB="$OPTARG"
	    ;;
	t)
	    NTOPNG_ALLOWED_NETWORKS="$OPTARG"
	    ;;
	i)
	    NTOPNG_ALLOWED_IFNAME="$OPTARG"
	    ;;
	r)
	    NTOPNG_USER_ROLE="$OPTARG"
	    ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

if [ $# != 3 ]  # username password fullname
then
    # TODO: handle fullname with spaces
    print_usage
    exit 1
fi
NTOPNG_USERNAME="$1"
shift
NTOPNG_PASSWORD="$1"
shift
NTOPNG_FULLNAME="$1"
shift

echo "Using Redis: $REDIS_HOSTNAME:$REDIS_PORT@$REDIS_DB"
echo "username: $NTOPNG_USERNAME password: $NTOPNG_PASSWORD full name: $NTOPNG_FULLNAME"
echo "role: $NTOPNG_USER_ROLE"
echo "allowed networks: $NTOPNG_ALLOWED_NETWORKS"
echo "allowed ifname: $NTOPNG_ALLOWED_IFNAME"


if validate_allowed_networks && validate_allowed_ifname \
	&& validate_user_role && validate_username && password_md5
then
    send_redis_cmd "SET ${REDIS_PREFIX}${NTOPNG_USERNAME}.allowed_nets $NTOPNG_ALLOWED_NETWORKS" > /dev/null
    if [[ $NTOPNG_ALLOWED_IFNAME != "" ]]
    then
	send_redis_cmd "SET ${REDIS_PREFIX}${NTOPNG_USERNAME}.allowed_ifname $NTOPNG_ALLOWED_IFNAME" > /dev/null
	# forcefully set the user as non-privileged
	NTOPNG_USER_ROLE="standard"
    fi
    send_redis_cmd "SET ${REDIS_PREFIX}${NTOPNG_USERNAME}.group $NTOPNG_USER_ROLE" > /dev/null
    send_redis_cmd "SET ${REDIS_PREFIX}${NTOPNG_USERNAME}.full_name $NTOPNG_FULLNAME" > /dev/null
    send_redis_cmd "SET ${REDIS_PREFIX}${NTOPNG_USERNAME}.password $NTOPNG_PASSWORD_MD5" > /dev/null
    echo "User created successfully"
    exit 0
else
    exit 1
fi



