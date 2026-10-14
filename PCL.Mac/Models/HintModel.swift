//
//  HintModel.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/1/13.
//

import Foundation

struct HintModel: Identifiable, Equatable {
    public let text: String
    public let type: Kind
    public let id: UUID = .init()
    
    public enum Kind {
        case info, finish, critical
    }
}
