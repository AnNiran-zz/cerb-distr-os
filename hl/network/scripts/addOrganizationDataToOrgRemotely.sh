#!/bin/bash
DESTINATION_ORG_CONFIG_FILE=$1
DELIVERY_ORG_CONFIG_FILE=$2
dataType=$3

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

if [ ! -f "$DESTINATION_ORG_CONFIG_FILE" ]; then
        echo
        echo "ERROR: $DESTINATION_ORG_CONFIG_FILE file not found. Cannot proceed with parsing new organization configuration"
        exit 1
fi

if [ ! -f "$DELIVERY_ORG_CONFIG_FILE" ]; then
        echo
        echo "ERROR: $DELIVERY_ORG_CONFIG_FILE file not found. Cannot proceed with parsing new organization configuration"
        exit 1
fi

source .env
source ~/.profile

# check if environment variables for organization are set
destOrgLabelValue=$(jq -r '.label' $DESTINATION_ORG_CONFIG_FILE)
result=$?

if [ "$result" -ne 0 ]; then
        echo "ERROR: Format for $DESTINATION_ORG_CONFIG_FILE does not match expected"
        exit 1
fi

destOrgLabelValueStripped=$(echo $destOrgLabelValue | sed 's/"//g')
destOrgLabelVar="${destOrgLabelValueStripped^^}_ORG_LABEL"

if [ -z "${!destOrgLabelVar}" ]; then
        echo "Required organization environment data is missing. Obtaining ... "
        bash scripts/addOrgEnvData.sh $DESTINATION_ORG_CONFIG_FILE
        source .env
fi

destOrgContainers=$(jq -r '.containers[]' $DESTINATION_ORG_CONFIG_FILE)

which sshpass
if [ "$?" -ne 0 ]; then
        echo "sshpass tool not found"
        exit 1
fi

# add environment data to each host
for destContainer in $(echo "${destOrgContainers}" | jq -r '. | @base64'); do
        _jq(){
                destContainerNameValue=$(echo "\"$(echo ${destContainer} | base64 --decode | jq -r ${1})\"")
                destContainerNameValueStripped=$(echo $destContainerNameValue | sed 's/"//g')

                destContainerHostVar="${destOrgLabelValueStripped^^}_ORG_${destContainerNameValueStripped^^}_HOST"
                destContainerUsernameVar="${destOrgLabelValueStripped^^}_ORG_${destContainerNameValueStripped^^}_USERNAME"
                destContainerPasswordVar="${destOrgLabelValueStripped^^}_ORG_${destContainerNameValueStripped^^}_PASSWORD"
                destContainerPathVar="${destOrgLabelValueStripped^^}_ORG_${destContainerNameValueStripped^^}_PATH"

                # check if file is present on the remote host and deliver it if it is not
                sshpass -p "${!destContainerPasswordVar}" ssh ${!destContainerUsernameVar}@${!destContainerHostVar} "test -e ${!destContainerPathVar}hl/network/${DELIVERY_ORG_CONFIG_FILE}"
                result=$?
                echo $result

                if [ $result -ne 0 ]; then
                        sshpass -p "${!destContainerPasswordVar}" scp $DELIVERY_ORG_CONFIG_FILE ${!destContainerUsernameVar}@${!destContainerHostVar}:${!destContainerPathVar}hl/network/external-orgs

                        if [ "$?" -ne 0 ]; then
                                echo "ERROR: Cannot copy ${DELIVERY_ORG_CONFIG_FILE} to ${!destContainerHostVar} remote host"
                                exit 1
                        fi

                        echo
                        echo "$DELIVERY_ORG_CONFIG_FILE copied to $destContainerHostVar"
                        echo

                else
                        echo
                        echo "$DELIVERY_ORG_CONFIG_FILE is already present on $destContainerHostVar"
                        echo
                fi

                # start remote script
		if [ "${dataType}" == "env" ]; then
                	sshpass -p "${!destContainerPasswordVar}" ssh ${!destContainerUsernameVar}@${!destContainerHostVar} "cd ${!destContainerPathVar}hl/network && bash scripts/addExternalOrgEnvData.sh $DELIVERY_ORG_CONFIG_FILE"
                        result=$?
                        echo $result

                        if [ $result -ne 0 ]; then
				echo "ERROR: Organization network data is not added to ${destContainerNameValue} host machine"
                                exit 1
                        fi

                        echo
                        echo "Organization environment data has been successfully added to ${destContainerNameValue} host machine"
		
		elif [ "${dataType}" == "extrahosts" ]; then
			sshpass -p "${!destContainerPasswordVar}" ssh ${!destContainerUsernameVar}@${!destContainerHostVar} "cd ${!destContainerPathVar}hl/network && bash scripts/addExternalOrgExtraHosts.sh $DELIVERY_ORG_CONFIG_FILE"
                        result=$?
                        echo $result

                        if [ $result -ne 0 ]; then
                                echo "ERROR: Organization network data is not added to ${destContainerNameValue} host machine"
                                exit 1
                        fi

                        echo
                        echo "Organization environment data has been successfully added to ${destContainerNameValue} host machine"

		else
                        echo "Unknown data type request"
                        exit 1
                fi
        }
        echo $(_jq '.name')
done

