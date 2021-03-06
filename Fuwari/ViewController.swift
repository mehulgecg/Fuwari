//
//  ViewController.swift
//  Fuwari
//
//  Created by Kengo Yokoyama on 2016/11/29.
//  Copyright © 2016年 AppKnop. All rights reserved.
//

import Cocoa
import Quartz

class ViewController: NSViewController {

    private var windowControllers = [NSWindowController]()
    private var fullScreenWindows = [FullScreenWindow]()
    private var isCancelled = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NSScreen.screens.forEach {
            let fullScreenWindow = FullScreenWindow(contentRect: $0.frame, styleMask: .borderless, backing: .buffered, defer: false)
            fullScreenWindow.captureDelegate = self
            fullScreenWindows.append(fullScreenWindow)
            let controller = NSWindowController(window: fullScreenWindow)
            controller.showWindow(nil)
            windowControllers.append(controller)
            fullScreenWindow.orderOut(nil)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(startCapture), name: Notification.Name(rawValue: Constants.Notification.capture), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name(rawValue: Constants.Notification.capture), object: nil)
    }
    
    private func createFloatWindow(rect: NSRect, image: CGImage) {
        let floatWindow = FloatWindow(contentRect: rect, image: image)
        floatWindow.floatDelegate = self
        let floatWindowController = NSWindowController(window: floatWindow)
        floatWindowController.showWindow(nil)
        windowControllers.append(floatWindowController)
    }
    
    @objc private func startCapture() {
        NSCursor.hide()
        StateManager.shared.isCapturing = true
        fullScreenWindows.forEach { $0.startCapture() }
    }
}

extension ViewController: CaptureDelegate {
    func didCaptured(rect: NSRect, image: CGImage) {
        createFloatWindow(rect: rect, image: image)
        NSCursor.unhide()
        StateManager.shared.isCapturing = false
        fullScreenWindows.forEach { $0.orderOut(nil) }
        isCancelled = false
    }
    
    func didCanceled() {
        NSCursor.unhide()
        StateManager.shared.isCapturing = false
        isCancelled = true
        fullScreenWindows.forEach { $0.orderOut(nil) }
    }
}

extension ViewController: FloatDelegate {
    func close(floatWindow: FloatWindow) {
        if !isCancelled {
            if windowControllers.filter({ $0.window === floatWindow }).first != nil {
                floatWindow.fadeWindow(isIn: false) {
                    floatWindow.close()
                }
            }
        }
        isCancelled = false
    }

    func save(floatWindow: FloatWindow, image: CGImage) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.nameFieldStringValue = "screenshot-\(formatter.string(from: Date()))"
        savePanel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.modalPanelWindow)))
        let saveOptions = IKSaveOptions(imageProperties: [:], imageUTType: kUTTypePNG as String?)
        saveOptions?.addAccessoryView(to: savePanel)
        
        let result = savePanel.runModal()
        if result == .OK {
            if let url = savePanel.url as CFURL?, let type = saveOptions?.imageUTType as CFString? {
                guard let destination = CGImageDestinationCreateWithURL(url, type, 1, nil) else { return }
                CGImageDestinationAddImage(destination, image, saveOptions!.imageProperties! as CFDictionary)
                CGImageDestinationFinalize(destination)
            }
        }
    }
}
