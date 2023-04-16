import Foundation
import NIO

public class Canvas {

    public static let instance : Canvas!

    private static let minimumSecondsBeforePing = 15
    private static var nextCanvasId : Int = 0
    private let painter : PainterProtocol
    private var pendingCommandList = [String]()
    private var identifiedObjectDictionary = [UUID:CanvasIdentifiedObject]()
    private var mostRecentPingTime = Date()

    public let canvasId : Int
    public private(set) var canvasSize : Size? = nil
    public private(set) var windowSize : Size? = nil
    
    internal init(painter:PainterProtocol) {
        self.instance = self

        // Assign ID.  Potentially conflict if two threads enter simultaneously?
        self.canvasId = Canvas.nextCanvasId
        Canvas.nextCanvasId += 1
        
        self.painter = painter
    }

    /*

        So yeah I decided that passing an instance of the canvas
        through an inherited function every time you'd want to
        render somethnig to the screen was doo-doo, so instead,
        Canvas is now a singleton and every CanvasObject will 
        have a built-in render function which should just forward 
        the command string data to this class to be sent to the 
        WebSocketHandler.

        Example of usage:
        Rect(
            position: .point(200, 200),
            size: .size(50, 50)
        ).render(self)
                 ^ This is your layer instance.

    */

    public func render(_ canvasObjects:[CanvasObject]) {
        for canvasObject in canvasObjects {
            let command = canvasObject.canvasCommand()
            pendingCommandList.append(command)
        }
    }

    public func render(_ canvasObjects:CanvasObject...) {
        render(canvasObjects)
    }

    public func setup(_ canvasIdentifiedObjects:[CanvasIdentifiedObject]) {
        for canvasIdentifiedObject in canvasIdentifiedObjects {
            identifiedObjectDictionary[canvasIdentifiedObject.id] = canvasIdentifiedObject
            
            let command = canvasIdentifiedObject.setupCommand()
            pendingCommandList.append(command)
            
            canvasIdentifiedObject.setState(.transmissionQueued)
        }
    }

    public func setup(_ canvasIdentifiedObjects:CanvasIdentifiedObject...) {
        setup(canvasIdentifiedObjects)
    }

    public func canvasSetSize(size:Size) {
        let command = "canvasSetSize|\(size.width)|\(size.height)"
        pendingCommandList.append(command)
    }

    public func displayStatistics(_ displayStatistics:Bool = true) {
        let command = "displayStatistics|\(displayStatistics)"
        pendingCommandList.append(command)
    }

    // MARK: ********** Internal **********

    // In some cases we need integers from strings but some browsers transmit doubles
    internal func intFromDoubleString(_ s:String) -> Int? {
        if let d = Double(s) {
            return Int(d)
        } else {
            return nil
        }
    }
    
    internal func processCommands(context: ChannelHandlerContext, webSocketHandler:WebSocketHandler) {
        if pendingCommandList.count > 0 {
            let allCommands = pendingCommandList.joined(separator:"||")
            webSocketHandler.send(context: context, text:allCommands)
            pendingCommandList.removeAll()
        } else {
            let secondsSincePreviousPing = -Int(mostRecentPingTime.timeIntervalSinceNow)
            if (secondsSincePreviousPing > Canvas.minimumSecondsBeforePing) {
                webSocketHandler.send(context: context, text:"ping")
                mostRecentPingTime = Date()
            }
        }
    }
    
    internal func ready(context: ChannelHandlerContext, webSocketHandler:WebSocketHandler) {
        painter.setup(canvas:self)
        processCommands(context: context, webSocketHandler:webSocketHandler)
    }

    internal func recurring(context: ChannelHandlerContext, webSocketHandler:WebSocketHandler) {
        painter.calculate(canvasId:self.canvasId, canvasSize:canvasSize)
        painter.render(canvas:self)
        processCommands(context: context, webSocketHandler:webSocketHandler)
    }

