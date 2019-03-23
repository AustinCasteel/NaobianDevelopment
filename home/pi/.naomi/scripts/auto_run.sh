#!/bin/bash
##########################################################################
# auto_run.sh
##########################################################################
# This script is executed by the .bashrc every time someone logs in to the
# system (including shelling in via SSH).

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
            echo "Network connection not found, press a key to setup via keyboard"
            echo "or plug in a network cable:"
            echo "  1) Basic wifi with SSID and password"
            echo "  2) Wifi with no password"
            echo "  3) Edit wpa_supplicant.conf directly"
            echo "  4) Force reboot"
            echo "  5) Skip network setup for now"
            echo -n "Choice [1-6]: "
            show_prompt=0
        fi

        read -N1 -s -t 1 pressed

        case $pressed in
         1)
            echo
            echo -n "Enter a network SSID: "
            read user_ssid
            echo -n "Enter the password: "
            read -s user_pwd
            echo
            echo -n "Enter the password again: "
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
            echo -n "Enter a network SSID: "
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
                echo "Reconfiguring WLAN0..."
                wpa_cli -i wlan0 reconfigure
                show_prompt=1
                sleep 3
            elif [[ $reset_wlan0 -eq 1 ]]
            then
                echo "Failed to connect to network."
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
        echo "Network connection detected!"
        should_reboot=0
    fi

    return $should_reboot
}

