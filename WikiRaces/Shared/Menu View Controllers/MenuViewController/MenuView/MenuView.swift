//
//  MenuView.swift
//  WikiRaces
//
//  Created by Andrew Finke on 2/23/19.
//  Copyright © 2019 Andrew Finke. All rights reserved.
//

import UIKit
import WKRUIKit
import StoreKit

class MenuView: UIView {

    // MARK: Types

    enum InterfaceState {
        case raceTypeOptions, noOptions, localOptions, noInterface
    }

    // MARK: - Closures

    var presentDebugController: (() -> Void)?
    var presentMPCConnectController: ((_ isHost: Bool) -> Void)?
    var presentGlobalConnectController: (() -> Void)?
    var presentLeaderboardController: (() -> Void)?
    var presentGCAuthController: (() -> Void)?
    var presentAlertController: ((UIAlertController) -> Void)?

    // MARK: - Properties

    /// Used to track if the menu should be animating
    var state = InterfaceState.noInterface

    // MARK: - Interface Elements

    /// The top of the menu (everything on white). Animates out of the left side.
    let topView = UIView()
    /// The bottom of the menu (everything not white). Animates out of the bottom.
    let bottomView = UIView()

    /// The "WikiRaces" label
    let titleLabel = UILabel()
    /// The "Conquer..." label
    let subtitleLabel = UILabel()

    let localRaceTypeButton = WKRUIButton()
    let globalRaceTypeButton = WKRUIButton()
    let joinLocalRaceButton = WKRUIButton()
    let createLocalRaceButton = WKRUIButton()
    let localOptionsBackButton = UIButton()

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

    var localRaceTypeButtonLeftConstraint: NSLayoutConstraint!
    var localRaceTypeButtonWidthConstraint: NSLayoutConstraint!
    var localRaceTypeButtonHeightConstraint: NSLayoutConstraint!
    var globalRaceTypeButtonWidthConstraint: NSLayoutConstraint!

    var joinLocalRaceButtonLeftConstraint: NSLayoutConstraint!
    var joinLocalRaceButtonWidthConstraint: NSLayoutConstraint!
    var createLocalRaceButtonWidthConstraint: NSLayoutConstraint!

    // MARK: - View Life Cycle

    init() {
        super.init(frame: .zero)

        backgroundColor = UIColor.wkrBackgroundColor
        UIApplication.shared.keyWindow?.backgroundColor = UIColor.wkrBackgroundColor

        let recognizer = UITapGestureRecognizer(target: self, action: #selector(tapGestureRecognizerFired))
        recognizer.numberOfTapsRequired = 2
        recognizer.numberOfTouchesRequired = 3
        addGestureRecognizer(recognizer)

        topView.translatesAutoresizingMaskIntoConstraints = false
        topView.backgroundColor = UIColor.wkrMenuTopViewColor
        addSubview(topView)

        bottomView.backgroundColor = UIColor.wkrMenuBottomViewColor
        bottomView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomView)

        topViewLeftConstraint = topView.leftAnchor.constraint(equalTo: leftAnchor)
        bottomViewAnchorConstraint = bottomView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 250)
        bottomViewHeightConstraint = bottomView.heightAnchor.constraint(equalToConstant: 250)

        setupTopView()
        setupBottomView()

