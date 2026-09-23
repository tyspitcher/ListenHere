//
//  ListenHereUITests.swift
//  ListenHereUITests
//
//  Created by Tyson Pitcher on 7/21/26.
//

import XCTest

final class ListenHereUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testCaptureComposerShowsDirectSourceActions() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing-reset-navigation")
        app.launch()

        let newMemoryButton = app.buttons["New Memory"]
        XCTAssertTrue(newMemoryButton.waitForExistence(timeout: 5))
        newMemoryButton.tap()

        let expectedActions = [
            (identifier: "capture.takePhoto", label: "Take Photo"),
            (identifier: "capture.chooseFromLibrary", label: "Choose from Library"),
            (identifier: "capture.recordSound", label: "Record Sound"),
            (identifier: "capture.chooseAudioFile", label: "Choose Audio File"),
        ]

        for action in expectedActions {
            let button = app.buttons[action.identifier]
            XCTAssertTrue(button.waitForExistence(timeout: 3), "Missing \(action.label) button")
            XCTAssertEqual(button.label, action.label)
            XCTAssertTrue(button.isEnabled)
            XCTAssertTrue(button.isHittable)
        }

        XCTAssertFalse(app.buttons["Add Photo"].exists)
        XCTAssertFalse(app.buttons["Add Sound"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
