#!/usr/bin/env bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#

# This is a collection of bash functions used by different scripts

ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/cerberus.net/orderers/orderer.cerberus.net/msp/tlscacerts/tlsca.cerberus.net-cert.pem

OSINSTANCE0_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/cerberus.net/orderers/osinstance0.cerberus.net/msp/tlscacerts/tlsca.cerberus.net-cert.pem
OSINSTANCE1_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/cerberus.net/orderers/osinstance1.cerberus.net/msp/tlscacerts/tlsca.cerberus.net-cert.pem
OSINSTANCE2_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/cerberus.net/orderers/osinstance2.cerberus.net/msp/tlscacerts/tlsca.cerberus.net-cert.pem
OSINSTANCE3_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/cerberus.net/orderers/osinstance3.cerberus.net/msp/tlscacerts/tlsca.cerberus.net-cert.pem
OSINSTANCE4_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/cerberus.net/orderers/osinstance4.cerberus.net/msp/tlscacerts/tlsca.cerberus.net-cert.pem

CORE_PEER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/cerberusorg.cerberus.net/peers/anchorpr.cerberusorg.cerberus.net/tls/ca.crt

# verify the result of the end-to-end test
verifyResult() {
	if [ $1 -ne 0 ]; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
		echo "========= ERROR !!! FAILED to execute End-2-End Scenario ==========="
		echo
		exit 1
	fi
}

setGlobals() {
	#CORE_PEER=$1
	PEER=$1
	# peer0 - anchorpr
	# peer1 - leadpr
	# peer2 - coomunicatepr
	# peer3 - execute0pr
	# peer4 - execute1pr
	# peer5 - fallback0pr
	# peer6 - fallback1pr

	CORE_PEER_LOCALMSPID="CerberusOrgMSP"
	ORGANIZATION_NAME="cerberusorg"
	CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_CA
	CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/cerberusorg.cerberus.net/users/Admin@cerberusorg.cerberus.net/msp

	if [ $PEER -eq 0 ]; then
		PEER_NAME="anchorpr"
		CORE_PEER_ADDRESS=anchorpr.cerberusorg.cerberus.net:7051
	elif [ $PEER -eq 1 ]; then
		PEER_NAME="leadpr"
		CORE_PEER_ADDRESS=leadpr.cerberusorg.cerberus.net:7051
	elif [ $PEER -eq 2 ]; then
		PEER_NAME="communicatepr"
		CORE_PEER_ADDRESS=communicatepr.cerberusorg.cerberus.net:7051
	elif [ $PEER -eq 3 ]; then
		PEER_NAME="execute0pr"
		CORE_PEER_ADDRESS=execute0pr.cerberusorg.cerberus.net:7051
	elif [ $PEER -eq 4 ]; then
		PEER_NAME="execute1pr"
		CORE_PEER_ADDRESS=execute1pr.cerberusorg.cerberus.net:7051
	elif [ $PEER -eq 5 ]; then
		PEER_NAME="fallback0pr"
		CORE_PEER_ADDRESS=fallback0pr.cerberusorg.cerberus.net:7051
	elif [ $PEER -eq 6 ]; then
		PEER_NAME="fallback1pr"
		CORE_PEER_ADDRESS=fallback1pr.cerberusorg.cerberus.net:7051
	else
		echo "Unknown peer"
		exit 1
	fi

	if [ "$VERBOSE" == "true" ]; then
		env | grep CORE
	fi
}

setOrdererGlobals() {
	OSINSTANCE=$1

	CORE_PEER_LOCALMSPID="CerberusOrgMSP"
	CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/cerberusorg.cerberus.net/users/Admin@cerberusorg.cerberus.net/msp
	#CORE_PEER_TLS_ROOTCERT_FILE=$ORDERER_CA
	if [ $OSINSTANCE -eq 0 ]; then
		CORE_PEER_TLS_ROOTCERT_FILE=$OSINSTANCE0_CA
	elif [ $OSINSTANCE -eq 1 ]; then
		CORE_PEER_TLS_ROOTCERT_FILE=$OSINSTANCE1_CA
	elif [ $OSINSTANCE -eq 2 ]; then
		CORE_PEER_TLS_ROOTCERT_FILE=$OSINSTANCE2_CA
	elif [ $OSINSTANCE -eq 3 ]; then
		CORE_PEER_TLS_ROOTCERT_FILE=$OSINSTANCE3_CA
	elif [ $OSINSTANCE -eq 4 ]; then
		CORE_PEER_TLS_ROOTCERT_FILE=$OSINSTANCE4_CA
	else
		echo "Unknown ordering service instance"
	fi
		
}

