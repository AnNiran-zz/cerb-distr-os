#!/bin/bash

ORG=$1

# This script is designed to be run remotely from organization hosts 
# to add its extra hosts to Cerberus network and CerberusOrg containers
echo "========= Adding ${ORG^} extra hosts to containers remotely ========="

source .profile

cd server/go/src/cerberus-os/hl/network
echo $PWD

. scripts/addExtraHosts.sh

addExternalHostsData $ORG

echo "========= ${ORG^} hosts added remotely to Cerberus network ========="
exit 0
