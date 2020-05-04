//
//  CustomRacePageViewController.swift
//  WikiRaces
//
//  Created by Andrew Finke on 5/3/20.
//  Copyright © 2020 Andrew Finke. All rights reserved.
//

import UIKit
import WKRKit

final class CustomRacePageViewController: UITableViewController {

    // MARK: - Types -

    enum PageType {
        case start, end, banned

        var isMultipleSelectionAllowed: Bool {
            return self == .banned
        }
    }

    // MARK: - Properties -

    let pageType: PageType

    var customPages: [WKRPage]
    var indexPathsOfSelectedOptions: Set<IndexPath> = []

    var didUpdateStartPage: ((WKRGameSettings.StartPage) -> Void)?
    var didUpdateEndPage: ((WKRGameSettings.EndPage) -> Void)?
    var didUpdateBannedPages: (([WKRGameSettings.BannedPage]) -> Void)?

    // MARK: - Initalization -

    //swiftlint:disable:next cyclomatic_complexity function_body_length
    init(pageType: PageType, customPages: [WKRPage], selectedOption: Any) {
        self.pageType = pageType

        self.customPages = customPages
        if customPages.isEmpty {

            guard let appleURL = URL(string: "https://en.m.wikipedia.org/wiki/Apple_Inc."),
                let usaURL = URL(string: "https://en.m.wikipedia.org/wiki/United_States."),
                let waltURL = URL(string: "https://en.m.wikipedia.org/wiki/Walt_Disney") else {
                    fatalError()
            }

            self.customPages.append(contentsOf: [
                WKRPage(title: "Apple Inc", url: appleURL),
                WKRPage(title: "United States", url: usaURL),
                WKRPage(title: "Walt Disney", url: waltURL)
            ])
        }

        super.init(style: .grouped)

        switch pageType {
        case .start:
            title = "Start Page"
            guard let page = selectedOption as? WKRGameSettings.StartPage else { fatalError() }
            switch page {
            case .random:
                select(indexPath: IndexPath(row: 0, section: 0))
            case .custom(let customPage):
                guard let index = customPages.firstIndex(where: { page -> Bool in
                    return customPage == page
                }) else { fatalError() }
                select(indexPath: IndexPath(row: index, section: 1))
            }
        case .end:
            title = "End Page"
            guard let page = selectedOption as? WKRGameSettings.EndPage else { fatalError() }
            switch page {
            case .curatedVoting:
                select(indexPath: IndexPath(row: 0, section: 0))
            case .randomVoting:
                select(indexPath: IndexPath(row: 1, section: 0))
            case .custom(let customPage):
                guard let index = customPages.firstIndex(where: { page -> Bool in
                    return customPage == page
                }) else { fatalError() }
                select(indexPath: IndexPath(row: index, section: 1))
            }
        case .banned:
            title = "Banned Pages"
            guard let pages = selectedOption as? [WKRGameSettings.BannedPage] else { fatalError() }
            for page in pages {
                switch page {
                case .portal:
                    select(indexPath: IndexPath(row: 0, section: 0))
                case .custom(let customPage):
                    guard let index = customPages.firstIndex(where: { page -> Bool in
                        return customPage == page
                    }) else { fatalError() }
                    select(indexPath: IndexPath(row: index, section: 1))
                }
            }
        }

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UITableViewDataSource -

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return pageType == .end ? 2 : 1
        } else {
            return customPages.count + 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)

        if indexPath.section == 0 {
            if indexPath.row == 0 {
                switch pageType {
                case .start:
                    cell.textLabel?.text = "Random"
                case .end:
                    cell.textLabel?.text = "Curated + Voting"
                case .banned:
                    cell.textLabel?.text = "Portal Pages"
                }
            } else if indexPath.row == 1 {
                cell.textLabel?.text = "Random + Voting"
            }
        } else {
            if indexPath.row == customPages.count {
                cell.textLabel?.text = "Add Page"
                cell.textLabel?.textColor = cell.tintColor
            } else {
                let customPage = customPages[indexPath.row]
                cell.textLabel?.text = customPage.title
                cell.detailTextLabel?.text = customPage.path
            }
        }

