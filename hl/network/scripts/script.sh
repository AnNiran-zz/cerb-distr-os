#!/bin/bash

echo
echo " ____    _____      _      ____    _____ "
echo "/ ___|  |_   _|    / \    |  _ \  |_   _|"
echo "\___ \    | |     / _ \   | |_) |   | |  "
echo " ___) |   | |    / ___ \  |  _ <    | |  "
echo "|____/    |_|   /_/   \_\ |_| \_\   |_|  "
echo
echo "Build Cerberus Network end-to-end test"
echo
PERSON_ACCOUNTS_CHANNEL="$1"
INSTITUTION_ACCOUNTS_CHANNEL="$2"
INTEGRATION_ACCOUNTS_CHANNEL="$3"
DELAY="$4"
LANGUAGE="$5"
TIMEOUT="$6"
VERBOSE="$7"
: ${PERSON_ACCOUNTS_CHANNEL:="persaccntschannel"}
: ${INSTITUTION_ACCOUNTS_CHANNEL:="instaccntschannel"}
: ${INTEGRATION_ACCOUNTS_CHANNEL:="integraccntschannel"}
: ${DELAY:="20"}
: ${LANGUAGE:="golang"}
: ${TIMEOUT:="10"}
: ${VERBOSE:="false"}
LANGUAGE=`echo "$LANGUAGE" | tr [:upper:] [:lower:]`
COUNTER=1
MAX_RETRY=5

PERSON_ACCOUNTS_CC_SRC_PATH="github.com/chaincode/person/"
INSTITUTION_ACCOUNTS_CC_SRC_PATH="github.com/chaincode/institution/"
INTEGRATION_ACCOUNTS_CC_SRC_PATH="github.com/chaincode/integration/"

echo "Channels: "
echo $PERSON_ACCOUNTS_CHANNEL
echo $INSTITUTION_ACCOUNTS_CHANNEL
echo $INTEGRATION_ACCOUNTS_CHANNEL

# import utils
. scripts/utils.sh

createChannels() {

	# how to check if a peer ia alive
	setGlobals 0

	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		set -x
		peer channel create -o osinstance0.cerberus.net:7050 -c $PERSON_ACCOUNTS_CHANNEL -f ./channel-artifacts/${PERSON_ACCOUNTS_CHANNEL}.tx >&log.txt
		res=$?
		set +x
	else
		set -x
		peer channel create -o osinstance0.cerberus.net:7050 -c $PERSON_ACCOUNTS_CHANNEL -f ./channel-artifacts/${PERSON_ACCOUNTS_CHANNEL}.tx --tls $CORE_PEER_TLS_ENABLED --cafile $OSINSTANCE0_CA >&log.txt
		res=$?
		set +x
	fi
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo "===================== PersonAccounts Channel created ===================== "
	echo

	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		set -x
		peer channel create -o osinstance1.cerberus.net:7050 -c $INSTITUTION_ACCOUNTS_CHANNEL -f ./channel-artifacts/${INSTITUTION_ACCOUNTS_CHANNEL}.tx >&log.txt
		res=$?
		set +x
	else
		set -x
		peer channel create -o osinstance1.cerberus.net:7050 -c $INSTITUTION_ACCOUNTS_CHANNEL -f ./channel-artifacts/${INSTITUTION_ACCOUNTS_CHANNEL}.tx --tls $CORE_PEER_TLS_ENABLED --cafile $OSINSTANCE1_CA >&log.txt
		res=$?
		set +x
	fi
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo "===================== InstitutionAccounts Channel created ===================== "
	echo

	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		set -x
		peer channel create -o osinstance2.cerberus.net:7050 -c $INTEGRATION_ACCOUNTS_CHANNEL -f ./channel-artifacts/${INTEGRATION_ACCOUNTS_CHANNEL}.tx >&log.txt
		res=$?
		set +x
	else
		set -x
		peer channel create -o osinstance2.cerberus.net:7050 -c $INTEGRATION_ACCOUNTS_CHANNEL -f ./channel-artifacts/${INTEGRATION_ACCOUNTS_CHANNEL}.tx --tls $CORE_PEER_TLS_ENABLED --cafile $OSINSTANCE2_CA >&log.txt
		res=$?
		set +x
	fi

	cat log.txt
	verifyResult $res "Channel creation failed"
	echo "===================== IntegrationAccounts Channel created ===================== "
	echo
}

joinCerberusOrgPeersToChannels () {
	for peer in 0 1 2; do
		joinPersonAccountsChannelWithRetry $peer
		sleep $DELAY
	done

	for peer in 0 1 2; do
		joinInstitutionAccountsChannelWithRetry $peer
		sleep $DELAY
	done

	for peer in 0 1 2; do
		joinIntegrationAccountsChannelWithRetry $peer
		sleep $DELAY
	done
}

## Create channel
echo "Creating channel..."
createChannels

echo "Having all peers join the channel..."
joinCerberusOrgPeersToChannels

