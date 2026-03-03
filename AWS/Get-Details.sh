#!/usr/bin/env bash
# =============================================================================
# iam-access-report.sh
# Generates a full IAM access report for a given user and exports it as JSON.
# Covers: inline policies, attached managed policies, group policies,
#         permission boundary, and service last-accessed data.
# =============================================================================

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# ── Dependency check ──────────────────────────────────────────────────────────
for cmd in aws jq; do
  if ! command -v "$cmd" &>/dev/null; then
    error "Required command '$cmd' not found. Please install it and retry."
    exit 1
  fi
done

# ── Prompt for username ───────────────────────────────────────────────────────
echo -e "\n${BOLD}╔══════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║        IAM User Access Report Generator      ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${RESET}\n"

read -rp "$(echo -e "${BOLD}Enter IAM username:${RESET} ")" USERNAME

if [[ -z "$USERNAME" ]]; then
  error "Username cannot be empty."
  exit 1
fi

# ── Validate user exists ──────────────────────────────────────────────────────
info "Validating user '${USERNAME}'..."
USER_META=$(aws iam get-user --user-name "$USERNAME" 2>/dev/null) || {
  error "IAM user '${USERNAME}' not found or you lack permission to query it."
  exit 1
}
success "User found."

ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
USER_ARN=$(echo "$USER_META" | jq -r '.User.Arn')
USER_CREATED=$(echo "$USER_META" | jq -r '.User.CreateDate')
OUTPUT_FILE="iam-access-report-${USERNAME}-$(date +%Y%m%d-%H%M%S).json"

# ── Helper: resolve managed policy document ───────────────────────────────────
get_managed_policy_doc() {
  local arn="$1"
  local version
  version=$(aws iam get-policy --policy-arn "$arn" \
    --query 'Policy.DefaultVersionId' --output text 2>/dev/null) || echo "UNKNOWN"
  if [[ "$version" == "UNKNOWN" ]]; then
    echo "null"
    return
  fi
  aws iam get-policy-version --policy-arn "$arn" --version-id "$version" \
    --query 'PolicyVersion.Document' --output json 2>/dev/null || echo "null"
}

# =============================================================================
# 1. INLINE USER POLICIES
# =============================================================================
info "Collecting inline user policies..."
INLINE_USER_POLICIES="[]"
INLINE_NAMES=$(aws iam list-user-policies --user-name "$USERNAME" \
  --query 'PolicyNames[]' --output json 2>/dev/null || echo "[]")

if [[ $(echo "$INLINE_NAMES" | jq 'length') -gt 0 ]]; then
  INLINE_USER_POLICIES="[]"
  while IFS= read -r policy_name; do
    doc=$(aws iam get-user-policy \
      --user-name "$USERNAME" \
      --policy-name "$policy_name" \
      --query 'PolicyDocument' \
      --output json 2>/dev/null || echo "null")
    entry=$(jq -n \
      --arg name "$policy_name" \
      --argjson doc "$doc" \
      '{"PolicyName": $name, "PolicyDocument": $doc}')
    INLINE_USER_POLICIES=$(echo "$INLINE_USER_POLICIES" | jq --argjson e "$entry" '. + [$e]')
  done < <(echo "$INLINE_NAMES" | jq -r '.[]')
fi
success "Inline user policies: $(echo "$INLINE_USER_POLICIES" | jq 'length')"

# =============================================================================
# 2. ATTACHED MANAGED POLICIES (direct)
# =============================================================================
info "Collecting attached managed policies..."
ATTACHED_USER_POLICIES="[]"
ATTACHED_RAW=$(aws iam list-attached-user-policies --user-name "$USERNAME" \
  --query 'AttachedPolicies[]' --output json 2>/dev/null || echo "[]")

if [[ $(echo "$ATTACHED_RAW" | jq 'length') -gt 0 ]]; then
  while IFS= read -r policy_arn; do
    policy_name=$(echo "$ATTACHED_RAW" | jq -r --arg arn "$policy_arn" \
      '.[] | select(.PolicyArn == $arn) | .PolicyName')
    doc=$(get_managed_policy_doc "$policy_arn")
    entry=$(jq -n \
      --arg name "$policy_name" \
      --arg arn "$policy_arn" \
      --argjson doc "$doc" \
      '{"PolicyName": $name, "PolicyArn": $arn, "PolicyDocument": $doc}')
    ATTACHED_USER_POLICIES=$(echo "$ATTACHED_USER_POLICIES" | jq --argjson e "$entry" '. + [$e]')
  done < <(echo "$ATTACHED_RAW" | jq -r '.[].PolicyArn')
