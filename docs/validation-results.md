# Validation results

The project was tested through controlled EC2 replacement, PostgreSQL failover, DMS migration and CloudWatch notification exercises. The observations below describe the conditions and outcomes of those tests.

## EC2 instance replacement

An application instance was deliberately terminated without reducing the Auto Scaling Group's desired capacity. The ASG launched a replacement, and the ALB returned to two healthy targets in approximately **2 minutes and 1 second**.

During the observation window, **148 of 148** sampled requests to `/health` returned HTTP 200. This shows that the health endpoint remained responsive during the recorded samples. It does not measure database connectivity or guarantee uninterrupted service between samples.

## PostgreSQL Multi-AZ failover

An RDS Multi-AZ failover was initiated while `/db-health` was sampled repeatedly. The primary database role moved from `eu-west-1a` to `eu-west-1b`. RDS Proxy subsequently reported an available database target, and the SQL health check recovered.

Of **101** SQL-backed HTTP probes, **99 returned HTTP 200**. The other two requests timed out after **8 seconds** each. The sampled success rate was **98.02%**. These results demonstrate a brief disruption under the test conditions, rather than an exact database outage duration or a general recovery-time guarantee.

## PostgreSQL full load and CDC

AWS DMS initially transferred **1,000 rows** from `migration_demo.orders` without reported full-load table errors. Source and target baseline row counts and aggregate amounts matched.

The CDC test then made **10 inserts, 5 updates and 5 deletes**. The resulting source and target tables each contained **1,005 rows**, with an amount total of **632006.25**. The recorded ordered row checksum also matched on both sides. Nine one-minute CloudWatch samples for source and target CDC latency reported 0.0 seconds; that metric observation does not establish zero end-to-end replication delay.

A final consistency check was performed after a declared source write freeze. This was a procedural cutover simulation, not an enforced database lock or a real application traffic switch. Rollback and reverse replication were not tested.

## Monitoring and alerts

The CloudWatch dashboard displayed ALB request volume, healthy hosts, target response time and RDS metrics. Five alarms were configured. SNS email delivery was confirmed, including a test in which a CloudWatch alarm was manually placed into the `ALARM` state and later returned to `OK`.

This verified the notification route. It did not demonstrate a naturally occurring CPU, storage or error-rate threshold breach.

## Teardown

After the tests, Terraform reported **62 resources destroyed** and no remaining resources in its managed state. Additional regional checks found no remaining instances, load balancers, Auto Scaling Groups, RDS instances or proxies, or NAT gateways among the checked services. The remote Terraform backend was retained, and deletion of earlier DMS secrets had been scheduled separately.

The results are based on the recorded lab verification outputs. The measurements should not be interpreted as production availability or performance guarantees.
