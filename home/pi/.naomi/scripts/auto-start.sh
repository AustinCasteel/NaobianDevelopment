#!/bin/bash
##########################################################################
# auto-start.sh
# This script is executed by .bashrc every time someone logs in to the
# system (including shelling in via SSH).
##########################################################################

export PATH="$HOME/bin:$HOME/Naomi/bin:$PATH"

function network_setup() {
    # silent check at first
    if ping -q -c 1 -W 1 1.1.1.1 >/dev/null 2>&1 ; then
        return 0
    fi

    # Wait for an internet connection -- either the user finished Wifi Setup or
    # plugged in a network cable.
    show_prompt=1
    should_reboot=255
    reset_wlan0=0
    while ! ping -q -c 1 -W 1 1.1.1.1 >/dev/null 2>&1 ; do
        if [ $show_prompt = 1 ]
        then
            echo -e "\e[1;36m"
            echo "Network connection not found, press a key to setup via keyboard"
            echo "or plug in a network cable:"
            echo "  1) Basic wifi with SSID and password"
            echo "  2) Wifi with no password"
            echo "  3) Edit wpa_supplicant.conf directly"
            echo "  4) Force reboot"
            echo "  5) Skip network setup for now"
            echo -n -e "\e[1;36mChoice [\e[1;35m1\e[1;36m-\e[1;35m6\e[1;36m]: \e[0m"
            show_prompt=0
        fi

        read -N1 -s -t 1 pressed

        case $pressed in
         1)
            echo
            echo -n -e "\e[1;36mEnter a network SSID: \e[0m"
            read user_ssid
            echo -n -e "\e[1;36mEnter the password: \e[0m"
            read -s user_pwd
            echo
            echo -n -e "\e[1;36mEnter the password again: \e[0m"
            read -s user_confirm
            echo

            if [[ "$user_pwd" = "$user_confirm" && "$user_ssid" != "" ]]
            then
                echo "network={" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
                echo "        ssid=\"$user_ssid\"" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
                echo "        psk=\"$user_pwd\"" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
                echo "}" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
                reset_wlan0=1
                break
            else
                show_prompt=1
            fi
            ;;
         2)
            echo
            echo -n -e "\e[1;36mEnter a network SSID: \e[0m"
            read user_ssid

            if [ ! "$user_ssid" = "" ]
            then
                echo "network={" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
                echo "        ssid=\"$user_ssid\"" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
                echo "        key_mgmt=NONE" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
                echo "}" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
                reset_wlan0=5
                break
            else
                show_prompt=1
            fi
            ;;
         3)
            sudo nano /etc/wpa_supplicant/wpa_supplicant.conf
            reset_wlan0=5
            break
            ;;
         4)
            should_reboot=1
            break
            ;;
         5)
            should_reboot=0
            break;
            ;;
        esac

        if [[ $reset_wlan0 -gt 0 ]]
        then
            if [[ $reset_wlan0 -eq 5 ]]
            then
                echo -e "\e[1;32mReconfiguring WLAN0...\e[0m"
                wpa_cli -i wlan0 reconfigure
                show_prompt=1
                sleep 3
            elif [[ $reset_wlan0 -eq 1 ]]
            then
                echo -e "\e[1;31mFailed to connect to network."
                show_prompt=1
            else
                # decrement the counter
                reset_wlan0= expr $reset_wlan0 - 1
            fi

            $reset_wlan0=4
        fi

    done

    if [[ $should_reboot -eq 255 ]]
    then
        # Auto-detected
        echo
        echo -e "\e[1;32mNetwork connection detected!\e[0m"
        should_reboot=0
    fi

    return $should_reboot
}

