# AWS credentials
This terraform script uses AWS infra, so proper credentials need to be set in the environment OR the profile
defined in ~/.aws/credentials and added to tf file

# Requirements
The terraform binary

# Files
provider.tf contains the cloud provider, in this case AWS

# run
First, initialize the terraform environment
```
terraform init
```

Then, check what terraform will do
```
terraform plan
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
In order to allow remote access, the PREFECT_SERVER_API_HOST must be configured to the specific interface
(this way we could keep the dashboard only local and ssh tunnel from a safe machine)

But for our purposes, we will set it to 0.0.0.0 so it can be accessed from anywhere
** THIS MUST BE CONTROLLED AS ANYONE COULD ACCESS THE SERVER **
Usually, the server will be down except for the specific tests, AND the contents will be only ones from the test

```
prefect config set PREFECT_SERVER_API_HOST=0.0.0.0
```



Let's start the agent for 'default' queue in prefect2-ec2-1 connecting to api in prefect2-ec2-0

```


Now, let's connect our local environment to the remote server in prefect2-ec2-0 using the PREFECT_API_URL


# in summary
- write the flow code
- add the storage block
- add the execution block
- create the deployment