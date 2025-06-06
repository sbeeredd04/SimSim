//
//  simsimApp.swift
//  simsim
//
//  Created by Sri Ujjwal Reddy B on 6/5/25.
//

import SwiftUI
import CoreData

@main
struct simsimApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