function setup_wizard() {

    # Handle internet connection
    network_setup
    if [[ $? -eq 1 ]]
    then
        echo -e "\e[1;32mRebooting...\e[0m"
        sudo reboot
    fi

    # installs pulseaudio if not already installed
    if [ $(dpkg-query -W -f='${Status}' pulseaudio 2>/dev/null | grep -c "ok installed") -eq 0 ];
    then
        sudo apt-get install pulseaudio -y
    fi

    echo -e "\e[1;36m"
    echo "========================================================================="
    echo "HARDWARE SETUP"
    echo "How do you want Naomi to output audio:"
    echo "  1) Speakers via 3.5mm output (aka the 'audio jack')"
    echo "  2) HDMI audio (e.g. a TV or monitor with built-in speakers)"
    echo "  3) USB audio (e.g. a USB soundcard or USB mic/speaker combo)"
    echo "  4) Google AIY Voice HAT and microphone board (Voice Kit v1)"
    echo -n -e "\e[1;36mChoice [\e[1;35m1\e[1;36m-\e[1;35m4\e[1;36m]: \e[0m"
    while true; do
        read -N1 -s key
        case $key in
         1)
            echo -e "\e[1;32m$key - Analog audio"
            # audio out the analog speaker/headphone jack
            sudo amixer cset numid=3 "1" > /dev/null
            echo 'sudo amixer cset numid=3 "1" > /dev/null' >> ~/.naomi/scripts/audio-setup.sh
            break
            ;;
         2)
            echo -e "\e[1;32m$key - HDMI audio"
            # audio out the HDMI port (e.g. TV speakers)
            sudo amixer cset numid=3 "2" > /dev/null
            echo 'sudo amixer cset numid=3 "2"  > /dev/null' >> ~/.naomi/scripts/audio-setup.sh
            break
            ;;
         3)
            echo -e "\e[1;32m$key - USB audio"
            # audio out to the USB soundcard
            sudo amixer cset numid=3 "0" > /dev/null
            echo 'sudo amixer cset numid=3 "0"  > /dev/null' >> ~/.naomi/scripts/audio-setup.sh
            break
            ;;
         4)
            echo -e "\e[1;32m$key - Google AIY Voice HAT and microphone board (Voice Kit v1)"
            # Get AIY drivers
            echo "deb https://dl.google.com/aiyprojects/deb stable main" | sudo tee /etc/apt/sources.list.d/aiyprojects.list
            wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -

            sudo apt-get update
            sudo mkdir /usr/lib/systemd/system

            sudo apt-get install aiy-dkms aiy-io-mcu-firmware aiy-vision-firmware dkms raspberrypi-kernel-headers
            sudo apt-get install aiy-dkms aiy-voicebonnet-soundcard-dkms aiy-voicebonnet-routes
            sudo apt-get install leds-ktd202x-dkms

            # make soundcard recognizable
            sudo sed -i \
                -e "s/^dtparam=audio=on/#\0/" \
                -e "s/^#\(dtparam=i2s=on\)/\1/" \
                /boot/config.txt
            grep -q -F "dtoverlay=i2s-mmap" /boot/config.txt || sudo echo "dtoverlay=i2s-mmap" | sudo tee -a /boot/config.txt
            grep -q -F "dtoverlay=googlevoicehat-soundcard" /boot/config.txt || sudo echo "dtoverlay=googlevoicehat-soundcard" | sudo tee -a /boot/config.txt

            # make changes to profile.yml
            sudo sed -i \
                -e "s/aplay -Dhw:0,0 %1/aplay %1/" \
                -e "s/mpg123 -a hw:0,0 %1/mpg123 %1/" \
                ~/.naomi/configs/profile.yml

            # Install asound.conf
            sudo cp ~/.naomi/scripts/AIY-asound.conf ~/.naomi/configs/asound.conf

            # rebuild venv
            ~/.naomi/configs/naobian-setup

            echo -e "\e[1;36m[\e[1;34m!\e[1;36m] Reboot is needed!\e[0m"
            break
            ;;

        esac
    done

    lvl=7
    echo -e "\e[1;36m"
    echo "Let's test and adjust the volume:"
    echo "  1-9) Set volume level (1-quietest, 9=loudest)"
    echo "  T)est"
    echo "  R)eboot (needed if you just installed Google Voice Hat or plugged in a USB speaker)"
    echo "  D)one!"
    while true; do
        echo -n -e "\r\e[1;36mLevel [\e[1;35m1\e[1;36m-\e[1;35m9\e[1;36m/\e[1;35mT\e[1;36m/\e[1;35mD\e[1;36m/\e[1;35mR\e[1;36m]: \e[0m${lvl}          \b\b\b\b\b\b\b\b\b\b"
        read -N1 -s key
        case $key in
         [1-9])
            lvl=$key
            # Set volume between 19% and 99%.
            amixer set Master "${lvl}9%" > /dev/null
            echo -e -n "\b$lvl PLAYING"
            aplay ~/Naomi/naomi/data/audio/beep_hi.wav
            aplay ~/Naomi/naomi/data/audio/beep_lo.wav
            ;;
         [Rr])
            echo -e "\e[1;32mRebooting..."
            sudo reboot
            ;;
         [Tt])
            amixer set Master '${lvl}9%' > /dev/null
            echo -e -n "\b$lvl PLAYING"
            aplay ~/Naomi/naomi/data/audio/beep_hi.wav
            aplay ~/Naomi/naomi/data/audio/beep_lo.wav
            ;;
         [Dd])
            echo -e "\e[1;32mSaving..."
            break
            ;;
      esac
    done
    echo "amixer set PCM "$lvl"9%" >> ~/.naomi/scripts/audio-setup.sh

    echo -e "\e[1;36m"
    echo "The final step is Microphone configuration:"
    echo "As a voice assistant, Naomi needs to access a microphone to operate."

    while true; do
        echo -e "\e[1;36m"
        echo "Please ensure your microphone is connected and select from the following"
        echo "list of microphones:"
        echo "  1) PlayStation Eye (USB)"
        echo "  2) Blue Snowball ICE (USB)"
        echo "  3) Google AIY Voice HAT and microphone board (Voice Kit v1)"
        echo "  4) Matrix Voice HAT."
        echo "  5) Other (might work... might not -- good luck!)"
        echo -n -e "\e[1;36mChoice [\e[1;35m1\e[1;36m-\e[1;35m5\e[1;36m]: \e[0m"
        echo
        while true; do
            read -N1 -s key
            case $key in
             1)
                echo -e "\e[1;32m$key - PS Eye"
                # nothing to do, this is the default
                break
                ;;
             2)
                echo -e "\e[1;32m$key - Blue Snoball"
                # nothing to do, this is the default
                break
                ;;
             3)
                echo -e "\e[1;32m$key - Google AIY Voice Hat"
                break
                ;;
             4)
                echo -e "\e[1;32m$key - Matrix Voice Hat"
                echo -e "\e[1;36mThe setup script for Matrix Voice Hat will run at the end of"
                echo "The setup wizard. Press any key to continue..."
                read -N1 -s anykey
                touch setup_matrix
                skip_mic_test=true
                skip_last_prompt=true
                break
                ;;
             5)
                echo -e "\e[1;32m$key - Other"
                echo -e "\e[1;36mOther microphone _might_ work, but there are no guarantees."
                echo "We'll run the tests, but you are on your own.  If you have"
                echo "issues, the most likely cause is an incompatible microphone."
                echo "The PS Eye is cheap -- save yourself hassle and just buy one!"
                break
                ;;
            esac
        done

        if [ ! $skip_mic_test ]; then
            echo -e "\e[1;36m"
            echo "Testing microphone..."
            echo "In a few seconds you will see a prompt to start talking."
            echo "Say something like 'testing 1 2 3 4 5 6 7 8 9 10'.  After"
            echo "10 seconds, the sound heard through the microphone will be played back."
            echo
            echo "Press any key to begin the test..."
            sleep 1
            read -N1 -s key

            echo
            echo -e "\e[1;32mAudio Recoding starts in 3 seconds...\e[0m"
            sleep 3
            arecord  -r16000 -fS16_LE -c1 -d10 audiotest.wav
            echo
            echo -e "\e[1;32mRecoding Playback starts in 3 seconds...\e[0m"
            sleep 3
            aplay audiotest.wav

            retry_mic=0
            echo -e "\e[1;36m"
            echo -e "\e[1;36m[\e[1;33m?\e[1;36m] Did you hear yourself in the audio? \e[0m"
            echo -e "\e[1;36m"
            echo "  1) Yes!"
            echo "  2) No, let's repeat the test."
            echo "  3) No :(   Let's move on and I'll mess with the microphone later."
            echo -n -e "\e[1;36mChoice [\e[1;35m1\e[1;36m-\e[1;35m3\e[1;36m]: \e[0m"
            while true; do
                read -N1 -s key
                case $key in
                [1])
                    echo -e "\e[1;32m$key - Yes, good to go"
                    break
                    ;;
                [2])
                    echo -e "\e[1;32m$key - No, trying again"
                    echo
                    retry_mic=1
                    break
                    ;;
                [3])
                    echo -e "\e[1;32m$key - No, I give up and will use command line only (for now)!"
                    break
                    ;;
                esac
            done

            if [ $retry_mic -eq 0 ] ; then
                break
            fi

        else
            break
        fi
    done

    echo -e "\e[1;36m"
    echo "========================================================================="
    echo "NAOMI SETUP:"
    echo "Naomi is continuously updated.  For most users it is recommended that"
    echo "you run on the 'master' branch -- which always holds stable builds."
    echo "Note: 'dev' comes with automatic updates."
    echo -e "\e[1;36m"
    echo "  1) Use the recommendations ('master')"
    echo "  2) I'm a core developer, put me on 'dev'"
    echo -n -e "\e[1;36mChoice [\e[1;35m1\e[1;36m-\e[1;35m2\e[1;36m]: \e[0m"
    while true; do
        read -N1 -s key
        case $key in
         1)
            echo -e "\e[1;32m$key - Easy street, 'master'"
            echo '{"use_branch":"master", "auto_update": false}' > ~/.naomi/configs/.naobian_options.json
            cd ~/Naomi
            git checkout master
            cd ..
            break
            ;;
         2)
            echo -e "\e[1;32m$key - I know what I'm doing and am a responsible human."
            echo '{"use_branch":"dev", "auto_update": true}' > ~/.naomi/configs/.naobian_options.json
            cd ~/Naomi
            git checkout dev
            cd ..
            break
            ;;
        esac
    done

    echo -e "\e[1;36m"
    echo "========================================================================="
    echo "SECURITY SETUP:"
    echo "Let's examine a few security settings."
    echo
    echo "By default, Raspbian is configured to not require a password to perform"
    echo "actions as root (e.g. 'sudo ...').  This allows any application on the"
    echo "pi to have full access to the system.  This can make some development"
    echo "tasks easy, but is less secure.  Would you like to remain with this default"
    echo "setup or would you lke to enable standard 'sudo' password behavior?"
    echo -e "\e[1;36m"
    echo "  1) Stick with normal Raspian configuration, no password for 'sudo'"
    echo "  2) Require a password for 'sudo' actions."
    echo -n -e "\e[1;36mChoice [\e[1;35m1\e[1;36m-\e[1;35m2\e[1;36m]: \e[0m"
    require_sudo=0
    while true; do
        read -N1 -s key
        case $key in
         [1])
            echo -e "\e[1;32m$key - No password"
            require_sudo=0
            break
            ;;
         [2])
            echo -e "\e[1;32m$key - Enabling password protection for 'sudo'"
            require_sudo=1
            break
            ;;
        esac
    done

    echo -e "\e[1;36m"
    echo -e "Unlike standard Raspbian which has a user \e[1;33m'pi' \e[1;36mwith a password \e[1;33m'raspberry',\e[1;36m"
    echo "the Naobian image uses the following as default username and password:"
    echo -e "\e[1;36m  Default user:      \e[1;92mpi"
    echo -e "\e[1;36m  Default password:  \e[1;92mNaobian"
    echo -e "\e[1;36mAs a network connected device, having a unique password significantly"
    echo "enhances your security and thwarts the majority of hacking attempts."
    echo "We recommend setting a unique password for any device, especially one"
    echo "that is exposed directly to the internet."
    echo " "
    echo -e "\e[1;36m[\e[1;33m?\e[1;36m] Would you like to enter a new password? \e[0m"
    echo -e "\e[1;36m"
    echo "  Y)es, prompt me for a new password"
    echo "  N)o, stick with the default password of 'Naobian'"
    echo -n -e "\e[1;36mChoice [\e[1;35mY\e[1;36m/\e[1;35mN\e[1;36m]: \e[0m"
    while true; do
        read -N1 -s key
        case $key in
        [Yy])
            echo -e "\e[1;32m$key - changing password"
            user_pwd=0
            user_confirm=1
            echo -n -e "\e[1;36mEnter your new password (characters WILL NOT appear): \e[0m"
            read -s user_pwd
            echo
            echo -n -e "\e[1;36mEnter your new password again: \e[0m"
            read -s user_confirm
            echo
            if [ "$user_pwd" = "$user_confirm" ]
            then
                # Change 'pi' user password
                echo "pi:$user_pwd" | sudo chpasswd
                break
            else
                echo -e "\e[1;31mPasswords didn't match."
            fi
            ;;
        [Nn])
           echo -e "\e[1;32m$key - Using password 'Naobian'"
           break
           ;;
        esac
    done

    if [ $require_sudo -eq 1 ]
    then
        echo "pi ALL=(ALL) ALL" | sudo tee /etc/sudoers.d/010_pi-nopasswd
    fi

    if [ ! $skip_last_prompt ]; then
        echo -e "\e[1;36m"
        echo "========================================================================="
        echo
        echo "That's all, setup is complete!  Now we'll pull the latest software"
        echo "updates and start Naomi."
        echo
        echo -e "To rerun this setup, type \e[1;35m'naobian-setup-wizard' \e[1;36mand reboot."
        echo
        echo -e "\e[1;36mPress any key to launch Naomi..."
        read -N1 -s anykey
    fi
}

