variable "region" {
  description = "デプロイするリージョン"
  type        = string
}

variable "tags" {
  description = "リソースに適用する共通タグ"
  type        = map(string)
  default     = {}
}

variable "cloudwatch_agent_config" {
  description = "CloudWatch Agent の設定（JSON 文字列）"
  type        = string
  default     = ""
}

variable "log_group_retention_days" {
  description = "CloudWatch Logs の保持日数"
  type        = number
  default     = 14
}
