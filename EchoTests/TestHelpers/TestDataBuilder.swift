import Foundation
import CoreData
@testable import Echo

// MARK: - Test Data Builder Protocol
protocol TestDataBuilder {
    associatedtype Entity
    
    func build(in context: NSManagedObjectContext) -> Entity
    func buildAndSave(in context: NSManagedObjectContext) throws -> Entity
}

extension TestDataBuilder {
    func buildAndSave(in context: NSManagedObjectContext) throws -> Entity {
        let entity = build(in: context)
        try context.save()
        return entity
    }
}

// MARK: - SelftalkScript Builder
class SelftalkScriptBuilder: TestDataBuilder {
    typealias Entity = SelftalkScript
    
    private var id: UUID = UUID()
    private var scriptText: String = "Default test script"
    private var repetitions: Int16 = 1
    private var intervalSeconds: TimeInterval = 2.0
    private var privateModeEnabled: Bool = false
    private var audioFilePath: String?
    private var audioDuration: TimeInterval = 0.0
    private var transcribedText: String?
    private var transcriptionLanguage: String = "en-US"
    private var playCount: Int32 = 0
    private var creationDate: Date = Date()
    private var lastModified: Date = Date()
    private var tags: [Tag] = []
    
    // Builder methods
    func withId(_ id: UUID) -> SelftalkScriptBuilder {
        self.id = id
        return self
    }
    
    func withScriptText(_ text: String) -> SelftalkScriptBuilder {
        self.scriptText = text
        return self
    }
    
    func withRepetitions(_ repetitions: Int16) -> SelftalkScriptBuilder {
        self.repetitions = repetitions
        return self
    }
    
    func withIntervalSeconds(_ interval: TimeInterval) -> SelftalkScriptBuilder {
        self.intervalSeconds = interval
        return self
    }
    
    func withPrivateMode(_ enabled: Bool) -> SelftalkScriptBuilder {
        self.privateModeEnabled = enabled
        return self
    }
    
    func withAudioFile(path: String, duration: TimeInterval) -> SelftalkScriptBuilder {
        self.audioFilePath = path
        self.audioDuration = duration
        return self
    }
    
    func withTranscription(_ text: String, language: String = "en-US") -> SelftalkScriptBuilder {
        self.transcribedText = text
        self.transcriptionLanguage = language
        return self
    }
    
    func withPlayCount(_ count: Int32) -> SelftalkScriptBuilder {
        self.playCount = count
        return self
    }
    
    func withDates(created: Date, modified: Date) -> SelftalkScriptBuilder {
        self.creationDate = created
        self.lastModified = modified
        return self
    }
    
    func withTags(_ tags: [Tag]) -> SelftalkScriptBuilder {
        self.tags = tags
        return self
    }
    
    func withTag(_ tag: Tag) -> SelftalkScriptBuilder {
        self.tags.append(tag)
        return self
    }
    
    func build(in context: NSManagedObjectContext) -> SelftalkScript {
        let script = SelftalkScript.create(
            scriptText: scriptText,
            repetitions: repetitions,
            privateMode: privateModeEnabled,
            in: context
        )
        
        script.id = id
        script.intervalSeconds = intervalSeconds
        script.audioFilePath = audioFilePath
        script.audioDuration = audioDuration
        script.transcribedText = transcribedText
        script.transcriptionLanguage = transcriptionLanguage
        script.playCount = playCount
        script.creationDate = creationDate
        script.lastModified = lastModified
        
        // Add tags
        for tag in tags {
            script.addToTags(tag)
        }
        
        return script
    }
    
    // Convenience method for creating multiple scripts
    static func createMultiple(
        count: Int,
        in context: NSManagedObjectContext,
        configure: ((SelftalkScriptBuilder, Int) -> SelftalkScriptBuilder)? = nil
    ) -> [SelftalkScript] {
        var scripts: [SelftalkScript] = []
        
        for i in 0..<count {
            var builder = SelftalkScriptBuilder()
                .withScriptText("Test script \(i + 1)")
                .withId(UUID())
            
            if let configure = configure {
                builder = configure(builder, i)
            }
            
            scripts.append(builder.build(in: context))
        }
        
        return scripts
    }
}

// MARK: - Tag Builder
class TagBuilder: TestDataBuilder {
    typealias Entity = Tag
    
    private var name: String = "Default Tag"
    private var colorHex: String = "#007AFF"
    private var creationDate: Date = Date()
    private var scripts: [SelftalkScript] = []
    
    func withName(_ name: String) -> TagBuilder {
        self.name = name
        return self
    }
    
    func withColorHex(_ colorHex: String) -> TagBuilder {
        self.colorHex = colorHex
        return self
    }
    
    func withCreationDate(_ date: Date) -> TagBuilder {
        self.creationDate = date
        return self
    }
    
    func withScripts(_ scripts: [SelftalkScript]) -> TagBuilder {
        self.scripts = scripts
        return self
    }
    
    func withScript(_ script: SelftalkScript) -> TagBuilder {
        self.scripts.append(script)
        return self
    }
    
    func build(in context: NSManagedObjectContext) -> Tag {
        let tag = Tag.findOrCreateNormalized(name: name, in: context)
        tag.colorHex = colorHex
        tag.creationDate = creationDate
        
        // Add scripts
        for script in scripts {
            tag.addToScripts(script)
        }
        
        return tag
    }
    