fi
success "Attached managed policies: $(echo "$ATTACHED_USER_POLICIES" | jq 'length')"

# =============================================================================
# 3. GROUP MEMBERSHIPS + GROUP POLICIES
# =============================================================================
info "Collecting group memberships and group policies..."
GROUPS_DATA="[]"
GROUPS_RAW=$(aws iam list-groups-for-user --user-name "$USERNAME" \
  --query 'Groups[]' --output json 2>/dev/null || echo "[]")

if [[ $(echo "$GROUPS_RAW" | jq 'length') -gt 0 ]]; then
  while IFS= read -r group_name; do
    # Inline group policies
    group_inline="[]"
    group_inline_names=$(aws iam list-group-policies --group-name "$group_name" \
      --query 'PolicyNames[]' --output json 2>/dev/null || echo "[]")
    while IFS= read -r gp_name; do
      gp_doc=$(aws iam get-group-policy \
        --group-name "$group_name" \
        --policy-name "$gp_name" \
        --query 'PolicyDocument' \
        --output json 2>/dev/null || echo "null")
      gp_entry=$(jq -n \
        --arg name "$gp_name" \
        --argjson doc "$gp_doc" \
        '{"PolicyName": $name, "PolicyDocument": $doc}')
      group_inline=$(echo "$group_inline" | jq --argjson e "$gp_entry" '. + [$e]')
    done < <(echo "$group_inline_names" | jq -r '.[]')

    # Attached managed group policies
    group_managed="[]"
    group_attached_raw=$(aws iam list-attached-group-policies \
      --group-name "$group_name" \
      --query 'AttachedPolicies[]' --output json 2>/dev/null || echo "[]")
    while IFS= read -r gm_arn; do
      gm_name=$(echo "$group_attached_raw" | jq -r --arg arn "$gm_arn" \
        '.[] | select(.PolicyArn == $arn) | .PolicyName')
      gm_doc=$(get_managed_policy_doc "$gm_arn")
      gm_entry=$(jq -n \
        --arg name "$gm_name" \
        --arg arn "$gm_arn" \
        --argjson doc "$gm_doc" \
        '{"PolicyName": $name, "PolicyArn": $arn, "PolicyDocument": $doc}')
      group_managed=$(echo "$group_managed" | jq --argjson e "$gm_entry" '. + [$e]')
    done < <(echo "$group_attached_raw" | jq -r '.[].PolicyArn')

    group_entry=$(jq -n \
      --arg name "$group_name" \
      --argjson inline "$group_inline" \
      --argjson managed "$group_managed" \
      '{"GroupName": $name, "InlinePolicies": $inline, "AttachedManagedPolicies": $managed}')
    GROUPS_DATA=$(echo "$GROUPS_DATA" | jq --argjson e "$group_entry" '. + [$e]')
  done < <(echo "$GROUPS_RAW" | jq -r '.[].GroupName')
fi
success "Groups found: $(echo "$GROUPS_DATA" | jq 'length')"

# =============================================================================
# 4. PERMISSION BOUNDARY
# =============================================================================
info "Checking permission boundary..."
BOUNDARY=$(echo "$USER_META" | jq -r '.User.PermissionsBoundary // empty')
BOUNDARY_DATA="null"
if [[ -n "$BOUNDARY" ]]; then
  boundary_arn=$(echo "$BOUNDARY" | jq -r '.PermissionsBoundaryArn // empty')
  boundary_type=$(echo "$BOUNDARY" | jq -r '.PermissionsBoundaryType // empty')
  if [[ -n "$boundary_arn" ]]; then
    boundary_doc=$(get_managed_policy_doc "$boundary_arn")
    BOUNDARY_DATA=$(jq -n \
      --arg arn "$boundary_arn" \
      --arg type "$boundary_type" \
      --argjson doc "$boundary_doc" \
      '{"PermissionsBoundaryArn": $arn, "PermissionsBoundaryType": $type, "PolicyDocument": $doc}')
    warn "Permission boundary is set — effective permissions are the intersection of granted policies and the boundary."
  fi
else
  success "No permission boundary set."
fi

