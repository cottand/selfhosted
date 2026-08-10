# Buckets

We use Backblaze B2 buckets as an S3 replacement for whatever
services need blob storage.

These are specified as IaC in `./terraform/base/buckets.tf`.

The module at `./terraform/modules/b2-bucket` also conveniently
provisions bucket credentials and leaves them in vault for use
by nomad jobs (see [nixmad](./nixmad.md)). Make sure the secret path
corresponds to the job name so that the job can access it at its namespace.