# update anchor peer for CerberusOrg
updateCerberusOrgAnchorPeers() {
	setGlobals 0

	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		set -x
		peer channel update -o osinstance0.cerberus.net:7050 -c $PERSON_ACCOUNTS_CHANNEL -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}PersAccChAnchors.tx >&log.txt
		res=$?
		set +x
	else
		set -x
		peer channel update -o osinstance0.cerberus.net:7050 -c $PERSON_ACCOUNTS_CHANNEL -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}PersAccChAnchors.tx --tls $CORE_PEER_TLS_ENABLED --cafile $OSINSTANCE0_CA >&log.txt
		res=$?
		set +x
	fi
	cat log.txt
	verifyResult $res "Anchor peer update failed"
	echo "===================== Anchor peers updated for org '$CORE_PEER_LOCALMSPID' on channel '$PERSON_ACCOUNTS_CHANNEL' ===================== "
	sleep $DELAY
	echo

	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		set -x
		peer channel update -o osinstance1.cerberus.net:7050 -c $INSTITUTION_ACCOUNTS_CHANNEL -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}InstAccChAnchors.tx >&log.txt
	 	es=$?
		set +x
	else
		set -x
		peer channel update -o osinstance1.cerberus.net:7050 -c $INSTITUTION_ACCOUNTS_CHANNEL -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}InstAccChAnchors.tx --tls $CORE_PEER_TLS_ENABLED --cafile $OSINSTANCE1_CA >&log.txt
		res=$?
		set +x
	fi
	cat log.txt
	verifyResult $res "Anchor peer update failed"
	echo "===================== Anchor peers updated for org '$CORE_PEER_LOCALMSPID' on channel '$INSTITUTION_ACCOUNTS_CHANNEL' ===================== "
	sleep $DELAY
	echo

	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		set -x
		peer channel update -o osinstance2.cerberus.net:7050 -c $INTEGRATION_ACCOUNTS_CHANNEL -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}IntgrAccChAnchors.tx >&log.txt
		res=$?
		set +x
	else
		set -x
		peer channel update -o osinstance2.cerberus.net:7050 -c $INTEGRATION_ACCOUNTS_CHANNEL -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}IntgrAccChAnchors.tx --tls $CORE_PEER_TLS_ENABLED --cafile $OSINSTANCE2_CA >&log.txt
		res=$?
		set +x
	fi
	cat log.txt
	verifyResult $res "Anchor peer update failed"
	echo "===================== Anchor peers updated for org '$CORE_PEER_LOCALMSPID' on channel '$INTEGRATION_ACCOUNTS_CHANNEL' ===================== "
	sleep $DELAY
	echo
}

## Sometimes Join takes time hence RETRY at least 5 times
joinPersonAccountsChannelWithRetry() {
	PEER=$1
	setGlobals $PEER

	set -x
	peer channel join -b $PERSON_ACCOUNTS_CHANNEL.block >&log.txt
	res=$?
	set +x

	cat log.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=$(expr $COUNTER + 1)
		echo "${PEER_NAME}.${ORGANIZATION_NAME} failed to join channel '$PERSON_ACCOUNTS_CHANNEL', Retry after $DELAY seconds"
		sleep $DELAY
		joinPersonAccountdChannelWithRetry $CORE_PEER
	else
		COUNTER=1
	fi
	verifyResult $res "After $MAX_RETRY attempts, ${PEER_NAME}.${ORGANIZATION_NAME} has failed to join channel '$PERSON_ACCOUNTS_CHANNEL' "
	echo "===================== ${PEER_NAME}.${ORGANIZATION_NAME} joined channel '$PERSON_ACCOUNTS_CHANNEL' ===================== "
}

