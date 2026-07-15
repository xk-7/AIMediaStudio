import SwiftUI
import AppKit

/// An editable combo box: pick a value from a dropdown list or type a custom one.
/// Used for model selection where the list is fetched from the provider.
struct ComboBoxField: NSViewRepresentable {
    @Binding var text: String
    var items: [String]
    var placeholder: String = ""

    func makeNSView(context: Context) -> NSComboBox {
        let combo = NSComboBox()
        combo.isEditable = true
        combo.completes = true
        combo.usesDataSource = false
        combo.delegate = context.coordinator
        combo.placeholderString = placeholder
        combo.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        combo.addItems(withObjectValues: items)
        combo.stringValue = text
        return combo
    }

    func updateNSView(_ nsView: NSComboBox, context: Context) {
        let current = (nsView.objectValues as? [String]) ?? []
        if current != items {
            nsView.removeAllItems()
            nsView.addItems(withObjectValues: items)
        }
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSComboBoxDelegate {
        var parent: ComboBoxField
        init(_ parent: ComboBoxField) { self.parent = parent }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let combo = notification.object as? NSComboBox else { return }
            DispatchQueue.main.async {
                let index = combo.indexOfSelectedItem
                if index >= 0, let value = combo.itemObjectValue(at: index) as? String {
                    self.parent.text = value
                }
            }
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let combo = notification.object as? NSComboBox else { return }
            parent.text = combo.stringValue
        }
    }
}
