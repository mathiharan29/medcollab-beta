# Vocle Developer Remediation Report

## 1. Executive summary

Validation date: **6 October 2026, Asia/Calcutta (IST)**. This is the final execution and remediation handoff for existing suites, not a new discovery campaign. Application source was not modified. Only the fork `Sriram4747/medcollab-beta-workflows` was written, through `origin/master`; upstream was fetched/inspected read-only. Production MongoDB/Atlas, Cloudinary, Railway, Firebase, MSG91 and real users/phone numbers were not accessed.

**GREEN WORKFLOW != NO APPLICATION FINDINGS.** Discovery lanes block infrastructure, safety, fixture, execution and cleanup errors while retaining unmet application expectations as observations. Functional sanity genuinely gates its named scenarios and therefore remains red.

Six current hosted workflows were executed, plus a corrected broad-security rerun and the automatic secret scan of its repair commit. Their infrastructure is healthy. The final security execution union covers **all 816 registered VOCLE IDs: 696 passes and 120 unique observed IDs**. Across the four security lanes there are **853 case executions (724 passes / 129 observations)** because the offline media lane repeats 37 general-suite cases, including nine observations. Functional sanity has **48 planned scenarios: 44 executed, 42 passes, two genuine failures and four dependency-blocked scenarios**. There are 864 distinct registered security/scenario IDs, 860 actually executed; do not count blocked scenarios as passes or duplicate executions as new coverage. Secret scans are whole-history scans, outside this testcase denominator.

The developer queue contains **24 confirmed application root-cause defects**: **17 security/integrity roots**, **five functional media/provider contract roots**, and **two upstream functional sanity roots**. There are **three likely/review groups**, **18 hardening recommendations** (two are explicitly source-only recommendations retained from prior review), **13 policy decisions**, and **three manual/account-owner workstreams**. Functional/provider defects are not all security vulnerabilities. S3/S5/N2 are grouped as one omitted-channel-authorization issue; S9/R2 are grouped as one stale-room reconciliation issue. No CRITICAL severity is assigned without additional deployed-impact evidence.

### Tested source and provenance

- Initial fork harness/application source: `4eb4c2a57bb0f47bb771321a44c2a283e546ef3e` (five security/scan lanes and sanity harness).
- Corrected broad-suite source: `cac620eef477addda94e6756e36f6aebecc374ab`; only two test files changed. It executed 613 passes/78 observations. Other security lanes are from the initial SHA; their tested backend `src` is identical to the repair SHA. They are not silently relabeled as reruns of that commit.
- Functional sanity target: upstream `master` **`4638682c0c930fcde3378d7e809612b6c0eab370`**, fetched without credentials and executed detached/read-only. Its harness SHA is `4eb4c2a57bb0f47bb771321a44c2a283e546ef3e`. The workflow `head_sha` is not the tested application SHA.
- Sanity target tree: `e7ed2a3d6e8b475b1a926a5352980453ee4818ec`; backend lockfile SHA-256: `008a57f3ae807a74f0f44d0c8b5612ab9c1785fba53535b60839244ddd9c1fe9`. Before/after target verification matches.
- Offline media and MongoDB source fingerprint before/after: `5b79b2a621d639303c5201cb43de5dc8ff0c8a3df19866912ff176374eb32df5`. Their actual report/source hashes are retained in execution metadata.

**These runs do not constitute one release candidate.** Seven backend source files already differ between tested upstream and fork, including pre-existing fork fixes `72eaee4` (MessageRequest notifications) and `8a3c8f4` (atomic DM creation). This task did not apply those application fixes. Upstream still fails the two sanity paths; the fork's passing security checks cannot waive them for an upstream release. Conversely, source-correlated fork security issues need developer verification on the intended application revision.

## 2. Final workflow validation matrix

### Inventory selected before dispatch

| Workflow/lane | Category | Decision |
| --- | --- | --- |
| Secret Scan, `secrets-scan.yml` | Secret scanning | Run; master push/PR plus manual dispatch |
| Vocle Backend Environment Test, `vocle-backend-environment-test.yml` | Active broad backend/security validation | Run; despite legacy name it executes 691 cases, auth/config/realtime coverage and report generation |
| Vocle Functional Sanity, `vocle-sanity.yml` | Functional sanity/regression | Force full manual run; exact upstream source, separate fork harness; daily schedule currently absent |
| Vocle Offline Media Security, `vocle-media-security.yml` | Local/offline media security plus SDK contract | Run 97 cases, including 34 separate contract cases 718–751 inside this lane |
| Vocle Real Cloudinary Security, `vocle-cloudinary-security.yml` | Approved isolated real-provider integration | Run 34 synthetic cases; existing positive TEST allowlist/guard/broker/janitor unchanged |
| Vocle MongoDB Data Security, `vocle-data-security.yml` | Disposable MongoDB/data validation | Run 31 HTTP/model/index/handler cases; no Atlas access |
| Vocle Security Environment Test, `vocle-security-environment-test.yml` | Obsolete environment-only/diagnostic | Not dispatched: package-import/Docker smoke adds no current application validation |

Cloudinary contract coverage is not an additional 34 cases outside offline media. There is no separate maintained backend unit/dependency/security gate or mobile-device workflow to credit here. Old documentation counts/design stages are historical, not extra workflows.

| Workflow / purpose | Run ID/link | Tested source SHA | Cases | Passes | Observations | Genuine failures / blocked | Infrastructure / start→end | Notes |
| --- | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| Secret Scan | [37361849823](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361849823) | `4eb4c2a57bb0f47bb771321a44c2a283e546ef3e` | — | — | — | 0 / 0 | Healthy; dispatched→SUCCESS | History scan; zero SARIF findings; not a count of VOCLE cases. |
| Vocle Backend Environment Test | [37361855710](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361855710) | `4eb4c2a57bb0f47bb771321a44c2a283e546ef3e` | 691 | 611 | 80 | 0 / 0 | Healthy; dispatched→SUCCESS | Initial baseline reproduced;171/355 are resolved harness artifacts. |
| Vocle Offline Media Security | [37361859575](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361859575) | `4eb4c2a57bb0f47bb771321a44c2a283e546ef3e` | 97 | 62 | 35 | 0 / 0 | Healthy; dispatched→SUCCESS | 97/97 exact cleanup; simulated SDK; zero external routes. |
| Vocle MongoDB Data Security | [37361864154](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361864154) | `4eb4c2a57bb0f47bb771321a44c2a283e546ef3e` | 31 | 22 | 9 | 0 / 0 | Healthy; dispatched→SUCCESS | 31/31 exact cleanups, zero residue; disposable TTL sweep paused only. |
| Vocle Functional Sanity | [37361869623](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361869623) | `4638682c0c930fcde3378d7e809612b6c0eab370` | 48 planned / 44 executed | 42 | 0 | 2 / 4 | Healthy; dispatched→FAILURE | Harness 4eb4c2a57bb0f47bb771321a44c2a283e546ef3e; failure is application behavior; success manifest correctly not published. |
| Vocle Real Cloudinary Security | [37361873736](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361873736) | `4eb4c2a57bb0f47bb771321a44c2a283e546ef3e` | 34 | 27 | 7 | 0 / 0 | Healthy; dispatched→SUCCESS | 13/13 origin absences in both cleanup passes; seven observations; raw/image cache probes now 404. |
| Vocle Backend Environment Test — harness repair rerun | [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669) | `cac620eef477addda94e6756e36f6aebecc374ab` | 691 | 613 | 78 | 0 / 0 | Healthy; dispatched→SUCCESS | Final broad validation; only 171/355 changed to pass. |
| Secret Scan — automatic repair-commit scan | [37362255522](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362255522) | `cac620eef477addda94e6756e36f6aebecc374ab` | — | — | — | 0 / 0 | Healthy; push→SUCCESS | History scan; zero SARIF findings; not a count of VOCLE cases. |

Counts exclude setup/self-tests and obsolete smoke diagnostics. No security cases skipped/unexecuted; sanity dependency blocks are listed explicitly. The original security 80→final 78 change is entirely harness classification, not remediation of application behavior. Real-provider 9→7 changes are two cache characterizations, not PDF/application fixes.

### Execution timestamps and artifacts

UTC timestamps below are API/job metadata (validation date above is IST). Every run was attempt 1. `execution.json` records workflow file, tested/harness SHA, job/step outcomes, artifact identity and SHA-256 of each retained file. Archives were independently downloaded and their hashes match GitHub's artifact digest.

| Run | Start UTC | End UTC | Artifact ID/name | Archive SHA-256 | Retained execution |
| --- | --- | --- | --- | --- | --- |
| 37361849823 | 2026-10-05T19:13:28Z | 2026-10-05T19:13:46Z | 11367002472 / gitleaks-results.sarif | `65252f5b0cd3987ab4ff6e6a3e5ce6948f5eaed1cc5633e1270ace0cbd6b0fd8` | [37361849823/execution.json](security-evidence/37361849823/execution.json) |
| 37361855710 | 2026-10-05T19:13:31Z | 2026-10-05T19:23:32Z | 11367536664 / vocle-security-discovery | `f3b874404ebd0d1138369570f7b9b5cc91f4919a9c28c423eb0c67c574bbacc8` | [37361855710/execution.json](security-evidence/37361855710/execution.json) |
| 37361859575 | 2026-10-05T19:13:33Z | 2026-10-05T19:16:51Z | 11367401455 / vocle-offline-media-security | `5a7a7472070d6f6f55ac05172d9ff7c2995aa9912af5a3572d85486d3bb5b554` | [37361859575/execution.json](security-evidence/37361859575/execution.json) |
| 37361864154 | 2026-10-05T19:13:35Z | 2026-10-05T19:14:53Z | 11367142202 / vocle-mongodb-data-security | `5552f27df7751b5cfe19bb0b152786f04c8c177acaf3b3f836e3eee3d9c6fe5d` | [37361864154/execution.json](security-evidence/37361864154/execution.json) |
| 37361869623 | 2026-10-05T19:13:38Z | 2026-10-05T19:16:35Z | 11367496175 / vocle-sanity-diagnostics-37361869623-1 | `0c5a708755ded3ded6e10dd39bec3967603dcb1ae92460f4d2156daf4b59381c` | [37361869623/execution.json](security-evidence/37361869623/execution.json) |
| 37361873736 | 2026-10-05T19:13:40Z | 2026-10-05T19:14:38Z | 11367315867 / vocle-real-cloudinary-security | `c214e99f52840915333eba71229368bd79ed73a6e3b48f273581c429f348e24b` | [37361873736/execution.json](security-evidence/37361873736/execution.json) |
| 37362263669 | 2026-10-05T19:16:47Z | 2026-10-05T19:26:16Z | 11367093060 / vocle-security-discovery | `7f289be0943064c5395efd1d76a20c61d4c07f74c5cd924476c56e1dc630b8ca` | [37362263669/execution.json](security-evidence/37362263669/execution.json) |
| 37362255522 | 2026-10-05T19:16:42Z | 2026-10-05T19:17:19Z | 11367247007 / gitleaks-results.sarif | `4d9a24d801de8cb3de8aa3d8bfc49ae121a7f07ba388bea07b7f2155971cd12e` | [37362255522/execution.json](security-evidence/37362255522/execution.json) |

Security raw `results.json`, summaries, detailed reports, manifests where produced, and new `reviewed-observations.json` are retained unchanged or separately labeled as reviews. Sanity JSON/JUnit/Markdown and provenance are retained; a narrowly sanitized diagnostics file records enum/upsert errors. Raw sanity backend logs are not committed. JUnit represents four blocked scenarios as failures too, hence six JUnit failure nodes versus two actual failed scenario executions. Secret SARIF is retained at its original archive path.

### VR-INFRA-01 — repaired test harness, not application defects

Commit `cac620eef477addda94e6756e36f6aebecc374ab` changes only `scripts/security/suites/direct-messages.js` and `phase0-repairs.js`. VOCLE-171 incorrectly required `persisted.isSelfNotes`, but the controller derives it in `enrichDM` and the model does not store that field. It now checks the response flag and exact persisted caller-only membership/creator/null space, stable replay ID, outsider 403 and one active self-notes channel. VOCLE-355 counted the seeded archived E/G DM as an opened conversation; its denial invariant now checks zero active DM channels while exact request/pair counts and full unchanged-state 403 assertions remain. No allowed/denied status changed, no frozen manifest/ID changed, and no application authorization expectation was relaxed. Local syntax and frozen 691/626 manifest passed; hosted 37362263669 confirms 171/355 pass, with all other statuses/outcomes identical to 37361855710. Repair push Secret Scan 37362255522 is green/zero findings.

Local guard/manifest self-checks passed for all security lanes. Cloudinary safety self-test passed 49 checks; the real-SDK offline transport roundtrip passed 85 intercepted requests with zero network I/O. A Windows sandbox temporary-directory rename error was eliminated by setting TMP/TEMP to an approved workspace scratch path; hosted transport checks already pass. Two dormant Jest-style helper files were briefly probed with Node's native runner and stopped at `describe is not defined` before any named testcase executed. This is an unconfigured legacy runner diagnostic, not an application result or an active workflow failure; no new unit coverage is credited and `npm test` remains a placeholder.

## 3. Priority remediation queue

Priority is recommended developer order, not activation of a CI gate or a release authorization. Severity uses demonstrated impact and bounded proof; policy-dependent items remain separately labeled.

