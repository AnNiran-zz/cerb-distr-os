#!/bin/bash

# prepending $PWD/../bin to PATH to ensure we are picking up the correct binaries
# this may be commented out to resolve installed version of tools if desired
export PATH=${PWD}/../bin:${PWD}:$PATH
export FABRIC_CFG_PATH=${PWD}
export VERBOSE=false

. cerberusntw.sh 
. extorgcerbntw.sh

# Print the usage message
function printHelp() {
	echo
	echo "### Commands: ###"
	echo
	echo "operatecntw.sh <action>"
	echo "	generate"
	echo "		Generates required certificates and genesis block for channels PersonAccounts, InstitutionAccounts and IntegrationAccounts"
	echo
	echo "	network-up"
	echo "		Generates required certifictaes and genesis block for channels PersonAccounts, InstitutionAccount and IntegrationAccounts"
	echo "		Starts all containers for Ordering Service instances and CerberusOrg"
	echo
	echo "	network-down"
	echo "		Stops all running containers for Ordering Service instances and CerberusOrg"
	echo "		Deletes all created certificates and genesis block for channels PersonAccounts, InstitutionAccounts and IntegrationAccounts"
	echo
	echo
	echo "	deliver-network-data -o <organization-name>"
	echo "		Checks if organization data is set in environment variaons"
	echo "		Delivers Cerberus network hosts data to external organization host machines"
	echo
	echo 
	echo "	add-org-env -o <organization-name>"
	echo "		Adds organization host machines data to environemnt configuration file"
	echo
	echo
	echo "	remove-org-env -o <organization-name>"
	echo "		Removes organization host machines data from environment configuration file"
	echo
	echo
	echo "	add-netenv-remotely -o <organization-name>"
	echo "		Add Cerberus network environment data to organization peers host machines remotely by starting predefined scripts on remote machines"
	echo
	echo
	echo "	help"
	echo "		Displays this message"
	echo

	echo "  cerberusntw.sh <mode> [-c <channel name>] [-t <timeout>] [-d <delay>] [-f <docker-compose-file>] [-s <dbtype>] [-l <language>] [-o <consensus-type>] [-i <imagetag>] [-v]"
	echo "    <mode> - one of 'up', 'down', 'restart', 'generate' or 'upgrade'"
	echo "      - 'restart' - restart the network"
 	echo "    -t <timeout> - CLI timeout duration in seconds (defaults to 10)"
	echo "    -d <delay> - delay duration in seconds (defaults to 3)"
	echo "    -f <docker-compose-file> - specify which docker-compose file use (defaults to docker-compose-cli.yaml)"
	echo "    -v - verbose mode"
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

CHANNELS_LIST=''
CHANNEL_NAME=''
NEW_ORG=''

# Parse commandline args
if [ "$1" = "-m" ]; then # supports old usage, muscle memory is powerful!
	shift
fi
MODE=$1
shift

# Determine action

# ./operatecntw.sh help
if [ "$MODE" == "help" ]; then
	EXPMODE="Display help usage message"

# ./operatecntw network-up
elif [ "$MODE" == "network-up" ]; then
	EXPMODE="Starting Cerberus network"

# ./operatecntw.sh network-down
elif [ "$MODE" == "network-down" ]; then
	EXPMODE="Stopping Cerberus network"

# ./operatecntw.sh generate
elif [ "$MODE" == "generate" ]; then
	EXPMODE="Generating Cerberus certificates and genesis block for channels: PersonAccounts, InstitutionAccounts and IntegrationAccounts"

# ./operatecntw.sh deliver-network-data -o sipher
elif [ "$MODE" == "deliver-network-data" ]; then
	EXPMODE="Deliver Cerberus network data to organization host machines"

# ./operatecntw.sh add-org-env -o sipher
elif [ "$MODE" == "add-org-env" ]; then
	EXPMODE="Adding new organization environment data"

# ./operatecntw.sh remove-org-env -o sipher
elif [ "$MODE" == "remove-org-env" ]; then
	EXPMODE="Removing organization environment data"

# ./operatecntw.sh add-netenv-remotely -o sipher
elif [ "$MODE" == "add-netenv-remotely" ]; then
	echo "This command will successfully add Cerberus network environment data to organization peers host machines remotely if network configuration files are present on them inside \"network-config/\" folder. If you are not certain about this run \"./operatecntw.sh deliver-network-data -o <organization-name>\" first."

	EXPMODE="Adding network environment data to organization hosts remotely"



# ./cerberusntw.sh remove-netenv-remotely -n sipher
elif [ "$MODE" == "remove-netenv-remotely" ]; then
	EXPMODE="Removing network environment data from organization host remotely"

# ./cerberusntw.sh add-org-hosts -n sipher
elif [ "$MODE" == "add-org-hosts" ]; then
	EXPMODE="Adding organization hosts to local host containers"

# ./cerberusntw.sh remove-org-hosts -n sipher
elif [ "$MODE" == "remove-org-hosts" ]; then
	EXPMODE="Removing organization hosts from local host containers"

# ./cerberusntw.sh add-network-hosts-remotely -n sipher
elif [ "$MODE" == "add-network-hosts-remotely" ]; then
	EXPMODE="Adding network hosts to organization configuration remotely "

# ./cerberusntw.sh remove-network-hosts-remotely
elif [ "$MODE" == "remove-network-hosts-remotely" ]; then
	EXPMODE="Removing network hosts from organization configuration remotely "










elif [ "$MODE" == "getorgartifacts" ]; then
	EXPMODE="Obtaining organization artifacts from remote hosts ..."

elif [ "$MODE" == "test" ]; then
	EXPMODE="testing"

elif [ "$MODE" == "connectorg" ]; then
	EXPMODE="Connecting to Cerberus network"

elif [ "$MODE" == "getartifacts" ]; then
	EXPMODE="Getting organization channel artifacts"

elif [ "$MODE" == "record" ]; then
	EXPMODE="Adding to records ..."

elif [ "$MODE" == "disconnectorg" ]; then
	EXPMODE="Disconnecting organization from network channels"

elif [ "$MODE" == "restart" ]; then
	EXPMODE="Restarting Cerberus network"

else
	printHelp
	exit 1
fi

while getopts "h?c:t:d:f:n:l:i:o:v" opt; do
	case "$opt" in
	h | \?)
		printHelp
		exit 0
		;;
	c)      
		CHANNEL_NAME=$OPTARG
		;;
	t)      
		CLI_TIMEOUT=$OPTARG
		;;
	d)      
		CLI_DELAY=$OPTARG
		;;
	f)      
		COMPOSE_FILE=$OPTARG
		;;
	n)      
		NEW_ORG=$OPTARG
		;;
	l)      
		CHANNELS_LIST=$OPTARG
		;;	
	i)      
		IMAGETAG=$(go env GOARCH)"-"$OPTARG
		;;
	o)      
		NEW_ORG=$OPTARG
		;;
	v)      
		VERBOSE=true
		;;
	esac    
