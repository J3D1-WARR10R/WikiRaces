//
//  WKRSeenFinalArticlesStore.swift
//  WKRKit
//
//  Created by Andrew Finke on 1/30/19.
//  Copyright © 2019 Andrew Finke. All rights reserved.
//

import Foundation
import os.log

public struct WKRSeenFinalArticlesStore {

    // MARK: - Types

    private struct RemoteTransfer: Codable {
        internal let articles: [String]
    }

    // MARK: - Properties

    private static let defaults = UserDefaults.standard
    private static let localPlayersSeenFinalArticlesKey = "WKRKit-LocalPlayerSeenFinalArticles"
    private static var localPlayersSeenFinalArticles: [String] {
        get {
            return defaults.stringArray(forKey: localPlayersSeenFinalArticlesKey) ?? []
        }
        set {
            defaults.setValue(newValue, forKey: localPlayersSeenFinalArticlesKey)
        }
    }
    private static var uniqueRemotePlayersSeenFinalArticles = Set<String>()

    // MARK: - Helpers

    internal static func unseenArticles() -> (articles: [String], log: WKRLogEvent?) {
        var finalArticles = Set(WKRKitConstants.current.finalArticles)

        // the remaining articles could all be invalid (i.e. redirects, deleted pages, etc.)
        // make sure that we reset before the rest are invalid. minCount is that buffer.
        let minCount = 500
        var resetLog: WKRLogEvent?

        // make sure at least minCount unseen articles left before removing locally seen
        if localPlayersSeenFinalArticles.count < finalArticles.count - minCount {
            // remove local seen articles from final list
            finalArticles = finalArticles.subtracting(localPlayersSeenFinalArticles)
        } else {
            // player has seen almost all articles already
            resetLog = WKRLogEvent(type: .localVotingArticlesReset,
                                   attributes: ["ArticleCount": localPlayersSeenFinalArticles.count])
            resetLocalPlayerSeenFinalArticles()
        }

        // make sure at least minCount unseen articles left before removing remotely seen
        if uniqueRemotePlayersSeenFinalArticles.count < finalArticles.count - minCount {
            finalArticles = finalArticles.subtracting(uniqueRemotePlayersSeenFinalArticles)
        }

        return (Array(finalArticles), resetLog)
    }

    // MARK: - Local Player

    public static func encodedLocalPlayerSeenFinalArticles() -> Data? {
        let object = RemoteTransfer(articles: localPlayersSeenFinalArticles)
        return try? JSONEncoder().encode(object)
    }

    internal static func addLocalPlayerSeenFinalPages(_ newSeenFinalPages: [WKRPage]) {
        let paths = newSeenFinalPages.map({ $0.path })
        var articles = localPlayersSeenFinalArticles
        articles.append(contentsOf: paths)
        localPlayersSeenFinalArticles = Array(Set(articles))
    }

    private static func resetLocalPlayerSeenFinalArticles() {
        os_log("%{public}s", log: .seenArticlesStore, type: .info, #function)
        localPlayersSeenFinalArticles = []
    }

    // MARK: - Remote Players

    public static func addRemoteTransferData(_ data: Data) {
        os_log("%{public}s", log: .seenArticlesStore, type: .info, #function)
        guard let tranfer = try? JSONDecoder().decode(RemoteTransfer.self, from: data) else { return }

        os_log("%{public}s: got %{public}ld", log: .seenArticlesStore, type: .info, #function, tranfer.articles.count)

        // 1. Add new paths
        // 2. Remove copies from remote array that are already in local array
        uniqueRemotePlayersSeenFinalArticles = uniqueRemotePlayersSeenFinalArticles
            .union(tranfer.articles)
            .subtracting(localPlayersSeenFinalArticles)

        os_log("%{public}s: total remote seen %{public}ld", log: .seenArticlesStore, type: .info, #function, uniqueRemotePlayersSeenFinalArticles.count)
    }

    public static func isRemoteTransferData(_ data: Data) -> Bool {
        guard let _ = try? JSONDecoder().decode(RemoteTransfer.self, from: data) else { return false }
        return true
    }

    public static func resetRemotePlayersSeenFinalArticles() {
        uniqueRemotePlayersSeenFinalArticles = []
        os_log("%{public}s", log: .seenArticlesStore, type: .info, #function)
    }

    public static func hostLogEvents() -> [WKRLogEvent] {
        let seenLocalCount = localPlayersSeenFinalArticles.count
        let seenCollectiveCount = Set(localPlayersSeenFinalArticles)
            .union(uniqueRemotePlayersSeenFinalArticles)
            .count

        return [
            WKRLogEvent(type: .localVotingArticlesSeen,
                        attributes: ["ArticleCount": seenLocalCount]),
            WKRLogEvent(type: .collectiveVotingArticlesSeen,
                        attributes: ["ArticleCount": seenCollectiveCount])
        ]
    }

    public static func localLogEvents() -> [WKRLogEvent] {
        let seenLocalCount = localPlayersSeenFinalArticles.count
        return [
            WKRLogEvent(type: .localVotingArticlesSeen,
                        attributes: ["ArticleCount": seenLocalCount])
        ]
    }

}
