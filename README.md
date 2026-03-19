# Customer Onboarding to **Entropy Fabric**

This public repository contains onboarding instructions and tools for **Entropy Fabric** customers.

## About

**Entropy Fabric** provides bespoke and actionable cost savings insights for your Google Cloud resources. 

This is achieved by leveraging advanced AI models as well as human expert analysis and judgement.

## Getting started

**Entropy Fabric** requires *read-only* access to certain Google Cloud usage data. This access is granted through predefined IAM roles assigned to a dedicated service account unique to your organization.

The next section describes these access requirements in full for transparency.

Because managing this access manually can be cumbersome, we provide automation to simplify the setup.

The sections that follow describe the two automation options available for granting this access.

### Access requirements

The permissions granted by the following roles are intentionally limited to what **Entropy Fabric** needs to deliver strong resource coverage and high-quality insights from day one. The main trade-off is access to BigQuery *job metadata*, which customers should review carefully, as it may include query text and employee email addresses. 

*By default*, the followined predefined IAM roles are granted:

<!--
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

--->

#### **Organization** roles

- `roles/aiplatform.viewer`
- `roles/bigquery.metadataViewer`
- `roles/bigquery.resourceViewer`
- `roles/browser`
- `roles/cloudasset.viewer`
- `roles/cloudsql.viewer`
- `roles/compute.viewer`
- `roles/container.viewer`
- `roles/monitoring.viewer`
- `roles/pubsub.viewer`
- `roles/recommender.viewer`
- `roles/resourcemanager.tagViewer`
- `roles/run.viewer`
- `roles/serviceusage.serviceUsageConsumer`
- `roles/storage.bucketViewer`

#### **Billing account** roles

- `roles/billing.viewer`

#### **Billing export dataset** roles

- `roles/bigquery.dataViewer`

#### **Runner project** roles

- `roles/bigquery.jobUser`

#### **Rationale**

Some further notes on individual roles:

* The basic **Brower** role (`roles/browser`) provides read access to discover the project hierarchy, including the folder, organization, and IAM allow policy resources. This role doesn't include permission to view resources in the project.

<!-- 
A more limited predefined **Organization Viewer** role (`roles/resourcemanager.organizationViewer`) would not be sufficient for discovery because it only grants organization lookup, not project and resource hierarchy discovery.
-->

* The **Kubernetes Engine Viewer** role (`roles/container.viewer`) can be used to extend the analysis to cover the configuration of Kubernetes workloads, namespaces, CRDs, and many custom resources such as `ComputeClass`. This role does not expose Kubernetes secrets.

### How to grant access

For customer convenience, we provide two different automated approaches to managing our access to your Cloud usage data. 

Both options grants the *same* IAM roles by default.

### Option 1: use our shell script

This option provides a `bash` shell script which makes use of Google Cloud CLI (`gcloud`): 

[`customer_onboard_service_account.sh`](./scripts/customer_onboard_service_account.sh)

Pick this option if you want to:

- Assess readiness without changing IAM policies by using the `--validate` flag.
- Preview missing grants with the `--dry-run` flag.
- Exclude specific categories of Google Cloud usage data from sharing with flags such as `--monitoring=false` and `--bigquery-jobs=false`.
- Limit access to the organization, folder, or project level.

Run the following command to onboard with the default configuration:

```bash
./scripts/customer_onboard_service_account.sh \
  --service-account-email SERVICE_ACCOUNT_EMAIL \
  --billing-account BILLING_ACCOUNT_ID \
  --organization ORG_ID \
  --billing-export-dataset BILLING_PROJECT_ID:BILLING_DATASET_ID:BILLING_LOCATION \
  --bigquery-job-user-project RUNNER_PROJECT_ID
```

Where the following placeholders must be replaced with your own:

| Value | Description |
|---|---|
| `SERVICE_ACCOUNT_EMAIL` | **Entropy Fabric** service account email to grant access to |
| `BILLING_ACCOUNT_ID` | [billing account] ID in `000000-000000-000000` format |
| `ORG_ID` | [organization] ID |
| `BILLING_PROJECT_ID` | [project] ID where *Cloud Billing export* to BigQuery was set up  |
| `BILLING_DATASET_ID` | *Cloud Billing export* BigQuery dataset name |
| `BILLING_LOCATION` | *Cloud Billing export* BigQuery dataset location |
| `RUNNER_PROJECT_ID` | project ID to run BigQuery metadata export jobs |

