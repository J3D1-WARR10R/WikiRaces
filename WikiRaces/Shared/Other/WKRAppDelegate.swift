//
//  WKRAppDelegate.swift
//  WikiRaces
//
//  Created by Andrew Finke on 8/25/17.
//  Copyright © 2017 Andrew Finke. All rights reserved.
//

import UIKit
import StoreKit

import WKRKit
import WKRUIKit

internal class WKRAppDelegate: UIResponder, UIApplicationDelegate {

    final var window: WKRUIWindow?

    final func configureConstants() {
        WKRKitConstants.updateConstants()
        WKRUIKitConstants.updateConstants()

        // Don't be that app that prompts people when they first open it
        Defaults.shouldPromptForRating = false
    }

    final func cleanTempDirectory() {
        let maxDayAge = 14.0
        let maxTimeInterval = maxDayAge * 60 * 60
        let manager = FileManager.default
        do {
            let path = NSTemporaryDirectory()
            let contents = try manager.contentsOfDirectory(atPath: path)
            for file in contents {
                let filePath = path + file
                let attributes = try manager.attributesOfItem(atPath: filePath)
                if let date = attributes[FileAttributeKey.creationDate] as? Date,
                    -date.timeIntervalSinceNow > maxTimeInterval {
                    try manager.removeItem(atPath: filePath)
                }
            }
        } catch {
            print(error)
        }
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let code = items.first(where: { $0.name == "Code" })?.value else {

            return false
        }
        GKHelper.shared.acceptedInvite(code: code)
        PlayerFirebaseAnalytics.log(event: .raceCodeLinkOpened)
        return true
    }

}
