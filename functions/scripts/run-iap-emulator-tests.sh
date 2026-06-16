#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

if ! java -version >/dev/null 2>&1; then
  if [[ -z "${JAVA_HOME:-}" ]]; then
    if /usr/libexec/java_home >/dev/null 2>&1; then
      export JAVA_HOME="$(/usr/libexec/java_home)"
    elif [[ -x /opt/homebrew/opt/openjdk@21/bin/java ]]; then
      export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
    elif [[ -x /opt/homebrew/opt/openjdk@17/bin/java ]]; then
      export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
    fi
  fi
  if [[ -n "${JAVA_HOME:-}" ]]; then
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
fi

npm --prefix functions run build
firebase emulators:exec \
  --project demo-tarot-iap-test \
  --only auth,firestore,functions \
  "./functions/node_modules/.bin/vitest run functions/test/iap-validation.integration.test.ts"
