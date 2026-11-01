# Dependency Map

This page records the important cross-layer paths verified at HEAD c0da268a. The owner listed as source of truth is where a value or decision is defined/persisted; nearby views and previews may hold derived state.

## Source of truth and derived state

| Concern | Source of truth / owner | Derived or consuming state | Trace when changing |
|---|---|---|---|
| Chat defaults | [ChatConfiguration](../../Packages/OsaurusCore/Models/Chat/ChatConfiguration.swift) persisted through [AppConfiguration](../../Packages/OsaurusCore/Models/Configuration/AppConfiguration.swift) | Settings controls, ChatSession's captured turn controls, ChatEngine's resolved generation params | UI binding → store update → captured turn/request → local or remote service |
| Agent-specific model/tools/reasoning | [AgentStore](../../Packages/OsaurusCore/Models/Agent/AgentStore.swift), [AgentGenerationSettings.swift](../../Packages/OsaurusCore/Models/Agent/AgentGenerationSettings.swift), [AgentConfigSnapshot.swift](../../Packages/OsaurusCore/Services/Chat/AgentConfigSnapshot.swift) | composer snapshots, model picker state, composed request | agent edit/save → snapshot → prompt/tool schemas → ChatEngine route |
| Server settings | [ServerConfigurationStore.swift](../../Packages/OsaurusCore/Models/Configuration/ServerConfigurationStore.swift) and [ServerRuntimeSettingsStore.swift](../../Packages/OsaurusCore/Models/Configuration/ServerRuntimeSettingsStore.swift) | ServerView controls, server/runtime consumers | UI save → server restart or live runtime store → API/runtime path |
| Tool registration and permission | [ToolRegistry.swift](../../Packages/OsaurusCore/Tools/ToolRegistry.swift), domain managers, [ToolConfigurationStore.swift](../../Packages/OsaurusCore/Models/Tool/ToolConfigurationStore.swift), [ToolPermissionPolicy.swift](../../Packages/OsaurusCore/Models/Tool/ToolPermissionPolicy.swift) | capability manifest and request tool schemas from SystemPromptComposer | registration → enabled/exposed snapshot → execution scope → permission gate → execute |
| Search providers | [SearchProviderCatalog.swift](../../Packages/OsaurusCore/Models/Configuration/SearchProviderCatalog.swift), provider configuration and [SearchProviderManager.swift](../../Packages/OsaurusCore/Managers/SearchProviderManager.swift) | ordered snapshots passed to SearchEngine; secret values resolved for backend calls | catalog/custom definition → saved config/Keychain → selected backend → normalized hits → extraction |
| Inference route | requested model plus connected services, resolved by [ModelServiceRouter](../../Packages/OsaurusCore/Services/Inference/ModelService.swift) inside ChatEngine | selected ModelService, effective model, generation parameters | requested model/agent identity → route → provider-specific request encoding/runtime admission |
| Prompt and tool schemas | [SystemPromptComposer.swift](../../Packages/OsaurusCore/Services/Chat/SystemPromptComposer.swift), with inputs captured by AgentConfigSnapshot | composed prompt sections, capabilities manifest, tool schema list | input stores and execution mode → composed context → request; separately verify ToolRegistry execution permission |
| Visible chat transcript | ChatSession state and [ChatTurn](../../Packages/OsaurusCore/Models/Chat/ChatTurn.swift) | rendered visible blocks in ChatView/MessageThreadView | stream/tool result → turn updates → visible blocks → finalization |
| Durable chat history | [ChatSessionStore.swift](../../Packages/OsaurusCore/Models/Chat/ChatSessionStore.swift) and [ChatHistoryDatabase.swift](../../Packages/OsaurusCore/Storage/ChatHistoryDatabase.swift); raw HTTP/plugin writes use [ChatHistoryWriter.swift](../../Packages/OsaurusCore/Storage/ChatHistoryWriter.swift) | ChatSessionsManager sidebar cache and rehydrated sessions | turn mapping → DB readiness/encryption/migration → save → manager refresh/reload |
| Memory context | [MemoryConfiguration](../../Packages/OsaurusCore/Models/Memory/MemoryConfiguration.swift), [MemoryContextAssembler.swift](../../Packages/OsaurusCore/Services/Memory/MemoryContextAssembler.swift), MemoryService/MemoryDatabase | one assembled prompt section and search results | memory write/index → relevance/search → context assembly → composed request |
| Knowledge context | Knowledge collections/index/search/write services and KnowledgeDatabase | tools and prompt guidance visible to current agent | collection grants → indexed data → retrieval/write tool → claim grounding |
| Runtime load/residency | [InferenceLoadCoordinator.swift](../../Packages/OsaurusCore/Services/ModelRuntime/InferenceLoadCoordinator.swift), [RuntimeConfig.swift](../../Packages/OsaurusCore/Services/ModelRuntime/RuntimeConfig.swift), [ModelResidencyManager.swift](../../Packages/OsaurusCore/Services/ModelRuntime/ModelResidencyManager.swift) | loaded model/runtime handles, admission and residency telemetry | model bundle/config → runtime plan/admission → load → stream → cancellation/release |

