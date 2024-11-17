import PencilKit

class TimedDrawing {
    
    // A struct to hold stroke data with timestamps
    struct TimedStroke {
        let stroke: PKStroke
        let startTime: Date
        let endTime: Date
    }
    
    // The wrapped PKDrawing
    private(set) var drawing: PKDrawing
    
    // An array to hold timed strokes
    private var timedStrokes: [TimedStroke] = []
    
    init(drawing: PKDrawing = PKDrawing()) {
        self.drawing = drawing
    }
    
    // Method to add a stroke with timestamps
    func addStrokeWithTimestamp(_ stroke: PKStroke, startTime: Date, endTime: Date) {
        let timedStroke = TimedStroke(stroke: stroke, startTime: startTime, endTime: endTime)
        timedStrokes.append(timedStroke)
        drawing.strokes.append(stroke)
    }
    
    // Method to retrieve all timed strokes
    func getTimedStrokes() -> [TimedStroke] {
        return timedStrokes
    }
    
    // Update the wrapped PKDrawing
    func updateDrawing(_ newDrawing: PKDrawing) {
        self.drawing = newDrawing
    }
}
