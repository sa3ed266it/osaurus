//
//  ChatWindowStateNavigationTests.swift
//  osaurusTests
//
//  The permanent navigation rail, per-window Chats / File Changes panel,
//  project-only settings panel, narrow-window overlay decision, and toolbar
//  tab alignment.
//

import Foundation
import Testing

@testable import OsaurusCore

@Suite(.serialized)
@MainActor
struct ChatWindowStateNavigationTests {

    @Test("a fresh window opens on Chats and the panel toggle never hides the rail")
    func defaultPanelAndToggle() async throws {
        try await ChatHistoryTestStorage.run {
            let window = ChatWindowState(windowId: UUID(), agentId: Agent.defaultId)
            defer { window.cleanup() }

            #expect(window.leftPanelMode == .chats)
            #expect(window.isLeftPanelOpen)
            #expect(window.leadingNavigationWidth == 58)

            window.toggleLeftPanel()
            #expect(window.isLeftPanelOpen == false)
            #expect(window.leftPanelMode == .chats)

            window.toggleLeftPanel()
            #expect(window.isLeftPanelOpen)
            #expect(window.leftPanelMode == .chats)
        }
    }

    @Test("mode changes and close/reopen preserve the selected mode and live session")
    func modeAndSessionAreIndependent() async throws {
        try await ChatHistoryTestStorage.run {
            let window = ChatWindowState(windowId: UUID(), agentId: Agent.defaultId)
            defer { window.cleanup() }
            let session = window.session

            window.showLeftPanel(.fileChanges)
            #expect(window.leftPanelMode == .fileChanges)
            #expect(window.isLeftPanelOpen)
            #expect(window.session === session)

            window.toggleLeftPanel()
            #expect(window.isLeftPanelOpen == false)
            #expect(window.leftPanelMode == .fileChanges)
            window.toggleLeftPanel()
            #expect(window.isLeftPanelOpen)
            #expect(window.leftPanelMode == .fileChanges)
            #expect(window.session === session)

            window.showLeftPanel(.chats)
            #expect(window.leftPanelMode == .chats)
            #expect(window.isLeftPanelOpen)
            #expect(window.session === session)
        }
    }

    @Test("a File Changes deep link selects and opens the left panel at its requested set")
    func openChangesPanelFocusesSet() async throws {
        try await ChatHistoryTestStorage.run {
            let window = ChatWindowState(windowId: UUID(), agentId: Agent.defaultId)
            defer { window.cleanup() }
            let setId = UUID()

            window.showLeftPanel(.chats)
            window.openChangesPanel(focusing: setId)
            #expect(window.leftPanelMode == .fileChanges)
            #expect(window.isLeftPanelOpen)
            #expect(window.changesPanelFocusSetId == setId)

            // Reopening without a focus clears any stale row selection.
            window.openChangesPanel()
            #expect(window.leftPanelMode == .fileChanges)
            #expect(window.changesPanelFocusSetId == nil)
        }
    }

    @Test("opening a persisted History session selects Chats in the target window")
    func historySessionOpensChatsPanel() async throws {
        try await ChatHistoryTestStorage.run {
            let manager = ChatWindowManager.shared
            let window = ChatWindowState(windowId: UUID(), agentId: Agent.defaultId)
            defer { window.cleanup() }
            let history = ChatSessionData(
                id: UUID(),
                title: "History panel route",
                turns: [ChatTurnData(role: .user, content: "Question")],
                agentId: Agent.defaultId
            )

            window.showLeftPanel(.fileChanges)
            manager.withRegisteredWindowStateForTesting(window) {
                manager.openHistorySession(history)
                #expect(window.leftPanelMode == .chats)
                #expect(window.isLeftPanelOpen)
                #expect(window.session.sessionId == history.id)
            }
        }
    }

    @Test("each chat window owns independent panel mode and visibility")
    func panelStateIsPerWindow() async throws {
        try await ChatHistoryTestStorage.run {
            let first = ChatWindowState(windowId: UUID(), agentId: Agent.defaultId)
            let second = ChatWindowState(windowId: UUID(), agentId: Agent.defaultId)
            defer {
                first.cleanup()
                second.cleanup()
            }

            first.showLeftPanel(.fileChanges)
            first.toggleLeftPanel()
            #expect(first.leftPanelMode == .fileChanges)
            #expect(first.isLeftPanelOpen == false)
            #expect(second.leftPanelMode == .chats)
            #expect(second.isLeftPanelOpen)
        }
    }

