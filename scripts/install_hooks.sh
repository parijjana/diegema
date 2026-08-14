#!/usr/bin/env bash
# Script to install local Git pre-commit hooks for diegema

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_DIR="$( dirname "$SCRIPT_DIR" )"
HOOKS_DIR="$REPO_DIR/.git/hooks"

if [ ! -d "$HOOKS_DIR" ]; then
  mkdir -p "$HOOKS_DIR"
fi

cat << 'EOF' > "$HOOKS_DIR/pre-commit"
#!/usr/bin/env bash
# Local CI Pre-Commit Hook for Diegema

set -e

echo "--------------------------------------------------------"
echo "  🚀 [LOCAL CI PRE-COMMIT HOOK] Starting Verification"
echo "--------------------------------------------------------"

# 1. Run Flutter Static Analysis
echo "🔍 Step 1: Running 'flutter analyze'..."
if ! flutter analyze; then
  echo "❌ PRE-COMMIT FAILURE: 'flutter analyze' detected issues."
  echo "Please fix all analysis errors/warnings before committing."
  exit 1
fi
echo "✅ Static Analysis Passed!"
echo ""

# 2. Run Flutter TDD Test Suite
echo "🧪 Step 2: Running 'flutter test'..."
if ! flutter test; then
  echo "❌ PRE-COMMIT FAILURE: One or more unit/widget tests failed."
  echo "Please fix failing tests before committing."
  exit 1
fi
echo "✅ All TDD Tests Passed Green!"
echo ""

echo "--------------------------------------------------------"
echo " 🎉 [LOCAL CI PRE-COMMIT HOOK] All checks passed green!"
echo "    Proceeding with Git Commit."
echo "--------------------------------------------------------"
exit 0
EOF

chmod +x "$HOOKS_DIR/pre-commit"
echo "✅ Git pre-commit hook installed successfully at $HOOKS_DIR/pre-commit!"
