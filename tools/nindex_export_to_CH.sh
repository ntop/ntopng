#!/usr/bin/env bash
#
#  Copyright (C) 2002-20 - ntop.org
#
#  http://www.ntop.org/
#

NTOPNG_DIR=""
NINDEX_PATH="/usr/bin/nindex"
CH_PATH="/usr/bin/clickhouse-client"
HOST="127.0.0.1"
USER="default"
PWD=""
DB_NAME="ntopng"
DB_FLOWS="flows"
CSV_DELIMITER="\\n"

DB_COLUMNS="IP_PROTOCOL_VERSION,FLOW_TIME,FIRST_SEEN,LAST_SEEN,VLAN_ID,PACKETS,TOTAL_BYTES,SRC2DST_BYTES,DST2SRC_BYTES,SRC2DST_DSCP,DST2SRC_DSCP,PROTOCOL,IPV4_SRC_ADDR,IPV6_SRC_ADDR,IP_SRC_PORT,IPV4_DST_ADDR,IPV6_DST_ADDR,IP_DST_PORT,L7_PROTO,L7_CATEGORY,FLOW_RISK,INFO,PROFILE,NTOPNG_INSTANCE_NAME,INTERFACE_ID,STATUS,SRC_COUNTRY_CODE,DST_COUNTRY_CODE,SRC_LABEL,DST_LABEL,SRC_MAC,DST_MAC,COMMUNITY_ID,SRC_ASN,DST_ASN,PROBE_IP,OBSERVATION_POINT_ID,SRC2DST_TCP_FLAGS,DST2SRC_TCP_FLAGS,SCORE,L7_PROTO_MASTER,CLIENT_NW_LATENCY_US,SERVER_NW_LATENCY_US"


function showHelp {
    {
    exporting="nIndex to ClickHouse Flow Exporter"
	company="(C) 1998-21 ntop.org\n\n"
	usage="nindex_export_to_CH -d <base dir> [-u <user>]\n"
	usage+="                    [-p <pwd>] [-n <name>]\n\n"
	d_option="[-d] <dir>		| ntopng database root folder.\n"
	u_option="[-h] <host>		| ClickHouse host. If no host is given\n 			| then the default host is going to be used.\n"
	u_option="[-u] <user>		| ClickHouse user. If no user is given\n 			| then the default user is going to be used.\n"
	p_option="[-p] <pwd>		| ClickHouse password. If no password is given\n 			| then the default password is going to be used.\n"
	n_option="[-n] <name>		| ClickHouse database name. If no name is given\n 			| then the default database name is going to be used.\n\n"
	n_option="[-np] <path>		| nIndex path. If no path is given\n 			| then /usr/bin/nindex is going to be launched.\n\n"
	n_option="[-cp] <path>		| ClickHouse path. If no path is given\n 			| then /usr/bin/clickhouse-client is going to be launched.\n\n"
	example="Example:\nnindex_export_to_CH -d /var/lib/ntopng/\n"

	help_print=$company
	help_print+=$usage
	help_print+=$d_option
	help_print+=$u_option
	help_print+=$p_option
	help_print+=$n_option
	help_print+=$example

	printf "%b" "$help_print"
    }
}

function exportCSV {
	{
	DB_QUERY="\"INSERT INTO flows ("
	DB_QUERY+=$DB_COLUMNS
	DB_QUERY+=") FORMAT CSV\""

	csv_file="/tmp/export_tmp.csv"
	
	# Getting all interfaces
	for dir in $NTOPNG_DIR/*
	do
		dir+="/flows"

		# Checking if the flows directory exists inside the interface
		if [ -d $dir ]
		then
			# Now export nindex values in a csv file
			$NINDEX_PATH -d "$dir" -f "$csv_file"

			if [ -f $csv_file ]
			then
				# Import the nindex values into ClickHouse
				cat $csv_file | $CH_PATH --host "$HOST" --user "$USER" --password "$PWD" -d "$DB_NAME" --format_csv_delimiter="\\n" --query="$DB_QUERY"
				rm $csv_file
			fi
		fi 
	done
	}
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
	    showHelp
	    exit 0
	    ;;
	    -d) # nIndex directory, mandatory opt.
		NTOPNG_DIR=$2
		;;
		-h) # CH host
		HOST=$2
		;;
		-u) # CH username
		USER=$2
		;;
		-p) # CH password
		PWD=$2
		;;
		-n) # CH database name, by default ntopng
		DB_NAME=$2
		;;
		-np) # nIndex exec path
		NINDEX_PATH=$2
		;;
		-cp) # CH exec path
		CH_PATH=$2
		;;
        *) echo "Unknown parameter passed: $1. Check -h for more infos"; exit 1 ;;
    esac

    # shift 2 positions
    shift
    shift
done

if [ "$NTOPNG_DIR" == "" ]
then
    printf "No ntopng folder provided. Please run this tool with option -d.\n\nExample:\nnindex_export_to_CH -d /var/lib/ntopng/\n"
    exit -1
fi

if [ "$EUID" -ne 0 ]
then
    printf "This tool requires root privileges. Try again with \"sudo \" please ...\n"
    exit -1
fi

exportCSV
exit 0