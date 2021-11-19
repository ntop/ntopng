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
CSV_DELIMITER="|"
MAX_ROW_NUM=100000

DB_COLUMNS="COMMUNITY_ID,DST2SRC_DSCP,DST2SRC_TCP_FLAGS,DST_ASN,DST_COUNTRY_CODE,DST_LABEL,DST_MAC,FLOW_TIME,INFO,INTERFACE_ID,IPV4_DST_ADDR,IPV4_SRC_ADDR,IPV6_DST_ADDR,IPV6_SRC_ADDR,IP_DST_PORT,IP_PROTOCOL_VERSION,L7_CATEGORY,L7_PROTO,L7_PROTO_MASTER,FIRST_SEEN,LAST_SEEN,PACKETS,PROFILE,PROTOCOL,SCORE,SRC2DST_DSCP,SRC2DST_TCP_FLAGS,SRC_ASN,SRC_COUNTRY_CODE,SRC_MAC,TOTAL_BYTES,VLAN_ID"


function showHelp {
    {
    exporting="nIndex to ClickHouse Flow Exporter"
	company="(C) 1998-21 ntop.org\n\n"
	usage="nindex_export_to_ch -d <base dir> [-u <user>]\n"
	usage+="                    [-p <pwd>] [-n <name>]\n"
	usage+="                    [-np <path>] [-cp <path>]\n\n"
	d_option="[-d] <dir>		| ntopng database root folder.\n"
	u_option="[-h] <host>		| ClickHouse host. If no host is given\n 			| then the default host is going to be used.\n"
	u_option="[-u] <user>		| ClickHouse user. If no user is given\n 			| then the default user is going to be used.\n"
	p_option="[-p] <pwd>		| ClickHouse password. If no password is given\n 			| then the default password is going to be used.\n"
	n_option="[-n] <name>		| ClickHouse database name. If no name is given\n 			| then the default database name is going to be used.\n\n"
	n_option="[-np] <path>		| nIndex path. If no path is given\n 			| then /usr/bin/nindex is going to be launched.\n\n"
	n_option="[-cp] <path>		| ClickHouse path. If no path is given\n 			| then /usr/bin/clickhouse-client is going to be launched.\n\n"
	important="IMPORTANT: Before running this tool is necessary to run ntopng with ClickHouse at least one time.\n 	Run this tool if ntopng shutdown.\n\n"
	example="Example:\nsudo ./nindex_export_to_ch.sh -d /var/lib/ntopng/ -np ../../nIndex/nindex -cp /usr/bin/clickhouse-client\n"

	help_print=$company
	help_print+=$usage
	help_print+=$d_option
	help_print+=$u_option
	help_print+=$p_option
	help_print+=$n_option
	help_print+=$important
	help_print+=$example

	printf "%b" "$help_print"
    }
}

function exportCSV {
	{
	csv_file="/tmp/export_tmp.csv"
	fault_dir="Error while exporting directory:\n"
	num_fault_dir=0
	
	# Getting all interfaces
	for dir in $NTOPNG_DIR/*
	do
		dir+="/flows"
		cur_row=0

		echo "Exporting directory: ${dir}"

		while [ true ] 
		do	
			# Checking if the flows directory exists inside the interface
			if [ -d $dir ]
			then
				if [ -f $csv_file ] 
				then
					rm $csv_file
				fi

				to_row=`expr $cur_row + $MAX_ROW_NUM`
				echo "Exporting from row: ${cur_row} to row: ${to_row}"
				
				# echo "-- DEBUG: $NINDEX_PATH -d $dir -f $csv_file -L $cur_row -l $MAX_ROW_NUM -c -s \"$DB_COLUMNS\""
				
				# Now export nindex values in a csv file
				$NINDEX_PATH -d $dir -f $csv_file -L $cur_row -l $MAX_ROW_NUM -c -s $DB_COLUMNS &> /dev/null
				cur_row=`expr $cur_row + $MAX_ROW_NUM`		

				# Get column list
				db_ch_columns=$(head -n 1 $csv_file)
				db_ch_columns=${db_ch_columns//"|"/","}

				DB_QUERY="INSERT INTO flows ("
				DB_QUERY+=$db_ch_columns
				DB_QUERY+=") FORMAT CSV"
				
				# echo $DB_QUERY

				# Remove first row from file (Column list row)
				sed -i '1d' $csv_file

				if [ -f $csv_file ] && [ ! -s $csv_file ]
				then
					echo "Done exporting directory: ${dir}"
					rm $csv_file
					break # No more data for this interface					
				fi

				# echo "-- DEBUG: cat $csv_file | $CH_PATH --host \"$HOST\" --user \"$USER\" --password \"$PWD\" -d \"$DB_NAME\" --format_csv_delimiter=\"$CSV_DELIMITER\" --query=\"$DB_QUERY\""
				
				# Import the nindex values into ClickHouse
				cat $csv_file | $CH_PATH --host "$HOST" --user "$USER" --password "$PWD" -d "$DB_NAME" --format_csv_delimiter="$CSV_DELIMITER" --query="$DB_QUERY"	
				ret_val=$?
			 
				# No data to insert error, skip directly to the subsequent directory
				if [ $ret_val -eq 108 ]
				then
					echo "Done exporting directory: ${dir}"
					break
				fi

				if [ $ret_val -ne 0 ]
				then
					echo "Error while exporting directory: ${dir}. Return code n. ${ret_val}"
					fault_dir+="${dir} | Return code n. ${ret_val}"
					if [ $ret_val -eq 27 ]
					then
						fault_dir+=": nIndex DB data corrupted."
					fi
					fault_dir+="\n"

					num_fault_dir=`expr $num_fault_dir + 1`
					break
				fi
			else
				echo "Done exporting directory: ${dir}"
				break
			fi
		done 
	done

	if [ $num_fault_dir -ne 0 ] 
	then
		printf "$fault_dir"
	else
		echo "Job accomplished, all flows have been exported"
	fi
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
        *) echo "Unknown parameter given: $1. Check -h for more infos"; exit 1 ;;
    esac

    # shift 2 positions
    shift
    shift
done

if [ "$NTOPNG_DIR" == "" ]
then
    printf "ntopng data directory not provided. Please run this tool with option -d.\n\nExample:\nnindex_export_to_ch -d /var/lib/ntopng/\n"
    exit -1
fi

if [ ! -f $CH_PATH ]
then
	printf "[ERROR] Missing executable clickhouse-client. Install at https://clickhouse.com/#quick-start\n"
	exit -1
fi

if [ ! -f $NINDEX_PATH ]
then
	printf "[ERROR] Missing executable nindex. Install the latest packaged ntopng. \n"
	exit -1
fi

if [ "$EUID" -ne 0 ]
then
    printf "[ERROR] This tool requires root privileges. Try again with \"sudo \" please ...\n"
    exit -1
fi

# Executes a SELECT to make sure the database exists
$CH_PATH --host "${HOST}" --user "${USER}" --password "${PWD}" -d "${DB_NAME}" --query="SELECT 1 from flows limit 1"

if [ "$?" -ne 0 ]
then
    printf "[ERROR] Unable to find database ${DB_NAME}. Start ntopng with ClickHouse using option -F \"clickhouse;${HOST};${DB_NAME};flows;${USER};${PW}\" to configure the database and then re-run this script. \n"
    exit -1
fi

exportCSV
exit 0
