# AshDesk — Realtime Support Inbox (Intercom-lite MVP)

Multi-tenant realtime support inbox SaaS using Phoenix LiveView + Ash.

---

## Architecture

### Domains

| Domain | Purpose |
|--------|---------|
| `Accounts` | User auth (AshAuthentication: password + confirmation + remember me) |
| `Organizations` | Multi-tenancy via `Organization` + `Membership` (roles: admin, agent, customer) |
| `Support` | Core product: `Conversation` + `Message` |

### Multi-tenancy

Strategy: `attribute` on `organization_id`. All support resources and memberships are scoped to an org.

### Authorization

Ash Policy Authorizer on all resources. Key rules:

| Resource | Rule |
|----------|------|
| **User** | Bypass for AshAuth interactions. Any authenticated user can read. |
| **Conversation** — Read | Org admin, assigned agent, or the customer who owns it. |
| **Conversation** — Create | Org member or the customer (self-create). |
| **Conversation** — Update/Destroy | Org admin only. |
| **Message** — Read | Org admin, assigned agent, or the conversation's customer. |
| **Message** — Create | Org admin, assigned agent, or the conversation's customer. |
| **Membership** — Create | Any authenticated user (MVP — tighten to admin later). |

---

## Data Model

### User (`accounts/user.ex`)

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID (PK) | |
| `email` | `:ci_string` | Unique, public, not-null |
| `hashed_password` | `:string` | Sensitive, not-null |
| `confirmed_at` | `:utc_datetime_usec` | Nullable |

Auth: password strategy + confirmation + remember me + reset.

### Organization (`organizations/organization.ex`)

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID (PK) | |
| `name` | `:string` | Not-null |
| `slug` | `:string` | Unique, auto-generated via AshSlug |

### Membership (`organizations/membership.ex`)

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID (PK) | |
| `role` | `:atom` | `:admin`, `:agent`, or `:customer` |
| `user_id` | UUID (FK → User) | |
| `organization_id` | UUID (FK → Organization) | Multi-tenant |

Identity: unique on `[user_id, organization_id]`.

### Conversation (`support/conversation.ex`)

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID (PK) | |
| `subject` | `:string` | Nullable |
| `status` | `:atom` | `:open`, `:pending`, `:resolved`. Default `:open`. |
| `customer_id` | UUID (FK → User) | The customer who started the conversation |
| `assigned_agent_id` | UUID (FK → User) | Nullable. Agent currently handling it |
| `organization_id` | UUID (FK → Organization) | Multi-tenant |

Actions:
- `defaults [:read, :destroy, create: [...], update: [...]]`
- `list_assigned_to` — filter by `agent_id`, loads `[:assigned_agent]`
- `list_for_customer` — filter by `customer_id`, sorted by `created_at: :desc`
- `create_by_customer` — creates conversation with `customer_id` set from actor

PubSub notifications:
- `conversation:meta:{id}` — on `:update`
- `org:conversations:{organization_id}` — on `:create`

### Message (`support/message.ex`)

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID (PK) | |
| `body` | `:string` | Max 500 chars, not-null |
| `sender_id` | UUID (FK → User) | Not-null. Set via `SetSenderChange` from actor |
| `conversation_id` | UUID (FK → Conversation) | |

Actions:
- `defaults [:read]`
- `create` — accepts `[:body, :conversation_id]`, sets sender from actor
- `list_messages_for_conversation` — filter by `conversation_id`, loads `[:sender]`

PubSub notifications:
- `conversation:messages:{conversation_id}` — on `:create`, loads `[sender: [:email]]`

---

## LiveView Pages

### Agent Inbox — `/inbox`

**Index** (`InboxLive.Index`)
- Lists conversations for the current agent/org
- Admins see all conversations; agents see only assigned
- Subscribes to `org:conversations:{org_id}` for realtime inserts
- Stream-based rendering

**Show** (`InboxLive.Show`)
- Full conversation view with message stream
- Send message form (textarea + submit)
- Realtime message insertion via PubSub
- Agent assignment dropdown (admin only)
- **Presence tracking** — shows online users in conversation
- **Typing indicator** — shows which agents are typing (animated dots)
- Subscribes to 3 PubSub topics: `conversation:messages:{id}`, `conversation:meta:{id}`, `conversation:{id}` (presence)

