#!/bin/bash

#Remove the alias from the users environment file
sudo sed -i '/x735/d' /home/$USER/.bashrc
#Remove the soft shutdown script
sudo rm /usr/local/bin/x735softsd.sh -f


#Remove the power control script from rc.local
sudo sed -i '/x735/d' /etc/rc.local
#delete the power control script
sudo rm /etc/x735pwr.sh -f

#Remove the Fan Control Service
systemctl stop x735fan.service
systemctl disable x735fan.service
systemctl daemon-reload
systemctl reset-failed
rm /etc/systemd/system/x735fan.service -f

#delete the fan control script
sudo rm  /etc/x735fan.py -f

##Going to leave this one enabled for now
#Disable the pigpiod daemon
#sudo systemctl disable pigpiod