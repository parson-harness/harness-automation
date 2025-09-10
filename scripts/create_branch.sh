#!/usr/bin/env bash
set -euo pipefail

# Optional: local .env for quick tests
if [[ -f .env ]]; then set -a; source .env; set +a; fi
: "${GITHUB_TOKEN:=${GH_TOKEN:-}}"

# ===========================
# HARNESS MAPPINGS (commented for local; OK to leave commented & map via step envs)
# ===========================
# export REPO_URL="<+pipeline.variables.repo_url>"   # OPTIONAL in pipeline (Clone Codebase already did it)
# export BASE_BRANCH="<+pipeline.variables.base_branch>"
# export NEW_BRANCH="feature/<+pipeline.sequenceId>-<+pipeline.variables.project_slug>"
# export GIT_AUTHOR_NAME="Harness IDP Bot"
# export GIT_AUTHOR_EMAIL="idp-bot@example.com"
# export ALLOW_SUFFIX="1"

# Defaults / required
: "${BASE_BRANCH:=main}"
: "${NEW_BRANCH:=feature/new-$(date +%Y%m%d%H%M%S)}"
: "${GIT_AUTHOR_NAME:=Harness IDP Bot}"
: "${GIT_AUTHOR_EMAIL:=idp-bot@example.com}"
: "${ALLOW_SUFFIX:=1}"

have(){ command -v "$1" >/dev/null 2>&1; }
have git || { echo "git not found"; exit 1; }

export GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

# If we're already inside a repo (pipeline w/ Clone Codebase), use it; else clone REPO_URL
if git rev-parse --git-dir >/dev/null 2>&1; then
  echo "📂 Using existing git worktree: $(pwd)"
else
  : "${REPO_URL:?Set REPO_URL (https://github.com/org/repo.git) or run inside a repo}"
  WORKDIR="$(mktemp -d)"
  echo "⤵️  Cloning $REPO_URL@$BASE_BRANCH to $WORKDIR/repo"
  git clone --branch "$BASE_BRANCH" --depth 1 "$REPO_URL" "$WORKDIR/repo"
  cd "$WORKDIR/repo"
fi

# Ensure base exists locally/up-to-date
git fetch --no-tags origin "$BASE_BRANCH" --depth 1 >/dev/null
git switch -C "$BASE_BRANCH" "origin/$BASE_BRANCH" >/dev/null 2>&1 || git switch "$BASE_BRANCH"

# Prepare branch name
SAFE_BRANCH="$NEW_BRANCH"
if git ls-remote --heads origin "$SAFE_BRANCH" | grep -q "$SAFE_BRANCH"; then
  if [[ "$ALLOW_SUFFIX" == "1" ]]; then
    SAFE_BRANCH="${NEW_BRANCH}-$(date +%s)"
    echo "ℹ️  Remote branch exists; using: $SAFE_BRANCH"
  else
    echo "❌ Branch '$NEW_BRANCH' exists. Set ALLOW_SUFFIX=1 to auto-suffix." >&2
    exit 2
  fi
fi

echo "🌱 Creating branch: $SAFE_BRANCH (off $BASE_BRANCH)"
git switch -c "$SAFE_BRANCH"

# Push using whatever auth the connector set on 'origin'
# (Locally, you can provide GITHUB_TOKEN; in pipeline, origin already has App token)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  # local convenience: rewrite remote to include token
  REPO_URL="$(git remote get-url origin)"
  case "$REPO_URL" in
    https://*@*) : ;; # already tokenized
    https://github.com/*) git remote set-url origin "$(echo "$REPO_URL" | sed -E 's#https://#https://oauth2:'"$GITHUB_TOKEN"'@#')" ;;
  esac
fi

git push -u origin "$SAFE_BRANCH"

# Pretty output
CLEAN_URL="$(git remote get-url origin | sed 's#https://[^@]*@#https://#')"
OWNER_REPO="$(echo "$CLEAN_URL" | sed -E 's#https?://[^/]+/([^/]+/[^.]+)(\.git)?#\1#')"
BRANCH_URL="https://github.com/${OWNER_REPO}/tree/${SAFE_BRANCH}"

echo ""
echo "✅ Branch created"
echo "Base:    $BASE_BRANCH"
echo "Branch:  $SAFE_BRANCH"
echo "URL:     $BRANCH_URL"

# Harness outputs
if [[ -n "${HARNESS_ENV_EXPORT:-}" ]]; then
  echo "branch_name=$SAFE_BRANCH" >> "$HARNESS_ENV_EXPORT"
  echo "branch_url=$BRANCH_URL"   >> "$HARNESS_ENV_EXPORT"
fi
