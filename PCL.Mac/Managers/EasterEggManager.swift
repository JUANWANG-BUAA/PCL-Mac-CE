//
//  EasterEggManager.swift
//  PCL.Mac
//

import SwiftUI

class EasterEggManager: ObservableObject {
    public static let shared: EasterEggManager = .init()

    @Published public var rotationAngle: Angle = .degrees(0)
    @Published public var rotationAxis: (CGFloat, CGFloat, CGFloat) = (0, 0, 0)
    @Published public var modifyColor: Bool = false
    public var enabled: Bool = false
    public var rotateTask: Task<Void, Error>?

    public func enable() -> Bool {
        if enabled { return false }
        enabled = true
        return true
    }

    private init() {}
}
