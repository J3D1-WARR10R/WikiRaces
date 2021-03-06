//
//  PlayerUserDefaultsStat.swift
//  WikiRaces
//
//  Created by Andrew Finke on 3/6/19.
//  Copyright © 2019 Andrew Finke. All rights reserved.
//

import Foundation

enum PlayerUserDefaultsStat: String, CaseIterable {
    case multiplayerAverage

    case mpcVotes
    case mpcHelp
    case mpcPoints
    case mpcPages
    case mpcFastestTime
    case mpcTotalTime
    case mpcRaces
    case mpcTotalPlayers
    case mpcUniquePlayers
    case mpcPressedJoin
    case mpcPressedHost
    case mpcMatch
    case mpcRaceFinishFirst
    case mpcRaceFinishSecond
    case mpcRaceFinishThird
    case mpcRaceDNF
    case mpcPixelsScrolled

    case gkVotes
    case gkHelp
    case gkPoints
    case gkPages
    case gkFastestTime
    case gkTotalTime
    case gkRaces
    case gkTotalPlayers
    case gkUniquePlayers
    case gkPressedJoin
    case gkInvitedToMatch
    case gkMatch
    case gkRaceFinishFirst
    case gkRaceFinishSecond
    case gkRaceFinishThird
    case gkRaceDNF
    case gkPixelsScrolled

    case soloVotes
    case soloHelp
    case soloPages
    case soloFastestTime
    case soloTotalTime
    case soloRaces
    case soloMatch
    case soloRaceFinishFirst
    case soloRaceDNF
    case soloPixelsScrolled

    case triggeredEasterEgg

    static var numericHighStats: [PlayerUserDefaultsStat] = [
        .mpcVotes,
        .mpcHelp,
        .mpcPoints,
        .mpcPages,
        .mpcTotalTime,
        .mpcRaces,
        .mpcPressedJoin,
        .mpcPressedHost,
        .mpcMatch,
        .mpcRaceFinishFirst,
        .mpcRaceFinishSecond,
        .mpcRaceFinishThird,
        .mpcRaceDNF,
        .mpcPixelsScrolled,

        .gkVotes,
        .gkHelp,
        .gkPoints,
        .gkPages,
        .gkTotalTime,
        .gkRaces,
        .gkPressedJoin,
        .gkInvitedToMatch,
        .gkMatch,
        .gkRaceFinishFirst,
        .gkRaceFinishSecond,
        .gkRaceFinishThird,
        .gkRaceDNF,
        .gkPixelsScrolled,

        .soloVotes,
        .soloHelp,
        .soloPages,
        .soloTotalTime,
        .soloRaces,
        .soloMatch,
        .soloRaceFinishFirst,
        .soloRaceDNF,
        .soloPixelsScrolled,

        .triggeredEasterEgg
    ]

    static var numericLowStats: [PlayerUserDefaultsStat] = [
        .mpcFastestTime,
        .gkFastestTime,
        .soloFastestTime
    ]

    var key: String {
        // legacy keys
        switch self {
        case .mpcTotalPlayers:  return "WKRStat-totalPlayers"
        case .mpcUniquePlayers: return "WKRStat-uniquePlayers"
        case .mpcPoints:        return "WKRStat-points"
        case .mpcPages:         return "WKRStat-pages"
        case .mpcFastestTime:   return "WKRStat-fastestTime"
        case .mpcTotalTime:     return "WKRStat-totalTime"
        case .mpcRaces:         return "WKRStat-races"
        default:                return "WKRStat-" + self.rawValue
        }
    }

    func value() -> Double {
        if self == .multiplayerAverage {
            let races = PlayerStatsManager.shared.multiplayerRaces
            let points = PlayerStatsManager.shared.multiplayerPoints
            let value = points / races
            return value.isNaN ? 0.0 : value
        } else {
            return UserDefaults.standard.double(forKey: key)
        }
    }

    func set(value: Double) {
        UserDefaults.standard.set(value, forKey: key)
    }

    func increment(by value: Double = 1) {
        let newValue = self.value() + value
        UserDefaults.standard.set(newValue, forKey: key)
    }

}
