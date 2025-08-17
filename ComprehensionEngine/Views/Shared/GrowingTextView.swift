import SwiftUI
import UIKit

struct GrowingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let onReturn: (() -> Void)?

    // New parameters to support placeholder and collision-aware exclusion region
    let placeholder: String
    let placeholderColor: UIColor
    let trailingAccessorySize: CGSize
    let collisionGap: CGFloat
    let textViewHorizontalPadding: CGFloat
    let accessoryTrailingPadding: CGFloat

    init(
        text: Binding<String>,
        height: Binding<CGFloat>,
        minHeight: CGFloat,
        maxHeight: CGFloat,
        onReturn: (() -> Void)? = nil,
        placeholder: String = "",
        placeholderColor: UIColor = .tertiaryLabel,
        trailingAccessorySize: CGSize = .zero,
        collisionGap: CGFloat = 6,
        textViewHorizontalPadding: CGFloat = 0,
        accessoryTrailingPadding: CGFloat = 0
    ) {
        self._text = text
        self._height = height
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.onReturn = onReturn
        self.placeholder = placeholder
        self.placeholderColor = placeholderColor
        self.trailingAccessorySize = trailingAccessorySize
        self.collisionGap = collisionGap
        self.textViewHorizontalPadding = textViewHorizontalPadding
        self.accessoryTrailingPadding = accessoryTrailingPadding
    }

    func makeUIView(context: Context) -> UITextView {
        // Build a TextKit 1 stack up-front to avoid runtime switching logs when accessing layoutManager
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: .zero)
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = true
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let tv = PlaceholderTextView(frame: .zero, textContainer: textContainer)
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        tv.textContainer.lineFragmentPadding = 0
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.adjustsFontForContentSizeCategory = true
        tv.delegate = context.coordinator
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.keyboardDismissMode = .interactive
        tv.returnKeyType = .send

        // Configure placeholder label
        if let phLabel = (tv as? PlaceholderTextView)?.placeholderLabel {
            phLabel.text = placeholder
            phLabel.textColor = placeholderColor
            phLabel.font = tv.font
            phLabel.numberOfLines = 1
            phLabel.isHidden = !text.isEmpty
        }

        if let ptv = tv as? PlaceholderTextView {
            ptv.onLayout = { [weak tv] in
                guard let tv else { return }
                self.updateExclusionPath(for: tv)
            }
        }

        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Sync text
        if uiView.text != text {
            uiView.text = text
        }

        // Update Dynamic Type font to track system changes
        let targetFont = UIFont.preferredFont(forTextStyle: .body)
        if uiView.font != targetFont {
            uiView.font = targetFont
        }

        // Insets: tighten bottom padding when no trailing accessory is present (stacked controls mode)
        var insets = uiView.textContainerInset
        insets.top = 8
        insets.bottom = (trailingAccessorySize == .zero ? 0 : 8)
        insets.left = 6
        insets.right = 6
        if insets != uiView.textContainerInset {
            uiView.textContainerInset = insets
        }

        // Update exclusion path so the last line wraps above the mic/send cluster
        updateExclusionPath(for: uiView)

        // Update placeholder visibility, styling, and layout
        if let phLabel = (uiView as? PlaceholderTextView)?.placeholderLabel {
            phLabel.isHidden = !text.isEmpty
            phLabel.text = placeholder
            phLabel.textColor = placeholderColor
            phLabel.font = uiView.font

            // Position inside the text container area to align baseline with caret
            let leading = uiView.textContainerInset.left + uiView.textContainer.lineFragmentPadding
            let top = uiView.textContainerInset.top
            let availableWidth = max(0, uiView.bounds.width - leading - uiView.textContainerInset.right)
            phLabel.frame = CGRect(x: leading, y: top, width: availableWidth, height: phLabel.intrinsicContentSize.height)
        }

        // Calculate intrinsic height and clamp; guard for initial zero width
        let width = uiView.bounds.width.isFinite ? uiView.bounds.width : 0
        if width > 0 {
            let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            var newHeight = max(minHeight, size.height.isFinite ? size.height : minHeight)
            newHeight = min(maxHeight, newHeight.isFinite ? newHeight : maxHeight)
            if height != newHeight {
                DispatchQueue.main.async { self.height = newHeight }
            }
            uiView.isScrollEnabled = size.height > maxHeight
        } else {
            if height != minHeight {
                DispatchQueue.main.async { self.height = minHeight }
            }
            uiView.isScrollEnabled = false
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: GrowingTextView
        init(_ parent: GrowingTextView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text

            // Keep placeholder visibility in sync on text changes
            if let phLabel = (textView as? PlaceholderTextView)?.placeholderLabel {
                phLabel.isHidden = !parent.text.isEmpty
            }

            // Recompute exclusion path immediately on content changes
            parent.updateExclusionPath(for: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
        // Update exclusion path when caret moves across lines
        parent.updateExclusionPath(for: textView)
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText string: String) -> Bool {
            if string == "\n" && textView.textInputMode?.primaryLanguage != "emoji" {
                parent.onReturn?()
                return false
            }
            return true
        }
    }

    private func updateExclusionPath(for uiView: UITextView) {
        // Ensure layout is up-to-date before measuring used rect
        let layoutManager = uiView.layoutManager
        let textContainer = uiView.textContainer
        layoutManager.ensureLayout(for: textContainer)

        // If accessory footprint is not yet known, clear any reservation
        if trailingAccessorySize.width <= 0 || trailingAccessorySize.height <= 0 {
            if !uiView.textContainer.exclusionPaths.isEmpty {
                uiView.textContainer.exclusionPaths = []
            }
            #if DEBUG
            if let placeholderTV = uiView as? PlaceholderTextView {
                placeholderTV.updateDebugOverlay(exclusionRect: .zero)
            }
            #endif
            return
        }

        // Authoritative container size in text container coordinates
        let containerSize = textContainer.size
        let safeBoundsWidth = uiView.bounds.width.isFinite ? uiView.bounds.width : 0
        let safeBoundsHeight = uiView.bounds.height.isFinite ? uiView.bounds.height : 0
        let containerWidth = containerSize.width > 0 ? containerSize.width : max(0, safeBoundsWidth - uiView.textContainerInset.left - uiView.textContainerInset.right)
        let containerHeight = containerSize.height > 0 ? containerSize.height : max(0, safeBoundsHeight - uiView.textContainerInset.top - uiView.textContainerInset.bottom)

        // Compute horizontal overlap only for the portion intruding into the text container
        let trailingDelta = max(0, accessoryTrailingPadding - textViewHorizontalPadding)
        let overlapWidth = max(0, trailingAccessorySize.width - trailingDelta)

        // Reserve area with a small gap and rounded corner so only the last line floats
        let exclusionWidth = max(0, overlapWidth + collisionGap)
        let exclusionHeight = max(0, trailingAccessorySize.height + collisionGap)

        // Used text height to anchor the rect just under the active line
        let usedRect = layoutManager.usedRect(for: textContainer)
        let usedHeight = usedRect.height.isFinite ? usedRect.height : 0
        let maxY = max(0, min(containerHeight - exclusionHeight, usedHeight - exclusionHeight))

        // Mirror horizontally for RTL
        let isRTL = uiView.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let originX = isRTL ? 0 : max(0, containerWidth - exclusionWidth)
        let originY = max(0, maxY)
        let exclusionRect = CGRect(x: originX, y: originY, width: exclusionWidth, height: exclusionHeight)

        let path = UIBezierPath(roundedRect: exclusionRect, cornerRadius: 8)
        let currentBounds = uiView.textContainer.exclusionPaths.first?.bounds ?? .null
        if currentBounds.integral != exclusionRect.integral {
            uiView.textContainer.exclusionPaths = [path]
        }

        // DEBUG overlay to visualize the exclusion rect in real time
        #if DEBUG
        if let placeholderTV = uiView as? PlaceholderTextView {
            placeholderTV.updateDebugOverlay(exclusionRect: exclusionRect)
        }
        #endif
    }
}

