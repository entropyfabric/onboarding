#!/usr/bin/env bash

set -euo pipefail

DEFAULT_BILLING_ROLE="roles/billing.viewer"
DEFAULT_RESOURCE_ROLE="roles/browser"
ROLE_CLOUD_ASSET_VIEWER="roles/cloudasset.viewer"
ROLE_SERVICE_USAGE_CONSUMER="roles/serviceusage.serviceUsageConsumer"
ROLE_RECOMMENDER_VIEWER="roles/recommender.viewer"
ROLE_MONITORING_VIEWER="roles/monitoring.viewer"
ROLE_COMPUTE_VIEWER="roles/compute.viewer"
ROLE_CONTAINER_VIEWER="roles/container.viewer"
ROLE_CLOUDSQL_VIEWER="roles/cloudsql.viewer"
ROLE_RUN_VIEWER="roles/run.viewer"
ROLE_TAG_VIEWER="roles/resourcemanager.tagViewer"
ROLE_PUBSUB_VIEWER="roles/pubsub.viewer"
ROLE_STORAGE_BUCKET_VIEWER="roles/storage.bucketViewer"
ROLE_VERTEX_AI_VIEWER="roles/aiplatform.viewer"
ROLE_BIGQUERY_METADATA_VIEWER="roles/bigquery.metadataViewer"
ROLE_BIGQUERY_RESOURCE_VIEWER="roles/bigquery.resourceViewer"
ROLE_BIGQUERY_JOB_USER="roles/bigquery.jobUser"
ROLE_BIGQUERY_DATA_VIEWER="roles/bigquery.dataViewer"

SERVICE_ACCOUNT_EMAIL=""
BILLING_ACCOUNT_ID=""
BILLING_ROLE="$DEFAULT_BILLING_ROLE"
RESOURCE_ROLE="$DEFAULT_RESOURCE_ROLE"
RESOURCE_SCOPE=""
RESOURCE_IDS=()
GCLOUD_BIN="${GCLOUD_BIN:-gcloud}"
BQ_BIN="${BQ_BIN:-bq}"
DRY_RUN=0
VALIDATE_ONLY=0
SHOW_ALLOWED_POLICY_MEMBER_DOMAIN_VALUES=0
CLOUD_ASSETS=1
RECOMMENDER=1
MONITORING=1
COMPUTE=1
CONTAINERS=1
CLOUDSQL=1
CLOUDRUN=1
TAGS=1
PUBSUB=1
STORAGE=1
VERTEX_AI=1
BIGQUERY_METADATA=1
BIGQUERY_JOB_METADATA=1
BQ_JOB_USER_PROJECT_IDS=()
BILLING_EXPORT_DATASETS=()
BINDING_RESULTS=()
BINDING_STATE_RESULT=""
POLICY_ROWS_CACHE_DIR=""

