import SwiftUI
import AVFoundation
import Defaults

struct ToastPopoverView: View {
    let thumbnailImage: NSImage
    let fileURL: URL
    @Default(.saveToDisk) var saveToDisk
    @State private var isDragging = false

    var body: some View {
        Image(nsImage: thumbnailImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
            .foregroundColor(Color(NSColor.labelColor))
            .cornerRadius(10)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .animation(Animation.easeInOut(duration: 1.0), value: thumbnailImage)
            .opacity(isDragging ? 0 : 1)
            .onTapGesture {
                if saveToDisk {
                    NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: "")
                }
            }
            .onDrag {
                self.isDragging = true
                let itemProvider = NSItemProvider(object: fileURL as NSURL)
                itemProvider.suggestedName = fileURL.lastPathComponent
                return itemProvider
            }
            .onDrop(of: [UTType.url], isTargeted: nil) { providers -> Bool in
                self.isDragging = false
                return true
            }
    }
}

func showToast(fileURL: URL, completion: (() -> Void)? = nil) {
    var thumbnailImage: NSImage?
    
    if fileURL.pathExtension == "mov" || fileURL.pathExtension == "mp4" {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVURLAsset(url: fileURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: 2, preferredTimescale: 60)
            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                thumbnailImage = NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
            } catch {
                print("Error generating thumbnail: \(error)")
            }
            
            // Show the toast on the main thread after thumbnail generation is complete.
            DispatchQueue.main.async {
                showThumbnailAndToast(fileURL: fileURL, thumbnailImage: thumbnailImage, completion: completion)
            }
        }
    } else {
        // For images, proceed directly to showing the toast without generating the thumbnail.
        showThumbnailAndToast(fileURL: fileURL, thumbnailImage: NSImage(contentsOf: fileURL), completion: completion)
    }
}

func showThumbnailAndToast(fileURL: URL, thumbnailImage: NSImage?, completion: (() -> Void)?) {
    @Default(.toastTimeout) var toastTimeout
    
    guard let thumbnail = thumbnailImage else {
        return
    }
    
    let toastWindow = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 250, height: 150),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    
    toastWindow.level = .floating
    toastWindow.isOpaque = false
    toastWindow.backgroundColor = .clear
    toastWindow.isMovableByWindowBackground = true
    toastWindow.contentView = NSHostingView(
        rootView: ToastPopoverView(thumbnailImage: thumbnail, fileURL: fileURL)
    )
    
    toastWindow.makeKeyAndOrderFront(nil)
    let screenSize = NSScreen.main?.frame.size ?? .zero
    let originX = screenSize.width - toastWindow.frame.width - 20
    let originY = screenSize.height - toastWindow.frame.height - 20
    toastWindow.setFrameOrigin(NSPoint(x: originX, y: originY))
    
    let fadeDuration = 0.2
    toastWindow.alphaValue = 0.0
    
    NSAnimationContext.runAnimationGroup({ context in
        context.duration = fadeDuration
        toastWindow.animator().alphaValue = 1.0
    }) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Int(toastTimeout))) {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = fadeDuration
                toastWindow.animator().alphaValue = 0.0
            }) {
                toastWindow.orderOut(nil)
                completion?()
            }
        }
    }
}
