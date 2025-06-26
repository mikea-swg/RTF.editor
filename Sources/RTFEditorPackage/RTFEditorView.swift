//
//  RTFEditorView.swift
//  RTFEditor
//
//  Created by Josip Bernat on 10.06.2025..
//

import SwiftUI

public struct RTFEditorView: View {

    @Bindable var interactor: RichTextViewInteractor
    
    private var isInspectorVisible: Binding<Bool> {
        Binding {
            switch interactor.inspectorState {
            case .closed:
                return false
            case .image, .text:
                return true
            }
        } set: { newValue in
            
            if newValue == false {
                interactor.inspectorState = .closed
            } else {
                interactor.inspectorState = .text(attributes: interactor.textAttributes)
            }
        }
    }
    
    @State private var textInspectorContentHeight: CGFloat = 319.0
    
    @State private var documentName = "MyDocument"
    @State private var isImporting: Bool = false
    
    @State private var documentToExport: RTFDDocument?
    
    @State private var importError: Error?
    @State private var exportError: Error?
    
    //MARK: - Initialization

    /// Auto generated init isn't available.
    
    public init(interactor: RichTextViewInteractor) {
        self.interactor = interactor
    }
    
    //MARK: - Body
    
    public var body: some View {
        
        NavigationStack {
            
            RichTextViewRepresentable(interactor: interactor)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackgroundVisibility(.visible, for: .navigationBar)
                .toolbar {
                    
                    ToolbarItem(placement: .topBarLeading) {
                        
                        HStack {
                            importButton()
                            exportButton()
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        inspectorButton()
                    }
                }
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(Color.white, for: .navigationBar)
#if targetEnvironment(macCatalyst)
                .inspector(isPresented: isInspectorVisible) {
                    VStack(alignment: .leading, spacing: 0) {
                        inspectorContent()
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
#endif
                .alert("An error occurred while exporting document",
                       isPresented: Binding(get: { exportError != nil },
                                            set: { if $0 == false { exportError = nil }})) {
                    Button("OK") {}
                } message: {
                    if let exportError = exportError {
                        Text(exportError.localizedDescription)
                    }
                }
                .alert("An error occurred while importing document",
                       isPresented: Binding(get: { importError != nil },
                                            set: { if $0 == false { importError = nil }})) {
                    Button("OK") {}
                } message: {
                    if let importError = importError {
                        Text(importError.localizedDescription)
                    }
                }
        }
        .navigationTitle(documentName)
    }
    
    @ViewBuilder
    private func toolbarButton(icon: String, title: String) -> some View {
        
        VStack(spacing: 0) {
            
            Image(systemName: icon)
                .font(.system(size: 18))
            Text(title)
                .font(.caption)
            
            Spacer()
        }
        .foregroundColor(interactor.isTextViewFirstResponder ? .accentColor : .gray)
        .frame(minWidth: 60)
    }
    
    @ViewBuilder
    private func importButton() -> some View {
        
        Button {
            isImporting = true
        } label: {
            toolbarButton(icon: "square.and.arrow.down", title: "Import")
                .foregroundColor(.accentColor)
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.rtfdsl],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                
                do {
                    try interactor.loadRTFD(url: url)
                    documentName = url.lastPathComponent.replacingOccurrences(of: RichTextConstants.rtfdslExtension, with: "")
                } catch {
                    importError = error
                }
            case .failure(let error):
                print("File import error: \(error)")
                importError = error
            }
        }
        .help("Import")
    }
    
    @ViewBuilder
    private func exportButton() -> some View {
        
        Button {
            interactor.cleanupTempFiles(fileName: documentName)
            documentToExport = interactor.exportAsRTFDDocument()
        } label: {
            toolbarButton(icon: "square.and.arrow.up", title: "Export")
                .foregroundColor(.accentColor)
        }
        .help("Export")
        .fileExporter(
            isPresented: Binding(get: { documentToExport != nil },
                                 set: { if $0 == false { documentToExport = nil } }),
            document: documentToExport,
            contentType: .rtfdsl,
            defaultFilename: documentName
        ) { result in
            switch result {
            case .success(let url):
                print("Exported successfully to: \(url)")
            case .failure(let error):
                self.exportError = error
            }
        }
    }
    
    @ViewBuilder
    private func inspectorButton() -> some View {
        
        Button {
            switch interactor.inspectorState {
            case .closed:
                interactor.inspectorState = .text(attributes: interactor.textAttributes)
            default:
                interactor.inspectorState = .closed
            }
        } label: {
            toolbarButton(icon: "paintbrush", title: "Format")
                .foregroundColor(interactor.isTextViewFirstResponder ? .accentColor : .gray)
        }
        .help("Inspector")
        .disabled(!interactor.isTextViewFirstResponder)
        .tint(interactor.isTextViewFirstResponder ? .accentColor : .gray)
#if !targetEnvironment(macCatalyst)
        .popover(isPresented: isInspectorVisible) {
            inspectorContent()
        }
#endif
    }
    
    @ViewBuilder
    private func inspectorContent() -> some View {
        
        switch interactor.inspectorState {
        case .closed:
            EmptyView()
        case .image(let metadata):
            ImageInspectorView(metadata: metadata,
                               onMetadataChanged: { _ in
                interactor.updateImageMetadata(metadata)
            }, onDelete: { _ in
                interactor.deleteImageWithMetadata(metadata)
                interactor.inspectorState = .closed
            })
            .frame(minWidth: 350.0, maxWidth: .infinity)
#if !targetEnvironment(macCatalyst)
            .presentationDetents([.height(500)])
            .frame(height: 360)
            .background(Color(UIColor.systemGroupedBackground))
            .presentationDragIndicator(.visible)
#endif
        case .text(let attributes):
            NavigationStack {
                TextInspectorView(attributes: attributes,
                                  contentHeight: $textInspectorContentHeight) { attributes, insertNewList in
                    interactor.onTextAttributesChanged?(attributes, insertNewList)
                }
            }
#if !targetEnvironment(macCatalyst)
            .navigationTitle("Text")
            .presentationDetents([.height(textInspectorContentHeight)])
            .frame(height: textInspectorContentHeight)
            .background(Color(UIColor.systemGroupedBackground))
            .presentationDragIndicator(.visible)
#endif
            .frame(minWidth: 350.0, maxWidth: .infinity)
        }
    }
}

#Preview {
    RTFEditorView(interactor: RichTextViewInteractor(isEditable: true))
}