if ! ls /etc/ssh/ssh_host_* 1> /dev/null 2>&1; then
    echo -e "\e[1;32mRegenerating SSH Host Keys...\e[0m"
    sudo dpkg-reconfigure openssh-server
    sudo systemctl restart ssh
    echo
    echo -e "\e[1;36m[\e[1;34m!\e[1;36m] New ssh host keys were created, rebooting in 3 seconds\e[0m"
    sleep 3
    sudo reboot
fi

echo -e "\e[33m"
echo "      ___           ___           ___           ___                  "
echo "     /\__\         /\  \         /\  \         /\__\          ___    "
echo "    /::|  |       /::\  \       /::\  \       /::|  |        /\  \   "
echo "   /:|:|  |      /:/\:\  \     /:/\:\  \     /:|:|  |        \:\  \  "
echo "  /:/|:|  |__   /::\~\:\  \   /:/  \:\  \   /:/|:|__|__      /::\__\ "
echo " /:/ |:| /\__\ /:/\:\ \:\__\ /:/__/ \:\__\ /:/ |::::\__\  __/:/\/__/ "
echo " \/__|:|/:/  / \/__\:\/:/  / \:\  \ /:/  / \/__/~~/:/  / /\/:/  /    "
echo "     |:/:/  /       \::/  /   \:\  /:/  /        /:/  /  \::/__/     "
echo "     |::/  /        /:/  /     \:\/:/  /        /:/  /    \:\__\     "
echo "     /:/  /        /:/  /       \::/  /        /:/  /      \/__/     "
echo "     \/__/         \/__/         \/__/         \/__/                 "
echo -e "\e[94m"
echo "                _   _             _     _                            "
echo "               | \ | |           | |   (_)                           "
echo "               |  \| | __ _  ___ | |__  _  __ _ _ __                 "
echo "               | .   |/ _  |/ _ \| '_ \| |/ _  |  _ \                "
echo "               | |\  | (_| | (_) | |_) | | (_| | | | |               "
echo "               |_| \_|\__,_|\___/|_.__/|_|\__,_|_| |_|               "
echo -e "\e[0m"

