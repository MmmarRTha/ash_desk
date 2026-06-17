# Chat UI Enhancement Plan

## Codebase Audit

### Files Involved

| File | Lines | Role |
|------|-------|------|
| `lib/ash_desk_web/live/chat_live/index.ex` | 220 | Customer conversation list |
| `lib/ash_desk_web/live/chat_live/show.ex` | 396 | Customer conversation view |
| `lib/ash_desk_web/live/inbox_live/index.ex` | 237 | Agent inbox list |
| `lib/ash_desk_web/live/inbox_live/show.ex` | 486 | Agent conversation view |
| `lib/ash_desk_web/live/typing_indicator.ex` | 89 | Typing indicator behavior |
| `lib/ash_desk_web/live/live_user_auth.ex` | 39 | Auth hooks |
| `lib/ash_desk_web/presence.ex` | 5 | Phoenix Presence |
| `lib/ash_desk_web/components/layouts.ex` | 165 | App layout |
| `lib/ash_desk_web/components/layouts/root.html.heex` | 36 | Root HTML layout |
| `lib/ash_desk_web/components/core_components.ex` | 505 | Core input/button/icon components |
| `assets/css/app.css` | 133 | Application CSS |
| `assets/js/app.js` | 92 | JS boot, LiveSocket setup |
| `assets/js/hooks/typing_indicator.js` | 25 | Typing indicator JS hook |
| `lib/ash_desk/support.ex` | 27 | Domain code interfaces |
| `lib/ash_desk/support/conversation.ex` | 151 | Conversation resource |
| `lib/ash_desk/support/message.ex` | 87 | Message resource |
| `lib/ash_desk/support/changes/set_sender_change.ex` | 16 | Sets sender_id from actor |
| `lib/ash_desk/support/typing_server.ex` | 110 | GenServer for typing tracking |
| `lib/ash_desk_web/router.ex` | 98 | Route definitions |
| `test/ash_desk_web/live/inbox_live_test.exs` | 98 | Inbox LiveView tests |
| `test/ash_desk/support/conversation_test.exs` | 253 | Conversation resource tests |
| `test/ash_desk/support/message_test.exs` | 186 | Message resource tests |

---

## UX Issues Found

1. **No conversation preview text** — only subject shown, no last message snippet
2. **No unread indicators** — can't tell which conversations have new messages
3. **No search** — can't search conversations on either customer or agent side
4. **No message actions** — can't copy, react, or give feedback on messages
5. **No message status** — no sending/sent/failed states; appears only after server confirms
6. **No markdown/code rendering** — messages are raw plain text
7. **No auto-scroll to bottom** — new messages insert at index 0, no scroll management
8. **No loading skeletons** — content appears abruptly with no placeholder
9. **Errors show `inspect(reason)`** — raw Elixir inspect output in flash messages
10. **No keyboard shortcuts** — must click send button, no enter-to-send
11. **No character count indicator** — 500 char limit is invisible to user
12. **No inline message editing or deletion**

---

## Design Issues Found

1. **No custom design tokens** — relies entirely on daisyUI defaults for spacing, radius, shadows
2. **Message bubbles lack polish** — no distinct visual personality, no depth, basic daisyUI
3. **No responsive sidebar layout** — traditional top-down single-column layout
4. **No proper typography scale** — uses raw Tailwind text sizes inconsistently
5. **No avatar images** — initials only, no photo upload/display
6. **Minimal animations** — only basic `message-in` CSS keyframe (0.25s translateY)
7. **No mobile-first adaptations** — same layout on all screen sizes
8. **Empty states are basic** — icon + text, no illustrations or helpful CTAs

---

## Technical Issues Found

1. **Heavy code duplication** — `ChatLive.Show` (396 lines) and `InboxLive.Show` (486 lines) are ~80% identical
2. **Duplicate `relative_time` helper** — defined identically in 4 separate LiveViews
3. **No message virtualization** — all messages rendered in full DOM, unbounded growth
4. **No optimistic updates** — waits for server round-trip before showing sent message
5. **No pagination** — all messages loaded at once in a single query
6. **Message bubble template duplicated** — same `chat-start`/`chat-end` pattern in both Show views
7. **Legacy `phx-disable-with="..."`** — hardcoded string, not descriptive

---

## Enhancement Plan

### Phase 1: Foundation — Shared Components & Design Tokens

**Goal**: Eliminate duplication, establish design foundations, extract shared patterns.

