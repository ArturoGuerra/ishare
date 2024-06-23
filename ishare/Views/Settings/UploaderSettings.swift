//
//  UploaderSettings.swift
//  ishare
//
//  Created by Adrian Castro on 15.07.23.
//  UI reworked by iGerman on 22.04.24.
//

import SwiftUI
import Defaults

struct UploaderSettingsView: View {
    @Default(.activeCustomUploader) var activeCustomUploader
    @Default(.savedCustomUploaders) var savedCustomUploaders
    @Default(.uploadType) var uploadType
    @Default(.aussieMode) var aussieMode
    
    @State private var isAddSheetPresented = false
    @State private var isImportSheetPresented = false
    
    var body: some View {
        VStack {
            if let uploaders = savedCustomUploaders {
                if (uploaders.isEmpty) {
                    HStack(alignment: .center) {
                        VStack {
                            Text("You have no saved uploaders")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                ForEach(uploaders.sorted(by: { $0.name < $1.name }), id: \.self) { uploader in
                    HStack {
                        Text(uploader.name)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Button(action: {
                            deleteCustomUploader(uploader)
                        }) {
                            Image(systemName: "trash")
                                .resizable()
                                .aspectRatio(contentMode: /*@START_MENU_TOKEN@*/.fill/*@END_MENU_TOKEN@*/)
                                .frame(width: 12, height: 12)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help("Delete Uploader")
                        
                        Button(action: {
                            testCustomUploader(uploader)
                        }) {
                            Image(systemName: "icloud.and.arrow.up")
                                .resizable()
                                .aspectRatio(contentMode: /*@START_MENU_TOKEN@*/.fill/*@END_MENU_TOKEN@*/)
                                .frame(width: 12, height: 12)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help("Test Uploader")
                        
                        Button(action: {
                            editCustomUploader(uploader) // Edit button added
                        }) {
                            Image(systemName: "pencil")
                                .resizable()
                                .aspectRatio(contentMode: /*@START_MENU_TOKEN@*/.fill/*@END_MENU_TOKEN@*/)
                                .frame(width: 12, height: 12)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help("Edit Uploader")
                        
                        Button(action: {
                            exportUploader(uploader) // Export button added
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .resizable()
                                .aspectRatio(contentMode: /*@START_MENU_TOKEN@*/.fill/*@END_MENU_TOKEN@*/)
                                .frame(width: 12, height: 12)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help("Export Uploader")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }.padding(.top)
            }
            
            Divider().padding(.horizontal)
            Spacer()
            
            HStack {
                Button(action: {
                    isAddSheetPresented.toggle()
                }) {
                    Text("Create")
                }
                .buttonStyle(DefaultButtonStyle())
                
                Button(action: {
                    isImportSheetPresented.toggle()
                }) {
                    Text("Import")
                }
                .buttonStyle(DefaultButtonStyle())
                
                Button(action: {
                    clearAllUploaders()
                }) {
                    Text("Clear All")
                        .foregroundColor(.red)
                }
                .buttonStyle(DefaultButtonStyle())
            }
            .padding(.bottom)
        }
        .rotationEffect(aussieMode ? .degrees(180) : .zero)
        .sheet(isPresented: $isAddSheetPresented) {
            AddCustomUploaderView()
                .frame(minWidth: 450)
        }
        .sheet(isPresented: $isImportSheetPresented) {
            ImportCustomUploaderView()
                .frame(minWidth: 350)
        }
    }
    
    private func deleteCustomUploader(_ uploader: CustomUploader) {
        guard var uploaders = savedCustomUploaders else { return }
        uploaders = uploaders.filter { $0.id != uploader.id }
        savedCustomUploaders = uploaders
        
        if uploader.id == activeCustomUploader {
            activeCustomUploader = nil
            uploadType = .IMGUR
        }
    }
    
    private func testCustomUploader(_ uploader: CustomUploader) {
        guard let iconImage = NSImage(named: NSImage.applicationIconName) else {
            print("Failed to get app icon image")
            return
        }

        guard let tiffData = iconImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            print("Failed to convert image to PNG data")
            return
        }

        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
        let fileURL = temporaryDirectory.appendingPathComponent("appIconImage.png")

        do {
            try pngData.write(to: fileURL)
        } catch {
            print("Failed to write image file: \(error)")
            return
        }

        let callback: ((Error?, URL?) -> Void) = { error, finalURL in
            if let error = error {
                print("Upload error: \(error)")
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.alertStyle = .critical
                    alert.messageText = "Upload Error"
                    alert.informativeText = "An error occurred during the upload process."
                    alert.runModal()
                }
            } else if let url = finalURL {
                print("Final URL: \(url)")
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.alertStyle = .informational
                    alert.messageText = "Upload Successful"
                    alert.informativeText = "The file was uploaded successfully."
                    alert.runModal()
                }
            }
        }

        customUpload(fileURL: fileURL, specification: uploader, callback: callback) {}

        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                print("Failed to delete temporary file: \(error)")
            }
        }
    }
    
    private func clearAllUploaders() {
        savedCustomUploaders = nil
        activeCustomUploader = nil
        uploadType = .IMGUR
    }
    
    private func editCustomUploader(_ uploader: CustomUploader) {
        isAddSheetPresented.toggle()
    }
    
    private func exportUploader(_ uploader: CustomUploader) {
        let data = try! JSONEncoder().encode(uploader)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.init(filenameExtension: "iscu")!]
        savePanel.nameFieldStringValue = "\(uploader.name).iscu"
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    try data.write(to: url)
                } catch {
                    print("Error exporting uploader: \(error)")
                }
            }
        }
    }
}

