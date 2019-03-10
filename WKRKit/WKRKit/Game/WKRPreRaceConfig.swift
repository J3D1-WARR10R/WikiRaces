//
//  WKRPreRaceConfig.swift
//  WKRKit
//
//  Created by Andrew Finke on 8/5/17.
//  Copyright © 2017 Andrew Finke. All rights reserved.
//

import Foundation

/// Used to transmit voting data and starting page
public struct WKRPreRaceConfig: Codable, Equatable {

    // MARK: - Properties

    /// The voting info
    internal var voteInfo: WKRVoteInfo
    /// The starting page
    internal let startingPage: WKRPage

    // MARK: Initialization

    /// Creates a WKRPreRaceConfig object
    ///
    /// - Parameters:
    ///   - startingPage: The starting page
    ///   - voteInfo: The voting info
    private init(startingPage: WKRPage, voteInfo: WKRVoteInfo) {
        self.voteInfo = voteInfo
        self.startingPage = startingPage
    }

    // MARK: - Creation

    /// Creates a race config object based on starting page and voting data
    ///
    /// - Returns: The new race config
    internal func raceConfig(with weights: [WKRPlayerProfile: Int]) -> WKRRaceConfig? {
        guard let finalPage = voteInfo.selectFinalPage(with: weights) else {
            return nil
        }
        return WKRRaceConfig(starting: startingPage, ending: finalPage)
    }

    /// Creates a WKRPreRaceConfig object
    ///
    /// - Parameter completionHandler: The handler holding the new config object
    static func new(completionHandler: @escaping ((_ config: WKRPreRaceConfig?) -> Void)) {
        let finalArticles = WKRSeenFinalArticlesStore.unseenArticles()

        let operationQueue = OperationQueue()

        // Get a few more than neccessary random paths in case some final articles are no longer valid
        var randomPaths = [String]()
        let numberOfPagesToFetch = WKRKitConstants.current.votingArticlesCount + 1

        // pages are suffled so we can just take index 0-n from the shuffled array
        for index in 0..<numberOfPagesToFetch where index < finalArticles.count {
            randomPaths.append(finalArticles[index])
        }

        var pages = [WKRPage]()
        var startingPage: WKRPage?

        let completedOperation = BlockOperation {
            // Used for quick debug to set first page to Apple and final page to first link on page.
            if WKRKitConstants.current.isQuickRaceMode {
                let startingURL = URL(string: "https://en.m.wikipedia.org/wiki/Apple_Inc.")!
                startingPage = WKRPage(title: "Apple Inc.", url: startingURL)

                let endingURL = URL(string: "https://en.m.wikipedia.org/wiki/Apple_Park")!
                let fakeEnd = WKRPage(title: "Apple Park", url: endingURL)

                pages.removeLast()
                pages.insert(fakeEnd, at: 0)
            }

            // Uses a set to remove any duplicates. This could happen if two final articles end up redirecting to the same page.
            let finalPages = Array(Set(pages.prefix(WKRKitConstants.current.votingArticlesCount)))
            if !finalPages.isEmpty, let page = startingPage {
                let config = WKRPreRaceConfig(startingPage: page, voteInfo: WKRVoteInfo(pages: finalPages))
                completionHandler(config)
            } else {
                completionHandler(nil)
            }

        }

        // Gets the starting page
        let startingPageOperation = WKROperation()
        startingPageOperation.addExecutionBlock { [unowned startingPageOperation] in
            WKRPageFetcher.fetchRandom { page in
                startingPage = page
                startingPageOperation.state = .isFinished
            }
        }
        completedOperation.addDependency(startingPageOperation)

        // All the operations for get WKRPage objects to vote on
        let endingPageOperations = randomPaths.map { path -> WKROperation in
            let operation = WKROperation()
            operation.addExecutionBlock { [unowned operation] in
                // don't use cache to make sure to get most recent page
                WKRPageFetcher.fetch(path: path, useCache: false) { page in
                    // 1. Make sure page not nil
                    // 2. Make sure page is not a link to a section "/USA#History"
                    // 3. Sometimes removed pages redirect to the Wikipedia homepage.
                    // 4/5. Make sure link not equal to starting page
                    if let page = page,
                        !page.url.absoluteString.contains("#"),
                         page.title != "Wikipedia, the free encyclopedia",
                        let startingPage = startingPage,
                        startingPage.url != page.url {
                        pages.append(page)
                    }
                    operation.state = .isFinished
                }
            }
            operation.addDependency(startingPageOperation)
            completedOperation.addDependency(operation)
            return operation
        }

        operationQueue.addOperations([startingPageOperation, completedOperation], waitUntilFinished: false)
        operationQueue.addOperations(endingPageOperations, waitUntilFinished: false)
    }

}
