//
//  WKRUIWebView.swift
//  WKRUIKit
//
//  Created by Andrew Finke on 8/5/17.
//  Copyright © 2017 Andrew Finke. All rights reserved.
//

import WebKit

final public class WKRUIWebView: WKWebView, WKScriptMessageHandler {

    // MARK: - Types -

    // WKScriptMessageHandler leaks due to a retain cycle
    private class ScriptMessageDelegate: NSObject, WKScriptMessageHandler {

        // MARK: - Properties -

        weak var delegate: WKScriptMessageHandler?

        // MARK: - Initalization -

        init(delegate: WKScriptMessageHandler) {
            self.delegate = delegate
            super.init()
        }

        // MARK: - WKScriptMessageHandler -

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            delegate?.userContentController(userContentController, didReceive: message)
        }
    }

    // MARK: - Properties -

    public var text: String? {
        set {
            linkCountLabel.text = newValue
        }
        get {
            return linkCountLabel.text
        }
    }

    private let linkCountLabel = UILabel()
    private let loadingView = UIView()

    public var progressView: WKRUIProgressView? {
        didSet {
            progressView?.isHidden = true
        }
    }

    public private(set) var pixelsScrolled = 0

    // network progress (fetch raw html) vs render progress (load html + images)
    private static let networkProgressWeight: Float = 0.7
    private var progressObservation: NSKeyValueObservation?
    public var networkProgress: Float = 0.0 {
        didSet {
            DispatchQueue.main.async {
                self.progressView?.setProgress(self.networkProgress * WKRUIWebView.networkProgressWeight,
                                               animated: true)
            }
        }
    }

    // MARK: - Initialization -

    public init() {
        guard let config = WKRUIWebView.raceConfig() else {
            fatalError("WKRWebView couldn't load raceConfig")
        }
        super.init(frame: .zero, configuration: config)

        let messageDelegate = ScriptMessageDelegate(delegate: self)
        config.userContentController.add(messageDelegate, name: "scrollY")

        isOpaque = false
        translatesAutoresizingMaskIntoConstraints = false

        allowsLinkPreview = false
        allowsBackForwardNavigationGestures = false
        
        scrollView.layer.masksToBounds = false

        let features: [[UIFontDescriptor.FeatureKey: Int]] = [
            [
                .featureIdentifier: kNumberSpacingType,
                .typeIdentifier: kMonospacedNumbersSelector
            ]
        ]
        let fontDescriptor = UIFont.systemFont(ofSize: 100, weight: .medium)
            .fontDescriptor
            .addingAttributes(
            [UIFontDescriptor.AttributeName.featureSettings: features]
        )

        loadingView.alpha = 0.0
        loadingView.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.5)
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(loadingView)

        linkCountLabel.text = "0"
        linkCountLabel.textColor = UIColor.white
        linkCountLabel.textAlignment = .center
        linkCountLabel.numberOfLines = 0

        linkCountLabel.adjustsFontSizeToFitWidth = true
        linkCountLabel.font = UIFont(descriptor: fontDescriptor, size: 100.0)
        linkCountLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingView.addSubview(linkCountLabel)

        scrollView.decelerationRate = UIScrollView.DecelerationRate.normal

        let constraints = [
            loadingView.topAnchor.constraint(equalTo: topAnchor),
            loadingView.bottomAnchor.constraint(equalTo: bottomAnchor),
            loadingView.leftAnchor.constraint(equalTo: leftAnchor),
            loadingView.rightAnchor.constraint(equalTo: rightAnchor),

            linkCountLabel.topAnchor.constraint(equalTo: loadingView.topAnchor),
            linkCountLabel.bottomAnchor.constraint(equalTo: loadingView.bottomAnchor),
            linkCountLabel.leftAnchor.constraint(equalTo: loadingView.leftAnchor),
            linkCountLabel.rightAnchor.constraint(equalTo: loadingView.rightAnchor)
        ]
        NSLayoutConstraint.activate(constraints)

        progressObservation = observe(\.estimatedProgress) { [weak self] webView, _ in
            DispatchQueue.main.async {
                let weight = WKRUIWebView.networkProgressWeight
                // network progress (would be weight * 1.0 since must be complete) + weighted webview progress
                let progress = weight + Float(webView.estimatedProgress) * (1 - weight)
                self?.progressView?.setProgress(progress, animated: true)
            }
        }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        progressObservation = nil
        NotificationCenter.default.removeObserver(self)
        configuration.userContentController.removeScriptMessageHandler(forName: "scrollY")
    }

    // MARK: - State Updates -

    @objc
    func keyboardWillShow() {
        resignFirstResponder()
        endEditing(true)
    }

    public func startedPageLoad() {
        progressView?.show()

        isUserInteractionEnabled = false

        let duration = WKRUIKitConstants.webViewAnimateOutDuration
        UIView.animate(withDuration: duration) {
            self.loadingView.alpha = 1.0
        }
    }

    public func completedPageLoad() {
        progressView?.hide()

        isUserInteractionEnabled = true
        let duration = WKRUIKitConstants.webViewAnimateInDuration

        UIView.animate(withDuration: duration, delay: 0.0, options: .beginFromCurrentState, animations: {
            self.loadingView.alpha = 0.0
        }, completion: nil)
    }

    // MARK: - Web View Configuration -

    private static func raceConfig() -> WKWebViewConfiguration? {
        let config = WKWebViewConfiguration()
        config.selectionGranularity = .character
        config.suppressesIncrementalRendering = false
        config.allowsAirPlayForMediaPlayback = false
        config.allowsPictureInPictureMediaPlayback = false
        config.dataDetectorTypes = []
        config.allowsInlineMediaPlayback = false
        config.mediaTypesRequiringUserActionForPlayback = .all

        let userContentController = WKUserContentController()

        WKContentRuleListStore.default()?
            .compileContentRuleList(forIdentifier: "WKRContentBlocker",
                                    encodedContentRuleList: WKRUIKitConstants.current.contentBlocker(),
                                    completionHandler: { (list, _) in
                                        guard let list = list else { return }
                                        userContentController.add(list)

            }
        )

        let startStyleScript = WKUserScript(source: WKRUIKitConstants.current.styleScript(),
                                            injectionTime: .atDocumentStart)
        let endStyleScript = WKUserScript(source: WKRUIKitConstants.current.styleScript(),
                                            injectionTime: .atDocumentEnd)
        let cleanScript = WKUserScript(source: WKRUIKitConstants.current.cleanScript(),
                                          injectionTime: .atDocumentEnd)

        userContentController.addUserScript(startStyleScript)
        userContentController.addUserScript(endStyleScript)
        userContentController.addUserScript(cleanScript)

        config.userContentController = userContentController
        return config
    }

    // MARK: - WKScriptMessageHandler -

    public func userContentController(_ userContentController: WKUserContentController,
                                      didReceive message: WKScriptMessage) {
        guard let messageBody = message.body as? Int else { return }
        switch message.name {
        case "scrollY":
            pixelsScrolled += messageBody
        default: return
        }
    }

}
