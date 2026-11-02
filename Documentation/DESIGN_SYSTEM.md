# HanguStep Design System

Version 0.1 · Phase 2 specification · Status: awaiting approval before implementation

## 1. Design principles

1. **Korean first, gloss second.** Hangul is always the largest text on a learning surface. English and Khmer support it and never compete with it.
2. **Calm, premium, native.** System materials, SF Symbols, standard navigation. The app should feel like it shipped with the OS, not like a web page.
3. **One glance to the next action.** Every screen has one obvious primary action (Start review, Check answer, Next).
4. **Honest feedback.** Correct and incorrect states are unmistakable without relying on color alone.
5. **Three scripts, one rhythm.** Hangul, Latin and Khmer have different vertical metrics. Line heights and paddings are set so mixed text never clips or collides.

## 2. Design tokens

Tokens live in `DesignSystem` as Swift constants and an asset catalog. Features reference tokens only, never raw numbers or hex values.

### 2.1 Spacing (8-point grid)

| Token | Value | Use |
|---|---|---|
| `Spacing.xxs` | 2 | hairline gaps |
| `Spacing.xs` | 4 | icon to label |
| `Spacing.sm` | 8 | inside compact rows |
| `Spacing.md` | 16 | default padding, list insets |
| `Spacing.lg` | 24 | between sections |
| `Spacing.xl` | 32 | screen top and bottom |
| `Spacing.xxl` | 48 | hero blocks |

### 2.2 Radius

| Token | Value | Use |
|---|---|---|
| `Radius.sm` | 8 | badges, chips |
| `Radius.md` | 12 | buttons, option rows |
| `Radius.lg` | 20 | cards |
| `Radius.pill` | 999 | pills, progress bars |

### 2.3 Typography

System font (SF Pro) for Latin, which the OS falls back to Apple SD Gothic Neo for Hangul and Khmer Sangam MN for Khmer. No bundled fonts. All styles map to Dynamic Type text styles so they scale.

| Token | Base style | Weight | Notes |
|---|---|---|---|
| `Typography.hangulDisplay` | `.largeTitle` scaled ×1.3 | semibold | Word hero on detail and quiz prompt |
| `Typography.hangulTitle` | `.title2` | semibold | List rows, option text |
| `Typography.hangulBody` | `.body` | regular | Example sentences |
| `Typography.title` | `.title2` | bold | Screen section titles |
| `Typography.headline` | `.headline` | semibold | Card titles |
| `Typography.body` | `.body` | regular | Explanations |
| `Typography.caption` | `.caption` | regular | Metadata, romanization |
| `Typography.khmerBody` | `.body` | regular | Khmer text, line spacing +4 pt |
| `Typography.khmerCaption` | `.caption` | regular | Khmer metadata, line spacing +2 pt |
| `Typography.statValue` | `.title` rounded | bold | Numbers on stat tiles |

Rules: Khmer text always gets extra line spacing because subscript consonants extend below the baseline. Hangul display text uses `.lineLimit(nil)` and `minimumScaleFactor(0.7)` so long words fit on compact widths.

### 2.4 Color

Semantic tokens only. Defined in `Colors.xcassets` with light and dark variants, plus high-contrast variants where contrast would otherwise drop below 4.5:1.

| Token | Light | Dark | Use |
|---|---|---|---|
| `HSColor.accent` | teal 700 `#0F766E` | teal 400 `#2DD4BF` | Primary actions, selection, links |
| `HSColor.accentSoft` | teal 50 `#F0FDFA` | teal 900 at 40 % | Selected row background |
| `HSColor.success` | green 600 `#16A34A` | green 400 `#4ADE80` | Correct answer |
| `HSColor.danger` | red 600 `#DC2626` | red 400 `#F87171` | Incorrect answer, destructive |
| `HSColor.warning` | amber 600 `#D97706` | amber 400 `#FBBF24` | Due items, sync warnings |
| `HSColor.background` | system grouped background | same | Screen background |
| `HSColor.surface` | system background | secondary system background | Cards |
| `HSColor.surfaceElevated` | white | tertiary system background | Modals, popovers |
| `HSColor.textPrimary` | label | label | |
| `HSColor.textSecondary` | secondary label | secondary label | Gloss, metadata |
| `HSColor.separator` | separator | separator | |

