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
		"ca-certificates"
		"gnupg-agent"
		"aria2"
		"net-tools"
		"tasksel"
		"p7zip-full"
		"unzip"
		"nmon"
		"htop"
		"apt-transport-https"
		"curl"
		"wget"
		"jq"
		"git"
		"gitg"
		"nfs-common"
		"ssh-audit"
		"python3"
		"python3-pip"
		"git-extras"
		"python2"
		"pv"
		"dialog"
		"nmap"
		"software-properties-common"
		"iotop"
		"lsof"
		"screen"
		"file"
		"gparted"
		"clonezilla"
		"libncurses5"
		"fio"

	)

	#Update Locale
	locale-gen en_US.UTF-8
	update-locale LANG=en_US.UTF-8
	update-locale LANG=en_US.UTF-8
	
	#Update Timezone
	timedatectl set-timezone America/Chicago
	
	#Add Universal Repo
	add-apt-repository universe

	#Update Snap Packages
	snap refresh
	
	for package in "${ArrayOfPackages[@]}"; do
		dpkg -s $package &>/dev/null

		if [ $? -eq 0 ]; then
			echo -e "${GREEN}Package $package is installed.${NC}"
		else
			echo -e "${RED}Package $package NOT installed!${NC}"
			apt install -y $package
		fi
	done

}

