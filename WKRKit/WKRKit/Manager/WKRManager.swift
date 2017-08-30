//
//  WKRManager.swift
//  WKRKit
//
//  Created by Andrew Finke on 8/5/17.
//  Copyright © 2017 Andrew Finke. All rights reserved.
//

import Foundation
import WKRUIKit
import MultipeerConnectivity

public enum WKRPlayerAction {
    case startedGame
    case neededHelp
    case voted(WKRPage)
    case state(WKRPlayerState)
    case forfeited
    case quit
}

public class WKRManager {

    // MARK: - Public

    public var finalPageURL: URL? {
        return game.raceConfig?.endingPage.url
    }

    public var votingInfo: WKRVoteInfo? {
        return game.preRaceConfig?.voteInfo
    }

    public var gameState: WKRGameState {
        return game.state
    }

    public var allPlayers: [WKRPlayer] {
        return game.players
    }

    public var racePlayers: [WKRPlayer] {
        return game.activeRace?.players ?? []
    }

    public var hostResultsInfo: WKRResultsInfo?

    // MARK: - Other

    let game: WKRGame
    let localPlayer: WKRPlayer

    // MARK: - Callbacks

    let stateUpdate: ((WKRGameState) -> Void)
    let playersUpdate: (([WKRPlayer]) -> Void)

    var voteTimeUpdate: ((Int) -> Void)?
    var voteInfoUpdate: ((WKRVoteInfo) -> Void)?
    var voteFinalPageUpdate: ((WKRPage) -> Void)?

    var resultsTimeUpdate: ((Int) -> Void)?
    var resultsInfoUpdate: ((WKRResultsInfo) -> Void)?
    var resultsInfoHostUpdate: ((WKRResultsInfo) -> Void)?

    // MARK: - Components

    let peerNetwork: WKRPeerNetwork
    let pageNavigation = WKRPageNavigation()

    // MARK: - User Interface

    var webView: WKRUIWebView!
    var alertView: WKRUIAlertView!

    // MARK: - Debug

    struct WKRDebugEntry {
        let date = Date()
        let object: Any
        let sender: WKRPlayerProfile
    }

    var debugEntry = [WKRDebugEntry]()

    // MARK: - Initialization

    private init(player: WKRPlayer,
                 network: WKRPeerNetwork,
                 stateUpdate: @escaping ((WKRGameState) -> Void),
                 playersUpdate: @escaping (([WKRPlayer]) -> Void)) {

        self.stateUpdate = stateUpdate
        self.playersUpdate = playersUpdate

        localPlayer = player
        peerNetwork = network

        game = WKRGame(localPlayer: localPlayer)

        if player.isHost {
            game.hostShouldEndRace = { result in
                DispatchQueue.main.async {
                    let state = WKRGameState.hostResults
                    self.peerNetwork.send(object: WKRCodable(enum: state))
                    self.peerNetwork.send(object: WKRCodable(result))
                    self.prepareResultsCountdown()
                }
            }
        }

        peerNetwork.delegate = self
        peerNetwork.send(object: WKRCodable(self.localPlayer))

        playersUpdate(game.players)
    }

    @available(*, deprecated, message: "Only for split view debugging")
    //swiftlint:disable:next identifier_name
    public convenience init(_playerName: String, isHost: Bool,
                            stateUpdate: @escaping ((WKRGameState) -> Void),
                            playersUpdate: @escaping (([WKRPlayer]) -> Void)) {

        let player = WKRPlayer(profile: WKRPlayerProfile(name: _playerName, playerID: _playerName), isHost: isHost)
        let network = WKRSplitViewNetwork(playerName: _playerName, isHost: isHost)

        self.init(player: player, network: network, stateUpdate: stateUpdate, playersUpdate: playersUpdate)
    }

    public convenience init(session: MCSession, isHost: Bool,
                            stateUpdate:   @escaping ((WKRGameState) -> Void),
                            playersUpdate: @escaping (([WKRPlayer]) -> Void)) {

        let player = WKRPlayer(profile: WKRPlayerProfile(peerID: session.myPeerID), isHost: isHost)
        let network = WKRMultipeerNetwork(session: session, isHost: isHost)

        self.init(player: player, network: network, stateUpdate: stateUpdate, playersUpdate: playersUpdate)
    }

    // MARK: View Controller Callbacks

    public func voting(timeUpdate: @escaping ((Int) -> Void),
                       infoUpdate: @escaping ((WKRVoteInfo) -> Void),
                       finalPageUpdate: @escaping ((WKRPage) -> Void)) {
        voteTimeUpdate = timeUpdate
        voteInfoUpdate = infoUpdate
        voteFinalPageUpdate = finalPageUpdate
    }

    public func results(timeUpdate: @escaping ((Int) -> Void),
                        infoUpdate: @escaping ((WKRResultsInfo) -> Void),
                        hostInfoUpdate: @escaping ((WKRResultsInfo) -> Void)) {

        resultsTimeUpdate = timeUpdate
        resultsInfoUpdate = infoUpdate
        resultsInfoHostUpdate = hostInfoUpdate
        game.currentResultsInfo = { results in
            if self.gameState == .results {
                self.resultsInfoUpdate?(results)
            }
        }
    }

    // MARK: User Interface

    public func configure(webView: WKRUIWebView, alertView: WKRUIAlertView) {
        self.webView = webView
        self.alertView = alertView

        pageNavigation.delegate = self
        webView.navigationDelegate = pageNavigation
    }

    public func presentNetworkInterface(on viewController: UIViewController) {
        peerNetwork.presentNetworkInterface(on: viewController)
    }

    public func enqueue(message: String, duration: Double = 5.0) {
        alertView.enqueue(text: message, duration: duration)
    }

    // MARK: - Actions

    public func player(_ action: WKRPlayerAction) {
        _debugLog(action)
        switch action {
        case .startedGame:
            let state = WKRGameState.voting
            peerNetwork.send(object: WKRCodable(enum: state))
        case .voted(let page):
            peerNetwork.send(object: WKRCodable(page))
        case .neededHelp:
            peerNetwork.send(object: WKRCodable(enum: WKRPlayerMessage.neededHelp))
        case .forfeited:
            peerNetwork.send(object: WKRCodable(enum: WKRPlayerMessage.forfeited))
            localPlayer.state = .forfeited
            peerNetwork.send(object: WKRCodable(localPlayer))
        case .quit:
            peerNetwork.send(object: WKRCodable(enum: WKRPlayerMessage.quit))
            localPlayer.state = .quit
            peerNetwork.send(object: WKRCodable(localPlayer))
            peerNetwork.disconnect()
        default: fatalError("\(action)")
        }
    }
}

extension Array where Element == WKRManager.WKRDebugEntry {
    func printFormatted() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        var string = ""
        for entry in self {
            string += "=========\n\nDate: \(formatter.string(from: entry.date))\nFrom: \(entry.sender.name)\n"
            string += "Object: \(entry.object)\n\n"
        }
        print(string)
    }
}
