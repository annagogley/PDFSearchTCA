//
//  PDFSearch.swift
//  AviaBriefingTCA
//
//  Created by Аня Воронцова on 14.10.2023.
//

import Foundation
import ComposableArchitecture
import PDFKit
import Combine

struct PDFSearch: Reducer {
    private enum CancelID {case cancel}
    let clock = ContinuousClock()

    var body: some ReducerOf<PDFSearch> {
        Reduce { state, action in
            switch action {
            case .update:
                state.updateEnabled = true
                state.isSheetPresented = false
                return .send(.stopSearch)
            case .searchTextChanged(let newText):
                state.isLoading = true
                state.textForSearch = newText
                guard !newText.isEmpty else {
                    return .none
                }
                state.isSheetPresented = true
                return .none
            case .stopSearch:
                state.isLoading = false
                return .none
            case .search:
                let pdf = state.pdf!
                let query = state.textForSearch
                guard !query.isEmpty else {
//                    return .send(.stopSearch)
                    return .none
                }
                state.searchResult = []
                
                let searchResults = pdf.findString(query, withOptions: .caseInsensitive)
                guard !searchResults.isEmpty else {
                    print("search results are empty")
//                    return .send(.stopSearch)
                    return .none
                }
                print(searchResults)
                for result in searchResults {
                    for page in result.pages {
                        let pagePic = page.thumbnail(of: CGSize(width: 50, height: 80), for: .mediaBox)
                        if Int(page.label!) != state.searchResult.last?.pageNumber {
                            state.searchResult.append(PDFSearch.State.Page(pagePic: pagePic, pageNumber: Int(page.label!) ?? 0))
                        }
                    }
                }
//                return .run { send in
//                    await send(.stopSearch)
//                }
                return .send(.stopSearch)
            case .setSheet(isPresented: let isPresented):
                state.isSheetPresented = isPresented
                return .none
            case .goToPage(let page):
                state.textForSearch = ""
                state.isSheetPresented = false
                state.currentPage = page - 1
                return .none
            }
        }
    }
    
    
    enum Action: Equatable {
        case update
        case searchTextChanged(String)
        case stopSearch
        case search
        case setSheet(isPresented: Bool)
        case goToPage(Int)
    }
    
    struct State: Equatable {
        var docURL: URL = Bundle.main.url(forResource: "A320-Part3", withExtension: "pdf")!
        var pdf = PDFDocument(url: Bundle.main.url(forResource: "A320-Part3", withExtension: "pdf")!)
        var textForSearch: String = ""
        var searchResult: [Page] = []
        var updateEnabled: Bool = false
        var isSheetPresented: Bool = false
        var isLoading: Bool = false
        var currentPage = 720
        
        struct Page: Equatable, Hashable {
            var pagePic: UIImage
            var pageNumber: Int
        }
    }
}