| Priority | Issues / theme | Why / dependency |
| --- | --- | --- |
| P0 — immediate/blocking review | [VR-AUTH-WIDGET](#vr-auth-widget) | Public identity assertion accepts fabricated tokens. Review as a release blocker for any configured exposed instance before relying on resource authorization. No production attack is claimed. |
| P1 — high priority | VR-S8, VR-S4, VR-N1-NEEDL-ACCESS, VR-N3-MENTION-AUDIENCE, VR-S9, VR-R1-ACTIVE-SOCKET, VR-R5-RECOVERY-AUTH | Private previews/full events and revoked/recovered access cross demonstrated boundaries; shared resource/audience checks precede lifecycle repair. |
| P1 — high priority | VR-S1, VR-S6, VR-A1-OTP-CONSUMPTION, VR-R4-SOCKET-CRASH | Foreign reference writes, exact cross-owner deletion, concurrent OTP reuse and authenticated process exit. |
| P1 — functional release flow | VR-FUNC-01, VR-FUNC-02 on upstream | Request notification and acceptance journeys fail; four dependent scenarios cannot run. Verify the intended release SHA and pre-existing fork fixes. |
| P2 — normal remediation | VR-S3 (grouped S3/S5/N2), VR-S2, VR-S7, VR-R3-TYPING-CACHE, VR-DATA-DELETED-EDIT | Metadata/private-pin integrity, handoff containment, unauthorized/stale typing and deleted text restoration. |
| P2 — functional media | Five confirmed roots in section 6 | Correct octet dispatch, typed deletion, video admission, PDF download and PDF preview before declaring end-to-end media support. |
| P3 — hardening/policy/follow-up | Three review groups; section 11's 31 hardening/policy groups; section 15 owner workstreams | Confirm lifecycle/consent/retention requirements, implement scoped hardening and obtain account attestations. Do not inflate policy questions into vulnerabilities. |

## 4. Detailed confirmed findings

The following **17 security/integrity root groups** consolidate multiple cases and legacy registry roots. Their individual source functions and expected boundaries are listed so a coding agent can begin remediation. Status discrepancies alone do not establish disclosure: the current per-case evidence retains canaries, control flags, state changes or process-exit proof as applicable.

<a id="vr-auth-widget"></a>

### VR-AUTH-WIDGET — Unverified widget payload establishes application identity

**Classification:** CONFIRMED DEFECT. **Severity:** HIGH. **Affected feature/boundary:** POST /api/auth/verify-msg91-token.

**Testcase IDs:** VOCLE-356, VOCLE-357. Original registry roots: AUTH_WIDGET.

**Observed behavior:** The Phase 1 dummy-key/outbound-disabled widget cases still issue sessions from fabricated unsigned/expired token shapes. Source locally decodes phone without signature verification.

**Expected secure/correct behavior:** Fabricated unsigned and expired widget tokens must not authenticate a subject or create usable application credentials.

**Source trace and likely root cause:** `verifyWidgetAccessToken` — [medcollab-backend/src/services/msg91Widget.service.js:148](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/services/msg91Widget.service.js#L148); `verifyMsg91Token` — [medcollab-backend/src/features/auth/auth.controller.js:98](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/auth/auth.controller.js#L98); `verify-msg91-token` — [medcollab-backend/src/features/auth/auth.routes.js:66](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/auth/auth.routes.js#L66). The widget service decodes a phone from a JWT-shaped token and returns success before its provider verification branch. A nonempty key is checked, but signature, issuer, audience and expiry are not checked on this fast path. The controller subsequently issues application credentials.

**Impact and severity rationale:** Unauthenticated identity impersonation is demonstrated against synthetic accounts with a dummy key and outbound traffic disabled. A configured deployed route could permit account takeover; deployment exposure and real-account compromise were not tested. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Remove identity trust in client decoding. Use the provider verification contract or a correctly configured trusted cryptographic verifier; bind the verified subject to the requested phone and validate freshness. Audit token issuance only after successful verification.

**Constraints to preserve / what not to change:** Keep request validation, rate limiting, phone normalization, inactive-user rejection and protected-profile controls. Do not substitute JWT decode for verification or accept an identity merely because the client claims it verified it. Keep MSG91 production disabled in tests.

**Regression verification and gate status:** Rerun VOCLE-356, VOCLE-357 plus their successful controls. Existing after-fix candidates: VOCLE-356, VOCLE-357; none active. Review/version the secure oracle before promotion.

**Dependencies/interactions:** Fix first: authenticated resource checks cannot compensate for forged login identity. Ordinary OTP consumption is a separate root.

<a id="vr-s1"></a>

### VR-S1 — Foreign thread parent is accepted and updated

**Classification:** CONFIRMED DEFECT. **Severity:** HIGH. **Affected feature/boundary:** POST /api/channels/:channelId/messages and POST /api/channels/:channelId/messages/:id/reply.

**Testcase IDs:** VOCLE-094, VOCLE-098, VOCLE-193, VOCLE-197, VOCLE-275, VOCLE-276. Original registry roots: S1.

**Observed behavior:** Foreign thread accepted without parent/channel authorization; persisted foreign binding and parent counter independently proven by 275/276.

**Expected secure/correct behavior:** Resolve a live parent in the authorized destination channel before creating a reply; foreign parents, counters and previews must remain unchanged.

**Source trace and likely root cause:** `sendMessage` — [medcollab-backend/src/features/messages/message.controller.js:78](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/messages/message.controller.js#L78); `replyToThread` — [medcollab-backend/src/features/messages/message.controller.js:296](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/messages/message.controller.js#L296); `getThread` — [medcollab-backend/src/features/messages/message.controller.js:256](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/messages/message.controller.js#L256); `assertMessageInChannel` — [medcollab-backend/src/utils/channelAccess.js:76](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/utils/channelAccess.js#L76). replyToThread assigns URL id to body.threadId; sendMessage authorizes only the destination channel, persists that threadId and asynchronously updates the foreign parent by ID. Mongoose refs do not enforce channel containment. getThread also queries children by threadId without a channel predicate.

**Impact and severity rationale:** Cross-context persisted child binding and foreign reply bookkeeping are proven. Additional mixed-thread disclosure is a source-supported investigation lead, not a separately executed disclosure. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Bind thread-parent lookup and every parent update to the authorized channel, validate permitted parent/deleted state, and scope thread retrieval to the same channel. Apply the same rule to direct body.threadId and reply routes.

**Constraints to preserve / what not to change:** Preserve replyToId quote containment (which already passes), sender derivation, normal threads, DM/group access, counters and legitimate pagination. Do not remove the denial oracle or allow foreign IDs to satisfy it.

**Regression verification and gate status:** Rerun VOCLE-094, VOCLE-098, VOCLE-193, VOCLE-197, VOCLE-275, VOCLE-276 plus their successful controls. Existing after-fix candidates: VOCLE-094, VOCLE-098, VOCLE-193, VOCLE-197, VOCLE-275, VOCLE-276; none active. Review/version the secure oracle before promotion.

**Dependencies/interactions:** Coordinate shared channel authorization, deleted-state checks and Needl selection; quote snapshots are a different retention issue.

<a id="vr-s2"></a>

### VR-S2 — Handoff channel reference is not bound to its space

**Classification:** CONFIRMED DEFECT. **Severity:** MEDIUM. **Affected feature/boundary:** POST /api/handoffs.

**Testcase IDs:** VOCLE-099. Original registry roots: S2.

**Observed behavior:** Handoff persists channelId without checking its space or caller access; downstream delivery not established.

**Expected secure/correct behavior:** A handoff channel must exist in the authorized handoff space and satisfy the intended caller access requirement.

**Source trace and likely root cause:** `createHandoff` — [medcollab-backend/src/features/handoffs/handoff.controller.js:56](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/handoffs/handoff.controller.js#L56); `channelId` — [medcollab-backend/src/features/handoffs/handoff.model.js:130](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/handoffs/handoff.model.js#L130); `validateCreateHandoff` — [medcollab-backend/src/middleware/validate.js:178](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/middleware/validate.js#L178). createHandoff validates sender/recipient membership in the supplied space, but persists channelId without loading the channel and checking its space/access. Independent ObjectId refs provide no relational check.

**Impact and severity rationale:** Invalid cross-space association is demonstrated; foreign-channel delivery is not. The system-message helper is defined but is not called by the observed submit/acknowledge paths. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Resolve channel plus space before creation and reject invalid associations without persisting a draft. Define whether private-channel access is needed for the handoff participants.

**Constraints to preserve / what not to change:** Preserve participant identity, owner/admin distinctions, valid drafts, atomic submit/acknowledge behavior and the separate audit-view policy. Do not assume an ObjectId validator verifies ownership.

**Regression verification and gate status:** Rerun VOCLE-099 plus their successful controls. Existing after-fix candidates: VOCLE-099; none active. Review/version the secure oracle before promotion.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-s3"></a>

### VR-S3 — Channel detail, member-list and pin routes omit canonical access checks

**Classification:** CONFIRMED DEFECT. **Severity:** MEDIUM. **Affected feature/boundary:** GET /api/channels/:id; GET /api/channels/:id/members; POST /api/channels/:id/pin/:messageId; DELETE /api/channels/:id/pin/:messageId.

**Testcase IDs:** VOCLE-159, VOCLE-272, VOCLE-273, VOCLE-594, VOCLE-595. Original registry roots: S3, S5, N2_PRIVATE_PIN.

**Observed behavior:** getChannelMembers returns channel member metadata without caller membership authorization. Exact response identity capture is a follow-up. Private channel detail checks space membership but omits private member/admin guard. An excluded ordinary same-space member pins/unpins a private message. Handlers check space membership but omit isPrivate/channel membership; independent owner pin persistence and unpin controls pass.

**Expected secure/correct behavior:** Before returning channel metadata or changing pins, require current DM participation or private membership/authorized administration and current parent-space access.

**Source trace and likely root cause:** `getChannelById` — [medcollab-backend/src/features/channels/channel.controller.js:67](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/channels/channel.controller.js#L67); `getChannelMembers` — [medcollab-backend/src/features/channels/channel.controller.js:374](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/channels/channel.controller.js#L374); `pinMessage` — [medcollab-backend/src/features/channels/channel.controller.js:404](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/channels/channel.controller.js#L404); `unpinMessage` — [medcollab-backend/src/features/channels/channel.controller.js:451](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/channels/channel.controller.js#L451); `canAccessChannel` — [medcollab-backend/src/utils/channelAccess.js:55](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/utils/channelAccess.js#L55). These handlers implement separate incomplete authorization: detail and pins check space membership without the private-channel boundary, while member listing has no resource-access check. Existing message routes use a stronger shared access helper.

**Impact and severity rationale:** Outsider DM member metadata and excluded private-channel detail/member metadata are returned, and an excluded ordinary member mutates private pins. Exact fields/canaries in retained results bound the claim; arbitrary full pinned-body disclosure is not separately claimed. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Centralize the access decision and call it before population/serialization or mutation in all four handlers. Then apply action-specific pin/role requirements and verify the pinned message belongs to the channel.

**Constraints to preserve / what not to change:** Preserve ordinary public channel use, DM membership, space admin exceptions, medical-role versus space-role distinction, message containment and owner pin/replay controls. Do not deny all public profiles or treat same-space membership as private-channel permission.

**Regression verification and gate status:** Rerun VOCLE-159, VOCLE-272, VOCLE-273, VOCLE-594, VOCLE-595 plus their successful controls. Existing after-fix candidates: VOCLE-159, VOCLE-272, VOCLE-273, VOCLE-594, VOCLE-595; none active. Review/version the secure oracle before promotion.

**Dependencies/interactions:** One grouped authorization omission with original registry roots S3/S5/N2 retained for traceability. Archived pin policy is recorded separately.

<a id="vr-s4"></a>

### VR-S4 — Draft handoffs leak through receiver reads and search

**Classification:** CONFIRMED DEFECT. **Severity:** HIGH. **Affected feature/boundary:** GET /api/handoffs?type=received&status=draft; GET /api/handoffs/:id; GET /api/search?type=handoffs.

**Testcase IDs:** VOCLE-267, VOCLE-268, VOCLE-270, VOCLE-271. Original registry roots: S4.

**Observed behavior:** Draft status/participant restriction absent in explicit received filter, receiver detail and member-space search. Ordinary receiver/member can read draft.

**Expected secure/correct behavior:** Ordinary receivers and unrelated space members must not see drafts until submission. Explicit status filters cannot broaden the caller visibility predicate.

**Source trace and likely root cause:** `getMyHandoffs` — [medcollab-backend/src/features/handoffs/handoff.controller.js:84](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/handoffs/handoff.controller.js#L84); `getHandoffById` — [medcollab-backend/src/features/handoffs/handoff.controller.js:133](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/handoffs/handoff.controller.js#L133); `globalSearch` — [medcollab-backend/src/features/search/search.controller.js:46](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/search/search.controller.js#L46); `DRAFT` — [medcollab-backend/src/constants/index.js:79](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/constants/index.js#L79). An explicit received draft filter survives getMyHandoffs. Detail treats receiver status-independent as a participant; search selects handoffs from member spaces without sender/draft/participant visibility constraints. Constants and submit comments establish draft privacy.

**Impact and severity rationale:** Matching synthetic draft canaries and detail responses confirm pre-submission disclosure. Attachment download and production clinical content were not tested. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Create a status-aware handoff visibility predicate and apply it consistently to list, detail and search. Intersect filters with permissions and preserve a separately defined admin audit exception.

**Constraints to preserve / what not to change:** Preserve sender draft editing, valid submitted/acknowledged views, participant notifications and accountable admin audit behavior. Do not fix only the default list while explicit filters/detail/search remain open.

**Regression verification and gate status:** Rerun VOCLE-267, VOCLE-268, VOCLE-270, VOCLE-271 plus their successful controls. Existing after-fix candidates: VOCLE-267, VOCLE-268, VOCLE-270, VOCLE-271; none active. Review/version the secure oracle before promotion.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-s6"></a>

### VR-S6 — Local-media ownership check can be bypassed by canonical traversal

**Classification:** CONFIRMED DEFECT. **Severity:** HIGH. **Affected feature/boundary:** DELETE /api/media/:publicId.

**Testcase IDs:** VOCLE-313, VOCLE-314, VOCLE-704. Original registry roots: S6.

**Observed behavior:** Decoded owner substring passes before path normalization; exact synthetic foreign file is deleted. No outside-upload or Cloudinary exploit executed. Avatar path with caller substring and dot segment resolves to the controlled foreign owner file; HTTP 200 deletes that foreign file. Extends the existing local canonical ownership root S6.

**Expected secure/correct behavior:** The canonical target must remain within the exact permitted owner namespace and upload root; malformed/double-decoded/traversing input must never delete another owner file.

**Source trace and likely root cause:** `deleteFile` — [medcollab-backend/src/features/media/media.controller.js:146](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/media/media.controller.js#L146); `deleteLocalUpload` — [medcollab-backend/src/utils/localMediaStorage.js:58](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/utils/localMediaStorage.js#L58); `deleteFile` — [medcollab-backend/src/features/media/media.routes.js:129](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/media/media.routes.js#L129). Express decoding plus decodeURIComponent and substring owner matching occur before path.join normalizes dot segments. A path containing the caller ownership substring can normalize to a different user file.

**Impact and severity rationale:** Exact synthetic foreign message/avatar files are deleted after independently verified existence. Outside-upload arbitrary filesystem deletion and real Cloudinary cross-user destruction are not demonstrated. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361859575](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361859575), [37361859575/results.json](security-evidence/37361859575/results.json) and [37361859575/reviewed-observations.json](security-evidence/37361859575/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Normalize/decode once under a documented grammar, reject unsafe segments, verify resolved-path containment and exact ownership independently, and prefer an immutable asset record to free-form IDs. Validate canonical provider namespace separately.

**Constraints to preserve / what not to change:** Keep valid owner image/avatar deletion and foreign-owner denials. Do not use substring matching, broaden permitted filesystem roots or claim Cloudinary exploitability from local evidence.

**Regression verification and gate status:** Rerun VOCLE-313, VOCLE-314, VOCLE-704 plus their successful controls. Existing after-fix candidates: VOCLE-313, VOCLE-314, VOCLE-704; none active. Review/version the secure oracle before promotion.

**Dependencies/interactions:** Asset provenance work can unify local and provider ownership, but preserve their distinct proof boundaries.

<a id="vr-s7"></a>

### VR-S7 — Typing events are emitted without channel authorization

**Classification:** CONFIRMED DEFECT. **Severity:** MEDIUM. **Affected feature/boundary:** Socket.IO typing_start and typing_stop.

**Testcase IDs:** VOCLE-339, VOCLE-340, VOCLE-342, VOCLE-343, VOCLE-345, VOCLE-346. Original registry roots: S7.

**Observed behavior:** Typing handler does not authorize channel. Attacker-attributed packets arrive after denied join/read; authorized delivery control passes.

**Expected secure/correct behavior:** An authenticated caller needs current access to the referenced channel before typing is broadcast; unauthorized room and personal-room deliveries must both be absent.

**Source trace and likely root cause:** `registerMessageHandlers` — [medcollab-backend/src/socket/handlers/message.handler.js:48](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/socket/handlers/message.handler.js#L48); `canAccessChannel` — [medcollab-backend/src/utils/channelAccess.js:55](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/utils/channelAccess.js#L55). The join handler checks canAccessChannel; typing handlers do not. They broadcast to caller-selected channel rooms and personal peer rooms even when attacker join/read is denied.

**Impact and severity rationale:** Unauthorized attacker-attributed typing reaches foreign-space, private-channel and DM viewers. Identity spoofing is not demonstrated; the server ignores a forged userId. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Validate payload and resource ID, perform live channel/active-user authorization before either fanout, and derive identity solely from the authenticated socket.

**Constraints to preserve / what not to change:** Keep successful authorized typing_start/stop, server userId attribution and the current typing_stop field contract. Do not introduce a required userName field on stop to hide an unrelated failure.

**Regression verification and gate status:** Rerun VOCLE-339, VOCLE-340, VOCLE-342, VOCLE-343, VOCLE-345, VOCLE-346 plus their successful controls. Existing after-fix candidates: VOCLE-339, VOCLE-340, VOCLE-342, VOCLE-343, VOCLE-345, VOCLE-346; none active. Review/version the secure oracle before promotion.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-s8"></a>

### VR-S8 — Private full-message fanout targets all space members

**Classification:** CONFIRMED DEFECT. **Severity:** HIGH. **Affected feature/boundary:** POST /api/channels/:channelId/messages → new_message personal-room delivery.

**Testcase IDs:** VOCLE-347. Original registry roots: S8.

**Observed behavior:** sendMessage uses all space members for private-message personal-room recipients; exact full canary arrives at excluded B.

**Expected secure/correct behavior:** Full message and ordinary preview notifications may reach only currently authorized channel viewers/participants, including devices outside the open channel room.

**Source trace and likely root cause:** `sendMessage` — [medcollab-backend/src/features/messages/message.controller.js:78](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/messages/message.controller.js#L78); `emitNewMessage` — [medcollab-backend/src/socket/index.js:187](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/socket/index.js#L187); `notifyNewMessage` — [medcollab-backend/src/services/notification.service.js:281](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/services/notification.service.js#L281). sendMessage derives group recipients from space.members without intersecting private-channel permissions; emitNewMessage sends the full persisted payload to each personal room.

**Impact and severity rationale:** An excluded private member receives the exact new-message ID and full synthetic canary despite a REST 403 control. External push impact is source-derived only. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Use a shared authorized-audience resolver for group/private/DM fanout and revalidate lifecycle state before side effects. Audit ordinary inbox/FCM audience using the same policy.

**Constraints to preserve / what not to change:** Preserve open-chat fallback for authorized users, emergency delivery, sender identity, successful persistence and DM audience controls. External FCM delivery is not tested here.

**Regression verification and gate status:** Rerun VOCLE-347 plus their successful controls. Existing after-fix candidates: VOCLE-347; none active. Review/version the secure oracle before promotion.

**Dependencies/interactions:** Shared audience work also addresses mention disclosure; stale channel rooms need the separate revocation fix.

<a id="vr-s9"></a>

### VR-S9 — Revocation and synchronization retain protected channel/space rooms

**Classification:** CONFIRMED DEFECT. **Severity:** HIGH. **Affected feature/boundary:** DELETE /api/spaces/:id/members/:userId; POST /api/spaces/:id/leave; sync_space_rooms; message_updated and presence broadcasts.

**Testcase IDs:** VOCLE-348, VOCLE-349, VOCLE-659, VOCLE-660, VOCLE-662, VOCLE-681. Original registry roots: S9, R2_SPACE_PRESENCE.

**Observed behavior:** Member removal does not evict channel rooms and sync only adds rooms; removed B receives edits despite fresh REST denial. Removed space member receives a subsequent matched presence update. Explicit sync returns zero spaces but only adds rooms and does not leave the old space room. REST denies revoked private-channel or invite/leave membership, yet the existing socket receives a matched protected message edit. Extends the established stale channel-room root.

**Expected secure/correct behavior:** After revocation, all subject devices must lose protected channel edits and space presence delivery, before and after sync; independent DM entitlements must survive.

**Source trace and likely root cause:** `removeMember` — [medcollab-backend/src/features/spaces/space.controller.js:314](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/spaces/space.controller.js#L314); `leaveSpace` — [medcollab-backend/src/features/spaces/space.controller.js:334](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/spaces/space.controller.js#L334); `syncSocketSpaceRooms` — [medcollab-backend/src/socket/spaceRooms.js:47](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/socket/spaceRooms.js#L47); `registerSpaceHandlers` — [medcollab-backend/src/socket/handlers/space.handler.js:14](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/socket/handlers/space.handler.js#L14); `broadcastPresenceUpdate` — [medcollab-backend/src/socket/handlers/presence.handler.js:139](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/socket/handlers/presence.handler.js#L139). Membership mutations do not evict existing sockets. syncSocketSpaceRooms updates space ID arrays and joins current rooms but never leaves obsolete space/channel rooms. Room membership can therefore outlive REST permissions.

**Impact and severity rationale:** Matched protected edit/presence packets reach revoked synthetic users while REST denies and owner/remaining-member controls succeed. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Reconcile room sets by leaving revoked rooms, evict on membership mutation, invalidate related recipient caches and address every active subject socket. Preserve separate DM entitlement and recheck private-channel membership.

**Constraints to preserve / what not to change:** Keep authorized deliveries, fresh reconnect isolation, explicit leave behavior, multi-device presence and the independent DM control. Private membership removal is model-seeded where no API exists; do not invent an endpoint.

**Regression verification and gate status:** Rerun VOCLE-348, VOCLE-349, VOCLE-659, VOCLE-660, VOCLE-662, VOCLE-681 plus their successful controls. Existing after-fix candidates: VOCLE-348, VOCLE-349, VOCLE-659, VOCLE-660, VOCLE-662, VOCLE-681; none active. Review/version the secure oracle before promotion.

**Dependencies/interactions:** Grouped registry roots S9/R2 share stale room reconciliation. Recovery replay bypass and cached personal-room typing remain separate mechanisms.

<a id="vr-n1-needl-access"></a>

### VR-N1-NEEDL-ACCESS — Needl selection bypasses private access and revocation

**Classification:** CONFIRMED DEFECT. **Severity:** HIGH. **Affected feature/boundary:** GET /api/users/me/needl.

**Testcase IDs:** VOCLE-429, VOCLE-434, VOCLE-503, VOCLE-509. Original registry roots: N1_NEEDL_ACCESS.

**Observed behavior:** A same-space caller excluded from the private channel receives its root ID and matching private preview through Needl, despite 403 on message reads and an authorized owner canary. getNeedl selects all channels in active member spaces without private access filtering. After actual leave/removal, a retained private channel.members entry lets Needl return the former space private root even though REST message reads deny 403. The owner Needl canary remains visible.

**Expected secure/correct behavior:** Every Needl root and preview must originate in a channel the caller may currently read; stale membership and same-space membership must not bypass private access.

**Source trace and likely root cause:** `getNeedl` — [medcollab-backend/src/features/users/user.controller.js:270](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/users/user.controller.js#L270); `canAccessChannel` — [medcollab-backend/src/utils/channelAccess.js:55](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/utils/channelAccess.js#L55). getNeedl ORs all channels in active member spaces with any channel containing the caller. The first branch ignores privacy; the second trusts retained membership after space removal.

**Impact and severity rationale:** Exact root IDs and matching private previews survive exclusion/real leave/removal with independent message-read 403 controls. Full thread/attachment download is not separately demonstrated. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Build accessible channel IDs with the canonical live access policy, including current space membership/private roles/archives, before root selection and preview serialization.

**Constraints to preserve / what not to change:** Preserve authorized owner Needl roots, reply participation, valid DM/self-notes access and bounded ordering. Do not mask leaks by removing Needl globally.

**Regression verification and gate status:** Rerun VOCLE-429, VOCLE-434, VOCLE-503, VOCLE-509 plus their successful controls. Existing after-fix candidates: VOCLE-429, VOCLE-434, VOCLE-503, VOCLE-509; none active. Review/version the secure oracle before promotion.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-n3-mention-audience"></a>

### VR-N3-MENTION-AUDIENCE — Mention notifications disclose previews to unauthorized recipients

**Classification:** CONFIRMED DEFECT. **Severity:** HIGH. **Affected feature/boundary:** POST /api/channels/:channelId/messages with mentions → inbox and new_notification.

**Testcase IDs:** VOCLE-603, VOCLE-604, VOCLE-685, VOCLE-686. Original registry roots: N3_MENTION_AUDIENCE.

**Observed behavior:** Explicit mentions create notifications with matching message-preview canaries for a foreign outsider or excluded private member. Authorized recipient controls execute first. notifyMention filters sender/viewers but never channel/space access. A private message mention delivers its matched preview and message reference as new_notification to an unauthorized outsider or excluded space member. Extends the established mention audience root with realtime evidence.

**Expected secure/correct behavior:** Sending a valid message may succeed, but unauthorized recipients must get no persisted preview, reference or socket notification.

**Source trace and likely root cause:** `notifyMention` — [medcollab-backend/src/services/notification.service.js:322](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/services/notification.service.js#L322); `sendNotification` — [medcollab-backend/src/services/notification.service.js:44](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/services/notification.service.js#L44); `sendMessage` — [medcollab-backend/src/features/messages/message.controller.js:78](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/messages/message.controller.js#L78). notifyMention filters only sender and current viewers. Caller-supplied recipient IDs are not intersected with channel/space permissions before notification persistence and personal-room emission.

**Impact and severity rationale:** Matching preview canaries are stored for foreign/private-excluded users and delivered over local sockets. Real Firebase/provider push was disabled. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Resolve recipient access and lifecycle state before storing/emitting previews, deduplicate mention IDs and share audience logic with ordinary message notifications.

**Constraints to preserve / what not to change:** Keep authorized mention positive controls, sender exclusion, preference/emergency behavior and successful message creation. Correct 201 is not sufficient: assert audience and persisted notification absence.

**Regression verification and gate status:** Rerun VOCLE-603, VOCLE-604, VOCLE-685, VOCLE-686 plus their successful controls. Existing after-fix candidates: VOCLE-603, VOCLE-604, VOCLE-685, VOCLE-686; none active. Review/version the secure oracle before promotion.

**Dependencies/interactions:** Coordinate private full-message fanout and inactive-recipient policy; they do not replace the resource audience check.

<a id="vr-r1-active-socket"></a>

### VR-R1-ACTIVE-SOCKET — Established socket retains actions after deactivation

**Classification:** CONFIRMED DEFECT. **Severity:** HIGH. **Affected feature/boundary:** Existing Socket.IO join_channel and availability_update after User.isActive=false.

**Testcase IDs:** VOCLE-654, VOCLE-655. Original registry roots: R1_ACTIVE_SOCKET.

**Observed behavior:** REST and new connections reject the deactivated user, but the established socket can persist availability or acknowledge a protected channel join. Event handlers lack active-user revalidation.

**Expected secure/correct behavior:** Deactivated users must lose protected room joins and persisted availability actions on all established sockets.

**Source trace and likely root cause:** `authenticateSocket` — [medcollab-backend/src/middleware/auth.js:101](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/middleware/auth.js#L101); `registerMessageHandlers` — [medcollab-backend/src/socket/handlers/message.handler.js:48](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/socket/handlers/message.handler.js#L48); `registerPresenceHandlers` — [medcollab-backend/src/socket/handlers/presence.handler.js:38](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/socket/handlers/presence.handler.js#L38). Handshake authentication loads active User once. Established handlers retain socket identity without active-user revalidation, so deactivation affects fresh requests/connections but not existing actions.

**Impact and severity rationale:** Protected join acknowledgement and actual availability DB writes persist after synthetic deactivation. Other event types and production deployment were not exhaustively tested. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Invalidate/disconnect every subject socket on deactivation and apply an efficient live active-session check to protected actions. Define revocation propagation across instances.

**Constraints to preserve / what not to change:** Preserve inactive REST/fresh socket denial and legitimate multi-device actions. Logout currently removes FCM rather than revoking JWTs; changing that is a separate policy decision.

**Regression verification and gate status:** Rerun VOCLE-654, VOCLE-655 plus their successful controls. Existing after-fix candidates: VOCLE-654, VOCLE-655; none active. Review/version the secure oracle before promotion.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-r3-typing-cache"></a>

### VR-R3-TYPING-CACHE — Cached typing peers survive DM membership removal

**Classification:** CONFIRMED DEFECT. **Severity:** MEDIUM. **Affected feature/boundary:** typing_stop personal-room fallback after participant removal and leave_channel.

**Testcase IDs:** VOCLE-663. Original registry roots: R3_TYPING_CACHE.

**Observed behavior:** After DM participant removal and channel leave, typing_stop still reaches the removed peer through a cached personal-room recipient list. Independent REST denial and active viewer delivery controls hold.

**Expected secure/correct behavior:** Recipient cache must never extend revoked DM access; removed peers receive no typing while remaining authorized viewers still do.

**Source trace and likely root cause:** `peerUserIds` — [medcollab-backend/src/socket/handlers/message.handler.js:31](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/socket/handlers/message.handler.js#L31). typingMembers caches IDs for 60 seconds and lacks invalidation/live recipient checks. A removed peer can receive personal-room typing after leaving the channel room.

**Impact and severity rationale:** Post-removal typing is observed within the cache lifetime. Long-duration eviction/load/multi-instance behavior is untested. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Invalidate on membership changes and validate cached recipients against current entitlement or use a versioned authorized audience. Cover both typing_start and typing_stop.

**Constraints to preserve / what not to change:** Keep personal-room-only warmup proof, positive viewer delivery, REST denial and fresh supervised cache isolation. Waiting for cache expiry is not revocation enforcement.

**Regression verification and gate status:** Rerun VOCLE-663 plus their successful controls. Existing after-fix candidates: VOCLE-663; none active. Review/version the secure oracle before promotion.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-r4-socket-crash"></a>

### VR-R4-SOCKET-CRASH — Null synchronous socket payload terminates the backend

**Classification:** CONFIRMED DEFECT. **Severity:** HIGH. **Affected feature/boundary:** Socket.IO leave_channel, typing_start and typing_stop with null.

**Testcase IDs:** VOCLE-673, VOCLE-674, VOCLE-675. Original registry roots: R4_SOCKET_CRASH.

**Observed behavior:** An authenticated null leave/typing payload causes an uncaught exception and exit code 1 in the real backend child. Positive pre-trigger controls and explicit exit evidence prove availability loss.

**Expected secure/correct behavior:** Malformed authenticated event payloads must be rejected safely without losing backend health or legitimate event delivery.

**Source trace and likely root cause:** `registerMessageHandlers` — [medcollab-backend/src/socket/handlers/message.handler.js:48](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/socket/handlers/message.handler.js#L48); `uncaughtException` — [medcollab-backend/src/server.js:164](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/server.js#L164). Synchronous listener signatures destructure incoming payloads before any validation/try-catch. Null throws an uncaught exception; the actual supervised child exits 1.

**Impact and severity rationale:** A single authenticated malformed packet kills the real test-mode backend child. Production exposure is not executed, but the synchronous handler mechanism is source-confirmed. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Validate payload object/type/ID before destructuring, return a bounded error and contain asynchronous work consistently. Keep unexpected server failures observable rather than suppressing all exceptions.

**Constraints to preserve / what not to change:** Keep authenticated positive pre-trigger controls and explicit process health/delivery verification after malformed events. Version crash expectations so fixed behavior does not wait for a failure diagnostic.

**Regression verification and gate status:** Rerun VOCLE-673, VOCLE-674, VOCLE-675 plus their successful controls. Existing after-fix candidates: VOCLE-673, VOCLE-674, VOCLE-675; none active. Review/version the secure oracle before promotion.

**Dependencies/interactions:** Async null rejection cases 672/676 remain hardening; do not inflate them into demonstrated process exits.

<a id="vr-r5-recovery-auth"></a>

### VR-R5-RECOVERY-AUTH — Connection recovery replays protected packets without renewed auth

**Classification:** CONFIRMED DEFECT. **Severity:** HIGH. **Affected feature/boundary:** Socket.IO transport recovery within configured two-minute window.

**Testcase IDs:** VOCLE-678, VOCLE-679, VOCLE-680. Original registry roots: R5_RECOVERY_AUTH.

**Observed behavior:** A transport recovery session replays a protected message edit after membership removal, deactivation or token expiry while independent fresh connection/REST checks deny access. skipMiddlewares restores rooms without revalidating auth.

**Expected secure/correct behavior:** Validate current auth, active account and room entitlement before any recovered protected packet is replayed or room restored.

**Source trace and likely root cause:** `connectionStateRecovery` — [medcollab-backend/src/socket/index.js:83](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/socket/index.js#L83); `initSocket` — [medcollab-backend/src/socket/index.js:54](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/socket/index.js#L54); `authenticateSocket` — [medcollab-backend/src/middleware/auth.js:101](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/middleware/auth.js#L101). connectionStateRecovery.skipMiddlewares=true restores/replays protected rooms without checking current identity validity or resource membership. Recovered connections also skip handler registration; identity/listener restoration needs developer investigation beyond measured replay.

**Impact and severity rationale:** Protected edits replay after space revocation, deactivation and token expiry while independent fresh auth/REST checks deny. Future listener behavior is not fully proven. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Use an auth-aware recovery strategy that prevents unauthorized replay (including buffered packets), restores trusted identity/listeners correctly and falls back to fresh authenticated reconnect where necessary.

**Constraints to preserve / what not to change:** Preserve legitimate recovery positive controls, exact recovered-versus-fresh detection and packet correlation. Do not merely add a post-replay check or disable all reconnect without a product recovery design.

**Regression verification and gate status:** Rerun VOCLE-678, VOCLE-679, VOCLE-680 plus their successful controls. Existing after-fix candidates: VOCLE-678, VOCLE-679, VOCLE-680; none active. Review/version the secure oracle before promotion.

**Dependencies/interactions:** Depends on room revocation and active-session checks; mid-session expiry policy is distinct from admitting an expired recovered session.

<a id="vr-a1-otp-consumption"></a>

### VR-A1-OTP-CONSUMPTION — Concurrent OTP verification consumes one code more than once

**Classification:** CONFIRMED DEFECT. **Severity:** HIGH. **Affected feature/boundary:** POST /api/auth/verify-otp with two overlapping requests.

**Testcase IDs:** VOCLE-687. Original registry roots: A1_OTP_CONSUMPTION.

**Observed behavior:** Two overlapping real verification requests accept the same hashed OTP and each return usable credentials for its synthetic subject; later sequential replay is rejected. OTP verify reads/deletes non-atomically.

**Expected secure/correct behavior:** At most one concurrent request may authorize usable credentials from one OTP; expiry and attempt caps remain enforced.

**Source trace and likely root cause:** `verifyOtp` — [medcollab-backend/src/features/auth/otp.model.js:96](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/auth/otp.model.js#L96); `verifyOtp` — [medcollab-backend/src/services/otp.service.js:133](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/services/otp.service.js#L133); `verifyOtp` — [medcollab-backend/src/features/auth/auth.controller.js:73](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/auth/auth.controller.js#L73). verifyOtp reads an eligible record, saves an incremented attempt counter, compares bcrypt and deletes by ID without requiring a successful atomic claim. Two overlapping reads both return valid even when only one delete consumes the record.

**Impact and severity rationale:** Two overlapping HTTP responses each yield credentials independently accepted at protected profiles. Actual SMS delivery, distinct token values and multiple distinct sessions are not asserted. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** After hash validation, atomically claim/consume an eligible record and require success before issuing credentials; make attempt counting/concurrent replacement semantics safe. Review failure paths and concurrent invalid attempts.

**Constraints to preserve / what not to change:** Preserve bcrypt storage, explicit expiry admission checks independent of TTL, attempt caps, sequential replay denial and protected-profile validation of the one successful credential response. Do not accept two credentials just because generated token strings may match.

**Regression verification and gate status:** Rerun VOCLE-687 plus their successful controls. Existing after-fix candidates: VOCLE-687; none active. Review/version the secure oracle before promotion.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-data-deleted-edit"></a>

### VR-DATA-DELETED-EDIT — Editing a soft-deleted message restores persisted content

**Classification:** CONFIRMED DEFECT. **Severity:** MEDIUM. **Affected feature/boundary:** PUT /api/channels/:channelId/messages/:id after DELETE.

**Testcase IDs:** VOCLE-805. Original registry roots: DATA_DELETED_EDIT.

**Observed behavior:** Own live edit control 200; real deletion 200 blanks stored text. A later real PUT returns 200 and restores synthetic text while isDeleted and deletedAt remain. editMessage lacks a deleted-state check; the save hook runs only when isDeleted changes. Confirmed deletion-integrity defect, not cross-user disclosure or restoration of old media.

**Expected secure/correct behavior:** Deleted messages cannot regain persisted text or produce restored-content update events; authorized edits to live messages must still work.

**Source trace and likely root cause:** `editMessage` — [medcollab-backend/src/features/messages/message.controller.js:305](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/messages/message.controller.js#L305); `isModified('isDeleted')` — [medcollab-backend/src/features/messages/message.model.js:240](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/messages/message.model.js#L240). editMessage has no isDeleted guard. The model blanks content only when isDeleted changes; a later edit saves new text while the deleted flag/date remain unchanged.

**Impact and severity rationale:** Own live edit 200 and deletion 200 controls precede a deleted edit 200 that restores stored synthetic text. No cross-user read or old-media resurrection is claimed. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361864154](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361864154), [37361864154/results.json](security-evidence/37361864154/results.json) and [37361864154/reviewed-observations.json](security-evidence/37361864154/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Reject edits to deleted records and enforce deletion invariants in the write boundary/model where appropriate, including atomic/concurrent transitions. Audit event emission after rejected writes.

**Constraints to preserve / what not to change:** Keep sender/channel ownership, normal live edits, deletion blanking, reactions cleanup and audit timestamps. Quote/channel preview retention is a separate policy issue.

**Regression verification and gate status:** Rerun VOCLE-805 plus their successful controls. Existing after-fix candidates: VOCLE-805; none active. Review/version the secure oracle before promotion.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

## 5. Functional sanity regressions

These are **two actual application failures on upstream `4638682c0c930fcde3378d7e809612b6c0eab370`**, not harness fixes and not extra security observations. All 48 scenario IDs are accounted for. Independent modules continued; startup, provenance, network-none isolation, provider interception, reports/artifact upload and Docker teardown succeeded. The misleading step name “Run isolated startup scenario” wraps the full suite; it does not mean startup failed.

<a id="vr-func-01"></a>

### VR-FUNC-01 — Message-request notification schema rejects its reference type

**Classification:** CONFIRMED DEFECT (functional). **Severity:** MEDIUM, because the recipient request inbox/bell notification is absent while request state persists; no security bypass is claimed. **Scenario:** `message-requests-01`, eligible-peer-request-lists-count-and-notification. **Module:** message requests and notification persistence.

**Expected:** create a request between synthetic eligible A→D, return 201, retain one stable pending request on duplicate, correct sent/received/count views and a recipient notification of type `message_request` with `referenceType=MessageRequest` bound to that request. **Actual:** request creation succeeds and persists; the notification is absent after the bounded five-second persistence poll. Selected sanitized backend diagnostic confirms `MessageRequest` is not a permitted `referenceType` enum value. This is a schema rejection, not a missing external Firebase credential or arbitrary notification latency.

**Source / route:** POST `/api/message-requests` → `createRequest` — [medcollab-backend/src/features/message-requests/messageRequest.controller.js:52](https://github.com/mathiharan29/medcollab-beta/blob/4638682c0c930fcde3378d7e809612b6c0eab370/medcollab-backend/src/features/message-requests/messageRequest.controller.js#L52) → `sendNotification` — [medcollab-backend/src/services/notification.service.js:44](https://github.com/mathiharan29/medcollab-beta/blob/4638682c0c930fcde3378d7e809612b6c0eab370/medcollab-backend/src/services/notification.service.js#L44) → `referenceType` — [medcollab-backend/src/features/notifications/notification.model.js:25](https://github.com/mathiharan29/medcollab-beta/blob/4638682c0c930fcde3378d7e809612b6c0eab370/medcollab-backend/src/features/notifications/notification.model.js#L25). The controller passes `MessageRequest`; the upstream enum allows only Message/Handoff/Space/Channel. `sendNotification` catches the persistence error and returns null, so the primary request still succeeds.

**Reproduce/evidence:** existing `tests/sanity/src/message-requests-and-conversations-scenarios.js`, scenario 01, and its independent DB query `notificationFor(recipientId,requestId)`. [37361869623](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361869623), [37361869623/sanity-report.json](security-evidence/37361869623/sanity-report.json), [37361869623/sanitized-diagnostics.json](security-evidence/37361869623/sanitized-diagnostics.json). No failed mutation was retried until green.

**Remediation / investigation:** align the polymorphic reference enum and request metadata schema with the caller/client deep-link contract; verify accepted-request notifications too. Review the already-existing fork commit `72eaee4` as a remediation reference, not proof it has been deployed/upstreamed. The fork contains MessageRequest reference support and messageRequestId metadata before this task. No source fix was made here.

**Preserve:** owner-bound inbox records, valid reference types, request consent/duplicates, requester identity, strict schemas, no production provider use and explicit failure visibility. Do not remove the DB notification assertion or convert the scenario to pass because the primary 201 succeeded. **Regression:** rerun message-requests-01 and 02 on the corrected target source; keep a persisted reference/type/control check. **Gate:** existing functional sanity scenario is already gating; no security-registry candidate exists for this upstream-specific failure. **Dependency:** independent of the acceptance-upsert failure below; failure of the primary notification should not prevent acceptance investigation.

<a id="vr-func-02"></a>

### VR-FUNC-02 — Request acceptance uses an invalid MongoDB upsert predicate

**Classification:** CONFIRMED DEFECT (functional). **Severity:** MEDIUM; normal request→DM acceptance returns 500 and blocks further collaboration, with partial accepted state source-supported. **Scenario:** `message-requests-02`, accept-request-dm-and-notification. **Module:** request acceptance/direct-channel creation.

**Expected:** recipient D accepts A's existing pending request 200, one stable two-member DM is created/reused, peer/list views and sender notification persist. **Actual:** POST `/api/message-requests/<synthetic-id>/accept` returns 500: MongoDB `findAndModify` cannot infer query fields because path `members` is matched twice. Four dependent scenarios are blocked because no DM fixture was returned. No dependency/image/DB startup failure caused this result.

**Source / root:** `acceptRequest` — [medcollab-backend/src/features/message-requests/messageRequest.controller.js:197](https://github.com/mathiharan29/medcollab-beta/blob/4638682c0c930fcde3378d7e809612b6c0eab370/medcollab-backend/src/features/message-requests/messageRequest.controller.js#L197) saves request.status=accepted before `Channel.findOneAndUpdate` with upsert and `members:{$all:sortedMembers,$size:2}`. MongoDB cannot synthesize an inserted base document from that array predicate. The failure occurs after the earlier status save; direct raw postfailure status was not captured separately by this sanity scenario, so partial-state scope is supported by source sequencing rather than invented new evidence.

**Evidence/reproduction:** scenario 02 follows the successful persisted request from 01 even though its notification assertion failed; submit the acceptance as the exact synthetic recipient with no existing pair DM. [37361869623](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361869623), [37361869623/sanity-report.json](security-evidence/37361869623/sanity-report.json) and sanitized diagnostics. Source links pin upstream, not the fork's already-changed controller.

**Remediation:** use an equality-based canonical pair key with an appropriate unique/partial index and atomic upsert while retaining legacy pair lookup. Review the pre-existing fork commit `8a3c8f4`; confirm safe error/replay handling and which request/DM/notification transitions need atomicity or recoverable partial-state behavior. Investigate concurrent acceptances and already-accepted requests after a failed first attempt. Do not replace the failed action with directly seeded DM fixtures to make the journey pass.

**Preserve:** recipient-only acceptance, terminal-state denial, stable pair identity, archived/legacy/self/group channel distinctions, request consent and owner-bound notifications. **Regression:** rerun message-requests-02 and direct-and-group-conversations-01/02/03/05 against the fixed intended source; keep 01 notification verification independent. **Gate:** these sanity scenarios are already gating, no new security gate automatically activated. **Dependency:** notification enum fix and canonical DM index/migration review.

| Dependency-blocked scenario | What remains unverified in this final upstream run |
| --- | --- |
| direct-and-group-conversations-01 | Accepted DM reopens to the same ID from both sides |
| direct-and-group-conversations-02 | DM send/read, peer detail and sidebar preview |
| direct-and-group-conversations-03 | Read-receipt deduplication and preference |
| direct-and-group-conversations-05 | Expansion with none/all history and unchanged source history |

These are four blocked journeys, not four separately confirmed regressions. Self notes/group rename scenario 04 passes. The remaining 42 scenarios pass but do not establish every security boundary.

## 6. Cloudinary/media findings

The following **five confirmed functional/provider root groups** are current developer defects and included in the confirmed total, without being described as five new vulnerabilities. Live scope is controller plus real SDK/provider under namespace adaptation; it grants no additional route/auth/database coverage. Offline local/SDK evidence and real provider evidence remain distinct.

<a id="vr-media-octet-resource-type"></a>

### VR-MEDIA-OCTET-RESOURCE-TYPE — Octet-stream PDF/video select the wrong Cloudinary type

**Classification:** CONFIRMED DEFECT. **Severity:** MEDIUM. **Affected feature/boundary:** POST /api/media/upload with valid PDF/MP4 and application/octet-stream.

**Testcase IDs:** VOCLE-724, VOCLE-725, VOCLE-782, VOCLE-783. Original registry roots: media-octet-resource-type.

**Observed behavior:** Valid PDF/MP4 bytes supplied as application/octet-stream select resource_type:image instead of raw/video. Exact input byte hash is recorded. Octet-PDF requests/stores image instead of raw and app returns 200; existing VOCLE-724. Octet-MP4 requests image; provider rejects 400 and app returns 500; no resource created. Existing VOCLE-725.

**Expected secure/correct behavior:** Accepted supported bytes must be consistently typed, stored and delivered as PDF/raw or video, with useful response metadata.

**Source trace and likely root cause:** `uploadFile` — [medcollab-backend/src/features/media/media.controller.js:25](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/media/media.controller.js#L25); `fileFilter` — [medcollab-backend/src/features/media/media.routes.js:44](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/media/media.routes.js#L44). The router admits supported octet-stream suffixes, but the controller chooses raw/video/image solely from MIME. Accepted octet-PDF/MP4 therefore defaults to image.

**Impact and severity rationale:** Octet-PDF is stored image/pdf instead of raw; octet-MP4 receives provider 400 and application 500 with no asset. The cause is application dispatch, not a provider outage. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361859575](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361859575), [37361859575/results.json](security-evidence/37361859575/results.json) and [37361859575/reviewed-observations.json](security-evidence/37361859575/reviewed-observations.json); [37361873736](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361873736), [37361873736/results.json](security-evidence/37361873736/results.json) and [37361873736/reviewed-observations.json](security-evidence/37361873736/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Unify validated byte/type classification across admission, resource dispatch, metadata and message attachment. Reject unsupported/mismatched content before provider calls.

**Constraints to preserve / what not to change:** Keep exact fixture byte hashes, MIME-validation denials, typed positive uploads and TEST-only provider controls. Do not label provider image acceptance of PDF as correct raw dispatch.

**Regression verification and gate status:** Rerun VOCLE-724, VOCLE-725, VOCLE-782, VOCLE-783 plus their successful controls. Existing after-fix candidates: VOCLE-724, VOCLE-725, VOCLE-782, VOCLE-783; none active. Review/version the secure oracle before promotion.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-media-video-delete"></a>

### VR-MEDIA-VIDEO-DELETE — Application deletion never dispatches the video resource type

**Classification:** CONFIRMED DEFECT. **Severity:** MEDIUM. **Affected feature/boundary:** DELETE /api/media/:publicId after successful video upload.

**Testcase IDs:** VOCLE-736, VOCLE-762. Original registry roots: media-video-delete.

**Observed behavior:** Video owner deletion dispatches destroy for image then raw, never video. The simulator returns not found/404 and retains the video entry. App returns 404, dispatches image/raw and video remains; independent video delete returnsok and origin disappears. Existing VOCLE-736; no duplicate root.

**Expected secure/correct behavior:** The canonical owner can delete the exact uploaded typed asset; authenticated origin lookup must prove absence.

**Source trace and likely root cause:** `deleteFile` — [medcollab-backend/src/features/media/media.controller.js:146](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/media/media.controller.js#L146). deleteFile tries image then raw and never video. A stored video remains while the controller reports 404.

**Impact and severity rationale:** Offline call intent and real TEST video retention reproduce; independent typed deletion succeeds, so provider deletion support is established. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361859575](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361859575), [37361859575/results.json](security-evidence/37361859575/results.json) and [37361859575/reviewed-observations.json](security-evidence/37361859575/reviewed-observations.json); [37361873736](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361873736), [37361873736/results.json](security-evidence/37361873736/results.json) and [37361873736/reviewed-observations.json](security-evidence/37361873736/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Persist/resolve trusted typed asset identity and destroy its actual resource_type/delivery type, with idempotent results and scoped ownership. Avoid unbounded blind guessing.

**Constraints to preserve / what not to change:** Keep owner/foreign-user checks, normal image/raw deletion, explicit video positive control and exact integration janitor cleanup. Production assets cannot be used for verification.

**Regression verification and gate status:** Rerun VOCLE-736, VOCLE-762 plus their successful controls. Existing after-fix candidates: VOCLE-736, VOCLE-762; none active. Review/version the secure oracle before promotion.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-media-video-message"></a>

### VR-MEDIA-VIDEO-MESSAGE — Uploaded video is rejected by message type validation

**Classification:** CONFIRMED DEFECT. **Severity:** MEDIUM. **Affected feature/boundary:** POST /api/media/upload → POST /api/channels/:channelId/messages with type=video.

**Testcase IDs:** VOCLE-746. Original registry roots: media-video-message.

**Observed behavior:** Valid MP4 upload selects video, but the subsequent real type=video message request is rejected 400 by the message validator.

**Expected secure/correct behavior:** A supported video upload must have a consistent authorized message attachment contract or the product must explicitly remove video support across layers.

**Source trace and likely root cause:** `validateSendMessage` — [medcollab-backend/src/middleware/validate.js:142](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/middleware/validate.js#L142); `VIDEO` — [medcollab-backend/src/constants/index.js:62](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/constants/index.js#L62); `sendMessage` — [medcollab-backend/src/features/messages/message.controller.js:78](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/messages/message.controller.js#L78). Upload/controller/constants have video handling, but validateSendMessage allows only text,image,document,ecg. A valid uploaded MP4 cannot pass type=video admission.

**Impact and severity rationale:** Authorized real message route returns 400 after a successful video upload in the focused offline lane. Real released-device playback remains untested. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361859575](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361859575), [37361859575/results.json](security-evidence/37361859575/results.json) and [37361859575/reviewed-observations.json](security-evidence/37361859575/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Reconcile route validators, model/constants, metadata and mobile rendering for the intended video journey; define rejection/cleanup compensation if intentionally unsupported.

**Constraints to preserve / what not to change:** Keep destination authorization, URL provenance, byte/type validation, sender identity and inert synthetic assets. Do not broadly relax trusted-host checks.

**Regression verification and gate status:** Rerun VOCLE-746 plus their successful controls. Existing after-fix candidates: VOCLE-746; none active. Review/version the secure oracle before promotion.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-cloudinary-pdf-attachment"></a>

### VR-CLOUDINARY-PDF-ATTACHMENT — Generated named PDF attachment URL does not deliver

**Classification:** CONFIRMED DEFECT. **Severity:** MEDIUM. **Affected feature/boundary:** POST /api/media/upload application/pdf → generated raw attachment URL.

**Testcase IDs:** VOCLE-770; additional passing characterization/contract context: VOCLE-731. Original registry roots: CLOUDINARY_PDF_ATTACHMENT.

**Observed behavior:** Application named attachment returns 400 while exact original and plain attachment controls both return 200 exact PDF bytes. No account-wide raw-delivery denial inferred.

**Expected secure/correct behavior:** A returned download URL must retrieve the exact uploaded PDF under supported account delivery policy.

**Source trace and likely root cause:** `uploadFile` — [medcollab-backend/src/features/media/media.controller.js:25](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/media/media.controller.js#L25). The PDF branch builds flags attachment:<filename including extension> for a raw resource. Exact generated URL returns 400 while direct raw/plain attachment controls return 200. Precise provider flag/escaping correction requires developer investigation.

**Impact and severity rationale:** Fresh real TEST URL 400 and successful exact-byte controls confirm a broken application download contract. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361873736](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361873736), [37361873736/results.json](security-evidence/37361873736/results.json) and [37361873736/reviewed-observations.json](security-evidence/37361873736/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Use a provider-supported raw download/filename contract and verify retrieved bytes/content type; handle unsupported naming deterministically without pretending URL construction establishes delivery.

**Constraints to preserve / what not to change:** Preserve plain-attachment/direct-byte controls and account-specific separation. Do not infer a global raw/PDF ban or change production account settings to conceal an application URL mismatch.

**Regression verification and gate status:** Rerun VOCLE-770 plus their successful controls. Existing after-fix candidates: VOCLE-770; none active. Review/version the secure oracle before promotion.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-cloudinary-pdf-preview"></a>

### VR-CLOUDINARY-PDF-PREVIEW — Raw PDF identity is used for an image-resource preview

**Classification:** CONFIRMED DEFECT. **Severity:** MEDIUM. **Affected feature/boundary:** PDF upload → generated image/webp first-page thumbnail.

**Testcase IDs:** VOCLE-771; additional passing characterization/contract context: VOCLE-731. Original registry roots: CLOUDINARY_PDF_PREVIEW.

**Observed behavior:** Raw public ID preview returns 404 while exact synthetic PDF stored as image/pdf previews 200 WebP. This account supports the bounded decoder; raw/image identity mismatch remains in the app.

**Expected secure/correct behavior:** Return a decodable preview backed by a valid correctly typed resource, or explicitly report no supported preview.

**Source trace and likely root cause:** `uploadFile` — [medcollab-backend/src/features/media/media.controller.js:25](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/media/media.controller.js#L25). The controller uploads raw, then constructs an image-resource preview for that raw ID. URL construction does not create a corresponding image/pdf resource. Raw preview 404 contrasts with correctly typed image/pdf WebP 200 control.

**Impact and severity rationale:** The account can preview the synthetic PDF when stored as image/pdf; the application raw-to-image reference fails. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361873736](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361873736), [37361873736/results.json](security-evidence/37361873736/results.json) and [37361873736/reviewed-observations.json](security-evidence/37361873736/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Choose a consistent typed PDF storage/derivation design or create and track a separate preview identity. Verify actual decoding/delivery and lifecycle cleanup for originals/derivatives.

**Constraints to preserve / what not to change:** Keep raw exact download, successful image/pdf control and independent exact cleanup; do not silently return a broken URL or claim account-wide decoder failure.

**Regression verification and gate status:** Rerun VOCLE-771 plus their successful controls. Existing after-fix candidates: VOCLE-771; none active. Review/version the secure oracle before promotion.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

### Real-provider and cache boundaries

All 34 real cases executed;27 pass/seven observations. The seven observed IDs are 762,765,770,771,782,783,784. Exact signed image/video/raw uploads, metadata, original-byte delivery, image/video transforms, correctly typed image-PDF preview control, naming/namespace/type separation and byte-level overwrite controls pass. Independent final and post-job janitors confirm **13/13 exact typed resources absent**, zero pending upload intents, no broad deletion; approved allowlist/broker and artifact hygiene pass. See [37361873736/safety.json](security-evidence/37361873736/safety.json), [37361873736/cleanup.json](security-evidence/37361873736/cleanup.json), [37361873736/post-job-cleanup.json](security-evidence/37361873736/post-job-cleanup.json). Application delete deficiencies did not prevent independent test cleanup.

| Case / historical evidence | Fresh result | Correct disposition |
| --- | --- | --- |
| VOCLE-765, video cache | Original 200 exact MP4 after authenticated origin absence | Cached delivery characterizes provider behavior; no failed origin deletion claim |
| VOCLE-773, raw cache; previously 200 exact bytes | Now 404 after origin absence | Historical observation no longer reproduces on this immediate probe; unchanged app source, variable CDN propagation, not an app fix |
| VOCLE-776, image cache; previously 200 exact bytes | Now 404 after origin absence | Same bounded variable-cache disposition; no worldwide/derived/client cache erasure proof |
| VOCLE-770/771 | Remain attachment 400 / preview 404 with direct/plain attachment and typed image-PDF 200 controls | Both application PDF contracts still fail; the two changed cache cases do not resolve them |
| VOCLE-781, first historical run false observation | PASS, exact namespace and dot-segment checks | Previously repaired filename-dot harness issue, not an application defect |

Public delivery of a synthetic unsigned asset (757 pass) is characterization, not an approved clinical confidentiality policy. Application invalidation intent, backup/derivative retention and delivery authorization are in VR-MEDIA-INVALIDATION-INTENT and the existing [Cloudinary owner checklist](SECURITY_CLOUDINARY_HARDENING_2026-10-06.md). Review likely handoff ownership and local upload compatibility in section 11 rather than inventing live provider IDOR/SSRF findings.

## 7. MongoDB/data findings

Disposable data run 37361864154 executes 31/31,22 passes/nine observations, and 31 exact cleanups with zero residue. **VR-DATA-DELETED-EDIT is the one confirmed data-layer deletion-integrity root.** Projection defaults 790, model pair uniqueness 797, expiry 803, copy retention 806, inactive-space 808, missing references 809, device transfer 815 and handler validation 816 are scoped hardening/policy items in section 11. The report does not confuse Mongoose strictness with authorization or direct model writes with HTTP exploits.

Fresh passes include nine-model strict persistence and nested field exclusion; HTTP profile allowlists and public/populated minimization; bounded actual query/parser/ObjectId input; real phone/invite/direct-pair unique indexes; hashed OTP storage, expiry/attempt/replacement/sequential lifecycle; actual OTP/inbox TTL index definitions; persisted soft-delete blanking; removed-space REST denial; fresh inactive/deleted auth denial; owner-bound notification writes; support attribution; FCM dedup/cap and routed acknowledgement length denial. OTP concurrency 687 is the independently confirmed HTTP root in the general suite.

MongoDB 7 and the runner share only a network-none loopback namespace, exact `vocle_ci` URI and no credentials/proxies/providers. **Only this disposable DB's TTL sweep is paused** to deterministically inspect already-expired visibility; TTL index definitions and explicit OTP expiry admission still run. Real TTL deletion latency and production index parity are not credited. Atlas/TLS/network/roles/encryption/backups/restore/audit controls require owner inspection. See [existing data review and Atlas checklist](SECURITY_MONGODB_HARDENING_2026-10-06.md) and [37361864154/results.json](security-evidence/37361864154/results.json).

## 8. Realtime/session findings

Consolidated mechanisms are VR-S7 unauthorized typing; VR-S8/N3 unauthorized personal-room bodies/previews; VR-S9 stale channel/space room reconciliation (S9/R2); VR-R1 active account revocation; VR-R3 stale typing recipients; VR-R4 synchronous malformed-payload process exit; VR-R5 recovery auth/replay. Their separate proofs/constraints are in section 4. This grouping avoids reporting each duplicate fanout packet or each test permutation as another vulnerability.

VOCLE-653 existing-session token expiry is policy;672/676 async rejection is hardening. FCM-only logout/stateless JWT behavior is source-supported current behavior, not a newly proven revocation defect. Token/active-state checks pass at fresh HTTP/socket admission. Local socket canaries and child exits are proven; real push, released mobile rendering, long expiry windows, recovery listener restoration, distributed adapters/load and packet duplicate semantics are not.

## 9. Authentication findings

VR-AUTH-WIDGET fabricated-token identity and VR-A1-OTP-CONSUMPTION concurrent single-code reuse are independent high-priority roots. Keep 356/357 and 687 positive protected-profile verification, real bcrypt/expiry/attempt controls, no provider traffic and no raw credentials in artifacts. A signed-looking payload is not evidence of trusted verification. Sequential OTP replay denial does not establish concurrent single consumption.

Current refresh-subject, injected subject/operator handling, deleted/inactive user admission, JWT expiry/signature/class and logout device-ownership controls pass in their bounded cases. Refresh/logout revocation, token theft/storage and actual MSG91/Firebase/production configuration are outside this proof; decide the session/device policy before expanding it into a release claim.

## 10. Authorization/data-isolation findings

Use one authoritative access model with action-specific constraints: authentication and active identity; current space membership; private channel membership/admin exception; explicit DM participants; archive/lifecycle state; resource-parent containment; recipient audience. `User.role` is a medical profile role, not a space admin grant. `ObjectId/ref` and approved URL hostname do not establish ownership, existence or containment.

The grouped channel routes VR-S3, thread binding VR-S1, handoff binding VR-S2, draft visibility VR-S4, local owner deletion VR-S6 and Needl VR-N1 require those checks at every alternate read/write surface. Audience helpers must be used before DB inbox creation and socket/push fanout as well as before REST responses. Revocation must update all established devices/caches/recovery sessions rather than relying on fresh REST denial. Preserve valid public-channel membership, independently entitled DMs, self notes and accountable draft admin audit exceptions.

## 11. Hardening and policy decisions

**Three review groups,18 hardening groups and 13 policy groups** below are separately classified. Sixteen hardening groups have retained testcase observations; logging and general partial-write recovery are source-only recommendations already present in prior hardening documentation. A green characterization can establish existing behavior without approving the associated policy. Unresolved business policy and provider/account checks must not be promoted automatically to vulnerability gates.

<a id="vr-u1"></a>

### VR-U1 — Local upload and message attachment contracts disagree

**Classification:** LIKELY DEFECT / REQUIRES DEVELOPER REVIEW. **Severity:** MEDIUM. **Affected feature/boundary:** POST /api/media/upload local mode → POST /api/channels/:channelId/messages.

**Testcase IDs:** VOCLE-323. Original registry roots: U1.

**Observed behavior:** Local upload succeeds but HTTP loopback media URL fails HTTPS requirement before Cloudinary host check. Functional integration contract needs local mobile/Reqable confirmation; no authorization bypass.

**Expected secure/correct behavior:** A supported local upload journey must attach through a tightly scoped local storage contract, or be explicitly unavailable to the client.

**Source trace and likely root cause:** `getApiBaseUrl` — [medcollab-backend/src/utils/localMediaStorage.js:19](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/utils/localMediaStorage.js#L19); `uploadFile` — [medcollab-backend/src/features/media/media.controller.js:25](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/media/media.controller.js#L25); `sendMessage` — [medcollab-backend/src/features/messages/message.controller.js:78](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/messages/message.controller.js#L78). Local fallback returns a loopback HTTP URL while sendMessage requires HTTPS and a Cloudinary host. Upload succeeds but an authorized attachment gets 400. Intended local beta/mobile contract remains unclear.

**Impact and severity rationale:** Likely functional integration mismatch. No authorization bypass or released mobile reproduction is established. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361859575](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361859575), [37361859575/results.json](security-evidence/37361859575/results.json) and [37361859575/reviewed-observations.json](security-evidence/37361859575/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Decide local fallback support and verify using a disposable local mobile build/Reqable. If supported, recognize trusted local asset identities rather than arbitrary user-supplied HTTP URLs.

**Constraints to preserve / what not to change:** Do not allow arbitrary URL protocols/hosts or alter production delivery policy to clear 323. Existing sanity media metadata uses approved inert URLs and does not prove this journey.

**Regression verification and gate status:** Rerun VOCLE-323 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-group-target-state"></a>

### VR-GROUP-TARGET-STATE — Unavailable users can be added as group participants/assignees

**Classification:** LIKELY DEFECT / REQUIRES DEVELOPER REVIEW. **Severity:** LOW. **Affected feature/boundary:** POST /api/channels/dm/group; POST /api/handoffs/:id/reassign.

**Testcase IDs:** VOCLE-527, VOCLE-528, VOCLE-572. Original registry roots: GROUP_TARGET_STATE, HANDOFF_TARGET_STATE.

**Observed behavior:** Group DM creation accepts and persists an opted-in inactive or incomplete target. createGroupDM selects only target ID/name and never checks isActive/isOnboarded. Reassignment persists an inactive same-space member as assignee, writes history and creates a notification. Controller checks space membership, not active User state.

**Expected secure/correct behavior:** Unless an explicit recovery/audit policy permits it, new collaboration work should reject inactive/incomplete targets without membership, history or notification writes.

**Source trace and likely root cause:** `createGroupDM` — [medcollab-backend/src/features/channels/channel.controller.js:294](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/channels/channel.controller.js#L294); `reassignHandoff` — [medcollab-backend/src/features/handoffs/handoff.controller.js:352](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/handoffs/handoff.controller.js#L352). Group target lookup selects only ID/name; handoff reassignment checks Space membership without active/onboarded User eligibility. They persist inactive/incomplete recipients.

**Impact and severity rationale:** Data integrity/availability concern; intended treatment of historical/inactive staff requires developer review. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Define target eligibility centrally and validate active/onboarding state before these transitions. Distinguish existing historical relationships from new invitations/assignments.

**Constraints to preserve / what not to change:** Preserve active target positive controls, consent and participant/admin authorization. Do not claim these inactive identities can authenticate or receive real provider pushes.

**Regression verification and gate status:** Rerun VOCLE-527, VOCLE-528, VOCLE-572 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Grouped lifecycle eligibility omissions across two features; consent and removed-party continuity remain independent policy decisions.

<a id="vr-media-shared-handoff"></a>

### VR-MEDIA-SHARED-HANDOFF — Handoff uploads have no ordinary owner deletion path

**Classification:** LIKELY DEFECT / REQUIRES DEVELOPER REVIEW. **Severity:** MEDIUM. **Affected feature/boundary:** POST /api/media/upload context=handoff → DELETE /api/media/:publicId.

**Testcase IDs:** VOCLE-705, VOCLE-721, VOCLE-740, VOCLE-784. Original registry roots: media-shared-handoff.

**Observed behavior:** An authenticated handoff upload cannot pass ordinary owner deletion: 403, file remains. Shared folder has no caller ownership segment. Cloud branch selects shared medcollab/handoffs without caller ID; the uploaded handoff asset fails owner deletion with 403 and zero destroy calls. Shared handoff folder cannot satisfy owner deletion; app 403 retains asset. Independent scoped janitor removes it. Existing VOCLE-740.

**Expected secure/correct behavior:** Define authorized lifecycle ownership for handoff attachments and provide the appropriate delete/retention path rather than unreachable cleanup.

**Source trace and likely root cause:** `uploadFile` — [medcollab-backend/src/features/media/media.controller.js:25](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/media/media.controller.js#L25); `deleteFile` — [medcollab-backend/src/features/media/media.controller.js:146](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/media/media.controller.js#L146); `saveLocalUpload` — [medcollab-backend/src/utils/localMediaStorage.js:30](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/utils/localMediaStorage.js#L30). Handoff uploads use shared medcollab/handoffs folders; deletion recognizes only messages/<caller> or avatars/<caller>. Uploader deletion 403 retains the asset in local/offline/real TEST evidence.

**Impact and severity rationale:** Confirmed lifecycle limitation; whether immediate uploader delete should be permitted requires product policy before declaring a security defect. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361859575](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361859575), [37361859575/results.json](security-evidence/37361859575/results.json) and [37361859575/reviewed-observations.json](security-evidence/37361859575/reviewed-observations.json); [37361873736](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361873736), [37361873736/results.json](security-evidence/37361873736/results.json) and [37361873736/reviewed-observations.json](security-evidence/37361873736/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Decide uploader/participant/audit retention policy, track typed asset ownership and references, and implement a scoped authorized deletion or managed retention workflow.

**Constraints to preserve / what not to change:** Do not authorize everyone to delete shared folders or erase attachments still required by other handoffs/audit records. Independent CI cleanup already succeeds and is not the application deletion fix.

**Regression verification and gate status:** Rerun VOCLE-705, VOCLE-721, VOCLE-740, VOCLE-784 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-h1"></a>

### VR-H1 — PUT text validation coerces nonstring input

**Classification:** HARDENING RECOMMENDATION. **Severity:** LOW. **Affected feature/boundary:** PUT /api/channels/:channelId/messages/:id.

**Testcase IDs:** VOCLE-110, VOCLE-112. Original registry roots: H1.

**Observed behavior:** PUT text trim coerces number/object before String persistence; sender and channel checks remain. POST strict-type cases now pass.

**Expected secure/correct behavior:** If strict text input is the contract, reject nonstrings 400 before sanitizing and preserve state.

**Source trace and likely root cause:** `body('content.text')` — [medcollab-backend/src/features/messages/message.routes.js:144](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/messages/message.routes.js#L144); `editMessage` — [medcollab-backend/src/features/messages/message.controller.js:305](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/messages/message.controller.js#L305). trim runs before type validation on the edit route; numbers/objects become strings. POST already has strict string checks.

**Impact and severity rationale:** Input consistency and client/error clarity; no ownership bypass. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Add edit-route type validation before trim, matching the documented send/edit contract.

**Constraints to preserve / what not to change:** Preserve valid string edits and ownership/channel checks; string coercion is not demonstrated code execution.

**Regression verification and gate status:** Rerun VOCLE-110, VOCLE-112 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-h2"></a>

### VR-H2 — Malformed upload rejection is reported as server failure

**Classification:** HARDENING RECOMMENDATION. **Severity:** LOW. **Affected feature/boundary:** POST /api/media/upload with wrong field, multiple files or unsupported type.

**Testcase IDs:** VOCLE-301, VOCLE-302, VOCLE-303, VOCLE-304, VOCLE-699, VOCLE-700. Original registry roots: H2.

**Observed behavior:** Multer/filter rejects malformed upload before storage, but error handler leaves these errors at 500. Zero files added; backend healthy. Unsupported SVG/MKV rejects before storage but returns 500 instead of 400; extends existing upload error mapping H2.

**Expected secure/correct behavior:** Malformed/unsupported uploads should produce bounded 400/appropriate 4xx, no storage writes and a healthy backend.

**Source trace and likely root cause:** `fileFilter` — [medcollab-backend/src/features/media/media.routes.js:44](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/media/media.routes.js#L44); `LIMIT_FILE_SIZE` — [medcollab-backend/src/middleware/errorHandler.js:77](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/middleware/errorHandler.js#L77). Multer and fileFilter reject before storage; errorHandler maps file-size errors but leaves other user-input errors 500.

**Impact and severity rationale:** Operational/client error handling; no upload permission bypass. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361859575](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361859575), [37361859575/results.json](security-evidence/37361859575/results.json) and [37361859575/reviewed-observations.json](security-evidence/37361859575/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Map known Multer/filter validation errors consistently while retaining genuine server failures as 5xx.

**Constraints to preserve / what not to change:** Keep rejection, zero files and denied-state preservation. Do not permit forbidden files to obtain a 200.

**Regression verification and gate status:** Rerun VOCLE-301, VOCLE-302, VOCLE-303, VOCLE-304, VOCLE-699, VOCLE-700 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-h3"></a>

### VR-H3 — Admission trusts MIME/extension rather than validating bytes

**Classification:** HARDENING RECOMMENDATION. **Severity:** MEDIUM. **Affected feature/boundary:** POST /api/media/upload local and SDK modes.

**Testcase IDs:** VOCLE-306, VOCLE-307, VOCLE-698, VOCLE-750. Original registry roots: H3.

**Observed behavior:** Allowed caller MIME reaches raw local buffer storage despite empty/mismatched content. One file added; active content/client execution untested. Malformed inert JPEG bytes are accepted and stored unchanged; missing byte validation extends the existing H3 finding. Zero-length accepted PNG invokes upload_stream with bytes:0 and a zero-byte hash; application has no pre-SDK byte validation.

**Expected secure/correct behavior:** Validate supported actual content, nonzero size and declared type consistency before persistence/provider dispatch.

**Source trace and likely root cause:** `fileFilter` — [medcollab-backend/src/features/media/media.routes.js:44](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/media/media.routes.js#L44); `uploadFile` — [medcollab-backend/src/features/media/media.controller.js:25](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/media/media.controller.js#L25); `saveLocalUpload` — [medcollab-backend/src/utils/localMediaStorage.js:30](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/utils/localMediaStorage.js#L30). Allowed caller MIME/suffix reaches raw storage or the SDK without an empty-content/decode check. Empty/inert mismatched/malformed bytes are accepted locally; SDK receives zero bytes in simulation.

**Impact and severity rationale:** Defense against unsafe content and broken rendering; exploit severity depends on actual client/serving behavior. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361859575](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361859575), [37361859575/results.json](security-evidence/37361859575/results.json) and [37361859575/reviewed-observations.json](security-evidence/37361859575/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Use bounded format identification/decoding for supported media, canonical extensions/content types and safe serving headers; reject invalid bytes before side effects.

**Constraints to preserve / what not to change:** Keep valid inert PNG/PDF/video controls and size limits. Active HTML/browser/mobile execution and a real empty-provider upload are not proven.

**Regression verification and gate status:** Rerun VOCLE-306, VOCLE-307, VOCLE-698, VOCLE-750 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-public-profile"></a>

### VR-PUBLIC-PROFILE — Public profile exposes preference and presence metadata

**Classification:** POLICY DECISION REQUIRED. **Severity:** LOW. **Affected feature/boundary:** GET /api/users/:id.

**Testcase IDs:** VOCLE-398. Original registry roots: PUBLIC_PROFILE.

**Observed behavior:** toPublicProfile exposes notification preference keys and lastSeenAt to authenticated foreign-profile reads. Credential/phone minimization controls pass.

**Expected secure/correct behavior:** Publish only fields explicitly approved for the public profile audience.

**Source trace and likely root cause:** `toPublicProfile` — [medcollab-backend/src/features/users/user.model.js:218](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/users/user.model.js#L218); `getUserById` — [medcollab-backend/src/features/users/user.controller.js:132](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/users/user.controller.js#L132). toPublicProfile includes notifications and lastSeenAt in authenticated foreign-profile responses; phone/device minimization controls pass.

**Impact and severity rationale:** Metadata privacy policy; sensitivity determines severity. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Decide visibility for each preference/last-seen field; separate private settings serialization from public clinical identity.

**Constraints to preserve / what not to change:** Do not deny all foreign profiles or label phone/token leakage when those controls pass.

**Regression verification and gate status:** Rerun VOCLE-398 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-search-space-filter"></a>

### VR-SEARCH-SPACE-FILTER — Foreign-space search narrows known users by hidden membership

**Classification:** POLICY DECISION REQUIRED. **Severity:** LOW. **Affected feature/boundary:** GET /api/users/search?q=...&spaceId=<foreign>.

**Testcase IDs:** VOCLE-421. Original registry roots: SEARCH_SPACE_FILTER.

**Observed behavior:** Search intersects known users with caller-selected foreign space members despite a successful foreign-space detail denial control.

**Expected secure/correct behavior:** Decide whether hidden space membership may be inferred by search filters; if disallowed, require access before using that space predicate.

**Source trace and likely root cause:** `searchUsers` — [medcollab-backend/src/features/users/user.controller.js:143](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/users/user.controller.js#L143). Search loads arbitrary space members and intersects them with known IDs without caller space membership. A returned known user allows limited membership inference despite foreign-space detail403.

**Impact and severity rationale:** Limited organizational membership metadata; policy-dependent. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Enforce the approved membership visibility policy at the filter boundary and preserve normal known-user discovery.

**Constraints to preserve / what not to change:** Not complete member enumeration or message disclosure; use narrow inference controls.

**Regression verification and gate status:** Rerun VOCLE-421 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-group-consent"></a>

### VR-GROUP-CONSENT — Group invitation can establish one-to-one DM eligibility without acceptance

**Classification:** POLICY DECISION REQUIRED. **Severity:** MEDIUM. **Affected feature/boundary:** POST /api/channels/dm/group; POST /api/channels/dm.

**Testcase IDs:** VOCLE-529, VOCLE-530. Original registry roots: GROUP_CONSENT.

**Observed behavior:** Request eligibility permits a group with pending/unaccepted peers; group message send/read succeeds and canMessageUser subsequently treats group membership as eligible for a one-to-one DM while the request remains pending.

**Expected secure/correct behavior:** Define whether group invitations establish consent for group messaging and independent direct messaging.

**Source trace and likely root cause:** `createGroupDM` — [medcollab-backend/src/features/channels/channel.controller.js:294](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/channels/channel.controller.js#L294); `canMessageUser` — [medcollab-backend/src/utils/knownUsers.js:98](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/utils/knownUsers.js#L98); `canRequestMessage` — [medcollab-backend/src/utils/knownUsers.js:129](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/utils/knownUsers.js#L129). Group creation explicitly accepts request eligibility, then shared direct-channel membership authorizes a one-to-one DM while the original request remains pending.

**Impact and severity rationale:** Potential consent/privacy bypass only if group-mediated consent is not intended; do not relabel source-supported policy as a proven vulnerability. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Document the policy and, if acceptance is required, distinguish pending invitation membership from active consent and separate group from 1:1 eligibility.

**Constraints to preserve / what not to change:** Preserve self notes, accepted requests, same-institution discovery without automatic direct consent and active legitimate groups.

**Regression verification and gate status:** Rerun VOCLE-529, VOCLE-530 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-removed-handoff-party"></a>

### VR-REMOVED-HANDOFF-PARTY — Removed handoff participants retain note/reassignment authority

**Classification:** POLICY DECISION REQUIRED. **Severity:** MEDIUM. **Affected feature/boundary:** POST /api/handoffs/:id/notes and /reassign after space removal.

**Testcase IDs:** VOCLE-574, VOCLE-575. Original registry roots: REMOVED_HANDOFF_PARTY.

**Observed behavior:** A removed participant may still add notes or reassign because the controller authorizes current participant IDs without current space membership.

**Expected secure/correct behavior:** Define retained audit access separately from ability to change operational assignments after membership removal.

**Source trace and likely root cause:** `addHandoffNote` — [medcollab-backend/src/features/handoffs/handoff.controller.js:299](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/handoffs/handoff.controller.js#L299); `reassignHandoff` — [medcollab-backend/src/features/handoffs/handoff.controller.js:352](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/handoffs/handoff.controller.js#L352). Handlers authorize current sender/assignee IDs without current space membership. Synthetic removed parties write despite space-read revocation.

**Impact and severity rationale:** Operational lifecycle authority with policy-dependent security implications. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Create explicit read/audit/write entitlement policy and enforce it on both transitions; record accountable exception paths.

**Constraints to preserve / what not to change:** Preserve legally/operationally necessary audit history and deny unrelated outsiders. Do not erase audit continuity automatically.

**Regression verification and gate status:** Rerun VOCLE-574, VOCLE-575 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-archived-pin"></a>

### VR-ARCHIVED-PIN — Archived channels still accept pin mutations

**Classification:** POLICY DECISION REQUIRED. **Severity:** LOW. **Affected feature/boundary:** POST/DELETE /api/channels/:id/pin/:messageId.

**Testcase IDs:** VOCLE-599. Original registry roots: ARCHIVED_PIN.

**Observed behavior:** Pinning mutates an archived channel even though archived message/reaction reads/writes are denied by the shared access helper.

**Expected secure/correct behavior:** Decide whether archive freezes all mutations or permits pin management; apply one explicit policy.

**Source trace and likely root cause:** `pinMessage` — [medcollab-backend/src/features/channels/channel.controller.js:404](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/channels/channel.controller.js#L404); `unpinMessage` — [medcollab-backend/src/features/channels/channel.controller.js:451](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/channels/channel.controller.js#L451); `canAccessChannel` — [medcollab-backend/src/utils/channelAccess.js:55](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/utils/channelAccess.js#L55). Pin handlers omit the archive guard used by messages/reactions and mutate an archived channel.

**Impact and severity rationale:** Archive consistency; no new outsider disclosure established. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Apply archive access/action rules consistently once decided.

**Constraints to preserve / what not to change:** Do not bypass private-channel authorization while resolving archive behavior; preserve normal owner pins and reaction denials.

**Regression verification and gate status:** Rerun VOCLE-599 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-inactive-mention"></a>

### VR-INACTIVE-MENTION — Inactive recipients still get persisted mention records

**Classification:** POLICY DECISION REQUIRED. **Severity:** LOW. **Affected feature/boundary:** Mention notification persistence.

**Testcase IDs:** VOCLE-605. Original registry roots: INACTIVE_MENTION.

**Observed behavior:** A mention writes a preview notification for an inactive target because recipient active state is not checked.

**Expected secure/correct behavior:** Define whether inactive accounts should retain new notifications and historical audit data.

**Source trace and likely root cause:** `notifyMention` — [medcollab-backend/src/services/notification.service.js:322](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/services/notification.service.js#L322); `sendNotification` — [medcollab-backend/src/services/notification.service.js:44](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/services/notification.service.js#L44). Recipient active state is not checked before notification persistence; the inactive fixture receives a preview record but cannot authenticate.

**Impact and severity rationale:** Inactive data lifecycle, not demonstrated readable disclosure. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Apply recipient lifecycle policy before new persistence/provider work and coordinate deferred/reactivation semantics.

**Constraints to preserve / what not to change:** Preserve resource audience authorization independently; no real push or inactive-user readability was tested.

**Regression verification and gate status:** Rerun VOCLE-605 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-support-type"></a>

### VR-SUPPORT-TYPE — Object support titles throw before validation

**Classification:** HARDENING RECOMMENDATION. **Severity:** LOW. **Affected feature/boundary:** POST /api/support/bug, /feature, /feedback.

**Testcase IDs:** VOCLE-611, VOCLE-618, VOCLE-625. Original registry roots: SUPPORT_TYPE.

**Observed behavior:** An object title reaches optional .trim() in each support controller, producing HTTP 500 rather than a 400 validation denial. Service remains healthy and no synthetic ticket is created.

**Expected secure/correct behavior:** Malformed titles/descriptions must reject400 without creating a ticket.

**Source trace and likely root cause:** `createBug` — [medcollab-backend/src/features/support/support.controller.js:45](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/support/support.controller.js#L45); `createFeature` — [medcollab-backend/src/features/support/support.controller.js:67](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/support/support.controller.js#L67); `createFeedback` — [medcollab-backend/src/features/support/support.controller.js:89](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/support/support.controller.js#L89). Optional .trim() is called on object titles before checking string type. Each controller returns 500; state and service remain healthy.

**Impact and severity rationale:** Error contract/reliability; no persistence or ownership bypass. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Validate primitive input types before trimming/truncating and share the validation across support entrypoints.

**Constraints to preserve / what not to change:** Keep authenticated attribution, missing/whitespace denial, length bounds and valid support scenario.

**Regression verification and gate status:** Rerun VOCLE-611, VOCLE-618, VOCLE-625 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-dev-notification-references"></a>

### VR-DEV-NOTIFICATION-REFERENCES — Developer notification seed lacks required references

**Classification:** HARDENING RECOMMENDATION. **Severity:** LOW. **Affected feature/boundary:** POST /api/dev/seed-notifications in enabled isolated config.

**Testcase IDs:** VOCLE-641. Original registry roots: DEV_NOTIFICATION_REFERENCES.

**Observed behavior:** Developer notification seed omits required referenceId/referenceType in generated samples. Mongoose rejects the route with 400 before any notification persists; the success expectation and ownership check remain intact.

**Expected secure/correct behavior:** When explicitly enabled for development, the helper should create only caller-bound valid synthetic records.

**Source trace and likely root cause:** `seed-notifications` — [medcollab-backend/src/features/dev/dev.routes.js:45](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/dev/dev.routes.js#L45); `referenceType` — [medcollab-backend/src/features/notifications/notification.model.js:25](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/notifications/notification.model.js#L25). Sample records omit required referenceId/referenceType; Mongoose rejects 400 before any notification persists.

**Impact and severity rationale:** Development helper reliability only; configuration/auth denials pass. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Populate valid exact synthetic references and required metadata; keep the helper production-disabled.

**Constraints to preserve / what not to change:** Do not remove schema requirements or expose developer tools in production to make the helper pass.

**Regression verification and gate status:** Rerun VOCLE-641 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-socket-expiry-policy"></a>

### VR-SOCKET-EXPIRY-POLICY — Established socket lifetime exceeds access-token expiry

**Classification:** POLICY DECISION REQUIRED. **Severity:** MEDIUM. **Affected feature/boundary:** availability_update on already established socket after exp.

**Testcase IDs:** VOCLE-653. Original registry roots: SOCKET_EXPIRY_POLICY.

**Observed behavior:** Expired tokens reject REST and fresh sockets. Existing socket availability writes continue under documented handshake-only authentication. Automatic mid-session expiry enforcement needs a policy decision.

**Expected secure/correct behavior:** Define maximum established-session lifetime and renewal/re-auth behavior for protected socket actions.

**Source trace and likely root cause:** `initSocket` — [medcollab-backend/src/socket/index.js:54](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/socket/index.js#L54); `authenticateSocket` — [medcollab-backend/src/middleware/auth.js:101](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/middleware/auth.js#L101). Source documents handshake-only authentication; established socket writes continue after token expiry while fresh REST/socket authentication denies.

**Impact and severity rationale:** Policy-dependent session duration; no stolen-token attack was executed. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Implement explicit expiry/disconnect or approved bounded renewal behavior if the product requires it; keep recovery admission validity separate.

**Constraints to preserve / what not to change:** Do not claim documented established-session behavior is automatically a vulnerability. Deactivation and expired recovery remain confirmed issues.

**Regression verification and gate status:** Rerun VOCLE-653 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-socket-async-payload"></a>

### VR-SOCKET-ASYNC-PAYLOAD — Null async payload escapes the handler catch

**Classification:** HARDENING RECOMMENDATION. **Severity:** LOW. **Affected feature/boundary:** join_channel and availability_update null payload.

**Testcase IDs:** VOCLE-672, VOCLE-676. Original registry roots: SOCKET_ASYNC_PAYLOAD.

**Observed behavior:** Null payload destructuring happens outside the async handler try/catch and produces a logged unhandled rejection. Test-mode child remains healthy and continues a real edit delivery.

**Expected secure/correct behavior:** Reject malformed objects safely before destructuring and avoid unhandled rejection diagnostics.

**Source trace and likely root cause:** `registerMessageHandlers` — [medcollab-backend/src/socket/handlers/message.handler.js:48](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/socket/handlers/message.handler.js#L48); `registerPresenceHandlers` — [medcollab-backend/src/socket/handlers/presence.handler.js:38](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/socket/handlers/presence.handler.js#L38); `unhandledRejection` — [medcollab-backend/src/server.js:155](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/server.js#L155). Async listener argument destructuring happens before try/catch. The synthetic child logs an unhandled rejection but remains healthy and delivers a subsequent edit.

**Impact and severity rationale:** Reliability hardening; distinct from synchronous process-exit evidence. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37362263669](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37362263669), [37362263669/results.json](security-evidence/37362263669/results.json) and [37362263669/reviewed-observations.json](security-evidence/37362263669/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Validate listener inputs at entry and contain asynchronous failures consistently with synchronous handlers.

**Constraints to preserve / what not to change:** Keep child health/subsequent delivery controls; production shutdown is source-only and not a proven test-mode crash.

**Regression verification and gate status:** Rerun VOCLE-672, VOCLE-676 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-media-octet-metadata"></a>

### VR-MEDIA-OCTET-METADATA — Local octet-video response loses format metadata

**Classification:** HARDENING RECOMMENDATION. **Severity:** LOW. **Affected feature/boundary:** POST /api/media/upload local MP4 application/octet-stream.

**Testcase IDs:** VOCLE-701. Original registry roots: media-octet-metadata.

**Observed behavior:** Valid MP4 supplied as application/octet-stream retains exact bytes but reports format:null instead of video.

**Expected secure/correct behavior:** Accepted media should report the actual validated type in stable client-facing metadata.

**Source trace and likely root cause:** `uploadFile` — [medcollab-backend/src/features/media/media.controller.js:25](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/media/media.controller.js#L25). Local response format selection uses MIME flags; valid MP4 bytes admitted by extension produce format:null.

**Impact and severity rationale:** Client compatibility; coordinated with confirmed octet provider dispatch. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361859575](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361859575), [37361859575/results.json](security-evidence/37361859575/results.json) and [37361859575/reviewed-observations.json](security-evidence/37361859575/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Use the same validated type classifier as provider dispatch and message admission.

**Constraints to preserve / what not to change:** Preserve exact stored bytes and reject invalid/mismatched content; do not infer mobile display failure from metadata alone.

**Regression verification and gate status:** Rerun VOCLE-701 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-media-reference-lifecycle"></a>

### VR-MEDIA-REFERENCE-LIFECYCLE — File/reference cleanup lacks a documented shared-retention contract

**Classification:** POLICY DECISION REQUIRED. **Severity:** MEDIUM. **Affected feature/boundary:** Handoff draft deletion; explicit media deletion; message soft deletion; avatar replacement.

**Testcase IDs:** VOCLE-709, VOCLE-710, VOCLE-747; additional passing characterization/contract context: VOCLE-706, VOCLE-708, VOCLE-712, VOCLE-748. Original registry roots: media-reference-lifecycle.

**Observed behavior:** Draft deletion succeeds and removes its database row but retains the uploaded local attachment. Automatic retention/cleanup policy requires a decision. Explicit owner media deletion removes local bytes but leaves the handoff URL reference unchanged. No media-reference reconciliation runs. Real message soft deletion blanks mediaUrl, emits no SDK destroy and retains its simulated asset. Retention policy must be decided before remediation.

**Expected secure/correct behavior:** Define last-reference, audit-retention and abandoned-upload behavior for originals, previews, avatars and shared attachments.

**Source trace and likely root cause:** `deleteHandoff` — [medcollab-backend/src/features/handoffs/handoff.controller.js:439](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/handoffs/handoff.controller.js#L439); `isModified('isDeleted')` — [medcollab-backend/src/features/messages/message.model.js:240](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/messages/message.model.js#L240); `deleteFile` — [medcollab-backend/src/features/media/media.controller.js:146](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/media/media.controller.js#L146); `updateMe` — [medcollab-backend/src/features/users/user.controller.js:32](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/users/user.controller.js#L32). Draft/message deletion can leave media assets; deleting media can leave stored URLs. Avatar replacement and failed attachment writes also retain assets in passing characterization cases.

**Impact and severity rationale:** Storage/data lifecycle; deletion/erasure expectations determine security impact. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361859575](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361859575), [37361859575/results.json](security-evidence/37361859575/results.json) and [37361859575/reviewed-observations.json](security-evidence/37361859575/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Introduce an asset/reference lifecycle with reference-aware retention, bounded abandoned-upload reconciliation and auditable retryable cleanup.

**Constraints to preserve / what not to change:** Do not destroy media still referenced by another record or required audit retention. Passing characterization is not policy approval. Provider backups/CDN/client copies require separate account policy.

**Regression verification and gate status:** Rerun VOCLE-709, VOCLE-710, VOCLE-747 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-media-reference-validation"></a>

### VR-MEDIA-REFERENCE-VALIDATION — Stored media URLs and metadata lack asset provenance validation

**Classification:** HARDENING RECOMMENDATION. **Severity:** MEDIUM. **Affected feature/boundary:** Message content, handoff attachment and avatar updates.

**Testcase IDs:** VOCLE-713, VOCLE-714, VOCLE-715, VOCLE-716, VOCLE-717; additional passing characterization/contract context: VOCLE-707, VOCLE-749. Original registry roots: media-reference-validation.

**Observed behavior:** Authorized draft accepts and persists an untrusted attachment URL. This is a reference-validation gap, not backend SSRF evidence. An authorized image message persists an alternate cloud path because the host allowlist does not bind cloud identity or upload provenance. An authorized image message persists an untrusted thumbnail URL without the mediaUrl host validation. Authorized image messages persist negative dimensions/size or omit mediaUrl, respectively. Status and actual database counts demonstrate acceptance.

**Expected secure/correct behavior:** Reference attachment should validate trusted asset identity/type/metadata and apply an explicit sharing authorization policy.

**Source trace and likely root cause:** `sendMessage` — [medcollab-backend/src/features/messages/message.controller.js:78](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/messages/message.controller.js#L78); `updateHandoff` — [medcollab-backend/src/features/handoffs/handoff.controller.js:162](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/handoffs/handoff.controller.js#L162); `attachments` — [medcollab-backend/src/features/handoffs/handoff.model.js:98](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/handoffs/handoff.model.js#L98); `updateMe` — [medcollab-backend/src/features/users/user.controller.js:32](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/users/user.controller.js#L32). URL-host validation does not bind an asset to the approved cloud/owner/resource. Handoff URL, thumbnail and metadata sinks accept untrusted/foreign references and negative/missing metadata in focused probes.

**Impact and severity rationale:** Defense-in-depth provenance and client integrity; actual confidential asset access is not established. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361859575](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361859575), [37361859575/results.json](security-evidence/37361859575/results.json) and [37361859575/reviewed-observations.json](security-evidence/37361859575/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Resolve immutable asset records with trusted cloud/publicId/type/owner, validate all URL fields and metadata, and allow explicit authorized sharing rather than accepting URL syntax as ownership.

**Constraints to preserve / what not to change:** No backend SSRF, foreign byte download or exploit from negative dimensions is proved. Preserve legitimate sharing only under a decided policy and never allow arbitrary hosts to fix local 323.

**Regression verification and gate status:** Rerun VOCLE-713, VOCLE-714, VOCLE-715, VOCLE-716, VOCLE-717 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-media-overwrite-intent"></a>

### VR-MEDIA-OVERWRITE-INTENT — Upload omits explicit overwrite prevention

**Classification:** HARDENING RECOMMENDATION. **Severity:** LOW. **Affected feature/boundary:** Cloudinary upload_stream options.

**Testcase IDs:** VOCLE-727. Original registry roots: media-overwrite-intent.

**Observed behavior:** Upload requests unique_filename:true and no explicit public_id, but omits overwrite:false. No overwrite or collision actually occurred.

**Expected secure/correct behavior:** Document and express immutability/overwrite policy explicitly for owned asset uploads.

**Source trace and likely root cause:** `uploadFile` — [medcollab-backend/src/features/media/media.controller.js:25](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/media/media.controller.js#L25). unique_filename:true and generated IDs exist, but overwrite:false is omitted. Real provider controls establish explicit false preserves bytes and true replaces them; no application collision occurred.

**Impact and severity rationale:** Policy/defense in depth, not demonstrated overwrite vulnerability. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361859575](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361859575), [37361859575/results.json](security-evidence/37361859575/results.json) and [37361859575/reviewed-observations.json](security-evidence/37361859575/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Specify overwrite prevention where intended and use trusted immutable identity/version handling for replacements.

**Constraints to preserve / what not to change:** Keep duplicate filename and exact-byte overwrite controls. Do not report an observed app overwrite or leaked production setting.

**Regression verification and gate status:** Rerun VOCLE-727 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-media-context-validation"></a>

### VR-MEDIA-CONTEXT-VALIDATION — Inherited context property reaches folder selection

**Classification:** HARDENING RECOMMENDATION. **Severity:** LOW. **Affected feature/boundary:** POST /api/media/upload context=constructor.

**Testcase IDs:** VOCLE-733. Original registry roots: media-context-validation.

**Observed behavior:** context=constructor selects an inherited function as folder and invokes upload_stream. The double rejects that nonstring folder and Vocle returns 500.

**Expected secure/correct behavior:** Only explicit supported context strings should choose a folder; malformed context should reject before side effects.

**Source trace and likely root cause:** `uploadFile` — [medcollab-backend/src/features/media/media.controller.js:25](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/media/media.controller.js#L25); `saveLocalUpload` — [medcollab-backend/src/utils/localMediaStorage.js:30](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/utils/localMediaStorage.js#L30). folderMap[context] accepts inherited properties; constructor selects a function instead of a folder string. The SDK double rejects and application 500 is recorded.

**Impact and severity rationale:** Input reliability and future namespace hardening. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361859575](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361859575), [37361859575/results.json](security-evidence/37361859575/results.json) and [37361859575/reviewed-observations.json](security-evidence/37361859575/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Use an explicit allowlist/own-property lookup, require a string and apply the same contract to local/provider modes.

**Constraints to preserve / what not to change:** Preserve valid message/avatar/handoff contexts. This is not demonstrated prototype pollution or real-provider behavior.

**Regression verification and gate status:** Rerun VOCLE-733 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-media-invalidation-intent"></a>

### VR-MEDIA-INVALIDATION-INTENT — Deletion does not establish CDN delivery revocation

**Classification:** POLICY DECISION REQUIRED. **Severity:** MEDIUM. **Affected feature/boundary:** Cloudinary destroy and original delivery URLs.

**Testcase IDs:** VOCLE-737, VOCLE-765, VOCLE-773, VOCLE-776. Original registry roots: media-invalidation-intent.

**Observed behavior:** Destroy succeeds in simulation but request options omit invalidate:true. Video origin absent but original URL returns 200 exact MP4 after non-invalidating test destroy. Not proof of failed provider origin deletion or eventual invalidation. Current TEST probe returns 404 after independent origin absence; historical probe returned 200 exact cached bytes. Unchanged application source, variable cache propagation; global/derived/client cache and backup erasure unverified.

**Expected secure/correct behavior:** Define whether media is public/cacheable or confidential and what deletion/revocation guarantee originals and derivatives require.

**Source trace and likely root cause:** `deleteFile` — [medcollab-backend/src/features/media/media.controller.js:146](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/media/media.controller.js#L146); `cloudinary` — [medcollab-backend/src/config/cloudinary.js:14](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/config/cloudinary.js#L14). Application destroy omits invalidate:true. Cached video bytes remain 200 after exact origin absence; raw/image delivery changed to 404 in the fresh run with unchanged source.

**Impact and severity rationale:** Conditional confidentiality/deletion policy; CI proves bounded origin/cache observations, not global revocation. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361859575](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361859575), [37361859575/results.json](security-evidence/37361859575/results.json) and [37361859575/reviewed-observations.json](security-evidence/37361859575/reviewed-observations.json); [37361873736](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361873736), [37361873736/results.json](security-evidence/37361873736/results.json) and [37361873736/reviewed-observations.json](security-evidence/37361873736/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Design authorization-controlled or expiring retrieval where needed, request appropriate invalidation and obtain owner attestation for cache/backup rules. Measure request intent separately from eventual global eviction.

**Constraints to preserve / what not to change:** Do not add an arbitrary delay/strict worldwide 404 assertion or label successful origin deletion as provider failure. Upload signing does not make public delivery private.

**Regression verification and gate status:** Rerun VOCLE-737, VOCLE-765, VOCLE-773, VOCLE-776 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-media-namespace-validation"></a>

### VR-MEDIA-NAMESPACE-VALIDATION — Substring ownership allows out-of-namespace SDK dispatch

**Classification:** HARDENING RECOMMENDATION. **Severity:** MEDIUM. **Affected feature/boundary:** DELETE /api/media/:publicId with foreign-root/messages/<caller>/....

**Testcase IDs:** VOCLE-739. Original registry roots: media-namespace-validation.

**Observed behavior:** A foreign-root public ID containing /messages/<caller>/ passes the substring ownership check and dispatches image/raw destroy. Simulator reports not found/404; status alone conceals the dispatch.

**Expected secure/correct behavior:** Reject foreign namespace IDs before any SDK operation, independently of returned provider status.

**Source trace and likely root cause:** `deleteFile` — [medcollab-backend/src/features/media/media.controller.js:146](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/media/media.controller.js#L146). The embedded caller substring passes ownsFile without exact approved application root/typed asset identity; the double records two destroys even though the ID is unregistered.

**Impact and severity rationale:** Authorization hardening based on call intent; no live provider IDOR claim. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361859575](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361859575), [37361859575/results.json](security-evidence/37361859575/results.json) and [37361859575/reviewed-observations.json](security-evidence/37361859575/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Bind deletion to a trusted asset ownership record and canonical permitted namespace/resource identity.

**Constraints to preserve / what not to change:** Real Cloudinary cross-user deletion was not executed. Keep provider tests restricted to journaled TEST resources and preserve local traversal finding separately.

**Regression verification and gate status:** Rerun VOCLE-739 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-media-compensation"></a>

### VR-MEDIA-COMPENSATION — Post-upload URL failure leaves an orphan

**Classification:** HARDENING RECOMMENDATION. **Severity:** LOW. **Affected feature/boundary:** Cloudinary upload success followed by URL construction failure.

**Testcase IDs:** VOCLE-743. Original registry roots: media-compensation.

**Observed behavior:** Successful upload callback followed by URL-builder failure returns generic 500 without destroy compensation; one new simulated orphan remains.

**Expected secure/correct behavior:** Partial failure should retain a journaled recoverable resource or compensate using exact returned identity.

**Source trace and likely root cause:** `uploadFile` — [medcollab-backend/src/features/media/media.controller.js:25](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/media/media.controller.js#L25). Generic catch returns 500 after successful upload but performs no compensating destroy. The SDK-double inventory contains a new orphan.

**Impact and severity rationale:** Lifecycle/reliability hardening with simulated failure injection, not a newly executed provider orphan exploit. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361859575](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361859575), [37361859575/results.json](security-evidence/37361859575/results.json) and [37361859575/reviewed-observations.json](security-evidence/37361859575/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Track upload completion before URL-building/response work, implement scoped compensation/retry reconciliation, and never lose the returned typed identity.

**Constraints to preserve / what not to change:** Do not perform prefix/bulk deletion or erase successfully referenced assets. Real forced runner-loss cleanup is a separate CI/account limitation.

**Regression verification and gate status:** Rerun VOCLE-743 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-data-default-projection"></a>

### VR-DATA-DEFAULT-PROJECTION — Default model serialization includes sensitive device/hash fields

**Classification:** HARDENING RECOMMENDATION. **Severity:** LOW. **Affected feature/boundary:** User/OTP default model reads and JSON.

**Testcase IDs:** VOCLE-790. Original registry roots: DATA_DEFAULT_PROJECTION.

**Observed behavior:** Default User JSON/lean includes fcmTokens and default OTP JSON includes otpHash. Public profile/populated response controls pass; no route credential disclosure was established. Defense-in-depth model projection/serialization review.

**Expected secure/correct behavior:** Default serialization/read behavior should minimize sensitive fields, with explicit service-only opt-in access where needed.

**Source trace and likely root cause:** `toJSON` — [medcollab-backend/src/features/users/user.model.js:195](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/users/user.model.js#L195); `otpHash` — [medcollab-backend/src/features/auth/otp.model.js:87](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/auth/otp.model.js#L87). Default User JSON/lean includes fcmTokens and OTP JSON includes otpHash; explicit public/populated route projections exclude credentials.

**Impact and severity rationale:** Defense in depth for future serialization mistakes; no current credential disclosure. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361864154](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361864154), [37361864154/results.json](security-evidence/37361864154/results.json) and [37361864154/reviewed-observations.json](security-evidence/37361864154/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Review select:false/serialization transforms and explicit service projections for device tokens/OTP hashes; audit callers before changing defaults.

**Constraints to preserve / what not to change:** No route credential leak is established. Keep OTP verification and provider dispatch able to explicitly access their required fields.

**Regression verification and gate status:** Rerun VOCLE-790 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-data-request-uniqueness"></a>

### VR-DATA-REQUEST-UNIQUENESS — Pending request pair uniqueness is not a data constraint

**Classification:** HARDENING RECOMMENDATION. **Severity:** LOW. **Affected feature/boundary:** MessageRequest direct model inserts and createRequest.

**Testcase IDs:** VOCLE-797. Original registry roots: DATA_REQUEST_UNIQUENESS.

**Observed behavior:** Two overlapping direct-model inserts persist two pending requests for the same pair; schema has nonunique pair indexes and controller does check-then-create. No HTTP race or cross-user consequence was executed.

**Expected secure/correct behavior:** If one active request per unordered pair is required, persistence must enforce it under concurrency.

**Source trace and likely root cause:** `index` — [medcollab-backend/src/features/message-requests/messageRequest.model.js:14](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/message-requests/messageRequest.model.js#L14); `createRequest` — [medcollab-backend/src/features/message-requests/messageRequest.controller.js:52](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/message-requests/messageRequest.controller.js#L52). Pair indexes are nonunique and controller checks then creates. Two overlapping direct model inserts persist duplicate pending records.

**Impact and severity rationale:** Data consistency hardening, not a newly demonstrated HTTP exploit. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361864154](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361864154), [37361864154/results.json](security-evidence/37361864154/results.json) and [37361864154/reviewed-observations.json](security-evidence/37361864154/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Define canonical pair/status key, review historical duplicates and use an appropriate unique/partial index plus atomic transition/error handling.

**Constraints to preserve / what not to change:** HTTP request race was not executed; preserve declined history, reciprocal handling and consent gates. Production index migration requires owner review.

**Regression verification and gate status:** Rerun VOCLE-797 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-data-notification-expiry"></a>

### VR-DATA-NOTIFICATION-EXPIRY — Expired inbox records remain visible before TTL sweep

**Classification:** POLICY DECISION REQUIRED. **Severity:** LOW. **Affected feature/boundary:** GET /api/notifications and unread counts.

**Testcase IDs:** VOCLE-803. Original registry roots: DATA_NOTIFICATION_EXPIRY.

**Observed behavior:** An expired inbox item still present before TTL cleanup returns 200 and is included in unreadCount1. Default retention is 30 days and TTL index exists. Decide whether expiresAt is a visibility boundary or physical cleanup only.

**Expected secure/correct behavior:** Decide whether expiresAt is an immediate visibility limit or only approximate physical retention.

**Source trace and likely root cause:** `getNotifications` — [medcollab-backend/src/features/notifications/notification.controller.js:14](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/notifications/notification.controller.js#L14); `getUnreadCount` — [medcollab-backend/src/features/notifications/notification.model.js:171](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/notifications/notification.model.js#L171). The TTL index exists, but inbox/count queries do not filter expiresAt. With only disposable TTL sweeping paused, an already-expired record is returned 200/count 1.

**Impact and severity rationale:** Retention/UX policy; no ownership leak. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361864154](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361864154), [37361864154/results.json](security-evidence/37361864154/results.json) and [37361864154/reviewed-observations.json](security-evidence/37361864154/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** If visibility must expire immediately, filter the inbox and all badge/count paths by expiry independent of asynchronous TTL.

**Constraints to preserve / what not to change:** Never disable TTL in deployed databases. Preserve owner binding, actual TTL index checks and expired OTP admission denial.

**Regression verification and gate status:** Rerun VOCLE-803 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-data-preview-retention"></a>

### VR-DATA-PREVIEW-RETENTION — Deletion retains quoted and sidebar text copies

**Classification:** POLICY DECISION REQUIRED. **Severity:** MEDIUM. **Affected feature/boundary:** DELETE message → Message.replyTo.text and Channel.lastMessage.text.

**Testcase IDs:** VOCLE-806. Original registry roots: DATA_PREVIEW_RETENTION.

**Observed behavior:** Real deletion blanks original content but quoted reply text and Channel.lastMessage text copies remain. Quote snapshot preservation is explicit in the schema comment; deletion/retention policy must resolve expectations before gating.

**Expected secure/correct behavior:** Document which derived/audit copies survive deletion and which must be scrubbed.

**Source trace and likely root cause:** `replyTo` — [medcollab-backend/src/features/messages/message.model.js:123](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/messages/message.model.js#L123); `deleteMessage` — [medcollab-backend/src/features/messages/message.controller.js:337](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/messages/message.controller.js#L337); `lastMessage` — [medcollab-backend/src/features/channels/channel.model.js:14](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/channels/channel.model.js#L14). Original text is blanked but quote/sidebar copies persist. Quote retention is explicitly intentional in schema comments.

**Impact and severity rationale:** Clinical text retention policy; no new cross-user read claimed. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361864154](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361864154), [37361864154/results.json](security-evidence/37361864154/results.json) and [37361864154/reviewed-observations.json](security-evidence/37361864154/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Implement the chosen retention behavior for quote/Needl/sidebar/notification copies with auditable consistency; distinguish erasure from soft-delete UI behavior.

**Constraints to preserve / what not to change:** Do not erase legally required history or call explicit quote retention an automatic vulnerability. Deleted-edit 805 remains a confirmed invariant violation.

**Regression verification and gate status:** Rerun VOCLE-806 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-data-inactive-space"></a>

### VR-DATA-INACTIVE-SPACE — Inactive-space access differs from discovery visibility

**Classification:** POLICY DECISION REQUIRED. **Severity:** MEDIUM. **Affected feature/boundary:** GET channel messages in model-seeded inactive space.

**Testcase IDs:** VOCLE-808. Original registry roots: DATA_INACTIVE_SPACE.

**Observed behavior:** A model-seeded inactive space still permits member message retrieval 200 with two messages. resolveChannelAccess checks membership but not isActive; discovery filters inactive spaces. No caller-accessible deactivation endpoint or ordinary-user deactivation exploit is claimed.

**Expected secure/correct behavior:** Define whether inactive spaces are hidden, archived-readable or fully revoked.

**Source trace and likely root cause:** `resolveChannelAccess` — [medcollab-backend/src/utils/channelAccess.js:10](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/utils/channelAccess.js#L10); `isActive` — [medcollab-backend/src/features/spaces/space.model.js:132](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/spaces/space.model.js#L132). Discovery filters isActive, while channel access checks membership without space active state. A model-seeded inactive space still returns message data 200.

**Impact and severity rationale:** Lifecycle policy; severity depends on deactivation semantics. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361864154](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361864154), [37361864154/results.json](security-evidence/37361864154/results.json) and [37361864154/reviewed-observations.json](security-evidence/37361864154/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Make resource read/write/discovery policy consistent for inactive spaces once defined.

**Constraints to preserve / what not to change:** No user-accessible space deactivation endpoint/exploit is established. Preserve active space access and current removal denials.

**Regression verification and gate status:** Rerun VOCLE-808 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-data-orphan-refs"></a>

### VR-DATA-ORPHAN-REFS — Typed references do not establish relational integrity

**Classification:** HARDENING RECOMMENDATION. **Severity:** LOW. **Affected feature/boundary:** Direct Message/Handoff model writes with missing Channel refs.

**Testcase IDs:** VOCLE-809. Original registry roots: DATA_ORPHAN_REFS.

**Observed behavior:** Direct Message and Handoff writes persist missing Channel references. Mongoose refs are typed ObjectIds, not foreign keys; this establishes a model constraint gap only. Existing controller foreign-resource defects remain separately tracked.

**Expected secure/correct behavior:** Enforce required relationship existence/containment at authoritative service transitions and define reconciliation for lifecycle deletion.

**Source trace and likely root cause:** `channelId` — [medcollab-backend/src/features/messages/message.model.js:90](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/messages/message.model.js#L90); `channelId` — [medcollab-backend/src/features/handoffs/handoff.model.js:130](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/handoffs/handoff.model.js#L130); `referenceId` — [medcollab-backend/src/features/notifications/notification.model.js:25](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/notifications/notification.model.js#L25). Mongoose ObjectId refs allow missing related documents; direct model probes persist orphan associations.

**Impact and severity rationale:** Persistence defense in depth; no new controller authorization failure. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361864154](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361864154), [37361864154/results.json](security-evidence/37361864154/results.json) and [37361864154/reviewed-observations.json](security-evidence/37361864154/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Centralize service integrity checks and bounded orphan reconciliation; consider transactions only where the invariant needs them.

**Constraints to preserve / what not to change:** This is model evidence, not another route bypass. S1/S2 are the separately proven HTTP binding defects.

**Regression verification and gate status:** Rerun VOCLE-809 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-data-device-transfer"></a>

### VR-DATA-DEVICE-TRANSFER — One device token can remain attached to two accounts

**Classification:** POLICY DECISION REQUIRED. **Severity:** MEDIUM. **Affected feature/boundary:** User.addFcmToken/registerFcmToken and logout.

**Testcase IDs:** VOCLE-815. Original registry roots: DATA_DEVICE_TRANSFER.

**Observed behavior:** Sequential model registrations leave one synthetic device token on two accounts. No real device token, provider push or stolen-token exploit was used; define account-transfer and logout/rotation semantics.

**Expected secure/correct behavior:** Define device-account transfer, logout, shared-device and stale-token delivery semantics.

**Source trace and likely root cause:** `addFcmToken` — [medcollab-backend/src/features/users/user.model.js:240](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/users/user.model.js#L240); `registerFcmToken` — [medcollab-backend/src/features/users/user.controller.js:121](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/users/user.controller.js#L121); `logout` — [medcollab-backend/src/features/auth/auth.controller.js:172](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/auth/auth.controller.js#L172). Sequential synthetic registrations persist the same device token on two users; per-user dedup/cap controls pass and there is no global ownership contract.

**Impact and severity rationale:** Policy-dependent cross-account notification/privacy risk; live delivery is unverified. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361864154](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361864154), [37361864154/results.json](security-evidence/37361864154/results.json) and [37361864154/reviewed-observations.json](security-evidence/37361864154/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Implement the chosen ownership/transfer policy and token retirement/rotation without exposing token values. Separately decide stateless JWT logout/session revocation requirements.

**Constraints to preserve / what not to change:** No real token, provider push or stolen-token attack was executed. Keep logout target ownership and per-user dedup/cap tests.

**Regression verification and gate status:** Rerun VOCLE-815 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-data-update-validation"></a>

### VR-DATA-UPDATE-VALIDATION — Socket presence update bypasses schema note length

**Classification:** HARDENING RECOMMENDATION. **Severity:** LOW. **Affected feature/boundary:** availability_update handler/model boundary.

**Testcase IDs:** VOCLE-816. Original registry roots: DATA_UPDATE_VALIDATION.

**Observed behavior:** Real socket presence handler/model writes a 101-character note despite maxlength 100 and emits no error. findByIdAndUpdate has no runValidators/note check. Direct synthetic handler boundary only; no network socket or security-impact claim.

**Expected secure/correct behavior:** Socket and HTTP availability writes must enforce the same intended enum/type/length constraints.

**Source trace and likely root cause:** `registerPresenceHandlers` — [medcollab-backend/src/socket/handlers/presence.handler.js:38](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/socket/handlers/presence.handler.js#L38); `availability` — [medcollab-backend/src/features/users/user.model.js:19](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/users/user.model.js#L19). findByIdAndUpdate omits runValidators and handler note-length checks;101 characters persist despite schema maxlength 100.

**Impact and severity rationale:** Schema validation parity. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [37361864154](https://github.com/Sriram4747/medcollab-beta-workflows/actions/runs/37361864154), [37361864154/results.json](security-evidence/37361864154/results.json) and [37361864154/reviewed-observations.json](security-evidence/37361864154/reviewed-observations.json). Use the existing registered scenario and its synthetic actor/resource setup, keep the positive control, perform the stated route/event/model transition, then inspect persisted state or predicate-matched packets. Full workflow invocation is in section 13; do not replay against production.

**Remediation direction:** Validate payload fields and enable appropriate update validators; preserve existing enum checks and reject oversize without writes.

**Constraints to preserve / what not to change:** This case invokes the real synthetic handler/model boundary, not a network event. No confidentiality/authorization impact is established.

**Regression verification and gate status:** Rerun VOCLE-816 plus their successful controls. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Shared access and lifecycle decisions; see the fix-order section.

<a id="vr-source-logging"></a>

### VR-SOURCE-LOGGING — Sensitive-value logging lacks a shared redaction boundary

**Classification:** HARDENING RECOMMENDATION. **Severity:** LOW. **Affected feature/boundary:** Auth/OTP/support/error diagnostics (source review only).

**Testcase IDs:** No dedicated failing testcase; retained source-review recommendation.. Original registry roots: SOURCE_LOGGING.

**Observed behavior:** The existing MongoDB hardening review records phone/name and support-title logs, nonproduction bypass-code logging, and raw error messages that may contain cast/duplicate values. There is no general sensitive-value redaction boundary.

**Expected secure/correct behavior:** Operational logs should avoid credentials, OTP/hash/device token values and unnecessary personal/clinical content; define permitted structured identifiers and retention.

**Source trace and likely root cause:** `logger` — [medcollab-backend/src/features/auth/auth.controller.js:22](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/auth/auth.controller.js#L22); `logger` — [medcollab-backend/src/services/otp.service.js:24](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/services/otp.service.js#L24); `logger` — [medcollab-backend/src/middleware/errorHandler.js:24](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/middleware/errorHandler.js#L24); `logger` — [medcollab-backend/src/utils/logger.js:29](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/utils/logger.js#L29). The existing MongoDB hardening review records phone/name and support-title logs, nonproduction bypass-code logging, and raw error messages that may contain cast/duplicate values. There is no general sensitive-value redaction boundary.

**Impact and severity rationale:** Defense in depth for logging and privacy. No actual production logs were accessed. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [Existing MongoDB source/hardening review](SECURITY_MONGODB_HARDENING_2026-10-06.md#source-review-and-evidence-boundaries). Source-only review is reproducible by inspecting the referenced committed files; no runtime exploit is credited.

**Remediation direction:** Implement structured sensitive-field redaction and safe error formatting across auth, providers and support; review log access/export/retention with the owner.

**Constraints to preserve / what not to change:** This is retained source-review context, not a newly executed sensitive-data leak. Do not copy real diagnostic values into tests/reports or suppress all actionable error classes.

**Regression verification and gate status:** No focused new testcase is claimed; audit the change and define a separate approved focused regression requirement. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Coordinate with Atlas/application log-access owner checklist; keep sanitized evidence generation separate.

<a id="vr-source-partial-writes"></a>

### VR-SOURCE-PARTIAL-WRITES — Primary state and derived side effects lack a recovery contract

**Classification:** HARDENING RECOMMENDATION. **Severity:** LOW. **Affected feature/boundary:** Message/handoff/request persistence followed by notifications/previews (source review only).

**Testcase IDs:** No dedicated failing testcase; retained source-review recommendation.. Original registry roots: SOURCE_PARTIAL_WRITES.

**Observed behavior:** The existing data hardening review records multiple writes/read-save transitions with fire-and-forget or swallowed notification failures and no multi-document transaction/outbox. The upstream acceptance failure concretely demonstrates state can advance before DM completion; other failure chains remain source-only.

**Expected secure/correct behavior:** Define which derived effects are best-effort and which must be durable/retryable, with consistent primary-state and replay semantics.

**Source trace and likely root cause:** `sendMessage` — [medcollab-backend/src/features/messages/message.controller.js:78](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/messages/message.controller.js#L78); `reassignHandoff` — [medcollab-backend/src/features/handoffs/handoff.controller.js:352](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/handoffs/handoff.controller.js#L352); `acceptRequest` — [medcollab-backend/src/features/message-requests/messageRequest.controller.js:197](https://github.com/Sriram4747/medcollab-beta-workflows/blob/4eb4c2a57bb0f47bb771321a44c2a283e546ef3e/medcollab-backend/src/features/message-requests/messageRequest.controller.js#L197). The existing data hardening review records multiple writes/read-save transitions with fire-and-forget or swallowed notification failures and no multi-document transaction/outbox. The upstream acceptance failure concretely demonstrates state can advance before DM completion; other failure chains remain source-only.

**Impact and severity rationale:** Reliability hardening; generalized concurrency/partial-failure exploits are not proven. The assigned severity reflects this demonstrated scope; production exposure/account policy is not inferred.

**Reproduction and evidence:** [Existing MongoDB source/hardening review](SECURITY_MONGODB_HARDENING_2026-10-06.md#source-review-and-evidence-boundaries). Source-only review is reproducible by inspecting the referenced committed files; no runtime exploit is credited.

**Remediation direction:** Use conditional transitions, idempotent derived-effect retries or an outbox/transaction only where required; reconcile failed previews/notifications/assignments and expose diagnostic status.

**Constraints to preserve / what not to change:** Do not describe every missing transaction as a vulnerability or roll back deliberately successful primary messages solely because optional push delivery failed. No general fault-injection phase was added.

**Regression verification and gate status:** No focused new testcase is claimed; audit the change and define a separate approved focused regression requirement. No existing active or eligible strict gate; first resolve the proposed requirement/policy. Do not activate an unresolved observation.

**Dependencies/interactions:** Coordinate upstream request acceptance, OTP atomic consumption, asset compensation and audit policy.

## 12. Developer remediation plan

1. **Establish trusted login identity first:** repair widget verification and OTP atomic consumption while retaining all denial/expiry/attempt controls. Verify the intended source revision and expose no production credentials to this test project.
2. **Build the canonical resource/audience policy:** reconcile channel/private/DM/admin/archive checks, thread/handoff parent binding and draft participant visibility. Apply it to detail/member/pin, Needl/search and ordinary/mention notifications. Start with a small shared primitive; do not replace business policy with blanket denials.
3. **Repair realtime lifecycle on top of that policy:** actively reconcile/evict revoked room membership, invalidate recipient caches and enforce deactivation; prevent auth-skipping recovered packet replay. Validate payload objects and keep authorized event delivery/health. Decide established token expiry/session renewal separately.
4. **Restore upstream functional request journeys:** review already-existing fork notification and canonical-DM fixes for the intended release branch, including partial accepted-state recovery and index migration. This testing repository does not push or PR those fixes upstream.
5. **Enforce data deletion invariants:** prohibit deleted-message edit restoration, then decide quote/preview/notification/audit retention and relationship reconciliation. Preserve intentional audit records until requirements are decided.
6. **Unify media identity/type/lifecycle:** validate actual type; persist trusted owner/cloud/publicId/resource/delivery/derivative identity; correct PDF/video contracts; implement typed deletion and exact partial-failure compensation. Decide handoff sharing and confidential retrieval/retention before destructive cleanup.
7. **Finish lower-priority hardening and owner attestations:** input/error mapping, default projections, pending uniqueness, safe logging, durable derived effects, policies and account configuration. Record accountable release decisions for unresolved issues.

Keep fixes reviewable by root group, reference its VR ID and testcase IDs, and identify the exact fix commit/source tested. Application code changes belong to the developer's remediation phase; none were made by this final validation task.

## 13. Verification after fixes

The required flow is **finding → developer fix commit → focused testcase rerun → secure behavior/state/audience confirmed → reviewed versioned assertion → explicit regression gate activation**. A green discovery run alone cannot mark the issue fixed. Legacy callbacks that inspect a disclosure body on unexpected success may need separately versioned secure-denial assertions; preserved historical evidence/IDs must not be silently changed. Null-crash cases need a success/health oracle after a fix, not a wait for crash diagnostics.

| Remediation group | Focused existing cases/scenarios | Current execution route | Required secure verification |
| --- | --- | --- | --- |
| Widget / OTP |356/357 and 687; associated auth/session positives | Broad security workflow | Fabricated tokens denied; at most one OTP success, credentials only after trusted verification, replay/expiry controls pass |
| Channel routes / containment / drafts / Needl |094/098/193/197/275/276;099;159/273/272/594/595;267/268/270/271;429/434/503/509 | Broad workflow | Correct denial with no leaked payload or writes; bound parent state; ordinary owner/private/admin positive controls |
| Audience |347;603/604/685/686 | Broad workflow | No unauthorized full/preview inbox/socket packet; matching authorized delivery still succeeds |
| Revocation / cache / recovery |348/349/659/660/662/681;654/655;663;678–680 | Broad workflow | All subject devices lose forbidden room/recipient/replay access while independently entitled DMs and current viewers pass |
| Malformed realtime |672–676, positive post-event health/edit delivery | Broad workflow | No process exit or unhandled listener failure; safely rejected malformed input |
| Deleted data / persistence |805 with 804 and live-edit control; approved changes 790/797/803/806/808/809/815/816 | MongoDB Data workflow | No restored deleted text/events; policy-specific queries/state and exact cleanup hold |
| Local/SDK media |313/314/704;323;724/725/736/746; relevant 698–751 IDs from each issue | Offline Media workflow | Canonical owner containment, type/admission/metadata/lifecycle, exact SDK intent and local bytes; no double evidence credited as provider behavior |
| Provider media |762/770/771/782/783/784 plus typed upload/delivery/delete positives | Real Cloudinary workflow | Exact approved TEST bytes and correct typed identities; both cleanup passes/hygiene succeed; keep global CDN timing nonblocking |
| Upstream request journeys |message-requests-01/02;direct-and-group-conversations-01/02/03/05 | Functional Sanity with force=true | All relevant scenarios really execute/pass on the intended source; no direct seeding bypass, no success baseline for partial runs |

Current deployed execution interfaces are workflow_dispatch with `ref=master` in the fork: `vocle-backend-environment-test.yml`, `vocle-media-security.yml`, `vocle-data-security.yml`, `vocle-cloudinary-security.yml`, `vocle-sanity.yml` (`force=true`). Secret Scan automatically runs on master pushes. Cloudinary remains only approved TEST configuration. MongoDB/media runtime commands belong inside their isolated workflow containers, not a developer/production DB session.

**Focused selection limitation:** the general runner has `--list` inventory but no verified per-ID hosted execution selector. Do not claim a `--case` or `--suite` option exists. Use the dedicated data/media/provider lanes for focused fixes and group general auth/access/realtime changes into one broader 691-case validation batch when their shared dependencies stabilize. Sanity modules expose local entrypoints but the hosted sanity gate requires the full 48; use controlled local focused module runs for iteration with the same fixtures/isolation, then one full forced hosted run. No need to rerun all six lanes after every small independent edit. Production/upstream publication is outside the test runner.

## 14. Regression-gate candidates

[Existing JSON registry](SECURITY_REGRESSION_GATES.json) contains **124 historically reviewed unique observed IDs:62 after-remediation candidates (53 security / nine functional-provider cases),62 excluded; zero active application gates**. It is a requirement/candidate registry, not an implemented strict runner. This report groups those IDs into fewer remediation roots; testcase and root counts are deliberately different.

The fresh union has 120 observed IDs. Historical 171/355 are now PASS after harness repair; historical 773/776 are PASS on the immediate provider probe with no source change. Their old evidence remains, and current status must not be mistaken for application remediation. Candidate counts remain 62 because all four are historical excluded entries; confirmed application candidates remain unresolved. None is automatically activated.

| Report root group | Existing candidate IDs | Current activation |
| --- | --- | --- |
| [VR-AUTH-WIDGET](#vr-auth-widget) (AUTH_WIDGET) | VOCLE-356, VOCLE-357 | Inactive; requires identified fix, secure-oracle audit, positive/denial/state controls and explicit promotion |
| [VR-S1](#vr-s1) (S1) | VOCLE-094, VOCLE-098, VOCLE-193, VOCLE-197, VOCLE-275, VOCLE-276 | Inactive; requires identified fix, secure-oracle audit, positive/denial/state controls and explicit promotion |
| [VR-S2](#vr-s2) (S2) | VOCLE-099 | Inactive; requires identified fix, secure-oracle audit, positive/denial/state controls and explicit promotion |
| [VR-S3](#vr-s3) (S3, S5, N2_PRIVATE_PIN) | VOCLE-159, VOCLE-272, VOCLE-273, VOCLE-594, VOCLE-595 | Inactive; requires identified fix, secure-oracle audit, positive/denial/state controls and explicit promotion |
| [VR-S4](#vr-s4) (S4) | VOCLE-267, VOCLE-268, VOCLE-270, VOCLE-271 | Inactive; requires identified fix, secure-oracle audit, positive/denial/state controls and explicit promotion |
| [VR-S6](#vr-s6) (S6) | VOCLE-313, VOCLE-314, VOCLE-704 | Inactive; requires identified fix, secure-oracle audit, positive/denial/state controls and explicit promotion |
| [VR-S7](#vr-s7) (S7) | VOCLE-339, VOCLE-340, VOCLE-342, VOCLE-343, VOCLE-345, VOCLE-346 | Inactive; requires identified fix, secure-oracle audit, positive/denial/state controls and explicit promotion |
| [VR-S8](#vr-s8) (S8) | VOCLE-347 | Inactive; requires identified fix, secure-oracle audit, positive/denial/state controls and explicit promotion |
| [VR-S9](#vr-s9) (S9, R2_SPACE_PRESENCE) | VOCLE-348, VOCLE-349, VOCLE-659, VOCLE-660, VOCLE-662, VOCLE-681 | Inactive; requires identified fix, secure-oracle audit, positive/denial/state controls and explicit promotion |
| [VR-N1-NEEDL-ACCESS](#vr-n1-needl-access) (N1_NEEDL_ACCESS) | VOCLE-429, VOCLE-434, VOCLE-503, VOCLE-509 | Inactive; requires identified fix, secure-oracle audit, positive/denial/state controls and explicit promotion |
| [VR-N3-MENTION-AUDIENCE](#vr-n3-mention-audience) (N3_MENTION_AUDIENCE) | VOCLE-603, VOCLE-604, VOCLE-685, VOCLE-686 | Inactive; requires identified fix, secure-oracle audit, positive/denial/state controls and explicit promotion |
| [VR-R1-ACTIVE-SOCKET](#vr-r1-active-socket) (R1_ACTIVE_SOCKET) | VOCLE-654, VOCLE-655 | Inactive; requires identified fix, secure-oracle audit, positive/denial/state controls and explicit promotion |
| [VR-R3-TYPING-CACHE](#vr-r3-typing-cache) (R3_TYPING_CACHE) | VOCLE-663 | Inactive; requires identified fix, secure-oracle audit, positive/denial/state controls and explicit promotion |
| [VR-R4-SOCKET-CRASH](#vr-r4-socket-crash) (R4_SOCKET_CRASH) | VOCLE-673, VOCLE-674, VOCLE-675 | Inactive; requires identified fix, secure-oracle audit, positive/denial/state controls and explicit promotion |
| [VR-R5-RECOVERY-AUTH](#vr-r5-recovery-auth) (R5_RECOVERY_AUTH) | VOCLE-678, VOCLE-679, VOCLE-680 | Inactive; requires identified fix, secure-oracle audit, positive/denial/state controls and explicit promotion |
| [VR-A1-OTP-CONSUMPTION](#vr-a1-otp-consumption) (A1_OTP_CONSUMPTION) | VOCLE-687 | Inactive; requires identified fix, secure-oracle audit, positive/denial/state controls and explicit promotion |
| [VR-DATA-DELETED-EDIT](#vr-data-deleted-edit) (DATA_DELETED_EDIT) | VOCLE-805 | Inactive; requires identified fix, secure-oracle audit, positive/denial/state controls and explicit promotion |
| [VR-MEDIA-OCTET-RESOURCE-TYPE](#vr-media-octet-resource-type) (media-octet-resource-type) | VOCLE-724, VOCLE-725, VOCLE-782, VOCLE-783 | Inactive; requires identified fix, secure-oracle audit, positive/denial/state controls and explicit promotion |
| [VR-MEDIA-VIDEO-DELETE](#vr-media-video-delete) (media-video-delete) | VOCLE-736, VOCLE-762 | Inactive; requires identified fix, secure-oracle audit, positive/denial/state controls and explicit promotion |
| [VR-MEDIA-VIDEO-MESSAGE](#vr-media-video-message) (media-video-message) | VOCLE-746 | Inactive; requires identified fix, secure-oracle audit, positive/denial/state controls and explicit promotion |
| [VR-CLOUDINARY-PDF-ATTACHMENT](#vr-cloudinary-pdf-attachment) (CLOUDINARY_PDF_ATTACHMENT) | VOCLE-770 | Inactive; requires identified fix, secure-oracle audit, positive/denial/state controls and explicit promotion |
| [VR-CLOUDINARY-PDF-PREVIEW](#vr-cloudinary-pdf-preview) (CLOUDINARY_PDF_PREVIEW) | VOCLE-771 | Inactive; requires identified fix, secure-oracle audit, positive/denial/state controls and explicit promotion |

VR-FUNC-01/02 already fail the functional sanity gate on upstream and are outside the security candidate registry. Likely/shared-handoff/policy/source-only items require an approved requirement and targeted verification before candidate creation. Activated gates should be wired to relevant changes in a separate reviewed CI change; this task does not activate them.

## 15. Manual/account-owner checklist

Three owner workstreams remain **EXTERNAL/ACCOUNT-LEVEL CHECK**, not CI-proven application source defects. Record owner/date, approved policy and redacted evidence references. Do not give this test project production/elevated credentials or copy secret values into the report.

| Workstream / report ID | Owner verification required | Existing authoritative checklist |
| --- | --- | --- |
| VR-OWNER-CLOUDINARY | TEST/production separation, key/human privileges/rotation, upload presets, confidential original/derivative access, PDF/transform/fetch limits, invalidation/hostname rules, backups/versions/retention, interrupted-cleanup ownership and account activity/data-location controls | [Cloudinary hardening checklist](SECURITY_CLOUDINARY_HARDENING_2026-10-06.md#developeraccount-owner-attestation), nine existing checklist items |
| VR-OWNER-ATLAS | Project/database/credential isolation; network CIDRs/private connectivity; least privilege/MFA/rotation; TLS/encryption/secrets/region; production unique/TTL index parity; backups/restore/retention; audit/log/alerts; data lifecycle/recovery | [MongoDB Atlas checklist](SECURITY_MONGODB_HARDENING_2026-10-06.md#manual-mongodb-atlas-owner-verification), eight existing checklist items |
| VR-OWNER-RELEASE | Actual deployed configuration/secret identities and release source/build, JWT/OTP/developer-tool/provider/origin guards, actual mobile-device smoke and accountable clinical consent/media/deletion/session policy | [Release security checklist](RELEASE_SECURITY_CHECKLIST.md) and [release/device sanity checklist](RELEASE_SANITY_CHECKLIST.md) |

TEST origin cleanup does not attest worldwide CDN/derived/client caches or provider backups. Fresh disposable indexes do not attest Atlas indexes. Source configuration checks do not attest Railway's running environment or real Firebase/MSG91 delivery. Account attestations remain open until the owners provide redacted verification.

## 16. Remaining coverage limitations

- No actual released APK/mobile device, OS background notification, secure storage, client media playback/unsafe-byte rendering or native deep-link execution was validated. Unrelated Flutter/Android worktree changes were not tested/staged as part of this backend security task.
- Sanity tests an exact upstream source, security a different fork source; four upstream collaboration scenarios remain blocked. The functional gate is manual with no current cron. Do not infer an all-green upstream release from fork security results.
- General coverage exercises 77/77 explicit HTTP method/path operations in bounded scenarios, including auth/developer/platform guards; Socket.IO/static media and implicit HEAD/OPTIONS are outside that denominator. Route coverage is not complete branch/security assurance.
- Backend `npm test` is a placeholder; dormant Jest-style helper files are not a configured maintained suite. No dependency vulnerability audit/gating, mobile build/test or full production entrypoint/deployment validation is credited. Restoring those suites/adding dependency gates is a separately scoped testing follow-up, not an application finding.
- Direct model/index/handler probes do not prove every HTTP race or foreign-key exploit. Multi-document partial failures, concurrent transitions/join/removal/reassignment, long-duration expiry/cache/recovery, multiple-server adapters/load and future recovery-listener behavior are bounded/unverified.
- Real Cloudinary is TEST-only with exact canary cleanup, namespace adaptation and controller-level execution. Account presets/roles/production access policy, global invalidation deadline, derived/version/backup erasure and forced runner-loss janitor completion are not proven. Historical cache observations are preserved when an immediate probe changes.
- No Atlas/production URI, Railway, Firebase, MSG91 production or real user/phone was used. All sensitive result fields are reduced to flags/counts/synthetic references; source and report evidence do not establish production configuration.
- Strict security gates remain inactive. Some historical secure assertions require versioning after developer fixes; a falling observation count does not itself establish remediation. Policies and owner attestations cannot be inferred from PASS characterization.

### Final consistency cross-check and testcase disposition index

All 120 currently observed VOCLE IDs map exactly once to a root group below; no duplicate reporting of reused offline cases, no resolved harness cases in the application defect count, and no unresolved policy promoted to vulnerability. Every report source link is pinned to the inspected tested revision. The registry preserves historical evidence/candidate state; this report is the current primary handoff.

Final mechanical review verified SHA-256 hashes for 36 retained evidence files, 217 local file/issue links and 143 pinned source links with valid line references. Initial-to-repaired broad-suite pass/observation transitions are exactly VOCLE-171 and VOCLE-355. The 124-entry historical registry still has 62 inactive candidates; no application source changed in this task. Raw downloaded artifacts retain their original bytes, including formatting, separately from authored review metadata.

| Report issue | Classification | All affected observed IDs |
| --- | --- | --- |
| [VR-AUTH-WIDGET](#vr-auth-widget) | CONFIRMED DEFECT | VOCLE-356, VOCLE-357 |
| [VR-S1](#vr-s1) | CONFIRMED DEFECT | VOCLE-094, VOCLE-098, VOCLE-193, VOCLE-197, VOCLE-275, VOCLE-276 |
| [VR-S2](#vr-s2) | CONFIRMED DEFECT | VOCLE-099 |
| [VR-S3](#vr-s3) | CONFIRMED DEFECT | VOCLE-159, VOCLE-272, VOCLE-273, VOCLE-594, VOCLE-595 |
| [VR-S4](#vr-s4) | CONFIRMED DEFECT | VOCLE-267, VOCLE-268, VOCLE-270, VOCLE-271 |
| [VR-S6](#vr-s6) | CONFIRMED DEFECT | VOCLE-313, VOCLE-314, VOCLE-704 |
| [VR-S7](#vr-s7) | CONFIRMED DEFECT | VOCLE-339, VOCLE-340, VOCLE-342, VOCLE-343, VOCLE-345, VOCLE-346 |
| [VR-S8](#vr-s8) | CONFIRMED DEFECT | VOCLE-347 |
| [VR-S9](#vr-s9) | CONFIRMED DEFECT | VOCLE-348, VOCLE-349, VOCLE-659, VOCLE-660, VOCLE-662, VOCLE-681 |
| [VR-N1-NEEDL-ACCESS](#vr-n1-needl-access) | CONFIRMED DEFECT | VOCLE-429, VOCLE-434, VOCLE-503, VOCLE-509 |
| [VR-N3-MENTION-AUDIENCE](#vr-n3-mention-audience) | CONFIRMED DEFECT | VOCLE-603, VOCLE-604, VOCLE-685, VOCLE-686 |
| [VR-R1-ACTIVE-SOCKET](#vr-r1-active-socket) | CONFIRMED DEFECT | VOCLE-654, VOCLE-655 |
| [VR-R3-TYPING-CACHE](#vr-r3-typing-cache) | CONFIRMED DEFECT | VOCLE-663 |
| [VR-R4-SOCKET-CRASH](#vr-r4-socket-crash) | CONFIRMED DEFECT | VOCLE-673, VOCLE-674, VOCLE-675 |
| [VR-R5-RECOVERY-AUTH](#vr-r5-recovery-auth) | CONFIRMED DEFECT | VOCLE-678, VOCLE-679, VOCLE-680 |
| [VR-A1-OTP-CONSUMPTION](#vr-a1-otp-consumption) | CONFIRMED DEFECT | VOCLE-687 |
| [VR-DATA-DELETED-EDIT](#vr-data-deleted-edit) | CONFIRMED DEFECT | VOCLE-805 |
| [VR-MEDIA-OCTET-RESOURCE-TYPE](#vr-media-octet-resource-type) | CONFIRMED DEFECT | VOCLE-724, VOCLE-725, VOCLE-782, VOCLE-783 |
| [VR-MEDIA-VIDEO-DELETE](#vr-media-video-delete) | CONFIRMED DEFECT | VOCLE-736, VOCLE-762 |
| [VR-MEDIA-VIDEO-MESSAGE](#vr-media-video-message) | CONFIRMED DEFECT | VOCLE-746 |
| [VR-CLOUDINARY-PDF-ATTACHMENT](#vr-cloudinary-pdf-attachment) | CONFIRMED DEFECT | VOCLE-770 |
| [VR-CLOUDINARY-PDF-PREVIEW](#vr-cloudinary-pdf-preview) | CONFIRMED DEFECT | VOCLE-771 |
| [VR-U1](#vr-u1) | LIKELY DEFECT / REQUIRES DEVELOPER REVIEW | VOCLE-323 |
| [VR-GROUP-TARGET-STATE](#vr-group-target-state) | LIKELY DEFECT / REQUIRES DEVELOPER REVIEW | VOCLE-527, VOCLE-528, VOCLE-572 |
| [VR-MEDIA-SHARED-HANDOFF](#vr-media-shared-handoff) | LIKELY DEFECT / REQUIRES DEVELOPER REVIEW | VOCLE-705, VOCLE-721, VOCLE-740, VOCLE-784 |
| [VR-H1](#vr-h1) | HARDENING RECOMMENDATION | VOCLE-110, VOCLE-112 |
| [VR-H2](#vr-h2) | HARDENING RECOMMENDATION | VOCLE-301, VOCLE-302, VOCLE-303, VOCLE-304, VOCLE-699, VOCLE-700 |
| [VR-H3](#vr-h3) | HARDENING RECOMMENDATION | VOCLE-306, VOCLE-307, VOCLE-698, VOCLE-750 |
| [VR-PUBLIC-PROFILE](#vr-public-profile) | POLICY DECISION REQUIRED | VOCLE-398 |
| [VR-SEARCH-SPACE-FILTER](#vr-search-space-filter) | POLICY DECISION REQUIRED | VOCLE-421 |
| [VR-GROUP-CONSENT](#vr-group-consent) | POLICY DECISION REQUIRED | VOCLE-529, VOCLE-530 |
| [VR-REMOVED-HANDOFF-PARTY](#vr-removed-handoff-party) | POLICY DECISION REQUIRED | VOCLE-574, VOCLE-575 |
| [VR-ARCHIVED-PIN](#vr-archived-pin) | POLICY DECISION REQUIRED | VOCLE-599 |
| [VR-INACTIVE-MENTION](#vr-inactive-mention) | POLICY DECISION REQUIRED | VOCLE-605 |
| [VR-SUPPORT-TYPE](#vr-support-type) | HARDENING RECOMMENDATION | VOCLE-611, VOCLE-618, VOCLE-625 |
| [VR-DEV-NOTIFICATION-REFERENCES](#vr-dev-notification-references) | HARDENING RECOMMENDATION | VOCLE-641 |
| [VR-SOCKET-EXPIRY-POLICY](#vr-socket-expiry-policy) | POLICY DECISION REQUIRED | VOCLE-653 |
| [VR-SOCKET-ASYNC-PAYLOAD](#vr-socket-async-payload) | HARDENING RECOMMENDATION | VOCLE-672, VOCLE-676 |
| [VR-MEDIA-OCTET-METADATA](#vr-media-octet-metadata) | HARDENING RECOMMENDATION | VOCLE-701 |
| [VR-MEDIA-REFERENCE-LIFECYCLE](#vr-media-reference-lifecycle) | POLICY DECISION REQUIRED | VOCLE-709, VOCLE-710, VOCLE-747 |
| [VR-MEDIA-REFERENCE-VALIDATION](#vr-media-reference-validation) | HARDENING RECOMMENDATION | VOCLE-713, VOCLE-714, VOCLE-715, VOCLE-716, VOCLE-717 |
| [VR-MEDIA-OVERWRITE-INTENT](#vr-media-overwrite-intent) | HARDENING RECOMMENDATION | VOCLE-727 |
| [VR-MEDIA-CONTEXT-VALIDATION](#vr-media-context-validation) | HARDENING RECOMMENDATION | VOCLE-733 |
| [VR-MEDIA-INVALIDATION-INTENT](#vr-media-invalidation-intent) | POLICY DECISION REQUIRED | VOCLE-737, VOCLE-765 |
| [VR-MEDIA-NAMESPACE-VALIDATION](#vr-media-namespace-validation) | HARDENING RECOMMENDATION | VOCLE-739 |
| [VR-MEDIA-COMPENSATION](#vr-media-compensation) | HARDENING RECOMMENDATION | VOCLE-743 |
| [VR-DATA-DEFAULT-PROJECTION](#vr-data-default-projection) | HARDENING RECOMMENDATION | VOCLE-790 |
| [VR-DATA-REQUEST-UNIQUENESS](#vr-data-request-uniqueness) | HARDENING RECOMMENDATION | VOCLE-797 |
| [VR-DATA-NOTIFICATION-EXPIRY](#vr-data-notification-expiry) | POLICY DECISION REQUIRED | VOCLE-803 |
| [VR-DATA-PREVIEW-RETENTION](#vr-data-preview-retention) | POLICY DECISION REQUIRED | VOCLE-806 |
| [VR-DATA-INACTIVE-SPACE](#vr-data-inactive-space) | POLICY DECISION REQUIRED | VOCLE-808 |
| [VR-DATA-ORPHAN-REFS](#vr-data-orphan-refs) | HARDENING RECOMMENDATION | VOCLE-809 |
| [VR-DATA-DEVICE-TRANSFER](#vr-data-device-transfer) | POLICY DECISION REQUIRED | VOCLE-815 |
| [VR-DATA-UPDATE-VALIDATION](#vr-data-update-validation) | HARDENING RECOMMENDATION | VOCLE-816 |

Resolved/variable historical IDs:171/355→VR-INFRA-01,37362263669;773/776→VR-MEDIA-INVALIDATION-INTENT,37361873736. Source-only VR-SOURCE-LOGGING/VR-SOURCE-PARTIAL-WRITES, functional VR-FUNC-01/02 and owner workstreams intentionally have no new failing VOCLE IDs. Original older expectation/fixture problems 168/218/219–221 and typing_stop668 were already repaired before this task and do not reappear in fresh findings. Original finding/test documents and execution evidence remain retained; the final report neither silently removes history nor fixes application code.
