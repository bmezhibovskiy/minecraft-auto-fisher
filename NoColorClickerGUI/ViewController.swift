//
//  ViewController.swift
//  NoColorClickerGUI
//
//  Created by Boris Mezhibovskiy on 6/29/22.
//

import Cocoa
import ApplicationServices
import AppKit
import Quartz

class ViewController: NSViewController {

    var debug = false
    var running = false
    var clicking = false

    var dEvent: CGEvent?
    var uEvent: CGEvent?
    var sound: NSSound!

    var wid: CGWindowID!

    var overlayController: OverlayWindowController?

    var currentImage: CGImage?

    //fishing rod line has black pixels
    let colorToFind: [CGFloat] = [0, 0, 0]

    let screenshotSize: CGFloat = 85
    var screenshotCGRect: CGRect {
        let x = (NSScreen.main!.visibleFrame.width - screenshotSize)/CGFloat(2)
        let y = (NSScreen.main!.visibleFrame.height - screenshotSize)/CGFloat(3)
        return CGRect(x: x, y: y, width: screenshotSize, height: screenshotSize)
    }
    var screenshotNSRect: NSRect {
        let cgRect = screenshotCGRect
        let height = NSScreen.main!.visibleFrame.height
        let pad: CGFloat = OverlayWindowController.thickBorderWidth/2
        let vOffset: CGFloat = 12 + pad*2
        return NSRect(x: (cgRect.minX)-pad, y: (height-cgRect.minY-vOffset)+pad, width: cgRect.width+2*pad+1, height: cgRect.height+2*pad+1)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        sound = NSSound(named: "Tink")!
        playDebugSound()
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 50 { //` to start/stop running
                self.running = !self.running
            }
        }

        overlayController = self.storyboard?
            .instantiateController(withIdentifier: "OverlayWindowController") as? OverlayWindowController
        overlayController?.window?.level = .init(rawValue: Int(CGShieldingWindowLevel()) + 1)
        overlayController?.window?.isOpaque = false
        overlayController?.window?.backgroundColor = .clear
        overlayController?.window?.setFrame(screenshotNSRect, display: true)

        overlayController?.showWindow(self)
        self.start()
    }


    func playDebugSound() {
        guard debug else { return }
        sound.stop()
        sound.play()
    }
    func cgFloat(_ theFloat: CGFloat, isCloseTo otherFloat: CGFloat, epsilon: CGFloat = 0.006) -> Bool {
        guard theFloat != otherFloat else { return true }
        return otherFloat > theFloat - epsilon &&
        otherFloat < theFloat + epsilon
    }

    func findColor(r: CGFloat, g: CGFloat, b: CGFloat, in image: CGImage) -> Bool {
        let pixelsWide = Int(image.width)
        let pixelsHigh = Int(image.height)

        guard let pixelData = image.dataProvider?.data else { return false }
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)

        for x in 0..<pixelsWide {
            for y in 0..<pixelsHigh {
                let point = CGPoint(x: x, y: y)
                let pixelInfo: Int = ((pixelsWide * Int(point.y)) + Int(point.x)) * 4
                if cgFloat(b, isCloseTo: CGFloat(data[pixelInfo]) / 255.0),
                   cgFloat(g, isCloseTo: CGFloat(data[pixelInfo + 1]) / 255.0),
                   cgFloat(r, isCloseTo: CGFloat(data[pixelInfo + 2]) / 255.0) {
                    return true
                }
            }
        }
        return false
    }

    func colorFound() -> Bool {
        self.currentImage = CGDisplayCreateImage(CGMainDisplayID(), rect: screenshotCGRect)
        if let image = currentImage {
            let colorFound = findColor(r: self.colorToFind[0],
                                       g: self.colorToFind[1],
                                       b: self.colorToFind[2],
                                       in: image)
            if colorFound {
                return true
            }
        }
        return false
    }

    func start() {
        let didFindColor = colorFound()
        overlayController?.greenBorder = didFindColor
        overlayController?.thickBorder = running
        if running && !clicking && !didFindColor {
            doClick()
        }
        DispatchQueue.main.asyncAfter(deadline: .now()+0.2) {
            self.start()
        }
    }

    func doClick(clickAgain: Bool = true) {
        clicking = true
        self.dEvent = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, mouseCursorPosition: NSEvent.mouseLocation, mouseButton: .right)
        self.uEvent = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, mouseCursorPosition: NSEvent.mouseLocation, mouseButton: .right)

        self.dEvent!.post(tap: .cghidEventTap)
        DispatchQueue.main.async {
            self.uEvent!.post(tap: .cghidEventTap)
            if clickAgain {
                DispatchQueue.main.asyncAfter(deadline: .now()+1) {
                    self.doClick(clickAgain: false)
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now()+2) {
                    self.clicking = false
                }
            }
        }
    }
}

