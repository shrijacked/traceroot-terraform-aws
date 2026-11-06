# traceroot-terraform-aws

Terraform module to deploy [TraceRoot](https://github.com/traceroot-ai/traceroot) on AWS.

Provisions the VPC, EKS cluster, RDS (PostgreSQL), ElastiCache (Redis), ECR, S3, EFS, ACM and
ALB ingress, then installs the
[traceroot Helm chart](https://github.com/traceroot-ai/traceroot-k8s) into the cluster.

## Usage

```hcl
module "traceroot" {
  source = "github.com/traceroot-ai/traceroot-terraform-aws?ref=v1.7.0"

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

The bucket's lifecycle rules expire staged and failed ingest batches. The prefixes, windows and
defaults are in the `ingest_*_expiration_days` inputs in [`variables.tf`](variables.tf).

S3 keeps one lifecycle configuration per bucket, so applying the module replaces any lifecycle
rule set outside Terraform. To keep a custom rule, add it to
`aws_s3_bucket_lifecycle_configuration.traceroot` in `s3.tf`.

## ECR lifecycle

Each repository keeps the last `ecr_image_retention_count` tagged builds and expires untagged
manifests that no kept build references. The count is by push, not by deploy, so the policy also
never expires the build tagged `deployed`, even after newer pushes overtake it.

The module does not set that tag. Your deploy pipeline must move `deployed` onto the image it
rolled out, in every repository, after each successful deploy (traceroot-infra's `deploy.yml`
does this). Without the tag, a few pushes that are not deployed can expire the running image, and
pods that restart cannot pull it.

## Worker resources

`worker_resources` sets the CPU and memory requests and limits of each worker pod. Raise the
memory limit if worker pods are restarted with `OOMKilled`:

```hcl
module "traceroot" {
  # ...

  worker_resources = {
    limits = { memory = "2Gi" }
  }
}
```

In a `.tfvars` file, put the same assignment at the top level. The defaults and accepted values
are in [`variables.tf`](variables.tf).

## Detector resources

`detector_resources` sets the CPU and memory requests and limits of the detector pod. The
detector is a Node.js process whose default heap size follows the container's memory, so raise
the memory if detector pods crash with `JavaScript heap out of memory`. On Fargate, a pod is sized
from its requests, so raise the requests along with the limits:

```hcl
module "traceroot" {
  # ...

  detector_resources = {
    requests = { cpu = "1", memory = "3Gi" }
    limits   = { cpu = "1", memory = "3Gi" }
  }
}
```

In a `.tfvars` file, put the same assignment at the top level. The defaults and accepted values
are in [`variables.tf`](variables.tf).

## Requirements

| | |
|---|---|
| Terraform | >= 1.5 |
| AWS provider | >= 5.0 |
| Permissions | ability to create VPC, EKS, RDS, ElastiCache, ECR, S3, EFS, IAM, ACM, Route53 |