# =============================================================================
# 5. SERVICE LAST-ACCESSED DATA
# =============================================================================
info "Requesting service last-accessed data (this may take a few seconds)..."
JOB_ID=$(aws iam generate-service-last-accessed-details \
  --arn "$USER_ARN" --query 'JobId' --output text 2>/dev/null || echo "")

LAST_ACCESSED_DATA="[]"
if [[ -n "$JOB_ID" ]]; then
  # Poll until job completes
  for i in {1..12}; do
    JOB_STATUS=$(aws iam get-service-last-accessed-details \
      --job-id "$JOB_ID" --query 'JobStatus' --output text 2>/dev/null || echo "FAILED")
    if [[ "$JOB_STATUS" == "COMPLETED" ]]; then break; fi
    if [[ "$JOB_STATUS" == "FAILED" ]]; then
      warn "Service last-accessed job failed."; break
    fi
    sleep 2
  done

  if [[ "$JOB_STATUS" == "COMPLETED" ]]; then
    LAST_ACCESSED_DATA=$(aws iam get-service-last-accessed-details \
      --job-id "$JOB_ID" \
      --query 'ServicesLastAccessed[]' \
      --output json 2>/dev/null || echo "[]")
    SERVICES_USED=$(echo "$LAST_ACCESSED_DATA" | \
      jq '[.[] | select(.TotalAuthenticatedEntities > 0)] | length')
    SERVICES_TOTAL=$(echo "$LAST_ACCESSED_DATA" | jq 'length')
    success "Last-accessed data retrieved. Services used: ${SERVICES_USED}/${SERVICES_TOTAL}"
  fi
else
  warn "Could not generate service last-accessed data."
fi

# =============================================================================
# 6. ASSEMBLE FINAL JSON REPORT
# =============================================================================
info "Assembling report..."

REPORT=$(jq -n \
  --arg generated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg account "$ACCOUNT_ID" \
  --arg username "$USERNAME" \
  --arg arn "$USER_ARN" \
  --arg created "$USER_CREATED" \
  --argjson boundary "$BOUNDARY_DATA" \
  --argjson inline_user "$INLINE_USER_POLICIES" \
  --argjson attached_user "$ATTACHED_USER_POLICIES" \
  --argjson groups "$GROUPS_DATA" \
  --argjson last_accessed "$LAST_ACCESSED_DATA" \
  '{
    "ReportMetadata": {
      "GeneratedAt": $generated,
      "AccountId": $account,
      "ReportType": "IAMUserAccessReport"
    },
    "User": {
      "UserName": $username,
      "UserArn": $arn,
      "CreatedAt": $created
    },
    "PermissionBoundary": $boundary,
    "DirectPermissions": {
      "InlinePolicies": $inline_user,
      "AttachedManagedPolicies": $attached_user
    },
    "GroupPermissions": $groups,
    "ServiceLastAccessed": $last_accessed,
    "Summary": {
      "InlinePoliciesCount": ($inline_user | length),
      "AttachedManagedPoliciesCount": ($attached_user | length),
      "GroupMembershipsCount": ($groups | length),
      "PermissionBoundarySet": ($boundary != null),
      "ServicesWithAccessCount": ($last_accessed | [.[] | select(.TotalAuthenticatedEntities > 0)] | length),
      "TotalServicesTracked": ($last_accessed | length)
    }
  }')

# =============================================================================
# 7. WRITE OUTPUT
# =============================================================================
echo "$REPORT" | jq '.' > "$OUTPUT_FILE"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║              Report Summary                  ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${RESET}"
echo -e "  User ARN          : ${CYAN}${USER_ARN}${RESET}"
echo -e "  Inline Policies   : $(echo "$REPORT" | jq '.Summary.InlinePoliciesCount')"
echo -e "  Managed Policies  : $(echo "$REPORT" | jq '.Summary.AttachedManagedPoliciesCount')"
echo -e "  Group Memberships : $(echo "$REPORT" | jq '.Summary.GroupMembershipsCount')"
echo -e "  Permission Boundary: $(echo "$REPORT" | jq '.Summary.PermissionBoundarySet')"
echo -e "  Services Used     : $(echo "$REPORT" | jq '.Summary.ServicesWithAccessCount') / $(echo "$REPORT" | jq '.Summary.TotalServicesTracked') tracked"
echo -e "\n${GREEN}${BOLD}Report saved to:${RESET} ${OUTPUT_FILE}\n"