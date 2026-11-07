# Phase 3 — PostgreSQL full load followed by CDC.

resource "aws_dms_replication_task" "orders" {
  replication_task_id      = "continuum-orders-cdc"
  migration_type           = "full-load-and-cdc"
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn

  source_endpoint_arn = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn = aws_dms_endpoint.target.endpoint_arn

  table_mappings = jsonencode({
    rules = [{
      "rule-type"   = "selection"
      "rule-id"     = "1"
      "rule-name"   = "include-orders"
      "rule-action" = "include"

      "object-locator" = {
        "schema-name" = "migration_demo"
        "table-name"  = "orders"
      }
    }]
  })

  replication_task_settings = jsonencode({
    FullLoadSettings = {
      TargetTablePrepMode             = "DO_NOTHING"
      StopTaskCachedChangesApplied    = false
      StopTaskCachedChangesNotApplied = false
    }
    Logging = {
      EnableLogging = true
    }
  })

  tags = {
    Name = "continuum-orders-cdc"
  }

  depends_on = [
    aws_iam_role_policy_attachment.dms_cloudwatch
  ]
}
