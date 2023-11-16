#!/bin/bash
# for debugging enable the next 2 lines (but we can't do step by step debugging inside the while loops or it breaks the loops
DEBUG=
if [[ "$DEBUG" != "" ]]; then 
	set -x
	trap 'read -p "run: $BASH_COMMAND"' DEBUG
fi
# Release information: 
# This script is designed for Ubiquiti EdgeRouters running nprobe software for ntopng.  It has been tested on ER-X routers and assumed
# to work on all other edge routers.  It uses only commands that are available natively in the edge router.  Works with any edge router 
# that is serving dhcp - it can use normal DHCP or DNSMASQ.  Tested on ER-X. Written by Stephen Wilkey 2021. Released to Public domain.
# ntopnghosts.sh v1 - initial release
# ntopnghosts.sh v1.2 - corrected a message formatting error
# ntopnghosts.sh v1.3 - added optional central management of script updates and hostnamesubstitute files
# ntopnghosts.sh v1.4 - separated constant definitions into /etc/nprobe/ntopnghosts-config.sh
# ntopnghosts.sh v1.5 - improved error handling
# ntopnghosts.sh v1.6 - revised code to improve to ntopng team standards:
# - request ssl upgrades for any curl connection where it is available
# - use a more reliable way to determine if a file already on the router is the same as another than using filesize
# - relocated script working files from /tmp/ to /run/ntopnghosts/ so that unprivileged processes that could otherwise write to tmp 
#   and inject code cannot do it to our files as they are in a more restricted location
# - corrected error with hard coded ntopngserver name
#
# It updates host information in ntopng whenever a new host entry appears in the lease table. This means that whenever there is data 
# present in ntopng for a host there should also be a valid hostname if it is available in DHCP.  Old hosts will stay listed until 
# they send new data again - we don't remove host records.  Note that DHCP doesn't always get a valid hostname - in those cases we'll
# upload the MAC address and the device name will just be unknown.  The format of device names in NTOPNG will be hostname(MACaddress).
#
# This script can be run from cron at regular intervals eg. 1 minute and it will look for changes in the DHCP lease table.  It will 
# then get the IP address, MAC address and hostname details from the DHCP lease table and will first check if we have identified any 
# substitute information for them in /etc/nprobe/hostnamesubstitute and then will submit the modified (or unmodified) hostname to 
# ntopng using the api.  /etc/nprobe/hostnamesubstitutes should not include spaces in the substitute name - please use underscore or 
# something else to ensure that the hostname has no spaces in it.  So each line should contain the hostname supplied by DHCP followed 
# by a space, then the mac address followed by a space and then the hostname we want to replace it with.
#
# An example crontab entry for this that we use is:
#     # m h  dom mon dow   command
#     * * * * * /etc/nprobe/ntopnghosts.sh >/dev/null
#
# If you want to run ntopnghosts.sh interactively you must do it with sudo as the folders on the ER-X are unusually locked down and sudo 
# is needed to overcome that.
#
# it is important that you set the local SUBNET below as any lines in the host file that don't belong to that subnet will be ignored
# You can set the subnet to broader than your subnet if it makes using the script easier on multiple routers.  For example, in my
# organistation, all our subnets start with 192.168, so we can set our subnet to this instead of 192.168.53 for example and that way
# we only have to modify this script once before installing it on all our routers.
# If SUBNETDESCRIPTION is set then that will be included in any notifications about the device, but it is not relevant if TELEGRAMENABLE=NO
#
# obviously also update the NTOPNG user and password variables with valid information for your NTOPNG server
#
# If the variable TELEGRAMENABLE=YES then this enables the script to send telegram messages when new devices appear on the local network.  In our 
# organisation this is useful as we add computers into a higher speed group on our network if they are ones that are authorised for that, otherwise
# they remain at a slow speed.  Our network retains knowledge of that configuration for 6 months after a device is last seen by the network, so 
# NOTIFYDAYS should be set to the number of days that you need to be wait before being notified again about the same computer after it has been last
# seen.  The script will keep track of the most recent time the computer has been seen and if that is longer ago than NOTIFYDAYS before today's date 
# when we see that computer again then we will send a notification.  The variable NOTIFYMESSAGE should include any message that you want to appear 
# in the notification following this message "$HOSTNAME has been seen with IP $IP today for the first time."
#
# WARNING: Using TELEGRAMENABLE=YES will cause a file to be updated daily on the permanent memory of the router, while ideally we would do it each time
# a new DHCP lease is issued to a device, this could lead to high wear on the memory and premature failure of the router since the memory cannot be
# replaced in models such as the ER-X.  We believe writing once per day is a reasonable compromise that will not significantly impact the life of the
# long term storage on the device however, if you are concerned about this you should not use this functionality.
# If you use TELEGRAMENABLE=YES, you must also enter a valid TELEGRAM_API_KEY and TELEGRAM_CHAT_ID.
#
# The first time you run the script with TELEGRAMENABLE=YES you might expect us to process all the computers in the DHCP lease table into the hostnameregister
# however, to keep running time short we don't.  We will then add devices as they get new DHCP leases following that time.  If you want to force
# hostnameregister to be populated you should use sudo rm /run/ntopnghosts/ntopng_olddhcp followed by sudo touch /run/ntopnghosts/ntopng_olddhcp and then run the script (manually is
# recommended) then it will fully populate the hostnameregister with all known devices.
#
# NOTE: if you change your router from DNSMASQ to normal DHCP or vice-versa and do not reboot afterward, the built in command show dhcp leases will hang if you run
# it.  As this is key to the operation of this script it means that this script will also hang.  Therefore it is wise to install this on a router once you have DHCP
# fully setup or reboot the router if you make a change to this.
#
# UPDATEURL and NAMESUBSTITUTEURL variables control whether the script and/or the hostnamesubstitute file are centrally managed or not.
# If either of these are blank then the corresponding file will be local only, but if they are a valid URL then the file will be
# centrally managed.  It is recommended that you use an https server (not http) for storing these files on.
# 
# On first run the script will create a file /etc/nprobe/ntopnghosts-config.sh which contains the default config.  In subsequent runs that config is included at
# run time.  You can modify that config file with the appropriate settings for each router and it will be retained between versions of the script - so even if the
# script gets updated the config will be retained.

