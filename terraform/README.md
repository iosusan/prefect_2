# AWS credentials
This terraform script uses AWS infra, so proper credentials need to be set in the environment OR the profile
defined in ~/.aws/credentials and added to tf file

# Requirements
The terraform binary, a vortualenv with the project_requirements.txt installed

# Files
ec2.tf contains the ec2 instances stuff
iam.tf contains the iam credentials and policies
provider.tf contains the cloud provider, in this case AWS
s3.tf contains the s3 bucket definition
ssmagent.tf contains the ssm agent installation part

# run
First, initialize the terraform environment
```
terraform init
```

Then, check what terraform will do
```
terraform plan
```
-etc..

# config management
This is done through ansible, scripts present in ansible directory.

- inventory.aws_ec2.yml contains the dynamic inventory for the ec2 instances
- base_system.yml contains the base system configuration (e.g. python libraries, etc)
- docker.yml contains the docker installation and configuration


To run a config update

```
ansible-playbook -v base_system.yml -i inventory.aws_ec2.yml
```

To run the docker installation

```
ansible-playbook -v docker.yml -i inventory.aws_ec2.yml
```



# setting up the prefect stuff
prefect2-ec2-0 will run the prefect server, the connection point will be http://prefect2-ec2-0:4200/api

```
$ prefect server start
```

to configure prefect communication from the other instance prefect-ec2-1, use

```
$ prefect config set PREFECT_API_URL=http://prefect2-ec2-0:4200/api
```


prefect2-ec2-1 will run the prefect agent. We will use a queue called dev. To start the agent, use

```
prefect agent start -q dev
```

# testing

## testflow

```
from prefect import flow                                                                                     
import time
from random import randint
 
@flow(name="testflow")
def my_flow(param):
    print(f"running for {param}")
    time.sleep(randint(1,3))
    return f"finished {param}"
    
@flow
def concurrent_flows():
    print(my_flow("FIRST"))
    print(my_flow("SECOND"))
 
if __name__=="__main__":
    concurrent_flows()

```

## case 0, parts
there are three parts in prefect2

- the flows, that are the functional parts that will be run
- the server, that orchestrates the flow execution
- the agent, that links the orchestrator to the execution environment

## case 1, local excution
I can run the prefect server, then 'prefect configure set PREFECT_API_URL=http://localhost:4200/api' and when i run the testflow with

```
python3 testflow.py
```

it will be locally run using the prefect library


## case 2, local deployment
The deployments are the name for the "server" flows (i.e. the local flow is "deployed" to the server so the way to access it is through the
created deployment)

The same workfloe code can be used in more than one deploymenet.


Now, let's start the server

```
prefect server start
```

and create the deployment

```
$ prefect deployment build testflow.py:concurrent_flows --name 'testflow'
```

This will create the concurrent_flows-deploymnet.yaml file. Now we can deploy it by 'applying' it


```
prefect deployment apply concurrent_flows-deployment.yaml
```

By default if no queue is specified, the default queue is used.
And now we would be able to see the deployment in our server (which means that now we can run our flow from the server)

```
prefect deployment ls

                            Deployments                             
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ Name                      ┃ ID                                   ┃
┡━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┩
│ concurrent-flows/testflow │ 9b78ea96-7e8a-41c5-a394-c0e8416635fa │
└───────────────────────────┴──────────────────────────────────────┘
```

So, let's try to run it (it should fail because there is no agent running for the specified queue)

```
prefect deployment run concurrent-flows/testflow
Creating flow run for deployment 'concurrent-flows/testflow'...
Created flow run 'electric-macaw'.
└── UUID: 20b6f218-459d-4015-b138-6c3bf0a93436
└── Parameters: {}
└── Scheduled start time: 2023-03-28 14:13:21 CEST (now)
└── URL: http://127.0.0.1:4200/flow-runs/flow-run/20b6f218-459d-4015-b138-6c3bf0a93436
```

The flow run is created but it is never triggered as there is no agent waiting. Let's start a local agent

```
prefect agent start -q 'default'
```

As soon as it is started, the flow run is triggered (it will actually never start because the storage part
has not been defined)

One thing to be taken into account is that the directory from where the deployment is built is the one that will be used
to download the flow code - this may cause some problems downlading stuff (e.g. if the directory contains more unrelated stuff))



## case 3, remote deployment
Let's start the server in prefect2-ec2-0
In order to allow remote access, the PREFECT_SERVER_API_HOST must be configured to the specific interface (by default its only 127.0.0.1)
Wit this mechanism we could keep the dashboard only local and ssh tunnel from a safe machine

