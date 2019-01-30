//
//  ConnectViewController.swift
//  WikiRaces
//
//  Created by Andrew Finke on 1/26/19.
//  Copyright © 2019 Andrew Finke. All rights reserved.
//

import UIKit
import WKRKit

class ConnectViewController: StateLogViewController {

    // MARK: - Interface Elements

    /// General status label
    @IBOutlet weak var descriptionLabel: UILabel!
    /// Activity spinner
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    /// The button to cancel joining/creating a race
    @IBOutlet weak var cancelButton: UIButton!

    var isFirstAppear = true
    var isShowingMatch = false
    var onQuit: (() -> Void)?

    // MARK: - Connection

    func runConnectionTest(completion: @escaping (Bool) -> Void) {
        #if !MULTIWINDOWDEBUG
        let trace = Performance.startTrace(name: "Connection Test Trace")
        #endif
        WKRConnectionTester.start { (success) in
            DispatchQueue.main.async {
                if success {
                    #if !MULTIWINDOWDEBUG
                    trace?.stop()
                    #endif
                }
                completion(success)
            }
        }
    }

    // MARK: - Core Interface

    func setupCoreInterface() {
        cancelButton.alpha = 0.0
        cancelButton.setAttributedTitle(NSAttributedString(string: "CANCEL", spacing: 1.5), for: .normal)

        updateDescriptionLabel(to: "CHECKING CONNECTION")
        descriptionLabel.alpha = 0.0

        activityIndicatorView.alpha = 0.0
        activityIndicatorView.color = UIColor.wkrActivityIndicatorColor
        view.backgroundColor = UIColor.wkrBackgroundColor
    }

    func toggleCoreInterface(isHidden: Bool,
                             duration: TimeInterval,
                             and items: [UIView] = [],
                             completion: (() -> Void)? = nil) {
        let core = [descriptionLabel, activityIndicatorView, cancelButton]
        UIView.animate(withDuration: duration,
                       animations: {
                        let views = items + core
                        views.forEach({ $0?.alpha = isHidden ? 0 : 1})
        }, completion: { _ in
            completion?()
        })
    }

    // MARK: - Interface Updates

    func updateDescriptionLabel(to text: String) {
        descriptionLabel.attributedText = NSAttributedString(string: text.uppercased(),
                                                             spacing: 2.0,
                                                             font: UIFont.systemFont(ofSize: 20.0, weight: .semibold))
    }

    /// Shows an error with a title
    ///
    /// - Parameters:
    ///   - title: The title of the error message
    ///   - message: The message body of the error
    @objc
    func showError(title: String, message: String, showSettingsButton: Bool = false) {
        onQuit?()

        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "Menu", style: .default) { _ in
            self.pressedCancelButton()
        }
        alertController.addAction(action)

        if showSettingsButton {
            let settingsAction = UIAlertAction(title: "Open Settings", style: .default, handler: { _ in
                PlayerMetrics.log(event: .userAction("showError:settings"))
                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                    fatalError("Settings URL nil")
                }
                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
                self.pressedCancelButton()
            })
            alertController.addAction(settingsAction)
        }

        present(alertController, animated: true, completion: nil)
        PlayerMetrics.log(presentingOf: alertController, on: self)
    }

    /// Cancels the join/create a race action and sends player back to main menu
    @IBAction func pressedCancelButton() {
        PlayerMetrics.log(event: .userAction(#function))
        onQuit?()

        UIView.animate(withDuration: 0.25, animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            self.navigationController?.popToRootViewController(animated: false)
        })
    }

    func showMatch(isPlayerHost: Bool,
                   generateFeedback: Bool,
                   andHide views: [UIView]) {

        guard !isShowingMatch else { return }
        isShowingMatch = true

        DispatchQueue.main.async {
            self.toggleCoreInterface(isHidden: true,
                                     duration: 0.25,
                                     and: views,
                                     completion: {
                                        self.performSegue(withIdentifier: "showRace", sender: isPlayerHost)
            })

            if generateFeedback {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

}