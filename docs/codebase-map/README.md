# Codebase Map

This is the source-checked navigation index for the upstream Osaurus repository. It was written against HEAD c0da268a4258e8f6db7c3bafab96cf93dac0d6b9 on branch main (2026-10-31). It routes work to likely owners; source and focused tests remain authoritative.

## Start here on every task

1. Read this page and [CHANGE_ROUTER.md](CHANGE_ROUTER.md).
2. Find the feature in [FEATURE_INDEX.md](FEATURE_INDEX.md), then follow its owner and dependencies in [DEPENDENCY_MAP.md](DEPENDENCY_MAP.md).
3. Inspect the smallest set of source files and tests that can establish the requested behavior. Expand only when a call or shared value leads to another owner.
4. Use [TEST_MAP.md](TEST_MAP.md) to choose a focused validation lane.
5. Update a map entry when implementation work changes the recorded owner, call path, or test location.

For a small change, do not start with a repository-wide scan. Some chat, server, and registry code is intentionally centralized in large files; search within the named owner for the relevant symbol before opening neighboring subsystems.

## Map documents

- [Feature index](FEATURE_INDEX.md) — owners, entry points, tests, guides, and dependencies.
- [Architecture](ARCHITECTURE.md) — package boundaries and verified execution paths.
- [Change router](CHANGE_ROUTER.md) — symptom-to-file routing and ten navigation examples.
- [Dependency map](DEPENDENCY_MAP.md) — call chains, source of truth, derived state, and gates.
- [Test map](TEST_MAP.md) — focused tests and commands; command status is explicit.

## Scope and limits

The repository root [AGENTS.md](../../AGENTS.md) and the two [.cursor rules](../../.cursor/rules/testing-workflow.mdc) and [settings-catalog.mdc](../../.cursor/rules/settings-catalog.mdc) were read while preparing this map. The root instructions refer to ~/AGENTS.md, but that file was not present at /Users/elsaidwasel/AGENTS.md in this checkout environment. No nested AGENTS.md was found.

Existing topic guides remain useful context. Their implementation details are not duplicated here; consult each guide alongside its current source owner. Dated runtime reports and proof ledgers are snapshots, not current architecture contracts. If source and a guide disagree, trace current code and flag the discrepancy before changing either.