| Step | Task | Files | Impact |
|------|------|-------|--------|
| 1.1 | Extract `relative_time` into shared view helper | New: `lib/ash_desk_web/helpers.ex`; remove from 4 LiveViews | **Medium** — DRY, maintainability |
| 1.2 | Create `AshDeskWeb.ChatComponents` module — shared message bubble, conversation card, presence display, typing indicator, status badge | New: `lib/ash_desk_web/components/chat_components.ex` | **High** — eliminates 80% duplication |
| 1.3 | Add custom design tokens in `app.css` — spacing scale, border radius system, shadow elevation, animation timings | `assets/css/app.css` | **High** — foundation for visual polish |
| 1.4 | Refactor `layouts.ex` to support sidebar/navigation state | `lib/ash_desk_web/components/layouts.ex` | **Medium** — enables Phase 2 layout |

#### 1.1 — Extract `relative_time` helper

Create a simple module with the shared `relative_time/1` function and import it in all LiveViews.

#### 1.2 — ChatComponents module

Extract these reusable components (currently duplicated across Chat + Inbox Show views):

- `<ChatComponents.message_bubble message={@message} current_user={@current_user} />`
- `<ChatComponents.conversation_card conversation={conv} active?={false} />`
- `<ChatComponents.presence_indicators users={@online_users} max_display={3} />`
- `<ChatComponents.typing_indicator users={@typing_users} />`
- `<ChatComponents.status_badge status={:open} />`
- `<ChatComponents.message_input form={@form} input_id={@id} />`
- `<ChatComponents.empty_state icon="hero-chat-bubble-left-right" title="No messages" />`

#### 1.3 — Design tokens

```css
/* Spacing scale */
:root {
  --chat-spacing-xs: 0.25rem;
  --chat-spacing-sm: 0.5rem;
  --chat-spacing-md: 1rem;
  --chat-spacing-lg: 1.5rem;
  --chat-spacing-xl: 2rem;
  --chat-radius-sm: 0.375rem;
  --chat-radius-md: 0.75rem;
  --chat-radius-lg: 1rem;
  --chat-radius-xl: 1.5rem;
  --chat-shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.05);
  --chat-shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.1);
  --chat-shadow-lg: 0 10px 15px -3px rgb(0 0 0 / 0.1);
  --chat-transition-fast: 150ms ease;
  --chat-transition-base: 200ms ease;
  --chat-transition-slow: 300ms ease;
}
```

#### 1.4 — Layout refactor

Add optional `sidebar` slot to `Layouts.app` so inbox views can use a split-pane layout:

```elixir
attr :sidebar, :slot, default: nil  # content rendered as sidebar
```

The layout wraps `inner_block` with or without a sidebar container based on whether the slot is provided.

---

### Phase 2: Layout & Navigation Redesign (Intercom-Style)

**Goal**: Transform inbox into a proper split-pane conversation view.

| Step | Task | Files | Impact |
|------|------|-------|--------|
| 2.1 | Redesign `InboxLive.Index` as sidebar — conversation list with search, last message preview, unread dot, active highlight | `inbox_live/index.ex` | **High** — transforms agent UX |
| 2.2 | Redesign `InboxLive.Show` as split-pane — sidebar on left, conversation on right | `inbox_live/show.ex` | **High** — enables quick triage |
| 2.3 | Add conversation search — combined client-side filter + debounced server search | `inbox_live/index.ex` | **High** — critical for scale |
| 2.4 | Add unread tracking — `last_read_at` on member_conversation or conversation metadata | New migration, `conversation.ex` | **High** — core inbox feature |
| 2.5 | Redesign customer chat list to match sidebar style | `chat_live/index.ex` | **Medium** — consistency |

#### 2.1 — Sidebar conversation list

The inbox index becomes a persistent sidebar (visible on both index and show pages) with:

- Search input at top
- Filter pills (All / Open / Pending / Resolved)
- Conversation cards showing:
  - Avatar (customer/agent initial or photo)
  - Name/email
  - Last message preview (truncated to 1 line)
  - Relative time
  - Unread dot indicator
  - Status badge (small)
- Active conversation highlighted with subtle background
- Smooth scroll for long lists
- Empty state when no matches

#### 2.2 — Split-pane show view

The inbox show view renders the sidebar alongside the conversation:

```
┌─────────────────────┬──────────────────────────────────────────┐
│  Search...          │  ← Back to Inbox                         │
│  [All] [Open] [...] │  Subject / Status                       │
│ ─────────────────── │  Online presence    [Assign agent]       │
│ ○ John — "Hey..."   │ ─────────────────────────────────────── │
│   • 2m ago          │  Messages...                             │
│ ● Support — "Sure"  │                                         │
│   • 1h ago          │  ┌──────────────────────────────┐       │
│                     │  │ Type your message...    ➤    │       │
│                     │  └──────────────────────────────┘       │
└─────────────────────┴──────────────────────────────────────────┘
```