done    
 
# Announce what was requested
echo "${EXPMODE}"

# ask for confirmation to proceed
askProceed

# ./operatecntw.sh help
if [ "${MODE}" == "help" ]; then
	printHelp

# ./operatecntw.sh network-up
elif [ "${MODE}" == "network-up" ]; then
	networkUp

# ./operatecntw.sh network-down
elif [ "${MODE}" == "network-down" ]; then
	networkDown

# ./operatecntw.sh generate
elif [ "${MODE}" == "generate" ]; then
	generateCerts
	replacePrivateKey
	generateChannelsArtifacts

# ./operatecntw.sh deliver-network-data -o sipher
elif [ "${MODE}" == "deliver-network-data" ]; then
	# check if organization option tag is provided
	if [ -z "$NEW_ORG" ]; then
		echo "Please provide a organization name with '-o' option tag"
		printHelp
		exit 1
	fi

	deliverNetworkData

# ./operatecntw.sh addorgenv -o sipher
elif [ "${MODE}" == "add-org-env" ]; then

	# check if organization option tag is provided
	if [ -z "$NEW_ORG" ]; then
		echo "Please provide a organization name with '-o' option tag"
		printHelp
		exit 1
	fi

	addOrgEnvironmentData

# ./operatecntw.sh remove-org-env -o sipher
elif [ "${MODE}" == "remove-org-env" ]; then

	# check if organization option tag is provided
	if [ -z "$NEW_ORG" ]; then
		echo "Please provide a organization name with '-o' option tag"
		printHelp
		exit 1
	fi

	removeOrgEnvironmentData

# ./operatecntw.sh add-netenv-remotely -n sipher
elif [ "${MODE}" == "add-netenv-remotely" ]; then

	# check if organization option tag is provided
	if [ -z "$NEW_ORG" ]; then
		echo "Please provide a organization name with '-o' option tag"
		printHelp
		exit 1
	fi

	addNetworkEnvDataRemotely






