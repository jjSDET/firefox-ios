/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import SnapKit

protocol URLBarDelegate: class {
    func urlBar(urlBar: URLBar, didSubmitText text: String)
    func urlBarDidCancel(urlBar: URLBar)
}

class URLBar: UIView {
    weak var delegate: URLBarDelegate?

    private let urlText = URLTextField()
    fileprivate let cancelButton = InsetButton()
    fileprivate var cancelButtonWidthConstraint: Constraint!
    fileprivate let deleteButton = InsetButton()
    fileprivate var deleteButtonWidthConstraint: Constraint!
    fileprivate var deleteButtonTrailingConstraint: Constraint!
    fileprivate var isEditing = false

    init() {
        super.init(frame: CGRect.zero)

        let urlTextContainer = UIView()
        urlTextContainer.backgroundColor = UIConstants.colors.urlTextBackground

        urlText.font = UIConstants.fonts.urlTextFont
        urlText.tintColor = UIConstants.colors.urlTextFont
        urlText.textColor = UIConstants.colors.urlTextFont
        urlText.layer.cornerRadius = UIConstants.layout.urlTextCornerRadius
        urlText.placeholder = UIConstants.strings.urlTextPlaceholder
        urlText.keyboardType = .webSearch
        urlText.autocapitalizationType = .none
        urlText.autocorrectionType = .no
        urlText.clearButtonMode = .whileEditing
        urlText.autocompleteDelegate = self

        cancelButton.setTitle(UIConstants.strings.urlBarCancel, for: .normal)
        cancelButton.titleLabel?.font = UIConstants.fonts.smallerFont
        cancelButton.titleEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        cancelButton.addTarget(self, action: #selector(didCancel), for: .touchUpInside)
        cancelButton.setContentCompressionResistancePriority(1000, for: .horizontal)

        deleteButton.setTitle(UIConstants.strings.deleteButton, for: .normal)
        deleteButton.titleLabel?.font = UIConstants.fonts.smallerFont
        deleteButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)
        deleteButton.backgroundColor = UIColor.lightGray
        deleteButton.layer.borderWidth = 1
        deleteButton.layer.cornerRadius = 2
        deleteButton.layer.borderColor = UIConstants.colors.deleteButtonBorder.cgColor
        deleteButton.layer.backgroundColor = UIConstants.colors.deleteButtonBackgroundNormal.cgColor
        deleteButton.setContentCompressionResistancePriority(1000, for: .horizontal)

        addSubview(urlTextContainer)
        urlTextContainer.addSubview(urlText)
        urlTextContainer.addSubview(deleteButton)
        addSubview(cancelButton)

        urlTextContainer.snp.makeConstraints { make in
            make.top.leading.bottom.equalTo(self).inset(UIConstants.layout.urlBarMargin)

            // Two required constraints.
            make.trailing.lessThanOrEqualTo(cancelButton.snp.leading)
            make.trailing.lessThanOrEqualTo(self).inset(UIConstants.layout.urlBarMargin)

            // Because of the two required constraints above, the first optional constraint
            // here will fail if the Cancel button has 0 width; the second will fail if the
            // Cancel button is visible. As a result, only one of these two constraints will
            // be in effect at a time.
            make.trailing.equalTo(cancelButton.snp.leading).priority(500)
            make.trailing.equalTo(self).priority(500)
        }

        urlText.snp.makeConstraints { make in
            make.leading.top.bottom.equalTo(urlTextContainer)
        }

        deleteButton.snp.makeConstraints { make in
            make.leading.equalTo(urlText.snp.trailing)
            make.centerY.equalTo(urlTextContainer)
            self.deleteButtonTrailingConstraint = make.trailing.equalTo(urlTextContainer).constraint
            self.deleteButtonWidthConstraint = make.size.equalTo(0).constraint
        }

        cancelButton.snp.makeConstraints { make in
            make.trailing.equalTo(self)
            make.centerY.equalTo(urlText)
            self.cancelButtonWidthConstraint = make.size.equalTo(0).constraint
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var url: URL? = nil {
        didSet {
            if !isEditing {
                setTextToURL()
            }
        }
    }

    @objc private func didCancel() {
        setTextToURL()
        urlText.resignFirstResponder()
        delegate?.urlBarDidCancel(urlBar: self)
    }

    func focus() {
        urlText.becomeFirstResponder()
    }

    fileprivate func setTextToURL() {
        urlText.text = url?.absoluteString ?? nil
    }
}

extension URLBar: AutocompleteTextFieldDelegate {
    func autocompleteTextFieldShouldBeginEditing(_ autocompleteTextField: AutocompleteTextField) -> Bool {
        self.layoutIfNeeded()
        UIView.animate(withDuration: 0.3) {
            self.cancelButton.alpha = 1
            self.cancelButtonWidthConstraint.deactivate()

            self.deleteButton.alpha = 0
            self.deleteButtonWidthConstraint.activate()

            self.deleteButtonTrailingConstraint.update(offset: 0)

            self.layoutIfNeeded()
        }

        autocompleteTextField.highlightAll()

        return true
    }

    func autocompleteTextFieldShouldEndEditing(_ autocompleteTextField: AutocompleteTextField) -> Bool {
        self.layoutIfNeeded()
        UIView.animate(withDuration: 0.3) {
            self.cancelButton.alpha = 0
            self.cancelButtonWidthConstraint.activate()

            self.deleteButton.alpha = 1
            self.deleteButtonWidthConstraint.deactivate()

            self.deleteButtonTrailingConstraint.update(offset: -5)

            self.layoutIfNeeded()
        }

        return true
    }

    func autocompleteTextFieldDidBeginEditing(_ autocompleteTextField: AutocompleteTextField) {
        isEditing = true
    }

    func autocompleteTextFieldDidEndEditing(_ autocompleteTextField: AutocompleteTextField) {
        isEditing = false
    }

    func autocompleteTextFieldShouldReturn(_ autocompleteTextField: AutocompleteTextField) -> Bool {
        delegate?.urlBar(urlBar: self, didSubmitText: autocompleteTextField.text!)
        autocompleteTextField.resignFirstResponder()
        return true
    }

    func autocompleteTextField(_ autocompleteTextField: AutocompleteTextField, didEnterText text: String) {
    }
}

private class URLTextField: AutocompleteTextField {
    override var placeholder: String? {
        didSet {
            attributedPlaceholder = NSAttributedString(string: placeholder!, attributes: [NSForegroundColorAttributeName: UIConstants.colors.urlTextPlaceholder])
        }
    }

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: UIConstants.layout.urlBarWidthInset, dy: UIConstants.layout.urlBarHeightInset)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: UIConstants.layout.urlBarWidthInset, dy: UIConstants.layout.urlBarHeightInset)
    }

    private override func rightViewRect(forBounds bounds: CGRect) -> CGRect {
        return super.rightViewRect(forBounds: bounds).offsetBy(dx: -UIConstants.layout.urlBarWidthInset, dy: 0)
    }
}
