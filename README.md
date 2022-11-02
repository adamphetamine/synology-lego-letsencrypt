While debugging this script, I found another project that 1. Works and 2. is more elegant

So I'll probably shelve this project. Here it is-

https://github.com/JessThrysoee/synology-letsencrypt



</sad_panda_face>




# synology-lego-letsencrypt

automating SSL renewal for Synology NAS

Projects used

https://go-acme.github.io/lego/dns/cloudflare/


Here's the short version

get a token with the correct permissions from Cloudflare

Log into your Synology NAS using SSH and execute

wget https://raw.githubusercontent.com/adamphetamine/synology-lego-letsencrypt/main/setup.sh

chmod +x setup.sh

sudo sh ./setup.sh

This will download latest version of Lego, the custom.env file and the le-renew.sh script

custom.env you need to modify this file and add your Cloudflare email, token ID etc.

le-renew.sh for getting and renewing LetsEncrypt certs. Uses DNS challenge, doesn't require port 80 to be open

move-certs.sh will assist in moving certs into place and restart the web server if new certs are added- most oif this code is er, 'repurposed' from the Acme.sh project- thank you!

After running setup.sh you need to update your environment variables in custom.env. Then you can issue a command to get your certs in this format

If this is successful, run the move-certs.sh script to finalise the initial setup, then log into the web interface of your Synology NAS, add a new schedule and make it run le-renew.sh around once a month with an email to you if it fails twice. This should give you 30 days to fix any issues.