Desktop: sidebar 320px fixed, conversation fills remaining width.
Tablet: sidebar collapsible.
Mobile: sidebar is a slide-over drawer.

#### 2.3 — Conversation search

Debounced search (300ms) that filters by:
- Subject match
- Customer email/name match
- Message body contains query

Implementation options:
- Ecto query with `ILIKE` for PostgreSQL
- Simple client-side filter for smaller datasets (< 500 conversations)

Start with client-side filtering on loaded conversations; add server-side when scale demands it.

#### 2.4 — Unread tracking

Approach: Add `last_read_at` timestamp tracked per-participant. When a new message arrives:
1. If the recipient is viewing the conversation, mark as read automatically
2. If not, show unread indicator
3. Store in a new `conversation_participants` table or as a simple field

Simpler alternative: Compare `message.created_at` against a `last_seen_at` stored in the LiveView assigns (less durable but simpler).

---

### Phase 3: Message Bubbles & Chat Experience Overhaul

**Goal**: Premium message UI with actions, statuses, and polish.

| Step | Task | Files | Impact |
|------|------|-------|--------|
| 3.1 | Refined message bubbles — better padding, distinct styling, subtle shadow, smoother radii | `components/chat_components.ex` | **High** — most visible change |
| 3.2 | Message actions — copy button, 👍/👎 feedback | `chat_components.ex`, new message actions partial | **High** — user agency |
| 3.3 | Message status indicators + optimistic updates | `chat_live/show.ex`, `inbox_live/show.ex` | **High** — perceived performance |
| 3.4 | Proper timestamps — relative + full date on hover | `chat_components.ex` | **Medium** — polish |
| 3.5 | Improved typing indicator — smoother animation, name + avatar | `chat_components.ex`, `typing_indicator.ex` | **Medium** — delight |
| 3.6 | Auto-scroll to bottom on new messages | New JS hook | **High** — usability fix |
| 3.7 | Enter-to-send + Shift+Enter for newline | Enhanced JS hook | **High** — UX efficiency |
| 3.8 | Character count indicator with visual ring | `chat_components.ex` | **Medium** — feedback |

#### 3.1 — Refined message bubbles

```
┌─────────────────────────────────────────────────────┐
│  User message (right-aligned):                       │
│     ┌──────────────────────────────┐                 │
│     │ Hey, I need help with my     │                 │
│     │ account setup                │                 │
│     │                     12:30 PM │                 │
│     │                     ✓✓ Sent  │                 │
│     └──────────────────────────────┘                 │
│                                                      │
│  Support message (left-aligned):                     │
│  ┌──────────────────────────────────┐                │
│  │ Sarah                           │                │
│  │                                │                │
│  │ Hi! I'd be happy to help you   │                │
│  │ get set up. Can you tell me    │                │
│  │ what you're trying to do?      │                │
│  │                                │                │
│  │ 12:31 PM                       │                │
│  └──────────────────────────────────┘                │
└─────────────────────────────────────────────────────┘
```

Design details:
- User bubbles: colored background (primary), white text, rounded-2xl with `rounded-br-sm` for tail effect
- Assistant/agent bubbles: neutral background (base-200/300), dark text, rounded-2xl with `rounded-bl-sm`
- Avatar + name in header for first message in a group; hidden for consecutive same-side messages (already works via CSS)
- Timestamp inside bubble, bottom-right, small, subtle opacity
- Status icons below timestamp: single check (sent), double check (read), clock (sending), error icon (failed)

#### 3.2 — Message actions

Each message gets a contextual action bar on hover:

```
┌──────────────────────────────────────────────┐
│  Hi! I'd be happy to help you get set up.    │
│                                     12:31 PM │
│ ┌────────────────────────────┐               │
│ │ 📋 Copy  👍  👎           │ (appears on   │
│ └────────────────────────────┘  hover)       │
└──────────────────────────────────────────────┘
```

- Copy: copies message body to clipboard using `navigator.clipboard` via JS hook
- 👍/👎: push feedback event to server (store on message resource)
- Actions fade in smoothly on hover

#### 3.3 — Optimistic updates + status

Messages go through states:
1. **Sending**: Show immediately with spinner/clock icon, dimmed
2. **Sent**: Server confirmed, single check ✓
3. **Failed**: Error state with retry option

