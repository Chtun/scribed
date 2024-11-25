import PencilKit

protocol TrackablePKCanvasViewDelegate: AnyObject {
    func penOrMouseDidGoDown()
}

class TrackablePKCanvasView: PKCanvasView {
    weak var trackableDelegate: TrackablePKCanvasViewDelegate?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        trackableDelegate?.penOrMouseDidGoDown() // Notify the delegate
    }
}
