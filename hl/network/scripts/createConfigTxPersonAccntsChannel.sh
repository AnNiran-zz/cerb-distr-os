#!/bin/bash
. scripts/utils.sh

org=$1
orgMsp=$2
PERSON_ACCOUNTS_CHANNEL=$3

setOrdererGlobals 0

echo "Fetching the most recent configuration for ${PERSON_ACCOUNTS_CHANNEL}"

if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
	set -x
	peer channel fetch config channel-artifacts/${PERSON_ACCOUNTS_CHANNEL}_config_block.pb -o osinstance0.cerberus.net:7050 -c $PERSON_ACCOUNTS_CHANNEL --cafile $OSINSTANCE0_CA
	set +x
else
	set -x
	peer channel fetch config channel-artifacts/${PERSON_ACCOUNTS_CHANNEL}_config_block.pb -o osinstance0.cerberus.net:7050 -c $PERSON_ACCOUNTS_CHANNEL --tls --cafile $OSINSTANCE0_CA
	set +x
fi

echo "Decoding config block to JSON and isolating output to channel-artifacts/${PERSON_ACCOUNTS_CHANNEL}-config.json"

set -x
configtxlator proto_decode --input channel-artifacts/${PERSON_ACCOUNTS_CHANNEL}_config_block.pb --type common.Block | jq .data.data[0].payload.data.config > channel-artifacts/${PERSON_ACCOUNTS_CHANNEL}-config.json
set +x

set -x
jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"'$orgMsp'":.[1]}}}}}' channel-artifacts/${PERSON_ACCOUNTS_CHANNEL}-config.json ./channel-artifacts/${org}-channel-artifacts.json > ./channel-artifacts/modified_${PERSON_ACCOUNTS_CHANNEL}-config.json
set +x

createConfigUpdate $PERSON_ACCOUNTS_CHANNEL channel-artifacts/${PERSON_ACCOUNTS_CHANNEL}-config.json channel-artifacts/modified_${PERSON_ACCOUNTS_CHANNEL}-config.json channel-artifacts/${org}-${PERSON_ACCOUNTS_CHANNEL}_update_in_envelope.pb $org

echo
echo "========= Config transaction to add ${org^^} to ${PERSON_ACCOUNTS_CHANNEL} created =========="
echo

echo "========= Signing config transactions for ${org^^} ========="
echo

signConfigtxByPeer channel-artifacts/${org}-${PERSON_ACCOUNTS_CHANNEL}_update_in_envelope.pb

setGlobals 1
set -x
peer channel update -f channel-artifacts/${org}-${PERSON_ACCOUNTS_CHANNEL}_update_in_envelope.pb -c $PERSON_ACCOUNTS_CHANNEL -o osinstance0.cerberus.net:7050 --tls --cafile $OSINSTANCE0_CA
set +x

echo
echo "========= Config transaction for adding ${org^^} to ${PERSON_ACCOUNTS_CHANNEL} submitted! ========="
echo

exit 0

