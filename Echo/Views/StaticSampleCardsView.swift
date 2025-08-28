//
//  StaticSampleCardsView.swift
//  Echo
//
//  Displays static sample cards instantly on first launch
//

import SwiftUI

struct StaticSampleCardsView: View {
    private let samples = StaticSampleProvider.shared.getSamples()
    @State private var showingSampleAlert = false
    @State private var hasTriggeredCoreData = false
    let onlyShowSamples: Bool
    
    init(onlyShowSamples: Bool = false) {
        self.onlyShowSamples = onlyShowSamples
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(samples) { sample in
                    StaticCardView(sample: sample)
                        .onTapGesture {
                            showingSampleAlert = true
                        }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .alert("Sample Card", isPresented: $showingSampleAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This is a sample card. You can create your own cards using the + button.")
        }
        .onAppear {
            // Only trigger Core Data if we're in MainScriptsView context
            if !onlyShowSamples && !hasTriggeredCoreData {
                hasTriggeredCoreData = true
                print("Static samples rendered, triggering Core Data load...")
                
                // Small delay to ensure the view has fully rendered
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let _ = try? PersistenceController.getSharedIfExists() {
                        PersistenceController.shared.startCoreDataLoading()
                    }
                }
            }
        }
    }
}

/// Individual static card view that mimics ScriptCard appearance
struct StaticCardView: View {
    let sample: StaticSampleCard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category tag
            HStack {
                Text(sample.category)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                Spacer()
                
                // Visual indicator that it's a sample
                Text("SAMPLE")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
            }
            
            // Script text
            Text(sample.scriptText)
                .font(.body)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            // Bottom row with repetitions and interval
            HStack {
                // Repetitions
                HStack(spacing: 4) {
                    Image(systemName: "repeat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(sample.repetitions)x")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Interval
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", sample.intervalSeconds))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Play button (disabled for samples)
                Button(action: {}) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray.opacity(0.5))
                }
                .disabled(true)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    StaticSampleCardsView()
}