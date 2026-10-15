//
//  HintModel.swift
//  PCL.Mac
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
