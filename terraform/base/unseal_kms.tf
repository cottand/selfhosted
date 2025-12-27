
resource "aws_kms_key" "vault" {
  description             = "Vault unseal key"
  deletion_window_in_days = 7

  tags = {
    Name = "vault-kms-unseal-key"
  }
}

resource "aws_kms_alias" "vault" {
  name          = "alias/vault-kms-unseal-key"
  target_key_id = aws_kms_key.vault.key_id
}


# IAM

resource "aws_iam_user" "vault-server2" {
  name = "vault-server2"
}

resource "aws_iam_access_key" "vault-server-unseal2" {
  user = aws_iam_user.vault-server2.id
}


import {
  id = "f14a73b1-908f-4d54-8cdf-f4239354daa0"
  to = bitwarden-secrets_secret.vault-kms-creds
}
resource "bitwarden-secrets_secret" "vault-kms-creds" {
  key        = "awsKms/vault.env"
  value      = <<EOT
# tf-generated
AWS_ACCESS_KEY_ID=${aws_iam_access_key.vault-server-unseal2.id}
AWS_SECRET_ACCESS_KEY=${aws_iam_access_key.vault-server-unseal2.secret}
EOT
  project_id = var.bitwarden_project_id
}

output "vault-kms-creds-bw-secret-id" {
  value = bitwarden-secrets_secret.vault-kms-creds.id
}

## Vault Server IAM Config
resource "aws_iam_user_policy" "vault-server-kms" {
  name   = "vault-server-kms"
  user   = aws_iam_user.vault-server2.name
  policy = data.aws_iam_policy_document.vault-server.json
}

data "aws_iam_policy_document" "vault-server" {
  statement {
    sid    = "VaultAWSAuthMethod"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "iam:GetInstanceProfile",
      "iam:GetUser",
      "iam:GetRole",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "VaultKMSUnseal"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey",
    ]

    resources = ["*"]
  }
}
