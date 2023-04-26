#!/bin/bash

echo "checking remote prefect platform status"
# first the server, prefect2-ec2-0
SERVER_ID=$(aws ec2 describe-instances --filters 'Name=tag:Name,Values=prefect2-ec2-0' --output text --query 'Reservations[*].Instances[*].InstanceId')
echo "got server's instance id $SERVER_ID"
SERVER_REMOTE_IP=$(aws ec2 describe-instances --filters 'Name=tag:Name,Values=prefect2-ec2-0' --output text --query 'Reservations[*].Instances[*].PublicIpAddress')
echo "got server's remote ip $SERVER_REMOTE_IP"
# send remote command to get the processes ids if any
# ps -ef | grep prefect | grep -v grep | awk '{print $2}'
PSEF_COMMAND="ps -ef | grep prefect | grep -v grep | awk '{print \$2}'"
PSEF_COMMAND_ID=$(aws ssm send-command --document-name "AWS-RunShellScript" \
--instance-ids $SERVER_ID --parameters commands=[\""$PSEF_COMMAND"\"] \
--output text --query 'Command.CommandId')
# wait for the command to finish
aws ssm wait command-executed --command-id "${PSEF_COMMAND_ID}" --instance-id $SERVER_ID
# get the output
PSEF_COMMAND_OUTPUT=$(aws ssm get-command-invocation --command-id $PSEF_COMMAND_ID --instance-id $SERVER_ID --output text --query 'StandardOutputContent')
if [ -z "$PSEF_COMMAND_OUTPUT" ]; then
    echo "no prefect server running found"
    exit 0
else
    echo "prefect server running found at $SERVER_REMOTE_IP"
fi
# second, the prefect agent prefect2-ec2-1
AGENT_ID=$(aws ec2 describe-instances --filters 'Name=tag:Name,Values=prefect2-ec2-1' --output text --query 'Reservations[*].Instances[*].InstanceId')
echo "got agent's instance id $AGENT_ID"
AGENT_REMOTE_IP=$(aws ec2 describe-instances --filters 'Name=tag:Name,Values=prefect2-ec2-1' --output text --query 'Reservations[*].Instances[*].PublicIpAddress')

# send remote command to get the processes ids if any
# ps -ef | grep prefect | grep -v grep | awk '{print $2}'
PSEF_COMMAND="ps -ef | grep prefect | grep -v grep | awk '{print \$2}'"
PSEF_COMMAND_ID=$(aws ssm send-command --document-name "AWS-RunShellScript" \
--instance-ids $AGENT_ID --parameters commands=[\""$PSEF_COMMAND"\"] \
--output text --query 'Command.CommandId')
# wait for the command to finish
aws ssm wait command-executed --command-id "${PSEF_COMMAND_ID}" --instance-id $AGENT_ID
# get the output
PSEF_COMMAND_OUTPUT=$(aws ssm get-command-invocation --command-id $PSEF_COMMAND_ID --instance-id $AGENT_ID --output text --query 'StandardOutputContent')
# check if there is any output
if [ -z "$PSEF_COMMAND_OUTPUT" ]; then
    echo "no prefect agennt running found"
    exit 0
else
    echo "prefect agent running found in prefect2-ec2-1"
fi
