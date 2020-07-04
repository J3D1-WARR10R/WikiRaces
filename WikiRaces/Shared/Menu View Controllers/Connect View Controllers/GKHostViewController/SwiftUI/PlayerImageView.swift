//
//  PlayerImageView.swift
//  WikiRaces
//
//  Created by Andrew Finke on 6/25/20.
//  Copyright © 2020 Andrew Finke. All rights reserved.
//

import SwiftUI

struct PlayerImageView: View {

    // MARK: - Properties -

    let player: SwiftUIPlayer
    let size: CGFloat
    let effectSize: CGFloat

    // MARK: - Body -

    var body: some View {
        PlayerImageDatabase.shared.image(for: player.id)
            .renderingMode(.original)
            .resizable()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .shadow(radius: effectSize)
    }
}