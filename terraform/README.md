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