joinInstitutionAccountsChannelWithRetry() {
	PEER=$1
	setGlobals $PEER

	set -x
	peer channel join -b $INSTITUTION_ACCOUNTS_CHANNEL.block >&log.txt
	res=$?
	set +x

	cat log.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=$(expr $COUNTER + 1)
		echo "${PEER_NAME}.${ORGANIZATION_NAME} failed to join channel '$INSTITUTION_ACCOUNTS_CHANNEL', Retry after $DELAY seconds"
		sleep $DELAY
		joinInstitutionAccountsChannelWithRetry $CORE_PEER $PEER
	else
		COUNTER=1
	fi
	verifyResult $res "After $MAX_RETRY attempts, ${PEER_NAME}.${ORGANIZATION_NAME} has failed to join channel '$INSTITUTION_ACCOUNTS_CHANNEL' "
	echo "===================== ${PEER_NAME}.${ORGANIZATION_NAME} joined channel '$INSTITUTION_ACCOUNTS_CHANNEL' ===================== "
}

joinIntegrationAccountsChannelWithRetry() {
	PEER=$1
	setGlobals $PEER

	set -x
	peer channel join -b $INTEGRATION_ACCOUNTS_CHANNEL.block >&log.txt
	res=$?
	set +x
	cat log.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=$(expr $COUNTER + 1)
		echo "${PEER_NAME}.${ORGANIZATION_NAME} failed to join channel '$INTEGRATION_ACCOUNTS_CHANNEL', Retry after $DELAY seconds"
		sleep $DELAY
		joinIntegrationAccountsChannelWithRetry $PEER $ORG
	else
		COUNTER=1
	fi
	verifyResult $res "After $MAX_RETRY attempts, ${PEER_NAME}.${ORGANIZATION_NAME} has failed to join channel '$INTEGRATION_ACCOUNTS_CHANNEL' "
	echo "===================== ${PEER_NAME}.${ORGANIZATION_NAME} joined channel '$INTEGRATION_ACCOUNTS_CHANNEL' ===================== "
}

function createConfigUpdate() {
	CHANNEL=$1
	ORIGINAL=$2
	MODIFIED=$3
	OUTPUT=$4

	echo "Original is "
	echo $ORIGINAL
	
	set -x
	# we have two json files of interest: channel-name-config.json and modified_channel-name-config.json
	# the initial contains the initial organizations, and the modified - the adder new organization
	configtxlator proto_encode --input ${ORIGINAL} --type common.Config --output channel-artifacts/${CHANNEL}-config.pb
	configtxlator proto_encode --input ${MODIFIED} --type common.Config --output channel-artifacts/modified_${CHANNEL}-config.pb

	# now we calculate the delta between the two files
	configtxlator compute_update --channel_id ${CHANNEL} --original channel-artifacts/${CHANNEL}-config.pb --updated channel-artifacts/modified_${CHANNEL}-config.pb --output channel-artifacts/${orgName}-${CHANNEL}_update.pb
	res=$?
	set +x

	delta=$(cat channel-artifacts/${orgName}-${CHANNEL}_update.pb)
	if [ -z "$delta" ]; then
		echo "========= No differences detected between original and updated configuration ========="

	else
		# the new files - $orgName-$CHANNEL_update.pb contains the new organization definitions and high level pointers to previous organizations materials
		set -x
		configtxlator proto_decode --input channel-artifacts/${orgName}-${CHANNEL}_update.pb --type common.ConfigUpdate | jq . > channel-artifacts/${orgName}-${CHANNEL}_update.json

		echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL'", "type":2}},"data":{"config_update":'$(cat channel-artifacts/${orgName}-${CHANNEL}_update.json)'}}}' | jq . > channel-artifacts/${orgName}-${CHANNEL}_update_in_envelope.json

		configtxlator proto_encode --input channel-artifacts/${orgName}-${CHANNEL}_update_in_envelope.json --type common.Envelope --output ${OUTPUT}
		res=$?
		set +x

		verifyResult $res "========= Adding ${orgName} to channel configuration for ${CHANNEL} failed ========"
	fi
}

function signConfigtxByPeer() {
	#PEER=$1
	TX=$1

	setGlobals 0
	set -x
	peer channel signconfigtx -f "${TX}"
	set +x
}

installPersonAccountsChaincode() {
  PEER=$1
  ORG=$2
  setGlobals $PEER $ORG
  VERSION=${3:-1.0}
  set -x
  peer chaincode install -n personaccountscc -v ${VERSION} -l ${LANGUAGE} -p ${PERSON_ACCOUNTS_CC_SRC_PATH} >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Chaincode installation on ${PEER_NAME}.${ORGANIZATION_NAME} has failed"
  echo "===================== Chaincode is installed on ${PEER_NAME}.${ORGANIZATION_NAME} ===================== "
  echo
}