But for our purposes, we will set it to 0.0.0.0 so it can be accessed from anywhere
** THIS MUST BE CONTROLLED AS ANYONE COULD ACCESS THE SERVER **
Usually, the server will be down except for the specific tests, AND the contents will be only ones from the test
And we must tell the UI app whart IP address it will connect (this is, the external IP address for the server)

```
prefect config set PREFECT_SERVER_API_HOST=0.0.0.0
prefect config set PREFECT_UI_API_URL=http://44.199.233.178:4200/api
```

Now we can start up the server in prefect2-ec2-0 and access it from both prefect2-ec2-1 (agent host) and our local machine

```
prefect server start
```


Let's start the agent for 'default' queue in prefect2-ec2-1 connecting to api in prefect2-ec2-0. First configure the API url
in prefect2-ec2-1

```
prefect config set PREFECT_API_URL=http://<prefect2-ec2-0>:4200/api
```
and after that, launch the agent listening to the 'default' queue

```
prefect agent start -q 'default'
```

And as the third step, we will configure our local machine to point to the remote prefect2-ec2-0 API

```
prefect config set PREFECT_API_URL=http://<prefect2-ec2-0>:4200/api
```


generate a workflow deployment from our local machine

```
prefect deployment build testflow.py:concurrent_flows --name 'testflow'
```

Then, apply the generated deployment

```
prefect deployment apply concurrent_flows-deployment.yaml
```

And finally, run the deployment fom our local machine

```
prefect deployment run concurrent-flows/testflow
```

And check that it is actually running in the server at http://<prefect2-ec2-0>:4200/flow-runs

We can see that the agent throws an error, because we are launching it as if it was local deployment

```
[...]
FileNotFoundError: [Errno 2] No such file or directory: '/home/iosu/tmp_flow'
```

Which was something to be expected, whenever we call 'prefect deployment' without explicitly adding a '--storage-block' flag
the LocalFileSystem will be used, which obviously is not accessible from remote machines.

We need to configure the storage place where the deployment contents will be placed and this is done by using blocks. We will be using
S3 storage, we will need the s3fs library.

This requires

- an s3 bucket (this is created in the terraform code): wa-prefect-storage
- instance role with permissions to access the bucket that will be assigned to agent instance(s)
- the creation of a storage block from the prefect UI (the server instance) that refers to the s3 bucket (thuis must be done manually)
- the s3fs library installed in local instance (where build happens), and in the agent instance

![storage block](docs/images/storage_block.png)

Now when building the deployment, the storage block to be used must be specified

```
❯ prefect deployment build testflow.py:concurrent_flows --name 'testflow' --storage-block s3/deployment-workflows
Found flow 'concurrent-flows'
Deployment YAML created at '/home/iosu/tmp_flow/concurrent_flows-deployment.yaml'.
Successfully uploaded 2 files to s3://wa-prefect2-deployments/
```

Then we can apply and run the deployment and see the correct execution in the agent instance.

***
There is a funny situation with ubuntu22 and the installed python3-openssl and cryptography libraries. The newest versions of cryptography (>38.0.4) have solved a bug that requires an openssl version greater than 22.1.0, but the one apt-installed is below that.






#### case 4, workflow is run using docker

Hopefully the only thing to change would be the agent part :-)

First, we run the ansible script to install the docker engine in the agent instance, and restart the agent.

Then we need to add a prefect-docker block within the UI

- block name: docker-runner
- environment (optional): we will add the pip dependencies, s3fs in our case (or more if required)

```
{
  "EXTRA_PIP_PACKAGES": "s3fs"
}
```

and now we have to rebuild our deployment to make use of the new infrastructure block

```
prefect deployment build testflow.py:concurrent_flows --name 'testflow' --storage-block s3/deployment-workflows --work-queue 'default' --infra-block docker-container/docker-runner 
```

then apply, and run, and we will see the "docker" backstage at the agent logs

```
14:59:55.253 | INFO    | prefect.infrastructure.docker-container - Pulling image 'prefecthq/prefect:2.8.7-python3.10'...
15:00:14.811 | INFO    | prefect.infrastructure.docker-container - Creating Docker container 'utopian-wildcat'...
15:00:14.892 | INFO    | prefect.infrastructure.docker-container - Docker container 'utopian-wildcat' has status 'created'
```

and finally get a missing credentials error (NoCredentialsError)

This part of the instance definition in terraform is the one to blame

```
  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "optional" #"required"
  } 
```

if the http_tokens is required, the docker container will not be able to access metadata service and will not be able to get the instance role.

Note: when creating the infra block, a custom docker image can be configured to be used, so we could have a custom image with the required dependencies already installed.

This means that we could have different configured docker-runners and select the one that fits our needs (e.g. different python versions, different dependencies, etc)



