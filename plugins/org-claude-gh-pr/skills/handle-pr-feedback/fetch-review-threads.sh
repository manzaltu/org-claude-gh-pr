#!/bin/bash
# Fetch inline review threads from a GitHub PR (paginated).
# Usage: ./fetch-review-threads.sh OWNER REPO PR_NUMBER [CURSOR]
# CURSOR is optional, for pagination.

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
          comments(first: 20) {
            totalCount
            nodes {
              databaseId
              author { login }
              path
              line
              originalLine
              body
              createdAt
            }
          }
        }
      }
    }
  }
}"
