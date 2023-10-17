//
//  AviaBriefingTCAApp.swift
//  AviaBriefingTCA
//
//  Created by Аня Воронцова on 14.10.2023.
//

import SwiftUI
import ComposableArchitecture

@main
struct AviaBriefingTCAApp: App {
    var body: some Scene {
        WindowGroup {
            PDFSearchView(
                store: Store(initialState: PDFSearch.State(), reducer: {
                    PDFSearch()._printChanges()
                }))
        }
    }
}
