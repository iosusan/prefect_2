#!/bin/bash

echo "stopping prefect2 server in prefect2-ec2-0"
# get the server instance id, prefect2-ec2-0
SERVER_ID=$(aws ec2 describe-instances --filters 'Name=tag:Name,Values=prefect2-ec2-0' --output text --query 'Reservations[*].Instances[*].InstanceId')
echo "got server's instance id $SERVER_ID"

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
# check if there is any output
if [ -z "$PSEF_COMMAND_OUTPUT" ]; then
    echo "no prefect server running found"
    exit 0
else
    echo "prefect server running found, stopping the processes"
    for i in ${PSEF_COMMAND_OUTPUT[*]}; do
        printf "stopping $i..."
        KILL_COMMAND="kill -9 $i"
        KILL_COMMAND_ID=$(aws ssm send-command --document-name "AWS-RunShellScript" \
        --instance-ids $SERVER_ID --parameters commands=[\""$KILL_COMMAND"\"] \
        --output text --query 'Command.CommandId')
        # wait for the command to finish
        aws ssm wait command-executed --command-id "${KILL_COMMAND_ID}" --instance-id $SERVER_ID
        printf " done\n"
    done
fi

echo "server not running"
