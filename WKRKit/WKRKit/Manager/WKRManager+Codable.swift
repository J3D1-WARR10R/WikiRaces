//
//  WKRGameManager+Codable.swift
//  WKRKit
//
//  Created by Andrew Finke on 8/5/17.
//  Copyright © 2017 Andrew Finke. All rights reserved.
//

import WKRUIKit

extension WKRGameManager {

    // MARK: - Object Handling

    internal func receivedRaw(_ object: WKRCodable, from player: WKRPlayerProfile) {
        if let preRaceConfig = object.typeOf(WKRPreRaceConfig.self) {
            game.preRaceConfig = preRaceConfig
            votingUpdate(.votingState(preRaceConfig.votingState))

            if webView?.url != preRaceConfig.startingPage.url {
                webView?.load(URLRequest(url: preRaceConfig.startingPage.url))
            }

            WKRSeenFinalArticlesStore.addLocalPlayerSeenFinalPages(preRaceConfig.votingState.pages)
        } else if let raceConfig = object.typeOf(WKRRaceConfig.self) {
            game.startRace(with: raceConfig)
            votingUpdate(.raceConfig(raceConfig))
        } else if let playerObject = object.typeOf(WKRPlayer.self) {
            if !game.players.contains(playerObject) && playerObject != localPlayer {
                peerNetwork.send(object: WKRCodable(localPlayer))
            }
            game.playerUpdated(playerObject)

            // if: other player just got to the same page
            // else if: local player just got to a new page
            var samePagePlayers = [WKRPlayerProfile]()
            if playerObject != localPlayer && game.shouldShowSamePageMessage(for: playerObject) {
                samePagePlayers.append(playerObject.profile)
            } else if playerObject == localPlayer {
                for player in game.players where game.shouldShowSamePageMessage(for: player) {
                    samePagePlayers.append(player.profile)
                }
            }

            var samePageMessage: String?
            if samePagePlayers.count == 1 {
                samePageMessage = "is on same page"
            } else if samePagePlayers.count > 1 {
                samePageMessage = "\(samePagePlayers.count) players are on same page"
            }
            if let message = samePageMessage {
                enqueue(message: message,
                        for: samePagePlayers.count == 1 ? samePagePlayers[0] : nil,
                        duration: 2.0,
                        isRaceSpecific: true,
                        playHaptic: false)
            }

            // Player joined mid-session
            if playerObject.state == .connecting
                && localPlayer.state != .connecting
                && localPlayer.isHost
                && gameState == .hostResults,
                let results = hostResultsInfo {
                peerNetwork.send(object: WKRCodable(results))
            }
        } else if let resultsInfo = object.typeOf(WKRResultsInfo.self), hostResultsInfo == nil {
            receivedFinalResults(resultsInfo)
        } else if let pageVote = object.typeOf(WKRPage.self), localPlayer.isHost {
            game.player(player, votedFor: pageVote)
            sendPreRaceConfig()
        }
    }

    internal func receivedEnum(_ object: WKRCodable, from player: WKRPlayerProfile) {
        if let gameState = object.typeOfEnum(WKRGameState.self) {
            transitionGameState(to: gameState)
        } else if let message = object.typeOfEnum(WKRPlayerMessage.self), player != localPlayer.profile {
            var isRaceSpecific = true
            var playHaptic = false
            if message == .quit {
                isRaceSpecific = false
            } else if message == .foundPage {
                playHaptic = true
            }

            // Don't show "on USA" message if expected to show "is on same page" message
            let lastPageTitle = localPlayer.raceHistory?.entries.last?.page.title ?? ""
            if message == .onUSA && lastPageTitle == "United States" {
                return
            }

            switch message {
            case .linkOnPage:
                if !settings.notifications.linkOnPage { return }
            case .missedLink:
                if !settings.notifications.missedLink { return }
            case .neededHelp:
                if !settings.notifications.neededHelp { return }
            case .onUSA:
                if !settings.notifications.isOnUSA { return }
            default:
                break
            }

            enqueue(message: message.text,
                    for: player,
                    duration: 3.0,
                    isRaceSpecific: isRaceSpecific,
                    playHaptic: playHaptic)
        } else if let error = object.typeOfEnum(WKRFatalError.self), !isFailing {
            isFailing = true
            localPlayer.state = .quit
            peerNetwork.send(object: WKRCodable(localPlayer))
            peerNetwork.disconnect()
            gameUpdate(.error(error))
        }
    }

    internal func receivedInt(_ object: WKRCodable, from player: WKRPlayerProfile) {
        guard let int = object.typeOf(WKRInt.self) else { fatalError("Object not a WKRInt type") }
        switch int.type {
        case .votingTime, .votingPreRaceTime:
            votingUpdate(.remainingTime(int.value))
        case .resultsTime:
            resultsUpdate(.remainingTime(int.value))
        case .bonusPoints:
            let string = int.value == 1 ? "Point" : "Points"
            let message = "Race Bonus Now \(int.value) " + string
            enqueue(message: message,
                    for: nil,
                    duration: 2.0,
                    isRaceSpecific: true,
                    playHaptic: false)
        case .showReady:
            resultsUpdate(.isReadyUpEnabled(int.value == 1))
        }
    }

    // MARK: - Game Updates

    private func receivedFinalResults(_ resultsInfo: WKRResultsInfo) {
        alertView.clearRaceSpecificMessages()
        game.finishedRace()

        if gameState != .hostResults {
            transitionGameState(to: .hostResults)
        }

        hostResultsInfo = resultsInfo
        resultsUpdate(.hostResultsInfo(resultsInfo))

        if localPlayer.state == .racing {
            localPlayer.state = .forcedEnd
        }
        if !localPlayer.hasReceivedPointsForCurrentRace {
            localPlayer.hasReceivedPointsForCurrentRace = true

            let points = resultsInfo.raceRewardPoints(for: localPlayer)
            var place: Int?

            for (index, player) in resultsInfo.raceRankings().enumerated() {
                if player == localPlayer && player.state == .foundPage {
                    place = index + 1
                }
            }

            let webViewPixelsScrolled = webView?.pixelsScrolled ?? 0
            let pages = resultsInfo.pagesViewed(for: localPlayer)
            gameUpdate(.playerStatsForLastRace(points: points,
                                               place: place,
                                               webViewPixelsScrolled: webViewPixelsScrolled,
                                               pages: pages))
        }

        peerNetwork.send(object: WKRCodable(localPlayer))
    }

    internal func transitionGameState(to state: WKRGameState) {
        game.state = state

        switch state {
        case .voting:
            hostResultsInfo = nil
            localPlayer.state = .voting
            localPlayer.raceHistory = nil
            localPlayer.hasReceivedPointsForCurrentRace = false
            if localPlayer.isHost {
                fetchPreRaceConfig()
            }
        case .race:
            guard let raceConfig = game.raceConfig else {
                localErrorOccurred(.configCreationFailed)
                return
            }
            localPlayer.startedNewRace(on: raceConfig.startingPage)
        case .hostResults:
            localPlayer.raceHistory = nil
        default:
            break
        }

        peerNetwork.send(object: WKRCodable(localPlayer))
        gameUpdate(.state(state))
    }

}
