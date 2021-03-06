//
//  WKRGame.swift
//  WKRKit
//
//  Created by Andrew Finke on 8/5/17.
//  Copyright © 2017 Andrew Finke. All rights reserved.
//

import WKRUIKit

final public class WKRGame {

    // MARK: - Types

    enum ListenerUpdate {
        case bonusPoints(Int)
        case playersReadyForNextRound
        case readyStates(WKRReadyStates)
        case hostResults(WKRResultsInfo)
        case localResults(WKRResultsInfo)
    }

    // MARK: - Closures

    var listenerUpdate: ((ListenerUpdate) -> Void)?

    // MARK: - Properties

    private let isSolo: Bool
    private let settings: WKRGameSettings

    private var bonusTimer: Timer?
    private let localPlayer: WKRPlayer

    internal var players = [WKRPlayer]()

    internal var raceConfig: WKRRaceConfig?
    internal var preRaceConfig: WKRPreRaceConfig?

    internal private(set) var activeRace: WKRRace?
    internal private(set) var completedRaces = [WKRRace]()

    public internal(set) var state = WKRGameState.preMatch

    // MARK: - Initialization

    init(localPlayer: WKRPlayer, isSolo: Bool, settings: WKRGameSettings) {
        self.isSolo = isSolo
        self.localPlayer = localPlayer
        self.settings = settings
    }

    // MARK: - Race Config

    internal func startRace(with config: WKRRaceConfig) {
        raceConfig = config
        activeRace = WKRRace(config: config, isSolo: isSolo)
        preRaceConfig = nil

        if localPlayer.isHost && !isSolo {
            bonusTimer?.invalidate()
            bonusTimer = Timer.scheduledTimer(
                withTimeInterval: settings.points.bonusPointsInterval,
                repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    self.activeRace?.bonusPoints += self.settings.points.bonusPointReward
                    if let points = self.activeRace?.bonusPoints {
                        self.listenerUpdate?(.bonusPoints(points))
                    }
            }
        }

    }

    func createRaceConfig() -> (config: WKRRaceConfig?, logEvent: WKRLogEvent?)? {
        guard localPlayer.isHost else { fatalError("Local player not host") }

        var sessionPoints = calculateSessionPoints()

        // include players that have no points yet
        let votingPlayers = players
            .filter { $0.state == .voting }
            .map { $0.profile }
        for player in votingPlayers where sessionPoints[player] == nil {
            sessionPoints[player] = 0
        }
        return preRaceConfig?.raceConfig(with: sessionPoints)
    }

    func finishedRace() {
        if var race = activeRace {
            race.linkedPagesFetcher = nil
            completedRaces.append(race)
        }
        activeRace = nil
        bonusTimer?.invalidate()
    }

    // MARK: - Player Voting

    internal func player(_ profile: WKRPlayerProfile, votedFor page: WKRPage) {
        preRaceConfig?.votingState.player(profile, votedFor: page)
    }

    internal func playerDisconnected(_ profile: WKRPlayerProfile) {
        guard let player = players.first(where: ({ $0.profile == profile })) else { return }
        player.state = .quit
        checkForRaceEnd()
    }

    // MARK: - Player States

    internal func playerUpdated(_ player: WKRPlayer) {
        if let index = players.firstIndex(of: player) {
            players[index] = player
        } else {
            players.append(player)
        }
        if player.state == .foundPage {
            bonusTimer?.invalidate()
        }

        activeRace?.playerUpdated(player)
        checkForRaceEnd()

        guard state == .hostResults else {
            return
        }

        let readyStates = WKRReadyStates(players: players)
        listenerUpdate?(.readyStates(readyStates))
        if localPlayer.isHost,
            let racePlayers = completedRaces.last?.players,
            readyStates.areAllRacePlayersReady(racePlayers: racePlayers) {
            listenerUpdate?(.playersReadyForNextRound)
        }
    }

    func shouldShowSamePageMessage(for player: WKRPlayer) -> Bool {
        /*
         Conditions:
         - player can't be local player
         - both players have to be racing
         - both players need histories
         - both players need at least three pages viewed (don't want to spam messages at start of race)
         - last viewed page needs to be the same
         - duration must be nil (must not be moving to new page)
         - link can't be on the page (don't want players to know they are close)
         */
        guard settings.notifications.isOnSamePage,
            localPlayer != player,
            player.state == .racing,
            localPlayer.state == .racing,
            let playerEntries = player.raceHistory?.entries,
            let localEntries = localPlayer.raceHistory?.entries,
            playerEntries.count > 2,
            localEntries.count > 2,
            let localPage = localEntries.last?.page,
            playerEntries.last?.page == localPage,
            playerEntries.last?.duration == nil,
            localEntries.last?.duration == nil,
            let isLinkOnPage = activeRace?.attributes(for: localPage).linkOnPage,
            !isLinkOnPage else { return false }

        return true
    }

    // MARK: - Race End

    func calculateSessionPoints() -> [WKRPlayerProfile: Int] {
        var sessionPoints = [WKRPlayerProfile: Int]()
        for race in completedRaces {
            for (player, points) in race.calculatePoints() {
                if let previousPoints = sessionPoints[player] {
                    sessionPoints[player] = previousPoints + points
                } else {
                    sessionPoints[player] = points
                }
            }
        }
        return sessionPoints
    }

    func checkForRaceEnd() {
        var sessionPoints = calculateSessionPoints()

        let racePoints = activeRace?.calculatePoints() ?? [:]
        for (player, points) in racePoints {
            if let previousPoints = sessionPoints[player] {
                sessionPoints[player] = previousPoints + points
            } else {
                sessionPoints[player] = points
            }
        }

        let currentResults = WKRResultsInfo(racePlayers: activeRace?.players ?? players,
                                            racePoints: racePoints,
                                            sessionPoints: sessionPoints)

        guard let race = activeRace, localPlayer.isHost, race.shouldEnd() else {
            listenerUpdate?(.localResults(currentResults))
            return
        }

        let adjustedPlayers = activeRace?.players ?? players
        for player in adjustedPlayers where player.state == .racing {
            player.state = .forcedEnd
        }
        let results = WKRResultsInfo(racePlayers: adjustedPlayers,
                                     racePoints: racePoints,
                                     sessionPoints: sessionPoints)

        finishedRace()
        listenerUpdate?(.hostResults(results))
    }

}
