# deploy/terraform/aws/variables.tf

variable "name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "traceroot"
}

variable "manage_app_secrets" {
  description = "When true (default), the module generates app secrets and creates the Kubernetes Secrets itself (turnkey self-hosting). Set false to provide app secrets externally (e.g. External Secrets Operator); the module then creates none of the app Secrets and generates none of the app-only values. Infrastructure passwords (RDS/ElastiCache) are always managed regardless."
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment name — controls namespace (traceroot-{env}) and database (traceroot_{env}). Use Terraform workspaces to isolate state per environment."
  type        = string
  default     = "staging"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.environment))
    error_message = "Environment must be lowercase alphanumeric with hyphens (e.g. staging, production)."
  }
}

variable "image_tag" {
  description = "Docker image tag for all services. Must be a git SHA (e.g. sha-abc1234). Never use 'latest' — the daily CI build overwrites it."
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

# --- VPC ---
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# --- EKS ---
variable "kubernetes_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.32"
}

variable "fargate_profile_namespaces" {
  description = "Namespaces for Fargate profiles"
  type        = list(string)
  default     = ["kube-system", "default"]
}

# --- ECR ---
variable "ecr_image_retention_count" {
  description = "Number of tagged builds to keep per ECR repository; older ones are expired by the lifecycle policy. Counts builds, not manifests: the index, platform image and attestation of one push count once. The build tagged \"deployed\" counts toward this number and is never expired, even after it falls out of the newest builds. Keep at least 2 so the build before the running one stays available for rollback."
  type        = number
  default     = 5

  validation {
    condition     = var.ecr_image_retention_count >= 1
    error_message = "ecr_image_retention_count must be at least 1."
  }
}

# --- RDS ---
variable "postgres_min_capacity" {
  description = "Aurora Serverless v2 minimum ACUs"
  type        = number
  default     = 0.5
}

variable "postgres_max_capacity" {
  description = "Aurora Serverless v2 maximum ACUs"
  type        = number
  default     = 2.0
}

# --- ElastiCache ---
variable "cache_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t4g.micro"
}

# --- S3 ---
variable "ingest_batch_expiration_days" {
  description = "Days to keep staged ingest batches (objects under events/ingest/ in the S3 bucket) before they expire. Objects under events/otel/ are not expired."
  type        = number
  default     = 7

  validation {
    condition     = var.ingest_batch_expiration_days >= 1 && floor(var.ingest_batch_expiration_days) == var.ingest_batch_expiration_days
    error_message = "ingest_batch_expiration_days must be a whole number of days, at least 1."
  }
}

variable "ingest_failed_expiration_days" {
  description = "Days to keep ingest batches that failed processing (objects under events/failed/ in the S3 bucket) before they expire."
  type        = number
  default     = 30

  validation {
    condition     = var.ingest_failed_expiration_days >= 1 && floor(var.ingest_failed_expiration_days) == var.ingest_failed_expiration_days
    error_message = "ingest_failed_expiration_days must be a whole number of days, at least 1."
  }
}

variable "ingest_noncurrent_version_expiration_days" {
  description = "Days to keep every noncurrent version of an object under events/ingest/ or events/failed/ in the S3 bucket, whether the object expired, was deleted or was overwritten. The bucket is versioned, so an expired or deleted batch's data is only removed when its noncurrent version expires."
  type        = number
  default     = 1

  validation {
    condition     = var.ingest_noncurrent_version_expiration_days >= 1 && floor(var.ingest_noncurrent_version_expiration_days) == var.ingest_noncurrent_version_expiration_days
    error_message = "ingest_noncurrent_version_expiration_days must be a whole number of days, at least 1."
  }
}

# --- Helm ---
variable "traceroot_helm_chart_repository" {
  description = "Helm repository serving the TraceRoot chart"
  type        = string
  default     = "https://traceroot-ai.github.io/traceroot-k8s"
}

variable "traceroot_helm_chart_version" {
  description = "Version of the TraceRoot Helm chart to deploy. Pin this; do not track latest. Charts before 1.0.1 omit the ALB health-check paths, so every target is unhealthy."
  type        = string
  default     = "1.1.2"
}

