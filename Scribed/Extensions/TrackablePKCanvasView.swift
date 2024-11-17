import PencilKit

protocol TrackablePKCanvasViewDelegate: AnyObject {
    func penOrMouseDidGoDown()
}

class TrackablePKCanvasView: PKCanvasView {
    weak var trackableDelegate: TrackablePKCanvasViewDelegate?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        print("Pen or mouse went down at \(Date())")
        trackableDelegate?.penOrMouseDidGoDown() // Notify the delegate
    }
}