// MARK: - Internal UITextView subclass to host a placeholder label aligned to caret metrics
final class PlaceholderTextView: UITextView {
    let placeholderLabel: UILabel = UILabel()
    var onLayout: (() -> Void)?
    #if DEBUG
    private let debugExclusionLayer = CAShapeLayer()
    #endif
    private var lastContainerBounds: CGRect = .zero

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isScrollEnabled = false
        backgroundColor = .clear
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(placeholderLabel)
        #if DEBUG
        debugExclusionLayer.fillColor = UIColor.systemRed.withAlphaComponent(0.15).cgColor
        debugExclusionLayer.strokeColor = UIColor.systemRed.withAlphaComponent(0.6).cgColor
        debugExclusionLayer.lineWidth = 1
        layer.addSublayer(debugExclusionLayer)
        #endif
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Keep placeholder aligned with current insets and padding
        let leading = textContainerInset.left + textContainer.lineFragmentPadding
        let top = textContainerInset.top
        let availableWidth = max(0, bounds.width - leading - textContainerInset.right)
        placeholderLabel.frame = CGRect(x: leading, y: top, width: availableWidth, height: placeholderLabel.intrinsicContentSize.height)
        #if DEBUG
        // Keep debug layer within text container coordinates
        let containerOriginX: CGFloat = textContainerInset.left
        let containerOriginY: CGFloat = textContainerInset.top
        debugExclusionLayer.frame = CGRect(x: containerOriginX, y: containerOriginY, width: bounds.width - textContainerInset.left - textContainerInset.right, height: bounds.height - textContainerInset.top - textContainerInset.bottom)
        #endif

        // Notify only when container bounds changed meaningfully to avoid feedback loops
        let containerBounds = CGRect(
            x: textContainerInset.left,
            y: textContainerInset.top,
            width: bounds.width - textContainerInset.left - textContainerInset.right,
            height: bounds.height - textContainerInset.top - textContainerInset.bottom
        )
        if abs(containerBounds.width - lastContainerBounds.width) > 0.5 ||
            abs(containerBounds.height - lastContainerBounds.height) > 0.5 ||
            abs(containerBounds.origin.x - lastContainerBounds.origin.x) > 0.5 ||
            abs(containerBounds.origin.y - lastContainerBounds.origin.y) > 0.5 {
            lastContainerBounds = containerBounds
            onLayout?()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // Recompute on layout direction and dynamic type changes
        onLayout?()
    }

    #if DEBUG
    func updateDebugOverlay(exclusionRect: CGRect) {
        let path = UIBezierPath(roundedRect: exclusionRect, cornerRadius: 8)
        // Update path without forcing another layout pass to avoid loops
        if debugExclusionLayer.path == nil || !UIBezierPath(cgPath: debugExclusionLayer.path!).bounds.equalTo(path.bounds) {
            debugExclusionLayer.path = path.cgPath
        }
    }
    #endif
}