#initialise constants
if [[ ! -f "/etc/nprobe/ntopnghosts-config.sh" ]]; then
	echo "SUBNET=192.168." > /etc/nprobe/ntopnghosts-config.sh
	echo "SUBNETDESCRIPTION=" >> /etc/nprobe/ntopnghosts-config.sh
	echo "NTOPNGUSER=ENTER_A_VALID_NTOPNG_USER_ACCOUNT_HERE" >> /etc/nprobe/ntopnghosts-config.sh
	echo "NTOPNGPASS=ENTER_VALID_NTOPNG_PASSWORD_HERE" >> /etc/nprobe/ntopnghosts-config.sh
	echo "TELEGRAMENABLE=NO" >> /etc/nprobe/ntopnghosts-config.sh
	echo "NOTIFYDAYS=180" >> /etc/nprobe/ntopnghosts-config.sh
	echo 'NOTIFYMESSAGE="Please check the unifi user groups are correct for this device"' >> /etc/nprobe/ntopnghosts-config.sh
	echo "TELEGRAM_API_KEY=ENTER_A_VALID_TELEGRAM_API_KEY_HERE(BOTFATHER_CAN_HELP_YOU)" >> /etc/nprobe/ntopnghosts-config.sh
	echo "TELEGRAM_CHAT_ID=ENTER_A_VALID_CHAT_ID_HERE" >> /etc/nprobe/ntopnghosts-config.sh
	echo 'UPDATEURL=' >> /etc/nprobe/ntopnghosts-config.sh
	echo 'NAMESUBSTITUTEURL=' >> /etc/nprobe/ntopnghosts-config.sh
	if [[ "`grep NTOPNGSERVER /etc/nprobe/ntopnghosts-config.sh`" == "" ]]; then
		echo 'NTOPNGSERVER=ENTER_VALID_FQDN_NTOPNG_SERVER_NAME_HERE' >> /etc/nprobe/ntopnghosts-config.sh
	fi
fi
# include constants
source /etc/nprobe/ntopnghosts-config.sh