### Customer Portal — `/chat`

**Index** (`ChatLive.Index`)
- Lists the customer's own conversations
- "New Conversation" button with subject input
- Uses `list_conversations_for_customer`

**Show** (`ChatLive.Show`)
- Conversation view for the customer
- Message sending (simplified, no agent controls)
- Realtime message updates via PubSub subscription
- No assignment UI, no agent-facing features

---

## Realtime Architecture

```
┌──────────────┐     Ash Notifier      ┌──────────────┐
│  Ash Resource │ ──────────────────▶  │  Phoenix      │
│  (Message,    │   PubSub publish     │  PubSub       │
│  Conversation)│                      │  (AshDesk     │
└──────────────┘                      │   .PubSub)    │
                                       └──────┬───────┘
                                              │
                                ┌─────────────┴─────────────┐
                                │                           │
                    ┌───────────▼────┐           ┌──────────▼──────┐
                    │ Agent Inbox    │           │ Customer Portal  │
                    │ LiveView       │           │ LiveView         │
                    │ (subscribes)   │           │ (subscribes)     │
                    └────────────────┘           └─────────────────┘
```

### PubSub Topics

| Topic Pattern | Payload | Publisher |
|---|---|---|
| `org:conversations:{org_id}` | `%Notification{data: conversation}` | Conversation create |
| `conversation:messages:{conv_id}` | `%Notification{data: message}` (with loaded sender) | Message create |
| `conversation:meta:{conv_id}` | `%Notification{data: conversation}` (with loaded assigned_agent) | Conversation update |
| `conversation:{conv_id}` | Presence diff | Presence |
| `conversation:typing:{conv_id}` | `%{user_id, email, typing: true/false}` | LiveView (manual) |

### Presence

- Tracked per-conversation topic: `conversation:{conv_id}`
- Metadata: `email`, `joined_at`
- Used to show online users in conversation header (up to 3 avatars + count)

### Typing Indicator Flow (Agents Only)

1. JS colocated hook on message textarea detects keystroke
2. Debounce: push `typing_start` immediately, then debounce subsequent events (300ms)
3. On 3 seconds of inactivity, push `typing_stop`
4. LiveView broadcasts to `conversation:typing:{conv_id}` PubSub topic
5. All agent subscribers receive the event and update `@typing_users` assign
6. UI shows "Agent is typing..." with animated dots
7. Stale cleanup: remove users not heard from in 5 seconds

---

## Routes

```
# Authenticated (agent)
GET  /inbox               → InboxLive.Index  :index
GET  /inbox/:id           → InboxLive.Show   :show

# Authenticated (customer)
GET  /chat                → ChatLive.Index   :index
GET  /chat/:id            → ChatLive.Show    :show

# Unauthenticated
GET  /                    → PageController   :home
      /auth/*             → AuthController
      /sign-in            → SignInLive
      /register           → RegisterLive
      /reset              → ResetLive
      /confirm            → ConfirmLive
```

Agent routes use `ash_authentication_live_session :authenticated_routes`.
Customer routes use `ash_authentication_live_session :customer_routes` (or same session with role-based filtering).

---

## Week 3 — Remaining Work

1. **Policies** — Add customer access to Conversation and Message resources
2. **Customer Registration** — Auto-create Membership with `:customer` role on first customer login
3. **ChatLive.Index** — Customer conversation list + new conversation form
4. **ChatLive.Show** — Customer conversation view with realtime messages
5. **Typing Indicator** — JS hook + LiveView handlers + PubSub + UI (agents only)
6. **Codegen** — `mix ash.codegen week3_customer_portal` (if any migration needed)

---

## Week 4 — Polish + SaaS Quality (Deferred)

- Admin dashboard (ash_admin already installed — mount in routes)
- Filters in inbox (open/pending/resolved) — use Cinder
- Assignment UX improvements (drag-and-drop, inline status toggle)
- UI polish (animations, empty states, responsive layout)
- README + architecture diagram
