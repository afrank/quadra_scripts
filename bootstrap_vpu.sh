#!/bin/bash

if [[ ! -e Quadra_AI_V4.5.tar.gz ]]; then
    wget https://releases.netint.ca/quadra/stress-test-HDEKSN23DKE/Quadra_AI_V4.5.tar.gz
fi

if [[ ! -e Quadra_AI_V4.5.tar.gz || ! -e Quadra_V4.8.2.zip ]]; then
    echo "Missing files. try again."
    exit 2
fi

apt update
apt install -y nvme-cli screen libopencv-dev libjson-c-dev libcanberra-gtk-module libcanberra-gtk3-module devscripts make zip unzip yasm mediainfo

tar xvfz Quadra_AI_V4.5.tar.gz

unzip Quadra_V4.8.2.zip

./quadra_quick_installer.sh
