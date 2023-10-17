//
//  PDFKitRepresentView.swift
//  AviaBriefingTCA
//
//  Created by Аня Воронцова on 14.10.2023.
//

import SwiftUI
import PDFKit
import ComposableArchitecture

struct PDFKitRepresentedView: UIViewRepresentable {
    let docURL: URL
    @Binding var pageNum: Int
    
    func makeUIView(context: UIViewRepresentableContext<PDFKitRepresentedView>) -> PDFView {
        let pdfView = PDFView()
        let document = PDFDocument(url: docURL)
        pdfView.document = document
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: UIViewRepresentableContext<PDFKitRepresentedView>) {
        if let thePage = uiView.document?.page(at: pageNum) {
            print("going to page \(pageNum)")
            uiView.go(to: thePage)
        }
    }
}
