#!/bin/bash

#
# Use this tool to create kafka topics wot be used with ntopng/nProbe
#

#
# See https://www.conduktor.io/kafka/kafka-topics-cli-tutorial/
#

ntop_topics=(flow event counter template snmp-ifaces option hello listening-ports)


# Set your PATH here
KAFKA_TOPICS=/home/kafka/kafka/bin/kafka-topics.sh


for topic in "${ntop_topics[@]}"
do
    $KAFKA_TOPICS --bootstrap-server localhost:9092 --topic $topic --create --partitions 3 --replication-factor 1
done


$KAFKA_TOPICS --bootstrap-server localhost:9092 --list
