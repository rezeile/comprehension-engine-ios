import SwiftUI

// MARK: - Modern Text Field
struct ModernTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String?
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let submitLabel: SubmitLabel
    let onSubmit: (() -> Void)?
    let onEditingChanged: ((Bool) -> Void)?
    
    @FocusState private var isFocused: Bool
    @State private var isSecureTextVisible = false
    
    init(
        placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        submitLabel: SubmitLabel = .return,
        onSubmit: (() -> Void)? = nil,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.submitLabel = submitLabel
        self.onSubmit = onSubmit
        self.onEditingChanged = onEditingChanged
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 20)
            }
            
            Group {
                if isSecure && !isSecureTextVisible {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(PlainTextFieldStyle())
            .keyboardType(keyboardType)
            .textContentType(textContentType)
            .submitLabel(submitLabel)
            .focused($isFocused)
            .onSubmit {
                onSubmit?()
            }
            .onChange(of: isFocused) { newValue in
                onEditingChanged?(newValue)
            }
            
            if isSecure {
                Button(action: {
                    isSecureTextVisible.toggle()
                }) {
                    Image(systemName: isSecureTextVisible ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, AppSpacing.Component.inputPadding)
        .padding(.vertical, AppSpacing.Component.inputPadding - 4)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.CornerRadius.lg)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .cornerRadius(AppSpacing.CornerRadius.lg)
        .shadow(shadowStyle)
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(AppAnimations.Preset.inputFocus, value: isFocused)
    }
    
    // MARK: - Computed Properties
    
    private var iconColor: Color {
        return isFocused ? AppColors.primary : AppColors.textTertiary
    }
    
    private var backgroundColor: Color {
        return isFocused ? AppColors.background : AppColors.backgroundSecondary
    }
    
    private var borderColor: Color {
        return isFocused ? AppColors.primary : AppColors.inputBorder
    }
    
    private var borderWidth: CGFloat {
        return isFocused ? 2 : 1
    }
    
    private var shadowStyle: ShadowStyle {
        return isFocused ? AppSpacing.Shadow.medium : AppSpacing.Shadow.small
    }
}

// MARK: - Modern Text Editor
struct ModernTextEditor: View {
    let placeholder: String
    @Binding var text: String
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let onEditingChanged: ((Bool) -> Void)?
    let submit: (() -> Void)?
    
    @FocusState private var isFocused: Bool
    
    init(
        placeholder: String,
        text: Binding<String>,
        minHeight: CGFloat = 44,
        maxHeight: CGFloat = 120,
        onEditingChanged: ((Bool) -> Void)? = nil,
        submit: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.onEditingChanged = onEditingChanged
        self.submit = submit
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.horizontal, AppSpacing.Component.inputPadding)
                    .padding(.vertical, AppSpacing.Component.inputPadding - 4)
                    .allowsHitTesting(false)
            }
            
            TextEditor(text: $text)
                .focused($isFocused)
                .onChange(of: isFocused) { newValue in
                    onEditingChanged?(newValue)
                }
                .padding(.horizontal, AppSpacing.Component.inputPadding - 4)
                .padding(.vertical, AppSpacing.Component.inputPadding - 4)
                .onSubmit {
                    submit?()
                }
        }
        .frame(minHeight: minHeight, maxHeight: maxHeight)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.CornerRadius.lg)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .cornerRadius(AppSpacing.CornerRadius.lg)
        .shadow(shadowStyle)
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(AppAnimations.Preset.inputFocus, value: isFocused)
    }
    
    // MARK: - Computed Properties
    
    private var backgroundColor: Color {
        return isFocused ? AppColors.background : AppColors.backgroundSecondary
    }
    
    private var borderColor: Color {
        return isFocused ? AppColors.primary : AppColors.inputBorder
    }
    
    private var borderWidth: CGFloat {
        return isFocused ? 2 : 1
    }
    
    private var shadowStyle: ShadowStyle {
        return isFocused ? AppSpacing.Shadow.medium : AppSpacing.Shadow.small
    }
}

// MARK: - Search Field
struct ModernSearchField: View {
    let placeholder: String
    @Binding var text: String
    let onSearch: (() -> Void)?
    let onClear: (() -> Void)?
    
    @FocusState private var isFocused: Bool
    
    init(
        placeholder: String = "Search...",
        text: Binding<String>,
        onSearch: (() -> Void)? = nil,
        onClear: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.onSearch = onSearch
        self.onClear = onClear
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isFocused)
                .onSubmit {
                    onSearch?()
                }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    onClear?()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, AppSpacing.Component.inputPadding)
        .padding(.vertical, AppSpacing.Component.inputPadding - 4)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.CornerRadius.pill)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .cornerRadius(AppSpacing.CornerRadius.pill)
        .shadow(shadowStyle)
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(AppAnimations.Preset.inputFocus, value: isFocused)
    }
    
    // MARK: - Computed Properties
    
    private var iconColor: Color {
        return isFocused ? AppColors.primary : AppColors.textTertiary
    }
    
    private var backgroundColor: Color {
        return isFocused ? AppColors.background : AppColors.backgroundSecondary
    }
    
    private var borderColor: Color {
        return isFocused ? AppColors.primary : AppColors.inputBorder
    }
    
    private var borderWidth: CGFloat {
        return isFocused ? 2 : 1
    }
    
    private var shadowStyle: ShadowStyle {
        return isFocused ? AppSpacing.Shadow.medium : AppSpacing.Shadow.small
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: AppSpacing.lg) {
        Text("Modern Text Field Components")
            .heading1()
        
        VStack(spacing: AppSpacing.md) {
            Text("Text Fields")
                .heading3()
            
            VStack(spacing: AppSpacing.sm) {
                ModernTextField(
                    placeholder: "Enter your name",
                    text: .constant(""),
                    icon: "person.fill"
                )
                
                ModernTextField(
                    placeholder: "Enter your email",
                    text: .constant(""),
                    icon: "envelope.fill",
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress
                )
                
                ModernTextField(
                    placeholder: "Enter your password",
                    text: .constant(""),
                    icon: "lock.fill",
                    isSecure: true,
                    textContentType: .password
                )
            }
        }
        
        VStack(spacing: AppSpacing.md) {
            Text("Text Editor")
                .heading3()
            
            ModernTextEditor(
                placeholder: "Type your message here...",
                text: .constant(""),
                minHeight: 80,
                maxHeight: 200
            )
        }
        
        VStack(spacing: AppSpacing.md) {
            Text("Search Field")
                .heading3()
            
            ModernSearchField(
                placeholder: "Search messages...",
                text: .constant(""),
                onSearch: { print("Search tapped") },
                onClear: { print("Clear tapped") }
            )
        }
        
        VStack(spacing: AppSpacing.md) {
            Text("Interactive States")
                .heading3()
            
            ModernTextField(
                placeholder: "Focus me to see animation",
                text: .constant(""),
                icon: "star.fill"
            )
        }
    }
    .padding()
    .background(AppColors.background)
}
