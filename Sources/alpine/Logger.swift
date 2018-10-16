struct Logger: TextOutputStream {

  func write(_ string: String) {
    print(string, terminator: "")
  }

}
