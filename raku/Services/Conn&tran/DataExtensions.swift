//
//  DataExtensions.swift
//  通用数据类型扩展
//
//  这个文件包含了音频处理中需要的数据类型扩展
//

import Foundation

// MARK: - UInt32 扩展
extension UInt32 {
    /// 将 UInt32 转换为小端序的 Data
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
    }
}

// MARK: - UInt16 扩展
extension UInt16 {
    /// 将 UInt16 转换为小端序的 Data
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<UInt16>.size)
    }
}

// MARK: - Int16 扩展
extension Int16 {
    /// 将 Int16 转换为小端序的 Data
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<Int16>.size)
    }
}

// MARK: - Notification.Name 扩展
extension Notification.Name {
    /// 音频数据接收通知
    static let audioDataReceived = Notification.Name("audioDataReceived")
}