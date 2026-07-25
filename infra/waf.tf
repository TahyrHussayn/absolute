resource "aws_wafv2_web_acl" "alb_waf" {
  name        = "absolute-waf-${var.environment}"
  description = "WAF for Absolute ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "rate-limit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "WAFRateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "absolute-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "absolute-waf"
    Environment = var.environment
  }
}

resource "aws_wafv2_web_acl_association" "alb_waf_assoc" {
  resource_arn = aws_lb.absolute_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.alb_waf.arn
}
