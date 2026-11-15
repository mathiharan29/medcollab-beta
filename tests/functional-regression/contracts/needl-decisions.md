# Needl-specific expectations requiring product input

The founder-approved Q1–Q14 decisions are recorded in `docs/PRODUCT_DECISIONS_2026-10-25.md`. The questions below require product approval.

| ID | Question | Status | Executable safe scope |
| --- | --- | --- | --- |
| NDL-D1 | May an authorized member expand an archived Needl into a new active conversation, with historical-copy options? | NEEDS_DECISION | FR-NDL-10 verifies omission from active lists, readable historical detail by explicit `allowArchived: true`, denied message writes, and unchanged archival state. It records expansion response without accepting either expansion policy as approved. |
| NDL-D2 | When an expansion reuses an existing Needl, should the original chat receive a second continuation line? | NEEDS_DECISION | FR-DM-08 requires reuse of the destination, preservation of both original user messages and no second import or destination activity line. Any source continuation must point to that same destination. |

Initial test draft incorrectly assumed that archived detail must be denied. Inspection of the explicit detail-route authorization corrected this expectation before the final run; it was not an application defect or a change to an existing assertion. Expansion policy is separately disputed. Concurrency and copy-retry failures are retained as failures.
