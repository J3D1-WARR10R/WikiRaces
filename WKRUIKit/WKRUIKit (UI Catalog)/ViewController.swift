//
//  ViewController.swift
//  WKRUIKit (UI Catalog)
//
//  Created by Andrew Finke on 8/5/17.
//  Copyright © 2017 Andrew Finke. All rights reserved.
//

import UIKit
import WKRUIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let webView = WKRUIWebView()
        view = webView
        webView.load(URLRequest(url: URL(string: "https://en.m.wikipedia.org/wiki/Apple")!))
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
