#!/bin/bash

ARCH=$(uname -s | grep Darwin)
if [ "$ARCH" == "Darwin" ]; then
	OPTS="-it"
else
	OPTS="-i"
fi

CURRENT_DIR=$PWD

ORG_CONFIG_FILE=$1
if [ ! -f "$ORG_CONFIG_FILE" ]; then
	echo
	echo "ERROR: $ORG_CONFIG_FILE file not found. Cannot proceed with parsing new organization configuration"
	exit 1
fi

source .env
source ~/.profile

# check if organization environment variables are present
orgLabelValue=$(jq -r '.label' $ORG_CONFIG_FILE)
result=$?

if [ $result -ne 0 ]; then
        echo "ERROR: File format for $ORG_CONFIG_FILE does no match expected"
        exit 1
fi

orgLabelValueStripped=$(echo $orgLabelValue | sed 's/"//g')
orgLabelVar="${orgLabelValueStripped^^}_ORG_LABEL"

if [ -z "${!orgLabelVar}" ]; then
	echo "Required organization environment data is missing. Obtaining ... "
	bash scripts/addOrgEnvData.sh $orgLabelValue
	source .env
fi

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

orgContainers=$(jq -r '.containers[]' $ORG_CONFIG_FILE)
result=$?

if [ $result -ne 0 ]; then
        echo "ERROR: File format for $ORG_CONFIG_FILE does no match expected"
        exit 1
fi

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
			if grep -q "${orgLabelValue}" "$file"; then
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


