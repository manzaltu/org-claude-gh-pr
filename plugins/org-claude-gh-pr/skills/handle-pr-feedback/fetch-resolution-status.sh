#!/bin/bash
# Fetch resolution status for all review threads.
# Usage: ./fetch-resolution-status.sh OWNER REPO PR_NUMBER [CURSOR]
# Returns JSON array of {id, resolved, commentCount} objects.

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"
CURSOR="$4"

AFTER_CLAUSE=""
if [ -n "$CURSOR" ]; then
    AFTER_CLAUSE=", after: \"$CURSOR\""
fi

gh api graphql -f query="
{
  repository(owner: \"$OWNER\", name: \"$REPO\") {
    pullRequest(number: $PR_NUMBER) {
      reviewThreads(first: 100${AFTER_CLAUSE}) {
        totalCount
        pageInfo { hasNextPage endCursor }
        nodes {
          isResolved
          comments(first: 1) {
            totalCount
            nodes { databaseId }
          }
        }
      }
    }
  }
}" --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | {id: .comments.nodes[0].databaseId, resolved: .isResolved, commentCount: .comments.totalCount}]'