    // Convenience method for creating multiple tags
    static func createMultiple(
        count: Int,
        in context: NSManagedObjectContext,
        configure: ((TagBuilder, Int) -> TagBuilder)? = nil
    ) -> [Tag] {
        var tags: [Tag] = []
        
        for i in 0..<count {
            var builder = TagBuilder()
                .withName("Tag \(i + 1)")
            
            if let configure = configure {
                builder = configure(builder, i)
            }
            
            tags.append(builder.build(in: context))
        }
        
        return tags
    }
}

// MARK: - Test Data Factory
class TestDataFactory {
    
    /// Creates a complete test dataset with scripts and tags
    static func createCompleteTestData(in context: NSManagedObjectContext) -> (scripts: [SelftalkScript], tags: [Tag]) {
        // Create tags
        let tags = TagBuilder.createMultiple(count: 3, in: context) { builder, index in
            let tagNames = ["Motivation", "Health", "Relationships"]
            let colors = ["#007AFF", "#34C759", "#FF3B30"]
            return builder
                .withName(tagNames[index])
                .withColorHex(colors[index])
        }
        
        // Create scripts with varying properties
        let scripts = SelftalkScriptBuilder.createMultiple(count: 5, in: context) { builder, index in
            let scriptTexts = [
                "I am confident and capable of achieving my goals.",
                "I choose healthy foods that nourish my body.",
                "I communicate with kindness and understanding.",
                "I am grateful for all the good things in my life.",
                "I face challenges with courage and determination."
            ]
            
            return builder
                .withScriptText(scriptTexts[index])
                .withRepetitions(Int16((index % 3) + 1))
                .withPrivateMode(index % 2 == 0)
                .withPlayCount(Int32(index * 2))
                .withTag(tags[index % tags.count])
        }
        
        return (scripts: scripts, tags: tags)
    }
    
    /// Creates test data for specific testing scenarios
    static func createScenarioData(scenario: TestScenario, in context: NSManagedObjectContext) -> TestScenarioData {
        switch scenario {
        case .emptyDatabase:
            return TestScenarioData(scripts: [], tags: [])
            
        case .singleScript:
            let tag = TagBuilder().withName("Test Category").build(in: context)
            let script = SelftalkScriptBuilder()
                .withScriptText("Single test script")
                .withTag(tag)
                .build(in: context)
            return TestScenarioData(scripts: [script], tags: [tag])
            
        case .scriptsWithAudio:
            let tag = TagBuilder().withName("Audio Tests").build(in: context)
            let scripts = SelftalkScriptBuilder.createMultiple(count: 3, in: context) { builder, index in
                return builder
                    .withScriptText("Script with audio \(index + 1)")
                    .withAudioFile(path: "/test/audio\(index + 1).m4a", duration: TimeInterval(10 + index * 5))
                    .withTranscription("Transcribed text for script \(index + 1)")
                    .withTag(tag)
            }
            return TestScenarioData(scripts: scripts, tags: [tag])
            
        case .scriptsWithoutAudio:
            let tag = TagBuilder().withName("No Audio").build(in: context)
            let scripts = SelftalkScriptBuilder.createMultiple(count: 2, in: context) { builder, index in
                return builder
                    .withScriptText("Script without audio \(index + 1)")
                    .withTag(tag)
            }
            return TestScenarioData(scripts: scripts, tags: [tag])
            
        case .manyScripts:
            let (scripts, tags) = createCompleteTestData(in: context)
            // Add more scripts
            let additionalScripts = SelftalkScriptBuilder.createMultiple(count: 20, in: context) { builder, index in
                return builder
                    .withScriptText("Additional script \(index + 1)")
                    .withTag(tags[index % tags.count])
            }
            return TestScenarioData(scripts: scripts + additionalScripts, tags: tags)
        }
    }
}

// MARK: - Test Scenarios
enum TestScenario {
    case emptyDatabase
    case singleScript
    case scriptsWithAudio
    case scriptsWithoutAudio
    case manyScripts
}

struct TestScenarioData {
    let scripts: [SelftalkScript]
    let tags: [Tag]
}

// MARK: - Test Data Extensions
extension SelftalkScript {
    /// Creates a minimal script for testing
    static func createTestScript(in context: NSManagedObjectContext) -> SelftalkScript {
        return SelftalkScriptBuilder()
            .withScriptText("Test script")
            .build(in: context)
    }
    
    /// Creates a script with all properties set
    static func createFullTestScript(in context: NSManagedObjectContext) -> SelftalkScript {
        let tag = Tag.findOrCreateNormalized(name: "Test Tag", in: context)
        return SelftalkScriptBuilder()
            .withScriptText("Full test script with all properties")
            .withRepetitions(5)
            .withIntervalSeconds(3.0)
            .withPrivateMode(true)
            .withAudioFile(path: "/test/audio.m4a", duration: 15.0)
            .withTranscription("This is a transcribed test script")
            .withPlayCount(10)
            .withTag(tag)
            .build(in: context)
    }
}

extension Tag {
    /// Creates a minimal tag for testing
    static func createTestTag(in context: NSManagedObjectContext) -> Tag {
        return TagBuilder()
            .withName("Test Tag")
            .build(in: context)
    }
}