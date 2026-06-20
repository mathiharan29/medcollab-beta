# MedCollab — Project State

**Last updated:** 2026-06-18  
**Analyzer:** `flutter analyze` — no issues  
**QA audit:** Staff Engineer / QA pass completed (reliability fixes applied)

---

## Phase status

| Phase | Status | Description |
|-------|--------|-------------|
| **1 — Foundation** | ✅ Complete | API client, socket, storage, theme, router |
| **2 — Auth UI** | ✅ Complete | Phone → OTP → profile → home |
| **3 — Core nav** | ✅ MVP | Spaces, channels, real-time channel chat |
| **4 — Threads** | ✅ MVP | Structured discussions per message |
| **5 — Rich comms** | ✅ MVP | Media, documents, message UX, members, search |
| **6 — Handoffs** | ✅ MVP | Clinical shift handover workflow |
| **Design system** | ✅ Complete | MedCollab tokens + shared components (clinical aesthetic) |

---

## MedCollab design system (2026-06-18)

**Personality:** Calm · Professional · Premium · Trustworthy · Clinical  
**Inspiration:** Linear (precision), Notion (calm surfaces), Slack (clinical chat)  
**Constraints:** No gradients · No flashy animations · Border-first surfaces · 48px touch targets

### Color tokens

| Token | Hex | Usage |
|-------|-----|-------|
| Primary Teal | `#0F766E` | CTAs, FAB, app bar actions |
| Primary Container | `#CCFBF1` | Own message bubbles, icon wells |
| Secondary Slate | `#1E293B` | Headings, secondary emphasis |
| Accent Amber | `#F59E0B` | Submitted handoffs, attention (non-error) |
| Background | `#F8FAFC` | Scaffold, composer fill |
| Success | `#22C55E` | Available presence, confirmations |
| Error | `#DC2626` | Errors, flagged patients, emergency |

### Typography

Modern, readable hierarchy — 15px body, generous line height, `titleSmall` for card headings. Large touch targets for gloved/clinical use.

### Core theme files

| File | Purpose |
|------|---------|
| `lib/core/theme/app_colors.dart` | Brand + semantic palette |
| `lib/core/theme/app_design_system.dart` | Personality, touch targets, component specs |
| `lib/core/theme/app_spacing.dart` | 4–40px spacing scale + `minTouchTarget` |
| `lib/core/theme/app_text_styles.dart` | Typography hierarchy |
| `lib/core/theme/app_decorations.dart` | Cards, bubbles, search, presence, skeletons |
| `lib/core/theme/app_theme.dart` | Material 3 `ThemeData` (app bar, nav bar, FAB, search, chips) |

### Shared UI components

| Widget | Path | Role |
|--------|------|------|
| `AppSearchBar` | `shared/presentation/widgets/app_search_bar.dart` | 48px bordered search |
| `AppFab` | `shared/presentation/widgets/app_fab.dart` | Extended primary FAB |
| `AppBottomBar` | `shared/presentation/widgets/app_bottom_bar.dart` | Sticky form/action bar |
| `AppEmptyState` | `shared/presentation/widgets/app_empty_state.dart` | Calm empty states |
| `AppSkeleton` / `AppListSkeleton` | `shared/presentation/widgets/app_skeleton.dart` | Static loaders (no shimmer) |
| `AppAvatar` | `shared/presentation/widgets/app_avatar.dart` | Initials + presence ring |
| `ErrorBanner` | `shared/presentation/widgets/error_banner.dart` | Inline error surface |

### Component treatments

| Surface | Treatment |
|---------|-----------|
| **Message bubbles** | Container teal (`#CCFBF1`) mine / slate-muted other; bordered, no shadow |
| **Handoff cards** | Bordered card + 4px priority stripe; amber chip for submitted |
| **Channel cards** | White surface, `border` outline, member count secondary text |
| **Presence** | Compact dot on avatars; labeled pill chips on member list |
| **Empty states** | Primary-container icon well, muted copy, optional CTA |
| **Skeletons** | Flat `surfaceMuted` blocks — no shimmer |
| **Avatars** | Initials on `primaryContainer`; optional presence dot |
| **Search bars** | `AppSearchBar` on channels, handoffs, members |
| **App bars** | White surface, slate title, teal actions — elevation 0 |
| **FAB** | `AppFab` on spaces, channels, handoffs — teal, no elevation |
| **Bottom bar** | `AppBottomBar` on handoff form; `navigationBarTheme` ready for tabs |

### Polished screens

- Spaces home, space detail (channels)
- Channel chat (bubbles + composer)
- Handoffs list + form + detail
- Members list + presence picker
- Auth scaffold

---

## QA audit summary (2026-06-20)

### Fixes applied (bugs / reliability only)

| Area | Fix |
|------|-----|
| **Auth + socket** | JWT refresh now reconnects socket with new token; session expiry notifies `AuthBloc` |
| **Auth restore** | `getMe()` before socket connect; network errors allow session retry |
| **Message send** | Duplicate bubble race fixed (socket arrives before REST) |
| **Send errors** | Chat/thread cubits reset `isSending` on unexpected failures |
| **Token refresh** | Single-flight refresh prevents parallel 401 storms |
| **Handoffs reload** | Debounced socket-triggered list refresh + immediate upsert on submit |
| **Presence map** | Capped at 300 entries to limit memory growth |
| **Media upload** | Local disk fallback when Cloudinary not configured |
| **Router** | `debugLogDiagnostics` only in debug builds |
| **Backend access** | Private/archived channel checks; socket `join_channel` membership guard |
| **Backend messages** | Message-by-id ops verify `channelId` matches URL |
| **Backend handoffs** | Atomic submit/acknowledge; `handoff_submitted` socket event |
| **Backend search** | Regex input escaped (ReDoS mitigation) |

### Open improvements (not implemented — no new features)

| Priority | Item |
|----------|------|
| High | MongoDB Atlas + Cloudinary + Railway deploy for beta |
| High | Refresh token rotation / server-side revocation |
| High | `connectionStateRecovery.skipMiddlewares` security review |
| Medium | App lifecycle socket reconnect on resume |
| Medium | Consume `message_updated` / `message_deleted` socket events in UI |
| Medium | Web tokens in `SharedPreferences` — XSS risk on web builds |
| Medium | Multi-instance: presence + rate limits need Redis before scale |
| Low | Message pagination (`hasMore`) in channel/thread UI |
| Low | App logo → launcher icon + splash (assets pending from designer) |
| Low | `AppDependencies.dispose()` wiring on app exit |

---

## Phase 6 — Clinical shift handoffs (MVP)

| Component | Path |
|-----------|------|
| Models + repository | `features/handoffs/data/` |
| List / create / edit / detail | `features/handoffs/presentation/pages/` |
| Realtime list refresh | `handoffs_cubit.dart` |

**Flow:** Space → Shift handoffs → create draft → submit → assigned doctor acknowledges → archived.

---

## Phase 5 — Rich communication (MVP)

Media upload, documents, message UX polish, members, presence, channel search.

---

## Run commands

**Backend:**
```powershell
cd D:\MedCollab\medcollab-backend
npm run dev
```

**Flutter Chrome:**
```powershell
cd D:\MedCollab\medcollab-app
flutter run -d chrome
```

Dev OTP: `123456`