# --- ClickHouse (EFS storage) ---
variable "clickhouse_replica_count" {
  description = "Number of ClickHouse replicas (each gets a separate EFS access point)"
  type        = number
  default     = 1
}

variable "clickhouse_storage_size" {
  description = "Storage size for each ClickHouse replica"
  type        = string
  default     = "20Gi"
}

variable "enable_clickhouse_log_tables" {
  description = "Enable ClickHouse's built-in system log tables (trace_log, metric_log, asynchronous_metric_log, etc.). Disabled by default: their unbounded growth and background merges can OOM-kill ClickHouse on a memory-capped box. query_log/part_log/error_log are always kept for debugging."
  type        = bool
  default     = false
}

variable "enable_sql_gateway" {
  description = "Provision the ClickHouse identities the public SQL gateway needs: an account that owns the curated read-only views and a least-privileged user that customer SQL runs as. Disabled by default. Requires a chart version that carries the provisioning hooks. When app secrets are delivered externally, the read-only password must already exist in that source under the key the chart reads (clickhouse-ro-password); the module generates it only on the turnkey path. The view owner needs no password, since nothing authenticates as it."
  type        = bool
  default     = false
}

variable "clickhouse_namespace" {
  description = "Kubernetes namespace where ClickHouse will be deployed. Defaults to traceroot-{environment}."
  type        = string
  default     = ""
}

# --- Custom Domain + TLS ---
variable "domain" {
  description = "Custom domain for the app (e.g. app.traceroot.ai). Empty = use ALB URL."
  type        = string
  default     = ""
}


# --- GitHub App ---
variable "github_app_id" {
  description = "GitHub App ID"
  type        = string
  default     = ""
}

variable "github_app_name" {
  description = "GitHub App name"
  type        = string
  default     = ""
}

variable "github_app_client_id" {
  description = "GitHub App Client ID"
  type        = string
  default     = ""
}

