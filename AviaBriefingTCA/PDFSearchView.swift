//
//  PDFSearchView.swift
//  AviaBriefingTCA
//
//  Created by Аня Воронцова on 14.10.2023.
//

import SwiftUI
import ComposableArchitecture
import Combine
import PDFKit

struct PDFSearchView: View {
    let store: StoreOf<PDFSearch>

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            VStack {
                TextField(
                    "Search in PDF",
                    text: viewStore.binding(
                        get: \.textForSearch,
                        send: { .searchTextChanged($0)})
                )
                .padding(.all)
                Button {
                    viewStore.send(.update)
                } label: {
                    Text("Update")
                        .background(Rectangle().frame(width: 350, height: 50).foregroundColor(.red).cornerRadius(10))
                        .foregroundColor(.white)
                        .font(.bold(.body)())
                }
                .padding(.all)
                
                ZStack {
                    if viewStore.isSheetPresented {
                        Group {
                            ZStack {
                                SearchResultView(store: store)
                            }
                        }
                    } else {
                        Group {
//                            viewStore.updateEnabled ? AnyView(PDFKitRepresentedView(docURL: viewStore.docURL, pageNum: viewStore.binding(get: \.currentPage, send: { .goToPage($0) }))) : AnyView(Spacer())
                            PDFKitRepresentedView(docURL: viewStore.docURL, pageNum: viewStore.binding(get: \.currentPage, send: { .goToPage($0) }))
                            
                        }
                    }
                    if viewStore.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .id(UUID())
                    }
                }
            }
            .padding()
            .task(id: viewStore.textForSearch) {
                do {
                  try await Task.sleep(for: .seconds(1))
                    await viewStore.send(.search).finish()
                } catch {}
            }
        }
    }
}

struct SearchResultView: View {
    let store: StoreOf<PDFSearch>
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            List {
                ForEach(viewStore.searchResult, id: \.self) { result in
                    HStack {
                        Image(uiImage: result.pagePic)
                        Text("page № \(result.pageNumber)")
                    }
                    .onTapGesture {
                        print("tap to \(result.pageNumber)")
                        viewStore.send(.goToPage(result.pageNumber))
                    }
                }
            }
        }
    }
}

struct PDFSearchView_Previews: PreviewProvider {
    static var previews: some View {
        PDFSearchView(
            store: Store(initialState: PDFSearch.State(),
                         reducer: {
                             PDFSearch()
                         }
                        )
        )
//        SearchView(
//            store: Store(initialState: PDFSearch.State(),
//                         reducer: {
//                             PDFSearch()
//                         }
//            )
//        )
    }
}
