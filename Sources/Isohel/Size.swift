public struct Size {

    typealias Pair = (_ width: Int, _ height: Int)

    public var width : Int!
    public var height : Int!

    init()

}


public class Layer {

    typealias Pair<T, U> = (_ : T, _ : U)

    class Pair<T, U> {
        let first: T
        let second: U
        
        init(first: T, second: U) {
            self.first = first
            self.second = second
        }
    }

}

public class Background : Layer {

    var r = Rect(size: (100, 100))

}