alias naomi-setup-wizard="cd ~ && touch first_run && source ~/.naomi/scripts/auto_start.sh"

if [ -f ~/first_run ]
then
    echo -e "\e[1;36m"
    echo "Welcome to Naobian. This image is designed to make getting started with"
    echo "Naomi quick and easy. Would you like help setting up your system?"
    echo
    echo "  Y)es, I'd like the guided setup."
    echo "  N)ope, just get me a command line and get out of my way!"
    echo
    echo -n -e "\e[1;36mChoice [\e[1;35mY\e[1;36m/\e[1;35mN\e[1;36m]: \e[0m"
    while true; do
        read -N1 -s key
        case $key in
         [Nn])
            echo $key
            echo
            echo -e "\e[1;92mAlright, have fun!"
            echo
            echo -e "\e[1;35mNOTE: \e[1;36mIf you decide to use the wizard later, just type \e[1;35m'naomi-setup-wizard'\e[1;36m"
            echo -e "      and reboot.\e[0m"
            break
            break
            ;;
         [Yy])
            echo $key
            echo
            setup_wizard
            break
            ;;
        esac
    done

   # Delete to flag setup is complete
    rm ~/first_run
fi

# Matrix Voice Hat Setup
if [ -f setup_matrix ]
then
    cd ~/.naomi/scripts
    ./audio-setup-matrix.sh