struct AddCustomUploaderView: View {
    @Environment(\.presentationMode) var presentationMode
    @Default(.savedCustomUploaders) var savedCustomUploaders
    
    @State private var uploaderName = ""
    @State private var requestURL = ""
    @State private var responseURL = ""
    @State private var deletionURL = ""
    @State private var fileFormName = ""
    @State private var header: [CustomEntryModel] = []
    @State private var formData: [CustomEntryModel] = []
    
    var body: some View {
        ScrollView {
            Text("Create Custom Uploader")
                .font(.title)
                .padding()
            Divider().padding(.horizontal)
            
            VStack(alignment: .leading) {
                Group {
                    InputField(label: "Name*", text: $uploaderName)
                    HStack{
                        InputField(label: "Request URL*", text: $requestURL)
                        InputField(label: "Response URL*", text: $responseURL)
                    }
                    HStack{
                        InputField(label: "Deletion URL", text: $deletionURL)
                        InputField(label: "File Form Name", text: $fileFormName)
                    }
                }
                .padding(.bottom)
                
                Divider().padding(.vertical)
                HeaderView()
                Divider().padding(.vertical)
                FormDataView()
                Divider().padding(.vertical)
                
                Text("*required").font(.footnote).frame(maxWidth: .infinity, alignment: .leading).opacity(0.5)
                
                Button(action: {
                    saveCustomUploader()
                }) {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                }
                .padding()
            }
            .padding()
        }
    }
    
    private struct InputField: View {
        let label: String
        @Binding var text: String
        
        var body: some View {
            VStack(alignment: .leading) {
                TextField(label, text: $text)
                    .padding(.top, 4)
            }
        }
    }
    
    
    private func HeaderView() -> some View {
        EntryListView(title: "Headers", entries: $header)
    }
    
    private func FormDataView() -> some View {
        EntryListView(title: "Form Data", entries: $formData)
    }
    
    struct EntryListView: View {
        let title: String
        @Binding var entries: [CustomEntryModel]
        
