# Vocle beta regression alignment

Reviewed Sanjay Babu's six commits from `fcacf3a` through `3fc7f71` against the Vocle `master` baseline at `db7fefa`. The [release checklist](FIX_CHECKLIST_2026-11-08.md) describes the product changes. The functional catalog still has 187 IDs, including 48 retained sanity IDs.

| Change | Regression evidence in this PR |
| --- | --- |
| Request dialogs, handoff form editing and rejected sessions | Existing Flutter tests exercise dialog dismissal and submission, doctor selection and sign-out recovery. |
| Back handling, tab swipes, latest-chat positioning, live list refresh, contact sync and UI feedback | Existing Flutter tests cover popup-first Back, Back-to-Home, tab navigation, chat position, optimistic sending, group activity, contact sync, voice notes, patient attachments, avatar removal, OTP overwrite and thread updates. |
| Vocle usernames, discovery, contacts and message requests | Profile and discovery tests check persisted username, uniqueness, normalized handle lookup, privacy of partial phone search and contact matching. Request tests check default eligibility, blocked pairs and pending requests without DM access. |
| Group adds, legacy DMs and Needl history | Backend tests check explicit consent, administrator permissions, member-added activity and alerts, legacy history retention, and history copy boundaries and remapping. |
| Submitted handoff edits and withdrawal | Backend tests check sender authorization, patient retention, edit audit, acknowledgement reset and re-acknowledgement, realtime events, and audit retention after withdrawal. |
| Message deletion, clear chat and voice media | Backend tests check permanent removal of related records and local media, per-viewer history and previews, and upload, send, retrieval and invalid voice metadata. |
| Grouped alerts and theme | The Flutter catalog checks grouped reads, failed read recovery and badge counts. Existing theme tests cover the live dark-mode switch and persistence. |

The MongoDB Data Security manifest now matches the existing hard-delete assertion for VOCLE-805. No assertion code in that suite or workflow configuration changed.

## Open application failures

`FR-MSG-05` verifies two remaining gaps in personal chat visibility. `GET /api/spaces` still includes a hidden or cleared message in its nested channel preview. The dedicated space-channel list respects both actions. After Clear chat, reopening an older thread directly can still return the pre-clear root even though its replies are filtered out. The test keeps the expected personal visibility rules for both views.
