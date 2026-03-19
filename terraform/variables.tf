variable "service_account_email" {
  description = "EntropyFabric service account email that will receive onboarding access."
  type        = string

  validation {
    condition = can(
      regex(
        "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.iam\\.gserviceaccount\\.com$",
        var.service_account_email,
      )
    )
    error_message = "service_account_email must be a Google Cloud service account email."
  }
}

variable "billing_account_id" {
  description = "Customer billing account ID in 000000-000000-000000 format."
  type        = string

  validation {
    condition     = can(regex("^[A-Z0-9]{6}-[A-Z0-9]{6}-[A-Z0-9]{6}$", var.billing_account_id))
    error_message = "billing_account_id must use the format 000000-000000-000000."
  }
}

variable "organization_id" {
  description = "Organization ID where EntropyFabric should receive org-scoped discovery access."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.organization_id))
    error_message = "organization_id must be numeric."
  }
}

variable "billing_role" {
  description = "Billing account role to grant."
  type        = string
  default     = "roles/billing.viewer"
}

variable "organization_role" {
  description = "Baseline organization role to grant for hierarchy discovery."
  type        = string
  default     = "roles/browser"
}

variable "enable_cloud_assets" {
  description = "Grant roles/cloudasset.viewer and roles/serviceusage.serviceUsageConsumer at org scope."
  type        = bool
  default     = true
}

variable "enable_recommender" {
  description = "Grant roles/recommender.viewer at org scope."
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Grant roles/monitoring.viewer at org scope."
  type        = bool
  default     = true
}

variable "enable_compute" {
  description = "Grant roles/compute.viewer at org scope."
  type        = bool
  default     = true
}

variable "enable_containers" {
  description = "Grant roles/container.viewer at org scope for direct GKE inventory and live in-cluster config analysis, including CRDs and ComputeClass resources."
  type        = bool
  default     = true
}

variable "enable_cloudsql" {
  description = "Grant roles/cloudsql.viewer at org scope."
  type        = bool
  default     = true
}

variable "enable_cloudrun" {
  description = "Grant roles/run.viewer at org scope."
  type        = bool
  default     = true
}

variable "enable_tags" {
  description = "Grant roles/resourcemanager.tagViewer at org scope for tag keys and effective tags."
  type        = bool
  default     = true
}

variable "enable_pubsub" {
  description = "Grant roles/pubsub.viewer at org scope for direct Pub/Sub inventory."
  type        = bool
  default     = true
}

variable "enable_storage" {
  description = "Grant roles/storage.bucketViewer at org scope for direct Cloud Storage bucket inventory."
  type        = bool
  default     = true
}

variable "enable_vertex_ai" {
  description = "Grant roles/aiplatform.viewer at org scope for direct Vertex AI inventory."
  type        = bool
  default     = true
}

variable "enable_bigquery_metadata" {
  description = "Grant roles/bigquery.metadataViewer at org scope for INFORMATION_SCHEMA storage and metadata analysis."
  type        = bool
  default     = true
}

variable "enable_bigquery_job_metadata" {
  description = "Grant roles/bigquery.resourceViewer at org scope for broader INFORMATION_SCHEMA job-history analysis."
  type        = bool
  default     = true
}

variable "billing_export_datasets" {
  description = "Required Cloud Billing export BigQuery datasets that EntropyFabric should be able to read. Each dataset must include its BigQuery location."
  type = list(object({
    project_id = string
    dataset_id = string
    location   = string
  }))

  validation {
    condition     = length(var.billing_export_datasets) > 0
    error_message = "billing_export_datasets must contain at least one Cloud Billing export dataset."
  }

  validation {
    condition = alltrue([
      for dataset in var.billing_export_datasets :
      can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", dataset.project_id))
    ])
    error_message = "Each billing_export_datasets.project_id must be a valid Google Cloud project ID."
  }

  validation {
    condition = alltrue([
      for dataset in var.billing_export_datasets :
      length(trimspace(dataset.dataset_id)) > 0 &&
      can(regex("^[A-Za-z_]", dataset.dataset_id)) &&
      can(regex("^[A-Za-z0-9_]+$", dataset.dataset_id))
    ])
    error_message = "Each billing_export_datasets.dataset_id must be a valid BigQuery dataset ID."
  }

  validation {
    condition = alltrue([
      for dataset in var.billing_export_datasets :
      can(regex("^[A-Za-z0-9-]+$", dataset.location))
    ])
    error_message = "Each billing_export_datasets.location must be a valid BigQuery location such as europe-west2, US, or EU."
  }
}

variable "bigquery_read_datasets" {
  description = "Optional extra BigQuery datasets that EntropyFabric should be able to read, such as GKE metering datasets or recommender export datasets. Each dataset must include its BigQuery location."
  type = list(object({
    project_id = string
    dataset_id = string
    location   = string
  }))
  default = []

  validation {
    condition = alltrue([
      for dataset in var.bigquery_read_datasets :
      can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", dataset.project_id))
    ])
    error_message = "Each bigquery_read_datasets.project_id must be a valid Google Cloud project ID."
  }

  validation {
    condition = alltrue([
      for dataset in var.bigquery_read_datasets :
      length(trimspace(dataset.dataset_id)) > 0 &&
      can(regex("^[A-Za-z_]", dataset.dataset_id)) &&
      can(regex("^[A-Za-z0-9_]+$", dataset.dataset_id))
    ])
    error_message = "Each bigquery_read_datasets.dataset_id must be a valid BigQuery dataset ID."
  }

  validation {
    condition = alltrue([
      for dataset in var.bigquery_read_datasets :
      can(regex("^[A-Za-z0-9-]+$", dataset.location))
    ])
    error_message = "Each bigquery_read_datasets.location must be a valid BigQuery location such as europe-west2, US, or EU."
  }
}

variable "billing_export_dataset_role" {
  description = "BigQuery dataset role to grant on each BigQuery read dataset."
  type        = string
  default     = "roles/bigquery.dataViewer"
}

variable "grant_billing_export_job_user" {
  description = "Grant roles/bigquery.jobUser on projects that host billing_export_datasets, bigquery_read_datasets, and any additional_bigquery_job_user_project_ids."
  type        = bool
  default     = true
}

variable "additional_bigquery_job_user_project_ids" {
  description = "Optional extra runner projects where EntropyFabric should receive roles/bigquery.jobUser for billing, metering, or metadata queries."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for project_id in var.additional_bigquery_job_user_project_ids :
      can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", project_id))
    ])
    error_message = "Each additional_bigquery_job_user_project_ids value must be a valid Google Cloud project ID."
  }
}

variable "bigquery_job_user_role" {
  description = "Project role to grant for BigQuery query execution."
  type        = string
  default     = "roles/bigquery.jobUser"
}
