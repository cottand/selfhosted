namespace "*" {
  policy       = "read"


variables {
    path "public/*" {
      capabilities = ["read"]
  }
}
}

agent {
  policy = "read"
}

operator {
  policy = "read"
}

quota {
  policy = "read"
}

node {
  policy = "read"
}

host_volume "*" {
  policy = "read"
}
