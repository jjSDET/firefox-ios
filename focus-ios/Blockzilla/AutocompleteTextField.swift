/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

// This code is loosely based on https://github.com/Antol/APAutocompleteTextField

import UIKit

/// Delegate for the text field events. Since AutocompleteTextField owns the UITextFieldDelegate,
/// callers must use this instead.
protocol AutocompleteTextFieldDelegate: class {
    func autocompleteTextField(_ autocompleteTextField: AutocompleteTextField, didEnterText text: String)
    func autocompleteTextFieldShouldReturn(_ autocompleteTextField: AutocompleteTextField) -> Bool
    func autocompleteTextFieldShouldBeginEditing(_ autocompleteTextField: AutocompleteTextField) -> Bool
    func autocompleteTextFieldDidBeginEditing(_ autocompleteTextField: AutocompleteTextField)
    func autocompleteTextFieldShouldEndEditing(_ autocompleteTextField: AutocompleteTextField) -> Bool
    func autocompleteTextFieldDidEndEditing(_ autocompleteTextField: AutocompleteTextField)
}

class AutocompleteTextField: UITextField, UITextFieldDelegate {
    var autocompleteDelegate: AutocompleteTextFieldDelegate?

    private var completionActive = false
    private var canAutocomplete = true

    // This variable is a solution to get the right behavior for refocusing
    // the AutocompleteTextField. The initial transition into Overlay Mode
    // doesn't involve the user interacting with AutocompleteTextField.
    // Thus, we update shouldApplyCompletion in touchesBegin() to reflect whether
    // the highlight is active and then the text field is updated accordingly
    // in touchesEnd() (eg. applyCompletion() is called or not)
    private var shouldApplyCompletion = false
    private var enteredText = ""
    private var previousSuggestion = ""

    let highlightColor = UIConstants.colors.urlTextHighlight

    override var text: String? {
        didSet {
            // textDidChange is not called when directly setting the text property, so fire it manually.
            textDidChange(textField: self)
        }
    }

    init() {
        super.init(frame: CGRect.zero)

        super.delegate = self
        super.addTarget(self, action: #selector(textDidChange), for: .editingChanged)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func highlightAll() {
        if let text = text {
            if !text.isEmpty {
                let attributedString = NSMutableAttributedString(string: text)
                attributedString.addAttribute(NSBackgroundColorAttributeName, value: highlightColor, range: NSMakeRange(0, (text).characters.count))
                attributedText = attributedString

                enteredText = ""
                completionActive = true
            }
        }

        selectedTextRange = textRange(from: beginningOfDocument, to: beginningOfDocument)
    }

    private func normalizeString(_ string: String) -> String {
        return string.lowercased().trimmingCharacters(in: .whitespaces)
    }

    /// Commits the completion by setting the text and removing the highlight.
    private func applyCompletion() {
        if completionActive {
            if let text = text {
                self.attributedText = NSAttributedString(string: text)
                enteredText = text
            }
            completionActive = false
            previousSuggestion = ""

            self.autocompleteDelegate?.autocompleteTextField(self, didEnterText: self.enteredText.trimmingCharacters(in: .whitespaces))
        }
    }

    /// Removes the autocomplete-highlighted text from the field.
    private func removeCompletion() {
        if completionActive {
            // Workaround for stuck highlight bug.
            if enteredText.characters.count == 0 {
                attributedText = NSAttributedString(string: " ")
            }

            attributedText = NSAttributedString(string: enteredText)
            completionActive = false
        }
    }

    // `shouldChangeCharactersInRange` is called before the text changes, and textDidChange is called after.
    // Since the text has changed, remove the completion here, and SELtextDidChange will fire the callback to
    // get the new autocompletion.
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Accept autocompletions if we're adding characters.
        canAutocomplete = !string.isEmpty

        if completionActive {
            if string.isEmpty {
                // Characters are being deleted, so clear the autocompletion, but don't change the text.
                removeCompletion()
                return false
            }
            removeCompletionIfRequiredForEnteredString(string: string)
        }
        return true
    }

