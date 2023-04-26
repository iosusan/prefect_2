from prefect import flow
import time
from random import randint
from prefect_aws.ecs import ECSTask

@flow(name="testflow")
def my_flow(param):
    mytask = ECSTask(command=["python3","-c",
                     "'import time; from random import randint;\
                     time.sleep(randint(1,3)); print(\"finished X\")'"],
                     image="python:3.8.2-alpine",
                     launch_type="FARGATE",
                     cluster="prefect2_cluster",
                     vpc_id="vpc-03f0a8502a215eab0",
                     stream_output=True,
                     configure_cloudwatch_logs=True,
                     # this role specification is because each task may have a different set of permissions
                     execution_role_arn="arn:aws:iam::461557490742:role/ecs-task-execution-role",)
    retval = mytask.run()
    print(retval)
    return retval


@flow
def concurrent_flows():
    print(my_flow("FIRST"))
    print(my_flow("SECOND"))


if __name__ == "__main__":
    concurrent_flows()
