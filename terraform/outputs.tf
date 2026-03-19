output "member" {
  description = "IAM member string granted by this onboarding stack."
  value       = local.member
}

output "billing_account_role" {
  description = "Billing account role granted to the EntropyFabric service account."
  value = {
    billing_account_id = var.billing_account_id
    role               = var.billing_role
  }
}

output "organization_roles" {
  description = "Organization-scoped roles granted to the EntropyFabric service account."
  value = {
    organization_id = var.organization_id
    roles           = sort(keys(local.organization_role_map))
  }
}

output "billing_export_datasets" {
  description = "BigQuery datasets where EntropyFabric has dataset read access."
  value = [
    for key in sort(keys(local.billing_export_dataset_map)) : {
      project_id = local.billing_export_dataset_map[key].project_id
      dataset_id = local.billing_export_dataset_map[key].dataset_id
      location   = local.billing_export_dataset_map[key].location
      role       = var.billing_export_dataset_role
    }
  ]
}

output "bigquery_read_datasets" {
  description = "All BigQuery datasets where EntropyFabric has dataset read access, including billing, metering, and recommender exports."
  value = [
    for key in sort(keys(local.billing_export_dataset_map)) : {
      project_id = local.billing_export_dataset_map[key].project_id
      dataset_id = local.billing_export_dataset_map[key].dataset_id
      location   = local.billing_export_dataset_map[key].location
      role       = var.billing_export_dataset_role
    }
  ]
}

output "bigquery_job_user_projects" {
  description = "Projects where EntropyFabric has BigQuery job execution access."
  value = [
    for project_id in sort(keys(local.bigquery_job_user_project_map)) : {
      project_id = project_id
      role       = var.bigquery_job_user_role
    }
  ]
}