## High-value call chains

### Chat window material and toolbar chrome

`ChatWindowState.theme` → `ChatWindowRootView` preferred color scheme and one window-sized `ChatWindowGlassBackdrop` → `NSWindow.appearance`/opacity and an AppKit `NSVisualEffectView` using `.underWindowBackground` with `.behindWindow`. On macOS 26+, `ChatPanel` uses `.unifiedCompact` with `.unified` as its deployment-compatible fallback; the native titlebar remains AppKit-managed. The permanent rail and full-screen SwiftUI header use `WindowChromeBackground`: clear over the shared backdrop, or `chatWindowChromeSolidFallback` when Reduce Transparency is enabled; the backdrop assigns the same fallback to the NSWindow. `ChatLeftNavigationPanel` and project-only `ProjectInspectorPanel` use the existing `SidebarBackground` surface; it applies the configured sidebar tint over the window-backed material or an opaque theme fallback under Reduce Transparency. `ChatView.chatBackground` places `ThemedBackgroundLayer` inside the 11pt rounded clip on the actual canvas surface; built-in default themes tint the same window-backed material with `primaryBackground` at `chatWindowGlassTintOpacity`, while explicit custom solid, gradient, and image backgrounds retain their configured rendering. Reduce Transparency hides the window effect and uses the theme's solid chrome and canvas fallbacks. No additional window-sized material or blur is introduced.

Titlebar/content geometry: `NSWindow.contentLayoutRect` and the window frame → `ChatWindowManager.titlebarContentInset` → `ChatWindowState.titlebarContentInset` → `ChatView.chatModeContent`. The 58pt navigation rail shares the titlebar backdrop; the Chats/File Changes panel and chat canvas start at the AppKit content boundary. When docked, the canvas begins to the right of the panel; at narrow widths, the panel overlays the canvas without changing its layout width. The canvas background itself retains its 11pt top-leading clip. In windowed mode `chatHeader` contributes only `max(0, 52 - titlebarContentInset)`, so the native inset and transcript spacer do not double-count; in full screen the custom header replaces the toolbar and `chatHeader` contributes zero. Full screen sets the native inset to zero.

### Chat navigation rail, content panel, and toolbar

