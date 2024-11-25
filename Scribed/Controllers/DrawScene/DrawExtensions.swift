//
//  DrawExtensions.swift
//  Jottre
//
//  Created by Anton Lorani on 16.01.21.
//

import Foundation
import PencilKit

extension DrawViewController {

    func reloadNavigationItems() {
        
        navigationItem.hidesBackButton = hasModifiedDrawing
        
        if hasModifiedDrawing {
            
            navigationItem.setLeftBarButton(UIBarButtonItem(customView: NavigationTextButton(title: NSLocalizedString("Save", comment: "Save the document"), target: self, action: #selector(self.writeDrawingHandler))), animated: true)
            
        } else {
            
            navigationItem.leftBarButtonItem = nil
            
            if isUndoEnabled {
            
                let spaceButton = UIBarButtonItem(customView: SpaceButtonBarItem())
                undoButton = UIBarButtonItem(customView: UndoButton(target: self, action: #selector(undoHandler)))
                redoButton = UIBarButtonItem(customView: RedoButton(target: self, action: #selector(redoHandler)))
                
                navigationItem.leftItemsSupplementBackButton = true
                navigationItem.setLeftBarButtonItems([spaceButton, undoButton, redoButton], animated: true)
            
                guard let undoManager = canvasView.undoManager else {
                    return
                }
                
                undoButton.isEnabled = undoManager.canUndo
                redoButton.isEnabled = undoManager.canRedo
                
            } else {
                
                navigationItem.setLeftBarButtonItems(nil, animated: true)
            
            }
            
        }
        
    }
    
    
    @objc func undoHandler() {
        canvasView.undoManager?.undo()
        reloadNavigationItems()
    }
    
    
    @objc func redoHandler() {
        canvasView.undoManager?.redo()
        reloadNavigationItems()
    }
    
}

extension PKStrokePath {
    func shortest_distance(_ point: CGPoint) -> Float {
        var smallest_distance = Float(1000000)
        for t in stride(from: 0.0, to: CGFloat(self.count), by: 0.01) { // Adjust stride for finer precision
            let pathPoint = interpolatedPoint(at: CGFloat(t))
            var distance = Float(abs(pathPoint.location.x - point.x) + abs(pathPoint.location.y - point.y))
            if distance < smallest_distance {
                smallest_distance = distance
            }
        }
        return smallest_distance
    }
}

extension DrawViewController: PKCanvasViewDelegate, TrackablePKCanvasViewDelegate {
    
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        
        guard !IsViewingMode else { return }
        
        // Update content size and navigation items
        updateContentSizeForDrawing()
        reloadNavigationItems()
        
        
        if modifiedCount == 1 {
            hasModifiedDrawing = true
        } else {
            modifiedCount += 1
        }
        
        // Only capture the last stroke while drawing
        let lastStrokeIndex = canvasView.drawing.strokes.count - 1
        guard lastStrokeIndex >= 0 else { return } // Ensure there is at least one stroke

        print("Stroke updated.")
        
        guard let startTime = currentStrokeStartTime else { return }
        
        let relativeStartTime = startTime.timeIntervalSince(self.startTime ?? Date())
        let relativeEndTime = Date().timeIntervalSince(self.startTime ?? Date())
        
        // Add stroke and timestamp to TimedDrawing
        timedDrawing.addStrokeWithTimestamp(
            lastStrokeIndex,
            startTime: relativeStartTime,
            endTime: relativeEndTime
        )
        
        // Log the stroke
        logTimedStrokes()
        
        // Reset stroke-related variables
        currentStrokeStartTime = nil
    }
    
    func penOrMouseDidGoDown() {
        currentStrokeStartTime = Date()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
            guard IsViewingMode, let touch = touches.first else { return } // Only process touches in viewing mode
            let locationInCanvas = touch.location(in: canvasView)
            
            // Transform the location to match the drawing's coordinate system
            let adjustedLocation = CGPoint(
                x: (locationInCanvas.x + canvasView.contentOffset.x) / canvasView.zoomScale,
                y: (locationInCanvas.y + canvasView.contentOffset.y + canvasView.adjustedContentInset.top) / canvasView.zoomScale
            )
            
            if let strokeIndex = getTappedStrokeIndex(from: canvasView.drawing, at: adjustedLocation) {
                handleStrokeSelection(at: strokeIndex)
            }
    }

    
    func getTappedStrokeIndex(from drawing: PKDrawing, at location: CGPoint, tolerance: CGFloat = 20) -> Int? {
        var shortest_distance = Float(tolerance) + 1
        var shortest_index = -1
        for (index, stroke) in drawing.strokes.enumerated() {
            var distance = stroke.path.shortest_distance(location)
            if distance < Float(tolerance) && distance < shortest_distance {
                shortest_index = index
                shortest_distance = distance
            }
        }
        
        if shortest_index == -1 {
            return nil
        }
        else
        {
            return shortest_index
        }
    }
    
    func handleStrokeSelection(at index: Int) {
        print("Selected Stroke at index: \(index)")
        
        handleStrokeDeselection(at: viewedStrokeIndex)
        
        if index == viewedStrokeIndex {
            viewedStrokeIndex = nil
            return
        }
                
        
        viewedStrokeIndex = index
        highlightStroke(at: index)
        
        // Find the time stroke that corresponds to this stroke index.
        let timedStrokes = self.timedDrawing.getTimedStrokes()
        
        for timedStroke in timedStrokes
        {
            if timedStroke.stroke_index == index
            {
                let secondsToSubtract: TimeInterval = 2
                var playbackTime = timedStroke.startTime - secondsToSubtract
                
                if (playbackTime < 0)
                {
                    playbackTime = TimeInterval(0)
                }
                
                // Once you find the time stroke, set the audio to the given second.
                currentAudioPlayerView?.setAudioPlayback(time: playbackTime)
            }
        }
    }
    
    func handleStrokeDeselection(at index: Int?)
    {
        if index != nil {
            var ind = index ?? -1
            dehighlightStroke(at: ind)
        }
    }

    func highlightStroke(at index: Int) {
        guard index < canvasView.drawing.strokes.count else { return }
        
        var drawing = canvasView.drawing
        let stroke = drawing.strokes[index]
        
        // Create a highlighted stroke
        let highlightedStroke = PKStroke(
            ink: PKInk(.pen, color: .red), // Highlight in red
            path: stroke.path
        )
        
        // Replace the selected stroke with the highlighted one
        drawing.strokes[index] = highlightedStroke
        canvasView.drawing = drawing
    }
    
    func dehighlightStroke(at index: Int) {
        guard index < canvasView.drawing.strokes.count else { return }
        
        var drawing = canvasView.drawing
        let stroke = drawing.strokes[index]
        
        // Create a highlighted stroke
        let highlightedStroke = PKStroke(
            ink: PKInk(.pen, color: .black), // Highlight in black
            path: stroke.path
        )
        
        // Replace the selected stroke with the highlighted one
        drawing.strokes[index] = highlightedStroke
        canvasView.drawing = drawing
    }
}


extension DrawViewController: UIScreenshotServiceDelegate {
    
    func startLoading() {
        toolPicker.setVisible(false, forFirstResponder: canvasView)
        canvasView.isUserInteractionEnabled = false
        loadingView.isAnimating = true
    }
    
    func stopLoading() {
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        canvasView.isUserInteractionEnabled = true
        loadingView.isAnimating = false
    }
    
    func drawingToPDF(_ completion: @escaping (_ PDFData: Data?, _ indexOfCurrentPage: Int, _ rectInCurrentPage: CGRect) -> Void) {
        
        let drawing = canvasView.drawing
            
        let visibleRect = canvasView.bounds
                
        let pdfWidth: CGFloat = node.codable!.width
        let pdfHeight = drawing.bounds.maxY + 100
        let canvasContentSize = canvasView.contentSize.height
                
        let xOffsetInPDF = pdfWidth - (pdfWidth * visibleRect.minX / canvasView.contentSize.width)
        let yOffsetInPDF = pdfHeight - (pdfHeight * visibleRect.maxY / canvasContentSize)
        let rectWidthInPDF = pdfWidth * visibleRect.width / canvasView.contentSize.width
        let rectHeightInPDF = pdfHeight * visibleRect.height / canvasContentSize
            
        let visibleRectInPDF = CGRect(x: xOffsetInPDF, y: yOffsetInPDF, width: rectWidthInPDF, height: rectHeightInPDF)
            
        DispatchQueue.global(qos: .background).async {
                    
            let bounds = CGRect(x: 0, y: 0, width: pdfWidth, height: pdfHeight)
            let mutableData = NSMutableData()
                    
            UIGraphicsBeginPDFContextToData(mutableData, bounds, nil)
            UIGraphicsBeginPDFPage()
                    
            var yOrigin: CGFloat = 0
            let imageHeight: CGFloat = 1024
            while yOrigin < bounds.maxY {
                let imageBounds = CGRect(x: 0, y: yOrigin, width: pdfWidth, height: min(imageHeight, bounds.maxY - yOrigin))
                let img = drawing.image(from: imageBounds, scale: 2, userInterfaceStyle: .light)
                img.draw(in: imageBounds)
                yOrigin += imageHeight                
            }
                    
            UIGraphicsEndPDFContext()
                    
            completion(mutableData as Data, 0, visibleRectInPDF)
            
        }
        
    }
    
    func screenshotService(_ screenshotService: UIScreenshotService, generatePDFRepresentationWithCompletion completion: @escaping (_ PDFData: Data?, _ indexOfCurrentPage: Int, _ rectInCurrentPage: CGRect) -> Void) {
        
        drawingToPDF { (data, indexOfCurrentPage, rectInCurrentPage) in
            completion(data, indexOfCurrentPage, rectInCurrentPage)
        }
            
    }
    
}


extension DrawViewController: PKToolPickerObserver {
    
    func toolPickerFramesObscuredDidChange(_ toolPicker: PKToolPicker) {
        updateLayout(for: toolPicker)
    }
    
    func toolPickerVisibilityDidChange(_ toolPicker: PKToolPicker) {
        updateLayout(for: toolPicker)
    }
        
    
    func updateLayout(for toolPicker: PKToolPicker) {
        let obscuredFrame = toolPicker.frameObscured(in: view)
        
        if obscuredFrame.isNull {
            canvasView.contentInset = .zero
        } else {
            canvasView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: view.bounds.maxX - obscuredFrame.minY, right: 0)
        }
        
        canvasView.scrollIndicatorInsets = canvasView.contentInset
        
        if isUndoEnabled != !obscuredFrame.isNull {
            isUndoEnabled = !obscuredFrame.isNull
            reloadNavigationItems()
        }
        
    }
    
}
