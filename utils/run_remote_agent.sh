#!/bin/bash

echo "starting prefect2 agent"
# get the agent instance id, prefect2-ec2-1
AGENT_ID=$(aws ec2 describe-instances --filters 'Name=tag:Name,Values=prefect2-ec2-1' --output text --query 'Reservations[*].Instances[*].InstanceId')
echo "got agent's instance id $AGENT_ID"
SERVER_INTERNAL_IP=$(aws ec2 describe-instances --filters 'Name=tag:Name,Values=prefect2-ec2-0' --output text --query 'Reservations[*].Instances[*].PrivateIpAddress')

# now config the agent
echo "configuring server url http://${SERVER_INTERNAL_IP}:4200/api"
CONFIG_COMMAND="prefect config set PREFECT_API_URL=http://${SERVER_INTERNAL_IP}:4200/api"
STARTAGENT_COMMAND="nohup prefect agent start -q 'default' > /home/ubuntu/prefect_agent.log 2>&1 &"
CONFIG_COMMAND_ID=$(aws ssm send-command --document-name "AWS-RunShellScript" \
--instance-ids $AGENT_ID --parameters commands=["$CONFIG_COMMAND"] \
--output text --query 'Command.CommandId')

# now await for the command to finish
aws ssm wait command-executed --command-id $CONFIG_COMMAND_ID --instance-id $AGENT_ID

# same thing but for the startagent command that will send the execution to the background
STARTAGENT_COMMAND_ID=$(aws ssm send-command --document-name "AWS-RunShellScript" \
--instance-ids $AGENT_ID --parameters commands=[\""$STARTAGENT_COMMAND"\"] \
--output text --query 'Command.CommandId')

echo "Agent starting..."
# wait for the command to finish
aws ssm wait command-executed --command-id "${STARTAGENT_COMMAND_ID}" --instance-id $AGENT_ID
# done, check if successful
CHECKLOG_COMMAND_ID=$(aws ssm send-command --document-name "AWS-RunShellScript" \
--instance-ids $AGENT_ID --parameters commands=["cat /home/ubuntu/prefect_agent.log"] \
--output text --query 'Command.CommandId')
aws ssm wait command-executed --command-id "${CHECKLOG_COMMAND_ID}" --instance-id $AGENT_ID
AGENT_LOG=$(aws ssm get-command-invocation --command-id "${CHECKLOG_COMMAND_ID}" --instance-id $AGENT_ID --output text --query 'StandardOutputContent')
echo "agent log: ${AGENT_LOG}"