    internal func reception(context: ChannelHandlerContext, webSocketHandler:WebSocketHandler, text:String) {
        var commandAndArguments = text.components(separatedBy:"|")
        if commandAndArguments.count > 0 {
            let command = commandAndArguments.removeFirst()
            let arguments = commandAndArguments
            switch (command) {
                // Mouse events
            case "onClick":
                receptionOnClick(arguments:arguments)
            case "onMouseDown":
                receptionOnMouseDown(arguments:arguments)
            case "onMouseUp":
                receptionOnMouseUp(arguments:arguments)
            case "onWindowMouseUp":
                receptionOnWindowMouseUp(arguments:arguments)
            case "onMouseMove":
                receptionOnMouseMove(arguments:arguments)

                // Key events
            case "onKeyDown":
                receptionOnKeyDown(arguments:arguments)
            case "onKeyUp":
                receptionOnKeyUp(arguments:arguments)

                // IdentifiedObject events
            case "onImageError", "onAudioError":
                receptionOnIdentifiedObjectError(arguments:arguments)
            case "onImageLoaded", "onAudioLoaded",
                 "onLinearGradientLoaded", "onRadialGradientLoaded",
                 "onPatternLoaded", "onTextMetricLoaded":
                receptionOnIdentifiedObjectLoaded(arguments:arguments)
            case "onImageProcessed", "onAudioProcessed",
                 "onLinearGradientProcessed", "onRadialGradientProcessed",
                 "onPatternProcessed", "onTextMetricProcessed":
                receptionOnIdentifiedObjectProcessed(arguments:arguments)

                // Text events
            case "onTextMetricReady":
                receptionOnTextMetricReady(arguments:arguments)

                // Resize events
            case "onCanvasResize":
                receptionOnCanvasResize(arguments:arguments)
            case "onWindowResize":
                receptionOnWindowResize(arguments:arguments)
            default:
                print("ERROR: Unknown command received: \(command)")
            }
        }
    }

    // ***** MARK: Event reception (mouse and keyboard) *****
    internal func receptionOnClick(arguments:[String]) {
        // In some cases (from some browsers) a Double is received
        guard arguments.count == 2,
              let x = intFromDoubleString(arguments[0]),
              let y = intFromDoubleString(arguments[1]) else {
            print("ERROR: onClick requires exactly two integer or double arguments")
            return
        }
        painter.onClick(location:Point(x:x, y:y))
    }

    internal func receptionOnMouseDown(arguments:[String]) {
        guard arguments.count == 2,
              let x = intFromDoubleString(arguments[0]),
              let y = intFromDoubleString(arguments[1]) else {
            print("ERROR: onMouseDown requires exactly two integer or double arguments")
            return
        }
        painter.onMouseDown(location:Point(x:x, y:y))
    }

    internal func receptionOnMouseUp(arguments:[String]) {
        guard arguments.count == 2,
              let x = intFromDoubleString(arguments[0]),
              let y = intFromDoubleString(arguments[1]) else {
            print("ERROR: onMouseUp requires exactly two integer or double arguments")
            return
        }
        painter.onMouseUp(location:Point(x:x, y:y))
    }

    internal func receptionOnWindowMouseUp(arguments:[String]) {
        guard arguments.count == 2,
              let x = intFromDoubleString(arguments[0]),
              let y = intFromDoubleString(arguments[1]) else {
            print("ERROR: onWindowMouseUp requires exactly two integer or double arguments")
            return
        }
        painter.onWindowMouseUp(location:Point(x:x, y:y))
    }

    internal func receptionOnMouseMove(arguments:[String]) {
        guard arguments.count == 2,
              let x = intFromDoubleString(arguments[0]),
              let y = intFromDoubleString(arguments[1]) else {
            print("ERROR: onMouseMove requires exactly two integer or double arguments")
            return
        }
        painter.onMouseMove(location:Point(x:x, y:y))
    }

    internal func receptionOnKeyDown(arguments:[String]) {
        guard arguments.count == 6,
              let ctrlKey = Bool(arguments[2]),
              let shiftKey = Bool(arguments[3]),
              let altKey = Bool(arguments[4]),
              let metaKey = Bool(arguments[5]) else {
            print("ERROR: onKeyDown requires exactly six arguments (String, String, Bool, Bool, Bool, Bool)")
            return
        }
        let key = arguments[0]
        let code = arguments[1]
        
        painter.onKeyDown(key:key, code:code, ctrlKey:ctrlKey, shiftKey:shiftKey, altKey:altKey, metaKey:metaKey)
    }

    internal func receptionOnKeyUp(arguments:[String]) {
        guard arguments.count == 6,
              let ctrlKey = Bool(arguments[2]),
              let shiftKey = Bool(arguments[3]),
              let altKey = Bool(arguments[4]),
              let metaKey = Bool(arguments[5]) else {
            print("ERROR: onKeyUp requires exactly six arguments (String, String, Bool, Bool, Bool, Bool)")
            return
        }
        let key = arguments[0]
        let code = arguments[1]

        painter.onKeyUp(key:key, code:code, ctrlKey:ctrlKey, shiftKey:shiftKey, altKey:altKey, metaKey:metaKey)
    }