#functions
date2stamp () { # source: https://www.unix.com/tips-and-tutorials/31944-simple-date-time-calulation-bash.html
    if [[ "$1" == "now" ]]; then
	    date --utc +%s
	else
		date --utc --date "$1" +%s
	fi
}

dateDiff (){ # source: https://www.unix.com/tips-and-tutorials/31944-simple-date-time-calulation-bash.html
    case $1 in
        -s)   sec=1;      shift;;
        -m)   sec=60;     shift;;
        -h)   sec=3600;   shift;;
        -d)   sec=86400;  shift;;
        *)    sec=86400;;
    esac
    dte1=$(date2stamp "$1")
    dte2=$(date2stamp "$2")
    diffSec=$((dte2-dte1))
    if ((diffSec < 0)); then abs=-1; else abs=1; fi
    echo $((diffSec/sec*abs))
}

sendmessage (){
	RESULT=`curl --ssl -s "https://api.telegram.org/bot$TELEGRAM_API_KEY/sendMessage?chat_id=$TELEGRAM_CHAT_ID&text=$MESSAGE"`
	#echo "RESULT=$RESULT"
	OK_STR=`echo $RESULT |jq -r '."ok"'`
	#echo "OK_STR=$OK_STR"
	if [[ "$OK_STR" != "true" ]]; then
		# Failed to update:  We're going to wait 30 seconds and then retry and then we'll give up.  This means that if we fail again that there 
		# will be no notification about this host
		sleep 31s
		RESULT=`curl --ssl -s "https://api.telegram.org/bot$TELEGRAM_API_KEY/sendMessage?chat_id=$TELEGRAM_CHAT_ID&text=$MESSAGE"`
		OK_STR=`echo $RESULT |jq -r '."ok"'`
	fi
	if [[ "$OK_STR" == "true" ]]; then
		OK_STR="OK"
	fi
	echo "Sending telegram message about $TELEGRAMHOSTNAME result=$OK_STR"
}

#initialise variables - this section shouldn't be modified
# HOSTLOG is used for temporarily storing the records of hosts we see in case we need to write them to the hostnameregister if TELEGRAMENABLE is set to YES
HOSTLOG=
CRLF="\n"
HOSTNAME=
MAC=

#check we're not already running
if [[ "`ps -ef |grep ntopnghosts.sh | wc -l`" -gt "4" ]]; then
    # if our process is present already we don't want to run again so we'll stop (more than 4 processes with our name means we are already running)
	exit
fi
# make a working directory in RAM (tmpfs)
mkdir -p /run/ntopnghosts
# we need to check if the hostnamesubstitute file needs to be updated
if [[ "$NAMESUBSTITUTEURL" != "" ]]; then
	# we get the remote file size (without downloading the file - we rely on the server being able to tell us the size - note some servers might not, so use another server)
	NAMESUBSTITUTESIZE=`curl --ssl -sI $NAMESUBSTITUTEURL --location --silent -H 'Accept-Encoding: gzip,deflate' |grep -i content-length |cut -d ' ' -f2`
	NAMESUBSTITUTESIZE=(${NAMESUBSTITUTESIZE:0:-1})
	#curl --ssl -sI $NAMESUBSTITUTEURL --location --silent --write-out 'size_download=%{size_download}\n'
	if [[ -f "/run/ntopnghosts/hostnamesubstitute" ]]; then
		FILESIZE=`wc -c /run/ntopnghosts/hostnamesubstitute |cut -d ' ' -f1`
	else
		FILESIZE=0
		if [[ -f "/etc/nprobe/hostnamesubstitute" ]]; then
			cp /etc/nprobe/hostnamesubstitute /run/ntopnghosts/hostnamesubstitute
		fi
	fi
	#echo "Centrally managed Namesubstitute size: $NAMESUBSTITUTESIZE"
	#echo "Local Namesubstitute size: $FILESIZE"
	if [[ "$NAMESUBSTITUTESIZE" != "0" ]]; then	
		# is our local file the same size as the remote one?  Note that we could use filesize or date stamp for this, filesize will be more accurate and not all servers will share the date stamp with us
		if [[ "$FILESIZE" != "$NAMESUBSTITUTESIZE" ]]; then
			echo "Downloading updated name substitute file"
			curl --ssl -s $NAMESUBSTITUTEURL -o "/run/ntopnghosts/hostnamesubstitute_new"
			FILESIZE=`wc -c /run/ntopnghosts/hostnamesubstitute_new|cut -d ' ' -f1`
			# did we download a file that was the same size as we were expecting?  If not, the download was interrupted
			if [[ "$FILESIZE" == "$NAMESUBSTITUTESIZE" ]]; then
				echo 'Hostname substitute list is up-to-date'
				cp /run/ntopnghosts/hostnamesubstitute_new /run/ntopnghosts/hostnamesubstitute
			else
				echo "Hostname substitute list download failed - we'll try again next run"
				#echo "Size doesn't match ($FILESIZE) vs ($NAMESUBSTITUTESIZE)"
			fi
		else
			echo "Hostname substitute list is up-to-date"
		fi
	fi
