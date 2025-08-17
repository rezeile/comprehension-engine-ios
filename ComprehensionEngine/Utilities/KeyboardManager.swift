import SwiftUI
import Combine
import UIKit

// MARK: - Keyboard Manager
class KeyboardManager: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    @Published var isKeyboardVisible = false
    @Published var keyboardAnimationDuration: Double = 0.25
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupKeyboardObservers()
    }
    
    deinit {
        removeKeyboardObservers()
    }
    
    private func setupKeyboardObservers() {
        // Keyboard will show
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { [weak self] notification in
                self?.handleKeyboardWillShow(notification)
            }
            .store(in: &cancellables)
        
        // Keyboard will hide
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] notification in
                self?.handleKeyboardWillHide(notification)
            }
            .store(in: &cancellables)
        
        // Keyboard did show
        NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)
            .sink { [weak self] notification in
                self?.handleKeyboardDidShow(notification)
            }
            .store(in: &cancellables)
        
        // Keyboard did hide
        NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)
            .sink { [weak self] notification in
                self?.handleKeyboardDidHide(notification)
            }
            .store(in: &cancellables)
    }
    
    private func removeKeyboardObservers() {
        cancellables.removeAll()
    }
    
    private func handleKeyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        let screenHeight = UIScreen.main.bounds.height
        let keyboardHeight = screenHeight - keyboardFrame.origin.y
        
        withAnimation(.easeInOut(duration: duration)) {
            self.keyboardHeight = keyboardHeight
            self.keyboardAnimationDuration = duration
        }
    }
    
    private func handleKeyboardWillHide(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        withAnimation(.easeInOut(duration: duration)) {
            self.keyboardHeight = 0
            self.keyboardAnimationDuration = duration
        }
    }
    
    private func handleKeyboardDidShow(_ notification: Notification) {
        isKeyboardVisible = true
    }
    
    private func handleKeyboardDidHide(_ notification: Notification) {
        isKeyboardVisible = false
    }
    
    // MARK: - Public Methods
    
    /// Dismisses the keyboard
    func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    /// Gets the safe area insets for the current device
    var safeAreaInsets: EdgeInsets {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return EdgeInsets()
        }
        
        let uiInsets = window.safeAreaInsets
        return EdgeInsets(
            top: uiInsets.top,
            leading: uiInsets.left,
            bottom: uiInsets.bottom,
            trailing: uiInsets.right
        )
    }
    
    /// Calculates the total bottom offset including keyboard and safe area
    var totalBottomOffset: CGFloat {
        return keyboardHeight + safeAreaInsets.bottom
    }
}

// MARK: - Keyboard Dismissal Gesture
struct KeyboardDismissalGesture: ViewModifier {
    let onDismiss: () -> Void
    
    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        if value.translation.height > 50 {
                            onDismiss()
                        }
                    }
            )
            .onTapGesture {
                onDismiss()
            }
    }
}

// MARK: - Keyboard Aware View
struct KeyboardAwareView<Content: View>: View {
    @StateObject private var keyboardManager = KeyboardManager()
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .environmentObject(keyboardManager)
            .padding(.bottom, keyboardManager.keyboardHeight)
            .animation(.easeInOut(duration: keyboardManager.keyboardAnimationDuration), value: keyboardManager.keyboardHeight)
    }
}

// MARK: - Keyboard Dismissal View Modifier
extension View {
    /// Adds keyboard dismissal functionality to a view
    func keyboardDismissal(onDismiss: @escaping () -> Void = {}) -> some View {
        self.modifier(KeyboardDismissalGesture(onDismiss: onDismiss))
    }
    
    /// Makes a view keyboard aware
    func keyboardAware() -> some View {
        KeyboardAwareView {
            self
        }
    }
    
    /// Injects a KeyboardManager environment object; usable on any View
    func keyboardManaged() -> some View {
        self.environmentObject(KeyboardManager())
    }
}

// MARK: - ScrollView Keyboard Awareness
extension ScrollView {
    /// Makes a ScrollView keyboard aware with proper content adjustment
    func keyboardAware() -> some View {
        self
            .environmentObject(KeyboardManager())
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                // Scroll to bottom when keyboard appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        // This will be handled by the ScrollViewReader in the parent view
                    }
                }
            }
    }
}

// MARK: - TextField Keyboard Management
extension TextField {
    /// Adds keyboard management to a TextField
    func keyboardManaged() -> some View {
        self
            .environmentObject(KeyboardManager())
    }
}

// MARK: - TextEditor Keyboard Management
extension TextEditor {
    /// Adds keyboard management to a TextEditor
    func keyboardManaged() -> some View {
        self
            .environmentObject(KeyboardManager())
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: AppSpacing.lg) {
        Text("Keyboard Manager Preview")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        Text("This view demonstrates keyboard management capabilities.")
            .font(.body)
        
        TextField("Type here...", text: .constant(""))
            .textFieldStyle(.roundedBorder)
            .keyboardManaged()
        
        Button("Dismiss Keyboard") {
            // This will be handled by the KeyboardManager
        }
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(AppSpacing.CornerRadius.md)
    }
    .padding()
    .keyboardAware()
    .background(Color(.systemBackground))
}