function setup_wizard() {

    # Handle internet connection
    network_setup
    if [[ $? -eq 1 ]]
    then
        echo "Rebooting..."
        sudo reboot
    fi

    # installs pulseaudio if not already installed
    if [ $(dpkg-query -W -f='${Status}' pulseaudio 2>/dev/null | grep -c "ok installed") -eq 0 ];
    then
        sudo apt-get install pulseaudio -y
    fi

    echo
    echo "========================================================================="
    echo "HARDWARE SETUP"
    echo "How do you want Naomi to output audio:"
    echo "  1) Speakers via 3.5mm output (aka the 'audio jack')"
    echo "  2) HDMI audio (e.g. a TV or monitor with built-in speakers)"
    echo "  3) USB audio (e.g. a USB soundcard or USB mic/speaker combo)"
    echo "  4) Google AIY Voice HAT and microphone board (Voice Kit v1)"
    echo -n "Choice [1-4]: "
    while true; do
        read -N1 -s key
        case $key in
         1)
            echo "$key - Analog audio"
            # audio out the analog speaker/headphone jack
            sudo amixer cset numid=3 "1" > /dev/null
            echo 'sudo amixer cset numid=3 "1" > /dev/null' >> ~/.naomi/scripts/audio_setup.sh
            break
            ;;
         2)
            echo "$key - HDMI audio"
            # audio out the HDMI port (e.g. TV speakers)
            sudo amixer cset numid=3 "2" > /dev/null
            echo 'sudo amixer cset numid=3 "2"  > /dev/null' >> ~/.naomi/scripts/audio_setup.sh
            break
            ;;
         3)
            echo "$key - USB audio"
            # audio out to the USB soundcard
            sudo amixer cset numid=3 "0" > /dev/null
            echo 'sudo amixer cset numid=3 "0"  > /dev/null' >> ~/.naomi/scripts/audio_setup.sh
            break
            ;;
         4)
            echo "$key - Google AIY Voice HAT and microphone board (Voice Kit v1)"
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
            ~/.naomi/configs/dev_setup

            echo "Reboot is needed !"
            break
            ;;

        esac
    done

    lvl=7
    echo
    echo "Let's test and adjust the volume:"
    echo "  1-9) Set volume level (1-quietest, 9=loudest)"
    echo "  T)est"
    echo "  R)eboot (needed if you just installed Google Voice Hat or plugged in a USB speaker)"
    echo "  D)one!"
    while true; do
        echo -n -e "\rLevel [1-9/T/D/R]: ${lvl}          \b\b\b\b\b\b\b\b\b\b"
        read -N1 -s key
        case $key in
         [1-9])
            lvl=$key
            # Set volume between 19% and 99%.  Lazily not allowing 100% :)
            amixer set Master "${lvl}9%" > /dev/null
            echo -e -n "\b$lvl PLAYING"
            speak "Test"
            ;;
         [Rr])
            echo "Rebooting..."
            sudo reboot
            ;;
         [Tt])
            amixer set Master '${lvl}9%' > /dev/null
            echo -e -n "\b$lvl PLAYING"
            speak "Test"
            ;;
         [Dd])
            echo " - Saving"
            break
            ;;
      esac
    done
    echo "amixer set PCM "$lvl"9%" >> ~/.naomi/scripts/audio_setup.sh

    echo
    echo "The final step is Microphone configuration:"
    echo "As a voice assistant, Naomi needs to access a microphone to operate."

    while true; do
        echo "Please ensure your microphone is connected and select from the following"
        echo "list of microphones:"
        echo "  1) PlayStation Eye (USB)"
        echo "  2) Blue Snoball ICE (USB)"
        echo "  3) Google AIY Voice HAT and microphone board (Voice Kit v1)"
        echo "  4) Matrix Voice HAT."
        echo "  5) Other (might work... might not -- good luck!)"
        echo -n "Choice [1-5]: "
        echo
        while true; do
            read -N1 -s key
            case $key in
             1)
                echo "$key - PS Eye"
                # nothing to do, this is the default
                break
                ;;
             2)
                echo "$key - Blue Snoball"
                # nothing to do, this is the default
                break
                ;;
             3)
                echo "$key - Google AIY Voice Hat"
                break
                ;;
             4)
                echo "$key - Matrix Voice Hat"
                echo "The setup script for Matrix Voice Hat will run at the end of"
                echo "The setup wizard. Press any key to continue..."
                read -N1 -s anykey
                touch setup_matrix
                skip_mic_test=true
                skip_last_prompt=true
                break
                ;;
             5)
                echo "$key - Other"
                echo "Other microphone _might_ work, but there are no guarantees."
                echo "We'll run the tests, but you are on your own.  If you have"
                echo "issues, the most likely cause is an incompatible microphone."
                echo "The PS Eye is cheap -- save yourself hassle and just buy one!"
                break
                ;;
            esac
        done

        if [ ! $skip_mic_test ]; then
            echo
            echo "Testing microphone..."
            echo "In a few seconds you will see some initialization messages, then a prompt"
            echo "to speak.  Say something like 'testing 1 2 3 4 5 6 7 8 9 10'.  After"
            echo "10 seconds, the sound heard through the microphone will be played back."
            echo
            echo "Press any key to begin the test..."
            sleep 1
            read -N1 -s key

            # Launch Naomi audio test
            ~/.naomi/scripts/audio_test.sh

            retry_mic=0
            echo
            echo "Did you hear the yourself in the audio?"
            echo "  1) Yes!"
            echo "  2) No, let's repeat the test."
            echo "  3) No :(   Let's move on and I'll mess with the microphone later."
            echo -n "Choice [1-3]: "
            while true; do
                read -N1 -s key
                case $key in
                [1])
                    echo "$key - Yes, good to go"
                    break
                    ;;
                [2])
                    echo "$key - No, trying again"
                    echo
                    retry_mic=1
                    break
                    ;;
                [3])
                    echo "$key - No, I give up and will use command line only (for now)!"
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

    echo "========================================================================="
    echo "NAOMI SETUP:"
    echo "Naomi is continuously updated.  For most users it is recommended that"
    echo "you run on the 'master' branch -- which always holds stable builds."
    echo "  1) Use the recommendations ('master')"
    echo "  2) I'm a core developer, put me on 'dev'"
    echo -n "Choice [1-2]: "
    while true; do
        read -N1 -s key
        case $key in
         1)
            echo "$key - Easy street, 'master'"
            echo '{"use_branch":"master", "auto_update": false}' > ~/.naomi/configs/.dev_options.json
            cd ~/Naomi
            git checkout master
            cd ..
            break
            ;;
         2)
            echo "$key - I know what I'm doing and am a responsible human."
            echo '{"use_branch":"dev", "auto_update": false}' > ~/.naomi/configs/.dev_options.json
            cd ~/Naomi
            git checkout dev
            cd ..
            break
            ;;
        esac
    done


    echo "========================================================================="
    echo "SECURITY SETUP:"
    echo "Let's examine a few security settings."
    echo
    echo "By default, Raspbian is configured to not require a password to perform"
    echo "actions as root (e.g. 'sudo ...').  This allows any application on the"
    echo "pi to have full access to the system.  This can make some development"
    echo "tasks easy, but is less secure.  Would you like to remain with this default"
    echo "setup or would you lke to enable standard 'sudo' password behavior?"
    echo "  1) Stick with normal Raspian configuration, no password for 'sudo'"
    echo "  2) Require a password for 'sudo' actions."
    echo -n "Choice [1-2]: "
    require_sudo=0
    while true; do
        read -N1 -s key
        case $key in
         [1])
            echo "$key - No password"
            # nothing to do, this is the default
            require_sudo=0
            break
            ;;
         [2])
            echo "$key - Enabling password protection for 'sudo'"
            require_sudo=1
            break
            ;;
        esac
    done


    echo "Unlike standard Raspbian which has a user 'pi' with a password 'raspberry',"
    echo "the Naobian image uses the following as default username and password:"
    echo "  Default user:      pi"
    echo "  Default password:  Naobian"
    echo "As a network connected device, having a unique password significantly"
    echo "enhances your security and thwarts the majority of hacking attempts."
    echo "We recommend setting a unique password for any device, especially one"
    echo "that is exposed directly to the internet."
    echo " "
    echo "Would you like to enter a new password?"
    echo "  Y)es, prompt me for a new password"
    echo "  N)o, stick with the default password of 'Naobian'"
    echo -n "Choice [Y,N]:"
    while true; do
        read -N1 -s key
        case $key in
        [Yy])
            echo "$key - changing password"
            user_pwd=0
            user_confirm=1
            echo -n "Enter your new password (characters WILL NOT appear): "
            read -s user_pwd
            echo
            echo -n "Enter your new password again: "
            read -s user_confirm
            echo
            if [ "$user_pwd" = "$user_confirm" ]
            then
                # Change 'pi' user password
                echo "pi:$user_pwd" | sudo chpasswd
                break
            else
                echo "Passwords didn't match."
            fi
            ;;
        [Nn])
           echo "$key - Using password 'Naobian'"
           break
           ;;
        esac
    done

    if [ $require_sudo -eq 1 ]
    then
        echo "pi ALL=(ALL) ALL" | sudo tee /etc/sudoers.d/010_pi-nopasswd
    fi

    if [ ! $skip_last_prompt ]; then
        echo
        echo "========================================================================="
        echo
        echo "That's all, setup is complete!  Now we'll pull down the latest software"
        echo "updates and start Naomi."
        echo
        echo "To rerun this setup, type 'naobian-setup-wizard' and reboot."
        echo
        echo "Press any key to launch Naomi..."
        read -N1 -s anykey
    fi
}

