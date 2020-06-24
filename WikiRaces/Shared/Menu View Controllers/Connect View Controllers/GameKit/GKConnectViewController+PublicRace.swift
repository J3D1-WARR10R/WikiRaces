//
//  a.swift
//  WikiRaces
//
//  Created by Andrew Finke on 6/24/20.
//  Copyright © 2020 Andrew Finke. All rights reserved.
//

import GameKit
import WKRKit

extension GKConnectViewController {
    
    // MARK: - Public Races -
    
    func publicRaceProcess(data: Data, from player: GKPlayer) {
        guard let match = match else { fatalError() }
        
        if isPlayerHost, WKRSeenFinalArticlesStore.isRemoteTransferData(data) {
            WKRSeenFinalArticlesStore.addRemoteTransferData(data)
        } else if let object = try? JSONDecoder().decode(StartMessage.self, from: data) {
            guard let hostAlias = self.publicRaceHostAlias, object.hostName == hostAlias else {
                PlayerAnonymousMetrics.log(event: .globalFailedToFindHost)
                let message = "Please try again later."
                showError(title: "Unable To Find Best Host", message: message)
                return
            }
            if let data = WKRSeenFinalArticlesStore.encodedLocalPlayerSeenFinalArticles() {
                try? match.send(data, to: [player], dataMode: .reliable)
            }
            showMatch(for: .gameKit(match: match, isHost: isPlayerHost), settings: object.gameSettings, andHide: [])
        }
    }
    
    func publicRaceSendStartMessage() {
        func fail() {
            showError(title: "Unable To Start Match",
                      message: "Please try again later.")
        }
        guard let match = match else {
            fail()
            let info = "findMatch: No valid match"
            PlayerAnonymousMetrics.log(event: .error(info))
            return
        }
        
        let settings = WKRGameSettings()
        let message = StartMessage(hostName: GKLocalPlayer.local.alias, gameSettings: settings)
        do {
            let data = try JSONEncoder().encode(message)
            try match.sendData(toAllPlayers: data, with: .reliable)
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                self.showMatch(for: .gameKit(match: match,
                                             isHost: true),
                               settings: settings,
                               andHide: [])
            }
        } catch {
            fail()
            let info = "sendStartMessageToPlayers: " + error.localizedDescription
            PlayerAnonymousMetrics.log(event: .error(info))
        }
    }
    
    func publicRaceDetermineHost(match: GKMatch) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.updateDescriptionLabel(to: "Finding best host")
            var players = match.players
            players.append(GKLocalPlayer.local)
            if let hostPlayer = players.sorted(by: { $0.alias > $1.alias }).first {
                self.publicRaceHostAlias = hostPlayer.alias
                if hostPlayer.alias == GKLocalPlayer.local.alias {
                    self.isPlayerHost = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                        self.publicRaceSendStartMessage()
                    })
                }
            } else {
                let info = "matchmaker...didFind: No host player"
                PlayerAnonymousMetrics.log(event: .error(info))
                PlayerAnonymousMetrics.log(event: .globalFailedToFindHost)
                self.showError(title: "Unable To Find Best Host",
                               message: "Please try again later.")
            }
        }
    }
    
}