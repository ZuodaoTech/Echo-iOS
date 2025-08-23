import Foundation
import CoreData

extension SelftalkScript {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SelftalkScript> {
        return NSFetchRequest<SelftalkScript>(entityName: "SelftalkScript")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var scriptText: String
    @NSManaged public var repetitions: Int16
    @NSManaged public var privacyModeEnabled: Bool
    @NSManaged public var audioFilePath: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var lastPlayedAt: Date?
    @NSManaged public var playCount: Int32
    @NSManaged public var category: Category?
}

extension SelftalkScript {
    var hasRecording: Bool {
        guard let path = audioFilePath else { return false }
        return FileManager.default.fileExists(atPath: path)
    }
    
    var scriptPreview: String {
        let maxLength = 100
        if scriptText.count <= maxLength {
            return scriptText
        }
        let endIndex = scriptText.index(scriptText.startIndex, offsetBy: maxLength)
        return String(scriptText[..<endIndex]) + "..."
    }
    
    var audioFileURL: URL? {
        guard let path = audioFilePath else { return nil }
        return URL(fileURLWithPath: path)
    }
    
    func incrementPlayCount() {
        playCount += 1
        lastPlayedAt = Date()
    }
    
    static func create(
        scriptText: String,
        category: Category?,
        repetitions: Int16 = 3,
        privacyMode: Bool = true,
        in context: NSManagedObjectContext
    ) -> SelftalkScript {
        let script = SelftalkScript(context: context)
        script.id = UUID()
        script.scriptText = scriptText
        script.category = category
        script.repetitions = repetitions
        script.privacyModeEnabled = privacyMode
        script.createdAt = Date()
        script.updatedAt = Date()
        script.playCount = 0
        return script
    }
}