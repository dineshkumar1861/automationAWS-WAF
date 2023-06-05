resource "aws_wafv2_rule_group" "sql-injection-rule" {
  name        = "sql-injection-rule"
  capacity    = 100
  scope       = "REGIONAL"
  description = "Rule group for SQL injection protection"
  visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SqlInjectionRuleMetrics"
      sampled_requests_enabled   = true
  }

  rule {
    name     = "block-sqli"
    priority = 1

    action {
      block {}
    }

    statement {
      sqli_match_statement {
        field_to_match {
          single_header {
            name = "referer"
          }
        }

        text_transformation {
          priority = 1
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "sqliVisibilityConfig"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_wafv2_rule_group" "xss-rule" {
  name        = "xss-rule"
  capacity    = 100
  scope       = "REGIONAL"
  description = "Rule group for XSS protection"
  visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "XssRuleMetrics"
      sampled_requests_enabled   = true
  }

  rule {
    name     = "block-xss"
    priority = 1

    action {
      block {}
    }

    statement {
      xss_match_statement {
        field_to_match {
          single_header {
            name = "user-agent"
          }
        }

        text_transformation {
          priority = 1
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "xssVisibilityConfig"
      sampled_requests_enabled   = true
    }
  }
}
