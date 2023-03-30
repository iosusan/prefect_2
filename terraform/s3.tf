# this file creates the s3 bucket that will be used for the workflow deployments
# a storage block will be created for this

resource "aws_s3_bucket" "prefect_2_deployments" {
  bucket = "wa-prefect2-deployments"

  tags = {
    Name    = "prefect2-deployments"
    Project = "prefect2"
    Team    = "engineering"
    Status  = "proof-of-concept"
  }


}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.prefect_2_deployments.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "bucket_public_access_block" {
  bucket = aws_s3_bucket.prefect_2_deployments.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

