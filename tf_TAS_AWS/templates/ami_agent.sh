#!/bin/bash -x
identity=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document)
region=`echo $identity | sed -n "s/.*\"region\"[  ]*\:[   ]*\"\([^\"      ]*\)\".*/\1/p" -`
instanceID=`echo $identity | sed -n "s/.*\"instanceId\"[  ]*\:[   ]*\"\([^\"      ]*\)\".*/\1/p" -`
curl ${APIbaseURL}/agent/download?OrganizationID=${organizationID}\&Type=onpremise-linux > /home/ec2-user/agent-init.run
