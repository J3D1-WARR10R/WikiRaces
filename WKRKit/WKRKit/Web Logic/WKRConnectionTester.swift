//
//  WKRConnectionTester.swift
//  WKRKit
//
//  Created by Andrew Finke on 8/5/17.
//  Copyright © 2017 Andrew Finke. All rights reserved.
//

import Foundation

/// Tests the connection to Wikipedia.
public struct WKRConnectionTester {

    /// Tests the connection to Wikipedia.
    ///
    /// - Parameters:
    ///   - timeout: The maximum time to wait for the page load. If it takes longer than the time out, returns false
    ///   - completionHandler: Handler with Bool indicating connectivity.
    public static func start(timeout: Double = 4.0, completionHandler: @escaping (_ connected: Bool) -> Void) {
        let startDate = Date()
        var timedOut = false

        let timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
            timedOut = true
            completionHandler(false)
        }

        WKRPageFetcher.fetch(path: "/United_States") { (page) in
            timer.invalidate()
            if timedOut {
                // Timer fired, completion handler already called
                return
            } else if page != nil, startDate.timeIntervalSinceNow > -3.0 {
                // Have valid page, loaded in time
                completionHandler(true)
            } else {
                // Connection test failed
                completionHandler(false)
            }
        }
    }

}