<!-- 
- `SERVICE_ACCOUNT_EMAIL`
- `BILLING_ACCOUNT_ID`
- `ORG_ID`
- `BILLING_PROJECT_ID`
- `BILLING_DATASET_ID`
- `BILLING_LOCATION`
- `RUNNER_PROJECT_ID`
-->

[billing account]: https://docs.cloud.google.com/billing/docs/how-to/find-billing-account-id
[organization]: https://docs.cloud.google.com/resource-manager/docs/cloud-platform-resource-hierarchy#organizations
[project]: https://docs.cloud.google.com/resource-manager/docs/cloud-platform-resource-hierarchy#projects

#### Notes

- Only organization-scoped onboarding supports the full default configuration.
- Folder-scoped and project-scoped onboarding require disabling organization-only viewer roles.

---

At least one `--billing-export-dataset` argument is required. Multiple datasets are supported, each requiring its own `--billing-export-dataset` argument.

The dataset location must match the dataset's actual BigQuery location.

---

The IAM roles to grant access to BigQuery metadata are enabled by default, so at least one `--bigquery-job-user-project` argument is required.

To avoid having to provide the argument, turn off BigQuery metadata access with *both* `--bigquery-metadata=false` *and* `--bigquery-jobs=false`.

<!--  TODO document this in roles list:

- the shell helper grants dataset-level `roles/bigquery.dataViewer` for billing export datasets and project-level `roles/bigquery.jobUser` for query execution
-->

#### Domain restricted sharing

> [!WARNING]
> If [domain-restricted sharing] is active on your organisation, you might need to adjust it first.


If the policy is enforced with the `constraints/iam.allowedPolicyMemberDomains` legacy managed constraint, you can run the following command to print the required organization principal set:

```bash
./scripts/customer_onboard_service_account.sh --show-allowed-policy-member-domain-values
```

Then allow the returned organization principal-set value and, where applicable, the returned directory customer ID value.

If the policy is enforced by some other method, check the [docs] on how to adjust it, or contact us for assistance.

[domain-restricted sharing]: https://docs.cloud.google.com/organization-policy/domain-restricted-sharing
[docs]: https://docs.cloud.google.com/organization-policy/domain-restricted-sharing

### Option 2: use our Terraform module

This option provides a Terraform module:

[`terraform/`](./terraform/)

Pick this option if you want to:

- the same default org-scoped grant package as the shell path
- a plan-and-apply workflow instead of imperative `gcloud`
- required billing export dataset access through `billing_export_datasets`
- additional dataset-level BigQuery access through `bigquery_read_datasets`
- runner-project grants through `additional_bigquery_job_user_project_ids`

Important notes:

- This Terraform module grants the same IAM roles by default as the shell script from option one.

<!--
- `organization_role` mirrors the shell default of `roles/browser`
- every org-level viewer boolean defaults to `true`
-->
- BigQuery metadata booleans default to `true`, so at least one runner project is required unless those booleans are turned off
- `billing_export_datasets` is mandatory and every dataset entry must include `project_id`, `dataset_id`, and `location`
- `bigquery_read_datasets` is optional, but every dataset entry must include `project_id`, `dataset_id`, and `location`

> [!WARNING]
> This Terraform module is not intended for use from another Terraform module.
>
> If you need to call it from another module, first delete the `providers.tf` file.
>
> For more information, see [Providers Within Modules](https://developer.hashicorp.com/terraform/language/modules/develop/providers) or contact us.

## Billing Export Datasets

Billing export datasets are not optional. EntropyFabric needs direct read access to billing export tables to attach observed cost to findings.

- Use `billing_export_datasets` in Terraform for Cloud Billing export datasets
- Use `--billing-export-dataset PROJECT_ID:DATASET_ID:LOCATION` in the shell helper
- Use `bigquery_read_datasets` for other BigQuery-backed sources such as GKE metering or recommender exports

BigQuery is location-sensitive. The dataset `location` must be captured explicitly so **Entropy Fabric** can run billing and metadata queries in the correct region or multi-region.

See [`terraform/README.md`](./terraform/README.md) for the Terraform-specific workflow and example configuration.

## Offboarding

You can stop sharing your Google Cloud usage data with us at any time. The process depends on how you onboarded.

- If you used Terraform, run `terraform destroy` to revoke access.
- If you used the shell script, contact us for assistance.

## Troubleshooting

We are very happy to help you with any potential issues. Just let us know!
