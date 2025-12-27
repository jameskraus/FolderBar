# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

Local plans belong in the `plans/` folder, which is gitignored.
Current plan: `plans/DEVELOPMENT_PLAN.md`.
Agents should skim that plan for the overall project goal and current direction.

## Parallel Agents

Multiple agents may be active in this repo at the same time. You must only commit your own work, and you should be deliberate about staging so you don't pick up other agents' changes.

Guidelines:
- Use `git status -sb` and `git diff` to review exactly what you are about to stage.
- Prefer `git add <paths>` over `git add .` so you stage only your files.
- If you see unrelated changes (including untracked files), leave them alone and ask before touching.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## Build Requirement

After any material app change, rebuild and relaunch the app:

```bash
./Scripts/compile_and_run.sh
```

## Release Process

FolderBar releases are automated via `./Scripts/release.sh` (builds, signs, notarizes, creates GitHub release + tag, and updates `appcast.xml`).

1. Ensure `main` is clean and up to date:
   ```bash
   git checkout main
   git pull --rebase
   git status  # must be clean
   ```
2. Draft user-facing release notes from commits since the last release:
   ```bash
   last_tag="$(git describe --tags --abbrev=0)"
   git log --oneline "$last_tag..HEAD"
   ```
   Turn this into a short `RELEASE_NOTES` string focused on product changes (ignore refactors, formatting, internal tooling unless it affects users).
3. Bump the version in `version.env` (the scripts read `VERSION=` from here), commit, and push.
4. Run the release script with your notes:
   ```bash
   RELEASE_NOTES="..." ./Scripts/release.sh
   ```
5. Verify results:
   - `git status` is clean and `main` is up to date with origin
   - tag `vX.Y.Z` exists and is pushed
   - `appcast.xml` has the new entry and was committed

Build-only (no tag/GitHub/appcast changes):
```bash
SKIP_PUBLISH=1 ./Scripts/release.sh
```

## Testing Philosophy

Prefer fast, deterministic unit tests over UI automation. Keep domain logic in importable modules, and add “seams” (protocols/DI for time, I/O, and system APIs) so tests don’t touch the filesystem/UI unless necessary. Add a small number of integration/smoke tests for critical paths, but avoid flaky timing-dependent tests in CI.

## Bead Close Notes

When closing a bead, add brief implementation notes to the issue (what changed, any deviations, and follow-ups).

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

### QA sign-off gate (when requested)

If the user requests QA/sign-off before commits or pushing:
- Do not update beads, commit, or push until the user explicitly confirms QA.
- Keep changes local and provide `git diff`/paths so the user can review.
- After sign-off, proceed with the normal “Landing the Plane” checklist.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds

---

<!-- bv-agent-instructions-v1 -->

---

## Beads Workflow Integration

This project uses [beads_viewer](https://github.com/Dicklesworthstone/beads_viewer) for issue tracking. Issues are stored in `.beads/` and tracked in git.

### Essential Commands

```bash
# View issues (launches TUI - avoid in automated sessions)
bv

# CLI commands for agents (use these instead)
bd ready              # Show issues ready to work (no blockers)
bd list --status=open # All open issues
bd show <id>          # Full issue details with dependencies
bd create --title="..." --type=task --priority=2
bd update <id> --status=in_progress
bd close <id> --reason="Completed"
bd close <id1> <id2>  # Close multiple issues at once
bd sync               # Commit and push changes
```

### Workflow Pattern

1. **Start**: Run `bd ready` to find actionable work
2. **Claim**: Use `bd update <id> --status=in_progress`
3. **Work**: Implement the task
4. **Complete**: Use `bd close <id>`
5. **Sync**: Always run `bd sync` at session end

### Key Concepts

- **Dependencies**: Issues can block other issues. `bd ready` shows only unblocked work.
- **Priority**: P0=critical, P1=high, P2=medium, P3=low, P4=backlog (use numbers, not words)
- **Types**: task, bug, feature, epic, question, docs
- **Blocking**: `bd dep add <issue> <depends-on>` to add dependencies

### Session Protocol

**Before ending any session, run this checklist:**

```bash
git status              # Check what changed
git add <files>         # Stage code changes
bd sync                 # Commit beads changes
git commit -m "..."     # Commit code
bd sync                 # Commit any new beads changes
git push                # Push to remote
```

### Best Practices

- Check `bd ready` at session start to find available work
- Update status as you work (in_progress → closed)
- Create new issues with `bd create` when you discover tasks
- Use descriptive titles and set appropriate priority/type
- Always `bd sync` before ending session

<!-- end-bv-agent-instructions -->
