import FouleeDomain
import SwiftUI

/// The one tile a figure is drawn in, on every screen (#811): the iPhone, the
/// watch, the widgets and the Live Activity.
///
/// Two shapes and three sizes, and nothing else varies:
/// - `.card`: the tinted symbol and title on top, the figure under it, then an
///   optional detail line. Today, the recap, a workout, the watch's home.
/// - `.compact`: the figure centred, its tinted caption under it. A screen
///   read while moving: the live outing, the watch's session, the Dynamic
///   Island.
///
/// The background and the padding are the container's: glass on the iPhone,
/// a fill on the watch, none in a widget.
public struct MetricTile: View {
    public enum Shape: Sendable {
        case card
        case compact
    }

    public enum Size: Sendable {
        /// The watch, the Dynamic Island, a Lock Screen widget.
        case small
        /// A screen read at a glance: a workout, the recap.
        case medium
        /// The iPhone's main figures: Today, a mirrored outing.
        case large

        var valuePoints: CGFloat {
            switch self {
            case .small: 18
            case .medium: 22
            case .large: 26
            }
        }

        var captionFont: Font {
            self == .small ? .caption2 : FouleeFont.footnote
        }
    }

    /// What VoiceOver reads for the tile.
    public enum Speech: Sendable {
        /// One element: this label and value, in words where the written
        /// figure reads wrong (« 8 240 pas sur 10 000 pas », « bpm »).
        case spoken(label: String, value: String?)
        /// One element, its texts read in the order drawn.
        case combined
    }

    private let title: String?
    private let value: String
    private let unit: String?
    private let detail: String?
    private let icon: String?
    private let tint: Color
    private let shape: Shape
    private let size: Size
    private let speech: Speech

    /// - Parameter unit: drawn beside the figure in a card, small and grey
    ///   (« kcal », « / 10 000 »).
    /// - Parameter detail: a card's line under the figure.
    public init(
        title: String?,
        value: String,
        unit: String? = nil,
        detail: String? = nil,
        icon: String?,
        tint: Color,
        shape: Shape,
        size: Size,
        speech: Speech = .combined
    ) {
        self.title = title
        self.value = value
        self.unit = unit
        self.detail = detail
        self.icon = icon
        self.tint = tint
        self.shape = shape
        self.size = size
        self.speech = speech
    }

    /// A catalogue metric: its symbol, its colour and its title.
    /// - Parameter spokenValue: the figure as VoiceOver says it, when the
    ///   written one reads wrong; by default the figure and its unit.
    public init(
        _ metric: MetricID,
        value: String,
        unit: String? = nil,
        spokenValue: String? = nil,
        shape: Shape = .card,
        size: Size = .large
    ) {
        self.init(
            title: metric.title,
            value: value,
            unit: unit,
            icon: metric.glyph,
            tint: metric.labelTint,
            shape: shape,
            size: size,
            speech: .spoken(label: metric.title, value: spokenValue ?? unit.map { "\(value) \($0)" } ?? value)
        )
    }

    public var body: some View {
        content.modifier(TileSpeech(speech: speech))
    }

    @ViewBuilder private var content: some View {
        switch shape {
        case .card: card
        case .compact: compact
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: size == .small ? 2 : 6) {
            if title != nil || icon != nil {
                caption
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                figure
                if let unit {
                    Text(unit)
                        .font(size.captionFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            if let detail {
                Text(detail)
                    .font(size == .small ? .caption2 : FouleeFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var compact: some View {
        VStack(spacing: 2) {
            figure
            // One line, shrunk if needed: at the largest sizes a caption split
            // mid-word (« Distance », #408; « pa/s », #588).
            caption
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var figure: some View {
        Text(value)
            .scaledNumericFont(size: size.valuePoints, weight: shape == .card ? .bold : .semibold)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
    }

    @ViewBuilder private var caption: some View {
        let font = shape == .card ? size.captionFont.weight(.semibold) : size.captionFont
        switch (title, icon) {
        case let (title?, icon?):
            Label(title, systemImage: icon).font(font).foregroundStyle(tint)
        case let (title?, nil):
            Text(title).font(font).foregroundStyle(tint)
        case let (nil, icon?):
            Image(systemName: icon).font(font.weight(.bold)).foregroundStyle(tint)
        case (nil, nil):
            EmptyView()
        }
    }
}

private struct TileSpeech: ViewModifier {
    let speech: MetricTile.Speech

    func body(content: Content) -> some View {
        switch speech {
        case let .spoken(label, value):
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(label))
                .accessibilityValue(Text(value ?? ""))
        case .combined:
            content.accessibilityElement(children: .combine)
        }
    }
}
