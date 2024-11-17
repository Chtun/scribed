import PencilKit

// A struct to hold stroke data with timestamps
struct TimedStroke: Codable {
    let stroke_index: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
}

class TimedDrawing {
    
    // An array to hold timed strokes
    private var timedStrokes: [TimedStroke] = []
    
    init(timedS: [TimedStroke] = []) {
        timedStrokes = timedS
    }
    
    // Method to add a stroke with timestamps
    func addStrokeWithTimestamp(_ stroke_index: Int, startTime: TimeInterval, endTime: TimeInterval) {
        let timedStroke = TimedStroke(stroke_index: stroke_index, startTime: startTime, endTime: endTime)
        timedStrokes.append(timedStroke)
    }
    
    // Method to retrieve all timed strokes
    func getTimedStrokes() -> [TimedStroke] {
        return timedStrokes
    }
}
