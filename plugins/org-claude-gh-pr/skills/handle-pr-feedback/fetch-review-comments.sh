#!/bin/bash
# Fetch review-level comments and general PR comments.
# Usage: ./fetch-review-comments.sh OWNER REPO PR_NUMBER

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"

echo "=== Review-level comments ==="
gh api graphql -f query="
{
  repository(owner: \"$OWNER\", name: \"$REPO\") {
    pullRequest(number: $PR_NUMBER) {
      reviews(first: 20) {
        nodes {
          databaseId
          author { login }
          state
          body
          submittedAt
        }
      }
    }
  }
}"

echo ""
echo "=== General PR comments ==="
gh api graphql -f query="
{
  repository(owner: \"$OWNER\", name: \"$REPO\") {
    pullRequest(number: $PR_NUMBER) {
      comments(first: 50) {
        nodes {
          databaseId
          author { login }
          body
          createdAt
        }
      }
    }
  }
}"
