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
configJson=channel-artifacts/${channel}-config.json
configPb=channel-artifacts/${channel}-config.pb
channelTx=channel-artifacts/${channel}.tx
channelConfigBlock=channel-artifacts/${channel}_config_block.pb

modifiedConfigJson=channel-artifacts/modified_${channel}-config.json
modifiedConfigPb=channel-artifacts/modified_${channel}-config.pb

orgChannelUpdateJson=channel-artifacts/${org}-${channel}_update.json
orgChannelUpdatePb=channel-artifacts/${org}-${channel}_update.pb
orgChannelUpdateInEnvelopeJson=channel-artifacts/${org}-${channel}_update_in_envelope.json
orgChannelUpdateInEnvelopePb=channel-artifacts/${org}-${channel}_update_in_envelope.pb

errorMessageMissingFile="Re-run channel update and context creation in the peer"

if [ ! -f "$configJson" ]; then
	echo "ERROR: $configJson file is missing."
	echo $errorMessageMissingFile
	exit 1
fi

if [ ! -f "$configPb" ]; then
	echo "ERROR: $configPb file is missing."
	echo $errorMessageMissingFile
	exit 1
fi

if [ ! -f "$channelTx" ]; then
	echo "ERROR: $channelTx file is missing."
	echo $errorMessageMissingFile
	exit 1
fi

if [ ! -f "$channelConfigBlock" ]; then
	echo "ERROR: $channelConfigBlock file is missing."
	echo $errorMessageMissingFile
	exit 1
fi

if [ ! -f "$modifiedConfigJson" ]; then
	echo "ERROR: $modifiedConfigJson file is missing."
	echo $errorMessageMissingFile
 	exit 1
fi

if [ ! -f "$modifiedConfigPb" ]; then
	echo "ERROR: $modifiedConfigPb file is missing."
	echo $errorMessageMissingFile
	exit 1
fi	

if [ ! -f "$orgChannelUpdatePb" ]; then
	echo "ERROR: $orgChannelUpdatePb file is missing."
	echo $errorMessageMissingFile
	exit 1
fi

if [ ! -f "$orgChannelUpdateJson" ]; then
	echo "ERROR: $orgChannelUpdateJson file is missing."
	echo $errorMessageMissingFile
	exit 1
fi

if [ ! -f "$orgChannelUpdateInEnvelopeJson" ]; then
	echo "ERROR: $orgChannelUpdateInEnvelopeJson is missing."
	echo $errorMessageMissingFile
	exit 1
fi	

if [ ! -f "$orgChannelUpdateInEnvelopePb" ]; then
	echo "ERROR: $orgChannelUpdateInEnvelopePb is missing."
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

		sshpass -p "${!containerPasswordVar}" scp channel-artifacts/${org}-channel-artifacts.json ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}hl/network/channel-artifacts
                copyResult0=$?
                echo $copyResult0

                if [ $copyResult0 -ne 0 ]; then
                        echo "ERROR: Cannot copy channel-artifacts/$org-channel-artifacts.json file to $containerHostVar"
                        exit 1
                fi

		# deliver all files to host
		sshpass -p "${!containerPasswordVar}" scp $configJson ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}hl/network/channel-artifacts
		copyResult1=$?
		echo $copyResult1

		if [ $copyResult1 -ne 0 ]; then
			echo "ERROR: Cannot copy $configJson file to $containerHostVar"
			exit 1
		fi

		sshpass -p "${!containerPasswordVar}" scp $configPb ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}hl/network/channel-artifacts
                copyResult2=$?
                echo $copyResult2

                if [ $copyResult2 -ne 0 ]; then 
                        echo "ERROR: Cannot copy $configPb file to $containerHostVar"
                        exit 1
                fi

		sshpass -p "${!containerPasswordVar}" scp $channelTx ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}hl/network/channel-artifacts
                copyResult3=$?
                echo $copyResult3

                if [ $copyResult3 -ne 0 ]; then
                        echo "ERROR: Cannot copy $channelTx file to $containerHostVar"
                        exit 1
                fi

		sshpass -p "${!containerPasswordVar}" scp $channelConfigBlock ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}hl/network/channel-artifacts
                copyResult4=$?
                echo $copyResult4

                if [ $copyResult4 -ne 0 ]; then 
                        echo "ERROR: Cannot copy $channelConfigBlock file to $containerHostVar"
                        exit 1
                fi

		sshpass -p "${!containerPasswordVar}" scp $modifiedConfigJson ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}hl/network/channel-artifacts
                copyResult5=$?
                echo $copyResult5

                if [ $copyResult5 -ne 0 ]; then 
                        echo "ERROR: Cannot copy $modifiedConfigJson file to $containerHostVar"
                        exit 1
                fi

		sshpass -p "${!containerPasswordVar}" scp $modifiedConfigPb ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}hl/network/channel-artifacts
                copyResult6=$?
                echo $copyResult6

                if [ $copyResult6 -ne 0 ]; then
                        echo "ERROR: Cannot copy $modifiedConfigPb file to $containerHostVar"
                        exit 1
                fi

		sshpass -p "${!containerPasswordVar}" scp $orgChannelUpdatePb ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}hl/network/channel-artifacts
                copyResult7=$?
                echo $copyResult7

                if [ $copyResult7 -ne 0 ]; then
                        echo "ERROR: Cannot copy $orgChannelUpdatePb file to $containerHostVar"
                        exit 1
                fi

		sshpass -p "${!containerPasswordVar}" scp $orgChannelUpdateJson ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}hl/network/channel-artifacts
                copyResult8=$?
                echo $copyResult8

                if [ $copyResult8 -ne 0 ]; then
                        echo "ERROR: Cannot copy $orgChannelUpdateJson file to $containerHostVar"
                        exit 1
                fi

		sshpass -p "${!containerPasswordVar}" scp $orgChannelUpdateInEnvelopeJson ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}hl/network/channel-artifacts
                copyResult8=$?
                echo $copyResult8

                if [ $copyResult8 -ne 0 ]; then
                        echo "ERROR: Cannot copy $orgChannelUpdateInEnvelopeJson file to $containerHostVar"
                        exit 1
                fi

		sshpass -p "${!containerPasswordVar}" scp $orgChannelUpdateInEnvelopePb ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}hl/network/channel-artifacts
                copyResult9=$?
                echo $copyResult9

                if [ $copyResult9 -ne 0 ]; then
                        echo "ERROR: Cannot copy $orgChannelUpdateInEnvelopePb file to $containerHostVar"
                        exit 1
                fi


	}
        echo $(_jq '.name')
done