TOPIK level colors, used only in `LevelBadge`:

| Level | Light | Dark |
|---|---|---|
| 1 | `#16A34A` | `#4ADE80` |
| 2 | `#65A30D` | `#A3E635` |
| 3 | `#CA8A04` | `#FACC15` |
| 4 | `#EA580C` | `#FB923C` |
| 5 | `#DC2626` | `#F87171` |
| 6 | `#7C3AED` | `#A78BFA` |

Rule: color never carries meaning alone. Correct and incorrect also use icons (`checkmark.circle.fill`, `xmark.circle.fill`) and text.

### 2.5 Motion

- Standard SwiftUI transitions. Answer feedback: `.spring(duration: 0.3)`.
- Progress ring animates on appear, 0.6 s ease-out.
- All motion disabled under Reduce Motion via `@Environment(\.accessibilityReduceMotion)`.

### 2.6 Iconography

SF Symbols only. Section icons fixed in `AppSection`. Consistent weight `.medium`.

## 3. Components

All in `DesignSystem`, pure presentation, no Domain import. They take plain values (String, Int, Double, enum) so DesignSystem never depends on Domain types.

| Component | API sketch | States |
|---|---|---|
| `PrimaryButton` | `PrimaryButton("Start review", systemImage:, action:)` | normal, pressed, disabled, loading |
| `SecondaryButton` | same, outlined | same |
| `DestructiveButton` | same, red tint | same |
| `HSCard` | `HSCard { content }` surface, radius lg, padding md | — |
| `StatTile` | `StatTile(title:, value:, caption:, systemImage:, tint:)` | — |
| `ProgressRing` | `ProgressRing(progress: 0...1, lineWidth:)` with center label slot | animated, reduced motion |
| `LevelBadge` | `LevelBadge(level: 1...6)` | — |
| `HangulText` | `HangulText("학교", style: .display)` | — |
| `GlossText` | `GlossText(primary:, secondary:)` primary larger, secondary muted; language order decided by caller | — |
| `OptionRow` | `OptionRow(label: "A", text:, state:)` | idle, selected, correct, incorrect, dimmed |
| `SectionHeader` | `SectionHeader("Library", trailing: { })` | — |
| `AsyncStateView` | `AsyncStateView(state:) { loaded in … }` wraps loading, empty, error with retry | loading, empty, error, loaded |
| `EmptyStateView` | `EmptyStateView(title:, systemImage:, message:, action:)` | — |
| `ErrorStateView` | `ErrorStateView(message:, retry:)` | — |
| `SyncStatusBadge` | `SyncStatusBadge(status: .synced(Date) / .syncing / .offline / .disabled / .error(String))` | 5 states |
| `StreakBadge` | `StreakBadge(days:)` flame icon | zero, active |
| `SearchField` | wraps `.searchable` conventions on all platforms | — |

`AsyncStateView` takes a generic `ViewState<T>` enum defined in DesignSystem (`idle, loading, loaded(T), empty, failed(message)`). Phase 2 will migrate `DashboardViewModel.State` to it.

## 4. Adaptive layout

| Width class | Shell | Content |
|---|---|---|
| Compact (iPhone portrait) | `TabView`, 5 tabs | Single column, full-width cards, `List` inset grouped |
| Regular (iPad, Mac, iPhone landscape Max) | `NavigationSplitView` sidebar + detail | Two-column where natural (list + detail), grids of stat tiles with `LazyVGrid` adaptive min 160 |
| Mac specifics | Sidebar persists, toolbar actions, keyboard shortcuts: ⌘1-5 sections, ⌘F search, 1-4 select option, Return next | Hover highlight on option rows |

Max readable content width 720 pt on regular widths so lines of Khmer explanation stay readable.

## 5. Screen specifications

