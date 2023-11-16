# Discontinuation Notice

ntopng 4.1+ no longer supports nagios integration via NSCA. [NSCA has not been maintained for more than four years](https://exchange.nagios.org/directory/Addons/Passive-Checks/NSCA--2D-Nagios-Service-Check-Acceptor/details]) and this no longer enables us to ensure its functionality and interoperability with ntopng.

Although nagios integration is no longer supported, the following alternatives are possible for software derived from nagios:
- [Icinga2](https://www.ntop.org/guides/ntopng/advanced_features/icinga2.html?highlight=nagios#icinga2-integration)
- [Check_MK](https://blog.checkmk.com/checkmk-conference-6-network-flow-monitoring-with-ntop)



## Using ntopng as a source of data for nagios (outdated)

ntopng can now be used by nagios as a source of data. For instance you can query ntopng via the HTTP interface and extract JSON-based traffic information

Now you can create nagios plugins that can query ntopng periodically and implement alerting on traffic.

Below you can find an example of what a ntop-nagios plugin looks like

```
================================================================================

#!/bin/bash

################################################################################
# Nagios plugin to get info about a host from a terminal running ntopng        #
# ntopng (C) 2015                                                              #
################################################################################

VERSION="0.1"
AUTHOR="ntopng (C) 2015"

# Exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

function print_help {
   # Print detailed help information
   echo "$AUTHOR - Get host info from ntopng instance"
   /bin/cat <<__EOT

Options:
-h
-?
   Print detailed help screen

-n HNAME
   Name of the host ntopng is running on.
-i INTEGER
   Interface to check the host on.
-H HNAME
   Name of host to get info for.
-p INTEGER
   Port ntopng is listening on the host specified with -h.
-u USER
   ntopng user for Nagios checks.
-c PASSWD
   Password for ntopng user for Nagios checks.
__EOT
}

NTOPNG_HOST=
NTOPNG_PORT=
NTOPNG_USER=
NTOPNG_PASS=
CHECK_HOST=
CHECK_INTF=

# Parse command line options
while [ "$1" ]; do
   case "$1" in
       -h | --help)
           print_help
           exit $STATE_OK
           ;;
       -H | --host)
           CHECK_HOST=$2
           shift 2
           ;;
       -i | --interface)
           CHECK_INTF=$2
           shift 2
           ;;
       -n | --ntopng)
           NTOPNG_HOST=$2
           shift 2
           ;;
       -p | --port)
           NTOPNG_PORT=$2
           shift 2
           ;;
       -u | --user)
           NTOPNG_USER=$2
           shift 2
           ;;
       -c | --password)
           NTOPNG_PASS=$2
           shift 2
           ;;
       -?)
           print_help
           exit $STATE_OK
           ;;
       *)
           echo "$0: Invalid option '$1'"
           print_help
           exit $STATE_UNKNOWN
           ;;
   esac
done

if [[ "$NTOPNG_HOST" == "" ]] || [[ "$NTOPNG_PORT" == "" ]] ||
   [[ "$NTOPNG_USER" == "" ]] || [[ "$NTOPNG_PASS" == "" ]] ||
   [[ "$CHECK_HOST" == "" ]] || [[ "$CHECK_INTF" == "" ]]; then
  echo "$0: all parameters are compulsory"
  print_help
  exit $STATE_WARNING
fi

RESULT_JSON=`curl -s -u ${NTOPNG_USER}:${NTOPNG_PASS} 'http://'${NTOPNG_HOST}':'${NTOPNG_PORT}'/lua/rest/get/host/data.lua?ifname='${CHECK_INTF}'&host='${CHECK_HOST}`

# Handle result and return appropriate status
echo $RESULT_JSON
if [[ "$RESULT_JSON" == "" ]]; then
  exit $STATE_CRITICAL
fi

#wget --auth-no-challenge -mk --user $NTOPNG_USER --password $NTOPNG_PASS 'http://'${NTOPNG_HOST}':'${NTOPNG_PORT}'/lua/rest/get/host/data.lua?ifname='${CHECK_INTF}'&host='${CHECK_HOST}

exit $STATE_OK

================================================================================
```
