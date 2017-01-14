/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit

protocol AutocompleteTextFieldSource: class {
    func completion(forText text: String) -> String?
}

@objc protocol AutocompleteTextFieldDelegate: class {
    @objc optional func autocompleteTextFieldShouldBeginEditing(_ autocompleteTextField: AutocompleteTextField) -> Bool
    @objc optional func autocompleteTextFieldShouldEndEditing(_ autocompleteTextField: AutocompleteTextField) -> Bool
    @objc optional func autocompleteTextFieldShouldReturn(_ autocompleteTextField: AutocompleteTextField) -> Bool
    @objc optional func autocompleteTextField(_ autocompleteTextField: AutocompleteTextField, didTextChange text: String)
}

class AutocompleteTextField: UITextField, UITextFieldDelegate {
    weak var source: AutocompleteTextFieldSource?
    weak var autocompleteDelegate: AutocompleteTextFieldDelegate?

    /// The range of the current completion, or nil if there is no active completion.
    private var completionRange: NSRange?

    // The last string used as a replacement in shouldChangeCharactersInRange.
    private var lastReplacement: String?

    init() {
        super.init(frame: CGRect.zero)
        addTarget(self, action: #selector(textDidChange), for: .editingChanged)
        delegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var text: String? {
        didSet {
            applyCompletion()
            super.text = text
            autocompleteDelegate?.autocompleteTextField?(self, didTextChange: text ?? "")
        }
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        lastReplacement = string
        return true
    }

    @objc private func textDidChange() {
        removeCompletion()

        // Try setting a completion if we're not deleting and we're typing at the end of the text field.
        let isAtEnd = selectedTextRange?.start == endOfDocument
        let textBeforeCompletion = text
        let isEmpty = lastReplacement?.isEmpty ?? true
        if !isEmpty, isAtEnd, markedTextRange == nil, let completion = source?.completion(forText: text ?? "") {
            setCompletion(completion)
        }

        // Fire the delegate with the text the user typed (not including the completion).
        autocompleteDelegate?.autocompleteTextField?(self, didTextChange: textBeforeCompletion ?? "")
    }

    override func deleteBackward() {
        lastReplacement = nil

        guard completionRange == nil else {
            // If we have an active completion, delete it without deleting any user-typed characters.
            removeCompletion()
            return
        }

        super.deleteBackward()
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return autocompleteDelegate?.autocompleteTextFieldShouldBeginEditing?(self) ?? true
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        applyCompletion()
        return autocompleteDelegate?.autocompleteTextFieldShouldEndEditing?(self) ?? true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return autocompleteDelegate?.autocompleteTextFieldShouldReturn?(self) ?? true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        applyCompletion()
        super.touchesBegan(touches, with: event)
    }

    override func caretRect(for forPosition: UITextPosition) -> CGRect {
        return (completionRange != nil) ? CGRect.zero : super.caretRect(for: forPosition)
    }

    func highlightAll() {
        let text = self.text
        self.text = nil
        setCompletion(text ?? "")
        selectedTextRange = textRange(from: beginningOfDocument, to: beginningOfDocument)
    }

    private func applyCompletion() {
        guard completionRange != nil else { return }

        completionRange = nil

        // Clear the current completion, then set the text without the attributed style.
        // The attributed string must have at least one character to clear the current style.
        let text = self.text ?? ""
        attributedText = NSAttributedString(string: " ")
        self.text = text

        // Move the cursor to the end of the completion.
        selectedTextRange = textRange(from: endOfDocument, to: endOfDocument)
    }

    private func removeCompletion() {
        guard let completionRange = completionRange else { return }

        applyCompletion()
        text = (text as NSString?)?.replacingCharacters(in: completionRange, with: "")
    }

    override func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        removeCompletion()
        super.setMarkedText(markedText, selectedRange: selectedRange)
    }

    private func setCompletion(_ completion: String) {
        let text = self.text ?? ""

        // Ignore this completion if it's empty or doesn't start with the current text.
        guard !completion.isEmpty, completion.lowercased().startsWith(other: text.lowercased()) else { return }

        // Add the completion suffix to the current text and highlight it.
        let completion = completion.substring(from: completion.index(completion.startIndex, offsetBy: text.characters.count))
        let attributed = NSMutableAttributedString(string: text + completion)
        let range = NSMakeRange((text as NSString).length, (completion as NSString).length)
        attributed.addAttribute(NSBackgroundColorAttributeName, value: UIConstants.colors.urlTextHighlight, range: range)
        attributedText = attributed
        completionRange = range
    }
}
