import Foundation

func writeResponse(_ response: BridgeResponse) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(response),
          let json = String(data: data, encoding: .utf8) else {
        fputs("{\"ok\":false,\"error\":{\"code\":\"internal_error\",\"message\":\"Failed to encode response\"}}\n", stdout)
        return
    }
    print(json)
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    writeResponse(.failure(code: "invalid_request", message: "Missing JSON command argument"))
    exit(1)
}

guard let input = args[1].data(using: .utf8) else {
    writeResponse(.failure(code: "invalid_request", message: "Command must be UTF-8 JSON"))
    exit(1)
}

let bridge = EventKitBridge()
let response = bridge.handle(input)
writeResponse(response)
exit(response.ok ? 0 : 1)
