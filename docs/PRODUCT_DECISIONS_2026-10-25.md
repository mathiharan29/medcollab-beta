# Vocle product decisions (2026-10-25)

Source: founder answers to NEEDS_DECISION Q1–Q14 from full-187 `ec430d29`.

| Q | Decision |
|---|----------|
| Q1 | Quote preview stays on edit; on delete show “This message was deleted”. Reply **count** may stay unchanged. Channel last-message updates on delete. |
| Q2 | Expand “today” uses **phone** local midnight (`todayStart`); copied `createdAt` stays server-stored. Expand **all** has no 500-cap; include deleted as “This message was deleted”; destination `lastMessage.messageId` points at **source** id. Thread/quote **remap** to destination ids (links keep working). |
| Q3 | Draft handoffs: **author only** (not receiver/admin). |
| Q4 | Handoff history: sort by `shiftDate`, use `_id` for stable cursor (no duplicates). |
| Q5 | Trust upload **filename extension** for octet-stream; full local upload→message; **video supported**; never surface raw Cloudinary URLs in UX (show media / message link). |
| Q6 | Replace avatar → **auto-delete** old file. Deleted media → allow delete; show Message/Image deleted. |
| Q7 | Accept-without-DM → **recover DM on retry**. Exactly **one** group DM per membership. Lost send response → **dedupe / wait for ack** (ticks). 401 → recoverable try-again / solid refresh (not blunt kick-only). |
| Q8 | Socket presence **note/until** must match REST. |
| Q9 | Quiet hours use **server** timezone. |
| Q10 | Leave/remove: banner “You left” / “Removed by …”; history **readable**, composer **disabled**; presence eviction **immediate**. |
| Q11 | Per-account isolation; drafts/bookmarks on **server**; B must not see A’s local leftovers. |
| Q12 | Handoff day labels: phone local midnight; wording OK. |
| Q13 | Deep link: logged-in → open chat/message; logged-out → login. |
| Q14 | Join with approval: show **Pending**; implement admin approve → B enters channels. |