# ./cerberusntw.sh remove-netenv-remotely -n sipher
elif [ "${MODE}" == "remove-netenv-remotely" ]; then

	# check if organization option tag is provided
	if [ -z "$NEW_ORG" ]; then
		echo "Please provide a organization name with '-n' option tag"
		printHelp
		exit 1
	fi
	
	removeNetworkEnvDataRemotely

# ./cerberusntw.sh add-org-hosts -n sipher
elif [ "${MODE}" == "add-org-hosts" ]; then

	# check if organization option tag is provided
	if [ -z "$NEW_ORG" ]; then
		echo "Please provide a organization name with '-n' option tag"
		printHelp
		exit 1
	fi
	
	addOrgHostsToCerberus

# ./cerberusntw.sh remove-org-hosts -n sipher
elif [ "${MODE}" == "remove-org-hosts" ]; then

	# check if organization option tag is provided
	if [ -z "$NEW_ORG" ]; then
		echo "Please provide a organization name with '-n' option tag"
		printHelp
		exit 1
	fi

	source ~/.profile

	removeOrgHostsFromOs $NEW_ORG
	removeOrgHostsFromNetworkOrg $NEW_ORG

	orgNameVar="${NEW_ORG^^}_ORG_NAME"
	if [ ! -z "${!orgNameVar}" ]; then
		echo "$NEW_ORG environment data is still present. You can remove it by running ./cerberusntw.sh removeorgenv -n $NEW_ORG"
	fi

# ./cerberusntw.sh add-network-hosts-remotely -n sipher
elif [ "${MODE}" == "add-network-hosts-remotely" ]; then

	# check if organization option tag is provided
	if [ -z "$NEW_ORG" ]; then
		echo "Please provide a organization name with '-n' option tag"
		printHelp
		exit 1
	fi

	addNetworkHostsRemotely

# ./cerberusntw.sh remove-network-hosts-remotely -n sipher
elif [ "${MODE}" == "remove-network-hosts-remotely" ]; then

	# check if organization option tag is provided
	if [ -z "$NEW_ORG" ]; then
		echo "Please provide a organization name with '-n' option tag"
		printHelp
		exit 1
	fi

	removeNetworkHostsRemotely










elif [ "${MODE}" == "getorgartifacts" ]; then

	# check if organization option tag is provided
	if [ -z "$NEW_ORG" ]; then
		echo "Please provide a organization name with '-n' option tag"
		printHelp
		exit 1
	fi

	source .env

	orgNameVar="${NEW_ORG^^}_ORG_NAME"
	if [ -z "${!orgNameVar}" ]; then
		echo "$NEW_ORG environment data has not been obtained yet."
		echo "Run ./cerberusntw.sh addorgenv -n $NEW_ORG first."
		exit 1
	fi

	# add environment variables

elif [ "${MODE}" == "test" ]; then

	# check if channel option tag is provided
	#if [ -z "$CHANNELS_LIST" ]; then
	#       echo "Please provide a channels list with '-l' option tag"
	#       exit 1
	#fi

	#parseChannelNames $CHANNELS_LIST

	checkOrgEnvForSsh

elif [ "${MODE}" == "connectorg" ]; then

	# check if channel option tag is provided
	if [ -z "$CHANNELS_LIST" ]; then
		echo "Please provide a list of channels names with '-l' option tag"
		echo "If you want to connect to more than one channel, please provide channel names separated with a comma and without spaces"
		echo "Examples:"
		echo "./cerberusntw.sh connectorg -n <org-name> -l pers"
		echo "./cerberusntw.sh connectorg -n <org-name> -l pers,inst"
		echo "./cerberusntw.sh connectorg -n <org-name> -l pers,inst,int"
		exit 1
	fi

	# check if organization option tag is provided
	if [ -z "$NEW_ORG" ]; then
		echo "Please provide a organization name with '-n' option tag"
		printHelp
		exit 1
	fi

	connectToChannels

elif [ "${MODE}" == "record" ]; then

	. scripts/addToRecords.sh

	addOrgToRecords $NEW_ORG

elif [ "${MODE}" == "restart" ]; then ## Restart the network
	networkDown
	networkUp

elif [ "$MODE" == "disconnectorg" ]; then
	disconnectOrg

 
else
	printHelp
	exit 1
fi


