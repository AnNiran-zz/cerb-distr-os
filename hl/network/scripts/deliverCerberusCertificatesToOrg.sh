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
        bash scripts/addOrgEnvData.sh $ORG_CONFIG_FILE
        source .env
fi

osCertsFolder=crypto-config/ordererOrganizations/
if [ ! -d "$osCertsFolder" ]; then
        echo
        echo "ERROR: ${osCertsFolder} folder not found. Cannot proceed with copying network data to organization host"
        exit 1
fi


orgCertsFolder=crypro-config/peerOrganizations/cerberusorg.cerberus.net/
if [ ! -d "$osCertsFolder" ]; then
        echo
        echo "ERROR: ${osCertsFolder} folder not found. Cannot proceed with copying network data to organization host"
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
             
		cd crypto-config/
			
		# check if folder is present on the remote host and deliver it if it is not
                sshpass -p "${!containerPasswordVar}" ssh ${!containerUsernameVar}@${!containerHostVar} "test -d ${!containerPathVar}hl/network/crypto-config/ordererOrganizations"
                testResultOs=$?
		echo $testResultOs

		# if the folder is not present - deliver it 
		if [ $testResultOs -ne 0 ]; then
                        sshpass -p "${!containerPasswordVar}" scp -r ordererOrganizations ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}hl/network/crypto-config
			copyResult=$?
			echo $copyResult

                        if [ $copyResult -ne 0 ]; then
                                echo "ERROR: Cannot copy ${osCertsFolder} folder to ${!containerHostVar} remote host"
                                exit 1
                        fi

		# if the folder is present - update it
		else
			sshpass -p "${!containerPasswordVar}" ssh ${!containerUsernameVar}@${!containerHostVar} "cd ${!containerPathVar}hl/network/crypto-config/ && rm -rf ordererOrganizations/"
			removeResult=$?
			echo $removeResult

			if [ $removeResult -ne 0 ]; then
                                echo "ERROR: Cannot remove ${osCertsFolder} folder folder ${!containerHostVar} remote host"
                                exit 1
                        fi

			sshpass -p "${!containerPasswordVar}" scp -r ordererOrganizations ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}hl/network/crypto-config
			copyResult=$?
			echo $copyResult

                        if [ $copyResult -ne 0 ]; then
                                echo "ERROR: Cannot copy ${osCertsFolder} folder to ${!containerHostVar} remote host"
                                exit 1
                        fi

                fi 

		# deliver cerberus org certificates
		sshpass -p "${!containerPasswordVar}" ssh ${!containerUsernameVar}@${!containerHostVar} "test -d ${!containerPathVar}hl/network/crypto-config/peerOrganizations/cerberusorg.cerberus.net"
		testResultOrg=$?
		echo $testResultOrg

		# test if the organizations folder exists
                if [ $testResultOrg -ne 0 ]; then
			sshpass -p "${!containerPasswordVar}" ssh ${!containerUsernameVar}@${!containerHostVar} "test -d ${!containerPathVar}hl/network/crypto-config/peerOrganizations"
			testResultPeer=$?
			echo $testResultPeer
			
                	if [ $testResultPeer -ne 0 ]; then
                        	sshpass -p "${!containerPasswordVar}" ssh ${!containerUsernameVar}@${!containerHostVar} "cd ${!containerPathVar}hl/network/crypto-config && mkdir peerOrganizations"
				createResult=$?
				echo $createResult

                        	if [ $createResult -ne 0 ]; then
                                	echo "ERROR: cannot create peerOrganizations directory needed to deliver Cerberus Organization certificates"
                                	exit 1
                        	fi
                	fi

                        sshpass -p "${!containerPasswordVar}" scp -r peerOrganizations/cerberusorg.cerberus.net ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}hl/network/crypto-config/peerOrganizations
			copyResult=$?
			echo $copyResult

                        if [ $copyResult -ne 0 ]; then
                                echo "ERROR: Cannot copy ${orgCertsFolder} folder to ${!containerHostVar} remote host"
                                exit 1
                        fi

                else
                        sshpass -p "${!containerPasswordVar}" ssh ${!containerUsernameVar}@${!containerHostVar} "cd ${!containerPathVar}hl/network/crypto-config/peerOrganizations && rm -rf cerberusorg.cerberus.net/"
			removeResult=$?
			echo $removeResult

                        if [ $removeResult -ne 0 ]; then
                                echo "ERROR: Cannot remove ${orgCertsFolder} folder folder ${!containerHostVar} remote host"
                                exit 1
                        fi

                        sshpass -p "${!containerPasswordVar}" scp -r peerOrganizations/cerberusorg.cerberus.net ${!containerUsernameVar}@${!containerHostVar}:${!containerPathVar}hl/network/crypto-config/peerOrganizations
			copyResult2=$?
			echo $copyResult2

                        if [ $copyResult2 -ne 0 ]; then
                                echo "ERROR: Cannot copy ${orgCertsFolder} folder to ${!containerHostVar} remote host"
                                exit 1
                        fi
                fi
	
		cd ..
        }
        echo $(_jq '.name')
done

echo "Cerberus Ordering Service instances and Cerberus Organization certificates successfully delivered to ${orgLabelValueStripped^^} hosts"




