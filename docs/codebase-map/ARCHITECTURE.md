# Architecture

Verified from source at HEAD c0da268a on branch main. Osaurus is a macOS SwiftUI application whose large OsaurusCore Swift package owns most UI, services, models, networking, tools, and storage code. The package boundaries are useful, but they are not a strict UI/domain/runtime layering inside OsaurusCore.

## Repository and targets

- The app entry point is [App/osaurus/osaurusApp.swift](../../App/osaurus/osaurusApp.swift), in the Xcode project [App/osaurus.xcodeproj](../../App/osaurus.xcodeproj). Xcode targets are osaurus, osaurusTests, and osaurusUITests. The app target depends on the OsaurusCore package product.
- The shared workspace is [osaurus.xcworkspace](../../osaurus.xcworkspace); it references the app project and the OsaurusCore, OsaurusCLI, and OsaurusRepository packages.
- [Packages/OsaurusCore/Package.swift](../../Packages/OsaurusCore/Package.swift) provides library target OsaurusCore, executable osaurus-plugin-host, and support/test targets OsaurusSQLCipher, OsaurusObjCSupport, and OsaurusCoreTests.
- [Packages/OsaurusCLI/Package.swift](../../Packages/OsaurusCLI/Package.swift) provides executable OsaurusCLI, library OsaurusCLICore, and OsaurusCLITests.
- [Packages/OsaurusEvals/Package.swift](../../Packages/OsaurusEvals/Package.swift) provides OsaurusEvalsKit, executable OsaurusEvalsCLI (product osaurus-evals), and OsaurusEvalsKitTests.
- Smaller packages are OsaurusNetworking / OsaurusNetworkingTests, OsaurusRepository / OsaurusRepositoryTests, OsaurusPluginTestKit / OsaurusPluginTestKitTests, and OsaurusStatsPack / OsaurusStatsPackTests in [Packages/OsaurusPlugins/StatsPack/Package.swift](../../Packages/OsaurusPlugins/StatsPack/Package.swift).
- Runtime dependencies including vmlx-swift are declared in OsaurusCore's package manifest. Runtime behavior still needs to be traced through OsaurusCore's adapter and policy code; dependency internals are not duplicated here.

The top-level source structure is: App for the app shell and intents; Packages for product/package code; docs for guides and engineering records; scripts for build, CI, eval, and live-proof tooling; .github/workflows for hosted CI. Relevant OsaurusCore source groups include Views, Managers, Models, Services, Tools, Networking, Storage, Identity, Browser, ComputerUse, and Resources/Guide.

## Layer responsibilities

- App shell: [osaurusApp.swift](../../App/osaurus/osaurusApp.swift) is the process entry and SwiftUI App; [AppDelegate.swift](../../Packages/OsaurusCore/AppDelegate.swift) coordinates app startup, server and service initialization, and window presentation.
- UI and session coordination: [ChatWindowManager.swift](../../Packages/OsaurusCore/Managers/Chat/ChatWindowManager.swift) owns chat windows/tabs; [ChatView.swift](../../Packages/OsaurusCore/Views/Chat/ChatView.swift) contains ChatSession and coordinates sends and transcript lifecycle; [FloatingInputCard.swift](../../Packages/OsaurusCore/Views/Chat/FloatingInputCard.swift) owns composer UI.
- Request orchestration: [SystemPromptComposer.swift](../../Packages/OsaurusCore/Services/Chat/SystemPromptComposer.swift) composes prompt context and tool specs; [ChatEngine.swift](../../Packages/OsaurusCore/Services/Chat/ChatEngine.swift) resolves inference routes and streams/completes requests.
- Inference services: [ModelService.swift](../../Packages/OsaurusCore/Services/Inference/ModelService.swift) defines ModelService and routing; [MLXService.swift](../../Packages/OsaurusCore/Services/Inference/MLXService.swift) adapts local generation; [ModelRuntime.swift](../../Packages/OsaurusCore/Services/ModelRuntime.swift) coordinates local runtime lifecycle and generation; [RemoteProviderService.swift](../../Packages/OsaurusCore/Services/Provider/RemoteProviderService.swift) adapts configured remote providers. [Services/ModelRuntime](../../Packages/OsaurusCore/Services/ModelRuntime) contains load coordination, batch adapter, residency, and event policy support.
- Tool execution: [AgentToolLoop.swift](../../Packages/OsaurusCore/Services/Chat/AgentToolLoop.swift) centralizes loop policy; surface-specific closures build messages, run model steps, approve/execute tools, and append outcomes. [ToolRegistry.swift](../../Packages/OsaurusCore/Tools/ToolRegistry.swift) owns registration, exposure snapshots, permissions, and execution dispatch.
- Durable state: Models and Managers own typed state/configuration interfaces; [Storage](../../Packages/OsaurusCore/Storage) owns database and encryption primitives. Chat persistence uses [ChatSessionStore.swift](../../Packages/OsaurusCore/Models/Chat/ChatSessionStore.swift) and [ChatHistoryDatabase.swift](../../Packages/OsaurusCore/Storage/ChatHistoryDatabase.swift); HTTP/plugin transcript persistence also uses [ChatHistoryWriter.swift](../../Packages/OsaurusCore/Storage/ChatHistoryWriter.swift).

