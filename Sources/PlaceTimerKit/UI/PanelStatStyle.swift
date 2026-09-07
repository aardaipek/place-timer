import SwiftUI

/// Paneldeki etiket–değer satırları.
///
/// `LabeledContent` varsayılan stiliyle yalnızca `Form` içinde iki yana
/// yaslanıyor; panelde etiketle değer yan yana yapışık kalıyordu. Değerlerin
/// aynı sütunda hizalanması, üç satırın göz gezdirilerek okunmasının tek yolu.
struct PanelStatStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Design.small) {
            configuration.label
                .foregroundStyle(.secondary)
            Spacer(minLength: Design.small)
            configuration.content
        }
    }
}

extension LabeledContentStyle where Self == PanelStatStyle {
    static var panelStat: PanelStatStyle { PanelStatStyle() }
}
