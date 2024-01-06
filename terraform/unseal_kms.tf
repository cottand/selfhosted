
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



//--------------------------------------------------------------------
// Data Sources

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}


# IAM

resource "aws_iam_user" "vault-server" {
  name = "vault-server"
}

resource "aws_iam_access_key" "vault-server-unseal" {
  user = aws_iam_user.vault-server.id
}

resource "local_sensitive_file" "vault-server-access-key-env" {
  content  = <<EOT
  # tf-generated
  AWS_ACCESS_KEY_ID=${aws_iam_access_key.vault-server-unseal.id}
  AWS_SECRET_ACCESS_KEY=${aws_iam_access_key.vault-server-unseal.secret}
  EOT
  filename = "../secret/aws/vault.env"
}

## Vault Server IAM Config
resource "aws_iam_user_policy" "vault-server-kms" {
  name   = "vault-server-kms"
  user   = aws_iam_user.vault-server.name
  policy = data.aws_iam_policy_document.vault-server.json
}

data "aws_iam_policy_document" "vault-server" {
  #   statement {
  #     sid    = "RaftSingle"
  #     effect = "Allow"

  #     actions = ["ec2:DescribeInstances"]

  #     resources = ["*"]
  #   }

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
