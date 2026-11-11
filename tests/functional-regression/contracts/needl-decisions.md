# Needl-specific expectations requiring product input

The founder-approved Q1–Q14 decisions in `docs/PRODUCT_DECISIONS_2026-10-25.md` remain unchanged and resolved. The following new question is not developer-approved.

| ID | Question | Status | Executable safe scope |
| --- | --- | --- | --- |
| NDL-D1 | May an authorized member expand an archived Needl into a new active conversation, with historical-copy options? | NEEDS_DECISION | FR-NDL-10 verifies omission from active lists, readable historical detail by explicit `allowArchived: true`, denied message writes, and unchanged archival state. It records expansion response without accepting either expansion policy as approved. |

Initial test draft incorrectly assumed that archived detail must be denied. Inspection of the explicit detail-route authorization corrected this expectation before the final run; it was not an application defect or a change to an existing assertion. Expansion policy is separately disputed. Concurrency and copy-retry failures are retained as failures.