        let constraints = [
            topView.topAnchor.constraint(equalTo: topAnchor),
            topView.bottomAnchor.constraint(equalTo: bottomView.topAnchor),
            topView.widthAnchor.constraint(equalTo: widthAnchor),

            bottomView.leftAnchor.constraint(equalTo: leftAnchor),
            bottomView.widthAnchor.constraint(equalTo: widthAnchor),
            bottomViewHeightConstraint!,

            topViewLeftConstraint!,
            bottomViewAnchorConstraint!
        ]
        NSLayoutConstraint.activate(constraints)
    }

    @objc func tapGestureRecognizerFired() {
        presentDebugController?()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        puzzleViewHeightConstraint.constant = 75 + safeAreaInsets.bottom / 2
        bottomViewHeightConstraint.constant = 250 + safeAreaInsets.bottom / 2
    }

    //swiftlint:disable:next function_body_length
    override func layoutSubviews() {
        super.layoutSubviews()

        // Button Styles

        let buttonStyle: WKRUIButtonStyle
        let buttonWidth: CGFloat
        let buttonHeight: CGFloat
        if frame.size.width > 420 {
            buttonStyle = .large
            buttonWidth = 195
            buttonHeight = 50
        } else {
            buttonStyle = .normal
            buttonWidth = 175
            buttonHeight = 40
        }

        if frame.size.width < UIScreen.main.bounds.width / 1.8 {
            leftMenuTile?.title = "WIKI\nPOINTS"
            middleMenuTile?.title = "AVG PER\nRACE"
            rightMenuTile?.title = "RACES\nPLAYED"
        } else {
            leftMenuTile?.title = "WIKI POINTS"
            middleMenuTile?.title = "AVG PER RACE"
            rightMenuTile?.title = "RACES PLAYED"
        }

        localRaceTypeButton.style = buttonStyle
        globalRaceTypeButton.style = buttonStyle
        joinLocalRaceButton.style = buttonStyle
        createLocalRaceButton.style = buttonStyle

        // Label Fonts
        titleLabel.font = UIFont.boldSystemFont(ofSize: min(frame.size.width / 10.0, 55))
        subtitleLabel.font = UIFont.systemFont(ofSize: min(frame.size.width / 18.0, 30), weight: .medium)

        // Constraints
        titleLabelConstraint.constant = frame.size.height / 7

        switch state {
        case .raceTypeOptions:
            localRaceTypeButtonLeftConstraint.constant = 30
            joinLocalRaceButtonLeftConstraint.constant = -topView.frame.width

            topViewLeftConstraint.constant = 0
            bottomViewAnchorConstraint.constant = 0

            if frame.size.height < 650 {
                bottomViewAnchorConstraint.constant = 75
            }
        case .noOptions:
            localRaceTypeButtonLeftConstraint.constant = -topView.frame.width
            joinLocalRaceButtonLeftConstraint.constant = -topView.frame.width
        case .localOptions:
            localRaceTypeButtonLeftConstraint.constant = -topView.frame.width
            joinLocalRaceButtonLeftConstraint.constant = 30
        case .noInterface:
            topViewLeftConstraint.constant = -topView.frame.width
            bottomViewAnchorConstraint.constant = bottomView.frame.height
            localRaceTypeButtonLeftConstraint.constant = 30
            joinLocalRaceButtonLeftConstraint.constant = 30
        }

        localRaceTypeButtonHeightConstraint.constant = buttonHeight
        localRaceTypeButtonWidthConstraint.constant = buttonWidth + 20
        globalRaceTypeButtonWidthConstraint.constant = buttonWidth + 30

        joinLocalRaceButtonWidthConstraint.constant = buttonWidth
        createLocalRaceButtonWidthConstraint.constant = buttonWidth + 30
    }

    func promptForCustomName(isHost: Bool) -> Bool {
        guard !UserDefaults.standard.bool(forKey: "PromptedCustomName") else {
            return false
        }
        UserDefaults.standard.set(true, forKey: "PromptedCustomName")

        let message = "Would you like to set a custom player name for local races?"
        let alertController = UIAlertController(title: "Set Name?", message: message, preferredStyle: .alert)

        let laterAction = UIAlertAction(title: "Maybe Later", style: .cancel, handler: { _ in
            PlayerMetrics.log(event: .userAction("promptForCustomNamePrompt:rejected"))
            PlayerMetrics.log(event: .namePromptResult, attributes: ["Result": "Cancelled"])
            if isHost {
                self.createLocalRace()
            } else {
                self.joinLocalRace()
            }
        })
        alertController.addAction(laterAction)

        let settingsAction = UIAlertAction(title: "Open Settings", style: .default, handler: { _ in
            PlayerMetrics.log(event: .userAction("promptForCustomNamePrompt:accepted"))
            PlayerMetrics.log(event: .namePromptResult, attributes: ["Result": "Accepted"])
            UIApplication.shared.openSettings()
        })
        alertController.addAction(settingsAction)

        presentAlertController?(alertController)
        return true
    }

    /// Animates the views on screen
    func animateMenuIn() {
        isUserInteractionEnabled = false
        UIApplication.shared.isIdleTimerDisabled = false

        let duration = TimeInterval(5)
        let offset = CGFloat(40 * duration)

        func animateScroll() {
            let xOffset = puzzleView.contentOffset.x + offset
            UIView.animate(withDuration: duration,
                           delay: 0,
                           options: .curveLinear,
                           animations: {
                            self.puzzleView.contentOffset = CGPoint(x: xOffset,
                                                                    y: 0)
            }, completion: nil)
        }

        puzzleTimer?.invalidate()
        puzzleTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: true) { _ in
            animateScroll()
        }
        puzzleTimer?.fire()

        state = .raceTypeOptions
        setNeedsLayout()

        UIView.animate(withDuration: WKRAnimationDurationConstants.menuToggle,
                       animations: {
                        self.layoutIfNeeded()
        }, completion: { _ in
            self.isUserInteractionEnabled = true
            if SKStoreReviewController.shouldPromptForRating {
                #if !DEBUG
                SKStoreReviewController.requestReview()
                #endif
            }
        })
    }

}
