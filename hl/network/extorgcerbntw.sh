#!/bin/bash

. scripts/addOrgData.sh
. scripts/removeOrgData.sh

function checkOrgEnvForSsh() {

	# read data inside external-orgs folder
 	ARCH=$(uname -s | grep Darwin)
	if [ "$ARCH" == "Darwin" ]; then
		OPTS="-it"
	else
		OPTS="-i"
	fi

	CURRENT_DIR=$PWD

 	ORG_CONFIG_FILE=external-orgs/${NEW_ORG}-data.json
	if [ ! -f "$ORG_CONFIG_FILE" ]; then
		echo
		echo "ERROR: $ORG_CONFIG_FILE file not found. Cannot proceed with parsing new orgation configuration"
		exit 1
	fi

	orgLabelValue=$(jq -r '.label' $ORG_CONFIG_FILE)
 	orgLabelValueStripped=$(echo $orgLabelValue | sed 's/"//g')
	orgLabelVar="${orgLabelValueStripped^^}_ORG_LABEL"

	source .env

	if [ -z "${!orgLabelVar}" ]; then
		echo "Required network environment data is not present. Obtaining ... "
		addOrgEnvData $NEW_ORG
		exit 0
	fi

	source .env
}

function deliverNetworkData() {

	orgDataFile="external-orgs/${NEW_ORG}-data.json"
	if [ ! -f "$orgDataFile" ]; then
		echo
		echo "ERROR: external-orgs/$NEW_ORG-data.json file not found. Cannot proceed with obtaining organization data."
		exit 1
	fi

	source .env

	# add environment variables
	addEnvironmentData $NEW_ORG

	osDataFile="network-config/os-data.json"
	if [ ! -f "$osDataFile" ]; then
		echo
		echo "ERROR: network-config/os-data.json file not found. Cannot proceed with copying network data to organization host"
 		exit 1
	fi

	cerberusOrgDataFile="network-config/cerberusorg-data.json"
	if [ ! -f "$cerberusOrgDataFile" ]; then
		echo
		echo "ERROR: network-config/cerberusorg-data.json file not found. Cannot proceed with copying network data to organization host"
		exit 1
	fi

	# copy files to organization host
	which sshpass
	if [ "$?" -ne 0 ]; then
		echo "sshpass tool not found"
		exit 1
	fi

	orgUsername="${NEW_ORG^^}_ORG_USERNAME"
	orgPassword="${NEW_ORG^^}_ORG_PASSWORD"
	orgHost="${NEW_ORG^^}_ORG_IP"
	orgPath="${NEW_ORG^^}_ORG_HOSTPATH"
	orgName="${NEW_ORG^^}_ORG_NAME"

	sshpass -p "${!orgPassword}" scp $osDataFile ${!orgUsername}@${!orgHost}:${!orgPath}/hl/network/network-config
	sshpass -p "${!orgPassword}" scp $cerberusOrgDataFile ${!orgUsername}@${!orgHost}:${!orgPath}/hl/network/network-config

	if [ "$?" -ne 0 ]; then
		echo "ERROR: Cannot copy data files to ${!orgName} remote host."
 		exit 1
	fi

	echo "Cerberus Network data files copied to ${!orgName} remote host successfully."
}

function addNetworkEnvDataRemotely() {
         
	# check if organization environment variables are set
	orgUsernameVar="${NEW_ORG^^}_ORG_USERNAME"
	orgPasswordVar="${NEW_ORG^^}_ORG_PASSWORD"
	orgHostVar="${NEW_ORG^^}_ORG_IP"
	orgHostPathVar="${NEW_ORG^^}_ORG_HOSTPATH"

	source .env

	if [ -z "${!orgUsernameVar}" ] || [ -z "${!orgPasswordVar}" ] || [ -z "${!orgHostVar}" ] || [ -z "${!orgHostPathVar}" ]; then
		echo "Required organization environment data is not present. Obtaining ... "
    
		addEnvironmentData $NEW_ORG
	fi      

	source .env

	# set network data remotely
	which sshpass 
	if [ "$?" -ne 0 ]; then
		echo "sshpass tool not found"
		exit 1	
	fi      

	sshpass -p "${!orgPasswordVar}" ssh ${!orgUsernameVar}@${!orgHostVar} "cd ${!orgHostPathVar}/hl/network && ./sipher.sh add-network-env"
 	if [ "$?" -ne 0 ]; then
		echo "Cerberus network environment data is not added to ${NEW_ORG^} host."
		exit 1
	fi      

	echo "Cerberus network environment data successfully added to ${NEW_ORG^} host"
}
 
