import Foundation

struct Logger: TextOutputStream {

  func write(_ string: String) {
    fputs(string, stderr)
  }

}
