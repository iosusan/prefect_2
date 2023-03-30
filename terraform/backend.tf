# this file configures the terraform backend to use the s3 bucket
# wa-prefect2-deployments

terraform {
  backend "s3" {
    bucket = "wa-prefect2-deployments"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}