variable "github_app_client_secret" {
  description = "GitHub App Client Secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_app_private_key" {
  description = "GitHub App Private Key (PEM format)"
  type        = string
  sensitive   = true
  default     = ""
}

# --- LLM API Keys ---
variable "anthropic_api_key" {
  description = "Anthropic API key for system-provided models"
  type        = string
  sensitive   = true
  default     = ""
}

variable "openai_api_key" {
  description = "OpenAI API key for system-provided models"
  type        = string
  sensitive   = true
  default     = ""
}

variable "daytona_api_key" {
  description = "Daytona API key for sandbox execution"
  type        = string
  sensitive   = true
  default     = ""
}

# --- Stripe Billing ---
variable "stripe_secret_key" {
  description = "Stripe secret key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "stripe_webhook_signing_secret" {
  description = "Stripe webhook signing secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "stripe_price_id_starter" {
  description = "Stripe price ID for Starter plan"
  type        = string
  default     = ""
}

variable "stripe_price_id_pro" {
  description = "Stripe price ID for Pro plan"
  type        = string
  default     = ""
}

variable "stripe_price_id_ai_usage" {
  description = "Stripe price ID for AI usage metering"
  type        = string
  default     = ""
}

variable "stripe_price_id_rca_usage" {
  description = "Stripe price ID for RCA usage metering"
  type        = string
  default     = ""
}

variable "stripe_price_id_detector_usage" {
  description = "Stripe price ID for managed detector inference metering"
  type        = string
  default     = ""
}

# --- Slack OAuth (workspace-level integration) ---
# SLACK_STATE_SECRET is auto-generated (random_password.slack_state_secret).
# Redirect URI is computed from var.domain in secrets.tf.
variable "slack_client_id" {
  description = "Slack App Client ID (from api.slack.com → Basic Information)"
  type        = string
  default     = ""
}

variable "slack_client_secret" {
  description = "Slack App Client Secret"
  type        = string
  sensitive   = true
  default     = ""
}

# --- Google OAuth ---
variable "google_oauth_client_id" {
  description = "Google OAuth client ID"
  type        = string
  default     = ""
}

variable "google_oauth_client_secret" {
  description = "Google OAuth client secret"
  type        = string
  sensitive   = true
  default     = ""
}

# --- Email / SMTP ---
variable "smtp_url" {
  description = "SMTP URL (e.g. smtp://user:pass@host:port)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "smtp_mail_from" {
  description = "SMTP sender email address"
  type        = string
  default     = ""
}

# --- Enterprise License ---
variable "enterprise_license_key" {
  description = "Enterprise edition license key"
  type        = string
  sensitive   = true
  default     = ""
}

# --- Feature Flags ---
variable "enable_billing" {
  description = "Enable billing features (set false for self-hosted to unlock all features)"
  type        = string
  default     = "true"
}

# --- Replicas ---
variable "web_replicas" {
  description = "Number of web replicas"
  type        = number
  default     = 1
}

variable "rest_replicas" {
  description = "Number of REST API replicas"
  type        = number
  default     = 1
}

variable "worker_replicas" {
  description = "Number of Celery worker replicas"
  type        = number
  default     = 1
}

# --- Worker resources ---
variable "worker_resources" {
  description = "CPU and memory requests and limits for each worker pod. A value left out keeps its default, which matches the chart's worker defaults. CPU is whole cores or millicores (\"1\", \"250m\"). Memory is a whole number of Mi or Gi (\"512Mi\", \"2Gi\"), so 1.5Gi is written \"1536Mi\". Each request must not exceed its limit."
  type = object({
    requests = optional(object({
      cpu    = optional(string, "250m")
      memory = optional(string, "512Mi")
    }), {})
    limits = optional(object({
      cpu    = optional(string, "1")
      memory = optional(string, "1Gi")
    }), {})
  })
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for q in [var.worker_resources.requests.cpu, var.worker_resources.limits.cpu] :
      can(regex("^[0-9]+m?$", q))
    ])
    error_message = "worker_resources CPU values must be whole cores or millicores, such as \"1\" or \"250m\"."
  }

  validation {
    condition = alltrue([
      for q in [var.worker_resources.requests.memory, var.worker_resources.limits.memory] :
      can(regex("^[0-9]+(Mi|Gi)$", q))
    ])
    error_message = "worker_resources memory values must be a whole number of Mi or Gi, such as \"512Mi\" or \"2Gi\"."
  }

  # Kubernetes rejects a pod whose request is above its limit. CPU is compared in
  # millicores and memory in MiB, so both sides are whole numbers. A value the
  # checks above reject becomes -1 and its pair is skipped, so it is reported once,
  # by its format check. A value they accept is parsed with no fallback, so a
  # parse failure is an error rather than a pass.
  validation {
    condition = alltrue([
      for pair in [
        [
          for q in [var.worker_resources.requests.cpu, var.worker_resources.limits.cpu] :
          can(regex("^[0-9]+m?$", q)) ? tonumber(trimsuffix(q, "m")) * (endswith(q, "m") ? 1 : 1000) : -1
        ],
        [
          for q in [var.worker_resources.requests.memory, var.worker_resources.limits.memory] :
          can(regex("^[0-9]+(Mi|Gi)$", q)) ? tonumber(trimsuffix(trimsuffix(q, "Gi"), "Mi")) * (endswith(q, "Gi") ? 1024 : 1) : -1
        ],
      ] : contains(pair, -1) || pair[0] <= pair[1]
    ])
    error_message = "worker_resources requests must not exceed the matching limits."
  }
}

