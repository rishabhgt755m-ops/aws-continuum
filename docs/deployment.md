# Deployment and teardown

This project provisions chargeable AWS resources. Before running it, review the configuration, account limits and likely cost of two NAT gateways, Multi-AZ RDS, RDS Proxy, the load balancer and the DMS migration phase.

The repository contains the infrastructure configuration used in the lab, along with the SQL scripts and application source. Recreating the full exercise also requires AWS account preparation and manual database setup.

## Prerequisites

- Terraform 1.16.x (required version `>= 1.16.0, < 1.18.0`) and AWS provider 6.x.
- AWS CLI credentials for an account with permission to provision the required services.
- Suitable EC2, RDS and DMS service quotas in `eu-west-1`.
- An existing S3 bucket for Terraform state, with locking and access permissions configured.
- A budget and a plan for deleting the infrastructure after testing.

The AWS provider is configured for `eu-west-1`. The S3 Terraform backend uses `ap-south-1` and currently refers to the bucket used for the original lab. **Set up an appropriate backend for your own account before `terraform init`.**

## Main infrastructure

Inspect the files in `terraform/` before planning the deployment. The main module defines the VPC, subnets, NAT gateways, ALB, EC2 application, RDS database, RDS Proxy, IAM permissions and CloudWatch/SNS monitoring.

```bash
cd terraform
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Review the plan, expected charges and account identity before applying. No application deployment should be attempted until the database and secret dependencies below are understood.

## Database and application setup

RDS manages the database administrator password. The application uses the PostgreSQL user `continuum_app` and reaches the database through RDS Proxy. The Terraform configuration creates the Secrets Manager secret resource, but its **secret value** and the associated database account require separate setup. Do not place credentials in source code, tracked variable files or Terraform state.

The EC2 launch template installs PostgreSQL client packages and starts `app/server.py` through `systemd`. The Python service uses the AWS CLI to generate IAM database authentication tokens and `psql` to run its health query. Check the selected AMI for the expected executable paths and certificate bundle before relying on `/db-health`.

## DMS migration phase

The migration Terraform files are stored in `terraform/phase3-archive/`. Terraform does not load this directory automatically when run from `terraform/`, and the archived files reference resources from the main module. They therefore cannot be applied as a standalone Terraform module.

The migration exercise additionally requires a PostgreSQL source, logical replication settings, suitable database grants and source/target secrets in Secrets Manager. The SQL scripts in `sql/` establish a small test dataset and subsequent changes. Validate endpoint connectivity, full-load completion, source/target row counts and CDC behaviour before considering migration successful.

The archive records the configuration from the completed exercise. Reproducing that phase requires carefully staging it with the main Terraform resources and reviewing the resulting plan. The SQL and secret preparation steps are not fully automated by this repository.

## Verification

1. Confirm that the ALB has two healthy application targets and that `/health` returns HTTP 200.
2. Confirm that `/db-health` can execute a query through RDS Proxy.
3. Check the CloudWatch dashboard, alarm configuration and the SNS subscription if notifications are enabled.
4. For migration, verify DMS endpoint tests, task status and source/target results after CDC changes.
5. During recovery exercises, collect HTTP samples separately for instance replacement and database failover.

## Teardown

Preserve necessary test results, inspect the destroy plan and remove the environment using the same Terraform state:

```bash
cd terraform
terraform plan -destroy
# Review the proposed deletions before running terraform destroy.
```

After destruction, confirm that billed resources such as NAT gateways, load balancers, RDS and DMS have been removed. Also review separately managed secrets, retained remote state and delayed AWS billing. Terraform state removal alone does not establish that no charges remain.