else 
	cp /etc/nprobe/hostnamesubstitute /run/ntopnghosts/hostnamesubstitute
fi
#main script follows
/opt/vyatta/bin/vyatta-op-cmd-wrapper show dhcp leases | tail -n +3| tr -s " " | sed 's/\^I//' | sort >/run/ntopnghosts/ntopng_newdhcp
#cp tmp/ntopng_newdhcp /run/ntopnghosts/ntopng_newdhcp # for testing only
#cp tmp/ntopng_olddhcp /run/ntopnghosts/ntopng_olddhcp # for testing only
if [[ ! -f "/run/ntopnghosts/ntopng_olddhcp" ]]; then
	if [[ "$TELEGRAMENABLE" == "YES" ]]; then
		MESSAGE="`uname -n` has recently rebooted.  There may be some repeat notifications for devices seen in the last 24 hours"
		TELEGRAMHOSTNAME="`uname -n`"
		echo `sendmessage`
	fi
	# we initialise olddhcp with the contents of newdhcp so that the script doesn't get bogged down with processing every device it can see - that would
	# take longer than 1 minute and therefore would end up with multiple copies of the script running after a reboot.
	cp /run/ntopnghosts/ntopng_newdhcp /run/ntopnghosts/ntopng_olddhcp
fi
comm -3 /run/ntopnghosts/ntopng_olddhcp /run/ntopnghosts/ntopng_newdhcp |grep $SUBNET >/run/ntopnghosts/ntopng_dhcpcomm
# we want to show any non-printable characters including ^I (tab)
cat -vet /run/ntopnghosts/ntopng_dhcpcomm >/run/ntopnghosts/ntopng_dhcpdiff
rm /run/ntopnghosts/ntopng_dhcpcomm
# next we need to remove ^I (tab) characters if they are present
sed -i 's/\^I//' /run/ntopnghosts/ntopng_dhcpdiff
# because we are using cat -vet to remove non-printable characters including ^I (tab) we get $ on the end of lines, so we remove that on the next line
# so that they don't end up in the hostnames
sed -i 's/\$$//' /run/ntopnghosts/ntopng_dhcpdiff
#cat /run/ntopnghosts/ntopng_dhcpdiff
if [[ "$DEBUG" != "" ]]; then 
	trap - DEBUG
	trap
