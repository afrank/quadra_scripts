#!/usr/bin/env bash

# Copyright (C) 2022 NETINT Technologies
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# This script is intended to help customers install Netint software and firmware

script_version="v2.8"
#SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>&1 > /dev/null; pwd)
SCRIPT_PATH=/root/Quadra_V4.8.2
exit_code=0
SUDO="sudo " # Will be "sudo " if user is not root, else ""

auto_options=("Setup Environment variables" "Install OS prerequisite packages" "Install Libxcoder" "Install FFmpeg-n6.1" "Quit")

if [ "$1" = "-v" ] || [ "$1" = "--version" ]; then
  echo "${script_version}"
  exit 0
fi

# Check if user is root. Set $SUDO accordingly
function set_sudo() {
    if [[ $(whoami) == "root" ]]; then
        SUDO=""
    else
        SUDO="sudo "
    fi
}

function end_script() {
    printf "\n"
    printf "Stopped quadra_quick_installer.sh\n"
    trap - EXIT
    exit $exit_code
}

# determine if host is "ubuntu", "centos", or "macos"
# put result in $get_os_ret
function get_os() {
    if lsb_release -i 2> /dev/null | grep -iq Ubuntu; then
        get_os_ret="ubuntu"
    elif lsb_release -i 2> /dev/null | grep -iq CentOS; then
        get_os_ret="centos"
    elif sw_vers -productName | grep -iq macOS; then
        get_os_ret="macos"
    else
        get_os_ret=""
        return 1
    fi
    return 0
}

# configure variables for terminal color text based on OS
function setup_terminal_colors() {
    if [[ $SHELL =~ .*zsh ]]; then
        cRst="\x1b[0m"
        cRed="\x1b[31m"
        cGrn="\x1b[32m"
        cYlw="\x1b[33m"
        cBlu="\x1b[34m"
        cMag="\x1b[35m"
        cCyn="\x1b[36m"
    else
        cRst="\e[0m"
        cRed="\e[31m"
        cGrn="\e[32m"
        cYlw="\e[33m"
        cBlu="\e[34m"
        cMag="\e[35m"
        cCyn="\e[36m"
    fi
}

# run `grep -Poh "$1"` for Linux or `perl -nle"print \$& while m{$1}g"` for MacOS
# $1 - regular expression to use
function grep_Poh() {
    if [[ "$get_os_ret" == "macos" ]]; then
        perl -nle "print \$& while m{$1}g"
    else
        grep -Poh "$1"
    fi
}

