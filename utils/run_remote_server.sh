#!/bin/bash

echo "starting prefect2 server in prefect2-ec2-0"
# get the server instance id, prefect2-ec2-0
SERVER_ID=$(aws ec2 describe-instances --filters 'Name=tag:Name,Values=prefect2-ec2-0' --output text --query 'Reservations[*].Instances[*].InstanceId')
echo "got server's instance id $SERVER_ID"
SERVER_REMOTE_IP=$(aws ec2 describe-instances --filters 'Name=tag:Name,Values=prefect2-ec2-0' --output text --query 'Reservations[*].Instances[*].PublicIpAddress')
# now launch the prefect server, first config
CONFIG_COMMAND="prefect config set PREFECT_SERVER_API_HOST=0.0.0.0; prefect config set PREFECT_UI_API_URL=http://${SERVER_REMOTE_IP}:4200/api"
STARTSERVER_COMMAND="nohup prefect server start > /home/ubuntu/prefect_server.log 2>&1 &"
CONFIG_COMMAND_ID=$(aws ssm send-command --document-name "AWS-RunShellScript" \
--instance-ids $SERVER_ID --parameters commands=["$CONFIG_COMMAND"] \
--output text --query 'Command.CommandId')

# now await for the command to finish
aws ssm wait command-executed --command-id $CONFIG_COMMAND_ID --instance-id $SERVER_ID

# same thing but for the startserver command that will send the execution to the background
STARTSERVER_COMMAND_ID=$(aws ssm send-command --document-name "AWS-RunShellScript" \
--instance-ids $SERVER_ID --parameters commands=["$STARTSERVER_COMMAND"] \
--output text --query 'Command.CommandId')

# no need to wait in this case
echo "starting server process at http://$SERVER_REMOTE_IP:4200 with id ${STARTSERVER_COMMAND_ID}"
# wait for the command to finish
aws ssm wait command-executed --command-id "${STARTSERVER_COMMAND_ID}" --instance-id $SERVER_ID
# done, check if successful
CHECKLOG_COMMAND_ID=$(aws ssm send-command --document-name "AWS-RunShellScript" \
--instance-ids $SERVER_ID --parameters commands=["cat /home/ubuntu/prefect_server.log"] \
--output text --query 'Command.CommandId')
aws ssm wait command-executed --command-id "${CHECKLOG_COMMAND_ID}" --instance-id $SERVER_ID
SERVER_LOG=$(aws ssm get-command-invocation --command-id "${CHECKLOG_COMMAND_ID}" --instance-id $SERVER_ID --output text --query 'StandardOutputContent')
echo "server log: ${SERVER_LOG}"



