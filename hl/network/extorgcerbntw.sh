#!/bin/bash

. scripts/addOrgData.sh
. scripts/removeOrgData.sh

function checkOrgEnvironmentData() {

	# read data inside external-orgs folder
	ARCH=$(uname -s | grep Darwin)
	if [ "$ARCH" == "Darwin" ]; then
		OPTS="-it"
	else
		OPTS="-i"
	fi

	CURRENT_DIR=$PWD

	ORG_CONFIG_FILE=external-orgs/${ORG}-data.json
	if [ ! -f "$ORG_CONFIG_FILE" ]; then
		echo
		echo "ERROR: $ORG_CONFIG_FILE file not found. Cannot proceed with parsing new organization configuration"
		exit 1
	fi

	source .env

	# check if environment variables for organization are set
	orgLabelValue=$(jq -r '.label' $ORG_CONFIG_FILE)
	orgLabelValueStripped=$(echo $orgLabelValue | sed 's/"//g')
	orgLabelVar="${orgLabelValueStripped^^}_ORG_LABEL"

	if [ -z "${!orgLabelVar}" ]; then
		echo "Required organization environment data is missing. Obtaining ... "
		addOrgEnvironmentData
		source .env
	fi
}

# deliver cerberus network organization and ordering service data to external organization remote hosts
function deliverNetworkData() {

	# check if organization environment variables are present
	addOrgEnvironmentData

	source .env

	echo
	echo

	osDataFile="network-config/os-data.json"
	if [ ! -f "$osDataFile" ]; then
		echo
		echo "ERROR: ${osDataFile} file not found. Cannot proceed with copying network data to organization host"
 		exit 1
	fi

	cerberusOrgDataFile="network-config/cerberusorg-data.json"
	if [ ! -f "$cerberusOrgDataFile" ]; then
		echo
		echo "ERROR: ${cerberusOrgDataFile} file not found. Cannot proceed with copying network data to organization host"
		exit 1
	fi

	# copy files to organization host
	which sshpass
	if [ "$?" -ne 0 ]; then
		echo "sshpass tool not found"
		exit 1
	fi

	# deliver files to all host machines
	ORG_CONFIG_FILE=external-orgs/${ORG}-data.json
	if [ ! -f "$ORG_CONFIG_FILE" ]; then
		echo
		echo "ERROR: $ORG_CONFIG_FILE file not found. Cannot proceed with parsing organization data and delivering to host machines"
		exit 1
	fi

	orgLabelValue=$(jq -r '.label' $ORG_CONFIG_FILE)
	orgLabelValueStripped=$(echo $orgLabelValue | sed 's/"//g')

	orgContainers=$(jq -r '.containers[]' $ORG_CONFIG_FILE)

	# deliver network data files to each host
	for orgContainer in $(echo "${orgContainers}" | jq -r '. | @base64'); do
		_jq(){
			containerNameValue=$(echo "\"$(echo ${orgContainer} | base64 --decode | jq -r ${1})\"")
			containerNameValueStripped=$(echo $containerNameValue | sed 's/"//g')
			
			containerHostVar="${orgLabelValueStripped^^}_ORG_${containerNameValueStripped^^}_HOST"
			containerUsernameVar="${orgLabelValueStripped^^}_ORG_${containerNameValueStripped^^}_USERNAME"
			containerPasswordVar="${orgLabelValueStripped^^}_ORG_${containerNameValueStripped^^}_PASSWORD"
			containerPathVar="${orgLabelValueStripped^^}_ORG_${containerNameValueStripped^^}_PATH"
			
			# check if file is present on the remote host and deliver it if it is not
			sshpass -p "${!containerPasswordVar}" ssh ${!containerUsernameVar}@${!containerHostVar} "test -e ${!containerPathVar}hl/network/${osDataFile}"
			result=$?
			echo $result
			
			if [ $result -ne 0 ]; then
				sshpass -p "${!containerPasswordVar}" scp $osDataFile ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}hl/network/network-config

				if [ "$?" -ne 0 ]; then
					echo "ERROR: Cannot copy ${osDataFile} to ${!containerHostVar} remote host"
					exit 1
				fi

				echo
				echo "$osDataFile copied to $containerHostVar"
				echo
			else
				echo
				echo "$osDataFile is already present on $containerHostVar"
				echo
			fi

			sshpass -p "${!containerPasswordVar}" ssh ${!containerUsernameVar}@${!containerHostVar} "test -e ${!containerPathVar}hl/network/${cerberusOrgDataFile}"
			result=$?
			echo $result

			if [ $result -ne 0 ]; then
				sshpass -p "${!containerPasswordVar}" scp $cerberusOrgDataFile ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}hl/network/network-config

				if [ "$?" -ne 0 ]; then
					echo "ERROR: Cannot copy ${osDataFile} to ${!containerHostVar} remote host"
					exit 1
				fi

				echo
				echo "$cerberusOrgDataFile copied to $containerHostVar"
				echo
			else
				echo
				echo "$cerberusOrgDataFile is already present on $containerHostVar"
				echo
			fi

			# list external organizations files
			for file in external-orgs/*-data.json; do
				if grep -q "${ORG}" "$file"; then
					continue
				else
					# copy external organization data file to remote host
					sshpass -p "${!containerPasswordVar}" ssh ${!containerUsernameVar}@${!containerHostVar} "test  -e ${!containerPathVar}hl/network/${file}"
					result=$?
					echo $result

					if [ $result -ne 0 ]; then
						sshpass -p "${!containerPasswordVar}" scp $file ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}/hl/network/external-orgs

						if [ "$?" -ne 0 ]; then
							echo "ERROR: Cannot copy ${file} to ${!containerHostVar} remote host"
							exit 1
						fi

						echo
						echo "$file copied to $containerHostVar"
						echo
					else
						echo
						echo "$file is already present on $containerHostVar"
						echo
					fi
				fi
			done
		}
		echo $(_jq '.name')
	done
}


function addExternalOrgExtraHosts() {
	
	# read data inside external-orgs folder
	ARCH=$(uname -s | grep Darwin)
	if [ "$ARCH" == "Darwin" ]; then
		OPTS="-it"
	else
		OPTS="-i"
	fi

	CURRENT_DIR=$PWD

	checkOrgEnvironmentData
	ORG_CONFIG_FILE=external-orgs/${ORG}-data.json

	addExtraHostsToOs $ORG_CONFIG_FILE
	addExtraHostsToNetworkOrg $ORG_CONFIG_FILE

}

function addNetworkEnvDataRemotely() {
         
	# check if organization environment variables are set
	addOrgEnvironmentData

	echo
	echo

	osDataFile="network-config/os-data.json"
	cerberusOrgDataFile="network-config/cerberusorg-data.json"

	# check if organization data file is present
	ORG_CONFIG_FILE=external-orgs/${ORG}-data.json
	if [ ! -f "$ORG_CONFIG_FILE" ]; then
		echo
		echo "ERROR: $ORG_CONFIG_FILE file not found. Cannot proceed with parsing organization data and delivering to host machines"
		exit 1
	fi

	orgLabelValue=$(jq -r '.label' $ORG_CONFIG_FILE)
	orgLabelValueStripped=$(echo $orgLabelValue | sed 's/"//g')

	orgContainers=$(jq -r '.containers[]' $ORG_CONFIG_FILE)

	which sshpass
	if [ "$?" -ne 0 ]; then
		echo "sshpass tool not found"
		exit 1
	fi
	
	# add environment data to each host
	for container in $(echo "${orgContainers}" | jq -r '. | @base64'); do
		_jq(){
			echo "here I am"
			containerNameValue=$(echo "\"$(echo ${orgContainer} | base64 --decode | jq -r ${1})\"")
			containerNameValueStripped=$(echo $containerNameValue | sed 's/"//g')

			containerHostVar="${orgLabelValueStripped^^}_ORG_${containerNameValueStripped^^}_HOST"
			containerUsernameVar="${orgLabelValueStripped^^}_ORG_${containerNameValueStripped^^}_USERNAME"
			containerPasswordVar="${orgLabelValueStripped^^}_ORG_${containerNameValueStripped^^}_PASSWORD"
			containerPathVar="${orgLabelValueStripped^^}_ORG_${containerNameValueStripped^^}_PATH"

			# check if file is present on the remote host and deliver it if it is not
			sshpass -p "${!containerPasswordVar}" ssh ${!containerUsernameVar}@${!containerHostVar} "test -e ${!containerPathVar}hl/network/${osDataFile}"
			result=$?
			echo $result

			if [ $result -ne 0 ]; then
				sshpass -p "${!containerPasswordVar}" scp $osDataFile ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}hl/network/network-config

				if [ "$?" -ne 0 ]; then
					echo "ERROR: Cannot copy ${osDataFile} to ${!containerHostVar} remote host"
					exit1
				fi

				echo
				echo "$osDataFile copied to $containerHostVar"
				echo
			fi

			sshpass -p "${!containerPasswordVar}" ssh ${!containerUsernameVar}@${!containerHostVar} "test -e ${!containerPathVar}hl/network/${cerberusOrgDataFile}"
			result=$?
			echo $result

			if [ $result -ne 0 ]; then
				sshpass -p "${!containerPasswordVar}" scp $cerberusOrgDataFile ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}hl/network/network-config

				if [ "$?" -ne 0 ]; then
					echo "ERROR: Cannot copy ${osDataFile} to ${!containerHostVar} remote host"
					exit 1
				fi

				echo
				echo "$cerberusOrgDataFile copied to $containerHostVar"
				echo
			fi

			# start remote script
			sshpass -p "${!containerPasswordVar}" ssh ${!containerUsernameVar}@${!containerHostVar} "cd ${!containerPathVar}hl/network && ./${ORG}.sh add-network-env"
			result=$?
			echo $result

			if [ $result -ne 0 ]; then
				echo "ERROR: Cerberus network data is not added to ${containerNameValue} host machine"
				exit 1
			fi

			echo
			echo "Cerberus network environment data has been successfully added to ${containerNameValue} host machine"

		}
		echo $(_jq '.name')
	done
}
 
function removeNetworkEnvDataRemotely() {

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

	sshpass -p "${!orgPasswordVar}" ssh ${!orgUsernameVar}@${!orgHostVar} "cd ${!orgHostPathVar}/hl/network && ./${ORG}.sh remove-network-env"
	if [ "$?" -ne 0 ]; then
		echo "Cerberus network environment data is not removed from ${ORG^} host"
		exit 1
	fi      

	echo "Cerberus network environment data successfully removed from ${ORG^} hosts"
}

function addOrgHostsToCerberus() {

	source ~/.profile
	source .env

	orgHostVar="${ORG^^}_ORG_IP"

	if [ -z "${!orgHostVar}" ]; then
		echo "Required organization environment data is not present. Obtaining ... "

		addEnvironmentData $ORG
	fi

	source .env

	addExtraHostsToOs $ORG
	addExtraHostsToNetworkOrg $ORG

	orgNameVar="${ORG^^}_ORG_NAME"
	echo "Organization ${!orgNameVar} extra hosts added successfully to Cerberusntw network configuration files"
}

function addNetworkHostsRemotely() {

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

	# add network data remotely
	which sshpass
	if [ "$?" -ne 0 ]; then
		echo "sshpass tool not found"
		exit 1
	fi

	sshpass -p "${!orgPasswordVar}" ssh ${!orgUsernameVar}@${!orgHostVar} "cd ${!orgHostPathVar}/hl/network && ./${ORG}.sh add-network-hosts"
	if [ "$?" -ne 0 ]; then
		echo "ERROR: Unable to add network hosts to organization remotely"
		exit 1
	fi

	echo "Cerberus hosts successfully added to remote organization hosts"
}

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



