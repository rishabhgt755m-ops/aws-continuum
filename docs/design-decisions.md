# Design decisions

The main choices were driven by the behaviours I wanted to test: instance replacement, database failover, migration continuity and visibility into failures. I kept the application small so that the infrastructure and recovery mechanisms could be examined separately from application complexity.

## Availability across two zones

The application tier uses two private EC2 instances in separate Availability Zones behind a single Application Load Balancer. The Auto Scaling Group maintains the desired capacity of two, allowing a failed instance to be replaced. A fixed capacity was sufficient for the replacement exercise, so traffic-driven scaling was not part of this implementation.

The database uses RDS PostgreSQL with Multi-AZ enabled. The standby provides a failover target within the Region. It is not used to serve read traffic, and Multi-AZ does not provide protection against the loss of the whole Region.

## Private network access

The application instances have no public IP addresses. They receive inbound traffic from the ALB and use per-zone NAT gateways for outbound connectivity. Separate database subnets keep the database out of the direct internet routing path. The EC2 role supports Systems Manager access without opening SSH to the internet.

Two NAT gateways were used to avoid routing private application traffic through a gateway in the other Availability Zone. The trade-off is an additional hourly and data-processing cost while the environment is running.

## Database authentication and connectivity

RDS Proxy sits between the application and PostgreSQL. The application uses IAM authentication tokens rather than storing a database password in its Python code, and TLS is required on the client connection. Secrets Manager holds credentials used by the proxy to authenticate to PostgreSQL.

The database user and secret value needed manual preparation. Terraform manages the infrastructure and secret resource, but not every database-level bootstrap step.

## Migration with full load and CDC

I used AWS DMS to separate the transfer of existing records from the replication of later changes. Starting with 1,000 rows made it possible to compare baseline totals, then inspect how inserts, updates and deletes were reflected at the target. The final comparison included row counts, aggregates and an ordered row checksum.

The exercise simulated a controlled cutover check, but it did not implement an application endpoint switch, an enforced source write lock or a reverse-replication rollback.

## Monitoring alongside failure tests

CloudWatch metrics and alarms were added before deliberately terminating an EC2 instance and initiating database failover. This allowed the test outcomes to be compared with resource states and application responses. SNS email delivery was tested using an explicit alarm-state change.

## Scope

This was a short-lived infrastructure lab. The public ALB served HTTP traffic, the application was a small test service, and the resources were destroyed after validation to limit cost. Production-facing TLS termination, demand-based scaling and automated migration rollback were not part of the exercise.