    // ***** MARK: IdentifiedObject handling *****
    internal func getIdentifiedObject(arguments:[String]) -> CanvasIdentifiedObject? {
        guard arguments.count == 1,
              let id = UUID(uuidString:arguments[0]) else {
            print("ERROR: getIdentifiedObject: requires exactly one argument which must be a valid UUID.")
            return nil
        }
        
        guard let identifiedObject = identifiedObjectDictionary[id] else {
            print("ERROR: getIdentifiedObject: Object with id \(id.uuidString) was not found.")
            return nil
        }

        return identifiedObject
    }

    internal func receptionOnIdentifiedObjectError(arguments:[String]) {
        if let identifiedObject = getIdentifiedObject(arguments:arguments) {
            identifiedObject.setState(.resourceError)
        }
    }

    internal func receptionOnIdentifiedObjectLoaded(arguments:[String]) {
        if let identifiedObject = getIdentifiedObject(arguments:arguments) {
            identifiedObject.setState(.ready)
        }
    }

    internal func receptionOnIdentifiedObjectProcessed(arguments:[String]) {
        if let identifiedObject = getIdentifiedObject(arguments:arguments) {
            identifiedObject.setState(.processedByClient)
        }
    }

    internal func receptionOnTextMetricReady(arguments:[String]) {
        guard arguments.count == 13 else {
            print("ERROR: receptionOnTextMetricReady requires exactly 13 arguments")
            return
        }

        guard let id = UUID(uuidString:arguments[0]) else {
            print("ERROR: receptionOnTextMetricReady argument 1 must be a UUID")
            return
        }

        guard let width                     = Double(arguments[ 1]),
              let actualBoundingBoxLeft     = Double(arguments[ 2]),
              let actualBoundingBoxRight    = Double(arguments[ 3]),
              let actualBoundingBoxAscent   = Double(arguments[ 6]),
              let actualBoundingBoxDescent  = Double(arguments[ 7])
        else {
            print("ERROR: receptionOnTextMetricReady arguments (width, actualBoundBoxLeft/Right, actualBoundingBoxAscent/Descent must be Doubles")
            return
        }

        // The following are not yet available in all browswers
        let fontBoundingBoxAscent     = Double(arguments[ 4])
        let fontBoundingBoxDescent    = Double(arguments[ 5])
        let emHeightAscent            = Double(arguments[ 8])
        let emHeightDescent           = Double(arguments[ 9])
        let hangingBaseline           = Double(arguments[10])
        let alphabeticBaseline        = Double(arguments[11])
        let ideographicBaseline       = Double(arguments[12])

        let metrics = TextMetric.Metrics(
          width: width,
          actualBoundingBoxLeft: actualBoundingBoxLeft,
          actualBoundingBoxRight: actualBoundingBoxRight,
          fontBoundingBoxAscent: fontBoundingBoxAscent,
          fontBoundingBoxDescent: fontBoundingBoxDescent,
          actualBoundingBoxAscent: actualBoundingBoxAscent,
          actualBoundingBoxDescent: actualBoundingBoxDescent,
          emHeightAscent: emHeightAscent,
          emHeightDescent: emHeightDescent,
          hangingBaseline: hangingBaseline,
          alphabeticBaseline: alphabeticBaseline,
          ideographicBaseline: ideographicBaseline)

        guard let identifiedObject = identifiedObjectDictionary[id] else {
            print("ERROR: receptionOnTextMetricReady: Object with id \(id.uuidString) was not found.")
            return
        }
        
        guard let textMetric = identifiedObject as? TextMetric else {
            print("ERROR: receptionOnTextMetricReady: Object with id \(id.uuidString) is not a TextMetric object.")
            return
        }

        textMetric.setMetrics(metrics:metrics)
    }

    // ***** MARK: canvas/window resize events *****
    internal func receptionOnCanvasResize(arguments:[String]) {
        guard arguments.count == 2,
              let width = Double(arguments[0]),
              let height = Double(arguments[1]) else {
            print("ERROR: onCanvasResize requires exactly two double arguments")
            return
        }
        canvasSize = Size(width:Int(width), height:Int(height))
        painter.onCanvasResize(size:canvasSize!);
    }
    
    internal func receptionOnWindowResize(arguments:[String]) {
        guard arguments.count == 2,
              let width = Double(arguments[0]),
              let height = Double(arguments[1]) else {
            print("ERROR: onWindowResize requires exactly two double arguments")
            return
        }
        windowSize = Size(width:Int(width), height:Int(height))
        painter.onWindowResize(size:windowSize!)
    }
    
    internal func nextRecurringInterval() -> TimeAmount {
        let framesPerSecond = painter.framesPerSecond()
        let intervalInSeconds = 1.0 / Double(framesPerSecond)
        let intervalInMilliSeconds = Int64(intervalInSeconds * 1_000)
        return .milliseconds(intervalInMilliSeconds)
    }
}