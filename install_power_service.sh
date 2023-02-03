#!/bin/bash

# Author: Tranko (https://github.com/haxx0r07/x735-v2.5
# Create a small service that will call the soft shutdown script if the host is powered off through "normal" methods
#I use this when shutting down a host through the Moonraker interface
#https://github.com/Arksine/moonraker/pull/137
#https://github.com/Arksine/moonraker/issues/240

# Create the service
echo "Creating the service in /etc/systemd/system/ with name x735pwr_catch_all.service"
sudo cat > /etc/systemd/system/x735pwr_catch_all.service <<EOF
[Unit]
Description=Shutdown the Pi using the Geekworm X735 hat.
DefaultDependencies=no
Before=poweroff.target halt.target

[Service]
ExecStart=/usr/local/bin/x735softsd.sh
ExecStop=/usr/local/bin/x735softsd.sh
Type=oneshot
RemainAfterExit=yes

[Install]
WantedBy=poweroff.target halt.target
EOF

# Reload the daemon
echo "Reload the systemd daemon"
sudo systemctl daemon-reload

# Enable the service to be enabled on startup
echo "Enable the new service (it will execute just before the shutdown of the system)."
sudo systemctl enable x735pwr_catch_all.service

# Additional notes
echo "Now the fan will start in any reboot of the system"
echo "Check the logs of the service: journalctl -u x735pwr_catch_all.service"
echo "Edit the service configuration in: /etc/systemd/system/x735pwr_catch_all.service"