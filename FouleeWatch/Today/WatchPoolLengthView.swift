import FouleeDomain
import SwiftUI

/// The pool a swim is counted in (#751), asked before it starts: HealthKit
/// counts a length at each turn and needs to know how long one is. The last
/// pool chosen comes first, marked; any other length is set with the crown.
struct WatchPoolLengthView: View {
    /// The pool of the last swim, marked.
    var current: PoolLength
    var onStart: (PoolLength) -> Void
    var onCancel: () -> Void
    @State private var customMeters: Double

    init(current: PoolLength, onStart: @escaping (PoolLength) -> Void, onCancel: @escaping () -> Void) {
        self.current = current
        self.onStart = onStart
        self.onCancel = onCancel
        _customMeters = State(initialValue: current.meters.rounded())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    Text("Quel bassin ?")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(PoolLength.presets, id: \.self) { pool in
                        WatchPoolLengthButton(pool: pool, isCurrent: pool == current) { onStart(pool) }
                    }
                    Text("Autre longueur")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                        .accessibilityAddTraits(.isHeader)
                    Slider(value: $customMeters, in: PoolLength.customRange, step: 1) {
                        Text("Longueur du bassin")
                    }
                    .accessibilityValue(Text("\(Int(customMeters)) mètres"))
                    Button {
                        onStart(PoolLength(meters: customMeters))
                    } label: {
                        Text("Nager · \(PoolLength(meters: customMeters).label)")
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollBounceBehavior(.basedOnSize)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    WatchActivityCancelButton(cancel: onCancel)
                }
            }
        }
    }
}

/// One pool. Internal so a test can reach its tap through the `ForEach`.
struct WatchPoolLengthButton: View {
    var pool: PoolLength
    var isCurrent: Bool
    var select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack {
                Text(pool.label)
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark")
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityAddTraits(isCurrent ? [.isSelected] : [])
    }
}