#####################################################
installOrganizationAccountsChaincode() {
  PEER=$1
  ORG=$2
  setGlobals $PEER $ORG
  VERSION=${3:-1.0}
  set -x
  peer chaincode install -n organizationaccountscc -v ${VERSION} -l ${LANGUAGE} -p ${ORGANIZATION_ACCOUNTS_CC_SRC_PATH} >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Chaincode installation on ${PEER_NAME}.${ORGANIZATION_NAME} has failed"
  echo "===================== Chaincode is installed on ${PEER_NAME}.${ORGANIZATION_NAME} ===================== "
  echo
}

installIntegrationAccountsChaincode() {
  PEER=$1
  ORG=$2
  setGlobals $PEER $ORG
  VERSION=${3:-1.0}
  set -x
  peer chaincode install -n integrationaccountscc -v ${VERSION} -l ${LANGUAGE} -p ${INTEGRATION_ACCOUNTS_CC_SRC_PATH} >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Chaincode installation on ${PEER_NAME}.${ORGANIZATION_NAME} has failed"
  echo "===================== Chaincode is installed on ${PEER_NAME}.${ORGANIZATION_NAME} ===================== "
  echo
}

instantiatePersonAccountsChaincode() {
  PEER=$1
  ORG=$2
  setGlobals $PEER $ORG
  VERSION=${3:-1.0}

  # while 'peer chaincode' command can get the orderer endpoint from the peer
  # (if join was successful), let's supply it directly as we know it using
  # the "-o" option
  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
    set -x
    peer chaincode instantiate -o osprimary1.cerberus.dev:7050 -C $PERSON_ACCOUNTS_CHANNEL -n personaccountscc -l ${LANGUAGE} -v ${VERSION} -c '{"Args":["init", "123456", "anna", "angelova", "angelowwa@gmail.com", "0877150173", "someData"]}' -P "OR ('SipherMSP.peer','WhiteBoxMSP.peer')" >&log.txt
    res=$?
    set +x
  else
    set -x
    peer chaincode instantiate -o osprimary1.cerberus.dev:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $OSPRIMARY1_CA -C $PERSON_ACCOUNTS_CHANNEL -n personaccountscc -l ${LANGUAGE} -v ${VERSION} -c '{"Args":["init", "123456", "anna", "angelova", "angelowwa@gmail.com", "0877150173", "some data"]}' -P "OR ('SipherMSP.peer','WhiteBoxMSP.peer')" >&log.txt
    res=$?
    set +x
  fi
  cat log.txt
  verifyResult $res "Chaincode instantiation on ${PEER_NAME}.${ORGANIZATION_NAME} on channel '$PERSON_ACCOUNTS_CHANNEL' failed"
  echo "===================== Chaincode is instantiated on ${PEER_NAME}.${ORGANIZATION_NAME} on channel '$PERSON_ACCOUNTS_CHANNEL' ===================== "
  echo
}

instantiateOrganizationAccountsChaincode() {
  PEER=$1
  ORG=$2
  setGlobals $PEER $ORG

  # while 'peer chaincode' command can get the orderer endpoint from the peer
  # (if join was successful), let's supply it directly as we know it using
  # the "-o" option
  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
    set -x
    peer chaincode instantiate -o osprimary2.cerberus.dev:7050 -C $ORGANIZATION_ACCOUNTS_CHANNEL -n organizationaccountscc -l ${LANGUAGE} -v ${VERSION} -c '{"Args":["init", "myOrganization", "Anna", "myAddress", "angelowwa@gmail.com", "angelowwa@gmail.com", "0877150173"]}' -P "OR ('SipherMSP.peer','WhiteBoxMSP.peer')" >&log.txt
    res=$?
    set +x
  else
    set -x
    peer chaincode instantiate -o osprimary2.cerberus.dev:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $OSPRIMARY2_CA -C $ORGANIZATION_ACCOUNTS_CHANNEL -n organizationaccountscc -l ${LANGUAGE} -v ${VERSION} -c '{"Args":["init", "myOrganization", "Anna", "myAddress", "angelowwa@gmail.com", "angelowwa@gmail.com", "0877150173"]}' -P "OR ('SipherMSP.peer','WhiteBoxMSP.peer')" >&log.txt
    res=$?
    set +x
  fi
  cat log.txt
  verifyResult $res "Chaincode instantiation on ${PEER_NAME}.${ORGANIZATION_NAME} on channel '$ORGANIZATION_ACCOUNTS_CHANNEL' failed"
  echo "===================== Chaincode is instantiated on ${PEER_NAME}.${ORGANIZATION_NAME} on channel '$ORGANIZATION_ACCOUNTS_CHANNEL' ===================== "
  echo
}

