/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest

class WebsiteMemoryTest: BaseTestCase {
        
    override func setUp() {
        super.setUp()
        dismissFirstRunUI()
    }
    
    override func tearDown() {
        XCUIApplication().terminate()
        super.tearDown()
    }
    
    func testGoogleTextField() {
        let app = XCUIApplication()
        let googleSearchField = app.webViews.otherElements["Search"]
        // Enter 'google' on the search field to go to google site
        loadWebPage("google")
        
        // type 'mozilla' (typing doesn't work cleanly with UIWebview, so had to paste from clipboard)
        UIPasteboard.general.string = "mozilla"

        googleSearchField.tap()
        googleSearchField.press(forDuration: 1.5)
        waitforExistence(element: app.menuItems["Paste"])
        app.menuItems["Paste"].tap()
        app.buttons["Google Search"].tap()
        
        // wait for mozilla link to appear
        waitforExistence(element: app.links["Mozilla"].staticTexts["Mozilla"])
        
        // revisit google site
        app.buttons["ERASE"].tap()
        // Disabling this check since BB seem to intermittently miss this popup which disappears after 1~2 seconds
        // The popup is also checked in PastenGOTest
        //waitforExistence(element: app.staticTexts["Your browsing history has been erased."])
        waitforExistence(element: app.staticTexts["Browse. Erase. Repeat."])
        waitforExistence(element: app.staticTexts["Automatic private browsing."])
        loadWebPage("google")
        waitforExistence(element: googleSearchField)
        googleSearchField.tap()
        
        // check the world 'mozilla' does not appear in the list of autocomplete
        waitforNoExistence(element: app.webViews.textFields["mozilla"])
        waitforNoExistence(element: app.webViews.searchFields["mozilla"])
    }    
}
