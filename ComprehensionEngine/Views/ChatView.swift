import SwiftUI
import UIKit

struct ChatView: View {
    @EnvironmentObject var chatManager: ChatManager
    @EnvironmentObject var audioManager: AudioManager
    @State private var inputText = ""
    @State private var showingVoiceMode = false
    @State private var showingSettings = false
    @State private var showingNewChatAlert = false
    @State private var inputContainerHeight: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(chatManager.messages) { message in
                                ModernChatMessageView(message: message)
                                    .id(message.id)
                            }
                            
                            if chatManager.isLoading {
                                LoadingViews.TypingIndicator()
                            }

                            // Bottom anchor to guarantee a valid target for scroll
                            Color.clear
                                .frame(height: 1)
                                .id("bottom-anchor")
                        }
                        .padding(.horizontal, AppSpacing.Layout.screenMarginSmall)
                        .padding(.top, AppSpacing.SafeArea.top + AppSpacing.md)
                        // Reserve space at bottom equal to the input's height so last message isn't obscured
                        .padding(.bottom, inputContainerHeight + AppSpacing.md)
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                        DispatchQueue.main.async {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                    .keyboardDismissal {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .onChange(of: chatManager.messages.count) { _ in
                        // Defer slightly so layout completes before scrolling
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                    // Also scroll when input height changes significantly (layout shift)
                    .onChange(of: inputContainerHeight) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                    // When switching sessions from history, ensure we scroll once layout stabilizes
                    .onChange(of: chatManager.currentSession.id) { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }
            }
            // Removed .keyboardAware(); we'll pin input using safeAreaInset
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .top) {
                ChatNavigationBar(
                    onNewChat: { showingNewChatAlert = true },
                    onShowSettings: { showingSettings = true },
                    onShowHistory: { showingHistory = true }
                )
                .padding(.horizontal, AppSpacing.Layout.screenMarginSmall)
                .padding(.top, 8)
                .background(
                    Color.clear
                        .background(
                            LinearGradient(
                                colors: [AppColors.background.opacity(0.98), AppColors.background.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .ignoresSafeArea(edges: .top)
                )
                .shadow(AppSpacing.Shadow.small)
            }
        }
        // Pin input to bottom using safeAreaInset so it abuts the keyboard
        .safeAreaInset(edge: .bottom) {
            ChatInputView(
                text: $inputText,
                onSend: sendTextMessage,
                onVoiceMode: { showingVoiceMode = true }
            )
            // Capture input container height from preference
            .onPreferenceChange(InputContainerHeightPreferenceKey.self) { h in
                inputContainerHeight = h
            }
        }
        .overlay {
            if showingVoiceMode {
                VoiceModeOverlay(isPresented: $showingVoiceMode) {
                    VoiceModeView(onClose: { showingVoiceMode = false })
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingHistory) {
            ChatHistoryView(onSelect: { session in
                chatManager.loadSession(session)
                showingHistory = false
            }, onDelete: { session in
                chatManager.deleteSession(session)
            }, onClose: { showingHistory = false })
            .environmentObject(chatManager)
        }
        .alert("New Chat", isPresented: $showingNewChatAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Start New Chat") {
                chatManager.createNewSession()
            }
        } message: {
            Text("This will start a new conversation. The current chat will be saved.")
        }
    }
    
    @State private var showingHistory = false
    
    private func sendTextMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let message = inputText
        inputText = ""
        
        Task {
            do {
                _ = try await chatManager.sendMessage(message)
            } catch {
                print("Failed to send message: \(error)")
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo("bottom-anchor", anchor: .bottom)
        }
    }
}

struct ChatMessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
                MessageBubble(
                    text: message.content,
                    isFromUser: true
                )
            } else {
                MessageBubble(
                    text: message.content,
                    isFromUser: false
                )
                Spacer()
            }
        }
    }
}

struct MessageBubble: View {
    let text: String
    let isFromUser: Bool
    
    var body: some View {
        VStack(alignment: isFromUser ? .trailing : .leading, spacing: 4) {
            Text(text)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isFromUser ? Color.blue : Color(.systemGray5))
                )
                .foregroundColor(isFromUser ? .white : .primary)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: isFromUser ? .trailing : .leading)
            
            Text(messageTimestamp)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
    }
    
    private var messageTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

// MARK: - Modern Chat Bubble & Message Row
struct ModernChatMessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: AppSpacing.sm) {
            if message.isFromUser {
                Spacer(minLength: 40)
                ModernMessageBubble(text: message.content, isFromUser: true)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.primary)
                    .frame(width: 24, height: 24)
                    .background(AppColors.secondary)
                    .clipShape(Circle())
                    .shadow(AppSpacing.Shadow.small)
                ModernMessageBubble(text: message.content, isFromUser: false)
                Spacer(minLength: 40)
            }
        }
        .padding(.vertical, AppSpacing.Component.messageVertical)
        .messageAppear()
    }
}

struct ModernMessageBubble: View {
    let text: String
    let isFromUser: Bool
    
    var body: some View {
        VStack(alignment: isFromUser ? .trailing : .leading, spacing: AppSpacing.xs) {
            Text(text)
                .bodyBase()
                .padding(.horizontal, AppSpacing.Component.messageHorizontal)
                .padding(.vertical, AppSpacing.md)
                .background(bubbleBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.CornerRadius.xl)
                        .stroke(bubbleBorder, lineWidth: isFromUser ? 0 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.CornerRadius.xl))
                .foregroundColor(AppColors.messageText(for: isFromUser))
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: isFromUser ? .trailing : .leading)
                .shadow(isFromUser ? AppSpacing.Shadow.medium : AppSpacing.Shadow.small)
            
            Text(timestamp)
                .captionSmall()
                .foregroundColor(AppColors.textTertiary)
                .padding(.horizontal, AppSpacing.xs)
        }
    }
    
    private var bubbleBackground: some View {
        Group {
            if isFromUser {
                LinearGradient(
                    colors: [AppColors.userMessage, AppColors.userMessageLight],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                AppColors.aiMessage
            }
        }
    }
    
    private var bubbleBorder: Color {
        AppColors.messageBorder(for: isFromUser)
    }
    
    private var timestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

// MARK: - Navigation Bar
struct ChatNavigationBar: View {
    let onNewChat: () -> Void
    let onShowSettings: () -> Void
    var onShowHistory: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: AppSpacing.Component.navigationSpacing) {
            // New Chat
            ModernIconButton(icon: "plus", style: .primary, size: .base) { onNewChat() }
            
            // History (optional, additive)
            if let onShowHistory {
                ModernIconButton(icon: "clock.arrow.circlepath", style: .tertiary, size: .base) { onShowHistory() }
            }
            
            Spacer()
            
            // Settings
            ModernIconButton(icon: "gearshape.fill", style: .secondary, size: .base) { onShowSettings() }
        }
        .padding(.vertical, 10)
    }
}

struct LoadingIndicator: View {
    var body: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Claude is thinking...")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    ChatView()
        .environmentObject(ChatManager.shared)
        .environmentObject(AudioManager.shared)
}
