#!/bin/bash
ORG_CONFIG_FILE=$1
dataType=$2

if [ "${dataType}" != "env" ] && [ "${dataType}" != "extrahosts" ]; then
	echo "Unknown data type request"
	echo $dataType
	exit 1
fi

ARCH=$(uname -s | grep Darwin)
if [ "$ARCH" == "Darwin" ]; then
        OPTS="-it"
else
        OPTS="-i"
fi

CURRENT_DIR=$PWD

if [ ! -f "$ORG_CONFIG_FILE" ]; then
        echo
        echo "ERROR: $ORG_CONFIG_FILE file not found. Cannot proceed with parsing new organization configuration"
        exit 1
fi

source .env
source ~/.profile

# check if environment variables for organization are set
orgLabelValue=$(jq -r '.label' $ORG_CONFIG_FILE)
result=$?

if [ "$result" -ne 0 ]; then
        echo "ERROR: Format for $ORG_CONFIG_FILE does not match expected"
        exit 1
fi

orgLabelValueStripped=$(echo $orgLabelValue | sed 's/"//g')
orgLabelVar="${orgLabelValueStripped^^}_ORG_LABEL"

if [ -z "${!orgLabelVar}" ]; then
        echo "Required organization environment data is missing. Obtaining ... "
        bash scripts/addOrgEnvData.sh $ORG_CONFIG_FILE
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

orgContainers=$(jq -r '.containers[]' $ORG_CONFIG_FILE)

which sshpass
if [ "$?" -ne 0 ]; then
	echo "sshpass tool not found"
	exit 1
fi

# add environment data to each host
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

		# start remote script
		if [ "${dataType}" == "env" ]; then
			sshpass -p "${!containerPasswordVar}" ssh ${!containerUsernameVar}@${!containerHostVar} "cd ${!containerPathVar}hl/network && bash scripts/addCerberusEnvData.sh"
			result=$?
	                echo $result

                	if [ $result -ne 0 ]; then
                        	echo "ERROR: Cerberus network data is not added to ${containerNameValue} host machine"
                        	exit 1
                	fi

                	echo
                	echo "Cerberus network environment data has been successfully added to ${containerNameValue} host machine"

		elif [ "${dataType}" == "extrahosts" ]; then
			sshpass -p "${!containerPasswordVar}" ssh ${!containerUsernameVar}@${!containerHostVar} "cd ${!containerPathVar}hl/network && bash scripts/addCerberusExtraHosts.sh"
			result=$?
                        echo $result

                        if [ $result -ne 0 ]; then
                                echo "ERROR: Cerberus network extra hosts data is not added to ${containerNameValue} host machine"
                                exit 1
                        fi

                        echo
                        echo "Cerberus network extra hosts data has been successfully added to ${containerNameValue} host machine"
		else
			echo "Unknown data type request"
			exit 1
		fi

	}
	echo $(_jq '.name')
done