# if release package folder exists and it matches expected md5sum, use folder for installation;
# else if tarball exists, use tarball;
# else proceed without FW/SW release
function select_tarball_vs_folder() {
    fw_folder=$(find . -maxdepth 1 -type d | grep_Poh 'Quadra_FW_V[0-9A-Z\.]{5}_[0-9A-Za-z]{3}$' | sort -V)
    if [ -f "md5sum" ] && [ ! -z $fw_folder ]; then
        expected_md5=$(grep "${fw_folder}" md5sum | grep_Poh '(?<=^# )[0-9a-f]{32}(?=  )')
        if [[ "$get_os_ret" == "macos" ]]; then
            actual_md5=$(cd ${fw_folder}; find . -type f -not -iwholename '*.git*' -exec md5 -r {} \;| sed 's/.\{32\}/& /' | LC_ALL='C' sort -k 2 | md5 -q)
        else
            actual_md5=$(cd ${fw_folder}; find . -type f -not -iwholename '*.git*' -exec md5sum {} \; | LC_ALL='C' sort -k 2 | md5sum | head -c -4)
        fi
        if [[ "$expected_md5" != "$actual_md5" ]]; then
            fw_folder=""
        fi
    else
        fw_folder=""
    fi
    if [ -z $fw_folder ]; then
        fw_pack=$(ls Quadra_FW_V*.*.*.tar.gz | sort -V | tail -n 1)
        if [ ! -z $fw_pack ]; then
            fw_folder=$(echo ${fw_pack} | grep_Poh 'Quadra_FW_V[0-9A-Z\.]{5}_[0-9A-Za-z]{3}(?=\.tar\.gz)')
        fi
    fi

    sw_folder=$(find . -maxdepth 1 -type d | grep_Poh 'Quadra_SW_V[0-9A-Z\.]{5}_[0-9A-Za-z]{3}$' | sort -V)
    if [ -f "md5sum" ] && [ ! -z $sw_folder ]; then
        expected_md5=$(grep "${sw_folder}" md5sum | grep_Poh '(?<=^# )[0-9a-f]{32}(?=  )')
        if [[ "$get_os_ret" == "macos" ]]; then
            actual_md5=$(cd ${sw_folder}; find . -type f -not -iwholename '*.git*' -exec md5 -r {} \;| sed 's/.\{32\}/& /' | LC_ALL='C' sort -k 2 | md5 -q)
        else
            actual_md5=$(cd ${sw_folder}; find . -type f -not -iwholename '*.git*' -exec md5sum {} \; | LC_ALL='C' sort -k 2 | md5sum | head -c -4)
        fi

        if [[ "$expected_md5" != "$actual_md5" ]]; then
            sw_folder=""
        else
            sw_release_num=$(echo ${sw_folder} | grep_Poh '(?<=Quadra_SW_V)[0-9A-Z\.]{5}_[0-9A-Za-z]{3}')
        fi
    else
        sw_folder=""
    fi
    if [ -z $sw_folder ]; then
        sw_pack=$(ls Quadra_SW_V*.*.*.tar.gz | sort -V | tail -n 1)
        if [ ! -z $sw_pack ]; then
            sw_folder=$(echo ${sw_pack} | grep_Poh 'Quadra_SW_V[0-9A-Z\.]{5}_[0-9A-Za-z]{3}(?=\.tar\.gz)')
            sw_release_num=$(echo ${sw_folder} | grep_Poh '(?<=Quadra_SW_V)[0-9A-Z\.]{5}_[0-9A-Za-z]{3}')
        fi
    fi
}

function extract_fw_sw_tarball() {
    echo "Please put the Netint Quadra FW/SW release tarballs or their extracted"
    echo "release folders in same directory as this script."
    echo -e "The latest FW release package found here is: ${cYlw}${fw_folder}${cRst}"
    echo -e "The latest SW release package found here is: ${cYlw}${sw_folder}${cRst}"

    #echo -e -n "${cYlw}Press [Y/y] to confirm the use of these two release packages.${cRst} "
    #read -n 1 -r
    #echo ""
    #if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    #    echo "Please ensure release package files and md5sum file you wish to use are latest"
    #    echo "versions in same directory as this script. Ensure they are unmodified (matches"
    #    echo "md5sum file). Then try again."
    #    end_script
    #fi

    # Extract release packages
    if [ ! -z $fw_pack ]; then
        ${SUDO}rm -rf ${fw_folder}
        tar -zxf $fw_pack
    fi
    if [ ! -z $sw_pack ]; then
        ${SUDO}rm -rf ${sw_folder}
        tar -zxf $sw_pack
    fi
}

function install_yasm() {
    rc=1
    if which curl &> /dev/null; then
        curl -O http://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz ||
        return $rc
    elif which wget &> /dev/null; then
        wget http://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz ||
        return $rc
    else
        return $rc
    fi
    tar -zxf yasm-1.3.0.tar.gz && rm yasm-1.3.0.tar.gz && cd yasm-1.3.0/ &&
    ./configure && make && ${SUDO}make install && cd .. &&
    rm -rf yasm-1.3.0 &&
    rc=0
    return $rc
}