######################

# this will regenerate new ssh keys on boot
# if keys don't exist. This is needed because
# ./bin/naomi-purge will delete old keys for
# security measures
if ! ls /etc/ssh/ssh_host_* 1> /dev/null 2>&1; then
    echo "Regenerating ssh host keys"
    sudo dpkg-reconfigure openssh-server
    sudo systemctl restart ssh
    echo "New ssh host keys were created. this requires a reboot"
    sudo reboot
fi

echo -e "\e[32m"
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
echo "                _   _             _     _                            "
echo "               | \ | |           | |   (_)                           "
echo "               |  \| | __ _  ___ | |__  _  __ _ _ __                 "
echo "               | .   |/ _  |/ _ \| '_ \| |/ _  |  _ \                "
echo "               | |\  | (_| | (_) | |_) | | (_| | | | |               "
echo "               |_| \_|\__,_|\___/|_.__/|_|\__,_|_| |_|               "
echo -e "\e[0m"

alias naomi-setup-wizard="cd ~ && touch first_run && source auto_run.sh"

if [ -f ~/first_run ]
then
    echo
    echo "Welcome to Naobian.  This image is designed to make getting started with"
    echo "Naomi quick and easy.  Would you like help setting up your system?"
    echo "  Y)es, I'd like the guided setup."
    echo "  N)ope, just get me a command line and get out of my way!"
    echo -n "Choice [Y/N]: "
    while true; do
        read -N1 -s key
        case $key in
         [Nn])
            echo $key
            echo
            echo "Alright, have fun!"
            echo "NOTE: If you decide to use the wizard later, just type 'naomi-setup-wizard'"
            echo "      and reboot."
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
    if [ ! -f matrix_setup_state.txt ]
    then
        echo ""
        echo "========================================================================="
        echo "Setting up Matrix Voice Hat. This will install the matrixio-kernel-modules and pulseaudio"
        echo "This process is automatic, but requires rebooting three times. Please be patient"
        echo "Press any key to continue..."
        read -N1 -s anykey
    else
        echo "Press any key to continue setting up Matrix Voice HAT"
        read -N1 -s anykey
    fi

    if [ ! -f matrix_setup_state.txt ]
    then
        echo "Adding Matrix repo and installing packages..."
        # add repo
        curl https://apt.matrix.one/doc/apt-key.gpg | sudo apt-key add -
        echo "deb https://apt.matrix.one/raspbian $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/matrixlabs.list
        sudo apt-get update -y
        sudo apt-get upgrade -y

        echo "stage-1" > matrix_setup_state.txt
        echo "Rebooting to apply kernel updates, the installation will resume afterwards"
        read -p "Press enter to continue reboot"
        sudo reboot
    else
        matrix_setup_state=$( cat matrix_setup_state.txt)
    fi

    if [ $matrix_setup_state == "stage-1" ]
    then
        echo "Installing matrixio-kernel-modules..."
        sudo apt install matrixio-kernel-modules -y

        echo "installing pulseaudio"
        sudo apt-get install pulseaudio -y
        
        echo "Rebooting to apply audio subsystem changes, the installation will continue afterwards."
        read -p "Press enter to continue reboot"
        echo "stage-2" > matrix_setup_state.txt
        sudo reboot
    fi

    if [ $matrix_setup_state == "stage-2" ]
    then
        echo "Setting Matrix as standard microphone..."
        echo "========================================================================="
        pactl list sources short
        sleep 5
        pulseaudio -k
        pactl set-default-source 2
        pulseaudio --start
        amixer set Master 99%
        echo "amixer set Master 99%" >> ~/.naomi/scripts/audio_setup.sh
        sleep 2
        amixer

        naomi-mic-test
        
        read -p "You should have heard the recording playback. Press enter to continue"

        echo "========================================================================="
        echo "Updating the python virtual environment"
        bash ~/.naomi/scripts/dev_setup.sh

        echo "stage-3" > matrix_setup_state.txt
        read -p "Your Matrix microphone is now setup! Press enter to perform the final reboot and start Naomi."
        sudo reboot
    fi

    rm ~/matrix_setup_state.txt
    rm ~/setup_matrix