`ChatWindowState.isLeftPanelOpen` + `leftPanelMode` → `ChatView.chatModeContent` → permanent `SidebarStyle.compactRailWidth` (58pt) rail and an optional 300pt `ChatLeftNavigationPanel` in [ChatNavigationPanel.swift](../../Packages/OsaurusCore/Views/Chat/ChatNavigationPanel.swift). The panel docks beside the rail while the 440pt canvas floor fits; below that threshold it overlays the canvas. Visibility and mode are per-window; the Chats rail button always opens/switches the panel to Chats. `ChatLeftPanelMode` defaults to Chats and remains selected while the panel is closed. One per-view `activeNavigatorFlyout` controls only Projects and Agents, including the `/agent` notification route. Chats reuses `ChatHistoryPaneView`/`ChatHistoryList`/`ChatHistoryWindowActions` with `ChatWindowState.activeScope`; workspace history is filtered by agent address and workspace id. File Changes reuses `FileChangesPanel`, whose existing journal, review, diff, revert, approval, and current-session behavior remain its source of truth. `openChangesPanel(focusing:)` redirects existing inline/deep-link requests to File Changes and carries set focus through a pending session switch. Projects uses the existing `ProjectRow` actions → `ChatView.onOpenProject` → `windowState.openProjectId` → `ProjectDetailView`; `ProjectManager.pendingRevealProjectsTab` opens the Projects flyout. Agent rows retain `switchAgent(to:)`, `switchToWorkspaceAgent(address:workspaceId:)`, and the discovered-agent pairing/connect callback. `windowState.leadingNavigationWidth` reports 58pt while closed/overlaid and 358pt while docked so `ChatTabStripView` aligns to the canvas. The leading toolbar button and ⌘B call `toggleLeftPanel()`; the 58pt rail itself cannot be hidden.

The Credits ring in `ChatSessionSidebar.CreditsRailIndicator` reads the shared [OsaurusRouterAccountService](../../Packages/OsaurusCore/Services/Router/OsaurusRouterAccountService.swift) balance and uses the existing five-minute passive refresh. Its non-persisted baseline/progress state belongs to `ChatWindowState`, so it survives tab-driven `ChatView` remounts but is independent per window. `ChatView` supplies active-session spend/cache details and the existing top-up sheet callback; wallet activity and View All/Add Credits actions remain in `WalletPopover` in [FloatingInputCard.swift](../../Packages/OsaurusCore/Views/Chat/FloatingInputCard.swift). Router enabled/online/identity availability is checked by the rail indicator, while remote-session visibility is passed from `ChatView`.

Persisted-session History requests enter `ChatWindowManager.openHistorySession(_:)`, which selects and opens Chats before focusing or opening the existing session tab. The active session remains the same when only the panel mode changes.

`ChatToolbarDelegate` hosts `ChatTabStripView` and one `ChatToolbarTrailingView`. On chat pages, the trailing group contains New Tab and Pin Window (`ChatWindowManager.setWindowPinned`); there is no right chat History/File Changes inspector or duplicate right-side chat toggle. On project detail pages only, the trailing `sidebar.right` button opens/closes the separate Project Settings panel. The leading toolbar button and ⌘B toggle the Chats/File Changes content panel, while the permanent rail retains Projects, Settings, and agent switching. The macOS full-screen header uses the same routes.

### Chat turn and tool cycle

ChatWindowManager → ChatView/ChatSession.send → SystemPromptComposer.composeChatContext → ChatEngine.streamChat or Responses path → ModelServiceRouter → selected ModelService → ChatSession stream processing → AgentToolLoop → ToolRegistry.execute → result envelope/history → next model step or finalization → ChatSessionStore/ChatHistoryDatabase and transcript views.

For local tool calls, distinguish four boundaries: SystemPromptComposer/capability and tool-choice resolution → ChatEngine and MLXService request dispatch → ModelRuntime/MLXBatchAdapter tool-schema preparation and the pinned upstream vmlx-swift `BatchEngine` parser → GenerationEventMapper and ResponsesGenerationStream (`ResponsesGenerationEvent.swift`) → ChatView.processStreamDeltas → AgentToolLoop hooks → ToolRegistry permission and execution. The vmlx-swift parser implementation is outside the Osaurus source tree; use the local event mapper and policy tests for Osaurus-owned boundaries.

