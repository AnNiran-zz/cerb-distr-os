#!/bin/bash

org=$1
channel=$2

ARCH=$(uname -s | grep Darwin)
if [ "$ARCH" == "Darwin" ]; then
        OPTS="-it"
else
        OPTS="-i"
fi

CURRENT_DIR=$PWD

ORG_CONFIG_FILE=external-orgs/$org-data.json
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
        bash scripts/addOrgEnvData.sh $ORG_CONFIG_FILE
        source .env
fi

# channel artifacts configuration files
channelTx=channel-artifacts/${channel}.tx
genesisBlock=channel-artifacts/genesis.block
orgChannelArtifacts=channel-artifacts/${org}-channel-artifacts.json

errorMessageMissingFile="Re-run channel update and context creation in the peer"

if [ ! -f "$channelTx" ]; then
	echo "ERROR: $channelTx file is missing."
	echo $errorMessageMissingFile
	exit 1
fi

if [ ! -f "$genesisBlock" ]; then
	echo "ERROR: $genesisBlock file is missing."
	echo $errorMessageMissingFile
	exit 1
fi

if [ ! -f "$orgChannelArtifacts" ]; then
	echo "ERROR: $orgChannelArtifacts file is missing."
	echo $errorMessageMissingFile
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

		# check if genesis.block file is present
		sshpass -p "${!containerPasswordVar}" ssh ${!containerUsernameVar}@${!containerHostVar} "test -e ${!containerPathVar}hl/network/${genesisBlock}"
		#sshpass -p "${!containerPasswordVar}" ssh ${!containerUsernameVar}@${!containerHostVar} "cd ${!containerPathVar}hl/network/channel-artifacts && ls -la"

		result0=$?
		echo $result0

		if [ $result0 -ne 0 ]; then
			sshpass -p "${!containerPasswordVar}" scp $genesisBlock ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}hl/network/channel-artifacts
                	copyResult1=$?
                	echo $copyResult1

                	if [ $copyResult1 -ne 0 ]; then
                        	echo "ERROR: Cannot copy $genesisBlock file to $containerHostVar"
                        	exit 1
                	fi
		fi

		sshpass -p "${!containerPasswordVar}" scp $channelTx ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}hl/network/channel-artifacts
                copyResult2=$?
                echo $copyResult2

                if [ $copyResult2 -ne 0 ]; then
                        echo "ERROR: Cannot copy $channelTx file to $containerHostVar"
                        exit 1
                fi

		sshpass -p "${!containerPasswordVar}" scp $orgChannelArtifacts ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}hl/network/channel-artifacts
		copyResult3=$?
		echo $copyResult3

		if [ $copyResult3 -ne 0 ]; then
			echo "ERROR: Cannot copy $orgChannelArtifacts file to $containerHostVar"
			exit 1
		fi
	}
        echo $(_jq '.name')
done

