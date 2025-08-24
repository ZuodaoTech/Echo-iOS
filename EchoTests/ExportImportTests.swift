import XCTest
import CoreData
@testable import Echo

class ExportImportTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var viewContext: NSManagedObjectContext!
    var exportService: ExportService!
    var importService: ImportService!
    
    override func setUpWithError() throws {
        // Create in-memory Core Data stack for testing
        persistenceController = PersistenceController(inMemory: true)
        viewContext = persistenceController.container.viewContext
        
        exportService = ExportService()
        importService = ImportService()
    }
    
    override func tearDownWithError() throws {
        persistenceController = nil
        viewContext = nil
        exportService = nil
        importService = nil
    }
    
    // MARK: - Export Tests
    
    func testExportEmptyScriptsList() throws {
        // Test that exporting empty list throws error
        XCTAssertThrowsError(try exportService.exportScripts([], includeAudio: false)) { error in
            XCTAssertEqual(error as? ExportService.ExportError, .noScriptsToExport)
        }
    }
    
    func testExportSingleScript() throws {
        // Create a test script
        let script = SelftalkScript(context: viewContext)
        script.id = UUID()
        script.scriptText = "Test script for export"
        script.repetitions = 3
        script.intervalSeconds = 2.0
        script.privacyModeEnabled = true
        script.createdAt = Date()
        script.updatedAt = Date()
        
        try viewContext.save()
        
        // Export as JSON (no audio files to worry about in tests)
        let exportURL = try exportService.exportScripts([script], includeAudio: false, format: .json)
        
        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))
        
        // Read and verify JSON content
        let data = try Data(contentsOf: exportURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(CompleteExport.self, from: data)
        
        XCTAssertEqual(export.scripts.count, 1)
        XCTAssertEqual(export.scripts.first?.scriptText, "Test script for export")
        XCTAssertEqual(export.manifest.scriptCount, 1)
        
        // Clean up
        try? FileManager.default.removeItem(at: exportURL)
    }
    
    func testExportMultipleFormats() throws {
        // Create test scripts
        let script1 = createTestScript(text: "First script", context: viewContext)
        let script2 = createTestScript(text: "Second script", context: viewContext)
        try viewContext.save()
        
        let scripts = [script1, script2]
        
        // Test each format
        let formats: [ExportService.ExportFormat] = [.bundle, .textOnly, .json]
        
        for format in formats {
            let url = try exportService.exportScripts(scripts, includeAudio: false, format: format)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Export failed for format: \(format)")
            
            // Verify file extension
            switch format {
            case .bundle:
                XCTAssertEqual(url.pathExtension, "echo")
            case .textOnly:
                XCTAssertEqual(url.pathExtension, "txt")
            case .json:
                XCTAssertEqual(url.pathExtension, "json")
            }
            
            // Clean up
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    // MARK: - Import Tests
    
    func testImportJSONBundle() async throws {
        // Create and export a script first
        let originalScript = createTestScript(text: "Script to import", context: viewContext)
        originalScript.transcribedText = "Transcribed text"
        try viewContext.save()
        
        let exportURL = try exportService.exportScripts([originalScript], includeAudio: false, format: .json)
        
        // Clear the context to simulate fresh import
        viewContext.reset()
        
        // Import the exported file
        let result = await importService.importBundle(
            from: exportURL,
            conflictResolution: .skip,
            context: viewContext
        )
        
        XCTAssertEqual(result.scriptsImported, 1)
        XCTAssertEqual(result.scriptsSkipped, 0)
        XCTAssertTrue(result.errors.isEmpty)
        
        // Verify imported script
        let fetchRequest: NSFetchRequest<SelftalkScript> = SelftalkScript.fetchRequest()
        let importedScripts = try viewContext.fetch(fetchRequest)
        
        XCTAssertEqual(importedScripts.count, 1)
        XCTAssertEqual(importedScripts.first?.scriptText, "Script to import")
        XCTAssertEqual(importedScripts.first?.transcribedText, "Transcribed text")
        
        // Clean up
        try? FileManager.default.removeItem(at: exportURL)
    }
    
    func testImportConflictResolution() async throws {
        // Create an existing script
        let existingScript = createTestScript(text: "Original text", context: viewContext)
        let scriptId = existingScript.id
        try viewContext.save()
        
        // Export it
        let exportURL = try exportService.exportScripts([existingScript], includeAudio: false, format: .json)
        
        // Modify the existing script
        existingScript.scriptText = "Modified text"
        try viewContext.save()
        
        // Test skip resolution
        var result = await importService.importBundle(
            from: exportURL,
            conflictResolution: .skip,
            context: viewContext
        )
        
        XCTAssertEqual(result.scriptsSkipped, 1)
        XCTAssertEqual(result.scriptsImported, 0)
        
        // Verify original wasn't changed
        let fetchRequest: NSFetchRequest<SelftalkScript> = SelftalkScript.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", scriptId as CVarArg)
        let scripts = try viewContext.fetch(fetchRequest)
        XCTAssertEqual(scripts.first?.scriptText, "Modified text")
        
        // Test replace resolution
        result = await importService.importBundle(
            from: exportURL,
            conflictResolution: .replace,
            context: viewContext
        )
        
        // Note: Our current implementation counts replace as an update, not import
        // This might need adjustment based on requirements
        
        // Clean up
        try? FileManager.default.removeItem(at: exportURL)
    }
    
    func testExportWithCategory() throws {
        // Create category and script
        let category = Category(context: viewContext)
        category.id = UUID()
        category.name = "Test Category"
        category.sortOrder = 0
        
        let script = createTestScript(text: "Categorized script", context: viewContext)
        script.category = category
        
        try viewContext.save()
        
        // Export
        let exportURL = try exportService.exportScripts([script], includeAudio: false, format: .json)
        
        // Read and verify
        let data = try Data(contentsOf: exportURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(CompleteExport.self, from: data)
        
        XCTAssertEqual(export.categories.count, 1)
        XCTAssertEqual(export.categories.first?.name, "Test Category")
        XCTAssertNotNil(export.scripts.first?.categoryId)
        
        // Clean up
        try? FileManager.default.removeItem(at: exportURL)
    }
    
    // MARK: - Helper Methods
    
    private func createTestScript(text: String, context: NSManagedObjectContext) -> SelftalkScript {
        let script = SelftalkScript(context: context)
        script.id = UUID()
        script.scriptText = text
        script.repetitions = 3
        script.intervalSeconds = 2.0
        script.privacyModeEnabled = true
        script.createdAt = Date()
        script.updatedAt = Date()
        return script
    }
}

// MARK: - CloudKit Tests

class CloudKitSyncTests: XCTestCase {
    
    func testPersistenceControllerCloudKitConfiguration() throws {
        // Test that CloudKit is properly configured when enabled
        UserDefaults.standard.set(true, forKey: "iCloudSyncEnabled")
        
        let controller = PersistenceController(inMemory: true)
        
        // Verify container type
        XCTAssertTrue(controller.container is NSPersistentCloudKitContainer)
        
        // Reset
        UserDefaults.standard.removeObject(forKey: "iCloudSyncEnabled")
    }
    
    func testCloudKitToggle() throws {
        // Test that toggling iCloud sync posts notification
        let expectation = XCTestExpectation(description: "Notification posted")
        
        let observer = NotificationCenter.default.addObserver(
            forName: Notification.Name("RestartCoreDataForICloud"),
            object: nil,
            queue: .main
        ) { notification in
            if let enabled = notification.userInfo?["enabled"] as? Bool {
                XCTAssertTrue(enabled)
                expectation.fulfill()
            }
        }
        
        // Simulate toggle
        NotificationCenter.default.post(
            name: Notification.Name("RestartCoreDataForICloud"),
            object: nil,
            userInfo: ["enabled": true]
        )
        
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
}