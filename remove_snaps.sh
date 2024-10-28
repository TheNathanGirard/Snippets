#!/bin/bash
# Removes old revisions of snaps
# CLOSE ALL SNAPS BEFORE RUNNING THIS
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

set -eu

snapsToRemove=$(LANG=en_US.UTF-8 snap list --all | awk '/disabled/{print $1, $2, $3}')

echo $snapsToRemove

while read snapname version revision; do
    if [[ "$revision" == *[a-zA-z]* ]]; then
        # Version field is empty. Revision is in second field
        revision=$version
    fi
        snap remove "$snapname" --revision="$revision"
done <<< $snapsToRemove
