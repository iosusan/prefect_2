resource "aws_ecs_cluster" "prefect2_cluster" {
  name = "prefect2_cluster"

  tags = {
    Name    = "prefect2-ecs-cluster"
    Project = "prefect2"
    Team    = "engineering"
    Status  = "proof-of-concept"
  }


}