usage() {
  cat <<'EOF'
Grant the baseline EntropyFabric onboarding permissions to a service account.

The script grants:
- a Cloud Billing role on the billing account
- a read-only resource-discovery role on one or more organizations, folders, or projects
- dataset-level BigQuery read access on one or more billing export datasets

Defaults:
- billing role: roles/billing.viewer
- resource role: roles/browser
- all org-level product roles: enabled by default
- BigQuery metadata roles: enabled by default and paired with runner-project job execution access
- billing export datasets: required and location-aware

Why these grants exist:
- roles/billing.viewer: lets EntropyFabric read billing-account metadata and linked-project billing state
- roles/browser: lets EntropyFabric enumerate projects and folders at org, folder, or project scope
- roles/resourcemanager.organizationViewer is not the default because it only grants resourcemanager.organizations.get
- roles/cloudasset.viewer: lets EntropyFabric perform broad org-wide asset discovery across products
- roles/serviceusage.serviceUsageConsumer: lets org-level API calls use a billing or quota project
- roles/recommender.viewer: lets EntropyFabric read savings and optimization recommendations
- roles/monitoring.viewer: lets EntropyFabric read Cloud Monitoring metrics for utilization analysis
- roles/compute.viewer: lets EntropyFabric inventory Compute Engine resources directly
- roles/container.viewer: lets EntropyFabric inspect live GKE cluster configuration, workloads, CRDs, and custom resources such as ComputeClass directly; it does not read Secret contents or source-repo YAML
- roles/cloudsql.viewer: lets EntropyFabric inventory Cloud SQL resources directly
- roles/run.viewer: lets EntropyFabric inventory Cloud Run services and jobs directly
- roles/resourcemanager.tagViewer: lets EntropyFabric read tag keys and effective tags for ownership and environment enrichment
- roles/pubsub.viewer: lets EntropyFabric inventory Pub/Sub topics, subscriptions, snapshots, and schemas directly
- roles/storage.bucketViewer (Beta): lets EntropyFabric inventory Cloud Storage buckets and bucket metadata without object reads
- roles/aiplatform.viewer: lets EntropyFabric inventory Vertex AI resources directly
- roles/bigquery.metadataViewer: lets EntropyFabric query BigQuery metadata views for storage, partitioning, and dataset-shape analysis
- roles/bigquery.resourceViewer: lets EntropyFabric query broader BigQuery job metadata views that can expose query text and user emails
- roles/bigquery.jobUser: lets EntropyFabric run BigQuery metadata jobs in the named runner projects
- roles/bigquery.dataViewer: lets EntropyFabric read the named Cloud Billing export datasets directly

Usage:
  ./customer_onboard_service_account.sh \
    --service-account-email onboarding-reader@entropyfabric-prod.iam.gserviceaccount.com \
    --billing-account 012345-6789AB-CDEF01 \
    --organization 123456789012 \
    --billing-export-dataset sample-billing-prod:billing_export:europe-west2 \
    --bigquery-job-user-project entropyfabric-runner

Examples:
  ./customer_onboard_service_account.sh \
    --service-account-email onboarding-reader@entropyfabric-prod.iam.gserviceaccount.com \
    --billing-account 012345-6789AB-CDEF01 \
    --organization 123456789012 \
    --billing-export-dataset sample-billing-prod:billing_export:europe-west2 \
    --bigquery-job-user-project entropyfabric-runner \
    --dry-run

  ./customer_onboard_service_account.sh \
    --service-account-email onboarding-reader@entropyfabric-prod.iam.gserviceaccount.com \
    --billing-account 012345-6789AB-CDEF01 \
    --project sample-prod-1 \
    --project sample-prod-2 \
    --billing-export-dataset sample-billing-prod:billing_export:europe-west2 \
    --cloud-assets=false \
    --recommender=false \
    --monitoring=false \
    --compute=false \
    --containers=false \
    --cloudsql=false \
    --cloudrun=false \
    --tags=false \
    --pubsub=false \
    --storage=false \
    --vertex-ai=false \
    --bigquery-metadata=false \
    --bigquery-jobs=false \
    --dry-run

  ./customer_onboard_service_account.sh \
    --show-allowed-policy-member-domain-values

Flags:
  --service-account-email EMAIL   EntropyFabric service account email to grant access to.
  --billing-account ID            Billing account ID in 000000-000000-000000 format.
  --organization ID               Organization ID for resource discovery. May be repeated.
  --folder ID                     Folder ID for resource discovery. May be repeated.
  --project ID                    Project ID for resource discovery. May be repeated.
  --billing-export-dataset SPEC   Billing export dataset in
                                  PROJECT_ID:DATASET_ID:LOCATION format.
                                  May be repeated. Required.
  --billing-role ROLE             Override the billing role. Default: roles/billing.viewer
  --resource-role ROLE            Override the resource role. Default: roles/browser
  --cloud-assets[=BOOL]           Org-level roles/cloudasset.viewer and
                                  roles/serviceusage.serviceUsageConsumer for org-wide
                                  asset discovery and quota-project usage. Default: true
  --recommender[=BOOL]            Org-level roles/recommender.viewer for savings and
                                  optimization recommendations. Default: true
  --monitoring[=BOOL]             Org-level roles/monitoring.viewer for metric-based
                                  utilization analysis. Default: true
  --compute[=BOOL]                Org-level roles/compute.viewer for direct Compute
                                  Engine inventory. Default: true
  --containers[=BOOL]             Org-level roles/container.viewer for direct GKE
                                  inventory and live in-cluster config analysis,
                                  including CRDs and ComputeClass. Default: true
  --cloudsql[=BOOL]               Org-level roles/cloudsql.viewer for direct Cloud SQL
                                  inventory. Default: true
  --cloudrun[=BOOL]               Org-level roles/run.viewer for direct Cloud Run
                                  inventory. Default: true
  --tags[=BOOL]                   Org-level roles/resourcemanager.tagViewer for tag
                                  keys and effective-tag visibility. Default: true
  --pubsub[=BOOL]                 Org-level roles/pubsub.viewer for direct Pub/Sub
                                  inventory. Default: true
  --storage[=BOOL]                Org-level roles/storage.bucketViewer (Beta)
                                  for direct Cloud Storage bucket inventory.
                                  Default: true
  --vertex-ai[=BOOL]              Org-level roles/aiplatform.viewer for direct
                                  Vertex AI inventory. Default: true
  --bigquery-metadata[=BOOL]      Org-level roles/bigquery.metadataViewer for
                                  INFORMATION_SCHEMA storage and metadata analysis.
                                  Requires at least one --bigquery-job-user-project.
                                  Default: true
  --bigquery-jobs[=BOOL]          Org-level roles/bigquery.resourceViewer for
                                  broader INFORMATION_SCHEMA job analysis. Requires
                                  at least one --bigquery-job-user-project.
                                  Default: true
  --bigquery-job-user-project ID  Project where EntropyFabric should receive
                                  roles/bigquery.jobUser to run metadata queries.
                                  May be repeated.
  --gcloud-bin PATH               gcloud binary to use. Default: gcloud
  --bq-bin PATH                   bq binary to use. Default: bq
  --dry-run                       Check existing IAM bindings, print only the missing
                                  grant commands, and apply nothing.
  --validate                      Check existing IAM bindings and print a summary
                                  without printing grant commands or applying changes.
  --show-allowed-policy-member-domain-values
                                  Print the org ID, directory customer ID, and paste-ready
                                  values for constraints/iam.allowedPolicyMemberDomains, then exit.
  --help                          Show this help text.

Notes:
  - Provide exactly one resource scope type: organization, folder, or project.
  - You can pass the chosen scope flag multiple times to grant the same role across several IDs.
  - The caller must already have permission to set IAM policy on the selected resources.
  - The product viewer families are organization-only. Disable them when using --folder or --project.
  - roles/container.viewer covers live in-cluster GKE object inspection, including many
    custom resources such as ComputeClass, but it does not expose Secret contents or the
    original Helm, Kustomize, or GitOps source files that authored those objects.
  - Billing export datasets are mandatory because observed cost needs direct BigQuery read access.
  - The LOCATION value on each --billing-export-dataset must match the dataset's actual BigQuery
    location. EntropyFabric uses that location when grouping query execution.
  - This shell helper only grants dataset access for billing export datasets. Use Terraform for
    additional BigQuery datasets such as GKE metering or recommender export tables.
  - Helpful discovery commands: 'gcloud billing accounts list', 'gcloud organizations list',
    'gcloud resource-manager folders list --organization=ORG_ID', 'gcloud projects list', and
    'bq show --format=prettyjson --dataset PROJECT_ID:DATASET_ID'.
  - Domain-restricted sharing: if your org policy uses constraints/iam.allowedPolicyMemberDomains,
    allow the organization principal-set value and, where applicable, the directory customer ID
    value printed by --show-allowed-policy-member-domain-values.
EOF
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

cleanup() {
  if [[ -n "${POLICY_ROWS_CACHE_DIR:-}" && -d "$POLICY_ROWS_CACHE_DIR" ]]; then
    rm -rf "$POLICY_ROWS_CACHE_DIR"
  fi
}

trap cleanup EXIT

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

print_allowed_policy_member_domain_values() {
  local org_rows

  require_command "$GCLOUD_BIN"
  org_rows="$("$GCLOUD_BIN" organizations list --format='value(DISPLAY_NAME,ID,DIRECTORY_CUSTOMER_ID)')"
  [[ -n "$org_rows" ]] || fail "no accessible organizations were returned by '$GCLOUD_BIN organizations list'"

  echo "Paste-ready values for constraints/iam.allowedPolicyMemberDomains:"
  while IFS=$'\t' read -r display_name org_id customer_id; do
    [[ -n "$org_id" ]] || continue
    echo
    echo "Organization: ${display_name:-unknown}"
    echo "  ORG_ID: ${org_id}"
    if [[ -n "$customer_id" ]]; then
      echo "  DIRECTORY_CUSTOMER_ID: ${customer_id}"
    else
      echo "  DIRECTORY_CUSTOMER_ID: unavailable"
    fi
    echo "  allowed value: is:principalSet://cloudresourcemanager.googleapis.com/organizations/${org_id}"
    if [[ -n "$customer_id" ]]; then
      echo "  allowed value: is:${customer_id}"
    fi
  done <<< "$org_rows"
}

run_cmd() {
  local -a cmd=("$@")
  printf '+'
  printf ' %q' "${cmd[@]}"
  printf '\n'

  if [[ "$DRY_RUN" -eq 0 ]]; then
    "${cmd[@]}"
  fi
}

record_binding_result() {
  local status="$1"
  local scope="$2"
  local resource_id="$3"
  local role="$4"
  local detail="${5:-}"

  BINDING_RESULTS+=("${status}|${scope}|${resource_id}|${role}|${detail}")
}

init_policy_cache_dir() {
  if [[ -n "$POLICY_ROWS_CACHE_DIR" && -d "$POLICY_ROWS_CACHE_DIR" ]]; then
    return 0
  fi

  POLICY_ROWS_CACHE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/entropyfabric-onboarding.XXXXXX")" || \
    fail "unable to create a temporary cache directory"
}

policy_cache_file() {
  local scope="$1"
  local resource_id="$2"
  local sanitized_resource_id

  init_policy_cache_dir
  sanitized_resource_id="$(printf '%s' "$resource_id" | tr -c 'A-Za-z0-9._-' '_')"
  printf '%s/%s-%s.policy' "$POLICY_ROWS_CACHE_DIR" "$scope" "$sanitized_resource_id"
}

policy_rows_for_scope() {
  local scope="$1"
  local resource_id="$2"
  local cache_file
  local output
  local rows
  local -a cmd

  cache_file="$(policy_cache_file "$scope" "$resource_id")"
  if [[ -f "$cache_file" ]]; then
    cat "$cache_file"
    return 0
  fi

  case "$scope" in
    billing-account)
      cmd=("$GCLOUD_BIN" billing accounts get-iam-policy "$resource_id")
      ;;
    organization)
      cmd=("$GCLOUD_BIN" organizations get-iam-policy "$resource_id")
      ;;
    folder)
      cmd=("$GCLOUD_BIN" resource-manager folders get-iam-policy "$resource_id")
      ;;
    project)
      cmd=("$GCLOUD_BIN" projects get-iam-policy "$resource_id")
      ;;
    dataset)
      if ! output="$("$BQ_BIN" show --format=prettyjson --dataset "$resource_id" 2>&1)"; then
        fail "unable to read dataset metadata for ${resource_id}: ${output}"
      fi
      if ! rows="$(printf '%s' "$output" | python3 -c '
