//
//  ViewController.swift
//  WikiRaces (UI Catalog)
//
//  Created by Andrew Finke on 9/17/17.
//  Copyright © 2017 Andrew Finke. All rights reserved.
//

import UIKit
import MultipeerConnectivity
@testable import WKRKit

class ViewController: UIViewController {

    //swiftlint:disable line_length function_body_length force_cast
    override func viewDidLoad() {
        super.viewDidLoad()

        let historyNav = viewController() as! UINavigationController
        let historyController = historyNav.rootViewController as! MPCHostViewController
historyController.peerID = MCPeerID(displayName: "h")
        historyController.serviceType = "gj"
//        let players = [
//            WKRPlayer(profile: WKRPlayerProfile(name: "A", playerID: "A"), isHost: true),
//            WKRPlayer(profile: WKRPlayerProfile(name: "B", playerID: "B"), isHost: false)
//        ]
//
//        let results = WKRResultsInfo(players: players, racePoints: [:], sessionPoints: [:])
//
//        historyController.state = .results
//        historyController.resultsInfo = results
        present(historyNav, animated: true, completion: nil)

//        let url = URL(string: "https://www.apple.com")!
//
//        let player = WKRPlayer(profile: WKRPlayerProfile(name: "andrew", playerID: "andrew"), isHost: false)
//        player.state = .racing
//        player.startedNewRace(on: WKRPage(title: "Page 1", url: url))

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//            historyController.state = .hostResults
//            historyController.player = player
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                player.finishedViewingLastPage()
//                player.nowViewing(page: WKRPage(title: "Page 2", url: url), linkHere: true)
//                player.finishedViewingLastPage()
//                player.nowViewing(page: WKRPage(title: "Page 3", url: url), linkHere: true)
//                player.state = WKRPlayerState.foundPage
//                historyController.player = player

                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                    player.finishedViewingLastPage()
//                    player.nowViewing(page: WKRPage(title: "Page 4", url: url), linkHere: true)
//                    player.finishedViewingLastPage()
//                    player.nowViewing(page: WKRPage(title: "Page 5", url: url), linkHere: true)
//                    player.state = WKRPlayerState.foundPage
//                    historyController.player = player
                }
            }
        }

    }

    //swiftlint:disable force_cast
    func viewController() -> UIViewController {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MPCHostNav")
    }

}
