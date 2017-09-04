//
//  ResultsViewController.swift
//  WikiRaces
//
//  Created by Andrew Finke on 8/5/17.
//  Copyright © 2017 Andrew Finke. All rights reserved.
//

import UIKit
import WKRKit
import WKRUIKit

class ResultsViewController: CenteredTableViewController {

    // MARK: - Properties

    var isPlayerHost = false {
        didSet {
            if isPlayerHost {
                navigationItem.leftBarButtonItem?.isEnabled = false
            } else {
                navigationItem.leftBarButtonItem = nil
            }
        }
    }

    var state: WKRGameState = .results {
        didSet {
            if state == .results || state == .hostResults {
                title = "RESULTS"
                tableView.isUserInteractionEnabled = true
                tableView.reloadData()
            } else {
                title = "STANDINGS"
                tableView.isUserInteractionEnabled = false
                if historyViewController != nil {
                    dismiss(animated: true, completion: nil)
                }

                guard let cells = tableView.visibleCells as? [ResultsTableViewCell] else {
                    return
                }

                UIView.animate(withDuration: 0.5, animations: {
                    cells.forEach { $0.detailLabel.alpha = 0.0 }
                    self.descriptionLabel.alpha = 0.0
                }, completion: { _ in
                    self.tableView.reloadData()
                    UIView.animate(withDuration: 0.5) {
                        cells.forEach { $0.detailLabel.alpha = 1.0 }
                    }
                })
            }
        }
    }

    var readyStates: WKRReadyStates? {
        didSet {
            if state != .points {
                tableView.reloadData()
            }
        }
    }

    var resultsInfo: WKRResultsInfo? {
        didSet {
            tableView.reloadData()
            updateHistoryController()
        }
    }

    var timeRemaining: Int = 100 {
        didSet {
            tableView.isUserInteractionEnabled = true
            descriptionLabel.text = "VOTING STARTS IN " + timeRemaining.description + " S"
        }
    }

    private var historyViewController: HistoryViewController?
    @IBOutlet weak var addPlayersBarButtonItem: UIBarButtonItem?

    var quitAlertController: UIAlertController?
    var readyButtonPressed: (() -> Void)?
    var addPlayersButtonPressed: ((UIViewController) -> Void)?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        registerTableView(for: self)
        overlayButtonTitle = "Ready up"

        descriptionLabel.text = "WAITING FOR PLAYERS"
        descriptionLabel.textColor = UIColor.wkrTextColor

        tableView.isUserInteractionEnabled = true
        tableView.register(ResultsTableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
    }

    // MARK: - Actions

    @IBAction func quitButtonPressed(_ sender: Any) {
        guard let alertController = quitAlertController else { fatalError() }
        present(alertController, animated: true, completion: nil)
    }

    @IBAction func addPlayersBarButtonItemPressed(_ sender: Any) {
        addPlayersButtonPressed?(self)
    }

    override func overlayButtonPressed() {
        navigationItem.leftBarButtonItem?.isEnabled = false
        readyButtonPressed?()
        isOverlayButtonHidden = true
        UIView.animate(withDuration: 0.5) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Helpers

    func resultsEnded() {
        UIView.animate(withDuration: 0.5) {
            self.descriptionLabel.alpha = 0.0
        }
    }

    func updateHistoryController() {
        guard let player = historyViewController?.player,
            let updatedPlayer = resultsInfo?.player(for: player.profile) else {
                return
        }
        historyViewController?.player = updatedPlayer
    }

    func showReadyUpButton(_ showReady: Bool) {
        navigationItem.leftBarButtonItem?.isEnabled = showReady
        isOverlayButtonHidden = !showReady
        UIView.animate(withDuration: 0.5) {
            self.view.layoutIfNeeded()
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let destinationNavigationController = segue.destination as? UINavigationController,
            let destination = destinationNavigationController.rootViewController as? HistoryViewController else {
                fatalError()
        }
        let player = sender as? WKRPlayer
        destination.player = player
        historyViewController = destination
    }

}