import json
import sys

dataset = json.load(sys.stdin)
role_map = {
    "READER": "roles/bigquery.dataViewer",
    "WRITER": "roles/bigquery.dataEditor",
    "OWNER": "roles/bigquery.dataOwner",
}

for entry in dataset.get("access", []) or []:
    mapped_role = role_map.get(entry.get("role", ""))
    if not mapped_role:
        continue

    member = None
    if "iamMember" in entry:
        member = entry["iamMember"]
    elif "userByEmail" in entry:
        email = entry["userByEmail"]
        member = f"serviceAccount:{email}" if email.endswith(".gserviceaccount.com") else f"user:{email}"
    elif "groupByEmail" in entry:
        member = f"group:{entry['groupByEmail']}"
    elif "domain" in entry:
        member = f"domain:{entry['domain']}"

    if member:
        print(f"{mapped_role}\t{member}\t")
')"; then
        fail "unable to parse dataset ACL for ${resource_id}"
      fi
      printf '%s' "$rows" > "$cache_file"
      printf '%s' "$rows"
      return 0
      ;;
    *)
      fail "unsupported IAM policy scope: $scope"
      ;;
  esac

  if ! output="$("${cmd[@]}" \
    --flatten="bindings[].members" \
    --format="value(bindings.role,bindings.members,bindings.condition.expression)" 2>&1)"; then
    fail "unable to read IAM policy for ${scope} ${resource_id}: ${output}"
  fi

  printf '%s' "$output" > "$cache_file"
  printf '%s' "$output"
}