## Chat → model → tool → result → UI

1. AppDelegate presents a chat window through ChatWindowManager. ChatWindowManager mounts ChatView with its ChatSession.
2. ChatSession.send in ChatView validates turn controls, captures the session/model context, and composes a live context with SystemPromptComposer.composeChatContext. The composer reads agent/project/config state and resolves tool specifications.
3. ChatSession builds a request and calls the injected ChatEngineProtocol. Production construction uses ChatEngine.
4. ChatEngine prepares generation parameters and resolves a ModelRoute through ModelServiceRouter. Explicit provider-prefixed models can resolve to connected remote services; local services include FoundationModelService and MLXService. A selected remote-agent run targets its selected provider by provider identity.
5. Streaming deltas/events return to ChatView, which updates turn content and activity state. When the model returns tool calls, ChatSession invokes AgentToolLoop with surface-owned hooks.
6. ToolRegistry validates the request-scoped tool exposure and permission state, then invokes the registered tool. The result is normalized and added to conversation history for the next model iteration.
7. The loop returns a final or surfaced incomplete result; ChatSession finalizes turn state, settles tool activity, updates visible message blocks, and saves session data. MessageThreadView, NativeMessageCellView, and NativeToolCallGroupView render that state.

HTTP and plugin execution enter through different surfaces. [OsaurusServer.swift](../../Packages/OsaurusCore/Networking/OsaurusServer.swift) installs [HTTPHandler.swift](../../Packages/OsaurusCore/Networking/HTTPHandler.swift), which routes OpenAI-compatible, Responses, and agent-run requests. Plugin calls enter through PluginHostAPI. These surfaces can reuse ChatEngine, AgentToolLoop, ToolRegistry, and ChatHistoryWriter, but each surface still owns its request/history, streaming, and error hooks. Check the relevant policy/configuration before assuming chat UI semantics apply headlessly.

## Local versus remote inference

ChatEngine's ModelServiceRouter examines local and remote ModelService candidates. Local model discovery and downloads are centered in ModelManager and model download services; actual local loading/generation is in MLXService and runtime support. RemoteProviderManager creates connected RemoteProviderService instances, which handle provider-specific transport, streaming, cancellation, and request encoding. Osaurus Router and paired remote-agent flows have additional identity, spend, and endpoint rules. A model picker or provider setting alone does not establish which route a request took.

## Configuration and persistence

Configuration has several owners, not one global file:

- AppConfiguration caches ChatConfiguration and provides load/update notifications.
- ServerConfigurationStore persists server settings; ServerRuntimeSettingsStore manages runtime-facing server state.
- AgentStore and DefaultAgentConfigurationStore persist agent-specific state.
- RemoteProviderManager, MCPProviderManager, SearchProviderManager, ToolConfigurationStore, and other domain stores own their respective provider/tool state. Secret material is resolved from Keychain-backed services rather than treated as ordinary public configuration.
- Settings UI edits these domain interfaces. SettingsSearchIndex is the navigation/search catalog, not the runtime store.
- Chat, memory, knowledge, agent, and billing data use domain databases under Storage, with shared encryption/open/migration services where configured. Do not assume all state is persisted through UserDefaults or AppConfiguration.

## Existing architecture guides

[CONTRIBUTING.md](../CONTRIBUTING.md) describes intended layer placement, but its directory inventory is not exact on this checkout: it lists Views/Work, while the source tree has Views/Workspaces and no Views/Work. [AGENT_LOOP.md](../AGENT_LOOP.md)'s shared-driver description matches the current AgentToolLoop owner and surface-supplied hooks. [INFERENCE_RUNTIME.md](../INFERENCE_RUNTIME.md)'s high-level local path matches the current ModelRuntime.swift → MLXBatchAdapter → GenerationEventMapper sources. Recheck its detailed cache/default values against live source and settings before relying on them. Provider, search, memory, knowledge, browser, plugin, and sandbox guides are topic-specific; check their source links and current code for details. Dated proof docs describe the commit/model/settings named in each report and should not be read as evergreen runtime guarantees.
