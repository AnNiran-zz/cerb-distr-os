#!/bin/bash

function addEnvVariable() {
        newValue=$1
        varName=$2
        currentValue=$3

        if [ -z "$currentValue" ]; then
                echo "${varName}=${newValue}">>.env
                echo "### $varName obtained"
        elif [ "$currentValue" != "$newValue" ]; then
                unset $varName
                sed -i -e "/${varName}/d" .env

                echo "${varName}=${newValue}">>.env
                echo "### ${varName} value updated"
        else
                echo "${varName} already set"
                echo ""
        fi

        source .env
}