instantiateIntegrationAccountsChaincode() {
  PEER=$1
  ORG=$2
  setGlobals $PEER $ORG

  # while 'peer chaincode' command can get the orderer endpoint from the peer
  # (if join was successful), let's supply it directly as we know it using
  # the "-o" option
  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
    set -x
    peer chaincode instantiate -o osprimary3.cerberus.dev:7050 -C $INTEGRATION_ACCOUNTS_CHANNEL -n integrationaccountscc -l ${LANGUAGE} -v ${VERSION} -c '{"Args":["init", "myOrganization", "Anna", "myAddress", "angelowwa@gmail.com", "angelowwa@gmail.com", "0877150173"]}' -P "OR ('SipherMSP.peer','WhiteBoxMSP.peer')" >&log.txt
    res=$?
    set +x
  else
    set -x
    peer chaincode instantiate -o osprimary3.cerberus.dev:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $OSPRIMARY3_CA -C $INTEGRATION_ACCOUNTS_CHANNEL -n integrationaccountscc -l ${LANGUAGE} -v ${VERSION} -c '{"Args":["init", "myOrganization", "Anna", "myAddress", "angelowwa@gmail.com", "angelowwa@gmail.com", "0877150173"]}' -P "OR ('SipherMSP.peer','WhiteBoxMSP.peer')" >&log.txt
    res=$?
    set +x
  fi
  cat log.txt
  verifyResult $res "Chaincode instantiation on ${PEER_NAME}.${ORGANIZATION_NAME} on channel '$INTEGRATION_ACCOUNTS_CHANNEL' failed"
  echo "===================== Chaincode is instantiated on ${PEER_NAME}.${ORGANIZATION_NAME} on channel '$INTEGRATION_ACCOUNTS_CHANNEL' ===================== "
  echo
}

chaincodeQuery() {
  PEER=$1
  ORG=$2
  setGlobals $PEER $ORG
  #EXPECTED_RESULT=$3
  echo "===================== Querying on ${PEER_NAME}.${ORGANIZATION_NAME} on channel '$PERSON_ACCOUNTS_CHANNEL'... ===================== "
  local rc=1
  local starttime=$(date +%s)

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while
    test "$(($(date +%s) - starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  do
    sleep $DELAY
    echo "Attempting to Query ${PEER_NAME}.${ORGANIZATION_NAME} ...$(($(date +%s) - starttime)) secs"
    set -x
    peer chaincode query -C $PERSON_ACCOUNTS_CHANNEL -n personaccountscc -c '{"Args":["queryPersonAccountByEmail","angelowwa@gmail.com"]}' >&log.txt
    res=$?
    set +x

    test $res -eq 0 && VALUE=$(cat log.txt | awk '/Query Result/ {print $NF}')
    echo $VALUE
    echo "Value printed"

    #test "$VALUE" = "$EXPECTED_RESULT" && let rc=0
    # removed the string "Query Result" from peer chaincode query command
    # result. as a result, have to support both options until the change
    # is merged.
    #test $rc -ne 0 && VALUE=$(cat log.txt | egrep '^[0-9]+$')
    #test "$VALUE" = "$EXPECTED_RESULT" && let rc=0
  done

  echo
  cat log.txt
  verifyResult $res "!!!!!!!!!!!!!!! Query result on ${PEER_NAME}.${ORGANIZATION_NAME} is INVALID !!!!!!!!!!!!!!!!"
  echo "===================== Query successful on ${PEER_NAME}.${ORGANIZATION_NAME} on channel '$PERSON_ACCOUNTS_CHANNEL' ===================== "


  #echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
  #echo
}