function install_os_prereqs() {
    rc=1
    if [[ "$get_os_ret" == "ubuntu" ]]; then
        echo -e "Installing OS pre-requisites for ${cYlw}Ubuntu${cRst}"
        ${SUDO}apt-get update
        ${SUDO}apt-get install -y pkg-config git gcc ninja-build python3 \
             python3-pip flex bison libpng-dev zlib1g-dev gnutls-bin uuid-runtime \
             uuid-dev libglib2.0-dev libxml2 libxml2-dev &&
        ${SUDO}pip3 install --break-system-packages meson &&
        echo "Installing YASM" &&
        install_yasm &&
        rc=0
        return $rc
    elif [[ "$get_os_ret" == "centos" ]]; then
        echo -e "Installing OS pre-requisites for ${cYlw}CentOS${cRst}"
        ${SUDO}yum --enablerepo=extras install -y epel-release &&
        ${SUDO}yum install -y pkgconfig git redhat-lsb-core make gcc python3 \
             python3-pip flex bison libpng-devel zlib-devel gnutls libuuid-devel &&
        ${SUDO}pip3 install --break-system-packages ninja meson &&
        echo "Installing YASM" &&
        install_yasm &&
        rc=0
        return $rc
    elif [[ "$get_os_ret" == "macos" ]]; then
        echo -e "Installing OS pre-requisites for ${cYlw}MacOS${cRst}"
        echo "Installing Xcode command line tools"
        xcode-select --install 2>&1 | tee xcode_install_log.txt
        rc=${PIPESTATUS[0]}
        if [ $rc -ne 0 ] && ! grep -q "command line tools are already installed" xcode_install_log.txt; then
            return $rc
        elif grep -q "install requested for command line developer tools" xcode_install_log.txt; then
            echo -e -n "Complete command line tools install on GUI. ${cYlw}Press [Y/y] to continue.${cRst} "
            read -n 1 -r
        fi
        rm xcode_install_log.txt

        if ! which pkg-config 2>&1 2> /dev/null; then
            echo "Installing pkgconfig" &&
            curl -O https://pkg-config.freedesktop.org/releases/pkg-config-0.28.tar.gz &&
            tar -zxvf pkg-config-0.28.tar.gz && rm pkg-config-0.28.tar.gz &&
            cd pkg-config-0.28 && export CC=/usr/bin/cc 2> /dev/null ||
            setenv CC /usr/bin/cc 2> /dev/null &&
            ./configure --prefix=/usr/local CC=$CC --with-internal-glib &&
            make && ${SUDO}make install && cd .. && rm -rf pkg-config-0.28 ||
            return 1
        fi

        yasm_ver=$(which yasm 2>&1 > /dev/null && yasm --version | \
                   egrep -o "[[:digit:]]\.[[:digit:]]\.[[:digit:]]")
        if [ -n "$yasm_ver" ] && [[ $(printf "${yasm_ver}\n1.3.0\n" | sort -V | head -n 1) == "1.3.0" ]]; then
            return 0
        else
            echo "Installing YASM"
            install_yasm
            return $?
        fi
    else
        echo "Cannot determine OS for installation of pre-requisites"
        return 1
    fi
}

