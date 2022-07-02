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

    var running = false
    var clicking = false

    var dEvent: CGEvent?
    var uEvent: CGEvent?
    var overlayController: OverlayWindowController?

    var currentImage: CGImage?

    //fishing rod line has black pixels
    let colorToFind: [CGFloat] = [0, 0, 0]

    let checkDelay: TimeInterval = 0.1
    let clickDelay: TimeInterval = 1.0
    let resetDelay: TimeInterval = 2.0

    var mouseLoc: CGPoint {
        let loc = NSEvent.mouseLocation
        let screenHeight = NSScreen.main!.frame.height
        //Flip the coordinate system for the mouse click events
        return CGPoint(x: loc.x, y: screenHeight - loc.y)
    }

    let screenshotSize: CGFloat = 85
    var displaySpaceRect: CGRect {
        let x = (NSScreen.main!.visibleFrame.width - screenshotSize)/CGFloat(2)
        let y = (NSScreen.main!.visibleFrame.height - screenshotSize)/CGFloat(3)
        return CGRect(x: x, y: y, width: screenshotSize, height: screenshotSize)
    }
    var screenSpaceRectWithPadding: NSRect {
        let cgRect = convertDisplaySpaceRectToScreenSpace(displaySpaceRect)
        let pad = OverlayWindowController.thickBorderWidth
        return NSRect(x: cgRect.minX-pad, y: cgRect.minY-pad, width: cgRect.width+2*pad, height: cgRect.height+2*pad)
    }
    func convertDisplaySpaceRectToScreenSpace(_ rect: CGRect) -> CGRect {
        let screenFrame = NSScreen.main!.visibleFrame
        return CGRect(x: rect.minX, y: screenFrame.height-rect.minY-(screenFrame.minY/4), width: rect.width+1, height: rect.height+1)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        overlayController = self.storyboard?
            .instantiateController(withIdentifier: "OverlayWindowController") as? OverlayWindowController
        overlayController?.window?.level = .init(rawValue: Int(CGShieldingWindowLevel()) + 1)
        overlayController?.window?.isOpaque = false
        overlayController?.window?.backgroundColor = .clear
        overlayController?.window?.setFrame(screenSpaceRectWithPadding, display: true)
        overlayController?.showWindow(self)

        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 50 { //` to start/stop running
                self.running = !self.running
            }
        }

        self.runColorCheck()
    }

    func cgFloat(_ theFloat: CGFloat, isCloseTo otherFloat: CGFloat, epsilon: CGFloat = 0.004) -> Bool {
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

    func doesColorExist() -> Bool {
        self.currentImage = CGDisplayCreateImage(CGMainDisplayID(), rect: displaySpaceRect)
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

    func runColorCheck() {
        let foundColor = doesColorExist()
        overlayController?.greenBorder = foundColor
        overlayController?.thickBorder = running
        if running && !clicking && !foundColor {
            doClick()
        }
        DispatchQueue.main.asyncAfter(deadline: .now()+checkDelay) {
            self.runColorCheck()
        }
    }

    func doClick(clickAgain: Bool = true) {
        clicking = true
        self.dEvent = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, mouseCursorPosition: mouseLoc, mouseButton: .right)
        self.uEvent = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, mouseCursorPosition: mouseLoc, mouseButton: .right)

        self.dEvent!.post(tap: .cghidEventTap)
        DispatchQueue.main.async {
            self.uEvent!.post(tap: .cghidEventTap)
            if clickAgain {
                DispatchQueue.main.asyncAfter(deadline: .now()+self.clickDelay) {
                    self.doClick(clickAgain: false)
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now()+self.resetDelay) {
                    self.clicking = false
                }
            }
        }
    }
}

