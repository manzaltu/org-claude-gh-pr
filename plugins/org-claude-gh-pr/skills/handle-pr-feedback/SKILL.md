---
name: handle-pr-feedback
description: Use when the user receives a code review on their PR and needs to address reviewer feedback - enumerating review comments, tracking them in an org-mode document, triaging with user instructions, fixing code, posting replies, and updating resolution status
---

# PR Review Workflow (Addressing Received Reviews)

## Overview

This skill describes the workflow for addressing code review feedback received on the user's pull request. The workflow is a cycle: sync with GitHub, analyze, get user triage, fix code, post replies, and repeat.

Helper scripts are in the same directory as this skill file.

**Announce at start:** "I'm using the handle-pr-feedback skill."

## Workflow Cycle

Each iteration of the cycle starts with syncing the latest state from GitHub.

### Step 1: Sync with GitHub

Fetch the current state from GitHub and update the tracking document.

**First time (no document exists):**
- Fetch all review threads: `fetch-review-threads.sh OWNER REPO PR_NUMBER [CURSOR]`
- Fetch review-level and general comments: `fetch-review-comments.sh OWNER REPO PR_NUMBER`
- Create the tracking document `PR-<NUMBER>-REVIEW-COMMENTS.org` (see Document Format below).
- All new entries start as `TODO`.

