import Foundation

struct Console {

  public func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let string = items.map({ String(describing: $0) }).joined(separator: separator) + terminator
    write(string)
  }

  public func write(_ string: String) {
    fputs(string, file)
  }

  public static var err = Console(file: stderr)

  private init(file: UnsafeMutablePointer<FILE>) {
    self.file = file
  }

  private var file: UnsafeMutablePointer<FILE>

}
