#!/bin/bash
#Set Variables
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

base_packages() {
	declare -a ArrayOfPackages=(
		"hcxdumptool"
		"hcxtools"
		"ca-certificates"
		"net-tools"
		"p7zip-full"
		"unzip"
		"nmon"
		"htop"
		"apt-transport-https"
		"curl"
		"wget"
		"jq"
		"git"
		"git-extras"
		"gitg"
		"nfs-common"
		"ssh-audit"
		"pv"
		"dialog"
		"software-properties-common"
		"iotop"
		"lsof"
		"screen"
		"file"
	)

	for package in "${ArrayOfPackages[@]}"; do
		dpkg -s $package &>/dev/null

		if [ $? -eq 0 ]; then
			echo -e "${GREEN}Package" $package "is installed.${NC}"
		else
			echo -e "${RED}Package" $package "NOT installed!${NC}"
			apt install -y $package
		fi
	done

}

build_packages() {
	declare -a ArrayOfPackages=(
		"build-essential"
		"automake"
		"libtool"
		"pkg-config"
		"ccache"
		"cmake"
		"libssl-dev"
		"libelf-dev"
		"libglib2.0-dev"
		"jq"
		"ecj"
		"fastjar"
		"java-propose-classpath"
		"subversion"
		"libncurses5-dev"
		"zlib1g-dev"
		"g++"
		"gawk"
		"gettext"
		"gcc-multilib"
		"gnulib"
		"flex"
		"libsnmp-dev"
		"liblzma-dev"
		"libpam0g-dev"
		"rake"
		"ruby"
		"ruby-dev"
		"rubygems"
		"valgrind"
		"libyang-cpp-dev"
		"openjdk-11-jre-headless"
		"cpio"
		"android-tools-adb"
		"android-tools-fastboot"
	)

	for package in "${ArrayOfPackages[@]}"; do
		dpkg -s $package &>/dev/null

		if [ $? -eq 0 ]; then
			echo -e "${GREEN}Package" $package "is installed.${NC}"
		else
			echo -e "${RED}Package" $package "NOT installed!${NC}"
			apt install -y $package
		fi
	done

	gem install fpm -f

}


desktop_packages() {
	declare -a ArrayOfPackages=(
		"vlc"
		"evolution"
		"dconf-editor"
		"gnome-weather"
		"gnome-tweak-tool"
		"onedrive"
		"code"
		"google-chrome-stable"
	)

	if [ -f "/etc/apt/sources.list.d/yann1ck-ubuntu-onedrive-focal.list" ]
	then
		echo "Onedrive Repository Already Exists"
	else
		add-apt-repository -y ppa:yann1ck/onedrive
		apt update
	fi

	if [ -f "/etc/apt/sources.list.d/vscode.list" ]
	then
		echo "MS VSCode Repository Already Exists"
	else
		wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
		install -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/trusted.gpg.d/
		sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
		apt update
	fi

	if [ -f "/etc/apt/sources.list.d/google-chrome.list" ]
	then
		echo "Google Repository Already Exists"
	else
		echo "Google Repository Already Exists"
		wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
		sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list'
		apt update
	fi
	
	for package in "${ArrayOfPackages[@]}"; do
		dpkg -s $package &>/dev/null

		if [ $? -eq 0 ]; then
			echo -e "${GREEN}Package" $package "is installed.${NC}"
		else
			echo -e "${RED}Package" $package "NOT installed!${NC}"
			apt install -y $package
		fi
	done

}

desktop_minimal() {
        apt install -y gnome-shell gnome-core xinit
        while true; do
    read -p "Which environment should start by default? GUI [G] or CLI [C]?" gc
    case $gc in
        [Gg]* ) break;;
        [Cc]* ) systemctl set-default multi-user.target; break;;
        * ) echo -e "${RED}Please answer GUI [G] or CLI [C].${NC}";;
    esac
done
}

disable_sudo_pw() {
	if [ -f "/etc/sudoers.d/99_sudo_all_users" ]; then
    		echo "No Password for sudoers already setup"
	else
    		echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/99_sudo_all_users
	fi
}

harden_ssh () {
	rm -v /etc/ssh/ssh_host_*
	dpkg-reconfigure openssh-server
	echo "KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group14-sha256" | tee -a /etc/ssh/sshd_config
	echo "HostKeyAlgorithms rsa-sha2-512,rsa-sha2-256,ssh-rsa,ssh-ed25519" | tee -a /etc/ssh/sshd_config
	echo "MACs umac-128-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com" | tee -a /etc/ssh/sshd_config

	systemctl restart sshd

}

install_vmtools () {
	apt install -y open-vm-tools open-vm-tools-desktop
}

install_nodejs () {
	curl -sL https://deb.nodesource.com/setup_15.x -o /tmp/nodesource_setup.sh
	/bin/bash /tmp/nodesource_setup.sh
	apt install -y nodejs
}

install_powershell () {
	apt install -y wget apt-transport-https software-properties-common
	wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -P /tmp
	dpkg -i /tmp/packages-microsoft-prod.deb
	apt update
	apt install -y powershell
}

install_docker () {
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
	add-apt-repository -y "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	apt update
	apt install -y docker-ce docker-ce-cli containerd.io docker-compose qemu-user-static qemu-utils pass golang-docker-credential-helpers
	wget https://github.com/wagoodman/dive/releases/download/v0.9.2/dive_0.9.2_linux_amd64.deb
	apt install ./dive_0.9.2_linux_amd64.deb
	rm dive_0.9.2_linux_amd64.deb
	usermod -aG docker $USER
}

install_webmin () {
	wget -q -O- http://www.webmin.com/jcameron-key.asc | sudo apt-key add
	echo "deb http://download.webmin.com/download/repository sarge contrib" | tee /etc/apt/sources.list.d/webmin.list
	apt update
	apt install -y webmin
}

install_zshell () {
	apt update
	apt install -y zsh zsh-syntax-highlighting zsh-autosuggestions
	cp zshell_config.conf /etc/skel/
	cp zshell_config.conf /root/
}


python_alias () {
	update-alternatives --install /usr/bin/python python /usr/bin/python3 10
	update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 10
}

while true; do
    read -p "Install Base Packages? " yn
    case $yn in
        [Yy]* ) base_packages; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -p "Install Build / Development Packages? " yn
    case $yn in
        [Yy]* ) build_packages; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -p "Install Minimal Desktop? " yn
    case $yn in
        [Yy]* ) desktop_minimal; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -p "Install Desktop Packages? " yn
    case $yn in
        [Yy]* ) desktop_packages; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -p "Harden SSH server? " yn
    case $yn in
        [Yy]* ) harden_ssh; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -p "Disable Password for all sudoers? " yn
    case $yn in
        [Yy]* ) disable_sudo_pw; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -p "Install NodeJS 15? " yn
    case $yn in
        [Yy]* ) install_nodejs; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -p "Install Powershell? " yn
    case $yn in
        [Yy]* ) install_powershell; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -p "Install VMtools? " yn
    case $yn in
        [Yy]* ) install_vmtools; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -p "Install Docker? " yn
    case $yn in
        [Yy]* ) install_docker; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -p "Install Webmin? " yn
    case $yn in
        [Yy]* ) install_webmin; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -p "Add Python alias for Python3? " yn
    case $yn in
        [Yy]* ) python_alias; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done


while true; do
    read -p "Install zshell? " yn
    case $yn in
        [Yy]* ) install_zshell; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done