Each spec: purpose · layout · components · states · actions · data · accessibility.

### S1 Dashboard (Home)

- **Purpose**: today's status and the fastest route into practice.
- **Layout**: scroll view. Top: greeting + `StreakBadge`. Row of 3 `StatTile` (Due today, Goal progress with `ProgressRing`, Accuracy 7d). `HSCard` "Continue" if an unfinished session exists. `PrimaryButton` Start review (disabled with reason when nothing due). `SecondaryButton` Quick quiz. Section "This week": 7-bar activity strip. Regular width: tiles in a 3-column grid, actions in a right column.
- **States**: loading, loaded, empty (first launch: onboarding card instead of stats), error.
- **Actions**: Start review, Quick quiz, Continue session, open Progress.
- **Data**: `DashboardSummary` extended in Phase 5 with due count, goal, streak, unfinished session.
- **A11y**: tiles are single accessibility elements reading "Due today, 14 items".

### S2 Vocabulary list

- **Purpose**: browse and search the library.
- **Layout**: `List` with `.searchable`. Filter bar: level chips (1-6, multi-select), part-of-speech menu, bookmarked toggle. Row: `HangulText` title style + romanization caption left, primary gloss right, `LevelBadge`, bookmark icon. Regular: list in sidebar column, detail in main column.
- **States**: loading, loaded, empty results ("No words match"), error.
- **Actions**: tap row → S3, swipe bookmark, pull to clear filters.
- **A11y**: row label "학교, hakgyo, school, level 1, bookmarked".

### S3 Vocabulary detail

- **Purpose**: learn one word deeply.
- **Layout**: `HangulText` display centered with hanja caption, speaker button (TTS), `LevelBadge` + part of speech chip. `GlossText` primary and secondary meanings. `HSCard` Examples: each Korean line in `hangulBody`, translations below. `HSCard` Notes (editable, Phase 4). Toolbar: bookmark toggle. Bottom: `SecondaryButton` Practice this word.
- **States**: loaded, not found (error state), note saving.
- **A11y**: TTS button labelled "Pronounce"; VoiceOver reads Korean with `ko-KR` language attribute.

### S4 Grammar lessons

- **Purpose**: patterns organized by level.
- **Layout**: sectioned `List`, one section per level with `LevelBadge` header. Row: pattern text (`hangulTitle`), category caption, bookmark icon. Detail: pattern hero, explanation card (primary gloss, secondary collapsed behind disclosure), formation card, examples card, related patterns chips, `PrimaryButton` Practice (Phase 4).
- **States**: loading, loaded, empty level, error.

### S5 Quiz

- **Purpose**: one question at a time, zero distraction.
- **Layout**: top bar: close (confirm if unanswered questions), progress bar `Radius.pill` "7 of 20". Optional passage card (scrollable, max 40 % height). Prompt in `hangulDisplay` or `body` depending on kind. 2-4 `OptionRow` stacked, full width, min height 56. Bottom: `PrimaryButton` "Check" (disabled until selected) → becomes "Next" after feedback. Feedback panel slides up: icon + "Correct" / "Incorrect", correct option highlighted, explanation in primary gloss with "Show English / Show Khmer" toggle, link "Open word".
- **States**: answering, checked (feedback), last question → results, resumed session banner, interrupted (no questions) error.
- **Actions**: select option, check, next, close, toggle gloss, open related item.
- **Rules**: after check, options are locked (prevents double submission at UI level; repository enforces it too).
- **A11y**: options are buttons with labels "Option A, school"; feedback announced with `AccessibilityNotification.Announcement`. Mac: keys 1-4 select, Return check/next.

### S6 Quiz results

- **Purpose**: close the loop.
- **Layout**: `ProgressRing` large with score percent, "16 of 20 correct", time. Row of `StatTile` (correct, incorrect, avg time). Section "Review these": list of incorrect questions, each row shows prompt, your answer struck in danger, correct in success, chevron to item. `PrimaryButton` Review mistakes now, `SecondaryButton` Done.
- **States**: loaded; perfect score variant with celebratory icon (no confetti, calm).
- **A11y**: ring has value label; list rows read both answers.

