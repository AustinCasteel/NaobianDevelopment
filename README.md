# NaobianDevelopment

These are the steps followed to create the base image for Naobian on Raspbian Stretch.  This was performed on a Raspberry Pi 3B+

NOTE: At startup Naobian will automatically update itself to the latest version of released software and scripts.


### Start with the official Raspbian Image
* Download and burn [Raspbian Stretch Lite](https://downloads.raspberrypi.org/raspbian_lite_latest).
* Install into Raspberry Pi and boot

### General configuration
  - ```sudo raspi-config```
  - 1 Change User Password
      - Enter and verify ```Naobian```
  - 2 Network Options
      - N1 Hostname
        - Enter ```Naobian```
      - N3 Network interface names
        - pick *Yes*
  - 3 Boot Options
      - B2 Wait for network
        - pick *No*
  - 4 Localization Options
      - I3 Change Keyboard Layout
          - Pick *Generic 104-key PC*
          - Pick *Other*
          - Pick *English (US)*
          - Pick *English (US)*
          - Pick *The default for the keyboard layout*
          - Pick *No compose key*
      - I4 Change Wi-fi Country
          - Pick *United States*
  - 5 Interfacing Options
      - P2 SSH
          - Pick *Yes*

### Set the device to not use locale settings provided by ssh
* ```sudo nano /etc/ssh/sshd_config``` and comment out the line (prefix with '#')
  ```
  AcceptEnv LANG LC_*
  ```

### Connect to the network
* Either plug in Ethernet or
  * ```sudo nano /etc/wpa_supplicant/wpa_supplicant.conf```
  * Enter network creds:
    ```
    network={
            ssid="NETWORK"
            psk="WIFI_PASSWORD"  # for one with password
            key_mgmt=NONE        # for open
    }
    ```

## Install Naobian scripts
* cd ~
* wget https://raw.githubusercontent.com/AustinCasteel/NaobianDevelopment/master/home/pi/.naomi/scripts/update.sh
* bash update.sh

**The update.sh script will perform all necessary steps to setup the img...**

Naobian will reboot, prompting the autostart but erroring itself out.
>Note: It is supposed to error out!

## Final steps
* Run ```. ~/.naomi/scripts/naomi-purge```
* Remove the SD card
* Create an IMG file named "Naobian_RELEASE-NUMBER.img"
* Compress the IMG using pishrink.sh










## Install Naomi script
* cd ~
* mkdir ~/Naomi
* cd ~/Naomi/
* wget https://raw.githubusercontent.com/AustinCasteel/NaobianDevelopment/NaomiSetup/home/pi/.naomi/scripts/naomi-setup2.sh
* bash naomi-setup2.sh