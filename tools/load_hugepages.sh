#!/bin/bash

rmmod pf_ring
insmod ../PF_RING/kernel/pf_ring.ko

# Dropping cached memory
sync && echo 3 > /proc/sys/vm/drop_caches

NUMPAGES=256
if [ `cat /proc/mounts | grep hugetlbfs | wc -l` -eq 0 ]; then
	echo $NUMPAGES > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

	if [ `cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages` -eq $NUMPAGES ]; then
	    if [ ! -d "$DIRECTORY" ]; then
		mkdir /mnt/huge
	    fi
	    mount -t hugetlbfs nodev /mnt/huge
	else
	    echo "FATAL ERROR: Unable to set hugepages."
	    exit
	fi
fi

ifconfig eth3 up
ifconfig eth4 up
#
# Disable interface GRO/TSO
#
ethtool -K eth3 gro off gso off tso off
ethtool -K eth4 gro off gso off tso off

