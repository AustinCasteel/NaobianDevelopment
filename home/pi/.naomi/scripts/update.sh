#!/bin/bash
##########################################################################
# update.sh
# This script is executed by auto-start.sh when a new version is found
# at https://github.com/naomiproject/naobian/tree/master
##########################################################################

REPO_PATH="https://raw.githubusercontent.com/austincasteel/naobiandevelopment/master"

if [ ! -f $REPO_PATH/home/pi/.naomi/configs/profile.yml ] ;
then
    # Assuming a fresh install...
    tput reset
    echo -e "\e[1;93m"
    echo "###################################################"
    echo "#                                                 #"
    echo -e "#             \e[1;32mNaobian Scripts Update\e[1;93m              #"
    echo "#                                                 #"
    echo "###################################################"
    echo -e "\e[0m"
    echo
    echo -e "\e[1;36m[\e[1;33m?\e[1;36m] Would you like to install Naobian on this machine? \e[0m"
    echo
    echo -n -e "\e[1;36mChoice [\e[1;35mY\e[1;36m/\e[1;35mN\e[1;36m]: \e[0m"
    read -N1 -s key
    case $key in
      [Yy])
        ;;

      *)
        echo -e "\e[1;31mAborting install."
        exit
        ;;
    esac

    # Create basic folder structures
    echo -e "\e[1;32mCreating File Structure...\e[0m"
    mkdir ~/.naomi/
    mkdir ~/.naomi/configs/
    mkdir ~/.naomi/scripts/

    # Get the Naobian profile file
    echo
    echo -e "\e[1;32mRetrieving Default Profile...\e[0m"
    cd ~/.naomi/configs/
    sudo wget -N $REPO_PATH/home/pi/.naomi/configs/profile.yml

    # Enable Autologin as the 'pi' user
    echo
    echo -e "\e[1;32mEnabling Autologin...\e[0m"
    echo "[Service]" | sudo tee -a /etc/systemd/system/getty@tty1.service.d/autologin.conf
    echo "ExecStart=" | sudo tee -a /etc/systemd/system/getty@tty1.service.d/autologin.conf
    echo "ExecStart=-/sbin/agetty --autologin pi --noclear %I 38400 linux" | sudo tee -a /etc/systemd/system/getty@tty1.service.d/autologin.conf
    sudo systemctl enable getty@tty1.service

    # Download and setup Naomi Dev
    echo
    echo -e "\e[1;32mInstalling 'git'...\e[0m"
    sudo apt-get install git -y
    echo
    echo -e "\e[1;32mDownloading 'Naomi'...\e[0m"
    cd ~
    git clone https://github.com/NaomiProject/Naomi.git
    cd Naomi
    git checkout naomi-dev

    echo -e "\e[1;36m"
    echo "Beginning the Naobian build process.  This will take around 3 hours..."
    echo "Treat yourself to a movie and some popcorn in the mean time."
    echo -e "Results will be in the \e[1;35m~/.naomi/build.log"
    sleep 10
    bash ~/.naomi/scripts/naobian-setup.sh -y 2>&1 | tee ~/.naomi/build.log
    echo
    echo -e "\e[1;36mBuild complete.  Press any key to review the output."
    read -N1 -s key
    nano ~/.naomi/build.log
fi

# Update Naomi Scripting
echo
echo -e "\e[1;32mUpdating Naobian Scripts...\e[0m"
cd ~
wget -N $REPO_PATH/home/pi/.bashrc
cd ~/.naomi/scripts/
sudo wget -N $REPO_PATH/home/pi/.naomi/scripts/update.sh
sudo wget -N $REPO_PATH/home/pi/.naomi/scripts/version
sudo wget -N $REPO_PATH/home/pi/.naomi/scripts/naomi-purge
sudo wget -N $REPO_PATH/home/pi/.naomi/scripts/naobian-setup.sh
sudo wget -N $REPO_PATH/home/pi/.naomi/scripts/auto-start.sh
sudo wget -N $REPO_PATH/home/pi/.naomi/scripts/audio-setup.sh
sudo wget -N $REPO_PATH/home/pi/.naomi/scripts/audio-setup-matrix.sh
sudo wget -N $REPO_PATH/home/pi/.naomi/scripts/AIY-asound.conf
sudo chmod +x naomi-purge
sleep 2
echo -e "\e[1;36m[\e[1;34m!\e[1;36m] Updates Complete\e[0m"
sleep 2
echo -e "\e[1;36m[\e[1;34m!\e[1;36m] Naobian is going to Reboot in 3 seconds\e[0m"
sleep 3
sudo reboot & sudo rm ~/update.sh