function removeNetworkEnvDataRemotely() {

	# check if organization environment variables are set
	orgUsernameVar="${NEW_ORG^^}_ORG_USERNAME"
	orgPasswordVar="${NEW_ORG^^}_ORG_PASSWORD"
	orgHostVar="${NEW_ORG^^}_ORG_IP"
	orgHostPathVar="${NEW_ORG^^}_ORG_HOSTPATH"

	source .env

	if [ -z "${!orgUsernameVar}" ] || [ -z "${!orgPasswordVar}" ] || [ -z "${!orgHostVar}" ] || [ -z "${!orgHostPathVar}" ]; then
		echo "Required organization environment data is not present. Obtaining ... "

		addEnvironmentData $NEW_ORG
	fi      

	source .env
	
	# remove network data remotely
	which sshpass 
	if [ "$?" -ne 0 ]; then
		echo "sshpass tool not found"
		exit 1
	fi      

	sshpass -p "${!orgPasswordVar}" ssh ${!orgUsernameVar}@${!orgHostVar} "cd ${!orgHostPathVar}/hl/network && ./${NEW_ORG}.sh remove-network-env"
	if [ "$?" -ne 0 ]; then
		echo "Cerberus network environment data is not removed from ${NEW_ORG^} host"
		exit 1
	fi      

	echo "Cerberus network environment data successfully removed from ${NEW_ORG^} hosts"
}

function addOrgHostsToCerberus() {

	source ~/.profile
	source .env

	orgHostVar="${NEW_ORG^^}_ORG_IP"

	if [ -z "${!orgHostVar}" ]; then
		echo "Required organization environment data is not present. Obtaining ... "

		addEnvironmentData $NEW_ORG
	fi

	source .env

	addExtraHostsToOs $NEW_ORG
	addExtraHostsToNetworkOrg $NEW_ORG

	orgNameVar="${NEW_ORG^^}_ORG_NAME"
	echo "Organization ${!orgNameVar} extra hosts added successfully to Cerberusntw network configuration files"
}

function addNetworkHostsRemotely() {

	# check if organization environment variables are set
	orgUsernameVar="${NEW_ORG^^}_ORG_USERNAME"
	orgPasswordVar="${NEW_ORG^^}_ORG_PASSWORD"
	orgHostVar="${NEW_ORG^^}_ORG_IP"
	orgHostPathVar="${NEW_ORG^^}_ORG_HOSTPATH"

	source .env

	if [ -z "${!orgUsernameVar}" ] || [ -z "${!orgPasswordVar}" ] || [ -z "${!orgHostVar}" ] || [ -z "${!orgHostPathVar}" ]; then
		echo "Required organization environment data is not present. Obtaining ... "

		addEnvironmentData $NEW_ORG
	fi

	source .env

	# add network data remotely
	which sshpass
	if [ "$?" -ne 0 ]; then
		echo "sshpass tool not found"
		exit 1
	fi

	sshpass -p "${!orgPasswordVar}" ssh ${!orgUsernameVar}@${!orgHostVar} "cd ${!orgHostPathVar}/hl/network && ./${NEW_ORG}.sh add-network-hosts"
	if [ "$?" -ne 0 ]; then
		echo "ERROR: Unable to add network hosts to organization remotely"
		exit 1
	fi

	echo "Cerberus hosts successfully added to remote organization hosts"
}