build_packages() {
	declare -a ArrayOfPackages=(
		"android-tools-adb"
		"android-tools-fastboot"
		"apt-transport-https"
		"automake"
		"build-essential"
		"ccache"
		"cmake"
		"cpio"
		"cron"
		"curl"
		"dnsutils"
		"docbook-xsl"
		"doxygen"
		"ecj"
		"elinks"
		"fastjar"
		"flex"
		"g++"
		"gawk"
		"gettext"
		"git"
		"gnulib"
		"gnupg2"
		"htop"
		"iputils-ping"
		"java-propose-classpath"
		"jq"
		"libboost-all-dev"
		"libboost-dev"
		"libboost-system-dev"
		"libcap-dev"
		"libelf-dev"
		"libglib2.0-dev"
		"liblog4cplus-dev"
		"liblzma-dev"
		"libmysqlclient-dev"
		"libncurses5"
		"libncurses5-dev"
		"libncursesw5-dev"
		"libnghttp2-dev"
		"libpam0g-dev"
		"libpq-dev"
		"libsnmp-dev"
		"libssh-dev"
		"libssl-dev"
		"libtool"
		"libuv1"
		"libuv1-dev"
		"libyang-cpp-dev"
		"nano"
		"net-tools"
		"nmon"
		"openjdk-11-jre-headless"
		"openssh-server"
		"p7zip-full"
		"pkg-config"
		"postgresql-server-dev-all"
		"procps"
		"python3-dev"
		"python3-distutils-extra"
		"python3-pip"
		"python3-setuptools"
		"rake"
		"rsync"
		"ruby-full"
		"ruby-dev"
		"software-properties-common"
		"subversion"
		"sudo"
		"swig time"
		"texlive-fonts-extra"
		"texlive-fonts-recommended"
		"texlive-latex-base"
		"texlive-latex-extra"
		"unzip"
		"valgrind"
		"wget"
		"xsltproc"
		"zlib1g-dev"
		"golang-go"
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
	pip3 install sphinx
	pip3 install sphinx_rtd_theme

}


desktop_packages() {
	declare -a ArrayOfPackages=(
		"vlc"
		"dconf-editor"
		"gnome-weather"
		"gnome-tweak-tool"
		"code"
		"google-chrome-stable"
		"kdiskmark"
	)

	if [ -f "/etc/apt/sources.list.d/vscode.list" ]
	then
		echo "MS VSCode Repository Already Exists"
	else
		wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
		install -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/trusted.gpg.d/
		sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
		apt update
	fi

	if [ -f "jonmagon-ubuntu-kdiskmark-jammy.list" ]
	then
		echo "kdiskmark"
	else
		add-apt-repository -y ppa:jonmagon/kdiskmark
		apt update
		apt install -y kdiskmark
	fi

	if [ -f "/etc/apt/sources.list.d/google-chrome.list" ]
	then
		echo "Google Repository Already Exists"
	else
		echo "Google Repository Already Exists"
		curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/googlechrom-keyring.gpg
		apt update
		apt install -y google-chrome-stable
	fi
	echo "deb [arch=amd64 signed-by=/usr/share/keyrings/googlechrom-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list
	for package in "${ArrayOfPackages[@]}"; do
		dpkg -s $package &>/dev/null

		if [ $? -eq 0 ]; then
			echo -e "${GREEN}Package $package is installed.${NC}"
		else
			echo -e "${RED}Package $package NOT installed!${NC}"
			apt install -y $package
		fi
	done

}

snap_packages() {
	declare -a ArrayOfPackages=(
		"ssd-benchmark"
	)

	for package in "${ArrayOfPackages[@]}"; do
		snap install $package
	done

}

vanilla_desktop() {
        apt install -y vanilla-gnome-desktop
        while true; do
    read -rp "Which environment should start by default? GUI [G] or CLI [C]?" gc
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
	echo "MACs umac-128-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-512" | tee -a /etc/ssh/sshd_config

	systemctl restart sshd

}

install_vmtools () {
	apt install -y open-vm-tools open-vm-tools-desktop
}

install_nodejs () {
	curl -sL https://deb.nodesource.com/setup_current.x -o /tmp/nodesource_setup.sh
	/bin/bash /tmp/nodesource_setup.sh
	apt install -y nodejs
}

install_powershell () {
	apt install -y wget apt-transport-https software-properties-common
	wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -P /tmp
	dpkg -i /tmp/packages-microsoft-prod.deb
	apt update
	apt install -y powershell
}

install_docker () {
	apt update
	apt install -y \
		ca-certificates \
		curl \
		gnupg \
		lsb-release

	mkdir -p /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
	$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
	
	apt update

	apt install -y docker-ce docker-ce-cli containerd.io
	# apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

	# git clone https://github.com/wagoodman/dive.git /tmp/dive
	# cd /tmp/dive
	# make
	# cp ./dist/dive_linux_amd64/dive /usr/bin
	
#	wget https://github.com/wagoodman/dive/releases/download/v0.9.2/dive_0.9.2_linux_amd64.deb
#	apt install ./dive_0.9.2_linux_amd64.deb
#	rm dive_0.9.2_linux_amd64.deb
#``	usermod -aG docker $USER
}

install_webmin () {
	wget -q -O- http://www.webmin.com/jcameron-key.asc | apt-key add
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
    read -rp "Install Base Packages? " yn
    case $yn in
        [Yy]* ) base_packages; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -rp "Install Build / Development Packages? " yn
    case $yn in
        [Yy]* ) build_packages; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -rp "Install Vanilla Desktop? " yn
    case $yn in
        [Yy]* ) vanilla_desktop; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -rp "Install Desktop Packages? " yn
    case $yn in
        [Yy]* ) desktop_packages; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -rp "Install Snap Packages? " yn
    case $yn in
        [Yy]* ) snap_packages; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -rp "Harden SSH server? " yn
    case $yn in
        [Yy]* ) harden_ssh; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -rp "Disable Password for all sudoers? " yn
    case $yn in
        [Yy]* ) disable_sudo_pw; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -rp "Install NodeJS (Current)? " yn
    case $yn in
        [Yy]* ) install_nodejs; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -rp "Install Powershell? " yn
    case $yn in
        [Yy]* ) install_powershell; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -rp "Install VMtools? " yn
    case $yn in
        [Yy]* ) install_vmtools; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -rp "Install Docker? " yn
    case $yn in
        [Yy]* ) install_docker; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -rp "Install Webmin? " yn
    case $yn in
        [Yy]* ) install_webmin; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done

while true; do
    read -rp "Add Python alias for Python3? " yn
    case $yn in
        [Yy]* ) python_alias; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done


while true; do
    read -rp "Install zshell? " yn
    case $yn in
        [Yy]* ) install_zshell; break;;
        [Nn]* ) break;;
        * ) echo -e "${RED}Please answer yes or no.${NC}";;
    esac
done