Implementation:
- On send, immediately `stream_insert` the message with a temporary client ID and `status: :sending`
- On server confirm, update the stream item with real data and `status: :sent`
- On error, update to `status: :failed` with a "Retry" button

#### 3.6 — Auto-scroll JS hook

```javascript
const AutoScroll = {
  mounted() {
    this.scrollToBottom();
    this.observer = new MutationObserver(() => this.scrollToBottom());
    this.observer.observe(this.el, { childList: true, subtree: true });
  },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight;
  },
  destroyed() {
    this.observer?.disconnect();
  }
};
```

Only auto-scroll if the user is already near the bottom (within 150px). If they've scrolled up to read history, don't force-scroll — show a "↓ New messages" button instead.

#### 3.7 — Enter-to-send JS enhancement

Extend the typing indicator hook:

```javascript
this.el.addEventListener("keydown", (e) => {
  if (e.key === "Enter" && !e.shiftKey) {
    e.preventDefault();
    this.el.closest("form")?.requestSubmit();
  }
});
```

---

### Phase 4: Markdown & Rich Content Support

**Goal**: Render rich content in messages.

| Step | Task | Files |
|------|------|-------|
| 4.1 | Add markdown rendering — code blocks, bold, italic, links, lists | `chat_components.ex`, add `earmark` dep |
| 4.2 | Syntax-highlighted code blocks with copy button | `chat_components.ex`, `app.css` |
| 4.3 | Enlarge message max_length (500 → 5000), auto-expanding textarea | `message.ex`, JS hook |
| 4.4 | Citation/source rendering support | `chat_components.ex` |

#### 4.1 — Markdown rendering

Add `{:earmark, "~> 1.4", hex: :earmark}` to deps. Render message body through Earmark before display (sanitized).

```elixir
def render_body(assigns) do
  ~H"""
  <div class="prose prose-sm max-w-none">
    {raw(Earmark.as_html!(@message.body, %Earmark.Options{code_class_prefix: "language-"}))}
  </div>
  """
end
```

Also add `{:makeup, "~> 1.1"}` and `{:makeup_elixir, "~> 0.1"}` for syntax highlighting in fenced code blocks.

#### 4.3 — Auto-expanding textarea JS hook

```javascript
const AutoResize = {
  mounted() {
    this.resize();
    this.el.addEventListener("input", () => this.resize());
  },
  resize() {
    this.el.style.height = "auto";
    this.el.style.height = this.el.scrollHeight + "px";
  }
};
```

---

### Phase 5: Micro-Interactions & Animations

**Goal**: Delightful polish.

| Step | Task | Files |
|------|------|-------|
| 5.1 | Smooth sidebar expand/collapse transition | `app.css` |
| 5.2 | Staggered enter/exit message animations | `app.css` |
| 5.3 | Hover states — cards, actions, buttons | `chat_components.ex` |
| 5.4 | Focus states — input, buttons, interactive | `app.css` |
| 5.5 | Loading skeletons for conversation list & messages | `chat_components.ex` |

#### 5.2 — Staggered message arrival

```css
#messages > div {
  animation: message-in 0.3s ease-out both;
}

#messages > div:nth-child(1) { animation-delay: 0ms; }
#messages > div:nth-child(2) { animation-delay: 50ms; }
#messages > div:nth-child(3) { animation-delay: 100ms; }
```

Use a JS hook to assign dynamic `--index` custom property for arbitrary-length stagger:

```css
#messages > div {
  animation: message-in 0.3s ease-out both;
  animation-delay: calc(var(--stagger-index, 0) * 50ms);
}
```

#### 5.5 — Loading skeletons

```html
<div class="space-y-4 p-4 animate-pulse">
  <div class="flex gap-3 items-start">
    <div class="size-8 bg-base-300 rounded-full" />
    <div class="flex-1 space-y-2">
      <div class="h-4 bg-base-300 rounded w-3/4" />
      <div class="h-4 bg-base-300 rounded w-1/2" />
    </div>
  </div>
  <div class="flex gap-3 items-start justify-end">
    <div class="flex-1 space-y-2">
      <div class="h-4 bg-base-300 rounded w-2/3" />
    </div>
    <div class="size-8 bg-base-300 rounded-full" />
  </div>
</div>
```

---

### Phase 6: Empty, Error & Edge States

**Goal**: Every state has a polished representation.