# --- Detector resources ---
variable "detector_resources" {
  description = "CPU and memory requests and limits for each detector pod. A value left out keeps its default, which matches the chart's detector defaults. CPU is whole cores or millicores (\"1\", \"250m\"). Memory is a whole number of Mi or Gi (\"512Mi\", \"2Gi\"), so 1.5Gi is written \"1536Mi\". Each request must not exceed its limit."
  type = object({
    requests = optional(object({
      cpu    = optional(string, "250m")
      memory = optional(string, "512Mi")
    }), {})
    limits = optional(object({
      cpu    = optional(string, "1")
      memory = optional(string, "1Gi")
    }), {})
  })
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for q in [var.detector_resources.requests.cpu, var.detector_resources.limits.cpu] :
      can(regex("^[0-9]+m?$", q))
    ])
    error_message = "detector_resources CPU values must be whole cores or millicores, such as \"1\" or \"250m\"."
  }

  validation {
    condition = alltrue([
      for q in [var.detector_resources.requests.memory, var.detector_resources.limits.memory] :
      can(regex("^[0-9]+(Mi|Gi)$", q))
    ])
    error_message = "detector_resources memory values must be a whole number of Mi or Gi, such as \"512Mi\" or \"2Gi\"."
  }

  # Kubernetes rejects a pod whose request is above its limit. CPU is compared in
  # millicores and memory in MiB, so both sides are whole numbers. A value the
  # checks above reject becomes -1 and its pair is skipped, so it is reported once,
  # by its format check. A value they accept is parsed with no fallback, so a
  # parse failure is an error rather than a pass.
  validation {
    condition = alltrue([
      for pair in [
        [
          for q in [var.detector_resources.requests.cpu, var.detector_resources.limits.cpu] :
          can(regex("^[0-9]+m?$", q)) ? tonumber(trimsuffix(q, "m")) * (endswith(q, "m") ? 1 : 1000) : -1
        ],
        [
          for q in [var.detector_resources.requests.memory, var.detector_resources.limits.memory] :
          can(regex("^[0-9]+(Mi|Gi)$", q)) ? tonumber(trimsuffix(trimsuffix(q, "Gi"), "Mi")) * (endswith(q, "Gi") ? 1024 : 1) : -1
        ],
      ] : contains(pair, -1) || pair[0] <= pair[1]
    ])
    error_message = "detector_resources requests must not exceed the matching limits."
  }
}

# --- ALB ---
variable "alb_scheme" {
  description = "ALB scheme: internet-facing or internal"
  type        = string
  default     = "internet-facing"
}

# --- Additional environment variables ---
# Catch-all for any env vars not covered above (Google OAuth, SMTP, Stripe, etc.)
# Each entry has either `value` (plain text) or `valueFrom` (secret ref).
#
# Example usage in terraform.tfvars:
#   additional_env = [
#     { name = "AUTH_GOOGLE_CLIENT_ID",     value = "123456.apps.googleusercontent.com" },
#     { name = "ENABLE_BILLING",            value = "true" },
#     { name = "STRIPE_SECRET_KEY", valueFrom = {
#       secretKeyRef = { name = "my-stripe-secret", key = "secret-key" }
#     }},
#   ]
variable "additional_env" {
  description = "Additional environment variables for all TraceRoot pods"
  type = list(object({
    name  = string
    value = optional(string)
    valueFrom = optional(object({
      secretKeyRef = optional(object({
        name = string
        key  = string
      }))
      configMapKeyRef = optional(object({
        name = string
        key  = string
      }))
    }))
  }))
  default = []

  validation {
    condition = alltrue([
      for env in var.additional_env :
      (env.value != null && env.valueFrom == null) || (env.value == null && env.valueFrom != null)
    ])
    error_message = "Each environment variable must have either 'value' or 'valueFrom' specified, but not both."
  }
}

variable "enable_cluster_creator_admin_permissions" {
  description = <<-EOT
    Grant Kubernetes cluster-admin to the identity that runs Terraform.

    True is right when one identity always applies. Set false when more than one
    does — otherwise whoever applies last replaces the previous one's access
    entry, removing their kubectl access. Declare `access_entries` instead.
  EOT
  type        = bool
  default     = true
}

variable "access_entries" {
  description = <<-EOT
    EKS access entries, passed through to the upstream EKS module. See its
    documentation for the shape. Use together with
    enable_cluster_creator_admin_permissions = false to state cluster access
    explicitly rather than inferring it from the caller.
  EOT
  type        = any
  default     = {}
}

variable "kms_key_administrators" {
  description = <<-EOT
    IAM principal ARNs that administer the EKS KMS key.

    Empty (the default) hands administration to whichever identity runs
    Terraform, which is fine when that is always the same one. When several
    apply — a person and a CI role, say — the key policy is rewritten on every
    apply and every plan shows a diff. List them explicitly in that case.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for a in var.kms_key_administrators : startswith(a, "arn:")])
    error_message = "Each entry must be a full IAM principal ARN, e.g. arn:aws:iam::123456789012:role/example. A bare role name or account id is rejected here rather than failing later with an opaque KMS policy error."
  }
}

variable "eks_log_retention_in_days" {
  description = "Retention for the EKS control-plane CloudWatch log group (/aws/eks/<name>/cluster). 365 satisfies the SOC 2 one-year log retention control."
  type        = number
  default     = 365
}
