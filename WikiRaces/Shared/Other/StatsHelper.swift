//
//  StatsHelper.swift
//  WikiRaces
//
//  Created by Andrew Finke on 8/31/17.
//  Copyright © 2017 Andrew Finke. All rights reserved.
//

import GameKit
import CloudKit

class StatsHelper {

    // MARK: - Types

    enum Stat: String {
        case points
        case races
        case average

        var key: String {
            return "WKRStat-" + self.rawValue
        }

        var leaderboard: String {
            switch self {
            case .points:   return "com.andrewfinke.wikiraces.points"
            case .races:    return "com.andrewfinke.wikiraces.races"
            case .average:  return "com.andrewfinke.wikiraces.ppr"
            }
        }
    }

    // MARK: - Properties

    static let shared = StatsHelper()

    var statsUpdated: ((_ points: Double, _ races: Double, _ average: Double) -> Void)?
    private let migrationKey = "WKR3StatMigrationComplete"

    private let defaults = UserDefaults.standard
    private let keyValueStore = NSUbiquitousKeyValueStore.default

    init() {
        attemptMigration()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func start() {
        attemptMigration()
        cloudSync()
        leaderboardSync()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyValueStoreChanged(_:)),
                                               name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: keyValueStore)

        keyValueStore.synchronize()
    }

    func updateStatsClosure() {
        statsUpdated?(statValue(for: .points), statValue(for: .races), statValue(for: .average))
    }

    // MARK: - Set/Get Stats

    func statValue(for stat: Stat) -> Double {
        if stat == .average {
            let value = statValue(for: .points) / statValue(for: .races)
            return value.isNaN ? 0.0 : value
        } else {
            return defaults.double(forKey: stat.key)
        }
    }

	func completedRace(points: Int) {
        let newPoints = statValue(for: .points) + Double(points)
        let newRaces = statValue(for: .races) + 1

        defaults.set(newPoints, forKey: Stat.points.key)
        defaults.set(newRaces, forKey: Stat.races.key)

        cloudSync()
        leaderboardSync()
        updateStatsClosure()
    }

    private func attemptMigration() {
        guard !defaults.bool(forKey: migrationKey) else {
            return
        }

        let oldPoints = Double(UserDefaults.standard.integer(forKey: "Points"))
        let oldRaces = Double(UserDefaults.standard.integer(forKey: "Rounds"))

        defaults.set(oldPoints, forKey: Stat.points.key)
        defaults.set(oldRaces, forKey: Stat.races.key)
        defaults.set(true, forKey: migrationKey)

        cloudSync()
        leaderboardSync()
        updateStatsClosure()
    }

    // MARK: - Syncing

    @objc private func keyValueStoreChanged(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo,
            let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
            let reasonForChange = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? NSNumber  else {
                return
        }

        let reason = reasonForChange.intValue
        if reason == NSUbiquitousKeyValueStoreServerChange || reason == NSUbiquitousKeyValueStoreInitialSyncChange {
            for key in changedKeys {
                let deviceValue = defaults.double(forKey: key)
                let cloudValue = keyValueStore.double(forKey: key)
                if deviceValue > cloudValue {
                    keyValueStore.set(deviceValue, forKey: key)
                } else {
                    defaults.set(deviceValue, forKey: key)
                }
            }
        }

        leaderboardSync()
        updateStatsClosure()
    }

    private func cloudSync() {
        let stats = [Stat.points, Stat.races]
        for stat in stats {
            let deviceValue = defaults.double(forKey: stat.key)
            let cloudValue = keyValueStore.double(forKey: stat.key)
            if deviceValue > cloudValue {
                keyValueStore.set(deviceValue, forKey: stat.key)
            } else {
                defaults.set(cloudValue, forKey: stat.key)
            }
        }
    }

    private func leaderboardSync() {
        guard GKLocalPlayer.localPlayer().isAuthenticated else {
            return
        }

        let points = statValue(for: .points)
        let races = statValue(for: .races)
        let average = statValue(for: .average)

        let pointsScore = GKScore(leaderboardIdentifier: Stat.points.leaderboard)
        pointsScore.value = Int64(points)

        let racesScore = GKScore(leaderboardIdentifier: Stat.races.leaderboard)
        racesScore.value = Int64(races)

        var scores = [pointsScore, racesScore]
        if races >= 5 {
            let averageScore = GKScore(leaderboardIdentifier: Stat.average.leaderboard)
            averageScore.value = Int64(average * 1000)
            scores.append(averageScore)
        }
        GKScore.report(scores, withCompletionHandler: nil)
    }

}