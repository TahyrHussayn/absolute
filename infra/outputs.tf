output "cluster_nodes" {
  description = "Summary of deployed BEAM cluster nodes"
  value = [
    for i, instance in aws_instance.beam_nodes : {
      node_name        = "absolute-node-${i + 1}"
      public_ip        = instance.public_ip
      private_ip       = instance.private_ip
      beam_node_id     = "absolute@${instance.private_ip}"
      url              = "http://${instance.public_ip}"
      cluster_page     = "http://${instance.public_ip}/cluster"
      playground       = "http://${instance.public_ip}/playground"
      metrics_endpoint = "http://${instance.public_ip}/metrics"
      live_dashboard   = "http://${instance.public_ip}/admin/dashboard"
      grafana_url      = "http://${instance.public_ip}:3000"
      prometheus_url   = "http://${instance.public_ip}:9090"
      ssh_command      = "ssh ubuntu@${instance.public_ip}"
    }
  ]
}

output "github_oidc_role_arn" {
  description = "IAM Role ARN assumed by GitHub Actions via OIDC keyless authentication"
  value       = aws_iam_role.github_actions.arn
}

output "ssm_parameter_prefix" {
  description = "Prefix for AWS SSM Parameter Store encrypted secrets"
  value       = "/absolute/${var.environment}"
}
