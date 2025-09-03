//
//  ScriptTextEditor.swift
//  Echo
//
//  Created by Nancy on 2025-01-03.
//

import SwiftUI

/// A text editor component for script editing with dynamic height
/// Extracted from AddEditScriptView for better modularity
struct ScriptTextEditor: View {
    // Use @Binding for two-way data flow
    @Binding var scriptText: String
    
    // Dynamic height calculation
    @State private var textEditorHeight: CGFloat = 120
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                // Invisible text for height calculation
                Text(scriptText.isEmpty ? "Placeholder\nPlaceholder\nPlaceholder\nPlaceholder\nPlaceholder\nPlaceholder" : scriptText)
                    .font(.body)
                    .opacity(0)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: ViewHeightKey.self,
                                value: geometry.size.height
                            )
                        }
                    )
                
                TextEditor(text: $scriptText)
                    .frame(minHeight: 120, maxHeight: max(120, min(textEditorHeight, 240)))
                    .overlay(
                        Group {
                            if scriptText.isEmpty {
                                Text(NSLocalizedString("guidance.enter_script", comment: ""))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        },
                        alignment: .topLeading
                    )
            }
            .onPreferenceChange(ViewHeightKey.self) { height in
                textEditorHeight = height + 16 // Add padding
            }
        }
    }
}

// Note: ViewHeightKey is defined in AddEditScriptView.swift
// We'll move it to a shared location later in the refactoring

// MARK: - Preview Provider
struct ScriptTextEditor_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var text = "I am confident and capable."
        
        var body: some View {
            ScriptTextEditor(scriptText: $text)
                .padding()
        }
    }
    
    static var previews: some View {
        Group {
            PreviewWrapper()
                .previewDisplayName("With Text")
            
            ScriptTextEditor(scriptText: .constant(""))
                .padding()
                .previewDisplayName("Empty")
        }
    }
}