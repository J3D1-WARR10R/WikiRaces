//
//  OSLog+WKRKit.swift
//  WKRKit
//
//  Created by Andrew Finke on 7/2/20.
//  Copyright © 2020 Andrew Finke. All rights reserved.
//

import Foundation
import os.log

extension OSLog {

    // MARK: - Types -

    private enum CustomCategory: String {
        case constants, seenArticlesStore, articlesValidation
    }

    private static let subsystem: String = {
        guard let identifier = Bundle.main.bundleIdentifier else { fatalError() }
        return identifier
    }()

    static let constants = OSLog(subsystem: subsystem, category: CustomCategory.constants.rawValue)
    static let seenArticlesStore = OSLog(subsystem: subsystem, category: CustomCategory.seenArticlesStore.rawValue)
    static let articlesValidation = OSLog(subsystem: subsystem, category: CustomCategory.articlesValidation.rawValue)

}
