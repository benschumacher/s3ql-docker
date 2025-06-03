#!/bin/bash
# .github/scripts/calculate_version.sh

set -e # Exit immediately if a command exits with a non-zero status.
# set -u # Treat unset variables as an error.
# set -o pipefail # Causes a pipeline to return the exit status of the last command in the pipe that failed.

# --- Helper Functions for Logging ---
log_info() {
  echo "INFO: $1"
}

log_error() {
  # GitHub Actions error annotation format
  echo "::error file=${VERSION_FILE}::$1"
}

log_notice() {
  # GitHub Actions notice annotation format
  echo "::notice file=${VERSION_FILE}::$1"
}

# --- Input Environment Variables (expected to be set by the caller) ---
# EVENT_NAME: ${{ github.event_name }}
# GIT_REF: ${{ github.ref }}
# EVENT_BEFORE_SHA: ${{ github.event.before }} (SHA before the push)
# CURRENT_SHA: ${{ github.sha }} (Current SHA of the push)
# S3QL_VERSION_VALUE: From S3QL_VERSION file
# VERSION_FILE: e.g., "VERSION" (relative to workspace root)
# WORKSPACE_PATH: ${{ github.workspace }}

# --- Script Logic ---
CURRENT_DATE_YM=$(date +'%Y.%m')
TARGET_VERSION_FOR_TAGGING=""
# This variable will hold the version that *should* be written to the VERSION file
# if this script decides an update is necessary (for main branch pushes/dispatches).
VERSION_TO_WRITE_TO_FILE_CONTENT=""

ABSOLUTE_VERSION_FILE_PATH="${WORKSPACE_PATH}/${VERSION_FILE}"

log_info "--- Version Calculation Script Start ---"
log_info "Event Name: ${EVENT_NAME}"
log_info "Git Ref: ${GIT_REF}"
log_info "Current Date (YYYY.MM): ${CURRENT_DATE_YM}"
log_info "S3QL Version: ${S3QL_VERSION_VALUE}"
log_info "Version File Path (relative): ${VERSION_FILE}"
log_info "Version File Path (absolute): ${ABSOLUTE_VERSION_FILE_PATH}"
log_info "Event Before SHA: ${EVENT_BEFORE_SHA}"
log_info "Current SHA: ${CURRENT_SHA}"
log_info "Workspace Path: ${WORKSPACE_PATH}"


if [[ ! -f "$ABSOLUTE_VERSION_FILE_PATH" ]]; then
  log_error "'${VERSION_FILE}' not found."
  if [[ ("${EVENT_NAME}" == "push" && "${GIT_REF}" == "refs/heads/main") || "${EVENT_NAME}" == "workflow_dispatch" ]]; then
    log_notice "Initializing '${VERSION_FILE}' to ${CURRENT_DATE_YM}.0 for main branch/dispatch."
    TARGET_VERSION_FOR_TAGGING="${CURRENT_DATE_YM}.0"
    VERSION_TO_WRITE_TO_FILE_CONTENT="${CURRENT_DATE_YM}.0"
  else
    # For PRs, the file must exist.
    log_notice "For Pull Requests, '${VERSION_FILE}' must exist. Please create it (e.g., with '${CURRENT_DATE_YM}.0') and commit it."
    exit 1
  fi