        if indexPathsOfSelectedOptions.contains(indexPath) {
            cell.accessoryType = .checkmark
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 && indexPath.row == customPages.count {
            let controller = UIAlertController(title: "Enter Page Name", message: "", preferredStyle: .alert)
            controller.addTextField { textField in
                textField.placeholder = "Page Title"
            }

            let confirmAction = UIAlertAction(title: "Ok", style: .default) { [weak controller] _ in
                guard let controller = controller, let text = controller.textFields?.first?.text else { return }

                guard let path = ("/" + text).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
                    self.failedToAdd(pageTitle: text)
                    return
                }
                WKRPageFetcher.fetch(path: path, useCache: true) { (page, _) in
                    if let page = page {
                        DispatchQueue.main.async {
                            tableView.deselectRow(at: IndexPath(row: self.customPages.count, section: 1),
                                                  animated: true)
                            self.customPages.append(page)
                            tableView.insertRows(at: [IndexPath(row: self.customPages.count - 1, section: 1)],
                                                 with: .automatic)
                        }
                    } else {
                        self.failedToAdd(pageTitle: text)
                    }
                }
            }
            controller.addAction(confirmAction)

            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            controller.addAction(cancelAction)

            present(controller, animated: true, completion: nil)
        } else {
            tableView.deselectRow(at: indexPath, animated: true)
            select(indexPath: indexPath)
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Standard" : "Custom"
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let str = "Stats Effect: Prevents setting new fastest race records."
        return section == 1 && pageType == .start ? str : nil
    }

    // MARK: - Helpers -

    private func select(indexPath: IndexPath) {
        if pageType.isMultipleSelectionAllowed {
            if indexPathsOfSelectedOptions.contains(indexPath) {
                tableView.cellForRow(at: indexPath)?.accessoryType = .none
                indexPathsOfSelectedOptions.remove(indexPath)
            } else {
                tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
                indexPathsOfSelectedOptions.insert(indexPath)
            }
            var pages = [WKRGameSettings.BannedPage]()
            for indexPath in indexPathsOfSelectedOptions.sorted() {
                let page: WKRGameSettings.BannedPage
                if indexPath.row == 0 && indexPath.section == 0 {
                    page = .portal
                } else {
                    page = .custom(customPages[indexPath.row])
                }
                pages.append(page)
            }
            didUpdateBannedPages?(pages)
        } else {
            if let first = indexPathsOfSelectedOptions.first {
                tableView.cellForRow(at: first)?.accessoryType = .none
                indexPathsOfSelectedOptions.removeAll()
            }
            tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
            indexPathsOfSelectedOptions.insert(indexPath)

            if pageType == .start {
                let page: WKRGameSettings.StartPage
                if indexPath.row == 0 && indexPath.section == 0 {
                    page = .random
                } else {
                    page = .custom(customPages[indexPath.row])
                }
                didUpdateStartPage?(page)
            } else {
                let page: WKRGameSettings.EndPage
                if indexPath.row == 0 && indexPath.section == 0 {
                    page = .curatedVoting
                } else if indexPath.row == 1 && indexPath.section == 0 {
                    page = .randomVoting
                } else {
                    page = .custom(customPages[indexPath.row])
                }
                didUpdateEndPage?(page)
            }
        }
    }

    private func failedToAdd(pageTitle: String) {
        DispatchQueue.main.async {
            let controller = UIAlertController(
                title: "An error occured",
                message: "Failed to find a page titled \"\(pageTitle)\"",
                preferredStyle: .alert)
            controller.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            self.present(controller, animated: true, completion: nil)
            self.tableView.deselectRow(at: IndexPath(row: self.customPages.count, section: 1), animated: true)
        }
    }

}
