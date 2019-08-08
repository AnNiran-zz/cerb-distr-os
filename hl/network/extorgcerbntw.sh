#!/bin/bash

function removeNetworkHostsRemotely() {

	# check if organization environment variables are set
	orgUsernameVar="${ORG^^}_ORG_USERNAME"
	orgPasswordVar="${ORG^^}_ORG_PASSWORD"
	orgHostVar="${ORG^^}_ORG_IP"
	orgHostPathVar="${ORG^^}_ORG_HOSTPATH"

	source .env

	if [ -z "${!orgUsernameVar}" ] || [ -z "${!orgPasswordVar}" ] || [ -z "${!orgHostVar}" ] || [ -z "${!orgHostPathVar}" ]; then
		echo "Required organization environment data is not present. Obtaining ... "
    
		addEnvironmentData $ORG
	fi      

	source .env

	# remove network data remotely
	which sshpass
	if [ "$?" -ne 0 ]; then
		echo "sshpass tool not found"   
		exit 1
	fi      

	sshpass -p "${!orgPasswordVar}" ssh ${!orgUsernameVar}@${!orgHostVar} "cd ${!orgHostPathVar}/hl/network && ./${ORG}.sh remove-network-hosts"
	if [ "$?" -ne 0 ]; then
		echo "ERROR: Unable to add network hosts to organization remotely"
		exit 1
	fi      

	echo "Cerberus hosts successfully removed from remote organization hosts"

	# check if network env variables are set on remote machine
	getVal=$(sshpass -p "${!orgPasswordVar}" ssh ${!orgUsernameVar}@${!orgHostVar} "cd ${!orgHostPathVar}/hl/network/scripts && ./testEnvVar.sh CERBERUS_OS_IP")

	if [ "${getVal}" != "not set" ]; then
		orgNameVar="${ORG^^}_ORG_NAME"
    
		echo
		echo "========="
		echo "NOTE:"
		echo "Cerberus network environment variables are still set on ${!orgNameVar} host machine."
		echo "You can remove them remotely by calling \" ./cerberusntw.sh remove-netenv-remotely -n ${ORG}\""
	fi      
}

function deliverOrgArtifacts() {
         
	which sshpass
	if [ "$?" -ne 0 ]; then
		echo "sshpass tool not found"
		exit 1
	fi      
    
	orgUsername="${ORG^^}_ORG_USERNAME"
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
			echo "Connecting ${ORG^} to Cerberus Network channel: Person Accounts"
			docker exec cli.cerberusorg.cerberus.net scripts/addOrgToPersonAccChannel.sh $ORG $PERSON_ACCOUNTS_CHANNEL

			if [ $? -ne 0 ]; then
				echo "Unable to create config tx for ${PERSON_ACCOUNTS_CHANNEL}"
				exit 1
			fi

		 elif [ "$channel" == "inst" ]; then
			echo "Connecting ${ORG^} to Cerberus Network channel: Institution Accounts"
			docker exec cli.cerberusorg.cerberus.net scripts/addOrgToInstitutionAccChannel.sh $ORG $INSTITUTION_ACCOUNTS_CHANNEL

			if [ $? -ne 0 ]; then
				echo "Unable to create config tx for ${INSTITUTION_ACCOUNTS_CHANNEL}"
				exit 1
			fi

		elif [ "$channel" == "int" ]; then
			echo "Connecting ${ORG^} to Cerberus Network channel: Integration Accounts"
			docker exec cli.cerberusorg.cerberus.net scripts/addOrgToIntegrationAccChannel.sh $ORG $INTEGRATION_ACCOUNTS_CHANNEL

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

	removeExternalOrgArtifacts $ORG
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



