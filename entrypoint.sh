#!/bin/bash
# Varun Chopra <vchopra@eightfold.ai>
#
# This action runs every time a comment is added to a pull request.
# Accepts the following commands: shipit, needs_ci

set -e

if [[ -z "$GITHUB_TOKEN" ]]; then
  echo "Set the GITHUB_TOKEN env variable."
  exit 1
fi

if [[ -z "$GITHUB_REPOSITORY" ]]; then
  echo "Set the GITHUB_REPOSITORY env variable."
  exit 1
fi

if [[ -z "$GITHUB_EVENT_PATH" ]]; then
  echo "Set the GITHUB_EVENT_PATH env variable."
  exit 1
fi

add_label(){
  curl -sSL \
    -H "${AUTH_HEADER}" \
    -H "${API_HEADER}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "{\"labels\":[\"${1}\"]}" \
    "${URI}/repos/${GITHUB_REPOSITORY}/issues/${number}/labels"
}

remove_label(){
  curl -sSL \
    -H "${AUTH_HEADER}" \
    -H "${API_HEADER}" \
    -X DELETE \
    "${URI}/repos/${GITHUB_REPOSITORY}/issues/${number}/labels/${1}"
}

URI="https://api.github.com"
API_HEADER="Accept: application/vnd.github.v3+json"
AUTH_HEADER="Authorization: token ${GITHUB_TOKEN}"

# action
action=$(jq --raw-output .action "$GITHUB_EVENT_PATH")
comment_body=$(jq --raw-output .comment.body "$GITHUB_EVENT_PATH")
number=$(jq --raw-output .issue.number "$GITHUB_EVENT_PATH")
labels=$(jq --raw-output .issue.labels[].name "$GITHUB_EVENT_PATH")

already_needs_ci=false
already_shipit=false

if [[ "$action" != "created" ]]; then
  echo This action should only be called when a comment is created on a pull request
  exit 0
fi

if [[ $comment_body == "shipit" ]]; then
  for label in $labels; do
    case $label in
      needs_revision)
        # remove_label "$label"
        echo "If needs_revision is present, we shouldn't be able to shipit"
        # set already_shipit here. does the same work as already_shipit = TRUE OR needs_revision = TRUE
        already_shipit=true
        ;;
      ci_verified)
        # remove_label "$label"
        echo "We used to remove this when we added needs_ci with shipit"
        ;;
      shipit)
        already_shipit=true
        ;;
      needs_ci)
        already_needs_ci=true
        ;;
      *)
        echo "Unknown label $label"
        ;;
    esac
  done
  if [[ "$already_shipit" == false ]]; then
    add_label "shipit"
  fi
  if [[ "$already_needs_ci" == false ]]; then
    # add_label "needs_ci"
    echo "We used to add needs_ci here but skipping it for now."
  fi
  exit 0
fi

if [[ $comment_body == "needs_ci" ]]; then
  for label in $labels; do
    case $label in
      needs_revision)
        remove_label "$label"
        ;;
      ci_verified)
        remove_label "$label"
        ;;
      shipit)
        remove_label "$label"
        ;;
      needs_ci)
        already_needs_ci=true
        ;;
      *)
        echo "Unknown label $label"
        ;;
    esac
  done
  if [[ "$already_needs_ci" == false ]]; then
    add_label "needs_ci"
  fi
fi
