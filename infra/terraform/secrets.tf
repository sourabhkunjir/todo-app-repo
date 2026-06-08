resource "aws_secretsmanager_secret" "app" {
  name        = "${local.name}/app"
  description = "Todo app secrets (MongoDB URI, frontend URL for CORS)"
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  secret_string = jsonencode({
    MONGODB_URI  = var.mongodb_uri
    FRONTEND_URL = var.frontend_url
  })
}
