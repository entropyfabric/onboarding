locals {
  member = "serviceAccount:${var.service_account_email}"

  organization_roles = compact([
    var.organization_role,
    var.enable_cloud_assets ? "roles/cloudasset.viewer" : null,
    var.enable_cloud_assets ? "roles/serviceusage.serviceUsageConsumer" : null,
    var.enable_recommender ? "roles/recommender.viewer" : null,
    var.enable_monitoring ? "roles/monitoring.viewer" : null,
    var.enable_compute ? "roles/compute.viewer" : null,
    var.enable_containers ? "roles/container.viewer" : null,
    var.enable_cloudsql ? "roles/cloudsql.viewer" : null,
    var.enable_cloudrun ? "roles/run.viewer" : null,
    var.enable_tags ? "roles/resourcemanager.tagViewer" : null,
    var.enable_pubsub ? "roles/pubsub.viewer" : null,
    var.enable_storage ? "roles/storage.bucketViewer" : null,
    var.enable_vertex_ai ? "roles/aiplatform.viewer" : null,
    var.enable_bigquery_metadata ? "roles/bigquery.metadataViewer" : null,
    var.enable_bigquery_job_metadata ? "roles/bigquery.resourceViewer" : null,
  ])

  organization_role_map = {
    for role in local.organization_roles : role => role
  }

  bigquery_read_datasets = concat(var.billing_export_datasets, var.bigquery_read_datasets)

  billing_export_dataset_map = {
    for dataset in local.bigquery_read_datasets :
    "${dataset.project_id}/${dataset.dataset_id}" => dataset
  }

  bigquery_job_user_project_ids = var.grant_billing_export_job_user ? toset(concat(
    [for dataset in local.bigquery_read_datasets : dataset.project_id],
    tolist(var.additional_bigquery_job_user_project_ids),
  )) : toset([])

  bigquery_job_user_project_map = {
    for project_id in local.bigquery_job_user_project_ids : project_id => project_id
  }
}
