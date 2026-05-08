# T3 Code for iOS

T3 Code is a native iOS client for the T3 Code desktop server. It connects to your Mac over WebSocket and gives you a mobile interface to your AI coding agents — create threads, send prompts, attach images, and receive streaming responses in real time.

## Overview

|                     |                                                                              |
| ------------------- | ---------------------------------------------------------------------------- |
| **Platform**        | iOS 17+ (iPhone, iPad)                                                       |
| **UI Framework**    | SwiftUI                                                                      |
| **Reactivity**      | Swift `@Observable` (Observation framework)                                  |
| **Networking**      | WebSocket via `URLSessionWebSocketTask` + custom Effect RPC protocol         |
| **Auth**            | Bearer token obtained through pairing with the desktop app, stored in Keychain |
| **Minimum Target**  | iOS 17.0                                                                     |
| **Bundle ID**       | `com.belweave.T3-Code`                                                       |

## How It Works

1. **Pairing** — Open the desktop T3 Code app, go to Settings → Connections → Network access, and copy the pairing URL.
2. **Connect** — Paste the URL (or manually enter the server URL + one-time token) in the iOS app. The app exchanges the one-time token for a long-lived bearer token over HTTPS and stores it in the Keychain.
3. **Streaming** — Once paired, the app opens a WebSocket to the server at `/ws` and maintains a persistent connection with automatic heartbeat/keep-alive.
4. **Real-time sync** — The app subscribes to `orchestration.subscribeShell` (projects + threads list) and `orchestration.subscribeThread` (individual thread messages + events). All data updates stream in live.
5. **Sending messages** — Text and optional image attachments (via PhotosPicker) are dispatched through `orchestration.dispatchCommand` with the `thread.turn.start` command. Responses stream back as `thread.message-sent` events.

## Project Structure

```
T3 Code/
├── T3 Code.xcodeproj/
│   └── project.pbxproj                # Xcode project configuration
├── Info.plist                          # App manifest (permissions, ATS, orientations)
├── T3 Code/
│   ├── T3_CodeApp.swift                # @main app entry point
│   ├── Assets.xcassets/                # App icon, accent color assets
│   ├── App/
│   │   ├── AppRoot.swift               # Root view — routes based on session state (paired / unpaired)
│   │   ├── MainTabView.swift           # 5-tab navigation: Projects, Plan, Chat, Files, Settings
│   │   ├── AppEnvironment.swift        # @Observable global session & connection state
│   │   └── AppPreferences.swift        # Enums for appearance, accent, transcript density, composer size
│   ├── Core/
│   │   ├── Models/
│   │   │   ├── Identifiers.swift       # ThreadID, ProjectID, MessageID, TurnID, CommandID, ProviderInstanceID
│   │   │   ├── Message.swift           # Message, MessageRole, ChatImageAttachment, ISO8601DateFormatter
│   │   │   ├── Thread.swift            # ThreadShell, ThreadDetail, OrchestrationSession, LatestTurn, ProjectShell
│   │   │   ├── ModelSelection.swift     # ModelSelection, ProviderOptionSelection, ProviderOptionValue
│   │   │   ├── ServerConfig.swift       # ServerRuntimeConfig, ServerProvider, ServerProviderModel
│   │   │   ├── EnvironmentDescriptor.swift  # Server environment bootstrap descriptor
│   │   │   └── ServerEvent.swift        # ShellStreamItem, ThreadStreamItem, ThreadEvent decoding
│   │   ├── Networking/
│   │   │   ├── T3Connection.swift       # Actor-managed WebSocket with heartbeat, reconnect, status stream
│   │   │   ├── T3Client.swift           # Actor-managed RPC client: request, subscribe, dispatch turn
│   │   │   ├── EffectRPC.swift          # Effect RPC message protocol encoder / decoder
│   │   │   └── Auth/
│   │   │       ├── PairingFlow.swift    # HTTPS pairing: environment fetch, token exchange, WS token issuance
│   │   │       └── KeychainStore.swift  # Secure credential storage (bearer token, server URL)
│   │   └── Stores/
│   │       ├── ThreadListStore.swift    # @Observable store — subscribes to shell stream, holds projects & threads
│   │       └── ThreadStore.swift        # @Observable store — subscribes to thread stream, holds messages & session
│   ├── DesignSystem/
│   │   ├── T3Color.swift                # Semantic color tokens (surface, text, separator, status) with dark mode
│   │   ├── T3Typography.swift           # Type scale using DM Sans (falls back to system), code font variants
│   │   ├── T3Spacing.swift              # Spacing & radius tokens (xxs…xxxl, sm…xl)
│   │   └── Components/
│   │       ├── MessageBubble.swift       # Chat bubble with role header, Markdown body, streaming dots
│   │       ├── ConnectionPill.swift      # Capsule indicator showing connection status (offline/connecting/connected/error)
│   │       ├── PrimaryButton.swift       # Filled + outlined button styles
│   │       └── StreamingDots.swift       # Animated three-dot "typing" indicator
│   └── Features/
│       ├── Connection/
│       │   └── ConnectionSetupView.swift  # Pairing form: server URL, token, paste-link, connect
│       ├── Threads/
│       │   ├── ThreadsListView.swift      # Plan tab — custom nav bar, project sections, active thread list
│       │   ├── ThreadRow.swift            # Thread row: icon, title, model, branch, relative date, status
│       │   └── NewThreadView.swift        # Thread creation form: project picker, prompt, model, mode, access
│       ├── Thread/
│       │   ├── ThreadView.swift           # Thread detail container — timeline + composer, nav bar title
│       │   ├── MessageTimelineView.swift  # Lazy scrollable message list with auto-scroll to bottom
│       │   └── ComposerView.swift         # Message input: text editor, image picker, send button
│       └── Settings/
│           └── SettingsView.swift         # Appearance, accent, transcript density, composer size, server, sign out
```

