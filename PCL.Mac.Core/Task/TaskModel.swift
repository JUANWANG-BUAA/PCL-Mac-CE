//
//  TaskModel.swift
//  PCL.Mac
//

import Foundation

public protocol TaskModel: AnyObject, Sendable {}

public final class EmptyModel: TaskModel, Sendable {
    public init() {}
}
