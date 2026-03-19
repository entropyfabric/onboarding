check "bigquery_runner_projects_for_metadata" {
  assert {
    condition = !(
      var.enable_bigquery_metadata || var.enable_bigquery_job_metadata
    ) || length(local.bigquery_job_user_project_ids) > 0
    error_message = "The default onboarding package includes BigQuery metadata grants, so add at least one BigQuery runner project via billing_export_datasets, bigquery_read_datasets, or additional_bigquery_job_user_project_ids, or disable the BigQuery metadata booleans."
  }
}

resource "google_billing_account_iam_member" "billing_role" {
  billing_account_id = var.billing_account_id
  role               = var.billing_role
  member             = local.member
}

resource "google_organization_iam_member" "organization_roles" {
  for_each = local.organization_role_map

  org_id = var.organization_id
  role   = each.value
  member = local.member
}

resource "google_bigquery_dataset_iam_member" "billing_export_dataset_viewers" {
  for_each = local.billing_export_dataset_map

  project    = each.value.project_id
  dataset_id = each.value.dataset_id
  role       = var.billing_export_dataset_role
  member     = local.member
}

resource "google_project_iam_member" "bigquery_job_users" {
  for_each = local.bigquery_job_user_project_map

  project = each.value
  role    = var.bigquery_job_user_role
  member  = local.member
}
