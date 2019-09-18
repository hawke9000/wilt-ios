import Foundation
import CoreData

/// Once logged in, the main app will revolve around this controller and
/// different tabs will be used to navigate
class MainAppViewController: UITabBarController {
    weak var controllerDelegate: MainAppViewControllerDelegate?
    private var tabs = [(controller: UIViewController, title: String)]()

    /// Create the main app controller
    ///
    /// - Parameters:
    ///   - database: Where data should be persisted
    ///   - api: Where data should be requested from
    init(database: WiltDatabase, api: WiltAPI) {
        super.init(nibName: nil, bundle: nil)
        delegate = self
        database.loadContext { [unowned self] in
            switch ($0) {
            case .success(let container):
                do {
                    try self.setupTabs(
                        container: container,
                        api: api
                    )
                } catch {
                    // This is most likely a developer error that means the
                    // cache is broken with no option of recovery
                    fatalError("Unexpected error setting up app: \(error)")
                }
            case .failure(let error):
                // This error might be recoverable, eg. if the device is out
                // of disk space. However, it's unlikely that clearing the
                // cache would free up enough space and I'm not sure whether
                // the user would care if we displayed an alert an exit vs
                // just exiting
                fatalError("Unexpected Core Data error: \(error)")
                break
            }
        }
    }

    private func setupFeedController(container: NSPersistentContainer,
                                     api: WiltAPI) throws -> FeedViewController {
        let viewModel = FeedViewModel(
            dao: try PlayHistoryCache(viewContext: container.viewContext),
            api: api
        )
        viewModel.delegate = self
        let feedViewController = FeedViewController(viewModel: viewModel)
        feedViewController.tabBarItem = UITabBarItem(
            tabBarSystemItem: .recents,
            tag: 1
        )
        return feedViewController
    }

    private func setupProfileController(container: NSPersistentContainer,
                                        api: WiltAPI) -> ProfileViewController {
        let cache = ProfileCache(
            backgroundContext: container.newBackgroundContext(),
            networkAPI: api
        )
        let controller = ProfileViewController(
            viewModel: ProfileViewModel(api: cache)
        )
        controller.tabBarItem = UITabBarItem(
            tabBarSystemItem: .contacts,
            tag: 0
        )
        return controller
    }

    private func setupTabs(container: NSPersistentContainer,
                           api: WiltAPI) throws {
        tabs = [
            (
                controller: setupProfileController(
                    container: container,
                    api: api
                ),
                title: "profile_title".localized
            ),
            (
                controller: try setupFeedController(
                    container: container,
                    api: api
                ),
                title: "feed_title".localized
            ),
        ]
        title = tabs[0].title
        viewControllers = tabs.map { $0.controller }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        view.backgroundColor = .white
    }
}

extension MainAppViewController: UITabBarControllerDelegate {
    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard item.tag < tabs.count else {
            title = "Wilt"
            return
        }
        title = tabs[item.tag].title
    }
}

extension MainAppViewController: FeedViewModelDelegate {
    func loggedOut() {
        controllerDelegate?.loggedOut()
    }
}

/// Delegate for the `MainAppViewController` for events that occur in the
/// main app
protocol MainAppViewControllerDelegate: class {
    func loggedOut()
}
