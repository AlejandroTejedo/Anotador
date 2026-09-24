import Foundation
import Testing
@testable import Anotador

struct LocalizationTests {
    private var english: Bundle? {
        Bundle(for: AppModel.self).path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:))
    }

    @Test func englishIsBundled() throws {
        let bundle = try #require(english)
        #expect(bundle.localizedString(forKey: "Nueva reunión", value: nil, table: nil) == "New meeting")
        #expect(bundle.localizedString(forKey: "Participantes", value: nil, table: nil) == "Participants")
    }

    @Test func permissionPromptsAreTranslated() throws {
        let bundle = try #require(english)
        let mic = bundle.localizedString(forKey: "NSMicrophoneUsageDescription", value: nil, table: "InfoPlist")
        #expect(mic.hasPrefix("Anotador uses the microphone"))
    }

    @Test func countersUsePluralRules() throws {
        let bundle = try #require(english)
        let format = bundle.localizedString(forKey: "%lld acciones", value: nil, table: nil)
        #expect(String.localizedStringWithFormat(format, 1) == "1 action item")
        #expect(String.localizedStringWithFormat(format, 3) == "3 action items")
    }
}