fi


if [ "$SSH_CLIENT" == "" ] && [ "$(/usr/bin/tty)" = "/dev/tty1" ];
then
    # Default to analog audio jack at 75% volume
    amixer cset numid=3 "1" > /dev/null
    amixer set PCM 75% > /dev/null

    # Check for custom audio setup
    if [ -f ~/.naomi/scripts/audio-setup.sh ]
    then
        source ~/.naomi/scripts/audio-setup.sh
        cd ~
    fi

    # verify network settings
    network_setup
    if [[ $? -eq 1 ]]
    then
        echo -e "\e[1;36m[\e[1;34m!\e[1;36m] Restarting in 3 seconds\e[0m"
        sleep 3
        sudo reboot
    fi

    # Look for internet connection.
    if ping -q -c 1 -W 1 1.1.1.1 >/dev/null 2>&1
    then
        echo -e "\e[1;32mChecking for updates to Naobian environment...\e[0m"
        cd /tmp
        wget -N -q https://raw.githubusercontent.com/AustinCasteel/NaobianDevelopment/master/home/pi/.naomi/scripts/version >/dev/null
        if [ $? -eq 0 ]
        then
            if [ ! -f ~/.naomi/scripts/version ] ; then
                echo "unknown" > ~/.naomi/scripts/version
            fi

            cmp /tmp/version ~/.naomi/scripts/version
            if  [ $? -eq 1 ]
            then
                echo -e "\e[1;32mUpdate found, downloadling new Naobian scripts!\e[0m"

                wget -N -q https://raw.githubusercontent.com/AustinCasteel/NaobianDevelopment/master/home/pi/.naomi/scripts/update.sh
                if [ $? -eq 0 ]
                then
                    source .naomi/scripts/update.sh
                    cp /tmp/version ~/.naomi/scripts/version

                    echo -e "\e[1;36m[\e[1;34m!\e[1;36m] Restarting in 3 seconds\e[0m"
                    sleep 3
                    sudo reboot now
                else
                    echo -e "\e[1;36m[\e[1;31m!\e[1;36m] \e[1;31mERROR: \e[1;36mFailed to download update script.\e[0m"
                fi
            fi
        fi

        echo -e "\e[1;32mChecking for Naomi Updates...\e[0m"
        cd ~/Naomi
        git pull
        cd ~
    fi

    # Launch Naomi
    # source ~/Naomi/Naomi.py
else
    # running in SSH session
    echo
fi