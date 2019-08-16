#!/bin/bash

# prepending $PWD/../bin to PATH to ensure we are picking up the correct binaries
# this may be commented out to resolve installed version of tools if desired
export PATH=${PWD}/../bin:${PWD}:$PATH
export FABRIC_CFG_PATH=${PWD}
export VERBOSE=false

. cerberusntw.sh

# Print help message
function printNetworkOperationHelp() {
	echo
	echo "### Commands: ###"
	echo


}

# Ask user for confirmation to proceed
function askProceed() {

        echo "Continue? [Y/n] "
        read -p " " ans

        case "$ans" in
        y | Y | "")
                echo "proceeding ..."
                ;;
        n | N)
                echo "exiting..."
                exit 1
                ;;
        *)
                echo "invalid response"
                askProceed
                ;;
        esac
}

MODE=$1

# Determine action
# ./operatecerbntw.sh help
if [ "$MODE" == "help" ]; then
	EXPMODE="Display Cerberus network operation help message"

elif [ "$MODE" == "read-conf" ]; then
	EXPMODE="Reading Cerberus network configuration and setting up configuration files"

else
	printNetworkOperationHelp
	exit 1
fi

# Announce what was requested
echo "${EXPMODE}"
askProceed

# ./operatecerbntw.sh help
if [ "${MODE}" == "help" ]; then
	printNetworkOperationHelp

# ./operatecerbntw.sh read-conf
elif [ "${MODE}" == "read-conf" ]; then

	bash scripts/cerberus/readConfiguration.sh

fi