### S7 Mistake review

- **Purpose**: see weaknesses grouped by item.
- **Layout**: segmented control Words / Grammar. `List` rows: item hangul, times missed badge in danger tint, last missed relative date, accuracy mini bar. Sort menu: recent, frequent. Header card: "23 items to clear" with `PrimaryButton` Start mistake quiz.
- **States**: loading, loaded, empty ("No mistakes yet, nice"), error.
- **A11y**: rows read "학교, missed 3 times, last missed 2 days ago".

### S8 Learning progress

- **Purpose**: evidence the routine works.
- **Layout**: `StatTile` grid: total answered, accuracy, streak, mastered. Chart card: 30-day activity (Swift Charts bar), accuracy trend line. Section Weak words (top 10) and Weak grammar. Goal card with editable target.
- **States**: loading, loaded, empty (fewer than 1 session: encouragement card), error.
- **A11y**: charts have `accessibilityChartDescriptor` (Phase 9 polish); summary text provided for each chart.

### S9 Settings and sync status

- **Purpose**: preferences and trust.
- **Layout**: `Form`. Section Learning: primary gloss language picker (English / Khmer), daily goal stepper, review limit, pronunciation toggle. Section iCloud: `SyncStatusBadge`, last sync time, toggle, "What syncs" disclosure. Section Content: version, item counts, licenses link. Section Data: export (future), reset local data (`DestructiveButton`, confirmation). Section About: version, acknowledgements.
- **States**: synced, syncing, offline, disabled, error with message, iCloud signed out.
- **A11y**: standard Form semantics.

## 6. Accessibility guidelines

- Dynamic Type across all styles; test at `.accessibility3`. No fixed heights on text containers.
- Minimum tap target 44×44 pt. Option rows 56 pt.
- Contrast ≥ 4.5:1 for text, ≥ 3:1 for icons and borders. Verified for every token pair in light and dark.
- VoiceOver: Korean strings carry `.speechLanguage("ko-KR")`? SwiftUI lacks a direct modifier; use `accessibilityAttributedLabel` with `.accessibilitySpeechLanguage`. Khmer gets `km-KH`.
- Reduce Motion, Reduce Transparency, Increase Contrast, Bold Text all honored through system APIs.
- Full keyboard navigation on Mac and iPad.

## 7. Phase 2 implementation plan (after approval)

1. Tokens: `Spacing`, `Radius`, `Typography`, `HSColor` + `Colors.xcassets` in DesignSystem resources.
2. `ViewState<T>` and `AsyncStateView`, `EmptyStateView`, `ErrorStateView`.
3. Buttons, `HSCard`, `SectionHeader`, `StatTile`, `ProgressRing`, `LevelBadge`, `StreakBadge`, `SyncStatusBadge`.
4. `HangulText`, `GlossText`, `OptionRow`.
5. SwiftUI previews for every component in light, dark and `.accessibility3` type size.
6. Migrate Dashboard to tokens and `AsyncStateView`; add the Settings screen shell (static, no persistence) to exercise `Form` and `SyncStatusBadge`.
7. Snapshot-free verification: build on iOS and macOS, screenshots of previews on iPhone and iPad simulators and Mac in both themes.
8. Unit tests for `ViewState` transitions and `LevelBadge` color mapping; everything else verified visually.

Not in Phase 2: real data for S2 to S9 (Phase 4 and 5), charts (Phase 5), TTS (Phase 4).

## 8. Open decisions

| # | Question | Default if no answer |
|---|---|---|
| D1 | Accent color teal, or do you prefer another hue? | Teal |
| D2 | Khmer shown above or below English when Khmer is primary gloss? | Primary gloss always on top, larger |
| D3 | Quiz option labels A/B/C/D or ①②③④ (TOPIK style)? | ①②③④, matches the real exam |
| D4 | Tab count: keep 5 or merge Quiz into Learn? | Keep 5 |
