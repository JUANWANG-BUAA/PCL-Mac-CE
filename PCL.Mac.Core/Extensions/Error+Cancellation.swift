//
//  Error+Cancellation.swift
//  PCL.Mac
//

import Foundation

public extension Error {
    var isCancellationError: Bool {
        if self is CancellationError { return true }
        if let error = self as? URLError, error.code == .cancelled { return true }
        return false
    }
}