fi
while IFS= read -r line; do
    LASTHOSTNAME=$HOSTNAME
	LASTMAC=$MAC
	#echo $line
	# we will process this file line by line to check each HOSTNAME
    # echo "Text read from file: $line"
    IP=`echo "$line" | cut -d ' ' -f 1`
    HOSTNAME=`echo "$line" | cut -d ' ' -f 6`
	if [[ "$HOSTNAME" == "?" || "$HOSTNAME" == "" ]]; then
	    HOSTNAME="unknown"
	fi
	# Note that while NTOPNG doesn't require the MAC address we are including it in the hostname as hostname(macaddress) as this helps with uniqueness (iPhones and iPads
	# for example all default to iPhone or iPad, unlike Android that uses a unique name).  We also use hostname and mac address for device name substitutions and for 
	# reporting to telegram if you have enabled that functionality.
	MAC=`echo "$line" | cut -d ' ' -f 2`
    echo "Checking IP=$IP HOSTNAME=$HOSTNAME MAC=$MAC"
	# echo "line=$line"
	if [[ "$HOSTNAME $MAC" != "$LASTHOSTNAME $LASTMAC" ]]; then
    	NTOPNGHOSTNAME="$HOSTNAME($MAC)"
        # check if we need to replace the hostname with something more meaningful that we have on file
		if [[ -f "/run/ntopnghosts/hostnamesubstitute" ]]; then
            SUB=`grep -i "^$HOSTNAME $MAC" /run/ntopnghosts/hostnamesubstitute | cut -d ' ' -f 3-100`
            if [[ "$SUB" != "" ]]; then
                echo "Replacing $HOSTNAME with $SUB"
                NTOPNGHOSTNAME="$SUB"
            fi
        fi
        # submit the host to NTOPNG
        RESULT=`curl --ssl -s -u $NTOPNGUSER:$NTOPNGPASS -H "Content-Type: application/json" -d '{"host": "'$IP'", "custom_name": "'$NTOPNGHOSTNAME'"}' "https://$NTOPNGSERVER/lua/rest/v1/set/host/alias.lua"`
        #echo "RESULT=$RESULT"
        # eg. {"rc_str_hr":"Success","rc_str":"OK","rsp":[],"rc":0}
        # check the response for the submission
        RC_STR=`echo $RESULT |jq -r '."rc_str"'`
        #echo "RC_STR=$RC_STR"
		echo "$HOSTNAME has a new DHCP lease.  Result of uploading to NTOPNG result=$RC_STR"
        if [[ "$RC_STR" != "OK" ]]; then
            # Failed to update:  We're going to retry again now and then we'll give up.  This means that if we fail again that host will not update unless it 
			# changes IP address as we'll never retry again.  The only thing that could cause a failure is if we have no internet connection when we run this 
			# or if the ntopng server is down.  Note that following a reboot of the router we WILL try again to register all known hosts from the hosts file 
			# to the ntopng server
            RESULT=`curl --ssl -s -u $NTOPNGUSER:$NTOPNGPASS -H "Content-Type: application/json" -d '{"host": "'$IP'", "custom_name": "'$NTOPNGHOSTNAME'"}' "https://$NTOPNGSERVER/lua/rest/v1/set/host/alias.lua"`
			#echo "RESULT=$RESULT"
            RC_STR=`echo $RESULT |jq -r '."rc_str"'`
			#echo "RC_STR=$RC_STR"
			echo "$HOSTNAME has a new DHCP lease.  Result of uploading to NTOPNG result=$RC_STR"
        fi
		# now check if we need to send a telegram notification about seeing this host
		# note: the telegram notifications are not related in any way to NTOPNG.  This is an additional function that is useful in some environments when it is
		# helpful to know that a new device has appeared on the network and been issued a DHCP address.  Therefore these notifications are based on whether a
		# device has been seen in a certain time period or not.
		# to minimise writes to permanent storage we will write only ONCE PER 24 hours.  https://stackoverflow.com/questions/24356909/sd-card-write-limit-data-logging
		# to do this we will assume that any device seen that day will still have a valid DHCP lease at the time we write it.  If the router is rebooted we will lose
		# this information, but if it is rebooted during working hours the clients will request their previous DHCP address again and that request will generally be
		# honoured and the DHCP lease table will be restored in this way.  Therefore we won't lose much information.  In fact it is probably unlikely to cause a problem
		# even if we only updated our records up to one tenth of the NOTIFYDAYS period.  So if you want to adjust the regularity of these writes you can change SAVEPERIOD
		if [[ "$TELEGRAMENABLE" == "YES" ]]; then
			# if we've recently rebooted we won't have a temporary hostnameregister so we'll copy it from the last saved in /etc/nprobe.  But if there isn't one there
			# we'll start a new file
			if [[ ! -f "/run/ntopnghosts/hostnameregister" ]]; then
				if [[ ! -f "/etc/nprobe/hostnameregister" ]]; then
				    touch /run/ntopnghosts/hostnameregister
				else
				    cp /etc/nprobe/hostnameregister /run/ntopnghosts/hostnameregister
				fi
			fi
			# when did we last see this device?  We'll check the HOSTLOG first because there is a possibility that this device is not uniquely named
			if [[ "`echo -e "$HOSTLOG" |grep -m 1 "^$HOSTNAME $MAC"`" == "" ]]; then 
				# we didn't find a device with this name already so we'll keep processing (some device names are not unique (eg. iPhone or iPad) so we make all device
				# names unique by matching them with their MAC address)
				HOSTLOG="$HOSTLOG$CRLF$HOSTNAME $MAC `date -I`"
				LASTSEEN=`grep -i "^$HOSTNAME $MAC" /run/ntopnghosts/hostnameregister | cut -d ' ' -f 3-100`
				if [[ "$LASTSEEN" == "" ]]; then
					echo "We have never seen this device before"
					DAYS=9999999
				else
					# echo "DEBUG: LASTSEEN=$LASTSEEN"
					DAYS=`dateDiff -d "now" "$LASTSEEN"`
					echo "$HOSTNAME was last seen $DAYS days ago"
				fi
				# check if we need to replace the hostname with something more meaningful that we have on file
				TELEGRAMHOSTNAME="$HOSTNAME ($MAC)"
				if [[ "$SUB" != "" ]]; then
					echo "Replacing $HOSTNAME with $SUB"
					TELEGRAMHOSTNAME="$SUB ($HOSTNAME $MAC)"
				fi
				if [[ "$DAYS" -gt "$NOTIFYDAYS" ]]; then
					if [[ "$LASTSEEN" == "" ]]; then
						if [[ "$SUBNETDESCRIPTION" != "" ]]; then
							MESSAGE="$TELEGRAMHOSTNAME has been seen for the first time ($SUBNETDESCRIPTION:$IP)."
						else 
							MESSAGE="$TELEGRAMHOSTNAME has been seen for the first time ($IP)."
						fi
					else 
						if [[ "$SUBNETDESCRIPTION" != "" ]]; then
							MESSAGE="$TELEGRAMHOSTNAME has been seen for the first time in $NOTIFYDAYS days ($SUBNETDESCRIPTION:$IP)."
						else
							MESSAGE="$TELEGRAMHOSTNAME has been seen for the first time in $NOTIFYDAYS days ($IP)."
						fi
					fi
					if [[ "$NOTIFYMESSAGE" != "" ]]; then
						MESSAGE="$MESSAGE  $NOTIFYMESSAGE"
					fi
					echo `sendmessage`
				fi
			fi
		fi
	fi
    echo ""
