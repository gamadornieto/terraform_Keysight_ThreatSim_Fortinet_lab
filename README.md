# terraform_Keysight_ThreatSim_Fortinet_lab


This is a Keysight ThreatSim lab to test Fortigate VM


## General prerequisites to deploy ThreatSim agents and Fortigate
Update the following file with your AWS credentials
- terraform_credentials/credentials.tfvars

## Optional.  Prerequisites to install Splunk SIEM
Update the following
- terraform_credentials/tas_token
with Keysight's ThreatSim SIEM token from here https://demo.threatsimulator.cloud/security/settings/apitokens

Download the SIEM Agent installer (install-siem-agent.sh) from here
https://demo.threatsimulator.cloud/security/settings/siem/siem-deployment-how-to
and replace current file in tf_TAS_AWS/templates/install-siem-agent.sh
update organizationID = "<YOUR_ORGANIZATION_ID>" field in tf_TAS_AWS/terraform.tfvars

 ## Optional.  Install Splunk

cd tf_TAS_AWS/Splunk_siem_agent
terraform init

 ## Deploy the infrastructure
terraform.exe apply --var-file="..\..\terraform_credentials\credentials.tfvars" --var-file="..\terraform.tfvars" --auto-approve
 ## Configure and test Splunk in ThreatSim https://demo.threatsimulator.cloud/security/settings/siem

 ## Deploy Fortigate VM and  agents in private and public subnets

cd tf_TAS_AWS/Fortigate_public_private_agents
terraform init

 First time deploy Fortigate VM and public agent(s)
 Use following values in ..\terraform.tfvars
 
  num_public_agents = 1
  num_private_agents = 0
  
 and deploy
   terraform.exe apply --var-file="..\..\terraform_credentials\credentials.tfvars" --var-file="..\terraform.tfvars" --auto-approve

 Log in into FortigateVM and create an IPv4 Policy rule to allow traffic from Private subnet to Public subnet ( port2 to port1)
 
 See "Howto_configure_Fortigate.pdf" 
 
 Once this is done use following values in ..\terraform.tfvars to start the agents in the private subnet  
  (they need to download software from internet) 
  
    num_public_agents = 1 
    num_private_agents = 1 
    
 and redeploy 
  terraform.exe apply --var-file="..\..\terraform_credentials\credentials.tfvars" --var-file="..\terraform.tfvars" --auto-approve
  
 ## Delete infrastructure
 
cd tf_TAS_AWS/Fortigate_public_private_agents 

terraform.exe destroy --var-file="..\..\terraform_credentials\credentials.tfvars" --var-file="..\terraform.tfvars"  --force 

cd tf_TAS_AWS/Splunk_siem_agent 

terraform.exe destroy --var-file="..\..\terraform_credentials\credentials.tfvars" --var-file="..\terraform.tfvars"  --force 

## License
MIT / BSD

Author Information
Created in 2020 Gustavo AMADOR NIETO.
