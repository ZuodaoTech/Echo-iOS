//
//  ScriptTextEditor.swift
//  Echo
//
//  Created by Nancy on 2025-01-03.
//

import SwiftUI

/// A minimal read-only component for displaying script text
/// This is the first step in extracting the text editor from AddEditScriptView
struct ScriptTextEditor: View {
    // Start with read-only to ensure safe integration
    let scriptText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Script")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(scriptText.isEmpty ? "Enter your self-talk script here..." : scriptText)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

// MARK: - Preview Provider
struct ScriptTextEditor_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ScriptTextEditor(scriptText: "I am confident and capable.")
                .padding()
                .previewDisplayName("With Text")
            
            ScriptTextEditor(scriptText: "")
                .padding()
                .previewDisplayName("Empty")
        }
    }
}