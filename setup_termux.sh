#!/bin/bash
pkg update
pkg upgrade
pkg install -y htop nano curl git openssh dnsutils jq pv iperf3 p7zip dialog nmap screen python rclone rsync termux-api termux-services termux-apt-repo termux-create-package termux-elf-cleaner

echo "alias ls='ls -alrth --color=auto'" | tee ~/.bashrc

setup_android_storage () {
	termux-setup-storage
}

while true; do
	read -p "Setup Android Storage in Termux?" yn
	case $yn in
		[Yy]* ) setup_android_storage; break;;
		[Nn]* ) break;;
		* ) echo -e "Please answer yes or no.";;
	esac
done