        var body: some View {
            Section(header: HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button(action: {
                    entries.append(CustomEntryModel(key: "", value: ""))
                }) {
                    Image(systemName: "plus")
                }
            }) {
                ForEach(entries) { entry in
                    if (entry == entries.last) {
                        CustomEntryView(entry: $entries[entries.firstIndex(of: entry)!])
                            .padding(.horizontal)
                    }
                }
                
                if (!entries.isEmpty) {
                    Divider()
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Name").frame(maxWidth: .infinity)
                        }
                        Divider()
                        VStack(alignment: .leading) {
                            Text("Value").frame(maxWidth: .infinity)
                        }
                        Button(action: {}) {
                            Image(systemName: "minus.circle")
                        }.opacity(0)
                            .disabled(/*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                    }
                    .frame(maxWidth: .infinity)
                    Divider()
                }
                
                ForEach(entries.indices, id: \.self) { index in
                    HStack {
                        VStack(alignment: .leading) {
                            Text((entries[index].key))
                                .padding(1)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .font(.system(.body, design: .monospaced))
                        }
                        Divider()
                        VStack(alignment: .leading) {
                            Text((entries[index].value))
                                .padding(1)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .font(.system(.body, design: .monospaced))
                        }
                        Button(action: {
                            entries.remove(at: index)
                        }) {
                            Image(systemName: "minus.circle").foregroundColor(.red)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    Rectangle()
                        .frame(width: .infinity, height: 1)
                        .opacity(0.1)
                        .padding(0)
                }
            }
        }
    }
    
    private func saveCustomUploader() {
        var headerData: [String: String] {
            return header.reduce(into: [String: String]()) { result, entry in
                result[entry.key] = entry.value
            }
        }
        
        var formDataModel: [String: String] {
            return formData.reduce(into: [String: String]()) { result, entry in
                result[entry.key] = entry.value
            }
        }
        
        let uploader = CustomUploader(
            name: uploaderName,
            requestURL: requestURL,
            headers: header.count == 0 ? nil : headerData,
            formData: formData.count == 0 ? nil : formDataModel,
            fileFormName: fileFormName.isEmpty ? nil : fileFormName,
            responseURL: responseURL,
            deletionURL: deletionURL.isEmpty ? nil : deletionURL
            
        )
        
        if var uploaders = savedCustomUploaders {
            uploaders.remove(uploader)
            uploaders.insert(uploader)
            savedCustomUploaders = uploaders
        } else {
            savedCustomUploaders = Set([uploader])
        }
        
        presentationMode.wrappedValue.dismiss()
    }
    
    private struct CustomEntryView: View {
        @Binding var entry: CustomEntryModel
        
        var body: some View {
            HStack {
                VStack(alignment: .leading) {
                    TextField("Name", text: $entry.key)
                }
                VStack(alignment: .leading) {
                    TextField("Value", text: $entry.value)
                }
            }
        }
    }
}

struct ImportCustomUploaderView: View {
    @Environment(\.presentationMode) var presentationMode
    @Default(.savedCustomUploaders) var savedCustomUploaders
    @Default(.activeCustomUploader) var activeCustomUploader
    @Default(.uploadType) var uploadType
    
    @State private var selectedFileURLs: [URL] = []
    @State private var importError: ImportError?
    
    func selectFile(completion: @escaping (URL?) -> Void) {
        let filePicker = NSOpenPanel()
        filePicker.canChooseDirectories = false
        filePicker.canChooseFiles = true
        filePicker.allowsMultipleSelection = false
        filePicker.canDownloadUbiquitousContents = true
        filePicker.canResolveUbiquitousConflicts = true
        
        filePicker.begin { response in
            if response == .OK {
                completion(filePicker.urls.first)
            } else {
                completion(nil)
            }
        }
    }
    
    var body: some View {
        VStack {
            Text("Import Custom Uploader")
                .font(.title)
            
            Divider()
            
            // Drag and Drop Receptacle
            RoundedRectangle(cornerRadius: 12)
                .frame(height: 150)
                .foregroundColor(.gray.opacity(0.2))
                .overlay(
                    VStack {
                        Image(systemName: "arrow.down.doc")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.gray)
                        Text("Drag and drop .iscu files here or click to select")
                            .foregroundColor(.gray)
                    }
                )
                .onTapGesture {
                    selectFile { fileURL in
                        if let url = fileURL {
                            selectedFileURLs.append(url)
                            importUploader()
                        }
                    }
                }
                .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
                    providers.first?.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                        if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                            DispatchQueue.main.async {
                                selectedFileURLs.append(url)
                                importUploader()
                            }
                        }
                    }
                    return true
                }
            
            if let fileURL = selectedFileURLs.first {
                Text("Selected File: \(fileURL.lastPathComponent)")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
        }
        .padding()
        .alert(item: $importError) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.localizedDescription),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func importUploader() {
        guard let fileURL = selectedFileURLs.first else { return }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let uploader = try decoder.decode(CustomUploader.self, from: data)
            
            if var uploaders = savedCustomUploaders {
                uploaders.remove(uploader)
                uploaders.insert(uploader)
                savedCustomUploaders = uploaders
            } else {
                savedCustomUploaders = Set([uploader])
            }
            
            activeCustomUploader = uploader.id
            uploadType = .CUSTOM
            presentationMode.wrappedValue.dismiss()
        } catch {
            importError = ImportError(error: error)
            print("Error importing custom uploader: \(error)")
            return
        }
        
        selectedFileURLs = []
        presentationMode.wrappedValue.dismiss()
    }
}

struct ImportError: Identifiable {
    let id = UUID()
    let error: Error
    
    var localizedDescription: String {
        error.localizedDescription
    }
}

struct CustomEntryModel: Identifiable, Equatable {
    let id = UUID()
    var key: String
    var value: String
}

#Preview {
    UploaderSettingsView()
}