# $1 - Libxcoder folder to use. Must be of format 'libxcoder*" (eg. libxcoder_quadra)
function install_libxcoder() {
    cd_success=false
    rc=1
    # product suffix strings
    ps_orig=$(echo $1 | grep_Poh '(?<=libxcoder).*')
    ps_lower=$(echo "$ps_orig" | tr '[:upper:]' '[:lower:]') # this is only used for name scheme of init_rsrc* app
    if [[ $ps_lower == "_quadra" ]]; then
        ps_upper="" # this is only used for name scheme of shared memory files
    else
        ps_upper=$(echo "$ps_orig" | tr '[:lower:]' '[:upper:]')
    fi

    ${SUDO}rm -rf $1 &> /dev/null
    cp -r ${sw_folder}/$1 ./ && cd $1 && bash build.sh && cd .. && rc=0
    if [ $rc != 0 ]; then
        return $rc
    fi

    if [[ "$get_os_ret" == "ubuntu" ]] || [[ "$get_os_ret" == "centos" ]]; then
        cd /dev/shm && cd_success=true &&
        ${SUDO}rm -f NI${ps_upper}_lck_* NI${ps_upper}_LCK_* NI${ps_upper}_RETRY_LCK_* NI${ps_upper}_shm_* NI${ps_upper}_SHM_* &> /dev/null
        if $cd_success; then cd -; fi
        timeout -s KILL 5 init_rsrc${ps_lower} 2>&1 > /dev/null
    elif [[ "$get_os_ret" == "macos" ]] && [[ -f "/private/tmp/NI${ps_upper}_LCK_CODERS" ]]; then
        echo "Cannot reset POSIX shared memory on MacOS via terminal."
        echo "You may need to reboot computer run init_rsrc${ps_lower}"
        ${SUDO}init_rsrc${ps_lower} > /dev/null 2>&1 &
        sleep 5
        ${SUDO}killall -KILL init_rsrc${ps_lower} > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            $(exit 137)   # if killall terminates init_rsrc, then it timed out. Set $? to 137
        else
            $(exit 0)
        fi
    elif [[ "$get_os_ret" == "macos" ]]; then
        ${SUDO}init_rsrc${ps_lower} > /dev/null 2>&1 &
        sleep 5
        ${SUDO}killall -KILL init_rsrc${ps_lower} > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            $(exit 137)   # if killall terminates init_rsrc, then it timed out. Set $? to 137
        else
            $(exit 0)
        fi
    else
        timeout -s KILL 5 init_rsrc${ps_lower} 2>&1 > /dev/null
    fi
    rc=$?
    return $rc
}

