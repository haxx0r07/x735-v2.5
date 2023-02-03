#!/bin/bash
#IMPORTANT! This script is only for the X735 V2.5
#x725 V2.5 Powering on /reboot /full shutdown through hardware





#Build out the power control script at /etc/x735pwr.sh
echo "Creating the power control script at /etc/x735pwr.sh"
sudo cat > /etc/x735pwr.sh <<EOF
#!/bin/bash

SHUTDOWN=5
REBOOTPULSEMINIMUM=200
REBOOTPULSEMAXIMUM=600
echo "$SHUTDOWN" > /sys/class/gpio/export
echo "in" > /sys/class/gpio/gpio$SHUTDOWN/direction
BOOT=12
echo "$BOOT" > /sys/class/gpio/export
echo "out" > /sys/class/gpio/gpio$BOOT/direction
echo "1" > /sys/class/gpio/gpio$BOOT/value

echo "X735 Shutting down..."

while [ 1 ]; do
  shutdownSignal=$(cat /sys/class/gpio/gpio$SHUTDOWN/value)
  if [ $shutdownSignal = 0 ]; then
    /bin/sleep 0.2
  else
    pulseStart=$(date +%s%N | cut -b1-13)
    while [ $shutdownSignal = 1 ]; do
      /bin/sleep 0.02
      if [ $(($(date +%s%N | cut -b1-13)-$pulseStart)) -gt $REBOOTPULSEMAXIMUM ]; then
        echo "X735 Shutting down", SHUTDOWN, ", halting Rpi ..."
        sudo poweroff
        exit
      fi
      shutdownSignal=$(cat /sys/class/gpio/gpio$SHUTDOWN/value)
    done
    if [ $(($(date +%s%N | cut -b1-13)-$pulseStart)) -gt $REBOOTPULSEMINIMUM ]; then
      echo "X735 Rebooting", SHUTDOWN, ", recycling Rpi ..."
      sudo reboot
      exit
    fi
  fi
done
EOF
#File build out complete

sudo chmod +x /etc/x735pwr.sh

#Currently added to rc.local file for execution upon boot. 
#Would this be better as a systemd service?
#if so use the fan service as a template
sudo sed -i '$ i /etc/x735pwr.sh &' /etc/rc.local





#Buit out the soft shutdown script at /usr/local/bin/x735softsd.sh
echo "Creating the soft shutdown command script at /usr/local/bin/x735softsd.sh"
sudo cat > /usr/local/bin/x735softsd.sh <<EOF
#!/bin/bash

BUTTON=20

echo "$BUTTON" > /sys/class/gpio/export;
echo "out" > /sys/class/gpio/gpio$BUTTON/direction
echo "1" > /sys/class/gpio/gpio$BUTTON/value

SLEEP=${1:-4}

re='^[0-9\.]+$'
if ! [[ $SLEEP =~ $re ]] ; then
   echo "error: sleep time not a number" >&2; exit 1
fi

echo "X735 Shutting down..."
/bin/sleep $SLEEP

echo "0" > /sys/class/gpio/gpio$BUTTON/value
EOF
#File build out complete

sudo chmod +x /usr/local/bin/x735softsd.sh
#USER_RUN_FILE=/home/$USER/.bashrc
#CUR_DIR=$(pwd)
echo "Adding alias 'x735off' to the $USER user's environment, this can be used to initiate a soft shutdown at anytime"
sudo echo "alias x735off='sudo x735softsd.sh'" >> /home/$USER/.bashrc





#Build out the fan control script at /etc/x735fan.py
echo "Creating the fan control script at /etc/x735fan.py"
sudo cat > /etc/x735fan.py <<EOF
#!/usr/bin/python 
import pigpio
import time

servo = 13

pwm = pigpio.pi()
pwm.set_mode(servo, pigpio.OUTPUT)
pwm.set_PWM_frequency( servo, 25000 )
pwm.set_PWM_range(servo, 100)
while(1):
     #get CPU temp
     file = open("/sys/class/thermal/thermal_zone0/temp")
     temp = float(file.read()) / 1000.00
     temp = float('%.2f' % temp)
     file.close()

     if(temp > 30):
          pwm.set_PWM_dutycycle(servo, 40)

     if(temp > 50):
          pwm.set_PWM_dutycycle(servo, 50)

     if(temp > 55):
          pwm.set_PWM_dutycycle(servo, 75)

     if(temp > 60):
          pwm.set_PWM_dutycycle(servo, 90)

     if(temp > 65):
          pwm.set_PWM_dutycycle(servo, 100)

     if(temp < 30):
          pwm.set_PWM_dutycycle(servo, 0)
     time.sleep(1)
EOF
#File build out complete

#Enable dthe pigpio daemon, required for fan control to work properly
sudo systemctl enable pigpiod
#Start the pigpiod daemon
sudo pigpiod





#Create and Enable the fan control as a systemd service

# Author: Tranko (https://github.com/thorkseng/x
# Create a small service that start when the pi starts.
# This avoid to have it in bashrc and wait until the user logon.
# This avoid the issue that if you logon several times ir runned several times.

# Create the service
#CUR_DIR=$(pwd)
echo "Creating the fan service in /etc/systemd/system/ with name x735fan.service"
sudo cat > /etc/systemd/system/x735fan.service <<EOF
[Unit]
Description=x735 Fan Service
After=multi-user.target

[Service]
Type=simple
Restart=always
ExecStart=/usr/bin/python3 /etc/x735fan.py

[Install]
WantedBy=multi-user.target
EOF

# Reload the daemon
echo "Reload the systemd daemon"
sudo systemctl daemon-reload

# Enable the service to be enabled on startup
echo "Enable the new service (it will start in any reboot of the system)."
sudo systemctl enable x735fan.service

# Start the service
echo "Start the service"
sudo systemctl start x735fan.service

# Check that the service is running fine
STATUS="$(systemctl is-active x735fan.service)"
if [ "${STATUS}" = "active" ]; then
    echo "Service is active and running correctly"
else
    echo "Service not running something went wrong."
    exit 1
fi

# Additional notes
echo "Everything going fine"
echo "Now the fan will start in any reboot of the system"
echo "You can control the service with the next commands:"
echo "Check the status of the service: sudo systemctl status x735fan.service"
echo "Stop the service: sudo systemctl stop x735fan.service"
echo "Restart the service: sudo systemctl restart x735fan.service"
echo "Check the logs of the service: journalctl -u x735fan.service"
echo "Edit the service configuration in: /etc/systemd/system/x735fan.service"





echo "The installation is complete."
echo "Please run 'sudo reboot' to reboot the device."
echo "NOTE:"
echo "1. /etc/x735fan.py is python file to control fan speed according temperature of CPU, you can modify it according your needs."
echo "2. PWM fan needs a PWM signal to start working. If fan doesn't work in third-party OS afer reboot only remove the YELLOW and BLUE wire of x735 fan to let the fan run immediately or contact us: info@geekworm.com."