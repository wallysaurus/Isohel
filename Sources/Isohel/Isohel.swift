import Foundation
import Dispatch
import NIO
import NIOHTTP1
import NIOWebSocket

/*

    The main point of this class was to initialize the directory path for the
    websocket website that igis feeds info to. It also provided a backup path
    for CoderMerlin shells that imported the library using a dylib.manifest
    file.

    oh yeah.. and it also initializes the websocket, its thread, and canvas...

    Because Isohel isn't supported by TheCoderMerlin, CoderMerlin users will
    be forced to manually import the library locally, and a lot of the
    original code here won't be needed.

*/

public class Isohel {
    let resourcePath : String!
    let resourceDirectory : URL!
    let localHost : String!
    let localPort : Int!

    public init(resourcePath:String?=nil, localHost:String?=nil, localPort:Int?=nil) {
        guard resourcePath != nil else {
            fatalError("resourcePath not specified.")
        }
        self.resourcePath = resourcePath
        self.resourceDirectory = URL(fileURLWithPath:self.resourcePath.expandingTildeInPath, isDirectory:true)

        // we can still use the same ip/port as igis. nothing really changes here.
        self.localHost = localHost ?? ProcessInfo.processInfo.environment["IGIS_LOCAL_HOST"]
        guard self.localHost != nil else {
            fatalError("localHost not specified and environment variable 'IGIS_LOCAL_HOST' not set")
        }

        self.localPort = localPort ?? Int(ProcessInfo.processInfo.environment["IGIS_LOCAL_PORT"] ?? "")
        guard self.localPort != nil else {
            fatalError("localPort not specified and environment variable 'IGIS_LOCAL_PORT' not set or invalid")
        }
    }

    public func run(painterType:PainterProtocol.Type) throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        let upgrader = NIOWebSocketServerUpgrader(shouldUpgrade: {  (channel: Channel, head: HTTPRequestHead) in channel.eventLoop.makeSucceededFuture(HTTPHeaders()) },
                                                  upgradePipelineHandler: { (channel: Channel, _: HTTPRequestHead) in
                                                      return channel.pipeline.addHandler(WebSocketHandler(canvas:Canvas(painter:painterType.init())))
                                                  })

        let bootstrap = ServerBootstrap(group: group)
        // Specify backlog and enable SO_REUSEADDR for the server itself
          .serverChannelOption(ChannelOptions.backlog, value: 256)
          .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)

        // Set the handlers that are applied to the accepted Channels
          .childChannelInitializer { channel in
              let httpHandler = HTTPHandler(resourceDirectory:self.resourceDirectory)
              let config: NIOHTTPServerUpgradeConfiguration = (
                upgraders: [ upgrader ], 
                completionHandler: { _ in 
                    channel.pipeline.removeHandler(httpHandler, promise: nil)
                }
              )
              return channel.pipeline.configureHTTPServerPipeline(withServerUpgrade: config).flatMap {
                  channel.pipeline.addHandler(httpHandler)
              }
          }

        // Enable TCP_NODELAY and SO_REUSEADDR for the accepted Channels
          .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
          .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)

        defer {
            try! group.syncShutdownGracefully()
        }
        let channel = try { () -> Channel in
            return try bootstrap.bind(host: localHost, port: localPort).wait()
        }()

        guard let localAddress = channel.localAddress else {
            fatalError("Address was unable to bind. Please check that the socket was not closed or that the address family was understood.")
        }

        if !Self.isMerlinMissionManagerMode() {
            print("Server started and listening on \(localAddress)")
        }

        // This will never unblock as we don't close the ServerChannel
        try channel.closeFuture.wait()
    }

}