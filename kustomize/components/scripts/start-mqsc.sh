#!/bin/bash
#
# A simple MVP script that will run MQSC against a queue manager.
ckksum=""

# Outer loop that keeps the MQ service running
while true; do

   tmpCksum=`cksum /dynamic-mq-config-mqsc/dynamic-definitions.mqsc | cut -d" " -f1`

   if (( tmpCksum != cksum ))
   then
      cksum=$tmpCksum
      echo "Applying MQSC"
      runmqsc $1 < /dynamic-mq-config-mqsc/dynamic-definitions.mqsc
   else
      sleep 3
   fi

done
