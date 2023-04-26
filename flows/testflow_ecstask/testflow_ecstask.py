from prefect import flow
from prefect_aws.ecs import ECSTask
import boto3


@flow
def my_flow():
    mytask = ECSTask(command=["echo", "hello world"],
                     image="alpine:latest",
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


if __name__ == "__main__":
    my_flow()