function removeNetworkHostsRemotely() {

	# check if organization environment variables are set
	orgUsernameVar="${NEW_ORG^^}_ORG_USERNAME"
	orgPasswordVar="${NEW_ORG^^}_ORG_PASSWORD"
	orgHostVar="${NEW_ORG^^}_ORG_IP"
	orgHostPathVar="${NEW_ORG^^}_ORG_HOSTPATH"

	source .env

	if [ -z "${!orgUsernameVar}" ] || [ -z "${!orgPasswordVar}" ] || [ -z "${!orgHostVar}" ] || [ -z "${!orgHostPathVar}" ]; then
		echo "Required organization environment data is not present. Obtaining ... "
    
		addEnvironmentData $NEW_ORG
	fi      

	source .env

	# remove network data remotely
	which sshpass
	if [ "$?" -ne 0 ]; then
		echo "sshpass tool not found"   
		exit 1
	fi      

	sshpass -p "${!orgPasswordVar}" ssh ${!orgUsernameVar}@${!orgHostVar} "cd ${!orgHostPathVar}/hl/network && ./${NEW_ORG}.sh remove-network-hosts"
	if [ "$?" -ne 0 ]; then
		echo "ERROR: Unable to add network hosts to organization remotely"
		exit 1
	fi      

	echo "Cerberus hosts successfully removed from remote organization hosts"

	# check if network env variables are set on remote machine
	getVal=$(sshpass -p "${!orgPasswordVar}" ssh ${!orgUsernameVar}@${!orgHostVar} "cd ${!orgHostPathVar}/hl/network/scripts && ./testEnvVar.sh CERBERUS_OS_IP")

	if [ "${getVal}" != "not set" ]; then
		orgNameVar="${NEW_ORG^^}_ORG_NAME"
    
		echo
		echo "========="
		echo "NOTE:"
		echo "Cerberus network environment variables are still set on ${!orgNameVar} host machine."
		echo "You can remove them remotely by calling \" ./cerberusntw.sh remove-netenv-remotely -n ${NEW_ORG}\""
	fi      
}

function deliverOrgArtifacts() {
         
	which sshpass
	if [ "$?" -ne 0 ]; then
		echo "sshpass tool not found"
		exit 1
	fi      
    
	orgUsername="${NEW_ORG^^}_ORG_USERNAME"
	artifactsLocation=/home/${!orgUsername}/server/go/src/cerberus
}       

function parseChannelNames() {

	namesList=$1

	channels=$(echo $namesList | tr "," "\n")

	for channel in $channels; do
		if [ "$channel" != "person" ] && [ "$channel" != "institution" ] && [ "$channel" != "integration" ]; then
			echo "Channel name: $channel unknown"
			exit 1
		fi
	done

}

function connectToChannels() {

	channels=$(echo $CHANNELS_LIST | tr "," "\n")

	for channel in $channels; do
		if [ "$channel" == "pers" ]; then
			echo "Connecting ${NEW_ORG^} to Cerberus Network channel: Person Accounts"
			docker exec cli.cerberusorg.cerberus.net scripts/addOrgToPersonAccChannel.sh $NEW_ORG $PERSON_ACCOUNTS_CHANNEL

			if [ $? -ne 0 ]; then
				echo "Unable to create config tx for ${PERSON_ACCOUNTS_CHANNEL}"
				exit 1
			fi

		 elif [ "$channel" == "inst" ]; then
			echo "Connecting ${NEW_ORG^} to Cerberus Network channel: Institution Accounts"
			docker exec cli.cerberusorg.cerberus.net scripts/addOrgToInstitutionAccChannel.sh $NEW_ORG $INSTITUTION_ACCOUNTS_CHANNEL

			if [ $? -ne 0 ]; then
				echo "Unable to create config tx for ${INSTITUTION_ACCOUNTS_CHANNEL}"
				exit 1
			fi

		elif [ "$channel" == "int" ]; then
			echo "Connecting ${NEW_ORG^} to Cerberus Network channel: Integration Accounts"
			docker exec cli.cerberusorg.cerberus.net scripts/addOrgToIntegrationAccChannel.sh $NEW_ORG $INTEGRATION_ACCOUNTS_CHANNEL

			if [ $? -ne 0 ]; then
				echo "Unable to create config tx for ${INTEGRATION_ACCOUNTS_CHANNEL}"
				exit 1
			fi
		else
			echo "Channel name: $channel unknown"
			exit 1
		fi
	done
}

function disconnectOrg() {

	. scripts/disconnectOrg.sh

	removeExternalOrgArtifacts $NEW_ORG
}

function parseYaml {
	local prefix=$2
	local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
	sed -ne "s|^\($s\):|\1|" \
		-e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
		-e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
	
	awk -F$fs '{
		indent = length($1)/2;
		vname[indent] = $2;
		for (i in vname) {if (i > indent) {delete vname[i]}}
		if (length($3) > 0) {
			vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
			printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
		}
	}'
}



