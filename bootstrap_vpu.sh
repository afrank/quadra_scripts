#!/bin/bash

if [[ ! "$(pwd)" = "/root" ]]; then
    echo "Error: this script must be run from /root. Please copy it to /root and run it from there."
    echo "wget -O /root/bootstrap_vpu.sh https://raw.githubusercontent.com/afrank/quadra_scripts/main/bootstrap_vpu.sh && chmod +x /root/bootstrap_vpu.sh"
    exit 2
fi

if [[ ! -e Quadra_AI_V4.5.tar.gz ]]; then
    wget https://releases.netint.ca/quadra/stress-test-HDEKSN23DKE/Quadra_AI_V4.5.tar.gz
fi

if [[ ! -e Quadra_V4.8.2.zip ]]; then
    wget https://raw.githubusercontent.com/afrank/quadra_scripts/main/Quadra_V4.8.2.zip
fi

if [[ ! -e quadra_quick_installer.sh ]]; then
    wget https://raw.githubusercontent.com/afrank/quadra_scripts/main/quadra_quick_installer.sh
    chmod +x quadra_quick_installer.sh
fi

apt update
apt install -y nvme-cli screen libopencv-dev libjson-c-dev libcanberra-gtk-module libcanberra-gtk3-module devscripts make zip unzip yasm mediainfo

tar xvfz Quadra_AI_V4.5.tar.gz

unzip Quadra_V4.8.2.zip

./quadra_quick_installer.sh
