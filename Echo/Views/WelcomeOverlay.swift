//
//  WelcomeOverlay.swift
//  Echo
//
//  Welcome screen overlay for first-time users
//

import SwiftUI

// Extension to get the app icon
extension Bundle {
    var icon: UIImage? {
        if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let lastIcon = files.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
}

// Native iOS page control
struct PageControl: UIViewRepresentable {
    var numberOfPages: Int
    @Binding var currentPage: Int
    
    func makeUIView(context: Context) -> UIPageControl {
        let control = UIPageControl()
        control.numberOfPages = numberOfPages
        control.currentPageIndicatorTintColor = UIColor.label
        control.pageIndicatorTintColor = UIColor.tertiaryLabel
        control.addTarget(context.coordinator, action: #selector(Coordinator.updateCurrentPage(sender:)), for: .valueChanged)
        return control
    }
    
    func updateUIView(_ uiView: UIPageControl, context: Context) {
        uiView.currentPage = currentPage
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var control: PageControl
        
        init(_ control: PageControl) {
            self.control = control
        }
        
        @objc func updateCurrentPage(sender: UIPageControl) {
            control.currentPage = sender.currentPage
        }
    }
}

struct WelcomeOverlay: View {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var currentPage = 0
    @Binding var isPresented: Bool
    
    let pages = [
        WelcomePage(
            icon: "WelcomeIcon",
            isCustomIcon: true,
            title: NSLocalizedString("welcome.page1.title", comment: ""),
            subtitle: NSLocalizedString("welcome.page1.subtitle", comment: ""),
            description: NSLocalizedString("welcome.page1.description", comment: ""),
            primaryColor: .blue
        ),
        WelcomePage(
            icon: "WelcomeIcon",
            isCustomIcon: true,
            title: NSLocalizedString("welcome.page2.title", comment: ""),
            subtitle: NSLocalizedString("welcome.page2.subtitle", comment: ""),
            description: NSLocalizedString("welcome.page2.description", comment: ""),
            primaryColor: .blue
        ),
        WelcomePage(
            icon: "WelcomeIcon",
            isCustomIcon: true,
            title: NSLocalizedString("welcome.page3.title", comment: ""),
            subtitle: NSLocalizedString("welcome.page3.subtitle", comment: ""),
            description: NSLocalizedString("welcome.page3.description", comment: ""),
            primaryColor: .blue
        )
    ]
    
    var body: some View {
        ZStack {
            // iOS-style blurred background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .onTapGesture {
                    // Allow dismissing by tapping outside
                    withAnimation(.spring()) {
                        dismissWelcome()
                    }
                }
            
            // Welcome content - iOS native sheet style
            VStack(spacing: 0) {
                // iOS-style drag indicator
                Capsule()
                    .fill(Color(.tertiaryLabel))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        WelcomePageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 380)
                
                // Page indicators - iOS style
                PageControl(numberOfPages: pages.count, currentPage: $currentPage)
                    .padding(.vertical, 20)
                
                // Action buttons - iOS style
                VStack(spacing: 12) {
                    // Primary action - Continue/Get Started
                    Button(action: {
                        if currentPage < pages.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            dismissWelcome()
                        }
                    }) {
                        Text(currentPage == pages.count - 1 ? NSLocalizedString("welcome.button.getStarted", comment: "") : NSLocalizedString("welcome.button.continue", comment: ""))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.accentColor)
                            .cornerRadius(14)
                    }
                    
                    // Skip button - text only, iOS style
                    if currentPage < pages.count - 1 {
                        Button(action: dismissWelcome) {
                            Text(NSLocalizedString("welcome.button.skip", comment: ""))
                                .font(.callout)
                                .foregroundColor(.accentColor)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 40)
        }
    }
    
    private func dismissWelcome() {
        hasSeenWelcome = true
        withAnimation(.spring()) {
            isPresented = false
        }
    }
}

struct WelcomePage {
    let icon: String
    let isCustomIcon: Bool
    let title: String
    let subtitle: String
    let description: String
    let primaryColor: Color
    
    init(icon: String, isCustomIcon: Bool = false, title: String, subtitle: String, description: String, primaryColor: Color) {
        self.icon = icon
        self.isCustomIcon = isCustomIcon
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.primaryColor = primaryColor
    }
}

struct WelcomePageView: View {
    let page: WelcomePage
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Group {
                if page.isCustomIcon {
                    Image(page.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    Image(systemName: page.icon)
                        .font(.system(size: 60))
                        .foregroundColor(page.primaryColor)
                }
            }
            .padding(.top, 20)
            
            // Title
            Text(page.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            
            // Subtitle
            Text(page.subtitle)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Description
            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding()
    }
}

// Preview
struct WelcomeOverlay_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeOverlay(isPresented: .constant(true))
    }
}