## Architecture Decisions

### @Observable State Management

All state is managed through Swift's `@Observable` macro rather than `@ObservableObject` / `@StateObject` / Combine. Three main stores:

| Store              | Scope         | Holds                                                                 |
| ------------------ | ------------- | --------------------------------------------------------------------- |
| `AppEnvironment`   | Global        | Session state, connection status, `T3Client`, `T3Connection`, `ServerRuntimeConfig` |
| `ThreadListStore`  | Global        | `[ProjectShell]`, `[ThreadShell]`, subscribes to `orchestration.subscribeShell` |
| `ThreadStore`      | Per-thread    | `ThreadDetail`, `[Message]`, `OrchestrationSession`, subscribes to `orchestration.subscribeThread` |

`AppEnvironment` is injected via `.environment(env)` and accessed with `@Environment(AppEnvironment.self)`.

### Actor-Isolated Networking

Both `T3Connection` and `T3Client` are Swift `actor` types, ensuring thread-safe access to WebSocket state, pending response continuations, and stream subscribers.

- **T3Connection** manages the raw WebSocket lifecycle: connect, disconnect, heartbeat loop (every 5s), receive loop, send.
- **T3Client** sits one layer above — it manages request/response matching via `withCheckedThrowingContinuation`, stream subscriptions with per-requestId callbacks, and demultiplexes inbound `EffectRPCMessage` frames.

### Effect RPC Protocol

The app communicates with the T3 Code server over a single WebSocket using a custom Effect RPC framing:

- **Outbound**: `Request` (id, tag, payload), `Interrupt`, `Ack`, `Ping`, `Pong`, `Eof`
- **Inbound**: `Chunk` (streamed values), `Exit` (success/failure terminal), `Defect` (fatal error), `Ping`, `Pong`

Each request gets a unique ID. Responses are matched by request ID. Stream subscriptions receive `Chunk` frames and must acknowledge with `Ack`.

### Streaming Events

Two persistent subscriptions drive the UI:

1. **Shell stream** (`orchestration.subscribeShell`) — delivers initial `snapshot` of all projects and threads, then incremental `project-upserted`, `project-removed`, `thread-upserted`, `thread-removed` events.
2. **Thread stream** (`orchestration.subscribeThread`) — delivers a `snapshot` with full `ThreadDetail` (including messages), then incremental events like `thread.message-sent` (new/updated message) and `thread.session-set` (session status changes).

### Auth Flow

```
[Desktop App] → generates pairing URL with ?token=... 
                  ↓
[iOS App]     → PairingFlow.parsePairingURL() extracts server URL + token
                  ↓
[iOS App]     → GET /.well-known/t3/environment (validates server)
                  ↓
[iOS App]     → POST /api/auth/bootstrap/bearer (exchanges one-time token for session)
                  ↓
[iOS App]     → Saves bearer token in Keychain via KeychainStore
                  ↓
[iOS App]     → POST /api/auth/ws-token (before each WebSocket connection, issues short-lived WS token)
                  ↓
[iOS App]     → Opens WebSocket to /ws?wsToken=... with Bearer token header
```

Credentials persist across app launches via `KeychainStore` (using `kSecClassGenericPassword` with `kSecAttrAccessibleAfterFirstUnlock`).

