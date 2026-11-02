# traceroot-terraform-aws

Terraform module to deploy [TraceRoot](https://github.com/traceroot-ai/traceroot) on AWS.

Provisions the VPC, EKS cluster, RDS (PostgreSQL), ElastiCache (Redis), ECR, S3, EFS, ACM and
ALB ingress, then installs the
[traceroot Helm chart](https://github.com/traceroot-ai/traceroot-k8s) into the cluster.

## Usage

```hcl
module "traceroot" {
  source = "github.com/traceroot-ai/traceroot-terraform-aws?ref=v1.6.0"

  environment = "production"
  name        = "traceroot-production"
  aws_region  = "us-east-1"
  vpc_cidr    = "10.0.0.0/16"
  domain      = "traceroot.example.com"
  image_tag   = "sha-1a321eb"

  traceroot_helm_chart_version = "1.0.0"
}
```

Pin `ref` to a tag rather than tracking `main`, so environments upgrade deliberately.

See [`examples/quickstart`](examples/quickstart) for a runnable example and
[`variables.tf`](variables.tf) for every input.

## Secrets

This module **generates** the application's internal secrets (session signing, internal API,
database and cache passwords) with `random_password`, and writes them into Kubernetes Secrets.
Values you supply — Stripe, GitHub App, LLM provider keys — are passed as variables.

Terraform state therefore contains secret material. Use a remote backend with encryption at
rest, and never commit `.tfvars` or state files.

## S3 lifecycle

The bucket is versioned, and lifecycle rules expire two ingest prefixes:

| Prefix | Expires after | Input |
|---|---|---|
| `events/ingest/` (staged ingest batches) | 7 days | `ingest_batch_expiration_days` |
| `events/failed/` (batches that failed processing) | 30 days | `ingest_failed_expiration_days` |

Every noncurrent version under those prefixes is removed after 1 day
(`noncurrent_version_expiration_days`), whether its object expired, was deleted or was
overwritten, so no older version is kept there longer than that. The delete marker an expired
or deleted object leaves behind is then cleaned up.
Incomplete multipart uploads under `events/ingest/` are aborted after 1 day.

Only `events/ingest/` and `events/failed/` expire. Everything else in the bucket is kept,
including any batches under `events/otel/`.

Ages count from when each object was written (for a noncurrent version, from when it became
noncurrent), not from when the rules were applied. An object already under `events/ingest/` or
`events/failed/` and older than its window when the rules are first applied expires shortly
after the apply, not 7 or 30 days later.

This module manages the bucket's whole lifecycle configuration. S3 keeps one lifecycle
configuration per bucket, so applying the module replaces any lifecycle rule set outside it,
whether in the console, with the AWS CLI or by another `aws_s3_bucket_lifecycle_configuration`.
To keep a custom rule, add it to `aws_s3_bucket_lifecycle_configuration.traceroot` in `s3.tf`.

## Worker resources

`worker_resources` sets the CPU and memory requests and limits of each worker pod. The default
matches the chart's worker defaults: requests of 250m CPU and 512Mi memory, and limits of 1 CPU
and 1Gi memory. Raise the memory limit if worker pods are restarted with `OOMKilled`:

```hcl
module "traceroot" {
  # ...

  worker_resources = {
    requests = { cpu = "250m", memory = "512Mi" }
    limits   = { cpu = "1", memory = "2Gi" }
  }
}
```

When you apply this repository directly with a `.tfvars` file, put the same `worker_resources`
assignment at the top level of that file instead.

Set all four values, and keep each request at or below its limit. The values use a subset of
Kubernetes quantity syntax:

- **CPU:** a number of cores, optionally with an `m`, `u` or `n` suffix: `1`, `1.5`, `.5`,
  `250m`.
- **Memory:** a number of bytes, optionally with a `k`, `M`, `G`, `T`, `Ki`, `Mi`, `Gi` or `Ti`
  suffix: `512Mi`, `1.5Gi`, `2G`.

Signs, exponents (`1e3`), the `P`, `E`, `Pi` and `Ei` suffixes, and `m`, `u` or `n` on memory
are rejected at plan.

## Requirements

| | |
|---|---|
| Terraform | >= 1.5 |
| AWS provider | >= 5.0 |
| Permissions | ability to create VPC, EKS, RDS, ElastiCache, ECR, S3, EFS, IAM, ACM, Route53 |
