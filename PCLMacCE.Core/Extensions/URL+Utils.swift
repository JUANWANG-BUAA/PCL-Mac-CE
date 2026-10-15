//
//  URL+Utils.swift
//  PCLMacCE
//

import Foundation

public extension URL {
    func deletingAllPathExtensions() -> URL {
        var url = self
        while url.pathExtension != "" {
            url = url.deletingPathExtension()
        }
        return url
    }
}