### Design System

- **Colors** — Semantic tokens (`T3Color.primary`, `.surface`, `.textPrimary`, `.separator`, etc.) with automatic dark mode via `UIColor(dynamicProvider:)`.
- **Typography** — Uses DM Sans when available (falls back to system), with named styles from `.largeTitle` to `.caption` plus `.code` and `.codeBlock` monospaced variants.
- **Spacing** — Defined as a fixed scale (`xxs`=2, `xs`=4, …, `xxxl`=32) and radius scale (`sm`=6, `md`=10, `lg`=14, `xl`=20).
- **Components** — Reusable: `MessageBubble` (role header + Markdown body + streaming indicator), `ConnectionPill`, `PrimaryButton`/`SecondaryButton`, `StreamingDots`.

## User Preferences (AppStorage)

| Key                 | Type   | Options                                   | Default    |
| ------------------- | ------ | ----------------------------------------- | ---------- |
| `appearance`        | String | `system`, `light`, `dark`                 | `system`   |
| `accent`            | String | `blue`, `violet`, `green`, `orange`       | `blue`     |
| `transcriptDensity` | String | `compact`, `comfortable`                  | `comfortable` |
| `composerSize`      | String | `compact`, `comfortable`, `expanded`      | `comfortable` |

## Permissions (Info.plist)

| Key                               | Purpose                                                      |
| --------------------------------- | ------------------------------------------------------------ |
| `NSPhotoLibraryUsageDescription`  | Attaching images to messages sent to T3 Code                 |
| `NSLocalNetworkUsageDescription`  | Connecting to the T3 Code desktop server on LAN or Tailscale |
| `NSAppTransportSecurity`          | `NSAllowsArbitraryLoads` enabled to allow HTTP connections to local servers |

## Building

1. Open `T3 Code.xcodeproj` in Xcode 15.4+.
2. Select the **T3 Code** scheme and a connected iOS 17 device or simulator.
3. The app requires no additional dependencies — it uses only Apple frameworks (SwiftUI, Foundation, Security, PhotosUI).
4. Press **Run**.

## Key Behaviors

- **Resume session** — If a valid bearer token and server URL exist in the Keychain at launch, the app reconnects automatically without requiring re-pairing.
- **Auto-scroll** — The message timeline scrolls to the bottom when new messages arrive or the last message's text updates during streaming.
- **Keyboard dismissal** — Tapping on the message timeline dismisses the keyboard via `UIApplication.dismissKeyboard()`.
- **Streaming dots** — Shown on the last assistant message when its `streaming` flag is `true`.
- **Refreshable** — The thread list supports pull-to-refresh, though data is live-streamed and refresh is a no-op.
- **Error handling** — Network errors surface through `connectionStatus.detail`, RPC errors through `ThreadStore.lastError`, and pairing errors through the connection setup form.

## Data Models

### Enums
- `MessageRole` — `user`, `assistant`, `system`
- `RuntimeMode` — `approvalRequired`, `autoAcceptEdits`, `fullAccess`
- `ProviderInteractionMode` — `default`, `plan`
- `SessionStatus` — `idle`, `starting`, `running`, `ready`, `interrupted`, `stopped`, `error`
- `LatestTurnState` — `running`, `interrupted`, `completed`, `error`
- `ConnectionState` — `offline`, `connecting`, `connected`, `error(String)`

### Structs
- `ThreadID`, `ProjectID`, `MessageID`, `TurnID`, `CommandID`, `ProviderInstanceID` — strongly-typed wrapper IDs
- `ThreadShell` — lightweight thread summary from shell stream
- `ThreadDetail` — full thread with embedded messages array
- `Message` — individual chat message with role, text, attachments, streaming flag
- `ChatImageAttachment` — metadata for attached images
- `ProjectShell` — project summary with title, workspace root
- `OrchestrationSession` — current session status, provider, runtime mode, active turn
- `LatestTurn` — state of the most recent turn
- `ModelSelection` — provider instance + model slug + options
- `ServerRuntimeConfig` / `ServerProvider` / `ServerProviderModel` — server capability descriptors
- `UploadImage` — local image prepared for upload (name, mimeType, base64 data URL)
- `ShellSnapshot`, `ShellStreamItem`, `ThreadStreamItem`, `ThreadEvent` — streaming event types

## Limitations

- **Files tab** — Currently a placeholder ("File browsing coming soon").
- **No offline mode** — The app requires a live WebSocket connection to function.
- **Single server** — Only one server configuration is stored at a time.
- **Image only** — Attachments are limited to images (PhotosPicker with `.images` filter).
