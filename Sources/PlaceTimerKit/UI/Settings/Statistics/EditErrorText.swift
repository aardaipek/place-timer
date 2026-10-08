import PlaceTimerCore

enum EditErrorText {
    static func message(_ error: SessionHistory.EditError) -> String {
        switch error {
        case .differentPlaces: "Farklı yerlerdeki oturumlar birleştirilemez."
        case .tooFew: "Birleştirmek için aynı yerde en az iki oturum gerekiyor."
        case .invalidRange: "Bitiş, başlangıçtan sonra olmalı."
        case .future: "Başlangıç gelecekte olamaz."
        case .overlaps: "Bu saatler başka bir oturumla çakışıyor."
        }
    }
}
