# EntropyFabric Onboarding

This repository contains the public customer onboarding assets for **EntropyFabric**:

- [`customer_onboard_service_account.sh`](./customer_onboard_service_account.sh) for an audited `gcloud`-driven path
- [`terraform/`](./terraform/) for a reviewable Terraform path

Both paths default to the same onboarding grant package:

- `roles/billing.viewer`
- `roles/browser`
- `roles/cloudasset.viewer`
- `roles/serviceusage.serviceUsageConsumer`
- `roles/recommender.viewer`
- `roles/monitoring.viewer`
- `roles/compute.viewer`
- `roles/container.viewer`
- `roles/cloudsql.viewer`
- `roles/run.viewer`
- `roles/resourcemanager.tagViewer`
- `roles/pubsub.viewer`
- `roles/storage.bucketViewer`
- `roles/aiplatform.viewer`
- `roles/bigquery.metadataViewer`
- `roles/bigquery.resourceViewer`
- `roles/bigquery.dataViewer` on one or more billing export datasets
- `roles/bigquery.jobUser` on one or more runner projects

This is intentionally broader than a minimal hierarchy-only package. The tradeoff is explicit: EntropyFabric gets better resource coverage and metadata quality on day one, but customers should review BigQuery job metadata access carefully because it can expose query text and employee email addresses.

`roles/browser` remains the default discovery role. `roles/resourcemanager.organizationViewer` is not enough for this baseline because it only grants organization lookup, not project and resource hierarchy discovery.

For GKE specifically, `roles/container.viewer` does not expose secrets and is used for live configuration analysis of workloads, namespaces, CRDs, and many custom resources such as `ComputeClass`.

## Shell Path

Use [`customer_onboard_service_account.sh`](./customer_onboard_service_account.sh) when you want:

- `--dry-run` to preview missing grants
- `--validate` to inspect readiness without changing IAM
- organization, folder, or project scope selection
- per-role toggles such as `--monitoring=false` or `--bigquery-jobs=false`

To onboard with the full default package:

```bash
./customer_onboard_service_account.sh \
  --service-account-email SERVICE_ACCOUNT_EMAIL \
  --billing-account BILLING_ACCOUNT_ID \
  --organization ORG_ID \
  --billing-export-dataset BILLING_PROJECT_ID:BILLING_DATASET_ID:BILLING_LOCATION \
  --bigquery-job-user-project RUNNER_PROJECT_ID
```

Replace `SERVICE_ACCOUNT_EMAIL`, `BILLING_ACCOUNT_ID`, `ORG_ID`, `BILLING_PROJECT_ID`, `BILLING_DATASET_ID`, `BILLING_LOCATION`, and `RUNNER_PROJECT_ID` with your values. Add `--dry-run` first if you want to preview the missing bindings before applying them.

Important shell rules:

- org-scoped onboarding is the only mode that can keep the full default package enabled
- folder-scoped and project-scoped onboarding must disable the org-only viewer families
- at least one `--billing-export-dataset PROJECT_ID:DATASET_ID:LOCATION` is mandatory
- the billing export dataset location must match the dataset's actual BigQuery location
- BigQuery metadata roles are enabled by default, so at least one `--bigquery-job-user-project` is required unless `--bigquery-metadata=false` and `--bigquery-jobs=false`
- the shell helper grants dataset-level `roles/bigquery.dataViewer` for billing export datasets and project-level `roles/bigquery.jobUser` for query execution

If your organization uses `constraints/iam.allowedPolicyMemberDomains`, run:

```bash
./customer_onboard_service_account.sh --show-allowed-policy-member-domain-values
```

Then allow the returned organization principal-set value and, where applicable, the returned directory customer ID value.

## Terraform Path

Use [`terraform/`](./terraform/) when you want:

- the same default org-scoped grant package as the shell path
- a plan-and-apply workflow instead of imperative `gcloud`
- required billing export dataset access through `billing_export_datasets`
- additional dataset-level BigQuery access through `bigquery_read_datasets`
- runner-project grants through `additional_bigquery_job_user_project_ids`

Important Terraform rules:

- `organization_role` mirrors the shell default of `roles/browser`
- every org-level viewer boolean defaults to `true`
- BigQuery metadata booleans default to `true`, so at least one runner project is required unless those booleans are turned off
- `billing_export_datasets` is mandatory and every dataset entry must include `project_id`, `dataset_id`, and `location`
- `bigquery_read_datasets` is optional, but every dataset entry must include `project_id`, `dataset_id`, and `location`

## Billing Export Datasets

Billing export datasets are not optional. EntropyFabric needs direct read access to billing export tables to attach observed cost to findings.

- Use `billing_export_datasets` in Terraform for Cloud Billing export datasets
- Use `--billing-export-dataset PROJECT_ID:DATASET_ID:LOCATION` in the shell helper
- Use `bigquery_read_datasets` for other BigQuery-backed sources such as GKE metering or recommender exports

BigQuery is location-sensitive. The dataset `location` must be captured explicitly so EntropyFabric can run billing and metadata queries in the correct region or multi-region.

See [`terraform/README.md`](./terraform/README.md) for the Terraform-specific workflow and example configuration.
