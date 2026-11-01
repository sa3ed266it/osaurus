//
//  ChatNavigationPanel.swift
//  osaurus
//
//  Collapsible Chats / File Changes content panel beside the permanent
//  navigation rail. The panel owns only its header and mode selection; the
//  existing history and file-change views remain the source of truth for
//  their actions and state.
//

import SwiftUI

struct ChatLeftNavigationPanel: View {
    @ObservedObject var windowState: ChatWindowState
    /// Fixed content-panel width while docked or temporarily overlaid.
    let width: CGFloat
    let sessionId: UUID?
    @Binding var focusSetId: UUID?
    /// First line of the user's request that produced a turn, for File
    /// Changes timeline headers.
    var userPrompt: (UUID) -> String? = { _ in nil }
    /// A History row was picked: open that chat in the current tab.
    var onSelectSession: (ChatSessionData) -> Void = { _ in }

    @Environment(\.themedAlertScope) private var alertScope
    @Environment(\.theme) private var theme

    private var chatsSelected: Bool { windowState.leftPanelMode == .chats }

    var body: some View {
        SidebarContainer(
            attachedEdge: .trailing,
            width: width,
            showsBorder: false
        ) {
            VStack(spacing: 0) {
                modePicker

                ZStack(alignment: .top) {
                    ChatHistoryPaneView(
                        windowState: windowState,
                        scope: alertScope,
                        onSelect: onSelectSession,
                        onOpenInNewTab: { windowState.openSessionInNewTab($0) },
                        sessionScope: windowState.activeScope
                    )
                    .opacity(chatsSelected ? 1 : 0)
                    .allowsHitTesting(chatsSelected)
                    .accessibilityHidden(!chatsSelected)
                    .zIndex(chatsSelected ? 1 : 0)

                    FileChangesPanel(
                        sessionId: sessionId,
                        focusSetId: $focusSetId,
                        userPrompt: userPrompt
                    )
                    .opacity(chatsSelected ? 0 : 1)
                    .allowsHitTesting(!chatsSelected)
                    .accessibilityHidden(chatsSelected)
                    .zIndex(chatsSelected ? 0 : 1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(windowState.leftPanelMode.title, bundle: .module))
    }

    private var modePicker: some View {
        HStack {
            Menu {
                Picker(
                    selection: Binding(
                        get: { windowState.leftPanelMode },
                        set: { windowState.showLeftPanel($0) }
                    )
                ) {
                    ForEach(ChatLeftPanelMode.allCases, id: \.self) { mode in
                        Label {
                            Text(mode.title, bundle: .module)
                        } icon: {
                            Image(systemName: mode.systemImage)
                        }
                        .tag(mode)
                    }
                }
                label: {
                    Text(windowState.leftPanelMode.title, bundle: .module)
                }
                .pickerStyle(.inline)
            } label: {
                Text(windowState.leftPanelMode.title, bundle: .module)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(theme.primaryText)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.visible)
            .accessibilityLabel(Text(windowState.leftPanelMode.title, bundle: .module))
            .accessibilityValue(Text(windowState.leftPanelMode.title, bundle: .module))

            Spacer(minLength: 8)
        }
        .frame(minHeight: 30)
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}
