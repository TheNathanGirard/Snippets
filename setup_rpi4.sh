#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

upgrade_eeprom () {
	rpi-eeprom-update -a
}

#cat /proc/device-tree/model

#model="$(cat /proc/device-tree/model)"
model=$(tr -d '\0' </proc/device-tree/model)
echo $model


rpi-eeprom-update
#Change file from critical to stable
#sudo nano /etc/default/rpi-eeprom-update

#sudo rpi-eeprom-update -d -a

#vcgencmd bootloader_version

while true; do
    read -p "Proceed with Upgrade?" yn
    case $yn in
        [Yy]* ) upgrade_eeprom; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done
