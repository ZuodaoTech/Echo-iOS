import Foundation
import SwiftUI

// Helper class for localization management
class LocalizationHelper {
    
    static let shared = LocalizationHelper()
    
    // Get localized sample scripts based on current locale
    func getLocalizedSampleScripts() -> [(category: String, text: String)] {
        let locale = Locale.current.languageCode ?? "en"
        
        switch locale {
        case "zh":
            return [
                (L10n.Category.breakingBadHabits, "我从来不吸烟，因为我珍惜健康，我也不喜欢被控制的感觉。"),
                (L10n.Category.buildingGoodHabits, "我总是在晚上十点前睡觉，因为这让我更健康，早晨充满活力。"),
                (L10n.Category.appropriatePositivity, "我虽然犯了错误，但也做对了很多事。错误是学习的机会，我会从中成长。")
            ]
        case "ja":
            return [
                (L10n.Category.breakingBadHabits, "私はタバコを吸いません。健康を大切にし、習慣に支配されたくないからです。"),
                (L10n.Category.buildingGoodHabits, "私は毎晩10時前に寝ます。健康的で、朝のエネルギーが素晴らしいからです。"),
                (L10n.Category.appropriatePositivity, "私は間違いを犯しましたが、うまくできたこともあります。間違いは学びの機会です。")
            ]
        case "es":
            return [
                (L10n.Category.breakingBadHabits, "Nunca fumo, porque apesta y odio ser controlado."),
                (L10n.Category.buildingGoodHabits, "Siempre me acuesto antes de las 10 p.m., porque es más saludable y me encanta despertar con energía."),
                (L10n.Category.appropriatePositivity, "Cometí algunos errores, pero también hice varias cosas bien. Los errores son oportunidades para mejorar.")
            ]
        case "fr":
            return [
                (L10n.Category.breakingBadHabits, "Je ne fume jamais, car cela sent mauvais et je déteste être contrôlé."),
                (L10n.Category.buildingGoodHabits, "Je me couche toujours avant 22h, car c'est plus sain et j'adore me réveiller plein d'énergie."),
                (L10n.Category.appropriatePositivity, "J'ai fait quelques erreurs, mais j'ai aussi bien réussi plusieurs choses. Les erreurs sont des opportunités d'amélioration.")
            ]
        case "de":
            return [
                (L10n.Category.breakingBadHabits, "Ich rauche nie, weil es stinkt und ich es hasse, kontrolliert zu werden."),
                (L10n.Category.buildingGoodHabits, "Ich gehe immer vor 22 Uhr ins Bett, weil es gesünder ist und ich es liebe, voller Energie aufzuwachen."),
                (L10n.Category.appropriatePositivity, "Ich habe einige Fehler gemacht, aber auch vieles gut gemacht. Fehler sind Lernchancen.")
            ]
        case "ko":
            return [
                (L10n.Category.breakingBadHabits, "나는 담배를 피우지 않습니다. 건강을 소중히 여기고 습관에 지배당하고 싶지 않기 때문입니다."),
                (L10n.Category.buildingGoodHabits, "나는 항상 밤 10시 전에 잠자리에 듭니다. 더 건강하고 활력 넘치는 아침을 맞이할 수 있기 때문입니다."),
                (L10n.Category.appropriatePositivity, "나는 실수를 했지만 잘한 일도 많습니다. 실수는 배움의 기회이며 성장할 수 있습니다.")
            ]
        case "it":
            return [
                (L10n.Category.breakingBadHabits, "Non fumo mai, perché puzza e odio essere controllato."),
                (L10n.Category.buildingGoodHabits, "Vado sempre a letto prima delle 22, perché è più salutare e amo svegliarmi pieno di energia."),
                (L10n.Category.appropriatePositivity, "Ho fatto alcuni errori, ma ho anche fatto molte cose bene. Gli errori sono opportunità di miglioramento.")
            ]
        case "pt":
            return [
                (L10n.Category.breakingBadHabits, "Nunca fumo, porque fede e odeio ser controlado."),
                (L10n.Category.buildingGoodHabits, "Sempre vou dormir antes das 22h, porque é mais saudável e adoro acordar com energia."),
                (L10n.Category.appropriatePositivity, "Cometi alguns erros, mas também fiz várias coisas bem. Erros são oportunidades de melhoria.")
            ]
        case "ru":
            return [
                (L10n.Category.breakingBadHabits, "Я никогда не курю, потому что это воняет, и я ненавижу быть под контролем."),
                (L10n.Category.buildingGoodHabits, "Я всегда ложусь спать до 10 вечера, потому что это здоровее, и я люблю просыпаться полным энергии."),
                (L10n.Category.appropriatePositivity, "Я сделал несколько ошибок, но также сделал многое правильно. Ошибки - это возможности для улучшения.")
            ]
        case "nl":
            return [
                (L10n.Category.breakingBadHabits, "Ik rook nooit, omdat het stinkt en ik haat het om gecontroleerd te worden."),
                (L10n.Category.buildingGoodHabits, "Ik ga altijd voor 22:00 naar bed, omdat het gezonder is en ik het heerlijk vind om vol energie wakker te worden."),
                (L10n.Category.appropriatePositivity, "Ik heb wat fouten gemaakt, maar ook veel dingen goed gedaan. Fouten zijn kansen om te verbeteren.")
            ]
        case "sv":
            return [
                (L10n.Category.breakingBadHabits, "Jag röker aldrig, för det stinker och jag hatar att bli kontrollerad."),
                (L10n.Category.buildingGoodHabits, "Jag går alltid och lägger mig före kl. 22, för det är hälsosammare och jag älskar att vakna full av energi."),
                (L10n.Category.appropriatePositivity, "Jag gjorde några misstag, men jag gjorde också flera saker bra. Misstag är möjligheter att förbättras.")
            ]
        case "no", "nb":
            return [
                (L10n.Category.breakingBadHabits, "Jeg røyker aldri, fordi det stinker og jeg hater å bli kontrollert."),
                (L10n.Category.buildingGoodHabits, "Jeg legger meg alltid før klokken 22, fordi det er sunnere og jeg elsker å våkne full av energi."),
                (L10n.Category.appropriatePositivity, "Jeg gjorde noen feil, men jeg gjorde også flere ting bra. Feil er muligheter til å forbedre seg.")
            ]
        case "da":
            return [
                (L10n.Category.breakingBadHabits, "Jeg ryger aldrig, fordi det stinker, og jeg hader at blive kontrolleret."),
                (L10n.Category.buildingGoodHabits, "Jeg går altid i seng før kl. 22, fordi det er sundere, og jeg elsker at vågne fuld af energi."),
                (L10n.Category.appropriatePositivity, "Jeg lavede nogle fejl, men jeg gjorde også flere ting godt. Fejl er muligheder for at forbedre sig.")
            ]
        case "pl":
            return [
                (L10n.Category.breakingBadHabits, "Nigdy nie palę, bo śmierdzi i nienawidzę być kontrolowany."),
                (L10n.Category.buildingGoodHabits, "Zawsze kładę się spać przed 22:00, bo to zdrowsze i uwielbiam budzić się pełen energii."),
                (L10n.Category.appropriatePositivity, "Popełniłem kilka błędów, ale też zrobiłem wiele rzeczy dobrze. Błędy to okazje do poprawy.")
            ]
        case "tr":
            return [
                (L10n.Category.breakingBadHabits, "Asla sigara içmem, çünkü kokuyor ve kontrol edilmekten nefret ediyorum."),
                (L10n.Category.buildingGoodHabits, "Her zaman saat 22:00'den önce yatarım, çünkü daha sağlıklı ve enerji dolu uyanmayı seviyorum."),
                (L10n.Category.appropriatePositivity, "Bazı hatalar yaptım, ama birçok şeyi de iyi yaptım. Hatalar gelişim fırsatlarıdır.")
            ]
        default: // English
            return [
                (L10n.Category.breakingBadHabits, "I never smoke, because it stinks, and I hate being controlled."),
                (L10n.Category.buildingGoodHabits, "I always go to bed before 10 p.m., because it's healthier, and I love waking up with a great deal of energy."),
                (L10n.Category.appropriatePositivity, "I made a few mistakes, but I also did several things well. Mistakes are a normal part of learning, and I can use them as an opportunity to improve.")
            ]
        }
    }
    
