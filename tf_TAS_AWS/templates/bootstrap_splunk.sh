#!/usr/bin/env bash

# Install Splunk 8.0.2.1
apt update -y
cd /tmp && wget  https://download.splunk.com/products/splunk/releases/8.0.2.1/linux/splunk-8.0.2.1-f002026bad55-linux-2.6-amd64.deb
dpkg -i /tmp/splunk-8.0.2.1-f002026bad55-linux-2.6-amd64.deb

# Enable Splunk at run time
# Web password defined in user-seed.conf  -- note that password has to be at least 8 characters long
# Otherwise it won't work but there's no error message
cp /home/ubuntu/user-seed.conf /opt/splunk/etc/system/local/user-seed.conf
/opt/splunk/bin/splunk start --accept-license --answer-yes  --no-prompt
/opt/splunk/bin/splunk enable boot-start --no-prompt --answer-yes

# Install Threatsim app
cd /opt/splunk/etc/apps && wget   https://demo.threatsimulator.cloud/siem/TA_threatsimulator-1.0.0.spl
cd /opt/splunk/etc/apps && tar xvfz TA_threatsimulator-1.0.0.spl
# Restart service
service splunk restart

# Add threatsim_index
 /opt/splunk/bin/splunk add index threatsim_index  -auth admin:admin123
# This is to check all indexes
#/opt/splunk/bin/splunk list index -datatype all -auth admin:admin123

# Add TCP data input
/opt/splunk/bin/splunk add tcp 5514 -sourcetype threatsim -connection_host ip -index threatsim_index -auth admin:admin123
# Restart service
service splunk restart
echo "Splunk Done" > /tmp/gustavo_msg.txt
