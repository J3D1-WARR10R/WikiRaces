//
//  MenuViewController.swift
//  WikiRaces
//
//  Created by Andrew Finke on 8/5/17.
//  Copyright © 2017 Andrew Finke. All rights reserved.
//

import UIKit
import GameKit
import StoreKit

import WKRKit
import WKRUIKit

/// The main menu view controller
class MenuViewController: StateLogViewController {

    // MARK: - Properties

    /// Used to track if the menu should be animating
    var isMenuVisable = false

    var isLeaderboardPresented = false

    // MARK: - Interface Elements

    /// The top of the menu (everything on white). Animates out of the left side.
    let topView = UIView()
    /// The bottom of the menu (everything not white). Animates out of the bottom.
    let bottomView = UIView()

    /// The "WikiRaces" label
    let titleLabel = UILabel()
    /// The "Conquer..." label
    let subtitleLabel = UILabel()

    let joinButton = WKRUIButton()
    let createButton = WKRUIButton()

    /// The Wiki Points tile
    var leftMenuTile: MenuTile?
    /// The average points tile
    var middleMenuTile: MenuTile?
    /// The races tile
    var rightMenuTile: MenuTile?

    /// Timer for moving the puzzle pieces
    var puzzleTimer: Timer?
    /// The puzzle piece view
    let puzzleView = UIScrollView()

    // MARK: - Constraints

    /// Used to animate the top view in and out
    var topViewLeftConstraint: NSLayoutConstraint!
    /// Used to animate the bottom view in and out
    var bottomViewAnchorConstraint: NSLayoutConstraint!

    /// Used for safe area layout adjustments
    var bottomViewHeightConstraint: NSLayoutConstraint!
    var puzzleViewHeightConstraint: NSLayoutConstraint!

    /// Used for adjusting y coord of title label based on screen height
    var titleLabelConstraint: NSLayoutConstraint!

    /// Used for adjusting button widths and heights based on screen width
    var joinButtonWidthConstraint: NSLayoutConstraint!
    var joinButtonHeightConstraint: NSLayoutConstraint!
    var createButtonWidthConstraint: NSLayoutConstraint!
    var createButtonHeightConstraint: NSLayoutConstraint!

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupInterface()

        let versionGesture = UITapGestureRecognizer(target: self, action: #selector(showVersionInfo))
        versionGesture.numberOfTapsRequired = 2
        versionGesture.numberOfTouchesRequired = 2
        view.addGestureRecognizer(versionGesture)

        //swiftlint:disable:next discarded_notification_center_observer line_length
        NotificationCenter.default.addObserver(forName: NSNotification.Name("PlayerQuit"), object: nil, queue: nil) { _ in
            DispatchQueue.main.async {
                self.dismiss(animated: true, completion: {
                    self.navigationController?.popToRootViewController(animated: false)
                })
            }
        }

        guard let bundleBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
            let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
                fatalError()
        }
        PlayerAnalytics.log(event: .buildInfo(version: bundleVersion, build: bundleBuild))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateMenuIn()

        #if MULTIWINDOWDEBUG
            performSegue(.debugBypass, isHost: view.window!.frame.origin == .zero)
        #else
            attemptGCAuthentication()
        #endif
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Actions

    @objc
    /// Changes title label to build info
    func showVersionInfo() {
        PlayerAnalytics.log(event: .versionInfo)
        guard let bundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
            let bundleShortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            fatalError()
        }
        let appVersion = bundleShortVersion + " (\(bundleVersion)) / "
        titleLabel.text = appVersion + "\(WKRKitConstants.current.version) / \(WKRUIConstants.current.version)"
    }

    @objc
    /// Join button pressed
    func joinRace() {
        PlayerAnalytics.log(event: .userAction(#function))
        PlayerAnalytics.log(event: .pressedJoin)
        guard !promptForCustomName(isHost: false) else {
            return
        }
        animateMenuOut {
            self.performSegue(.showConnecting, isHost: false)
        }
    }

    @objc
    /// Create button pressed
    func createRace() {
        PlayerAnalytics.log(event: .userAction(#function))
        PlayerAnalytics.log(event: .pressedHost)
        guard !promptForCustomName(isHost: true) else {
            return
        }
        animateMenuOut {
            self.performSegue(.showConnecting, isHost: true)
        }
    }

    func promptForCustomName(isHost: Bool) -> Bool {
        guard !UserDefaults.standard.bool(forKey: "PromptedCustomName") else {
            return false
        }
        UserDefaults.standard.set(true, forKey: "PromptedCustomName")

        let message = "Would you like to set a custom player name before racing?"
        let alertController = UIAlertController(title: "Set Name?", message: message, preferredStyle: .alert)

        let laterAction = UIAlertAction(title: "Maybe Later", style: .cancel, handler: { _ in
            PlayerAnalytics.log(event: .userAction("promptForCustomNamePrompt:rejected"))
            PlayerAnalytics.log(event: .namePromptResult, attributes: ["Result": "Cancelled"])
            if isHost {
                self.createRace()
            } else {
                self.joinRace()
            }
        })
        alertController.addAction(laterAction)

        let settingsAction = UIAlertAction(title: "Open Settings", style: .default, handler: { _ in
            PlayerAnalytics.log(event: .userAction("promptForCustomNamePrompt:accepted"))
            PlayerAnalytics.log(event: .namePromptResult, attributes: ["Result": "Accepted"])
            UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!,
                                      options: [:], completionHandler: nil)
        })
        alertController.addAction(settingsAction)

        present(alertController, animated: true, completion: nil)
        PlayerAnalytics.log(presentingOf: alertController, on: self)
        return true
    }

    // MARK: - Menu Animations

    /// Animates the views off screen
    ///
    /// - Parameter completion: The completion handler
    func animateMenuOut(completion: (() -> Void)?) {
        view.isUserInteractionEnabled = false
        bottomViewAnchorConstraint.constant = bottomView.frame.height

        isMenuVisable = false
        view.setNeedsLayout()

        UIView.animate(withDuration: 0.75, animations: {
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.puzzleTimer?.invalidate()
            completion?()
        })
    }

    /// Animates the views on screen
    func animateMenuIn() {
        view.isUserInteractionEnabled = false
        UIApplication.shared.isIdleTimerDisabled = false

        puzzleTimer?.invalidate()
        puzzleTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            self.puzzleView.contentOffset = CGPoint(x: self.puzzleView.contentOffset.x + 0.5, y: 0)
        }

        isMenuVisable = true
        view.setNeedsLayout()

        UIView.animate(withDuration: 0.75, animations: {
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.view.isUserInteractionEnabled = true
            if StatsHelper.shared.statValue(for: .points) > 0, #available(iOS 10.3, *) {
                SKStoreReviewController.requestReview()
            }
        })
    }

}