dataset_location_for_ref() {
  local dataset_ref="$1"
  local output
  local location

  if ! output="$("$BQ_BIN" show --format=prettyjson --dataset "$dataset_ref" 2>&1)"; then
    fail "unable to read dataset metadata for ${dataset_ref}: ${output}"
  fi

  if ! location="$(printf '%s' "$output" | python3 -c '
import json
import sys

dataset = json.load(sys.stdin)
location = dataset.get("location", "")
if not location:
    raise SystemExit(1)
print(location)
')"; then
    fail "unable to determine dataset location for ${dataset_ref}"
  fi

  printf '%s' "$location"
}

verify_billing_export_dataset_locations() {
  local dataset_entry
  local project_id
  local dataset_id
  local declared_location
  local actual_location
  local dataset_ref

  for dataset_entry in "${BILLING_EXPORT_DATASETS[@]}"; do
    IFS='|' read -r project_id dataset_id declared_location <<< "$dataset_entry"
    dataset_ref="${project_id}:${dataset_id}"
    actual_location="$(dataset_location_for_ref "$dataset_ref")"
    if [[ "$(canonicalize_bigquery_location "$actual_location")" != "$(canonicalize_bigquery_location "$declared_location")" ]]; then
      fail "declared location ${declared_location} does not match actual BigQuery location ${actual_location} for ${dataset_ref}"
    fi
  done
}

dataset_update_source_file() {
  local dataset_ref="$1"
  local source_file
  local output
  local updated_json

  source_file="$(policy_cache_file "dataset-update" "$dataset_ref").json"

  if ! output="$("$BQ_BIN" show --format=prettyjson --dataset "$dataset_ref" 2>&1)"; then
    fail "unable to read dataset metadata for ${dataset_ref}: ${output}"
  fi

  if ! updated_json="$(printf '%s' "$output" | python3 -c '
import json
import sys

service_account_email = sys.argv[1]
dataset = json.load(sys.stdin)
access = dataset.get("access", []) or []

for entry in access:
    if entry.get("role") != "READER":
        continue
    if entry.get("iamMember") == f"serviceAccount:{service_account_email}" or entry.get("userByEmail") == service_account_email:
        print(json.dumps(dataset))
        raise SystemExit(0)

access.append({
    "role": "READER",
    "userByEmail": service_account_email,
})
dataset["access"] = access
print(json.dumps(dataset))
' "$SERVICE_ACCOUNT_EMAIL")"; then
    fail "unable to prepare dataset ACL update payload for ${dataset_ref}"
  fi

  printf '%s' "$updated_json" > "$source_file"
  printf '%s' "$source_file"
}

apply_billing_export_dataset_binding() {
  local dataset_ref="$1"
  local current_state
  local payload_file

  binding_state "dataset" "$dataset_ref" "$ROLE_BIGQUERY_DATA_VIEWER"
  current_state="$BINDING_STATE_RESULT"
  case "$current_state" in
    present_unconditional)
      echo "= already granted: dataset ${dataset_ref} -> ${ROLE_BIGQUERY_DATA_VIEWER}"
      record_binding_result "EXISTS" "dataset" "$dataset_ref" "$ROLE_BIGQUERY_DATA_VIEWER" "dataset access already present"
      return 0
      ;;
    present_conditional)
      ;;
    missing)
      ;;
    *)
      fail "unexpected binding state for dataset ${dataset_ref} ${ROLE_BIGQUERY_DATA_VIEWER}: ${current_state}"
      ;;
  esac

  if [[ "$VALIDATE_ONLY" -eq 1 ]]; then
    record_binding_result "MISSING" "dataset" "$dataset_ref" "$ROLE_BIGQUERY_DATA_VIEWER"
    return 0
  fi

  payload_file="$(dataset_update_source_file "$dataset_ref")"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    run_cmd "$BQ_BIN" update --source "$payload_file" --dataset "$dataset_ref"
    record_binding_result "WOULD-ADD" "dataset" "$dataset_ref" "$ROLE_BIGQUERY_DATA_VIEWER"
    return 0
  fi

  run_cmd "$BQ_BIN" update --source "$payload_file" --dataset "$dataset_ref"
  record_binding_result "APPLIED" "dataset" "$dataset_ref" "$ROLE_BIGQUERY_DATA_VIEWER"
}

binding_state() {
  local scope="$1"
  local resource_id="$2"
  local role="$3"
  local rows
  local bound_role
  local bound_member
  local bound_condition
  local conditional_match=0

  BINDING_STATE_RESULT="missing"
  rows="$(policy_rows_for_scope "$scope" "$resource_id")"
  while IFS=$'\t' read -r bound_role bound_member bound_condition; do
    [[ -n "${bound_role:-}" ]] || continue
    [[ "$bound_role" == "$role" ]] || continue
    [[ "$bound_member" == "$MEMBER" ]] || continue
    if [[ -z "${bound_condition:-}" ]]; then
      BINDING_STATE_RESULT="present_unconditional"
      return 0
    fi
    conditional_match=1
  done <<< "$rows"

  if [[ "$conditional_match" -eq 1 ]]; then
    BINDING_STATE_RESULT="present_conditional"
  fi
}

