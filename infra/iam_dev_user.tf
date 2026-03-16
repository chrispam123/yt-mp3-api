# =============================================================================
# iam_dev_user.tf
# Permisos adicionales para el usuario de desarrollo yt_mp3_api_dev.
# Permite leer logs de CloudWatch para depurar problemas en desarrollo.
# =============================================================================

resource "aws_iam_user_policy" "dev_user_logs" {
  name = "${var.project_name}-dev-user-logs-policy"
  user = "yt_mp3_api_dev"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsRead"
        Effect = "Allow"
        Action = [
          "logs:FilterLogEvents",
          "logs:GetLogEvents",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:eu-west-1:${var.aws_account_id}:log-group:/aws/lambda/${var.project_name}-*:*"
      }
    ]
  })
}
