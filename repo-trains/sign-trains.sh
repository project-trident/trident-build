#!/bin/sh
#
# Use the following to create a pub/priv pair
# openssl genrsa -des3 -out sysup.pem 4096
# openssl rsa -in sysup.pem -outform PEM -pubout -out sysup.pub
#
# Example: ./sign-trains.sh trains.json

pKEY="$2"
pubKEY="$3"

if [ -z "$3" ] ; then
	echo "Usage: $0 <file> <private-key-file> <public-key-file>"
	exit 1
fi

if [ -e "${1}.sha1" ] ; then
   rm ${1}.sha1
fi

openssl dgst -sha512 -sign ${pKEY} -out ${1}.sha1 ${1}

# verify the signing worked
openssl dgst -sha512 -verify ${pubKEY} -signature ${1}.sha1 ${1}
