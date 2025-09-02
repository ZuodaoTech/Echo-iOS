import Foundation

/// Protocol for services that need proper cleanup to prevent retain cycles
protocol ServiceLifecycle: AnyObject {
    /// Called when the service should release all resources and callbacks
    func prepareForDeallocation()
    
    /// Called to validate the service is in a valid state
    func validateState() -> Bool
    
    /// Called to recover from an invalid state if possible
    func recoverIfNeeded()
}

/// Default implementations
extension ServiceLifecycle {
    func validateState() -> Bool {
        return true
    }
    
    func recoverIfNeeded() {
        // Default: no recovery needed
    }
}

/// Manager for coordinating service lifecycle
final class ServiceLifecycleManager {
    private weak var coordinator: AudioCoordinator?
    private var services: [ServiceLifecycle] = []
    private var validationTimer: Timer?
    
    init(coordinator: AudioCoordinator) {
        self.coordinator = coordinator
    }
    
    func register(_ service: ServiceLifecycle) {
        services.append(service)
    }
    
    func startValidation(interval: TimeInterval = 5.0) {
        stopValidation() // Ensure no duplicate timers
        
        validationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.validateAllServices()
        }
    }
    
    func stopValidation() {
        validationTimer?.invalidate()
        validationTimer = nil
    }
    
    private func validateAllServices() {
        for service in services {
            if !service.validateState() {
                print("⚠️ Service validation failed: \(type(of: service))")
                service.recoverIfNeeded()
            }
        }
    }
    
    func cleanupAll() {
        stopValidation()
        
        for service in services {
            service.prepareForDeallocation()
        }
        
        services.removeAll()
    }
    
    deinit {
        cleanupAll()
    }
}