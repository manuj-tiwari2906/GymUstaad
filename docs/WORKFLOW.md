# How work flows in this repo

```
main (always working, protected)
 ├── chore/ci-and-ai-review   → PR → CI + Claude review → merge
 ├── feat/rule-engine-core    → PR → CI + Claude review → merge
 └── feat/<next-module>       → ...
```

1. Every module or feature gets its own branch from an up-to-date `main`.
2. Push the branch and open a PR.
3. Two automatic checks run on the PR:
   - **CI** (`.github/workflows/ci.yml`): ruff lint + pytest for the rule engine, and all SQL migrations applied to a fresh Postgres with an RLS check. Catches broken code.
   - **Claude review** (`.github/workflows/claude-review.yml`): reads `CLAUDE.md` + `docs/REVIEW.md` and comments on real problems in the diff. Catches wrong numbers, missing tests, privacy/safety slips.
4. You read the review, fix (new commits re-run both checks), then merge.
5. `main` is protected: no direct pushes, merge only through a PR with green CI.

Optional extra layer before pushing: in Claude Code, run `/code-review` on the branch for a local review.

## Branch names

| Prefix | For | Example |
|---|---|---|
| `feat/` | a module or user-facing feature | `feat/rule-engine-core`, `feat/food-logging` |
| `fix/` | a bug fix | `fix/oil-clamp` |
| `chore/` | tooling, CI, docs, deps | `chore/ci-and-ai-review` |
| `data/` | food DB / knowledge cards content | `data/ifct-priority-1` |

## Command reference

| Command | What it does |
|---|---|
| `git switch main` | Go to the main branch |
| `git pull` | Bring your local main up to date with GitHub |
| `git switch -c feat/x` | Create a new branch `feat/x` from where you are, and move to it |
| `git status` | Show what changed and what is staged |
| `git add <paths>` | Stage only these files for the next commit (avoid `git add .` on mixed work) |
| `git diff --staged` | Review exactly what will be committed |
| `git commit -m "..."` | Save the staged changes as one commit on this branch |
| `git push -u origin feat/x` | Upload the branch to GitHub; `-u` remembers the link so later just `git push` |
| `gh pr create --fill` | Open a PR from this branch to main, using commit messages as title/body |
| `gh pr checks --watch` | Watch CI + Claude review run live |
| `gh pr view --comments` | Read the PR, including Claude's review comments |
| `gh pr merge --squash --delete-branch` | Merge the PR as one commit and delete the branch |
