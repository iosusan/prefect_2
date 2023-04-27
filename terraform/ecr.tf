resource "aws_ecr_repository" "prefect2" {
  name                 = "prefect2"
  image_tag_mutability = "MUTABLE"

  tags = {
    Name = "prefect2"
    Project = "prefect2"
    Team    = "engineering"
    Status  = "proof-of-concept"
  }
}