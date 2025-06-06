import CoreData

class PersistenceController {
    static let shared = PersistenceController() // Singleton instance

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // Initialize the container with the name of our Core Data model file
        container = NSPersistentContainer(name: "PhotoDataModel")

        // If inMemory is true, the data will not be persisted to disk
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // Handle the error appropriately in a real app
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        // Automatically merge changes from other contexts to this context
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Configure the view context to merge conflicts automatically
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Core Data Saving support
    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                // Handle the error appropriately in a real app
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    // Create a background context for operations that shouldn't block the UI
    func backgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
}