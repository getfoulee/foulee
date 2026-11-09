import Foundation

extension LocalizedStringResource {
    /// Text already in the screen's language — a figure, a name, a label the
    /// kit wrote — for a component that takes a key (issue #587). Its key, « %@ »,
    /// is marked as not to be translated in the catalog.
    static func verbatim(_ text: String) -> LocalizedStringResource {
        "\(text)"
    }
}

nonisolated extension String {
    /// The first letter capitalised and the rest as written, for a line that
    /// opens with a formatted date: « Vendredi 9 octobre », not « Vendredi 9
    /// Octobre » like `capitalized` would.
    var sentenceCased: String {
        let initial = prefix(1).uppercased()
        return initial + dropFirst()
    }
}
