#!/bin/bash

ORG=$1

# This script is designed to be run remotely from organization hosts 
# to add its extra hosts to Cerberus network and CerberusOrg containers
echo "========= Removing ${ORG^} extra hosts from network containers remotely ========="

source .profile
cd server/go/src/cerberus-os/hl/network

. scripts/removeExtraHosts.sh

removeExternalHostsData $ORG
 
echo "========= ${ORG}^ hosts removed remotely from Cerberus network ========="
exit 0
                                                                                                                                                                                             
