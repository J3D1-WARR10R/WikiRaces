//
//  HelpViewController+KB.swift
//  WikiRaces
//
//  Created by Andrew Finke on 9/15/18.
//  Copyright © 2018 Andrew Finke. All rights reserved.
//

import UIKit

extension HelpViewController {

    // MARK: - Keyboard Support

    override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(keyboardClose))
        ]
    }

    @objc
    private func keyboardClose() {
        doneButtonPressed()
    }

}