    @Test("Project Settings remains a separate project-page-only panel")
    func projectSettingsToggle() async throws {
        let defaults = UserDefaults.standard
        let key = ChatWindowState.projectInspectorDefaultsKey
        let previous = defaults.object(forKey: key)
        defer {
            if let previous { defaults.set(previous, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
        defaults.removeObject(forKey: key)

        try await ChatHistoryTestStorage.run {
            let window = ChatWindowState(windowId: UUID(), agentId: Agent.defaultId)
            defer { window.cleanup() }

            #expect(window.showProjectInspector)
            #expect(window.isProjectSettingsOpen == false)
            window.openProjectId = UUID()
            #expect(window.isProjectSettingsOpen)
            window.toggleProjectInspector()
            #expect(window.showProjectInspector == false)
            #expect(window.isProjectSettingsOpen == false)

            // Chats / File Changes state remains independent of project settings.
            window.showLeftPanel(.fileChanges)
            #expect(window.leftPanelMode == .fileChanges)
            #expect(window.isLeftPanelOpen)

            let next = ChatWindowState(windowId: UUID(), agentId: Agent.defaultId)
            defer { next.cleanup() }
            #expect(next.showProjectInspector == false)
            #expect(next.leftPanelMode == .chats)
        }
    }

    @Test("the left content panel overlays when docking would squeeze the canvas below its minimum")
    func narrowPanelOverlayDecision() {
        // 58pt rail + 300pt panel + 440pt canvas = 798pt.
        #expect(ChatView.leftPanelUsesOverlay(windowWidth: 800, isOpen: true, projectSettingsOpen: false) == false)
        #expect(ChatView.leftPanelUsesOverlay(windowWidth: 797, isOpen: true, projectSettingsOpen: false))
        #expect(ChatView.leftPanelUsesOverlay(windowWidth: 800, isOpen: false, projectSettingsOpen: false) == false)

        // The project-only right panel adds its 300pt minimum to the docked threshold.
        #expect(ChatView.leftPanelUsesOverlay(windowWidth: 1100, isOpen: true, projectSettingsOpen: true) == false)
        #expect(ChatView.leftPanelUsesOverlay(windowWidth: 1097, isOpen: true, projectSettingsOpen: true))
    }

    @Test("Project Settings width is clamped while preserving the main content floor")
    func projectSettingsWidth() {
        #expect(ChatView.projectSettingsPanelWidth(totalWidth: 1400, leadingNavigationWidth: 358, preferredWidth: 380) == 380)
        #expect(ChatView.projectSettingsPanelWidth(totalWidth: 800, leadingNavigationWidth: 58, preferredWidth: 380) == 302)
        #expect(ChatView.projectSettingsPanelWidth(totalWidth: 700, leadingNavigationWidth: 58, preferredWidth: 380) == 300)
        #expect(ChatView.clampProjectSettingsWidth(100) == 300)
        #expect(ChatView.clampProjectSettingsWidth(900) == 520)
        #expect(ChatView.projectSettingsPanelWidth(totalWidth: 1400, leadingNavigationWidth: 58, preferredWidth: 900) == 520)
    }

    @Test("the normal-window inset follows AppKit's unobscured content rectangle")
    func titlebarContentInsetUsesWindowGeometry() {
        let contentLayoutRect = CGRect(x: 0, y: 0, width: 1200, height: 748)
        #expect(
            ChatWindowManager.titlebarContentInset(
                windowFrameHeight: 800,
                contentLayoutRect: contentLayoutRect,
                isFullScreen: false
            ) == 52
        )
        #expect(
            ChatWindowManager.titlebarContentInset(
                windowFrameHeight: 800,
                contentLayoutRect: CGRect(x: 0, y: 0, width: 1200, height: 810),
                isFullScreen: false
            ) == 0
        )
        #expect(
            ChatWindowManager.titlebarContentInset(
                windowFrameHeight: 800,
                contentLayoutRect: contentLayoutRect,
                isFullScreen: true
            ) == 0
        )
    }

    @Test("the toolbar tab strip aligns with the docked panel or the permanent rail")
    func tabStripInsetsFollowLeadingNavigation() async throws {
        #expect(ChatTabStripView.leadingInset(sidebarWidth: 358, chromeWidth: 76) == 282)
        #expect(ChatTabStripView.leadingInset(sidebarWidth: 333, chromeWidth: 76) == 257)
        #expect(ChatTabStripView.leadingInset(sidebarWidth: 58, chromeWidth: 76) == 0)
        #expect(ChatTabStripView.leadingInset(sidebarWidth: 0, chromeWidth: 76) == 0)

        try await ChatHistoryTestStorage.run {
            let window = ChatWindowState(windowId: UUID(), agentId: Agent.defaultId)
            defer { window.cleanup() }
            #expect(window.leadingNavigationWidth == SidebarStyle.compactRailWidth)
        }
    }
}
