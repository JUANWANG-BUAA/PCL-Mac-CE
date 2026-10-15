//
//  ModLoader.swift
//  PCL.Mac
//

import Foundation

public enum ModLoader: String, Codable, CustomStringConvertible {
    case fabric, forge, neoforge

    public var index: Int {
        switch self {
        case .fabric: 0
        case .forge: 1
        case .neoforge: 2
        }
    }

    public var description: String {
        switch self {
        case .fabric: "Fabric"
        case .forge: "Forge"
        case .neoforge: "NeoForge"
        }
    }
}
