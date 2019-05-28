#!/bin/bash
##########################################################################
# pocketsphinx-setup.sh
# This script is executed by naomi-setup.sh during the setup process and when
# the user invokes the script with 'bash ~/.naomi/scripts/pocketsphinx-setup.sh'
##########################################################################

# Installing & Building openfst
    echo
    echo -e "\e[1;32mInstalling & Building openfst...\e[0m"
    cd ~
    sudo apt install gcc g++ make python-pip autoconf libtool -y
    wget http://www.openfst.org/twiki/pub/FST/FstDownload/openfst-1.6.9.tar.gz
    tar -zxvf openfst-1.6.9.tar.gz
    cd openfst-1.6.9
    autoreconf -i
    ./configure --enable-static --enable-shared --enable-far --enable-lookahead-fsts --enable-const-fsts --enable-pdt --enable-ngram-fsts --enable-linear-fsts --prefix=/usr
    make
    sudo make install
    cd ~

# Installing & Building mitlm-0.4.2
    echo
    echo -e "\e[1;32mInstalling & Building mitlm-0.4.2...\e[0m"
    cd ~
    sudo apt install git gfortran autoconf-archive -y
    git clone https://github.com/mitlm/mitlm.git
    cd mitlm
    ./autogen.sh
    make
    sudo make install
    sudo ldconfig
    cd ~

# Installing & Building phonetisaurus
    echo
    echo -e "\e[1;32mInstalling & Building phonetisaurus...\e[0m"
    cd ~
    git clone https://github.com/AdolfVonKleist/Phonetisaurus.git
    cd Phonetisaurus
    ./configure --enable-python
    make
    sudo make install
    cd python
    cp -iv ../.libs/Phonetisaurus.so ./
    sudo python3 setup.py install
    cd ~

# Installing & Building cmuclmtk
    echo
    echo -e "\e[1;32mInstalling & Building cmuclmtk...\e[0m"
    cd ~
    sudo apt install subversion -y
    svn co https://svn.code.sf.net/p/cmusphinx/code/trunk/cmuclmtk/
    cd cmuclmtk
    ./autogen.sh
    make
    sudo make install
    sudo ldconfig
    cd ~
    sudo pip install cmuclmtk
    cd ~

# Installing & Building sphinxbase
    echo
    echo -e "\e[1;32mInstalling & Building sphinxbase...\e[0m"
    cd ~
    sudo apt install swig libasound2-dev bison -y
    git clone --recursive https://github.com/cmusphinx/pocketsphinx-python.git
    cd pocketsphinx-python/sphinxbase
    ./autogen.sh
    make
    sudo make install
    cd ..

# Installing & Building pocketsphinx
    echo
    echo -e "\e[1;32mInstalling & Building pocketsphinx...\e[0m"
    cd ~
    cd pocketsphinx-python/pocketsphinx
    ./autogen.sh
    make
    sudo make install
    cd ..

# Installing PocketSphinx library
    echo
    echo -e "\e[1;32mInstalling PocketSphinx library...\e[0m"
    cd ~
    cd pocketsphinx-python
    sudo python3 setup.py install

# Formatting cmudict.dict and train model.fst
    echo
    echo -e "\e[1;32mFormatting cmudict.dict and training model.fst...\e[0m"
    cd ~
    cd pocketsphinx-python/pocketsphinx/model/en-us
    cat cmudict-en-us.dict | perl -pe 's/^([^\s]*)\(([0-9]+)\)/\1/;s/\s+/ /g;s/^\s+//;s/\s+$//; @_=split(/\s+/); $w=shift(@_);$_=$w."\t".join(" ",@_)."\n";' > cmudict-en-us.formatted.dict
    phonetisaurus-train --lexicon cmudict-en-us.formatted.dict --seq2_del
    cd ~
