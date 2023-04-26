# lets create an IAM role for the ec2 instances
# this role will include the AmazonSSMManagedInstanceCore policy
# we need to add the ssm session policy to both the instance role and the users
resource "aws_iam_role" "prefect2_ec2_ssm_role" {
  name               = "prefect2_ec2_ssm_role"
  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF

  tags = {
    Name    = "prefect2-ec2-ssm-role"
    Project = "prefect2"
    Team    = "engineering"
    Status  = "proof-of-concept"
  }

  managed_policy_arns = [
    aws_iam_policy.prefect2_ssm_session_policy.arn,
    aws_iam_policy.prefect2_s3_deployments_policy.arn,
    aws_iam_policy.prefect2_ecs_policy.arn
  ]
}


# create an instance profile for the ec2 instances
resource "aws_iam_instance_profile" "prefect2_ec2_ssm_instance_profile" {
  name = "prefect2_ec2_ssm_instance_profile"
  role = aws_iam_role.prefect2_ec2_ssm_role.name
}

# finally, crearte the group of users that will have ssm access to the instances
resource "aws_iam_group" "prefect2_ssm_group" {
  name = "prefect2_ssm_group"
  path = "/projects/prefect2/"
}

# the policy that incudes the acccesses to the instances
resource "aws_iam_policy" "prefect2_ssm_session_policy" {
  name = "prefect2_ssm_session_policy"
  path = "/projects/prefect2/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:StartSession",
          "ssm:TerminateSession",
          "ssm:ResumeSession",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "logs:PutLogEvents",
          "logs:CreateLogStream"

        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
        ]
        # this is the wa-sl SSM key from KMS
        Resource = "arn:aws:kms:us-east-1:461557490742:key/54a5fd33-0104-4408-a51d-1bfece71ecd5"
      }
    ]
  })

}

# a policy that allows the readwrite access to the s3 bucket for deployments
resource "aws_iam_policy" "prefect2_s3_deployments_policy" {
  name = "prefect2_s3_deployments_policy"
  path = "/projects/prefect2/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads",
          "s3:ListBucketVersions"
        ],
        Resource = "arn:aws:s3:::wa-prefect2-deployments"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ],
        Resource = "arn:aws:s3:::wa-prefect2-deployments/*"
      }
    ]
  })

}

resource "aws_iam_policy" "prefect2_ecs_policy" {
  name = "prefect2_ecs_policy"
  path = "/projects/prefect2/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecs:RegisterTaskDefinition",
          "ec2:DescribeVpcs",
          "ecs:DescribeClusters",
          "ec2:DescribeSubnets",
          "ecs:RunTask",
          "ecs:DescribeTasks",
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "logs:PutLogEvents",
          "iam:PassRole",
          "ecs:DeregisterTaskDefinition"
        ],
        Resource = "*"
      }

    ]
  })
}

# the roles for the ECS access ##############################################
# these roles will be used by the ECS tasks
# - ecs_task_execution_role
# - ecs_task_role

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"
 
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF

  managed_policy_arns = [
    aws_iam_policy.prefect2_ecs_policy.arn
  ]
}



resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"
 
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}
 
resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# we may nbeed to attath policies to ecs_task_role aswell such as s3 access, etcc
####################################################################################

# now add the policy to the group
resource "aws_iam_group_policy_attachment" "prefect2_ssm_session_policy_attachment" {
  group      = aws_iam_group.prefect2_ssm_group.name
  policy_arn = aws_iam_policy.prefect2_ssm_session_policy.arn
}

# to add an already existing iam user, run this command on before hand
# otherwise this line will attempt to CREATE a new user
# terraform import aws_iam_user.user_iosu_santurtun iosu.santurtun

# the users to be added to the group
resource "aws_iam_user" "user_iosu_santurtun" {
  name = "iosu.santurtun"

  lifecycle {
    prevent_destroy = true # do not remove  users!
  }
}

# add the user to the group
resource "aws_iam_group_membership" "team" {
  name = "prefect2_ssm_group"
  users = [
    aws_iam_user.user_iosu_santurtun.name
  ]
  group = aws_iam_group.prefect2_ssm_group.name
}
