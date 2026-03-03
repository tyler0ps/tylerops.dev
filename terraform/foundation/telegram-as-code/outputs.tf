output "webhook_url" {
  value = "${aws_apigatewayv2_stage.default.invoke_url}/webhook"
}

output "webhook_secret" {
  value     = random_password.webhook_secret.result
  sensitive = true
}

# Run this after apply to register the webhook with Telegram
output "register_webhook_cmd" {
  sensitive = true
  value     = <<-EOT
    BOT_TOKEN=$(aws ssm get-parameter --name ${var.bot_token_ssm_path} --with-decryption --query Parameter.Value --output text)
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/setWebhook" \
      --data-urlencode "url=${aws_apigatewayv2_stage.default.invoke_url}/webhook" \
      --data-urlencode "secret_token=${random_password.webhook_secret.result}"
  EOT
}
