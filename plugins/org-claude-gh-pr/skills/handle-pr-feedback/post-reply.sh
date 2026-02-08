#!/bin/bash
# Post a reply to a review comment thread.
# Usage: ./post-reply.sh OWNER REPO PR_NUMBER COMMENT_ID "reply text"

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"
COMMENT_ID="$4"
BODY="$5"

gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments" \
  -f body="$BODY" \
  -F in_reply_to="$COMMENT_ID"
