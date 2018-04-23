#!/usr/bin/env bash

# Get the absolute path of this script on the system.
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

echo -e "\n===== SCRIPT PARAMETERS ====="
echo $@

HOSTFILE=$1
HOSTNAME=$2

for p in ("$HOSTFILE")
do
    for word in "${p[@]}"
    do
        ssh $word "iperf3 -c $HOSTNAME"
        break;
    done
done
