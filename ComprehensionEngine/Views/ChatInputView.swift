import SwiftUI
import UIKit

struct ChatInputView: View {
    @Binding var text: String
    let onSend: () -> Void
    let onVoiceMode: () -> Void
    @State private var inputHeight: CGFloat = 40
    @State private var accessorySize: CGSize = .zero
    @State private var controlsRowHeight: CGFloat = 0
    
    private enum InputLayoutMode { case wrapAboveControls, stackedControls }

    var body: some View {
        let textViewHorizontalPadding: CGFloat = AppSpacing.Component.inputPadding - 12
        let textViewVerticalPadding: CGFloat = AppSpacing.Component.inputPadding - 6
        let controlsSpacing: CGFloat = 0
        let layoutMode: InputLayoutMode = .stackedControls
        let controlsTopNudge: CGFloat = -10

        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: AppSpacing.Component.inputSpacing) {
                // Capsule container with growing input
                Group {
                    switch layoutMode {
                    case .wrapAboveControls:
                        ZStack(alignment: .bottomTrailing) {
                            // Growing text view with internal placeholder and dynamic trailing inset
                            GrowingTextView(
                                text: $text,
                                height: $inputHeight,
                                minHeight: 40,
                                maxHeight: 136,
                                onReturn: sendIfPossible,
                                placeholder: "Ask anything",
                                placeholderColor: UIColor(AppColors.inputPlaceholder),
                                trailingAccessorySize: accessorySize,
                                collisionGap: 6,
                                textViewHorizontalPadding: textViewHorizontalPadding,
                                accessoryTrailingPadding: 6
                            )
                            .frame(height: max(1, inputHeight))
                            .padding(.horizontal, textViewHorizontalPadding)
                            .padding(.top, textViewVerticalPadding)

                            // Trailing controls: mic and send inside the capsule
                            HStack(spacing: 4) {
                                Button(action: onVoiceMode) {
                                    Image(systemName: "mic.fill")
                                        .imageScale(.medium)
                                        .foregroundColor(AppColors.textPrimary)
                                        .frame(width: 36, height: 36)
                                        .contentShape(RoundedRectangle(cornerRadius: 18))
                                }
                                .accessibilityLabel("Start voice input")

                                Button(action: sendIfPossible) {
                                    Image(systemName: "paperplane.fill")
                                        .imageScale(.medium)
                                        .foregroundColor(AppColors.textPrimary)
                                        .frame(width: 36, height: 36)
                                        .contentShape(RoundedRectangle(cornerRadius: 18))
                                }
                                .disabled(isTextEmpty)
                                .opacity(isTextEmpty ? 0.4 : 1)
                            }
                            .padding(.trailing, 6)
                            .padding(.bottom, 4)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(key: AccessorySizePreferenceKey.self, value: geo.size)
                                }
                            )
                        }
                        // Constrain height to content + vertical padding; add background/border here
                        .frame(height: max(1, inputHeight + (textViewVerticalPadding * 2)))
                        .background(
                            RoundedRectangle(cornerRadius: AppSpacing.CornerRadius.pill)
                                .fill(AppColors.backgroundSecondary)
                        )
                        .onPreferenceChange(AccessorySizePreferenceKey.self) { size in
                            // Exclude trailing/bottom paddings from measured accessory footprint
                            let correctedWidth = max(0, size.width - 6)
                            let correctedHeight = max(0, size.height - 4)
                            accessorySize = CGSize(width: correctedWidth, height: correctedHeight)
                        }

                    case .stackedControls:
                        VStack(spacing: controlsSpacing) {
                            GrowingTextView(
                                text: $text,
                                height: $inputHeight,
                                minHeight: 40,
                                maxHeight: 136,
                                onReturn: sendIfPossible,
                                placeholder: "Ask anything",
                                placeholderColor: UIColor(AppColors.inputPlaceholder),
                                trailingAccessorySize: .zero, // disable exclusion path
                                collisionGap: 6,
                                textViewHorizontalPadding: textViewHorizontalPadding,
                                accessoryTrailingPadding: 6
                            )
                            .frame(height: max(1, inputHeight))
                            .padding(.horizontal, textViewHorizontalPadding)
                            .padding(.top, textViewVerticalPadding)

                            HStack(spacing: 4) {
                                Button(action: onVoiceMode) {
                                    Image(systemName: "mic.fill")
                                        .imageScale(.medium)
                                        .foregroundColor(AppColors.textPrimary)
                                        .frame(width: 36, height: 36)
                                        .contentShape(RoundedRectangle(cornerRadius: 18))
                                }
                                .accessibilityLabel("Start voice input")

                                Button(action: sendIfPossible) {
                                    Image(systemName: "paperplane.fill")
                                        .imageScale(.medium)
                                        .foregroundColor(AppColors.textPrimary)
                                        .frame(width: 36, height: 36)
                                        .contentShape(RoundedRectangle(cornerRadius: 18))
                                }
                                .disabled(isTextEmpty)
                                .opacity(isTextEmpty ? 0.4 : 1)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 6)
                            .padding(.bottom, 4)
                            .padding(.top, controlsTopNudge)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(key: ControlsRowSizePreferenceKey.self, value: geo.size)
                                }
                            )
                        }
                        .frame(height: max(1, inputHeight + textViewVerticalPadding + controlsRowHeight + 4 + controlsSpacing + controlsTopNudge))
                        .background(
                            RoundedRectangle(cornerRadius: AppSpacing.CornerRadius.pill)
                                .fill(AppColors.backgroundSecondary)
                        )
                        .onPreferenceChange(ControlsRowSizePreferenceKey.self) { size in
                            // Exclude bottom padding from measured controls height to avoid double counting
                            let correctedHeight = max(0, size.height - 4)
                            controlsRowHeight = correctedHeight
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.Layout.screenMarginSmall)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.background)
            .shadow(AppSpacing.Shadow.small)
        }
        // Report the total container height upwards so parent can pad ScrollView bottom
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: InputContainerHeightPreferenceKey.self, value: geo.size.height)
            }
        )
    }

    private func sendIfPossible() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSend()
        text = ""
        inputHeight = 40
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private var isTextEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - PreferenceKey to measure trailing accessory width
private struct AccessorySizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        value = CGSize(width: max(value.width, next.width), height: max(value.height, next.height))
    }
}

// Measure controls row size in stacked mode
private struct ControlsRowSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        value = CGSize(width: max(value.width, next.width), height: max(value.height, next.height))
    }
}

// Expose total ChatInputView container height to ancestors
struct InputContainerHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 60
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    ChatInputView(
        text: .constant(""),
        onSend: {},
        onVoiceMode: {}
    )
}