apply_binding() {
  local scope="$1"
  local resource_id="$2"
  local role="$3"
  local current_state
  local detail=""
  shift 3

  binding_state "$scope" "$resource_id" "$role"
  current_state="$BINDING_STATE_RESULT"
  case "$current_state" in
    present_unconditional)
      echo "= already granted: ${scope} ${resource_id} -> ${role}"
      record_binding_result "EXISTS" "$scope" "$resource_id" "$role" "unconditional binding already present"
      return 0
      ;;
    present_conditional)
      detail="conditional binding already present; requested unconditional binding is still missing"
      echo "! conditional grant found: ${scope} ${resource_id} -> ${role}"
      ;;
    missing)
      ;;
    *)
      fail "unexpected binding state for ${scope} ${resource_id} ${role}: ${current_state}"
      ;;
  esac

  if [[ "$VALIDATE_ONLY" -eq 1 ]]; then
    record_binding_result "MISSING" "$scope" "$resource_id" "$role" "$detail"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    run_cmd "$@"
    record_binding_result "WOULD-ADD" "$scope" "$resource_id" "$role" "$detail"
    return 0
  fi

  run_cmd "$@"

  record_binding_result "APPLIED" "$scope" "$resource_id" "$role" "$detail"
}

print_binding_summary() {
  local entry
  local status
  local scope
  local resource_id
  local role
  local detail

  echo
  echo "Binding summary:"
  for entry in "${BINDING_RESULTS[@]}"; do
    IFS='|' read -r status scope resource_id role detail <<< "$entry"
    if [[ -n "${detail:-}" ]]; then
      echo "  ${status} ${scope} ${resource_id} -> ${role} (${detail})"
    else
      echo "  ${status} ${scope} ${resource_id} -> ${role}"
    fi
  done
}

validate_service_account_email() {
  [[ "$1" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.iam\.gserviceaccount\.com$ ]] || \
    fail "service account email must end with .iam.gserviceaccount.com"
}

validate_billing_account_id() {
  [[ "$1" =~ ^[A-Z0-9]{6}-[A-Z0-9]{6}-[A-Z0-9]{6}$ ]] || \
    fail "billing account ID must use the format 000000-000000-000000"
}

validate_numeric_id() {
  [[ "$1" =~ ^[0-9]+$ ]] || fail "resource IDs for organizations and folders must be numeric"
}

validate_project_id() {
  [[ "$1" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]] || \
    fail "project IDs must be valid Google Cloud project IDs"
}

validate_bigquery_dataset_id() {
  [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]{0,1023}$ ]] || \
    fail "BigQuery dataset IDs must be valid dataset identifiers"
}

validate_bigquery_location() {
  [[ "$1" =~ ^[A-Za-z0-9-]+$ ]] || \
    fail "BigQuery locations must be non-empty and use only letters, numbers, or hyphens"
}

canonicalize_bigquery_location() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

parse_bool_flag() {
  local value="$1"

  case "$value" in
    true|TRUE|1|yes|YES)
      echo 1
      ;;
    false|FALSE|0|no|NO)
      echo 0
      ;;
    *)
      fail "boolean flags must be true or false"
      ;;
  esac
}

org_only_roles_enabled() {
  [[ "$CLOUD_ASSETS" -eq 1 || "$RECOMMENDER" -eq 1 || "$MONITORING" -eq 1 || \
     "$COMPUTE" -eq 1 || "$CONTAINERS" -eq 1 || "$CLOUDSQL" -eq 1 || "$CLOUDRUN" -eq 1 || \
     "$TAGS" -eq 1 || "$PUBSUB" -eq 1 || "$STORAGE" -eq 1 || "$VERTEX_AI" -eq 1 || \
     "$BIGQUERY_METADATA" -eq 1 || "$BIGQUERY_JOB_METADATA" -eq 1 ]]
}

append_resource_id() {
  local incoming_scope="$1"
  local resource_id="$2"

  if [[ -n "$RESOURCE_SCOPE" && "$RESOURCE_SCOPE" != "$incoming_scope" ]]; then
    fail "use only one of --organization, --folder, or --project in a single run"
  fi

  RESOURCE_SCOPE="$incoming_scope"
  RESOURCE_IDS+=("$resource_id")
}

