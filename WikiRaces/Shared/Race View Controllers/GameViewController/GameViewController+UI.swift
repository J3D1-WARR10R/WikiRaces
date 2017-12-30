//
//  GameViewController+UI.swift
//  WikiRaces
//
//  Created by Andrew Finke on 8/5/17.
//  Copyright © 2017 Andrew Finke. All rights reserved.
//

import UIKit
import WKRUIKit

extension GameViewController {

    // MARK: - Interface

    func setupInterface() {
        guard let navigationController = navigationController,
            let navigationView = navigationController.view else {
                fatalError("No navigation controller view")
        }

        navigationController.setNavigationBarHidden(true, animated: false)

        flagBarButtonItem = navigationItem.leftBarButtonItem
        quitBarButtonItem = navigationItem.rightBarButtonItem

        navigationItem.hidesBackButton = true
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem = nil

        thinLine.alpha = 0
        thinLine.backgroundColor = UIColor.wkrTextColor
        thinLine.translatesAutoresizingMaskIntoConstraints = false
        navigationView.addSubview(thinLine)

        setupWebView()

        let constraints: [NSLayoutConstraint] = [
            thinLine.topAnchor.constraint(equalTo: navigationView.bottomAnchor),
            thinLine.leftAnchor.constraint(equalTo: navigationView.leftAnchor),
            thinLine.rightAnchor.constraint(equalTo: navigationView.rightAnchor),
            thinLine.heightAnchor.constraint(equalToConstant: 1)
        ]
        NSLayoutConstraint.activate(constraints)
    }

    // MARK: - Elements

    private func setupWebView() {
        webView.alpha = 0.0

        var contentInset = webView.scrollView.contentInset
        contentInset.bottom = -20
        webView.scrollView.contentInset = contentInset

        view.addSubview(webView)
        view.addSubview(progressView)
        webView.progressView = progressView

        let constraints: [NSLayoutConstraint] = [
            webView.topAnchor.constraint(equalTo: topLayoutGuide.topAnchor),
            webView.leftAnchor.constraint(equalTo: view.leftAnchor),
            webView.rightAnchor.constraint(equalTo: view.rightAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            progressView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor),
            progressView.leftAnchor.constraint(equalTo: view.leftAnchor),
            progressView.rightAnchor.constraint(equalTo: view.rightAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 3)
        ]
        NSLayoutConstraint.activate(constraints)

        manager.webView = webView
    }

    // MARK: - Alerts

    func quitAlertController(raceStarted: Bool) -> UIAlertController {
        var message = "Are you sure you want to quit? You will be disconnected from the match and returned to the menu."
        if raceStarted {
            message += " Press the forfeit button to give up on the race but stay in the match."
        }

        let alertController = UIAlertController(title: "Leave The Match?", message: message, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "Keep Playing", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)

        if raceStarted {
            let forfeitAction = UIAlertAction(title: "Forfeit Race", style: .default) {  [weak self] _ in
                PlayerAnalytics.log(event: .userAction("quitAlertController:forfeit"))
                PlayerAnalytics.log(event: .forfeited, attributes: ["Page": self?.finalPage?.title as Any])
                self?.manager.player(.forfeited)
            }
            alertController.addAction(forfeitAction)
        }

        let quitAction = UIAlertAction(title: "Quit Match", style: .destructive) {  [weak self] _ in
            PlayerAnalytics.log(event: .userAction("quitAlertController:quit"))
            PlayerAnalytics.log(event: .quitRace, attributes: ["View": self?.activeViewController?.description as Any])
            self?.isPlayerQuitting = true
            self?.resetActiveControllers()
            self?.manager.player(.quit)
            NotificationCenter.default.post(name: NSNotification.Name("PlayerQuit"), object: nil)
        }
        alertController.addAction(quitAction)

        return alertController
    }

}
