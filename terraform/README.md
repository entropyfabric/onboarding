# Terraform Onboarding

This directory provides a Terraform mirror of [`../customer_onboard_service_account.sh`](../customer_onboard_service_account.sh) for the org-scoped onboarding path.

The default role package matches the shell helper:

- `roles/billing.viewer` on the billing account
- `roles/browser` on the organization
- `roles/cloudasset.viewer` on the organization
- `roles/serviceusage.serviceUsageConsumer` on the organization
- `roles/recommender.viewer` on the organization
- `roles/monitoring.viewer` on the organization
- `roles/compute.viewer` on the organization
- `roles/container.viewer` on the organization
- `roles/cloudsql.viewer` on the organization
- `roles/run.viewer` on the organization
- `roles/resourcemanager.tagViewer` on the organization
- `roles/pubsub.viewer` on the organization
- `roles/storage.bucketViewer` on the organization
- `roles/aiplatform.viewer` on the organization
- `roles/bigquery.metadataViewer` on the organization
- `roles/bigquery.resourceViewer` on the organization
- `roles/bigquery.dataViewer` on one or more billing export datasets
- `roles/bigquery.jobUser` on one or more runner projects

Terraform grants the required billing export dataset access and can also grant additional dataset-level BigQuery access for GKE metering and recommender export tables.

`roles/container.viewer` is the role that unlocks live in-cluster GKE config analysis in the baseline package. It is enough for EntropyFabric to inspect workloads, namespaces, CRDs, and many custom resources such as `ComputeClass`, but it does not grant Secret reads or access to the original source manifests in Helm, Kustomize, or GitOps repos.

For the policy rationale and shell-versus-Terraform option summary, start with [`../README.md`](../README.md).

## Minimal Example

Create a `terraform.tfvars` file:

```hcl
service_account_email = "onboarding-reader@entropyfabric-prod.iam.gserviceaccount.com"
billing_account_id    = "012345-6789AB-CDEF01"
organization_id       = "123456789012"

billing_export_datasets = [
  {
    project_id = "sample-billing-prod"
    dataset_id = "billing_export"
    location   = "europe-west2"
  }
]

additional_bigquery_job_user_project_ids = [
  "entropyfabric-runner",
]
```

Then run:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Billing Export Datasets

`billing_export_datasets` is mandatory. EntropyFabric needs direct read access to Cloud Billing export datasets so it can attach observed cost to findings.

```hcl
billing_export_datasets = [
  {
    project_id = "sample-billing-prod"
    dataset_id = "billing_export"
    location   = "europe-west2"
  }
]
```

Every billing export dataset entry must include:

- `project_id`
- `dataset_id`
- `location`

BigQuery is location-sensitive. Query jobs must run in the same location as the datasets they read, so the onboarding input needs the dataset location explicitly.

## Additional Dataset Access

Add `bigquery_read_datasets` when EntropyFabric should read extra BigQuery datasets directly:

```hcl

bigquery_read_datasets = [
  {
    project_id = "sample-gke-prod"
    dataset_id = "gke_usage_metering"
    location   = "europe-west2"
  },
  {
    project_id = "sample-finops-prod"
    dataset_id = "org_recommender_export"
    location   = "US"
  }
]
```

## Domain-Restricted Sharing

If your org policy uses `constraints/iam.allowedPolicyMemberDomains`, allow the organization principal-set value and, where applicable, the directory customer ID value returned by:

```bash
../customer_onboard_service_account.sh --show-allowed-policy-member-domain-values
```

## Variable Notes

- `service_account_email`, `billing_account_id`, and `organization_id` are the required core inputs.
- `organization_role` mirrors the shell default of `roles/browser`.
- Every `enable_*` org-level viewer flag defaults to `true`.
- `enable_containers` keeps `roles/container.viewer`, which is required for live GKE object inspection such as workloads, CRDs, and `ComputeClass` resources.
- `enable_bigquery_metadata` and `enable_bigquery_job_metadata` default to `true`, so at least one runner project is required unless those flags are turned off.
- `billing_export_datasets` is required and every dataset object must include `project_id`, `dataset_id`, and `location`.
- `bigquery_read_datasets` is optional, but every dataset object must include `project_id`, `dataset_id`, and `location`.
- `billing_export_datasets` and `bigquery_read_datasets` add dataset-level `roles/bigquery.dataViewer`.
- `grant_billing_export_job_user` defaults to `true`, so dataset host projects and any explicit runner projects receive `roles/bigquery.jobUser`.
- `additional_bigquery_job_user_project_ids` is the direct Terraform mirror of the shell script's `--bigquery-job-user-project`.

## Difference From The Shell Script

Use the shell helper when the customer wants:

- `--dry-run` or `--validate`
- folder-scoped onboarding
- project-scoped onboarding
- direct `gcloud` inspection of existing IAM policy before apply

Use Terraform when the customer wants:

- a reviewable plan
- the same default org-scoped grants as code
- required billing export dataset IAM as code
- additional dataset-level BigQuery IAM beyond billing exports in the same change set