done < /run/ntopnghosts/ntopng_dhcpdiff
if [[ "$DEBUG" != "" ]]; then 
	set -x
	trap 'read -p "run: $BASH_COMMAND"' DEBUG
fi
# now we update the ntopng_olddhcp file so that it is ready for next time with what was current this time
if [[ -f "/run/ntopnghosts/ntopng_olddhcp" ]]; then
    rm /run/ntopnghosts/ntopng_olddhcp
fi
cp /run/ntopnghosts/ntopng_newdhcp /run/ntopnghosts/ntopng_olddhcp
if [[ "$TELEGRAMENABLE" == "YES" ]]; then
	# need to look for all devices that are in the current hostname register but not in HOSTLOG and add them to HOSTLOG with their old dates - note this will usually be
	# almost all the devices because we should only get a few lease updates every few minutes at the most, and therefore every other device will be added from history
	# note that the next 7 lines of code should be redundant but they are kept here for safety since we don't want to have errors if files don't exist
	if [[ ! -f "/run/ntopnghosts/hostnameregister" ]]; then
		if [[ ! -f "/etc/nprobe/hostnameregister" ]]; then
			touch /run/ntopnghosts/hostnameregister
		else
			cp /etc/nprobe/hostnameregister /run/ntopnghosts/hostnameregister
		fi
	fi
	#echo -e "$HOSTLOG"
	#echo "adding additional computers from old hostnameregister..."
	#echo "for checking, here is the current hostname register - all computers in this list should be copied to the new list if they aren't already in it"
	if [[ "$DEBUG" != "" ]]; then 
		trap - DEBUG
		trap
	fi
	while IFS= read -r line; do
		HOSTNAME=`echo "$line" | cut -d ' ' -f 1`
		MAC=`echo "$line" | cut -d ' ' -f 2`
		#echo "$HOSTNAME $MAC"
		if [[ "$HOSTNAME" != "" ]]; then
			if [[ "`echo -e "$HOSTLOG" |grep -m 1 "^$HOSTNAME $MAC"`" == "" ]]; then
				# we didn't find a matching device that we've already processed
				HOSTLOG="$HOSTLOG$CRLF$line"
			fi
		fi
	done < /run/ntopnghosts/hostnameregister 
	if [[ "$DEBUG" != "" ]]; then 
		set -x
		trap 'read -p "run: $BASH_COMMAND"' DEBUG
	fi
	#echo -e "$HOSTLOG"
	echo -e "$HOSTLOG" | sort -f > /run/ntopnghosts/hostnameregister
	SAVEPERIOD=1
	# when did we last update the long term storage with our current last seen hosts list?
	if [[ -f "/run/ntopnghosts/hostsupdate" ]]; then
		LASTSAVEDHOSTS=`cat /run/ntopnghosts/hostsupdate`
		SINCESAVED=`dateDiff -d "now" "$LASTSAVEDHOSTS"`
	else 
		# this is the first time we've run it
		LASTSAVEDHOSTS=
		SINCESAVED=9999999
	fi
	if [[ "$SINCESAVED" -gt "$SAVEPERIOD" ]]; then 
		# now we need to write an update of all the hosts we can see today in dhcp
		if [[ ! -f "/etc/nprobe/hostnameregister" ]]; then
			touch /etc/nprobe/hostnameregister
		fi
		cmp -s /etc/nprobe/hostnameregister /run/ntopnghosts/hostnameregister
		if [[ "$?" != "0" ]]; then
			cp /run/ntopnghosts/hostnameregister /etc/nprobe/hostnameregister
			echo `date -I` > /run/ntopnghosts/hostsupdate
			echo Updated the hostnameregister in long term storage
		fi
		# if we are centrally managing the hostnamesubstitute file then we may need to update it to long term storage too
		if [[ "$NAMESUBSTITUTEURL" != "" ]]; then
			if [[ ! -f "/etc/nprobe/hostnamesubstitute" ]]; then
				touch /etc/nprobe/hostnamesubstitute
			fi
			cmp -s /etc/nprobe/hostnamesubstitute /run/ntopnghosts/hostnamesubstitute
			if [[ "$?" != "0" ]]; then
				cp /run/ntopnghosts/hostnamesubstitute /etc/nprobe/hostnamesubstitute
				echo Updated the hostnamesubstitute in long term storage
			fi
		fi
	fi