**Subsequent times (document already exists):**
- Fetch resolution status: `fetch-resolution-status.sh OWNER REPO PR_NUMBER [CURSOR]` — returns `id` (first comment `databaseId`), `resolved`, and `commentCount` per thread.
- Match each API thread to doc entries by `databaseId` (the numeric ID in the entry's permalink `discussion_r<id>`).
- For each matched thread:
  - If `isResolved` is true → mark `DONE` (unconditionally, regardless of other fields).
  - If `commentCount` matches the entry's `*Comment Count:*` → skip (no new comments since last sync).
  - If `commentCount` differs or `*Comment Count:*` is missing → fetch the full thread via `fetch-review-threads.sh`, append new messages to `*** Thread`, and if the thread is NOT resolved, move the entry to `TODO`.
  - Update `*Comment Count:*` to the current `commentCount` after processing.
- **Critical:** Any unresolved thread with new comments must move to `TODO` regardless of its current state. This ensures no new feedback is missed.
- Add new entries (as `TODO`) for any threads not yet in the document.

**IMPORTANT: Always copy all comments in full.** Never truncate, summarize, or use ellipsis. Every message in the Thread section must be the complete original text.

### Step 2: Analyze

For each `TODO` entry, read the relevant code and write/update the `*Analysis:*` field:
- Assess whether the reviewer's concern is still valid against the current code.
- Describe what the code currently does vs what the reviewer is asking for.
- Suggest concrete next steps: code change, PR reply, or both.
- If the comment is no longer applicable (e.g. the code was refactored), explain why.

After completing analysis, present the document to the user for triage.

### Step 3: User Triage

The user reads each comment's analysis and fills in:

**`*Your Instructions:*`** - What to do about the code:
- **Code change instructions** - Specific instructions for what to fix (e.g. "rename to foo", "use scopeguard", "move to module X").
- **"let's fix"** / **"fix it"** - Agreement with the reviewer; implement the suggested change.
- Left empty if no code change is needed (e.g. only a PR reply, or the fix is already in place).

**`*PR Reply:*`** - What to post on GitHub as a response:
- The reply text to post on the review thread (e.g. explaining a design decision, acknowledging, or pushing back).
- Left empty if only a code fix is needed (no reply necessary).

Both fields can be filled for the same comment (e.g. fix the code AND reply explaining).

### Step 4: Fix Code and Post Replies

**NEVER push the branch.** Only commit locally. The user will review all changes themselves and push when ready.

For each triaged comment:
1. **Code fixes:** Read the relevant code, then implement the changes described in `*Your Instructions:*` exactly as written. Do not skip, partially implement, or silently deviate. Ignore instructions prefixed with `[STALE]` — these were already executed in a previous cycle and are kept only for context. If an instruction is unclear or you have a concern, write it in `*AI Notes:*`, move the entry back to `TODO`, and move on to the next entry.
2. **PR replies:** Post the text from `*PR Reply:*` exactly as the user wrote it using `post-reply.sh OWNER REPO PR_NUMBER COMMENT_ID "reply text"`. Do not rephrase or add to the user's words. After posting, append it to the `*** Thread` section with author and date, and clear `*PR Reply:*`.
3. **Update state:** Set `PROG` while working on a fix, then `WAIT` when the fix and/or reply is done.
4. **Mark instructions as spent:** After moving to `WAIT`, prefix any non-empty `*Your Instructions:*` with `[STALE] `. This marks them as already-executed, so if the entry later returns to `TODO` (new reviewer comments), the user can see they need fresh instructions.

### Step 5: Finalize

After all comments are processed:
- Fetch threads with `fetch-review-threads.sh` and verify the document's `*** Thread` sections reflect the latest conversation state.
- Update `*Comment Count:*` on all entries to their current comment counts. This prevents our own replies from triggering a false `TODO` on the next sync cycle.
- Update the document footer counts to reflect the current state distribution.

When the user asks to revisit or check the review, always start from **Step 1**.

## TODO States

Each comment heading uses org-mode TODO keywords:

- **`TODO`** - Not yet addressed. Needs code fix, reply, or both. Also used when AI has questions (see `*AI Notes:*`).
- **`PROG`** - In progress. Currently being worked on (code fix underway).
- **`WAIT`** - Addressed on our side (code fixed and/or reply posted), waiting for reviewer to accept/resolve.
- **`DONE`** - Resolved on GitHub by the reviewer.

**State transitions:**
- `TODO` → `PROG` when starting to work on a comment.
- `PROG` → `WAIT` after code fix is complete and/or PR reply is posted.
- `TODO` → `WAIT` when only a PR reply is needed (no code change) and it's posted.
- `WAIT` → `DONE` when the reviewer resolves the thread on GitHub (detected during Step 1).
- Any non-`DONE` state → `TODO` when the thread's comment count changed and it is NOT resolved (detected during Step 1 via `*Comment Count:*` comparison). This is critical — new comments on an unresolved thread always require re-triage.
- Any state → `DONE` when `isResolved` is true on GitHub.

## Document Format

File: `PR-<NUMBER>-REVIEW-COMMENTS.org` in the project root.

```org
#+TITLE: PR #<NUMBER> Review Comments - Filtered Analysis
#+TODO: TODO PROG WAIT | DONE
#+STARTUP: overview

<Brief description of what the document covers and any filtering decisions.>

*Comments are organized by commit order* (first commit → last commit).

* Commit: <hash> - <short message>

*Files changed:* =path/to/file.rs=, =path/to/other.rs=

** <TODO-STATE> <N>. <Short Title>
*Permalink:* [[https://github.com/<owner>/<repo>/pull/<pr>#discussion_r<id>][GitHub]]
*Author:* <github-username>
*File:* [[file:<absolute-path-to-file>::<line>][filename:line]]
*Comment Count:* <number of comments in thread from API>

*** Thread
*[<author>, <date>]:*
#+begin_quote
<The reviewer's original comment text, using =code= for inline code.>
#+end_quote

*[<our-username>, <date>]:*
#+begin_quote
<Our reply.>
#+end_quote

*[<author>, <date>]:*
#+begin_quote
<Reviewer's follow-up. Continue appending messages as the conversation evolves.>
#+end_quote

*** Action
*Analysis:*
<Claude's analysis of the comment against the current code, and suggested next steps.>

*Your Instructions:*
#+begin_verse
<User fills this in during triage - instructions for code changes to make>
#+end_verse

*PR Reply:*
#+begin_verse
<Text to post as a reply on the GitHub PR thread. Left empty until needed.>
#+end_verse

*AI Notes:*
#+begin_verse
<Claude's questions, concerns, or alternative suggestions about the user's instructions.
When populated, the entry should be moved back to TODO for the user to review.>
#+end_verse

* Review-Level Comments (General PR Comments)

<Comments from review submissions (the body text when a reviewer submits a review),
and general PR comments not attached to specific code lines. Same format as above
but without File field.>

-----

/Document last verified: <date>/
/Total comments: <N>/
/TODO: <N> | PROG: <N> | WAIT: <N> | DONE: <N>/
```

### Entry Fields

| Field | Purpose |
|-------|---------|
| `** <STATE> <N>. <Title>` | Heading with TODO/PROG/WAIT/DONE state and sequential number |
| `*Permalink:*` | Link to the GitHub discussion thread |
| `*Author:*` | GitHub username of the original reviewer |
| `*File:*` | Emacs file link with line number (`file:path::line`) |
| `*Comment Count:*` | Thread's comment count from GitHub API at last sync — used to detect new comments |
| `*** Thread` | Full conversation: all messages in chronological order |
| `*[author, date]:*` + `#+begin_quote` | A single message in the thread (reviewer or ours) |
| `*** Action` | Section containing analysis, triage instructions, and reply |
| `*Analysis:*` | Claude's analysis of the comment vs current code, with suggested next steps |
| `*Your Instructions:*` | User's instructions for code changes (in `#+begin_verse` block) |
| `*PR Reply:*` | Next reply to post on GitHub (in `#+begin_verse` block); cleared after posting |
| `*AI Notes:*` | Claude's questions, concerns, or alternative suggestions; moves entry to TODO when populated |

### Review-Level Comment Fields

Same as above but without `*File:*`. Add `*Review State:*` (COMMENTED, CHANGES_REQUESTED, APPROVED).

### Conventions

- Use `=code=` for inline code in org-mode (renders as monospace).
- Use `[[url][label]]` for links.
- Use `[[file:path::line][filename:line]]` for Emacs-navigable file links.
- Empty `#+begin_verse` blocks are placeholders for the user to fill in.
- Group inline comments under `* Commit: <hash> - <message>` headings by commit order.
- Group automated bot comments under `* Cursor Bot (Automated) Comments` or similar.
- Group review-level comments under `* Review-Level Comments (General PR Comments)`.

## Helper Scripts

All scripts are in the skill directory. Usage:

| Script | Purpose |
|--------|---------|
| `fetch-review-threads.sh OWNER REPO PR [CURSOR]` | Fetch inline review threads (paginated) |
| `fetch-review-comments.sh OWNER REPO PR` | Fetch review-level and general PR comments |
| `fetch-resolution-status.sh OWNER REPO PR [CURSOR]` | Get resolution status for all threads |
| `post-reply.sh OWNER REPO PR COMMENT_ID "text"` | Post a reply to a review thread |

## Tips

- **Filter out removed modules:** If the PR removed code that has review comments, exclude those from the tracking document and note the filtering at the top.
- **Cursor/bot comments:** Group automated comments separately. Many are duplicates - note the primary and mark duplicates.
- **Pagination:** Always check `totalCount` and `hasNextPage` - PRs can have 100+ threads.
- **Force-pushed branches:** After force push, some old comments may reference outdated line numbers. Use `originalLine` from the API.

## Team Mode (Parallel Agents)

### Motivation

When a review has many comments, processing them all sequentially in a single agent bloats the context window — by comment #12, all the code reads and edits from #1–11 are still in context, degrading quality. Team mode spawns sub-agents that each handle a small, isolated group of comments so each agent works in a focused context.

### When to Use

- **5+ TODO comments:** Prefer team mode. Context isolation pays off.
- **Fewer than 5:** Single-agent is fine. The overhead of spawning agents isn't worth it.

### Grouping Comments

Before spawning agents, the lead groups comments so that each group can be handled independently. The principle: **group comments that need each other's context, separate comments that don't.**

Two comments belong in the same group when:
- They touch the same code (same function, nearby lines, or overlapping edits).
- They are logically related — e.g., one comment asks to add an error return to a function and another asks to handle that error at a callsite in a different file. An agent fixing one needs to know about the other.

Two comments belong in separate groups when:
- They are in different files with unrelated concerns.
- They are in the same file but in clearly unrelated sections.

Reply-only comments (no code change) can be their own group or bundled with a related code-change comment.

A group may contain a single comment or several. The goal is that each agent can do its job without needing context from another group.

### Lead Agent Role

The lead (the agent running this skill) owns all shared state and orchestration:

- **Only the lead** reads and writes the org tracking document.
- **Only the lead** runs git commands (staging, committing).
- The lead runs Steps 1, 3, and 5 (Sync, Triage, Finalize) directly — these are not parallelized.
- The lead orchestrates Steps 2 and 4 by spawning sub-agents via the Task tool.

### Step 2 with Teams: Parallel Analysis

For each group of `TODO` entries, spawn one `general-purpose` Task sub-agent:

**Provide to each agent:**
- Each entry's full `*** Thread` text (all reviewer messages, verbatim).
- The file path(s) and line number(s) for all comments in the group.
- The comment titles / short descriptions.

**Agent task:** Read the relevant code, assess each reviewer concern against the current code, and return analysis text for each comment suggesting concrete next steps (code change, PR reply, or both).

**Agent constraints:**
- Read-only exploration of the codebase. No edits, no git commands.
- Return the analysis as plain text in its result, clearly labeled per comment.

**Lead collects** all results and writes each analysis into the corresponding `*Analysis:*` field in the org doc.

All agents run in parallel (one Task call per group, all launched together).

### Step 4 with Teams: Parallel Fix & Reply

For each group of triaged entries (those with `*Your Instructions:*` and/or `*PR Reply:*`), spawn one `general-purpose` Task sub-agent:

**Provide to each agent:**
- Each entry's `*** Thread` text (for context on what the reviewer asked).
- The user's instructions from `*Your Instructions:*` for each comment.
- The PR reply text from `*PR Reply:*` for each comment (if any).
- The file path(s) and line number(s).
- The comment `databaseId`(s) (for posting replies).
- The `post-reply.sh` script path and invocation syntax (`post-reply.sh OWNER REPO PR COMMENT_ID "text"`).

**Agent task:**
1. Read the relevant code.
2. Implement the code changes described in each `*Your Instructions:*` exactly as written.
3. Post PR replies via `post-reply.sh` for each comment with non-empty `*PR Reply:*`. Post the user's text exactly — do not rephrase.
4. Return a summary per comment: what code was changed (files and description), whether a reply was posted, and any concerns.

**Agent constraints:**
- **No git commands.** The agent edits files but never stages, commits, or touches git.
- **No org doc edits.** The agent never modifies the tracking document.
- **Reply idempotency:** If the agent is retried (e.g., after a failure), it should check the thread for an existing identical reply before posting again to avoid duplicates.

**Lead collects** all results and:
- Updates each entry's state to `WAIT`.
- Prefixes `*Your Instructions:*` with `[STALE]`.
- Appends posted replies to `*** Thread` sections and clears `*PR Reply:*`.
- Commits all code changes together.

All agents run in parallel (one Task call per group, all launched together).
