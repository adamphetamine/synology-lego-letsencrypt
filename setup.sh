#!/bin/sh

# let's figure out the current version of Acme Lego
lego_tag=$(curl -sL https://api.github.com/repos/go-acme/lego/releases/latest | jq -r ".tag_name")
echo -----------------------------------
echo Current version of Acme Lego is $lego_tag
echo -----------------------------------

# figure out the full name of the download to work around a stupid issue in path
# download_name=$lego_tag_linux_amd64.tar.gz
# echo name of file to download is $download_name
# Download it and print the current directory to the user
echo 'we are downloading Lego to ' $PWD
echo and the url is "https://github.com/go-acme/lego/releases/download/"$lego_tag/"lego_"$lego_tag"_linux_"$(dpkg --print-architecture).tar.gz

wget "https://github.com/go-acme/lego/releases/download/"$lego_tag/"lego_"$lego_tag"_linux_"$(dpkg --print-architecture).tar.gz

# unpack the binary
echo unpack the binary
tar xvzf lego_"$lego_tag"_linux_$(dpkg --print-architecture).tar.gz 

# create a new directory structure to hold the project
echo create a new directory structure to hold the project
sudo mkdir -p /usr/local/sbin

# Move the binary into position, update permissions and check it launches...
echo Move the binary into position
sudo mv ./lego /usr/local/sbin
echo update permissions
sudo chown root:root /usr/local/sbin/lego
# Make sure it works!
echo check it launches...
./lego --version

# get the custom.env to use with our variables
echo get the custom.env to use with our variables
wget https://raw.githubusercontent.com/adamphetamine/synology-lego-letsencrypt/main/custom.env


# get the renewal script so we can renew our certificates
echo get the renewal script so we can renew our certificates
wget https://raw.githubusercontent.com/adamphetamine/synology-lego-letsencrypt/main/le-renew.sh
chmod +x le-renew.sh

# create a directory to keep the Letencrypt bits- do we even need this?
# sudo su -
# mkdir letsencrypt
# chmod 700 letsencrypt
# cd letsencrypt

# tell the carbon unit at the keyboard to add their variables into the .env file

echo -----------------------------------
echo We are finished!
echo -----------------------------------
echo Now go and add your custom variables to the file called custom.env
echo Which is located here '/usr/local/sbin/lego'
echo
echo -----------------------------------
echo Your setup WILL FAIL unless you complete this
echo -----------------------------------
echo
echo update the variables
echo run the command once to get your certs
echo test the move-certs script
echo and setup a cron schedule to trigger the le-renew script
echo
echo Thanks you, and good night. Exiting
