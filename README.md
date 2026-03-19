# Customer Onboarding to **Entropy Fabric**

This repository contains onboarding resources for **Entropy Fabric** customers:

- Access requirements
- Onboarding instructions
- IAM configuration automation

## **Entropy Fabric**

**Entropy Fabric** is our Google Cloud cost optimization platform, delivering actionable savings insights through AI-powered analysis validated by our team of cloud experts.

## Access requirements

**Entropy Fabric** requires access to certain Google Cloud usage data. You control this access by granting IAM roles to a *dedicated* service account *unique* to your organization.

These IAM roles grant permissions to *read* information about your resources but not to modify or delete them.

The following IAM roles are granted *by default*, organized by resource scope. These roles deliver comprehensive resource coverage and high-quality insights while following the principle of least privilege.

<!--
> [!IMPORTANT]
> BigQuery job metadata access is enabled by default but this can be overridden. This metadata may include SQL query text and employee email addresses.
-->

### **Organization** roles

The following IAM roles are granted *by default* at the organisation level.

- `roles/aiplatform.viewer`<sup>†</sup>
- **`roles/bigquery.metadataViewer`**<sup>† ‡</sup>
- `roles/bigquery.resourceViewer`<sup>† ‡</sup>
- **`roles/browser`**
- `roles/cloudasset.viewer`<sup>†</sup>
- `roles/cloudsql.viewer`<sup>†</sup>
- `roles/compute.viewer`<sup>†</sup>
- `roles/container.viewer`<sup>†</sup>
- `roles/monitoring.viewer`<sup>†</sup>
- `roles/pubsub.viewer`<sup>†</sup>
- `roles/recommender.viewer`<sup>†</sup>
- `roles/resourcemanager.tagViewer`<sup>†</sup>
- `roles/run.viewer`<sup>†</sup>
- **`roles/serviceusage.serviceUsageConsumer`**<sup>†</sup>
- `roles/storage.bucketViewer`<sup>†</sup>

<sup>†</sup> **Optional**, can be disabled during onboarding.

<sup>‡</sup> **BigQuery metadata** accessible through these roles may contain *query text* and *employee email addresses*; however, these roles *do not provide access* to dataset content or query results.

---

The **Browser** role (`roles/browser`) provides read access to discover the resource hierarchy (projects, folders, organization, and IAM policies) but does not grant permissions to view resources within projects.

The **Kubernetes Engine Viewer** role (`roles/container.viewer`) provides read access to the configuration of Kubernetes workloads, namespaces, CRDs, and custom resources such as `ComputeClass`. This role does not expose Kubernetes Secrets.

### **Billing account** roles

The following IAM roles are granted on each billing account you specify:

- `roles/billing.viewer`

<!-- 
### **Billing export dataset** roles
-->

### **BigQuery dataset** roles

The following IAM roles are granted on each BigQuery dataset you specify:

- `roles/bigquery.dataViewer`

Only grant this role on datasets containing Cloud Billing data exports or other relevant billing or monitoring data.

### **Project** roles

The following IAM roles are granted on each **runner project** you specify:

- `roles/bigquery.jobUser`<sup>†</sup>

<sup>†</sup> **Optional**, can be disabled during onboarding.

You only need a runner project if you granted either of the two **BigQuery metadata** roles explained in the [**Organization** roles](#organization-roles) section.

## How to grant access

Grant the required IAM roles using any method, or use our automated tools for convenience. All our tools apply the same defaults and allow fine-grained customization.

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

## License

Copyright © 2026 Devil Mice Labs. All rights reserved.