### Headless API and plugin execution

OsaurusServer → HTTPHandler route → API request decoding → ChatEngine and, for agent-run surfaces, AgentToolLoop hooks → ToolRegistry and request scope → streaming/response encoding → ChatHistoryWriter where that endpoint persists history. PluginHostAPI is a separate plugin entry point and should be traced independently for lifecycle, cancellation, and permissions.

### Search

SystemPromptComposer resolves the available search tool specs → ToolRegistry executes WebSearchTool or SearchAndExtractTool → WebSearchTools calls SearchProviderManager's hosted-first coordinator. If hosted search returns hits, its hosted text is passed to result enrichment; on hosted failure/empty results, the manager runs the local SearchEngine provider cascade. WebSearchTools then uses hosted text per URL when present and otherwise calls SearchReadability for local fetch/extraction → extractionEnvelope reports whether page content was retrieved and preserves discovery results as metadata on total extraction failure. SearchEngine/provider backends own hit discovery and are conditional when the reported symptom is correct hits but missing page content.

### MCP and plugin tool exposure

MCPProviderManager connects/discovers tools → MCPProviderTool wrappers register with ToolRegistry → agent configuration and execution mode determine eligible specs → SystemPromptComposer emits the request schema → request-scoped ToolExecutionScope and ToolRegistry permission checks authorize execution → MCP request runs and returns an envelope.

### Configuration to effective request

Settings or agent view → domain model/store (not a duplicated prompt list) → AppConfiguration notification or manager snapshot → ChatSession captures controls/configuration → SystemPromptComposer and ChatEngine prepare request → local or remote consumer. When behavior is stale, identify the first edge where the saved value stops matching the next derived value.

## Registration and feature-gating boundaries

- ToolRegistry is the central runtime registry, but each tool kind has an owning registration path: built-ins, sandbox tools, MCP tools, native plugin tools, and sandbox plugin tools have different managers and lifecycle.
- SystemPromptComposer determines which prompt sections and schemas are sent for a request. ToolRegistry separately checks if the request is permitted to execute a named tool. Preserve both boundaries.
- SearchProviderCatalog defines bundled search definitions; SearchProviderManager combines them with custom configuration and key availability before SearchEngine runs.
- Discovery and extraction are separate search outcomes. `search_and_extract` uses SearchProviderManager hosted-first coordination; SearchReadability owns local page-body retrieval. No direct hosted-first query orchestration test is currently present in the Osaurus test tree.
- The local model tool parser and `.toolCall` emission are owned by the pinned upstream vmlx-swift `BatchEngine`. Osaurus owns tool-schema preparation, request policy, event mapping, response-stream translation, and execution hooks around that dependency boundary.
- ModelServiceRouter resolves a request among available local services and connected remote services. Provider availability and selected remote-agent identity are meaningful inputs, not display-only state.
- SettingsSearchIndex is the single settings search/help catalog. It is not the persisted configuration and not an execution gate.
- Runtime load, admission, residency, and cancellation span ChatEngine, MLXService, and Services/ModelRuntime. A UI badge, model catalog fit hint, or stored preference is not by itself proof that a model loaded or a limit took effect.

## Change propagation

When a shared value changes, follow these consumers before modifying anything:

1. Find its persisted owner and migration/default logic.
2. Find the editor and any view model/cache/snapshot.
3. Find request or prompt composition.
4. Find the runtime/provider consumer and its precedence rules.
5. Find telemetry, cancellation, and finalization paths if they describe the same operation.
6. Find tests at each boundary and add only the tests needed for the changed contract.

For model settings, specifically check model-bundle defaults, explicit request overrides, reasoning/tool mode, cache and concurrency settings, and admission where those inputs share the request. For tool exposure, check both emitted schemas and execution scope. For persistence, distinguish live in-memory state from the database row and rehydration path.
