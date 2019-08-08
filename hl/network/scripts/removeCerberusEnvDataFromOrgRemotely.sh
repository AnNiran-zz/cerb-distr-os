#!/bin/bash
ORG_CONFIG_FILE=$1

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

                # start remote script
                sshpass -p "${!containerPasswordVar}" ssh ${!containerUsernameVar}@${!containerHostVar} "cd ${!containerPathVar}hl/network && bash scripts/removeCerberusEnvData.sh"
                        result=$?
                        echo $result

                        if [ $result -ne 0 ]; then
                                echo "ERROR: Cerberus network data is not removed from ${containerNameValue} host machine"
                                exit 1
                        fi

                        echo
                        echo "Cerberus network environment data has been successfully removed from ${containerNameValue} host machine"


        }
	echo $(_jq '.name')
done

