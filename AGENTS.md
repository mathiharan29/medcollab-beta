# Vocle regression workspace rules

- Latest user instruction, 3 November 2026: work only in **Vocle repo**, `mathiharan29/medcollab-beta`. Commit the manual-workflow fix together with the extra regression cases on the same temporary branch in that repository. This supersedes earlier fork-only/read-only delivery restrictions.
- Verified Vocle `master`: `4c01dc24247aa95a73e286a2b42c7f2f81257c7a`; the repository owner has made `master` the default branch.
- This isolated checkout's only remote is `origin`, pointing to `https://github.com/mathiharan29/medcollab-beta.git`. Do not use or push the former fork. Historical execution records retain their actual repository identities and SHAs; do not relabel them.
- Push only `temp/needl-functional-regression-20261103` in Vocle repo. Do not push or merge into `master`, deploy, change repository settings, or open a PR without a further user request.
- Preserve the user's original checkout, its branch/remotes and uncommitted/untracked Flutter, Android and documentation work. Make changes in this isolated checkout.
- Preserve the original 187 catalog IDs, assertions, and all 48 retained sanity cases. Append source-grounded cases; update validators, coverage accounting and reports so new cases cannot silently be omitted.
- Do not modify application functional/security behavior to make tests pass. Preserve genuine FAIL, ERROR, BLOCKED and NEEDS_DECISION outcomes. Do not infer product approval from implementation behavior.
- All execution uses disposable loopback MongoDB, test-owned HTTP/socket/provider/platform fakes and synthetic data. Never access production MongoDB/Atlas, real Cloudinary, Firebase, MSG91, real users or patient data.
- Record exact source/harness revisions, working-tree provenance where applicable, execution commands, cleanup, outcomes and remaining limitations in `docs/VOCLE_NEEDL_REGRESSION_PROGRESS.md`.
