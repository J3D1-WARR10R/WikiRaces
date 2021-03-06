//
//  PlayerDatabaseMetrics.swift
//  WikiRaces
//
//  Created by Andrew Finke on 1/29/19.
//  Copyright © 2019 Andrew Finke. All rights reserved.
//

import CloudKit
import UIKit
import WKRKit

final class PlayerCloudKitStatsManager: NSObject {

    // MARK: - Types -

    private struct ProcessedResults {
        let csvURL: URL
        let playerCount: Int
        let totalPlayerTime: Int
        let links: Int
    }

    // MARK: - Properties -

    static let shared = PlayerCloudKitStatsManager()

    static let banHammerNotification = Notification.Name("banHammerNotification")

    private let container = CKContainer.default()
    private let publicDB = CKContainer.default().publicCloudDatabase

    private var userRecord: CKRecord?
    private var userStatsRecord: CKRecord?

    private var isConnecting = false
    private var isCreatingStatsRecord = false
    private var isSyncing = false

    private var queuedKeyValues = [String: CKRecordValueProtocol]()

    // MARK: - Initalization -

    private override init() {
        super.init()
    }

    // MARK: - Connecting -

    func connect() {
        #if MULTIWINDOWDEBUG
        return
        #endif

        guard !isConnecting else { return }
        isConnecting = true

        // seperated out due to type checking time

        // step 2, get the user main record
        func fetched(userRecord: CKRecord?) {
            self.userRecord = userRecord
            guard let userRecord = userRecord else {
                isConnecting = false
                return
            }

            // negative races indicates ban
            if let raceCount = userRecord["Races"] as? NSNumber, raceCount.intValue == -1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                    let name = PlayerCloudKitStatsManager.banHammerNotification
                    NotificationCenter.default.post(name: name, object: nil)
                })
                return
            }

            // Get user stats record, or create new one.
            guard let statsRecordName = userRecord.object(forKey: "UserStatsNamev3") as? NSString,
                  statsRecordName.length > 5 else {
                self.createUserStatsRecord()
                self.isConnecting = false
                return
            }
            let userStatsRecordID = CKRecord.ID(recordName: statsRecordName as String)
            self.publicDB.fetch(withRecordID: userStatsRecordID, completionHandler: { userStatsRecord, error in
                fetched(userStatsRecord: userStatsRecord, error: error)
            })
        }

        // step 3, get the current user stats record
        func fetched(userStatsRecord: CKRecord?, error: Error?) {
            if let error = error as? CKError, error.code == CKError.unknownItem {
                createUserStatsRecord()
                isConnecting = false
                return
            }
            guard let userStatsRecord = userStatsRecord else { return }
            self.userStatsRecord = userStatsRecord
            isConnecting = false
            DispatchQueue.main.async {
                self.saveKeyValues()
            }
        }

        // step 1
        container.fetchUserRecordID(completionHandler: { userRecordID, _ in
            guard let userRecordID = userRecordID else {
                self.isConnecting = false
                return
            }
            self.publicDB.fetch(withRecordID: userRecordID, completionHandler: { userRecord, _ in
                fetched(userRecord: userRecord)
            })
        })
    }

    private func createUserStatsRecord() {
        guard let userRecord = userRecord, !isCreatingStatsRecord else { return }
        isCreatingStatsRecord = true

        let userStatsRecord = CKRecord(recordType: "UserStatsv3")
        userStatsRecord["DeviceNames"] = [UIDevice.current.name]
        publicDB.save(userStatsRecord, completionHandler: { (savedUserStatsRecord, _) in
            guard let savedUserStatsRecord = savedUserStatsRecord else {
                self.isCreatingStatsRecord = false
                return
            }
            userRecord["UserStatsNamev3"] = savedUserStatsRecord.recordID.recordName as NSString

            self.publicDB.save(userRecord, completionHandler: { (savedUserRecord, _) in
                self.userRecord = savedUserRecord
                self.userStatsRecord = savedUserStatsRecord
                self.isCreatingStatsRecord = false
                DispatchQueue.main.async {
                    self.saveKeyValues()
                }
            })
        })
    }

    // MARK: - Events -

    func log(value: CKRecordValueProtocol, for key: String) {
        DispatchQueue.main.async {
            self.queuedKeyValues[key] = value
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                self.saveKeyValues()
            })
        }
    }

    private func saveKeyValues() {
        guard !queuedKeyValues.isEmpty,
              !isConnecting,
              !isCreatingStatsRecord,
              !isSyncing,
              let record = userStatsRecord else { return }

        isSyncing = true
        let keyValues = queuedKeyValues
        queuedKeyValues = [:]

        for (key, value) in keyValues {
            if key == "GCAliases" || key == "DeviceNames" || key == "CustomNames" {
                guard let name = value as? String else { return }
                var names = [String]()
                if let existingNames = record[key] as? [String] {
                    names.append(contentsOf: existingNames)
                }
                names.append(name)
                record[key] = Array(Set(names))
            } else if let num = value as? Double {
                if num.isFinite {
                    if floor(num) == num {
                        record[key] = Int(num)
                    } else {
                        record[key] = num
                    }
                }
            } else {
                record[key] = value
            }
        }

        publicDB.save(record) { savedUserStatsRecord, _ in
            if let savedUserStatsRecord = savedUserStatsRecord {
                self.userStatsRecord = savedUserStatsRecord
            } else {
                self.userStatsRecord = nil
                self.userRecord = nil
                DispatchQueue.main.async {
                    for (key, value) in keyValues where self.queuedKeyValues[key] == nil {
                        self.queuedKeyValues[key] = value
                    }
                }
                self.connect()
            }
            DispatchQueue.main.async {
                self.isSyncing = false
                self.saveKeyValues()
            }
        }
    }

    // MARK: - Results Collection

    func record(results: WKRResultsInfo) {
        #if MULTIWINDOWDEBUG
        return
        #endif

        guard let processedResults = process(results: results) else { return }

        let resultsRecord = CKRecord(recordType: "RaceResult")
        resultsRecord["CSV"] = CKAsset(fileURL: processedResults.csvURL)
        resultsRecord["Links"] = NSNumber(value: processedResults.links)
        resultsRecord["PlayerCount"] = NSNumber(value: processedResults.playerCount)
        resultsRecord["TotalPlayerTime"] = NSNumber(value: processedResults.totalPlayerTime)

        publicDB.save(resultsRecord) { _, _ in
            try? FileManager.default.removeItem(at: processedResults.csvURL)
        }
    }

    private func process(results: WKRResultsInfo) -> ProcessedResults? {

        func csvRow(for player: WKRPlayer, state: WKRPlayerState) -> String {

            func formatted(row: String?) -> String {
                return row?.replacingOccurrences(of: ",", with: " ") ?? ""
            }

            var string = ""
            string += formatted(row: player.name) + ","
            string += formatted(row: state.text) + ","

            if state == .foundPage {
                let time = String(player.raceHistory?.duration ?? 0)
                string += formatted(row: time) + ","
            } else {
                string += ","
            }

            for entry in player.raceHistory?.entries ?? [] {
                let title = (entry.page.title ?? "")
                let duration = String(entry.duration ?? 0)  + "|"
                string += formatted(row: duration + title) + ","
            }

            string.removeLast()

            return string
        }

        var links = 0
        var totalPlayerTime = 0

        var csvString = "Name,State,Duration,Pages\n"
        for player in results.raceRankings() {
            links += player.raceHistory?.entries.count ?? 0
            totalPlayerTime += player.raceHistory?.duration ?? 0
            csvString += csvRow(for: player, state: player.state) + "\n"
        }

        guard let filePath = FileManager
                .default
                .urls(for: .documentDirectory, in: .userDomainMask)
                .last?
                .path
                .appendingFormat("/\(Date()).csv") else {
            return nil
        }
        do {
            try csvString.write(toFile: filePath, atomically: true, encoding: .utf8)
            return ProcessedResults(csvURL: URL(fileURLWithPath: filePath),
                                    playerCount: results.raceRankings().count,
                                    totalPlayerTime: totalPlayerTime,
                                    links: links)
        } catch {
            return nil
        }
    }

}
