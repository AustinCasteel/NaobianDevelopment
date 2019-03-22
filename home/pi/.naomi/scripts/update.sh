#!/bin/bash

##########################################################################
# update.sh
##########################################################################
# This script is executed by the auto_run.sh when a new version is found
# at https://github.com/naomiproject/naobian/tree/master

REPO_PATH="https://raw.githubusercontent.com/austincasteel/naobiandevelopment/master"

if [ ! -f $REPO_PATH/home/pi/.naomi/configs/profile.yml ] ;
then
    # Assume this is a fresh install, setup the system
    echo "Would you like to install Naobian on this machine?"
    echo -n "Choice [Y/N]: "
    read -N1 -s key
    case $key in
      [Yy])
        ;;

      *)
        echo "Aborting install."
        exit
        ;;
    esac

    # Create basic folder structures
    sudo mkdir ~/.naomi/
    sudo mkdir ~/.naomi/configs/
    sudo mkdir ~/.naomi/scripts/

    # Get the Naobian profile file
    cd .naomi/configs/
    sudo wget -N $REPO_PATH/home/pi/.naomi/configs/profile.yml

    # Enable Autologin as the 'pi' user
    echo "[Service]" | sudo tee -a /etc/systemd/system/getty@tty1.service.d/autologin.conf
    echo "ExecStart=" | sudo tee -a /etc/systemd/system/getty@tty1.service.d/autologin.conf
    echo "ExecStart=-/sbin/agetty --autologin pi --noclear %I 38400 linux" | sudo tee -a /etc/systemd/system/getty@tty1.service.d/autologin.conf
    sudo systemctl enable getty@tty1.service

    # Create RAM disk
    echo "tmpfs /ramdisk tmpfs rw,nodev,nosuid,size=20M 0 0" | sudo tee -a /etc/fstab

    # Download and setup Naomi
    echo "Installing 'git'..."
    sudo apt-get install git -y

    echo "Downloading 'Naomi'..."
    cd ~
    git clone https://github.com/NaomiProject/Naomi.git
    cd Naomi
    git checkout master

    echo
    echo "Beginning the Naobian build process.  This will"
    echo "take a bit. Results will be in the ~/.naomi/build.log"
    bash ~/.naomi/scripts/dev_setup.sh -y 2>&1 | tee ~/.naomi/build.log
    echo "Build complete.  Press any key to review the output before it is deleted."
    read -N1 -s key
    nano ~/.naomi/build.log
fi

# update software
cd ~
wget -N $REPO_PATH/home/pi/.bashrc
cd ~/.naomi/configs/
wget -N $REPO_PATH/home/pi/.naomi/configs/AIY-asound.conf
cd ~/.naomi/scripts/
wget -N $REPO_PATH/home/pi/.naomi/scripts/audio_setup.sh
wget -N $REPO_PATH/home/pi/.naomi/scripts/audio_test.sh
wget -N $REPO_PATH/home/pi/.naomi/scripts/auto_run.sh
wget -N $REPO_PATH/home/pi/.naomi/scripts/version
wget -N $REPO_PATH/home/pi/.naomi/scripts/dev_setup.sh
wget -N $REPO_PATH/home/pi/.naomi/scripts/dev_options.json
wget -N $REPO_PATH/home/pi/.naomi/scripts/naomi-purge
chmod +x naomi-purge