//
//  MenuViewController+Segue.swift
//  WikiRaces
//
//  Created by Andrew Finke on 9/6/17.
//  Copyright © 2017 Andrew Finke. All rights reserved.
//

import UIKit
import WKRKit

extension MenuViewController {

    // MARK: - Types

    enum Segue: String {
        case debugBypass
        case showMPCConnecting
        case showGameKitConnecting
    }

    // MARK: - Performing Segues

    /// Perform as segue with host parameter
    ///
    /// - Parameters:
    ///   - segue: The segue to perform
    ///   - isHost: Is the local player host
    func performSegue(_ segue: Segue, isHost: Bool) {
        performSegue(withIdentifier: segue.rawValue, sender: isHost)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let unwrappedSegueIdentifier = segue.identifier,
            let segueIdentifier = Segue(rawValue: unwrappedSegueIdentifier),
            let isPlayerHost = sender as? Bool else {
                fatalError("Unknown segue \(String(describing: segue.identifier))")
        }

        UIApplication.shared.isIdleTimerDisabled = true
        WKRSeenFinalArticlesStore.resetRemotePlayersSeenFinalArticles()

        switch segueIdentifier {
        case .debugBypass:
            guard let destination = (segue.destination as? UINavigationController)?
                .rootViewController as? GameViewController else {
                    fatalError("Destination not a GameViewController nav")
            }
            #if MULTIWINDOWDEBUG
                //swiftlint:disable:next force_cast
            destination.networkConfig = .multiwindow(windowName: (view.window as! DebugWindow).playerName,
                                                  isHost: isPlayerHost)
            #else
                fatalError()
            #endif

        case .showMPCConnecting:
            #if MULTIWINDOWDEBUG
                fatalError()
            #else
                guard let destination = segue.destination as? MPCConnectViewController else {
                    fatalError("Destination not a MPCConnectViewController nav")
                }
                destination.isPlayerHost = isPlayerHost
            #endif
        case .showGameKitConnecting:
            #if MULTIWINDOWDEBUG
                fatalError()
            #endif
        }
    }

    // MARK: - Settings

    @objc
    func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            fatalError("Settings URL nil")
        }

        UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
    }

}