| Step | Task | Files |
|------|------|-------|
| 6.1 | "No conversations" — illustration + CTA | `chat_live/index.ex`, `inbox_live/index.ex` |
| 6.2 | "No messages" — illustration with starter prompt | `chat_live/show.ex`, `inbox_live/show.ex` |
| 6.3 | Loading conversation — skeleton UI | `chat_live/show.ex`, `inbox_live/show.ex` |
| 6.4 | Error loading — retry action | `chat_live/show.ex`, `inbox_live/show.ex` |
| 6.5 | Network disconnected banner | `layouts.ex`, `root.html.heex` |
| 6.6 | Agent unavailable — offline avatar state | `chat_components.ex` |

---

### Phase 7: Mobile Experience

**Goal**: Fully responsive.

| Step | Task | Files |
|------|------|-------|
| 7.1 | Mobile sidebar — slide-over drawer | `inbox_live/index.ex`, `inbox_live/show.ex` |
| 7.2 | Touch-friendly — larger tap targets | `chat_components.ex` |
| 7.3 | Proper keyboard behavior | `app.css`, JS hooks |
| 7.4 | Safe-area support enhancement | `app.css` |
| 7.5 | Responsive breakpoints for all layouts | All templates |

---

### Phase 8: Accessibility

**Goal**: WCAG-compliant.

| Step | Task | Files |
|------|------|-------|
| 8.1 | Keyboard navigation — tab order, escape, arrow keys | JS hooks |
| 8.2 | ARIA attributes — live regions, roles, labels | All templates |
| 8.3 | Screen reader support — status announcements | All templates |
| 8.4 | Focus management — trap/restore | JS hooks |
| 8.5 | Color contrast audit | `app.css`, themes |

---

### Phase 9: Performance

**Goal**: Smooth at scale.

| Step | Task | Files |
|------|------|-------|
| 9.1 | Message virtualization — render only visible | New component + JS |
| 9.2 | Debounced search | `inbox_live/index.ex` |
| 9.3 | Paginate messages (batches of 50) | `message.ex`, LiveViews |
| 9.4 | Reduce re-renders — static assigns, `:let` caching | All LiveViews |
| 9.5 | Lazy-load heavy components | `chat_components.ex` |

---

### Phase 10: Streaming AI Responses (Future)

**Goal**: Real-time token-by-token rendering.

| Step | Task | Files |
|------|------|-------|
| 10.1 | Regenerate response action | `chat_live/show.ex`, `inbox_live/show.ex` |
| 10.2 | Token-by-token via PubSub channel | JS hook, LiveViews |
| 10.3 | Streaming indicator — shimmer effect | `chat_components.ex`, `app.css` |

---

## Architecture Decisions

### Refactoring Strategy: ChatComponents Module

Create a single `AshDeskWeb.ChatComponents` module that houses all shared chat UI. Both `ChatLive.Show` and `InboxLive.Show` render through these components, eliminating the current duplication.

```
lib/ash_desk_web/components/
├── layouts.ex              ← Updated sidebar slot support
├── core_components.ex      ← Unchanged
├── chat_components.ex      ← NEW: message_bubble, conversation_card,
                               presence_indicators, typing_indicator,
                               status_badge, message_input, empty_state,
                               loading_skeleton
├── layouts/
│   └── root.html.heex      ← Unchanged
```

### Shared Helpers

```
lib/ash_desk_web/
├── helpers.ex              ← NEW: relative_time/1, format_datetime/1
```

### JS Hooks

```
assets/js/hooks/
├── typing_indicator.js     ← Enhanced: enter-to-send, auto-resize
├── auto_scroll.js          ← NEW: intelligent auto-scroll
├── message_actions.js      ← NEW: copy, feedback
```

### Message Model Extension

```
message.ex additions:
- status: :string (sending, sent, failed) — for optimistic updates
- feedback: :atom (thumbs_up, thumbs_down, nil)
- parent_message_id: :uuid — for threading/editing
```

---

## Success Criteria

After implementation:

- [ ] The chat feels like a modern premium SaaS product (Intercom, Crisp, ChatGPT)
- [ ] No code is duplicated between Chat and Inbox Show views
- [ ] All existing functionality preserved (no regressions)
- [ ] Messages render with proper markdown + code highlighting
- [ ] Optimistic updates make sending feel instant
- [ ] Auto-scroll works intelligently (not when user is reading history)
- [ ] Typing indicator is smooth and shows agent names
- [ ] Unread indicators visible on conversation list
- [ ] Search finds conversations in real-time
- [ ] Mobile layout is fully usable — sidebar as drawer
- [ ] Keyboard navigation works end-to-end
- [ ] Loading skeletons shown during data fetch
- [ ] Empty/error states are polished with CTAs
- [ ] Animations are subtle and respect `prefers-reduced-motion`
- [ ] All tests pass
