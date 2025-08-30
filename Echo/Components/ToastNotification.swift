import SwiftUI

// MARK: - Toast Model
struct Toast: Equatable {
    let id = UUID()
    let type: ToastType
    let title: String
    let message: String?
    let action: ToastAction?
    let autoDismissAfter: TimeInterval
    
    enum ToastType {
        case error
        case warning
        case info
        case success
        
        var color: Color {
            switch self {
            case .error: return .red
            case .warning: return .orange
            case .info: return .blue
            case .success: return .green
            }
        }
        
        var iconName: String {
            switch self {
            case .error: return "exclamationmark.triangle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            }
        }
    }
    
    struct ToastAction {
        let title: String
        let handler: () -> Void
        
        static func == (lhs: ToastAction, rhs: ToastAction) -> Bool {
            lhs.title == rhs.title
        }
    }
    
    static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Toast Notification View
struct ToastNotification: View {
    let toast: Toast
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    @State private var dragOffset = CGSize.zero
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: toast.type.iconName)
                .font(.title3)
                .foregroundColor(.white)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(toast.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                if let message = toast.message {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                }
            }
            
            Spacer()
            
            // Action button or dismiss
            if let action = toast.action {
                Button(action: action.handler) {
                    Text(action.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.white.opacity(0.2))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Manual dismiss button
            Button {
                dismissToast()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(
                    colors: [toast.type.color, toast.type.color.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .offset(y: isVisible ? 0 : -100)
        .offset(dragOffset)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.9)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isVisible)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height < 0 {  // Only allow upward swipe
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    if value.translation.height < -50 {  // Threshold for dismissal
                        dismissToast()
                    } else {
                        dragOffset = .zero
                    }
                }
        )
        .onTapGesture {
            dismissToast()
        }
        .onAppear {
            // Animate in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isVisible = true
            }
            
            // Auto-dismiss after specified time
            if toast.autoDismissAfter > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + toast.autoDismissAfter) {
                    dismissToast()
                }
            }
        }
    }
    
    private func dismissToast() {
        // Trigger haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isVisible = false
        }
        
        // Call dismiss handler after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onDismiss()
        }
    }
}

// MARK: - Toast Container View Modifier
struct ToastContainer: ViewModifier {
    @Binding var toast: Toast?
    
    func body(content: Content) -> some View {
        content
            .overlay(
                VStack {
                    if let toast = toast {
                        ToastNotification(toast: toast) {
                            self.toast = nil
                        }
                        .zIndex(1000)
                    }
                    Spacer()
                }
                .allowsHitTesting(toast != nil)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: toast?.id)
            )
    }
}

// MARK: - View Extension
extension View {
    func toast(_ toast: Binding<Toast?>) -> some View {
        self.modifier(ToastContainer(toast: toast))
    }
}

// MARK: - Toast Convenience Methods
extension Toast {
    static func error(
        title: String,
        message: String? = nil,
        action: ToastAction? = nil,
        autoDismissAfter: TimeInterval = 4.0
    ) -> Toast {
        Toast(
            type: .error,
            title: title,
            message: message,
            action: action,
            autoDismissAfter: autoDismissAfter
        )
    }
    
    static func warning(
        title: String,
        message: String? = nil,
        action: ToastAction? = nil,
        autoDismissAfter: TimeInterval = 4.0
    ) -> Toast {
        Toast(
            type: .warning,
            title: title,
            message: message,
            action: action,
            autoDismissAfter: autoDismissAfter
        )
    }
    
    static func info(
        title: String,
        message: String? = nil,
        action: ToastAction? = nil,
        autoDismissAfter: TimeInterval = 3.0
    ) -> Toast {
        Toast(
            type: .info,
            title: title,
            message: message,
            action: action,
            autoDismissAfter: autoDismissAfter
        )
    }
    
    static func success(
        title: String,
        message: String? = nil,
        action: ToastAction? = nil,
        autoDismissAfter: TimeInterval = 3.0
    ) -> Toast {
        Toast(
            type: .success,
            title: title,
            message: message,
            action: action,
            autoDismissAfter: autoDismissAfter
        )
    }
}