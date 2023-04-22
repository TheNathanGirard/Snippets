#!/bin/ash
#Set Variables
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

apk update
apk upgrade
apk add \
    htop \
    nano \
    openssh \
    autossh \
    ssh-audit \
    bind-tools \
    bash \
    git \
    p7zip \
    curl \
    wget \
