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

    func testSocketAddressChangesPortAndKeepsLinkLocalInterface() throws {
        var original = sockaddr_in6()
        original.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        original.sin6_family = sa_family_t(AF_INET6)
        original.sin6_port = UInt16(1716).bigEndian
        original.sin6_scope_id = 7
        inet_pton(AF_INET6, "fe80::17f0:dc07:67bf:1161", &original.sin6_addr)

        let result = try XCTUnwrap(SocketAddress.address(withUnsafeBytes(of: original) { Data($0) }, withPort: 1739))
        let changed = result.withUnsafeBytes { $0.load(as: sockaddr_in6.self) }
        XCTAssertEqual(UInt16(bigEndian: changed.sin6_port), 1739)
        XCTAssertEqual(changed.sin6_scope_id, 7)
        XCTAssertEqual(withUnsafeBytes(of: changed.sin6_addr) { Data($0) },
                       withUnsafeBytes(of: original.sin6_addr) { Data($0) })
    }

    func testSocketAddressChangesPortOfIPv4() throws {
        var original = sockaddr_in()
        original.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        original.sin_family = sa_family_t(AF_INET)
        original.sin_port = UInt16(1716).bigEndian
        original.sin_addr.s_addr = inet_addr("192.168.1.27")

        let result = try XCTUnwrap(SocketAddress.address(withUnsafeBytes(of: original) { Data($0) }, withPort: 1739))
        let changed = result.withUnsafeBytes { $0.load(as: sockaddr_in.self) }
        XCTAssertEqual(UInt16(bigEndian: changed.sin_port), 1739)
        XCTAssertEqual(changed.sin_addr.s_addr, original.sin_addr.s_addr)
    }

    func testSocketAddressRejectsUnusableAddresses() {
        XCTAssertNil(SocketAddress.address(nil, withPort: 1739))
        XCTAssertNil(SocketAddress.address(Data([1, 2]), withPort: 1739))
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