fi


if [ "$SSH_CLIENT" == "" ] && [ "$(/usr/bin/tty)" = "/dev/tty1" ];
then
    # running at the local console (e.g. plugged into the HDMI output)

    # Make sure the audio is being output reasonably.  This can be set
    # to match user preference in audio_setup.sh.  DON'T EDIT HERE,
    # the script will likely be overwritten during updates.
    #
    # Default to analog audio jack at 75% volume
    amixer cset numid=3 "1" > /dev/null
    amixer set PCM 75% > /dev/null

    # Check for custom audio setup
    if [ -f ~/.naomi/scripts/audio_setup.sh ]
    then
        source ~/.naomi/scripts/audio_setup.sh
        cd ~
    fi

    # verify network settings
    network_setup
    if [[ $? -eq 1 ]]
    then
        echo "Rebooting..."
        sudo reboot
    fi

    # Look for internet connection.
    if ping -q -c 1 -W 1 1.1.1.1 >/dev/null 2>&1
    then
        echo "**** Checking for updates to Naobian environment"
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
                # Versions don't match...update needed
                echo "**** Update found, downloadling new Naobian scripts!"
                speak "Updating Naobian, please hold on."


                wget -N -q https://raw.githubusercontent.com/AustinCasteel/NaobianDevelopment/master/home/pi/.naomi/scripts/update.sh
                if [ $? -eq 0 ]
                then
                    source .naomi/scripts/update.sh
                    cp /tmp/version ~/.naomi/scripts/version

                    # restart
                    echo "Restarting..."
                    speak "Update complete, restarting."
                    sudo reboot now
                else
                    echo "ERROR: Failed to download update script."
                fi
            fi
        fi

        echo -n "Checking for naomi updates..."
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