//
//  DataLoadingState.swift
//  Echo
//
//  Tracks the state of data loading for smooth transitions
//

import Foundation

/// Represents the current state of data loading
enum DataLoadingState: Equatable {
    case staticSamples          // Initial state, showing hardcoded cards
    case transitioningToCore    // Core Data ready, importing samples
    case coreDataReady         // Full Core Data functionality
    case error(String)         // Fallback state with error message
    
    var isReady: Bool {
        switch self {
        case .coreDataReady:
            return true
        default:
            return false
        }
    }
    
    var isLoading: Bool {
        switch self {
        case .transitioningToCore:
            return true
        default:
            return false
        }
    }
}