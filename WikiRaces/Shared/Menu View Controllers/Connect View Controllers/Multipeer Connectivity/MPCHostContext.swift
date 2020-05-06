//
//  MPCHostContext.swift
//  WikiRaces
//
//  Created by Andrew Finke on 1/30/19.
//  Copyright © 2019 Andrew Finke. All rights reserved.
//

import Foundation

struct MPCHostContext: Codable {

    static let minBuildToJoinLocalHost: Int = 7000
    static let minBuildToJoinRemoteHost: Int = 7000

    let appBuild: Int
    let appVersion: String
    let name: String

    let inviteTimeout: TimeInterval
    let minPeerAppBuild: Int
}
