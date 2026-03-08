data "aws_ssm_parameter" "allowed_chat_id" {
  name            = "/terraform/infrastructure-as-bot/allowed_chat_id"
  with_decryption = true
}
