import Foundation  
  
public class CanvasIdentifiedObject : CanvasObject {

    internal let id = UUID()

    // Object state; proceeds from top to bottom
    internal enum State : Int {
        case pendingTransmission   // Not yet transmitted
        case transmissionQueued    // Transmission queued for client
        case processedByClient     // Processed by client
        case resourceError         // Resource is not available on client
        case ready                 // Ready for use on client
    }
    private var state : State = .pendingTransmission
    
    internal func setupCommand() -> String {
        fatalError("setupCommand() invoked on CanvasIdentifiedObject")
    }

    internal func setState(_ newState:State) {
        if newState.rawValue <= state.rawValue {
            print("ERROR: State of object with id \(id) is regressing from \(state) to \(newState).")
        }
        state = newState
    }

    public var isReady : Bool {
        return state == .ready
    }

    public var isResourceError : Bool {
        return state == .resourceError
    }
    
}
