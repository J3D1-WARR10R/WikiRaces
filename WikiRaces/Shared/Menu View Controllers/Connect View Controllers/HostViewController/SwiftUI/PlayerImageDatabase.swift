//
//  PlayerImageDatabase.swift
//  WikiRaces
//
//  Created by Andrew Finke on 6/25/20.
//  Copyright © 2020 Andrew Finke. All rights reserved.
//

import GameKit
import SwiftUI

class PlayerImageDatabase {

    // MARK: - Properties -

    static var shared = PlayerImageDatabase()
    private var dict = [String: Image]()

    private(set) var hasValidLocalPlayerImage = false

    // MARK: - Initalization -

    private init() {}

    // MARK: - Helpers -

    func connected(to player: GKPlayer, completion: (() -> Void)?) {
        dict[player.alias] = Image("temp")

        player.loadPhoto(for: .small) { photo, _ in
            guard let photo = photo else {
                completion?()
                return

            }
            if player.alias == GKLocalPlayer.local.alias {
                self.hasValidLocalPlayerImage = true
            }
            self.dict[player.alias] = Image(uiImage: photo)
            completion?()
        }
    }

    func image(for playerID: String) -> Image {
        guard let image = dict[playerID] else {
            return Image("temp")
            // TODO: fix
            //            fatalError()
        }
        print("PlayerImageDatabase: \(playerID)")
        return image
    }
}
