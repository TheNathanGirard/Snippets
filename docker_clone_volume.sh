#!/bin/bash

#Script that can clone a given volume

#Verify user entered arguments
if [ "$1" = "" ]
then
        echo "Provide a source volume name that needs to be cloned"
        exit
fi

if [ "$2" = "" ] 
then
        echo "Provide a destination volume name"
        exit
fi


#Verify the source volume name if it's valid or not
docker volume inspect "$1" > /dev/null 2>&1
if [ "$?" != "0" ]
then
        echo "The specified source volume \"$1\" does not exist"
        exit
fi

#Verify the destination volume name whether it is not conflicting with other existing volume
docker volume inspect "$2" > /dev/null 2>&1

if [ "$?" = "0" ]
then
        echo "The specified destination volume \"$2\" is conflicting with an already existing volume"
        exit
fi



echo "Creating destination volume \"$2\"..."
docker volume create --name "$2"  
echo "Copying data from source volume \"$1\" to destination volume \"$2\"..."
docker run --rm \
           -i \
           -t \
           -v "$1":/from \
           -v "$2":/to \
           alpine ash -c "cd /from ; cp -av . /to"