fi
# we need to check if the script itself needs to be updated
if [[ "$UPDATEURL" != "" ]]; then
	UPDATESIZE=`curl --ssl -sI $UPDATEURL --location --silent -H 'Accept-Encoding: gzip,deflate' |grep -i content-length |cut -d ' ' -f2`
	UPDATESIZE=(${UPDATESIZE:0:-1})
	#curl --ssl -sI $UPDATEURL --location --silent --write-out 'size_download=%{size_download}\n'
	if [[ -f "/etc/nprobe/ntopnghosts.sh" ]]; then
		FILESIZE=`wc -c /etc/nprobe/ntopnghosts.sh|cut -d ' ' -f1`
	else
		FILESIZE=0
	fi
	#echo "Centrally managed script size: $UPDATESIZE"
	#echo "Local script size: $FILESIZE"
	if [[ "$UPDATESIZE" != "0" ]]; then
		if [[ "$FILESIZE" != "$UPDATESIZE" ]]; then
			echo "Downloading updated script"
			curl --ssl -s $UPDATEURL -o "/run/ntopnghosts/ntopnghosts.sh"
			# verify that we actually downloaded a file of the expected file size
			FILESIZE=`wc -c /run/ntopnghosts/ntopnghosts.sh|cut -d ' ' -f1`
			if [[ "$FILESIZE" == "$UPDATESIZE" ]]; then
				echo 'Script is up-to-date'
				cp /run/ntopnghosts/ntopnghosts.sh /etc/nprobe/ntopnghosts.sh
				chmod +x /etc/nprobe/ntopnghosts.sh
			else
				echo "Script  download failed - we'll try again next run"
				#echo "Size doesn't match ($FILESIZE) vs ($UPDATESIZE)"
			fi
		else
			echo "Script is up-to-date"
		fi
	fi
fi
echo "Checking complete."