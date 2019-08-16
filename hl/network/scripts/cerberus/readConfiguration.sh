#!/bin/bash

ARCH=$(uname -s | grep Darwin)
if [ "$ARCH" == "Darwin" ]; then
        OPTS="-it"
else
        OPTS="-i"
fi

CURRENT_DIR=$PWD

# read configuration file
cerberusOrgConfigFile=cerberus-config/org/org-data.json

if [ ! -f "$cerberusOrgConfigFile" ]; then
        echo
        echo "ERROR: $cerberusOrgConfigFile file not found. Cannot proceed with parsing new orgation configuration"
        exit 1
fi

cerberusOsConfigFile=cerberus-config/os/os-data.json

if [ ! -f "$cerberusOsConfigFile" ]; then
        echo
        echo "ERROR: $cerberusOsConfigFile file not found. Cannot proceed with parsing new orgation configuration"
        exit 1
fi


# read cerberusorg configuration file and add environment variables for external services
bash scripts/cerberus/addCerberusOrgExternalPeersToEnv.sh

# read ordering service configuration file and add environment variables for external services
bash scripts/cerberus/addCerberusOsExternalPeersToEnv.sh

echo "hello from the new configuration logic"
