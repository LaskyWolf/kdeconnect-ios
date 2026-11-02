/*
 * SPDX-FileCopyrightText: 2023 Apollo Zhu <public-apollonian@outlook.com>
 *
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

//
//  FileTransferItem.swift
//  KDE Connect
//
//  Created by Apollo Zhu on 2/20/23.
//

import Foundation
import CocoaAsyncSocket

@objc(KDESocketAddress)
@objcMembers
class SocketAddress: NSObject {
    /// Returns a copy of `address`, a `sockaddr`, that uses another port and keeps everything else.
    static func address(_ address: Data?, withPort port: UInt16) -> Data? {
        guard var result = address else { return nil }
        let isValid = result.withUnsafeMutableBytes { bytes -> Bool in
            guard bytes.count >= MemoryLayout<sockaddr>.size else { return false }
            let portOffset: Int
            let minimumSize: Int
            switch Int32(bytes.load(as: sockaddr.self).sa_family) {
            case AF_INET:
                portOffset = MemoryLayout<sockaddr_in>.offset(of: \.sin_port)!
                minimumSize = MemoryLayout<sockaddr_in>.size
            case AF_INET6:
                portOffset = MemoryLayout<sockaddr_in6>.offset(of: \.sin6_port)!
                minimumSize = MemoryLayout<sockaddr_in6>.size
            default:
                return false
            }
            guard bytes.count >= minimumSize else { return false }
            bytes.storeBytes(of: port.bigEndian, toByteOffset: portOffset, as: UInt16.self)
            return true
        }
        return isValid ? result : nil
    }
}

@objc(KDEFileTransferItem)
@objcMembers
class FileTransferItem: NSObject {
    let fileHandle: FileHandle
    let networkPacket: NetworkPacket
    private(set) var info: FileTransferItemInfo
    let buffer = NSMutableData()
    
    init(fileHandle: FileHandle, networkPacket: NetworkPacket) {
        self.fileHandle = fileHandle
        self.networkPacket = networkPacket
        guard let path = networkPacket.payloadPath else {
            preconditionFailure("NetworkPacket missing payloadPath")
        }
        guard let name = networkPacket._Body["filename"] as? String else {
            preconditionFailure("file transfer packet missing filename")
        }
        self.info = FileTransferItemInfo(
            path: path,
            name: name,
            creationEpoch: networkPacket._Body["creationTime"] as? Int64,
            lastModifiedEpoch: networkPacket._Body["lastModified"] as? Int64,
            totalBytes: networkPacket._PayloadSize == -1 ? nil : networkPacket._PayloadSize
        )
        super.init()
    }
    
    var totalBytes: NSNumber? { info.totalBytes as? NSNumber }
    
    var totalBytesCompleted: Int {
        get { info.totalBytesCompleted }
        set { info.totalBytesCompleted = newValue }
    }
}

struct FileTransferItemInfo: Equatable, Identifiable {
    let path: URL
    let name: String
    let creationEpoch: Int64?
    let lastModifiedEpoch: Int64?
    let totalBytes: Int?
    var totalBytesCompleted: Int = 0
    
    var id: URL { path }
}

extension FileTransferItemInfo {
    init(path: URL, name: String, totalBytes: Int?, totalBytesCompleted: Int = 0) {
        self.init(path: path, name: name,
                  creationEpoch: nil, lastModifiedEpoch: nil,
                  totalBytes: totalBytes, totalBytesCompleted: totalBytesCompleted)
    }
}

struct FailedFileTransferItemInfo: Identifiable {
    let path: URL
    let name: String
    let error: Error
    /// Sometimes file transfers are packetd together and we don't know
    /// exact file names, so the other related files are just a number.
    let countOtherFailedFilesInTheSameTransfer: Int
    
    var id: URL { path }
}