else
  # VERSION file exists
  EXISTING_VERSION_IN_FILE=$(cat "$ABSOLUTE_VERSION_FILE_PATH")
  log_info "Existing version in '${VERSION_FILE}': $EXISTING_VERSION_IN_FILE"

  if ! [[ "$EXISTING_VERSION_IN_FILE" =~ ^([0-9]{4}\.[0-9]{2})\.([0-9]+)$ ]]; then
    log_error "Content '$EXISTING_VERSION_IN_FILE' in '${VERSION_FILE}' is not in YYYY.MM.REVISION format."
    if [[ ("${EVENT_NAME}" == "push" && "${GIT_REF}" == "refs/heads/main") || "${EVENT_NAME}" == "workflow_dispatch" ]]; then
        log_notice "Resetting '${VERSION_FILE}' to ${CURRENT_DATE_YM}.0 due to format error on main branch/dispatch."
        TARGET_VERSION_FOR_TAGGING="${CURRENT_DATE_YM}.0"
        VERSION_TO_WRITE_TO_FILE_CONTENT="${CURRENT_DATE_YM}.0"
    else
        # For PRs, fail if format is wrong.
        log_notice "Please correct '${VERSION_FILE}' (e.g., to '${CURRENT_DATE_YM}.0') and commit the change for the Pull Request."
        exit 1
    fi
  else
    # VERSION file has correct format
    EXISTING_YM_IN_FILE="${BASH_REMATCH[1]}"
    EXISTING_REV_IN_FILE="${BASH_REMATCH[2]}"

    if [[ "${EVENT_NAME}" == "pull_request" ]]; then
      # For PRs, always use the version from the PR's VERSION file for tagging.
      # Do not modify the VERSION file or attempt to commit.
      TARGET_VERSION_FOR_TAGGING="$EXISTING_VERSION_IN_FILE"
      log_info "Pull Request event. Using version from '${VERSION_FILE}' for tagging: $TARGET_VERSION_FOR_TAGGING"
      # VERSION_TO_WRITE_TO_FILE_CONTENT remains empty, so file isn't touched by script.

    elif [[ ("${EVENT_NAME}" == "push" && "${GIT_REF}" == "refs/heads/main") || "${EVENT_NAME}" == "workflow_dispatch" ]]; then
      # Logic for PUSH to MAIN branch or WORKFLOW_DISPATCH on main branch
      VERSION_FILE_MANUALLY_UPDATED_IN_PUSH=false
      if [[ "${EVENT_NAME}" == "push" ]]; then
        # Check if EVENT_BEFORE_SHA is the zero hash (initial push to a new branch, or branch created from empty)
        # The `github.event.before` is '0000000000000000000000000000000000000000' for the first push to a new branch.
        if [[ "${EVENT_BEFORE_SHA}" != "0000000000000000000000000000000000000000" ]]; then
          # Use `git diff` to see if VERSION file was part of the pushed commits
          # Ensure we run git commands from the repository root
          if (cd "${WORKSPACE_PATH}" && git diff --name-only "${EVENT_BEFORE_SHA}" "${CURRENT_SHA}" | grep -q "^${VERSION_FILE}$"); then
            log_info "'${VERSION_FILE}' was explicitly modified in this push."
            VERSION_FILE_MANUALLY_UPDATED_IN_PUSH=true
          else
            log_info "'${VERSION_FILE}' was NOT explicitly modified in this push."
          fi
        else
          log_info "This is an initial push to the branch or the 'before' SHA is zero. Assuming '${VERSION_FILE}' (if valid) is as intended by the user."
          # If the file exists and is valid on an initial push, treat its content as "manually set" for this event.
          VERSION_FILE_MANUALLY_UPDATED_IN_PUSH=true
        fi
      fi
      # For workflow_dispatch, VERSION_FILE_MANUALLY_UPDATED_IN_PUSH remains false (default), meaning auto-increment logic will apply unless month changes.

      if [[ "$EXISTING_YM_IN_FILE" == "$CURRENT_DATE_YM" ]]; then
        # YYYY.MM in file matches current YYYY.MM
        if [[ "$VERSION_FILE_MANUALLY_UPDATED_IN_PUSH" == "true" && "${EVENT_NAME}" == "push" ]]; then
          # Manually updated in this push, and month matches. Use the version from the file as is.
          TARGET_VERSION_FOR_TAGGING="$EXISTING_VERSION_IN_FILE"
          VERSION_TO_WRITE_TO_FILE_CONTENT="$EXISTING_VERSION_IN_FILE" # This ensures the file reflects the used version.
          log_info "Month matches. '${VERSION_FILE}' was manually updated in this push. Using its content: $TARGET_VERSION_FOR_TAGGING"
        else
          # Month matches, but file NOT manually updated in this push (or it's a workflow_dispatch). Auto-increment.
          NEW_REV=$((EXISTING_REV_IN_FILE + 1))
          TARGET_VERSION_FOR_TAGGING="${CURRENT_DATE_YM}.${NEW_REV}"
          VERSION_TO_WRITE_TO_FILE_CONTENT="${CURRENT_DATE_YM}.${NEW_REV}"
          log_info "Month matches. Auto-incrementing revision for '${VERSION_FILE}': $TARGET_VERSION_FOR_TAGGING"
        fi
      else
        # YYYY.MM in file does NOT match current YYYY.MM (new month/year). Reset revision.
        TARGET_VERSION_FOR_TAGGING="${CURRENT_DATE_YM}.0"
        VERSION_TO_WRITE_TO_FILE_CONTENT="${CURRENT_DATE_YM}.0"
        log_info "New month/year (file YM: $EXISTING_YM_IN_FILE, current YM: $CURRENT_DATE_YM). Resetting revision in '${VERSION_FILE}' to: $TARGET_VERSION_FOR_TAGGING"
      fi
    else
      # Fallback for any other unexpected event contexts (should not be reached with current workflow triggers)
      TARGET_VERSION_FOR_TAGGING="$EXISTING_VERSION_IN_FILE"
      log_info "Fallback: Unknown event context. Using version from '${VERSION_FILE}' for tagging: $TARGET_VERSION_FOR_TAGGING"
    fi
  fi
fi

log_info "Final version for image tagging determined as: $TARGET_VERSION_FOR_TAGGING"

# --- Set GitHub Actions Outputs ---
# The GITHUB_OUTPUT environment file is automatically available.
echo "new_version=${TARGET_VERSION_FOR_TAGGING}" >> "$GITHUB_OUTPUT"
echo "s3ql_version_passthrough=${S3QL_VERSION_VALUE}" >> "$GITHUB_OUTPUT"
log_info "Set GitHub Action outputs: new_version, s3ql_version_passthrough"

# --- Update VERSION file in Workspace (if applicable) ---
# This write happens only if VERSION_TO_WRITE_TO_FILE_CONTENT was set,
# meaning it's a main branch push or dispatch, and the script decided on a version.
if [[ -n "$VERSION_TO_WRITE_TO_FILE_CONTENT" ]]; then
  if [[ ! -f "$ABSOLUTE_VERSION_FILE_PATH" || "$(cat "$ABSOLUTE_VERSION_FILE_PATH")" != "$VERSION_TO_WRITE_TO_FILE_CONTENT" ]]; then
    log_info "Updating '${ABSOLUTE_VERSION_FILE_PATH}' in workspace to: '$VERSION_TO_WRITE_TO_FILE_CONTENT'"
    echo "$VERSION_TO_WRITE_TO_FILE_CONTENT" > "$ABSOLUTE_VERSION_FILE_PATH"
  else
    log_info "'${ABSOLUTE_VERSION_FILE_PATH}' content already matches '$VERSION_TO_WRITE_TO_FILE_CONTENT'. No write needed."
  fi
else
  log_info "'${ABSOLUTE_VERSION_FILE_PATH}' in workspace not modified by this script for this event type/condition."
fi

log_info "--- Version Calculation Script End ---"