append_billing_export_dataset() {
  local spec="$1"
  local project_id
  local dataset_id
  local location
  local extra

  IFS=':' read -r project_id dataset_id location extra <<< "$spec"
  [[ -n "${project_id:-}" && -n "${dataset_id:-}" && -n "${location:-}" && -z "${extra:-}" ]] || \
    fail "--billing-export-dataset must use PROJECT_ID:DATASET_ID:LOCATION"

  validate_project_id "$project_id"
  validate_bigquery_dataset_id "$dataset_id"
  validate_bigquery_location "$location"

  BILLING_EXPORT_DATASETS+=("${project_id}|${dataset_id}|${location}")
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --service-account-email)
      [[ $# -ge 2 ]] || fail "missing value for $1"
      SERVICE_ACCOUNT_EMAIL="$2"
      shift 2
      ;;
    --billing-account)
      [[ $# -ge 2 ]] || fail "missing value for $1"
      BILLING_ACCOUNT_ID="$2"
      shift 2
      ;;
    --organization)
      [[ $# -ge 2 ]] || fail "missing value for $1"
      append_resource_id "organization" "$2"
      shift 2
      ;;
    --folder)
      [[ $# -ge 2 ]] || fail "missing value for $1"
      append_resource_id "folder" "$2"
      shift 2
      ;;
    --project)
      [[ $# -ge 2 ]] || fail "missing value for $1"
      append_resource_id "project" "$2"
      shift 2
      ;;
    --billing-export-dataset)
      [[ $# -ge 2 ]] || fail "missing value for $1"
      append_billing_export_dataset "$2"
      shift 2
      ;;
    --billing-role)
      [[ $# -ge 2 ]] || fail "missing value for $1"
      BILLING_ROLE="$2"
      shift 2
      ;;
    --resource-role)
      [[ $# -ge 2 ]] || fail "missing value for $1"
      RESOURCE_ROLE="$2"
      shift 2
      ;;
    --cloud-assets)
      CLOUD_ASSETS=1
      shift
      ;;
    --cloud-assets=*)
      CLOUD_ASSETS=$(parse_bool_flag "${1#*=}")
      shift
      ;;
    --recommender)
      RECOMMENDER=1
      shift
      ;;
    --recommender=*)
      RECOMMENDER=$(parse_bool_flag "${1#*=}")
      shift
      ;;
    --monitoring)
      MONITORING=1
      shift
      ;;
    --monitoring=*)
      MONITORING=$(parse_bool_flag "${1#*=}")
      shift
      ;;
    --compute)
      COMPUTE=1
      shift
      ;;
    --compute=*)
      COMPUTE=$(parse_bool_flag "${1#*=}")
      shift
      ;;
    --containers)
      CONTAINERS=1
      shift
      ;;
    --containers=*)
      CONTAINERS=$(parse_bool_flag "${1#*=}")
      shift
      ;;
    --cloudsql)
      CLOUDSQL=1
      shift
      ;;
    --cloudsql=*)
      CLOUDSQL=$(parse_bool_flag "${1#*=}")
      shift
      ;;
    --cloudrun)
      CLOUDRUN=1
      shift
      ;;
    --cloudrun=*)
      CLOUDRUN=$(parse_bool_flag "${1#*=}")
      shift
      ;;
    --tags)
      TAGS=1
      shift
      ;;
    --tags=*)
      TAGS=$(parse_bool_flag "${1#*=}")
      shift
      ;;
    --pubsub)
      PUBSUB=1
      shift
      ;;
    --pubsub=*)
      PUBSUB=$(parse_bool_flag "${1#*=}")
      shift
      ;;
    --storage)
      STORAGE=1
      shift
      ;;
    --storage=*)
      STORAGE=$(parse_bool_flag "${1#*=}")
      shift
      ;;
    --vertex-ai)
      VERTEX_AI=1
      shift
      ;;
    --vertex-ai=*)
      VERTEX_AI=$(parse_bool_flag "${1#*=}")
      shift
      ;;
    --bigquery-metadata)
      BIGQUERY_METADATA=1
      shift
      ;;
    --bigquery-metadata=*)
      BIGQUERY_METADATA=$(parse_bool_flag "${1#*=}")
      shift
      ;;
    --bigquery-jobs)
      BIGQUERY_JOB_METADATA=1
      shift
      ;;
    --bigquery-jobs=*)
      BIGQUERY_JOB_METADATA=$(parse_bool_flag "${1#*=}")
      shift
      ;;
    --bigquery-job-user-project)
      [[ $# -ge 2 ]] || fail "missing value for $1"
      BQ_JOB_USER_PROJECT_IDS+=("$2")
      shift 2
      ;;
    --gcloud-bin)
      [[ $# -ge 2 ]] || fail "missing value for $1"
      GCLOUD_BIN="$2"
      shift 2
      ;;
    --bq-bin)
      [[ $# -ge 2 ]] || fail "missing value for $1"
      BQ_BIN="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --validate)
      VALIDATE_ONLY=1
      shift
      ;;
    --show-allowed-policy-member-domain-values)
      SHOW_ALLOWED_POLICY_MEMBER_DOMAIN_VALUES=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

if [[ "$SHOW_ALLOWED_POLICY_MEMBER_DOMAIN_VALUES" -eq 1 ]]; then
  print_allowed_policy_member_domain_values
  exit 0
fi

[[ -n "$SERVICE_ACCOUNT_EMAIL" ]] || fail "--service-account-email is required"
[[ -n "$BILLING_ACCOUNT_ID" ]] || fail "--billing-account is required"
[[ ${#RESOURCE_IDS[@]} -gt 0 ]] || fail "at least one --organization, --folder, or --project value is required"
[[ ${#BILLING_EXPORT_DATASETS[@]} -gt 0 ]] || fail "at least one --billing-export-dataset value is required"

validate_service_account_email "$SERVICE_ACCOUNT_EMAIL"
validate_billing_account_id "$BILLING_ACCOUNT_ID"

case "$RESOURCE_SCOPE" in
  organization|folder)
    for resource_id in "${RESOURCE_IDS[@]}"; do
      validate_numeric_id "$resource_id"
    done
    ;;
  project)
    for resource_id in "${RESOURCE_IDS[@]}"; do
      validate_project_id "$resource_id"
    done
    ;;
  *)
    fail "unsupported resource scope: $RESOURCE_SCOPE"
    ;;
esac

for project_id in "${BQ_JOB_USER_PROJECT_IDS[@]}"; do
  validate_project_id "$project_id"
done

require_command "$GCLOUD_BIN"
require_command "$BQ_BIN"
require_command python3

if [[ "$RESOURCE_SCOPE" != "organization" ]] && org_only_roles_enabled; then
  fail "org-level product roles require --organization. Disable them with --cloud-assets=false --recommender=false --monitoring=false --compute=false --containers=false --cloudsql=false --cloudrun=false --tags=false --pubsub=false --storage=false --vertex-ai=false --bigquery-metadata=false --bigquery-jobs=false when using --folder or --project"
fi

if [[ "$BIGQUERY_METADATA" -eq 1 || "$BIGQUERY_JOB_METADATA" -eq 1 ]] && [[ ${#BQ_JOB_USER_PROJECT_IDS[@]} -eq 0 ]]; then
  fail "enabled BigQuery metadata roles require at least one --bigquery-job-user-project"
fi

verify_billing_export_dataset_locations

MEMBER="serviceAccount:${SERVICE_ACCOUNT_EMAIL}"

if [[ "$VALIDATE_ONLY" -eq 1 ]]; then
  DRY_RUN=0
fi

echo "Granting EntropyFabric onboarding permissions to ${SERVICE_ACCOUNT_EMAIL}"
echo "Billing account: ${BILLING_ACCOUNT_ID} (${BILLING_ROLE})"
echo "Resource scope: ${RESOURCE_SCOPE} (${RESOURCE_ROLE})"
printf 'Resource IDs:'
printf ' %s' "${RESOURCE_IDS[@]}"
printf '\n'
echo "Billing export datasets:"
for dataset_entry in "${BILLING_EXPORT_DATASETS[@]}"; do
  IFS='|' read -r project_id dataset_id location <<< "$dataset_entry"
  echo "  ${project_id}:${dataset_id} (${location})"
done
if [[ "$VALIDATE_ONLY" -eq 1 ]]; then
  echo "Mode: validate-only"
elif [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Mode: dry-run"
else
  echo "Mode: apply"
fi
if [[ "$RESOURCE_SCOPE" == "organization" ]]; then
  echo "Org-level roles:"
  echo "  cloud-assets=${CLOUD_ASSETS} recommender=${RECOMMENDER} monitoring=${MONITORING} compute=${COMPUTE} containers=${CONTAINERS} cloudsql=${CLOUDSQL} cloudrun=${CLOUDRUN}"
  echo "  tags=${TAGS} pubsub=${PUBSUB} storage=${STORAGE} vertex-ai=${VERTEX_AI} bigquery-metadata=${BIGQUERY_METADATA} bigquery-jobs=${BIGQUERY_JOB_METADATA}"
  if [[ ${#BQ_JOB_USER_PROJECT_IDS[@]} -gt 0 ]]; then
    printf 'BigQuery runner projects:'
    printf ' %s' "${BQ_JOB_USER_PROJECT_IDS[@]}"
    printf '\n'
  fi
fi

apply_binding "billing-account" "$BILLING_ACCOUNT_ID" "$BILLING_ROLE" \
  "$GCLOUD_BIN" billing accounts add-iam-policy-binding \
  "$BILLING_ACCOUNT_ID" \
  --member="$MEMBER" \
  --role="$BILLING_ROLE"

for resource_id in "${RESOURCE_IDS[@]}"; do
  case "$RESOURCE_SCOPE" in
    organization)
      apply_binding "organization" "$resource_id" "$RESOURCE_ROLE" \
        "$GCLOUD_BIN" organizations add-iam-policy-binding \
        "$resource_id" \
        --member="$MEMBER" \
        --role="$RESOURCE_ROLE" \
        --condition=None

      if [[ "$CLOUD_ASSETS" -eq 1 ]]; then
        apply_binding "organization" "$resource_id" "$ROLE_CLOUD_ASSET_VIEWER" \
          "$GCLOUD_BIN" organizations add-iam-policy-binding \
          "$resource_id" \
          --member="$MEMBER" \
          --role="$ROLE_CLOUD_ASSET_VIEWER" \
          --condition=None
        apply_binding "organization" "$resource_id" "$ROLE_SERVICE_USAGE_CONSUMER" \
          "$GCLOUD_BIN" organizations add-iam-policy-binding \
          "$resource_id" \
          --member="$MEMBER" \
          --role="$ROLE_SERVICE_USAGE_CONSUMER" \
          --condition=None
      fi

      if [[ "$RECOMMENDER" -eq 1 ]]; then
        apply_binding "organization" "$resource_id" "$ROLE_RECOMMENDER_VIEWER" \
          "$GCLOUD_BIN" organizations add-iam-policy-binding \
          "$resource_id" \
          --member="$MEMBER" \
          --role="$ROLE_RECOMMENDER_VIEWER" \
          --condition=None
      fi

      if [[ "$MONITORING" -eq 1 ]]; then
        apply_binding "organization" "$resource_id" "$ROLE_MONITORING_VIEWER" \
          "$GCLOUD_BIN" organizations add-iam-policy-binding \
          "$resource_id" \
          --member="$MEMBER" \
          --role="$ROLE_MONITORING_VIEWER" \
          --condition=None
      fi

      if [[ "$COMPUTE" -eq 1 ]]; then
        apply_binding "organization" "$resource_id" "$ROLE_COMPUTE_VIEWER" \
          "$GCLOUD_BIN" organizations add-iam-policy-binding \
          "$resource_id" \
          --member="$MEMBER" \
          --role="$ROLE_COMPUTE_VIEWER" \
          --condition=None
      fi

      if [[ "$CONTAINERS" -eq 1 ]]; then
        apply_binding "organization" "$resource_id" "$ROLE_CONTAINER_VIEWER" \
          "$GCLOUD_BIN" organizations add-iam-policy-binding \
          "$resource_id" \
          --member="$MEMBER" \
          --role="$ROLE_CONTAINER_VIEWER" \
          --condition=None
      fi

      if [[ "$CLOUDSQL" -eq 1 ]]; then
        apply_binding "organization" "$resource_id" "$ROLE_CLOUDSQL_VIEWER" \
          "$GCLOUD_BIN" organizations add-iam-policy-binding \
          "$resource_id" \
          --member="$MEMBER" \
          --role="$ROLE_CLOUDSQL_VIEWER" \
          --condition=None
      fi

      if [[ "$CLOUDRUN" -eq 1 ]]; then
        apply_binding "organization" "$resource_id" "$ROLE_RUN_VIEWER" \
          "$GCLOUD_BIN" organizations add-iam-policy-binding \
          "$resource_id" \
          --member="$MEMBER" \
          --role="$ROLE_RUN_VIEWER" \
          --condition=None
      fi

      if [[ "$TAGS" -eq 1 ]]; then
        apply_binding "organization" "$resource_id" "$ROLE_TAG_VIEWER" \
          "$GCLOUD_BIN" organizations add-iam-policy-binding \
          "$resource_id" \
          --member="$MEMBER" \
          --role="$ROLE_TAG_VIEWER" \
          --condition=None
      fi

      if [[ "$PUBSUB" -eq 1 ]]; then
        apply_binding "organization" "$resource_id" "$ROLE_PUBSUB_VIEWER" \
          "$GCLOUD_BIN" organizations add-iam-policy-binding \
          "$resource_id" \
          --member="$MEMBER" \
          --role="$ROLE_PUBSUB_VIEWER" \
          --condition=None
      fi

      if [[ "$STORAGE" -eq 1 ]]; then
        apply_binding "organization" "$resource_id" "$ROLE_STORAGE_BUCKET_VIEWER" \
          "$GCLOUD_BIN" organizations add-iam-policy-binding \
          "$resource_id" \
          --member="$MEMBER" \
          --role="$ROLE_STORAGE_BUCKET_VIEWER" \
          --condition=None
      fi

      if [[ "$VERTEX_AI" -eq 1 ]]; then
        apply_binding "organization" "$resource_id" "$ROLE_VERTEX_AI_VIEWER" \
          "$GCLOUD_BIN" organizations add-iam-policy-binding \
          "$resource_id" \
          --member="$MEMBER" \
          --role="$ROLE_VERTEX_AI_VIEWER" \
          --condition=None
      fi

      if [[ "$BIGQUERY_METADATA" -eq 1 ]]; then
        apply_binding "organization" "$resource_id" "$ROLE_BIGQUERY_METADATA_VIEWER" \
          "$GCLOUD_BIN" organizations add-iam-policy-binding \
          "$resource_id" \
          --member="$MEMBER" \
          --role="$ROLE_BIGQUERY_METADATA_VIEWER" \
          --condition=None
      fi

      if [[ "$BIGQUERY_JOB_METADATA" -eq 1 ]]; then
        apply_binding "organization" "$resource_id" "$ROLE_BIGQUERY_RESOURCE_VIEWER" \
          "$GCLOUD_BIN" organizations add-iam-policy-binding \
          "$resource_id" \
          --member="$MEMBER" \
          --role="$ROLE_BIGQUERY_RESOURCE_VIEWER" \
          --condition=None
      fi
      ;;
    folder)
      apply_binding "folder" "$resource_id" "$RESOURCE_ROLE" \
        "$GCLOUD_BIN" resource-manager folders add-iam-policy-binding \
        "$resource_id" \
        --member="$MEMBER" \
        --role="$RESOURCE_ROLE" \
        --condition=None
      ;;
    project)
      apply_binding "project" "$resource_id" "$RESOURCE_ROLE" \
        "$GCLOUD_BIN" projects add-iam-policy-binding \
        "$resource_id" \
        --member="$MEMBER" \
        --role="$RESOURCE_ROLE" \
        --condition=None
      ;;
  esac
done

for dataset_entry in "${BILLING_EXPORT_DATASETS[@]}"; do
  IFS='|' read -r project_id dataset_id location <<< "$dataset_entry"
  apply_billing_export_dataset_binding "${project_id}:${dataset_id}"
done

for project_id in "${BQ_JOB_USER_PROJECT_IDS[@]}"; do
  apply_binding "project" "$project_id" "$ROLE_BIGQUERY_JOB_USER" \
    "$GCLOUD_BIN" projects add-iam-policy-binding \
    "$project_id" \
    --member="$MEMBER" \
    --role="$ROLE_BIGQUERY_JOB_USER" \
    --condition=None
done

print_binding_summary

if [[ "$VALIDATE_ONLY" -eq 1 ]]; then
  echo "Validation complete. No IAM policies were changed."
elif [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run complete. Existing bindings were detected and no IAM policies were changed."
else
  echo "Onboarding bindings applied successfully. Existing bindings were skipped."
fi
