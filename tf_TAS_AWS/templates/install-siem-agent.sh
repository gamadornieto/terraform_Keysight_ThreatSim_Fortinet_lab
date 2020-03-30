#!/bin/bash

organizationID= <PUT HERE YOUR ORGANIZATIONID>
APIbaseURL=https://demo-api.threatsimulator.cloud

# Mandatory arguments
token=

# Parses command line arguments.
while getopts t option
do
   case $option in
    t) req_token=true;;                     # Ask user to enter a new SIEM API Token
    *) printf "$0: Usage: $0 [-t Token]\n"
       exit 2;;
    esac
done

which docker

if [ $? -eq 0 ]
then
    docker --version | grep "Docker version"
    if [ $? -eq 0 ]
    then
        echo "Docker OK"
    else
        echo "ERROR: Docker is not installed" >&2
        exit 1
    fi
else
    echo "ERROR: Docker is not installed" >&2
    exit
fi

# .threatsim exists ?
BP_DIR=~/.threatsim
if [ ! -e "$BP_DIR" ]; then
    echo "$BP_DIR does not exist"
    mkdir -p "$BP_DIR"
fi

TOKEN_FILE_PATH=~/.threatsim/token
if [ -f "$TOKEN_FILE_PATH" ] && [ -z "$req_token" ]; then
    echo "$TOKEN_FILE_PATH exist"
    token=$(<$TOKEN_FILE_PATH)
else
    # Read the SIEM API token
    echo -n "SIEM API Token:"
    read -s token
    echo
fi

[ "$token" ] || {
   echo "$0: Invalid SIEM API Token !"
   exit 1
}

echo "$token" > $TOKEN_FILE_PATH

AGENT_ID_FILE_PATH=~/.threatsim/id
if [ ! -f "$AGENT_ID_FILE_PATH" ]; then
    echo $(cat /proc/sys/kernel/random/uuid) > $AGENT_ID_FILE_PATH
fi

# Logs into AWS ECR and pulls the latest agent container.
u=`expr "\`dd if=/dev/urandom bs=1M count=1 | sha256sum\`" : "\([^ ]*\).*"`
u=${u:0:32}
p=`expr "$(echo -n $u:$organizationID | sha256sum)" : "\([^ ]*\)".*`
blob=`curl --insecure --user $u:$p --globoff $APIbaseURL/agent/docker?OrganizationID=$organizationID 2>/dev/null`
siem_agent_repo="547135861352.dkr.ecr.us-east-2.amazonaws.com/siem-agent"
siem_agent_image_tag="latest"
auth_endpoint=`echo $blob | sed -n "s/.*\"auth-endpoint\"[ ]*\:[ ]*\"\([^\" ]*\)\".*/\1/p"`
auth_password=`echo $blob | sed -n "s/.*\"auth-pass\"[ ]*\:[ ]*\"\([^\" ]*\)\".*/\1/p"`
auth_user=`echo $blob | sed -n "s/.*\"auth-user\"[ ]*\:[ ]*\"\([^\" ]*\)\".*/\1/p"`

echo "$auth_password" | sudo docker login -u $auth_user --password-stdin $auth_endpoint
sudo docker pull $siem_agent_repo:$siem_agent_image_tag

# Cleans up an existing Docker SIEM agent of the same name
sudo docker stop threatsim-siem-agent 2>/dev/null
sudo docker rm threatsim-siem-agent 2>/dev/null

sudo docker run \
  --name threatsim-siem-agent \
  -itd \
  --volume ~/.threatsim:/root/.threatsim \
  --restart=always \
  $siem_agent_repo:$siem_agent_image_tag $token $APIbaseURL $organizationID
