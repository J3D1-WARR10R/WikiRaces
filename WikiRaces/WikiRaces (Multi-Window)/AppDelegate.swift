//
//  AppDelegate.swift
//  WikiRaces (Multi-Window)
//
//  Created by Andrew Finke on 8/5/17.
//  Copyright © 2017 Andrew Finke. All rights reserved.
//

import UIKit
import WKRUIKit

@UIApplicationMain
internal class AppDelegate: WKRAppDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        configureConstants()

        window = WKRUIWindow(frame: UIScreen.main.bounds)
        let controller = ViewController()
        let nav = WKRUINavigationController(rootViewController: controller)
        nav.setNavigationBarHidden(true, animated: false)
        window?.rootViewController = nav
        window?.makeKeyAndVisible()
        return true
    }

}
