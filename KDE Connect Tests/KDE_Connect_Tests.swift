/*
 * SPDX-FileCopyrightText: 2021 Lucas Wang <lucas.wang@tuta.io>
 *
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

// Original header below:
//
//  KDE_Connect_Tests.swift
//  KDE Connect Tests
//
//  Created by Lucas Wang on 2021-06-17.
//

import XCTest
@testable import KDE_Connect

// Intentional naming matching app target name
// swiftlint:disable:next type_name
class KDE_Connect_Tests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

#if !os(macOS)
    func testEveryAppIconHasAPreviewImage() {
        for icon in AppIcon.allCases {
            XCTAssertNotNil(UIImage(named: icon.previewImageName, in: Bundle(for: Share.self), with: nil),
                            icon.previewImageName)
        }
    }

    func testAvailabilityEndsOnlyWithoutTransferAfterCountdown() {
        let idle = TransferProgress()
        let sending = TransferProgress(totalFiles: 1)
        XCTAssertEqual(BackgroundAvailabilityStep(transfer: idle, elapsed: 60, duration: 900),
                       .waiting(remaining: 840))
        XCTAssertEqual(BackgroundAvailabilityStep(transfer: idle, elapsed: 900, duration: 900), .finished)
        XCTAssertEqual(BackgroundAvailabilityStep(transfer: idle, elapsed: 0, duration: 0), .finished)
        XCTAssertEqual(BackgroundAvailabilityStep(transfer: sending, elapsed: 1000, duration: 900),
                       .transferring(sending))
    }

    func testTransferProgressNeverMovesBackBetweenFiles() {
        let nearlyDone = TransferProgress(totalFiles: 2, finishedFiles: 0, inFlightFraction: 0.99)
        let nextFile = TransferProgress(totalFiles: 2, finishedFiles: 1, inFlightFraction: 0)
        XCTAssertEqual(nearlyDone.completedUnits, 990)
        XCTAssertEqual(nextFile.completedUnits, 1000)
        XCTAssertEqual(nextFile.totalUnits, 2000)
        let overshoot = TransferProgress(totalFiles: 1, finishedFiles: 1, inFlightFraction: 1)
        XCTAssertEqual(overshoot.completedUnits, overshoot.totalUnits)
    }

    func testFractionOfFileWithoutKnownSizeKeepsGrowing() {
        let path = URL(fileURLWithPath: "/tmp/file")
        let known = FileTransferItemInfo(path: path, name: "file", totalBytes: 200, totalBytesCompleted: 50)
        XCTAssertEqual(TransferProgress.fraction(of: known), 0.25)
        let empty = FileTransferItemInfo(path: path, name: "file", totalBytes: 0)
        XCTAssertEqual(TransferProgress.fraction(of: empty), 0)
        let unknownSmall = FileTransferItemInfo(path: path, name: "file", totalBytes: nil, totalBytesCompleted: 1_000)
        let unknownBig = FileTransferItemInfo(path: path, name: "file", totalBytes: nil, totalBytesCompleted: 1_000_000)
        XCTAssertLessThan(TransferProgress.fraction(of: unknownSmall), TransferProgress.fraction(of: unknownBig))
        XCTAssertLessThan(TransferProgress.fraction(of: unknownBig), 1)
    }
#endif

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
}