    // Get the appropriate transcription language code based on current locale
    func getDefaultTranscriptionLanguage() -> String {
        let locale = Locale.current
        let languageCode = locale.languageCode ?? "en"
        let regionCode = locale.regionCode ?? "US"
        
        // Map to our supported transcription languages
        switch languageCode {
        case "zh":
            return regionCode == "TW" || regionCode == "HK" ? "zh-TW" : "zh-CN"
        case "en":
            return "en-US"
        case "es":
            return "es-ES"
        case "fr":
            return "fr-FR"
        case "de":
            return "de-DE"
        case "ja":
            return "ja-JP"
        case "ko":
            return "ko-KR"
        case "it":
            return "it-IT"
        case "pt":
            return "pt-BR"
        case "ru":
            return "ru-RU"
        case "nl":
            return "nl-NL"
        case "sv":
            return "sv-SE"
        case "nb", "no":
            return "nb-NO"
        case "da":
            return "da-DK"
        case "pl":
            return "pl-PL"
        case "tr":
            return "tr-TR"
        case "ar":
            return "ar-SA"
        case "hi":
            return "hi-IN"
        default:
            return "en-US"
        }
    }
}

// Extension for localized strings in SwiftUI
extension String {
    var localized: LocalizedStringKey {
        LocalizedStringKey(self)
    }
    
    func localized(with arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}
