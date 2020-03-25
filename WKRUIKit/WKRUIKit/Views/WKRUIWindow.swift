//
//  WKRWindow.swift
//  WikiRaces
//
//  Created by Andrew Finke on 9/25/19.
//  Copyright © 2019 Andrew Finke. All rights reserved.
//

import UIKit

public class WKRUIWindow: UIWindow {
    override public func layoutSubviews() {
        super.layoutSubviews()
        backgroundColor = .wkrBackgroundColor(for: traitCollection)
    }
}
