
namespace "*" {
      policy = "read"
      variables {
        # list access to variables in all paths, full access in nested/variables/*
        path "*" {
          capabilities = ["list", "read"]
          }
    }
}