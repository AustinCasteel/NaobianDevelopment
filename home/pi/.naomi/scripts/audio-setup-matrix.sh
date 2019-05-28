#!/bin/bash
##########################################################################
# audio-setup-matrix.sh
# This script runs through the setup process for the Matrix HAT
##########################################################################

if [ ! -f matrix_setup_state.txt ]
then
    echo -e "\e[1;36m"
    echo "========================================================================="
    echo -e "Setting up Matrix Voice Hat. This will install the \e[1;35mmatrixio-kernel-modules \e[1;36mand \e[1;35mpulseaudio"
    echo -e "\e[1;36mThis process is automatic, but requires rebooting three times. Please be patient"
    sleep 2
    echo -e "\e[1;36mPress any key to continue..."
    read -N1 -s anykey
else
    echo -e "\e[1;36mPress any key to continue setting up Matrix Voice HAT"
    read -N1 -s anykey
fi

if [ ! -f matrix_setup_state.txt ]
then
    echo -e "\e[1;32mAdding Matrix repo and installing packages...\e[0m"
    curl https://apt.matrix.one/doc/apt-key.gpg | sudo apt-key add -
    echo "deb https://apt.matrix.one/raspbian $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/matrixlabs.list
    sudo apt-get update -y
    sudo apt-get upgrade -y

    echo "stage-1" > matrix_setup_state.txt
    echo -e "\e[1;36m[\e[1;34m!\e[1;36m] Rebooting to apply kernel updates, the installation will resume afterwards\e[0m"
    read -p "Press enter to continue reboot"
    sudo reboot
else
    matrix_setup_state=$( cat matrix_setup_state.txt)
fi

if [ $matrix_setup_state == "stage-1" ]
then
    echo ""
    echo -e "\e[1;32mInstalling matrixio-kernel-modules...\e[0m"
    sudo apt install matrixio-kernel-modules -y

    echo ""
    echo -e "\e[1;32mInstalling pulseaudio\e[0m"
    sudo apt-get install pulseaudio -y
        
    echo -e "\e[1;36m[\e[1;34m!\e[1;36m] Rebooting to apply audio subsystem changes, the installation will continue afterwards.\e[0m"
    read -p "Press enter to continue reboot"
    echo "stage-2" > matrix_setup_state.txt
    sudo reboot
fi

if [ $matrix_setup_state == "stage-2" ]
then
    echo -e "\e[1;36mSetting Matrix as standard microphone..."
    echo "========================================================================="
    pactl list sources short
    sleep 5
    pulseaudio -k
    pactl set-default-source 2
    pulseaudio --start
    amixer set Master 99%
    echo "amixer set Master 99%" >> ~/.naomi/scripts/audio-setup.sh
    sleep 2
    amixer

    naomi-mic-test
        
    read -p "You should have heard the recording playback. Press enter to continue"

    echo "========================================================================="

    echo "stage-3" > matrix_setup_state.txt
    read -p "Your Matrix microphone is now setup! Press enter to perform the final reboot and start Naomi."
    sudo reboot
fi

rm ~/matrix_setup_state.txt
rm ~/setup_matrix