    private func removeCompletionIfRequiredForEnteredString(string: String) {
        // If user-entered text does not start with previous suggestion then remove the completion.

        let actualEnteredString = enteredText + string
        // Detecting the keyboard type, and remove hightlight in "zh-Hans" and "ja-JP"
        if !previousSuggestion.startsWith(other: normalizeString(actualEnteredString)) ||
            UIApplication.shared.textInputMode?.primaryLanguage == "zh-Hans" ||
            UIApplication.shared.textInputMode?.primaryLanguage == "ja-JP" {
            removeCompletion()
        }
        enteredText = actualEnteredString
    }

    func setAutocompleteSuggestion(_ suggestion: String?) {
        // Setting the autocomplete suggestion during multi-stage input will break the session since the text
        // is not fully entered. If `markedTextRange` is nil, that means the multi-stage input is complete, so
        // it's safe to append the suggestion.
        if let suggestion = suggestion, isEditing && canAutocomplete && markedTextRange == nil {
            // Check that the length of the entered text is shorter than the length of the suggestion.
            // This ensures that completionActive is true only if there are remaining characters to
            // suggest (which will suppress the caret).
            if suggestion.startsWith(other: normalizeString(enteredText)) && normalizeString(enteredText).characters.count < suggestion.characters.count {
                let endingString = suggestion.substring(from: suggestion.index(suggestion.startIndex, offsetBy: normalizeString(enteredText).characters.count))
                let completedAndMarkedString = NSMutableAttributedString(string: enteredText + endingString)
                completedAndMarkedString.addAttribute(NSBackgroundColorAttributeName, value: highlightColor, range: NSMakeRange(enteredText.characters.count, endingString.characters.count))
                attributedText = completedAndMarkedString
                completionActive = true
                previousSuggestion = suggestion
                return
            }
        }
        removeCompletion()
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return autocompleteDelegate?.autocompleteTextFieldShouldBeginEditing(self) ?? true
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        applyCompletion()
        return autocompleteDelegate?.autocompleteTextFieldShouldEndEditing(self) ?? true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        autocompleteDelegate?.autocompleteTextFieldDidBeginEditing(self)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        autocompleteDelegate?.autocompleteTextFieldDidEndEditing(self)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return autocompleteDelegate?.autocompleteTextFieldShouldReturn(self) ?? true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        removeCompletion()
        return true
    }

    override func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        // Clear the autocompletion if any provisionally inserted text has been
        // entered (e.g., a partial composition from a Japanese keyboard).
        removeCompletion()
        super.setMarkedText(markedText, selectedRange: selectedRange)
    }

    func textDidChange(textField: UITextField) {
        if completionActive {
            // Immediately reuse the previous suggestion if it's still valid.
            setAutocompleteSuggestion(previousSuggestion)
        } else {
            // Updates entered text while completion is not active. If it is
            // active, enteredText will already be updated from
            // removeCompletionIfRequiredForEnteredString.
            enteredText = text ?? ""
        }
        self.autocompleteDelegate?.autocompleteTextField(self, didEnterText: self.enteredText.trimmingCharacters(in: .whitespaces))

    }

    override func deleteBackward() {
        removeCompletion()
        super.deleteBackward()
    }

    override func caretRect(for forPosition: UITextPosition) -> CGRect {
        return completionActive ? CGRect.zero : super.caretRect(for: forPosition)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        shouldApplyCompletion = completionActive
        if !completionActive {
            super.touchesBegan(touches, with: event)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !completionActive {
            super.touchesMoved(touches, with: event)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !shouldApplyCompletion {
            super.touchesEnded(touches, with: event)
        } else {
            applyCompletion()

            // Set the current position to the end of the text.
            selectedTextRange = textRange(from: endOfDocument, to: endOfDocument)

            shouldApplyCompletion = !shouldApplyCompletion
        }
    }
}
