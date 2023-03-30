This project implemets the prefect2 proof of concept. The contents are

## terraform
This folder contains the terraform scripts to deploy the infrastructure

## ansible
This folder contains the ansible scripts to configure the deployed infrastructure

## infra
This project makes extensive use of the s3 bucket wa-prefect2-deployments

- stores the terraform tfstate file
- uploads the deployment artifacts to the s3 bucket


## requirements

### pre-commit
there are some project wide requirements, such as the pre-commit framework, which is used to enforce some coding standards. To install the requirements, run the following command:

```
$ pip install -r project-requirements.txt
```

It's advised to use a virtualenv to keep the project requirements separate from the system requirements.

### pre-commit hooks
We use two additional tools within the pre-commit checlks

```
#!/bin/bash                                                                                                              
 
# tflint
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
 
# tfsec
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
```

Please install these tools by running the script

```
bash utils/install_pre_commit_tools.sh
```


<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

No inputs.

## Outputs

No outputs.
<!-- END_TF_DOCS -->