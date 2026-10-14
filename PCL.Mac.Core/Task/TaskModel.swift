//
//  TaskModel.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/12/4.
//

import Foundation

public protocol TaskModel: AnyObject, Sendable {}

public final class EmptyModel: TaskModel, Sendable {
    public init() {}
}
