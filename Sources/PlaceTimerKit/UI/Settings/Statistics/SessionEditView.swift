import PlaceTimerCore
import SwiftUI

/// Bir oturumun saatini ve yerini düzeltir. Açık oturumun yalnızca
/// başlangıcı değişir: bitişi yok, yerini de otomatik takip yönetiyor.
struct SessionEditView: View {
    let coordinator: AppCoordinator
    @State private var draft: Session
    @State private var end: Date
    private let isCurrent: Bool
    @Environment(\.dismiss) private var dismiss

    init(coordinator: AppCoordinator, session: Session) {
        self.coordinator = coordinator
        _draft = State(initialValue: session)
        _end = State(initialValue: session.endedAt ?? Date())
        isCurrent = session.endedAt == nil
    }

    private var edited: Session {
        var session = draft
        if !isCurrent { session.endedAt = end }
        return session
    }

    var body: some View {
        let error = coordinator.validateEdit(edited)

        Form {
            DatePicker("Başlangıç", selection: $draft.startedAt)
            if !isCurrent {
                DatePicker("Bitiş", selection: $end)
            }
            Picker("Yer", selection: $draft.placeID) {
                Text("Bilinmeyen yer").tag(UUID?.none)
                ForEach(coordinator.knownPlaces) { place in
                    Text(place.displayName).tag(Optional(place.id))
                }
            }
            .disabled(isCurrent)

            if let error {
                Label(EditErrorText.message(error), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
        .formStyle(.grouped)
        .environment(\.locale, Locale(identifier: "tr_TR"))
        .frame(width: 380)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Vazgeç") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Kaydet") {
                    if coordinator.updateSession(edited) == nil { dismiss() }
                }
                .disabled(error != nil)
            }
        }
    }
}
