//
//  Archive+Entry.swift
//  PCLMacCE
//

import Foundation
import ZIPFoundation

public extension Archive {
    /// 解压归档中的某个 `Entry`。
    func extract(_ entry: Entry) throws -> Data {
        var entryData: Data = .init()
        _ = try extract(entry, consumer: { data in
            entryData.append(data)
        })
        return entryData
    }
}
