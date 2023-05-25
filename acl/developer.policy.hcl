namespace "*" {
  capabilities = ["alloc-node-exec"]
  policy = "write"
    variables {
        path "public/*" {
        capabilities = ["read", "write", "destroy"]
    }
    }
}

node {
  policy = "write"
}


agent {
  policy = "write"
}

operator {
  policy = "write"
}

quota {
  policy = "write"
}

node {
  policy = "write"
}

host_volume "*" {
  policy = "write"
}