## Set the anchor peers for each org in the channel
echo "Updating anchor peer for CerberusOrg..."
updateCerberusOrgAnchorPeers

# Install chaincode on anchorpr.sipher and anchorpr.whitebox
#echo "Installing pachaincode on anchorpr.sipher..."
#installPersonAccountsChaincode 0 1

#echo "Installing oachaincode on anchorpr.sipher..."
#installOrganizationAccountsChaincode 0 1

#echo "Installing iachaincode on anchorpr.sipher..."
#installIntegrationAccountsChaincode 0 1

#echo "Installing pachaincode on leadpr.sipher..."
#installPersonAccountsChaincode 1 1

#echo "Installing oachaincode on leadpr.sipher..."
#installOrganizationAccountsChaincode 1 1

#echo "Installing iachaincode on leadpr.sipher..."
#installIntegrationAccountsChaincode 1 1

#echo "Installing pachaincode on communicatepr.sipher..."
#installPersonAccountsChaincode 2 1

#echo "Installing oachaincode on communicatepr.sipher..."
#installOrganizationAccountsChaincode 2 1

#echo "Installing iachaincode on communicatepr.sipher..."
#installIntegrationAccountsChaincode 2 1

#echo "Installing pachaincode on endorsepr.sipher..."
#installPersonAccountsChaincode 3 1

#echo "Installing oachaincode on endorsepr.sipher..."
#installOrganizationAccountsChaincode 3 1

#echo "Installing iachaincode on endorsepr.sipher..."
#installIntegrationAccountsChaincode 3 1


#echo "Installing pachaincode on commitpr.sipher..."
#installPersonAccountsChaincode 4 1

#echo "Installing oachaincode on commitpr.sipher..."
#installOrganizationAccountsChaincode 4 1

#echo "Installing iachaincode on commitpr.sipher..."
#installIntegrationAccountsChaincode 4 1




#echo "Installing pachaincode on anchorpr.whitebox..."
#installPersonAccountsChaincode 0 2

#echo "Installing oachaincode on anchorpr.whitebox..."
#installOrganizationAccountsChaincode 0 2

#echo "Installing iachaincode on anchorpr.whitebox..."
#installIntegrationAccountsChaincode 0 2

#echo "Installing pachaincode on leadpr.whitebox..."
#installPersonAccountsChaincode 1 2

#echo "Installing oachaincode on leadpr.whitebox..."
#installOrganizationAccountsChaincode 1 2

#echo "Installing iachaincode on leadpr.whitebox..."
#installIntegrationAccountsChaincode 1 2

#echo "Installing pachaincode on communicatepr.whitebox..."
#installPersonAccountsChaincode 2 2

#echo "Installing oachaincode on communicatepr.whitebox..."
#installOrganizationAccountsChaincode 2 2

#echo "Installing iachaincode on communicatepr.whitebox..."
#installIntegrationAccountsChaincode 2 2


#echo "Installing pachaincode on endorsepr.whitebox..."
#installPersonAccountsChaincode 3 2

#echo "Installing oachaincode on endorsepr.whitebox..."
#installOrganizationAccountsChaincode 3 2

#echo "Installing iachaincode on endorsepr.whitebox..."
#installIntegrationAccountsChaincode 3 2


#echo "Installing pachaincode on commitpr.whitebox..."
#installPersonAccountsChaincode 4 2

#echo "Installing oachaincode on commitpr.whitebox..."
#installOrganizationAccountsChaincode 4 2

#echo "Installing iachaincode on commitpr.whitebox..."
#installIntegrationAccountsChaincode 4 2



#echo "Instantiating chaincode on anchorpr.sipher..."
#instantiatePersonAccountsChaincode 0 1

#instantiateOrganizationAccountsChaincode 0 1

#instantiateIntegrationAccountsChaincode 0 1

#echo "Querying chaincode on anchorpr.sipher..."
#chaincodeQuery 0 1

# Invoke chaincode on peer0.org1 and peer0.org2
#echo "Sending invoke transaction on peer0.org1 peer0.org2..."
#chaincodeInvoke 0 1 0 2

#echo "Installing chaincode on leadpr.sipher..."
#installchaincode 0 2

## Install chaincode on peer1.org2
#echo "Installing chaincode on leadpr.whitebox..."
#installChaincode 1 2

# Query on chaincode on peer1.org2, check if the result is 90
#echo "Querying chaincode on leadpr.whitebox..."
#chaincodeQuery 1 2 100

#echo "Querying chaincode on peer1.org1..."
#chaincodeQuery 1 1 90

echo
echo "========= All GOOD, Cerberus Network build execution completed =========== "
echo

echo
echo " _____   _   _   ____   "
echo "| ____| | \ | | |  _ \  "
echo "|  _|   |  \| | | | | | "
echo "| |___  | |\  | | |_| | "
echo "|_____| |_| \_| |____/  "
echo

exit 0