# Remove libav shared libraries (lib*.so, lib*.pc, lib*.h) from system installation paths.
# This is has more coverage than `make uninstall` as it can also affect installation paths used
# by Android NDK.
function remove_installed_libav() {
    # remove shared libraries
    lib_dirs=$(ldconfig -np | grep_Poh '(?<=\) => ).+(?=/libav\w+\.so.*)' | sort -u | tr '\n' ' ')
    lib_dirs+=$(ldconfig -np | grep_Poh '(?<=\) => ).+(?=/libswscale\.so.*)' | sort -u | tr '\n' ' ')
    lib_dirs+=$(ldconfig -np | grep_Poh '(?<=\) => ).+(?=/libswresample\.so.*)' | sort -u | tr '\n' ' ')
    lib_dirs+=$(ldconfig -np | grep_Poh '(?<=\) => ).+(?=/libpostproc\.so.*)' | sort -u | tr '\n' ' ')
    uniq_lib_dirs=($(echo "${lib_dirs[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    for lib_dir in ${uniq_lib_dirs[@]}; do
        ${SUDO}rm -f $lib_dir/libavcodec*
        ${SUDO}rm -f $lib_dir/libavdevice*
        ${SUDO}rm -f $lib_dir/libavfilter*
        ${SUDO}rm -f $lib_dir/libavformat*
        ${SUDO}rm -f $lib_dir/libavresample*
        ${SUDO}rm -f $lib_dir/libavutil*
        ${SUDO}rm -f $lib_dir/libswscale*
        ${SUDO}rm -f $lib_dir/libswresample*
        ${SUDO}rm -f $lib_dir/libpostproc*
    done

    # remove pkg-config files
    ${SUDO}rm -f $(find /usr/ -name libav*.pc 2> /dev/null | grep_Poh '^.+/pkgconfig/\w+\.pc' | sort -u | tr '\n' ' ')
    ${SUDO}rm -f $(find /usr/ -name libswscale*.pc 2> /dev/null | grep_Poh '^.+/pkgconfig/\w+\.pc' | sort -u | tr '\n' ' ')
    ${SUDO}rm -f $(find /usr/ -name libswresample*.pc 2> /dev/null | grep_Poh '^.+/pkgconfig/\w+\.pc' | sort -u | tr '\n' ' ')
    ${SUDO}rm -f $(find /usr/ -name libpostproc*.pc 2> /dev/null | grep_Poh '^.+/pkgconfig/\w+\.pc' | sort -u | tr '\n' ' ')

    # remove header files
    gcc_inc_dirs=$(echo '' | `gcc -print-prog-name=cpp` -v 2>&1 | tr -d '\n' | grep_Poh '(?<=search starts here: ).+(?=End of search list.)')
    for gcc_inc_dir in ${gcc_inc_dirs[@]}; do
        for libav_dir in $gcc_inc_dir/libav*; do
            if [ -d "$libav_dir" ]; then ${SUDO}rm -rf $libav_dir; fi
        done
        ${SUDO}rm -rf $gcc_inc_dir/libswscale $gcc_inc_dir/libswresample $gcc_inc_dir/libpostproc
    done

    ${SUDO}ldconfig 2> /dev/null
}

# $1 - FFmpeg version to use (eg. n4.2.1)
function install_ffmpeg_ver() {
    rc=1
    extra_build_flags="--quadra --ffprobe --shared --custom_flags=--enable-libvmaf"
    remove_shared_lib=true

    echo "Installation Path: ./FFmpeg/"
    echo "Note: This will install NETINT-Quadra FFmpeg-${1} patch ontop base ${1} FFmpeg"
    echo "      Any customizations must be integrated manually"
    echo ""
    echo -e "Current build_ffmpeg.sh flags: ${cCyn}${extra_build_flags}${cRst}"
    extra_build_flags="${extra_build_flags} ${REPLY}"

    echo "Downloading FFmpeg-${1} from github..." &&
    ${SUDO}rm -rf FFmpeg/ &> /dev/null; mkdir FFmpeg/
    # Determine if target is a tag/branch name or commit SHA1. Download accordingly
    if  [[ `echo ${1} | grep -E "^[0-9a-fA-F]{7,}$"` != "" ]]; then
        git clone https://github.com/FFmpeg/FFmpeg.git FFmpeg/
        rc=$?
        if [ $rc -ne 0 ]; then
            echo "Failed to git clone FFmpeg"
            return $rc
        fi
        rc=1 && cd FFmpeg/ && git checkout ${1} && cd ..
    else
        git clone -b ${1} --depth=1 https://github.com/FFmpeg/FFmpeg.git FFmpeg/
        rc=$?
        if [ $rc -ne 0 ]; then
            echo "Failed to git clone FFmpeg"
            return $rc
        fi
        rc=1
    fi
    echo "Copying NETINT patch for FFmpeg-${1} to installation directory..." &&
    cp ${sw_folder}/FFmpeg-${1}_netint_v${sw_release_num}.diff FFmpeg/ &&
    cd FFmpeg/ &&
    patch -t -p 1 < FFmpeg-${1}_netint_v${sw_release_num}.diff &&
    echo "Compiling FFmpeg-${1}..." &&
    ${SUDO}make clean &> /dev/null || true &&
    rc=0
    if [ $rc -ne 0 ]; then
        return $rc
    fi
    rc=1

    export SRC_PATH=/root/Quadra_V4.8.2/FFmpeg
    ./configure
    yes | bash build_ffmpeg.sh ${extra_build_flags}
    rc=$?; if [ $rc -ne 0 ]; then return $rc; fi
    rc=1

    if $remove_shared_lib; then
        remove_installed_libav
    fi

    ${SUDO}make install &&
    rc=0

    if [[ "$extra_build_flags" == *"--gstreamer"* ]]; then
        ${SUDO}make uninstall-progs 2> /dev/null
        rm -f ffmpeg ffmpeg_g 2> /dev/null
        ${SUDO}ldconfig 2> /dev/null
    else
        chmod +x run_ffmpeg_quadra.sh 2> /dev/null
        ${SUDO}ldconfig 2> /dev/null
    fi
    cd ..
    return $rc
}

# Determine whether to use gstreamer or gst-build for git project name
# put result in $gst_proj_name
# $1 - gstreamer/gst-build version to use (eg. 1.22.2)
function set_gst_proj_name() {
    if $(printf '%s\n' "$1" 1.19 | sort -C -V); then
        gst_proj_name="gst-build"
    else
        gst_proj_name="gstreamer"
    fi
}

# $1 - gstreamer version (eg. 1.22.2)
function get_gstreamer() {
    rc=1

    rm -rf ${gst_proj_name}
    echo "Downloading ${gst_proj_name} from git..."
    git clone --depth 1 -b $1 https://gitlab.freedesktop.org/gstreamer/$gst_proj_name.git
    rc=$?

    if [ $rc -eq 0 ]; then
        cd ${gst_proj_name} &&
        meson setup build &&
        rc=0
    fi

    if [[ ${PWD##*/} == "${gst_proj_name}" ]]; then
        cd ..
    fi

    if ! [ $rc -eq 0 ]; then
        echo "Failed to download ${gst_proj_name}"
    fi
    return $rc
}

# $1 - gstreamer/gst-build version to use (eg. 1.22.2)
function install_gstreamer_ver() {
    rc=0

    # check libxcoder linkable
    if ! (pkg-config --modversion xcoder &> /dev/null); then
        echo "Error: libxcoder must be installed on system before compiling Gstreamer"
        return 1
    fi

    # if ffmpeg app exists in path, check it has gstreamer flag set
    if (which ffmpeg &> /dev/null && ! ffmpeg 2>&1 | grep -q -- "-DNI_DEC_GSTREAMER_SUPPORT"); then
        echo "Error: Netint FFmpeg-n4.3.1 or above must be installed with --shared and --gstreamer flags before compiling Gstreamer"
        return 1
    fi

    # if libavcodec exists in pkg-config, check libavcodec is from FFmpeg-n4.3.1+
    libavcodec_ver=$(pkg-config --modversion libavcodec 2> /dev/null)
    if [ -n $libavcodec_ver ] && [[ $(printf "${libavcodec_ver}\n58.91.100\n" | sort -V | tail -n 1) == "58.91.100" ]] && [[ "${libavcodec_ver}" != "58.91.100" ]]; then
        echo "Error: Netint FFmpeg-n4.3.1 or above must be installed with --shared flag before compiling Gstreamer"
        return 1
    fi

    get_gstreamer $1 || return $?

    echo "Patching ${gst_proj_name} with Netint changes..." &&
    cp ${sw_folder}/${gst_proj_name}-${1}_netint_v${sw_release_num}.diff ${gst_proj_name}/ || return $?

    cd ${gst_proj_name}/ &&
    patch -t -p 1 < ${gst_proj_name}-${1}_netint_v${sw_release_num}.diff &&
    chmod +x *.sh &&
    echo "Compiling Gstreamer..." &&
    ./build_gstreamer.sh --install &&
    rc=0 || rc=1
    cd ..

    return $rc
}

# $1 - rc
# $2 - prefix to print
function print_eval_rc() {
    if [[ $1 == 0 ]]; then
        echo -e "${cGrn}${2} ran succesfully${cRst}"
    else
        echo -e "${cRed}${2} failed${cRst}"
        exit_code=$1
    fi
    return $1
}

# MAIN -------------------------------------------------------------------------
trap end_script EXIT

if [ -n "$1" ] && [ "$1" != "-s" ] && [ "$1" != "--avoid_sudo" ]; then
    echo "No input args accepted."
    echo "There is a numbered menu after confirming tarballs to use."
    exit 0
fi

# '-s' and '--avoid_sudo' are hidden options to avoid sudo regardless of whether user is root
if [ "$1" = "-s" ] || [ "$1" = "--avoid_sudo" ]; then
    SUDO=""
else
    # do not use 'sudo ' if user is root
    set_sudo
fi

get_os
setup_terminal_colors

cd $SCRIPT_PATH
base_dir=$(pwd)
fw_pack=""
fw_folder=""
sw_pack=""
sw_folder=""
sw_release_num=""
select_tarball_vs_folder

echo "Welcome to the NETINT Quadra Quick Installer utility ${script_version}."
echo "This script supports Linux (not Android) and a subset of features for MacOS."
extract_fw_sw_tarball

# Setup options table
options=("Setup Environment variables"
         "Unlock CPU governor"
         "Install OS prerequisite packages"
         "Install NVMe CLI")
# Setup options table for Libxcoder variants
for libx_dir in $(ls -d ${sw_folder}/libxcoder*); do
    ps_orig=$(echo ${libx_dir} | grep_Poh '(?<=/libxcoder)[^ ]*')

    if [[ $ps_orig == "_quadra" ]]; then
        options+=("Install Libxcoder${ps_orig} (for FFmpeg-n3.1.1 only)")
    else
        options+=("Install Libxcoder${ps_orig}")
    fi
done
# Setup options table for FFmpeg versions
for ff_patch in ${sw_folder}/FFmpeg-*_netint_v${sw_release_num}.diff; do
    ver_num=$(echo ${ff_patch} | grep_Poh '(?<=/FFmpeg-)[^_]*(?=_netint_v[0-9A-Z\.]{5}_[0-9A-Za-z]{3}.diff)')
    if [[ $ver_num == '*' ]] || [ -z $ver_num ]; then
        continue;
    fi

    if [[ $ver_num == "n3.1.1" ]]; then
        options+=("Install FFmpeg-${ver_num} (must install Libxcoder_quadra first)")
    else
        options+=("Install FFmpeg-${ver_num}")
    fi
done
# Setup options table for Gstreamer versions
for gs_patch in ${sw_folder}/gst-build-*_netint_v${sw_release_num}.diff \
                ${sw_folder}/gstreamer-*_netint_v${sw_release_num}.diff; do
    ver_num=$(echo ${gs_patch} | grep_Poh '(?<=/gst(-build|reamer)-)[^_]*(?=_netint_v[0-9A-Z\.]{5}_[0-9A-Za-z]{3}.diff)')
    if [[ $ver_num == '*' ]] || [ -z $ver_num ]; then
        continue;
    fi
    set_gst_proj_name $ver_num
    options+=("Install ${gst_proj_name}-${ver_num}")
done
# Setup options table for remaining items
options+=("Firmware Update"
          "Quit")

# Main menu loop
while true; do
    cd $base_dir
    echo -e "${cYlw}Choose an option:${cRst}"
    for opt in "${auto_options[@]}"; do
        [[ "$opt" ]] || continue
        case $opt in
            "Setup Environment variables")
                echo -e "${cYlw}You chose $REPLY which is $opt${cRst}"
                if [[ "$get_os_ret" == "macos" ]]; then
                    export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig/:/opt/homebrew/lib/pkgconfig/:$PKG_CONFIG_PATH
                    print_eval_rc $? "${opt}"
                    continue
                fi

                if [ -n "$SUDO" ]; then
                    sudo grep -qxF 'Defaults    secure_path = /sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin' /etc/sudoers ||
                    sudo `which sed` -i '/^Defaults    secure_path = /s/$/:\/usr\/local\/sbin:\/usr\/local\/bin/' /etc/sudoers &&
                    sudo grep -qxF 'Defaults    env_keep += "PKG_CONFIG_PATH"' /etc/sudoers ||
                    sudo sh -c "echo 'Defaults    env_keep += \"PKG_CONFIG_PATH\"' >> /etc/sudoers"
                fi

                export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig/ &&
                export LD_LIBRARY_PATH=/usr/local/lib/ &&
                ${SUDO}grep -qxF '/usr/local/lib' /etc/ld.so.conf ||
                ${SUDO}sh -c 'echo "/usr/local/lib" >> /etc/ld.so.conf'
                ${SUDO}ldconfig

                print_eval_rc $? "${opt}"
                continue
            ;;
            "Unlock CPU governor")
                echo -e "${cYlw}You chose $REPLY which is $opt${cRst}"
                if [[ "$get_os_ret" == "macos" ]]; then
                    echo -e "CPU govenor unlock ${cRed}not supported/unnecessary${cRst} on MacOS"
                    print_eval_rc $? "${opt}"
                    continue
                fi
                if [ -z "$SUDO" ]; then
                    echo -e "CPU govenor unlock ${cRed}not supported${cRst} when user is root or sudo cannot be used"
                    print_eval_rc $? "${opt}"
                    continue
                fi

                grep -qxF 'for (( i=0; i<`nproc`; i++ )); do sudo sh -c "echo performance > /sys/devices/system/cpu/cpu${i}/cpufreq/scaling_governor"; done 2> /dev/null' ~/.bashrc ||
                echo 'for (( i=0; i<`nproc`; i++ )); do sudo sh -c "echo performance > /sys/devices/system/cpu/cpu${i}/cpufreq/scaling_governor"; done 2> /dev/null' >> ~/.bashrc
                print_eval_rc $? "${opt}"
                continue
            ;;
            "Install OS prerequisite packages")
                echo -e "${cYlw}You chose $REPLY which is $opt${cRst}"
                install_os_prereqs
                print_eval_rc $? "${opt}"
                continue
            ;;
            "Install NVMe CLI")
                echo -e "${cYlw}You chose $REPLY which is $opt${cRst}"
                if [[ "$get_os_ret" == "macos" ]]; then
                    echo -e "NVMe CLI ${cRed}not supported${cRst} on MacOS"
                    print_eval_rc $? "${opt}"
                    continue
                fi
                nvme_cli_ver="1.6"
                if [[ $(gcc -dumpversion | grep_Poh "^\d+") -ge 11 ]]; then
                    nvme_cli_ver="1.16"
                fi
                wget https://github.com/linux-nvme/nvme-cli/archive/v${nvme_cli_ver}.tar.gz &&
                tar -zxf v${nvme_cli_ver}.tar.gz &&
                cd nvme-cli-*/ &&
                make LIBJSONC=-1 &&  # disable linking with libjson-c as some versions (0.15-3~ubuntu1.22.04.1) have bugs
                sudo make install &&
                cd ..
                print_eval_rc $? "${opt}"
                continue
            ;;
            Install\ Libxcoder*)
                echo -e "${cYlw}You chose $REPLY which is $opt${cRst}"
                # get Libxcoder folder name from $opt
                ps_orig=$(echo ${opt} | grep_Poh '(?<=Install Libxcoder)[^ ]*(?=.*)')
                install_libxcoder libxcoder${ps_orig}
                print_eval_rc $? "Libxcoder${ps_orig} installation"
                continue
            ;;
            Install\ FFmpeg-*)
                echo -e "${cYlw}You chose $REPLY which is $opt${cRst}"
                # get FFmpeg version number from $opt
                ff_ver=$(echo ${opt} | grep_Poh '(?<=Install FFmpeg-)[^ ]+(?=.*)')
                install_ffmpeg_ver $ff_ver
                print_eval_rc $? "FFmpeg-${ff_ver} installation"
                continue
            ;;
            Install\ gst-build-* | Install\ gstreamer-*)
                echo -e "${cYlw}You chose $REPLY which is $opt${cRst}"
                # get gst-libav version number from $opt
                gst_ver=$(echo ${opt} | grep_Poh 'Install gst(reamer|-build)-\K.*')
                set_gst_proj_name $gst_ver
                if [[ "$get_os_ret" == "macos" ]]; then
                    echo -e "${gst_proj_name} installation ${cRed}not supported${cRst} on MacOS"
                    print_eval_rc 1 "${gst_proj_name} installation"
                    continue
                fi
                install_gstreamer_ver $gst_ver
                print_eval_rc $? "${gst_proj_name} installation"
                continue
            ;;
            "Firmware Update")
                echo -e "${cYlw}You chose $REPLY which is $opt${cRst}"
                if [[ "$get_os_ret" == "macos" ]]; then
                    echo -e "FW update ${cRed}not supported${cRst} on MacOS"
                    print_eval_rc $? "${opt}"
                    continue
                fi
                cd ${fw_folder} && ./quadra_auto_upgrade.sh &&
                cd .. &&
                echo "re"
                print_eval_rc $? "${opt}"
                continue
            ;;
            "Quit")
                exit
            ;;
            *) echo -e "${cRed}Invalid choice!${cRst}"
            ;;
        esac
    done
    break
done
