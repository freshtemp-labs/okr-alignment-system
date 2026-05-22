import SwiftUI

// MARK: - ValuePicker

/// A combined numeric input control with stepper and direct text entry for OKR values.
///
/// `ValuePicker` provides a dual-interface for numeric value selection:
/// - Stepper buttons for incremental adjustments (+/- 1 or +/- 10)
/// - Direct text field for precise value entry
/// - Optional unit selector
///
/// The component validates input to ensure values stay within specified bounds.
///
/// ## Example
/// ```swift
/// ValuePicker(
///     title: "Current Value",
///     value: $currentValue,
///     unit: $unit,
///     min: 0,
///     max: 100
/// )
/// ```
public struct ValuePicker: View {
    // MARK: - Properties
    
    /// The title label displayed above the picker.
    let title: String
    
    /// The bound numeric value.
    @Binding var value: Double
    
    /// The bound unit string (e.g., "%", "users").
    @Binding var unit: String?
    
    /// The minimum allowed value.
    let min: Double
    
    /// The maximum allowed value.
    let max: Double
    
    /// The step increment for the stepper buttons.
    let step: Double
    
    /// Whether to show the unit selector.
    let showUnitSelector: Bool
    
    /// Available unit options for the selector.
    let unitOptions: [String]
    
    /// Local text representation for the text field.
    @State private var textValue: String = ""
    
    /// Whether the text field has a validation error.
    @State private var hasError: Bool = false
    
    // MARK: - Initialization
    
    /// Creates a new value picker.
    /// - Parameters:
    ///   - title: The label text.
    ///   - value: Binding to the numeric value.
    ///   - unit: Binding to the unit string (optional).
    ///   - min: Minimum allowed value (default: 0).
    ///   - max: Maximum allowed value (default: 999999).
    ///   - step: Stepper increment (default: 1).
    ///   - showUnitSelector: Whether to show unit dropdown (default: true).
    ///   - unitOptions: Available units for selection (default: ["%", "count", "$", "days", "hours"]).
    public init(
        title: String,
        value: Binding<Double>,
        unit: Binding<String?> = .constant(nil),
        min: Double = 0,
        max: Double = 999999,
        step: Double = 1,
        showUnitSelector: Bool = true,
        unitOptions: [String] = ["%", "count", "$", "days", "hours", "users", "points"]
    ) {
        self.title = title
        self._value = value
        self._unit = unit
        self.min = min
        self.max = max
        self.step = step
        self.showUnitSelector = showUnitSelector
        self.unitOptions = unitOptions
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
            
            HStack(spacing: 12) {
                // Stepper controls
                HStack(spacing: 0) {
                    Button {
                        adjustValue(by: -step)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 32, height: 32)
                            .foregroundStyle(canDecrement ? .white : .gray)
                            .background(canDecrement ? Color.white.opacity(0.1) : Color.white.opacity(0.03))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canDecrement)
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    // Direct text input
                    TextField("Value", text: $textValue)
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .frame(width: 60)
                        .textFieldStyle(.plain)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .onChange(of: textValue) { _, newValue in
                            validateAndUpdate(from: newValue)
                        }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    Button {
                        adjustValue(by: step)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 32, height: 32)
                            .foregroundStyle(canIncrement ? .white : .gray)
                            .background(canIncrement ? Color.white.opacity(0.1) : Color.white.opacity(0.03))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canIncrement)
                }
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(hasError ? Color.red.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
                )
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
                .onAppear {
                    textValue = formatValue(value)
                }
                .onChange(of: value) { _, newValue in
                    textValue = formatValue(newValue)
                }
                
                // Unit selector
                if showUnitSelector {
                    Menu {
                        Button("None") { unit = nil }
                        ForEach(unitOptions, id: \.self) { option in
                            Button(option) { unit = option }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(unit ?? "—")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(red: 148/255, green: 163/255, blue: 184/255))
                        }
                        .frame(width: 60, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    #if os(macOS)
                    .menuStyle(.borderlessButton)
                    #endif
                }
            }
            
            if hasError {
                Text("Value must be between \(Int(min)) and \(Int(max))")
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.8))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title): \(formatValue(value)) \(unit ?? "")")
    }
    
    // MARK: - Computed Properties
    
    private var canDecrement: Bool {
        value - step >= min
    }
    
    private var canIncrement: Bool {
        value + step <= max
    }
    
    // MARK: - Helpers
    
    /// Adjusts the current value by the given delta, clamped to bounds.
    private func adjustValue(by delta: Double) {
        let newValue = (value + delta).clamped(to: min...max)
        value = newValue
        textValue = formatValue(newValue)
        hasError = false
    }
    
    /// Validates text input and updates the bound value.
    private func validateAndUpdate(from text: String) {
        let filtered = text.filter { $0.isNumber || $0 == "." }
        if filtered != text {
            textValue = filtered
            return
        }
        
        if let newValue = Double(text) {
            if newValue >= min && newValue <= max {
                value = newValue
                hasError = false
            } else {
                hasError = true
            }
        } else if text.isEmpty {
            hasError = false
        } else {
            hasError = true
        }
    }
    
    /// Formats a double value as a clean string.
    private func formatValue(_ val: Double) -> String {
        if val == Double(Int(val)) {
            return String(Int(val))
        }
        return String(format: "%.1f", val)
    }
}

// MARK: - Helper Extension

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Previews

#Preview("Default ValuePicker") {
    @Previewable @State var value: Double = 50
    @Previewable @State var unit: String? = "%"
    
    ValuePicker(
        title: "Current Value",
        value: $value,
        unit: $unit,
        min: 0,
        max: 100
    )
    .padding()
    .background(Color(red: 15/255, green: 23/255, blue: 42/255))
}

#Preview("Without Unit Selector") {
    @Previewable @State var value: Double = 100
    
    ValuePicker(
        title: "Target Value",
        value: $value,
        showUnitSelector: false,
        min: 1,
        max: 1000,
        step: 10
    )
    .padding()
    .background(Color(red: 15/255, green: 23/255, blue: 42/255))
}

#Preview("At Boundaries") {
    @Previewable @State var value: Double = 0
    @Previewable @State var unit: String? = "users"
    
    ValuePicker(
        title: "Users Acquired",
        value: $value,
        unit: $unit,
        min: 0,
        max: 10000,
        step: 100
    )
    .padding()
    .background(Color(red: 15/255, green: 23/255, blue: 42/255))
}
