import CoreGraphics
import Foundation

/// Son kullanıcı girdisinden bu yana geçen süre.
///
/// `CGEventSource` yalnızca "en son ne zaman bir girdi oldu" saniyesini verir;
/// tuş vuruşlarını görmez ve Input Monitoring izni istemez.
public enum IdleReader {
    private static let anyInputEventType = CGEventType(rawValue: ~UInt32(0))!

    public static func idleSeconds() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: anyInputEventType
        )
    }
}
