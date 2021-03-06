import CoreData

/// A coordinator to handle the flow once the user is logged in
final class LoggedInCoordinator: Coordinator {
    private let database: WiltDatabase
    private let api: WiltAPI
    var navigationController: UINavigationController
    var childCoordinators = [Coordinator]()
    weak var delegate: LoggedInCoordinatorDelegate?
    // Will be non-nil if the settings page is being presented and nil when
    // not visible
    private var settingsController: UINavigationController?
    private var container: NSPersistentContainer?

    init(navigationController: UINavigationController, database: WiltDatabase,
         api: WiltAPI) {
        self.navigationController = navigationController
        self.database = database
        self.api = api
    }

    func start() {
        database.loadContext { [unowned self] in
            switch ($0) {
            case .success(let container):
                self.container = container
                let controller = MainAppViewController(
                    container: container,
                    api: self.api
                )
                controller.controllerDelegate = self
                self.navigationController.pushViewController(
                    controller,
                    animated: false
                )
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

    func dismiss() {
        navigationController.popViewController(animated: false)
        _ = childCoordinators.popLast()
    }

    private func clearCacheAndLogOut() {
        // Clear the caches so that we don't cache data of the wrong user once
        // we log back in
        clearCaches()
        delegate?.logOut()
    }

    /// Clear all the data that we've stored in Core Data
    private func clearCaches() {
        guard let container = container else {
            return
        }
        container.viewContext.performAndWait {
            let entities = container.managedObjectModel.entities
            for entity in entities {
                guard let name = entity.name else {
                    // Not sure what to do in this case
                    continue
                }
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(
                    entityName: name
                )
                let deleteRequest = NSBatchDeleteRequest(
                    fetchRequest: fetchRequest
                )
                // Ignore the error since I'm not sure what to do if it fails
                _ = try? container.persistentStoreCoordinator.execute(
                    deleteRequest,
                    with: container.viewContext
                )
            }
            _ = try? container.viewContext.save()
        }
    }
}

extension LoggedInCoordinator: MainAppViewControllerDelegate {
    func open(url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func showSettings() {
        let controller = SettingsViewController()
        controller.delegate = self
        let toPresent = UINavigationController(rootViewController: controller)
        toPresent.modalPresentationStyle = .popover
        settingsController = toPresent
        navigationController.present(
            toPresent,
            animated: true,
            completion: nil
        )
    }

    func loggedOut() {
        clearCacheAndLogOut()
    }
}

extension LoggedInCoordinator: SettingsViewControllerDelegate {
    func contactUs() {
        delegate?.contactUs()
    }

    private func closeSettings(animated: Bool = false,
                               completionHandler: @escaping () -> Void) {
        guard let controller = settingsController else { return }
        controller.dismiss(animated: animated, completion: completionHandler)
        settingsController = nil
    }

    func close() {
        closeSettings(animated: true) { }
    }

    func logOut() {
        closeSettings { [unowned self] in
            self.clearCacheAndLogOut()
        }
    }
}

/// Delegate for the `OnboardingCoordinator` for events that occur during
/// onboarding
protocol LoggedInCoordinatorDelegate: class {
    func contactUs()
    func logOut()
}
