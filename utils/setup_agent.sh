#!/bin/bash

echo "starting prefect2 agent"
# get the agent instance id, prefect2-ec2-1
AGENT_ID=$(aws ec2 describe-instances --filters 'Name=tag:Name,Values=prefect2-ec2-1' --output text --query 'Reservations[*].Instances[*].InstanceId')
echo "got instance id $AGENT_ID"
SERVER_INTERNAL_IP=$(aws ec2 describe-instances --filters 'Name=tag:Name,Values=prefect2-ec2-0' --output text --query 'Reservations[*].Instances[*].PrivateIpAddress')

# now config the agent
echo "configuring server url"
CONFIG_COMMAND="prefect config set PREFECT_API_URL=http://${SERVER_INTERNAL_IP}:4200/api"
STARTAGENT_COMMAND="prefect agent start -q \'default\' &"
CONFIG_COMMAND_ID=$(aws ssm send-command --document-name "AWS-RunShellScript" \
--instance-ids $AGENT_ID --parameters commands=["$CONFIG_COMMAND"] \
--output text --query 'Command.CommandId')

# now await for the command to finish
aws ssm wait command-executed --command-id $CONFIG_COMMAND_ID --instance-id $AGENT_ID

# same thing but for the startagent command that will send the execution to the background
echo "starting agent"
STARTAGENT_COMMAND_ID=$(aws ssm send-command --document-name "AWS-RunShellScript" \
--instance-ids $AGENT_ID --parameters commands=['$STARTAGENT_COMMAND'] \
--output text --query 'Command.CommandId')

# no need to wait in this case
echo "Agent starting..."
