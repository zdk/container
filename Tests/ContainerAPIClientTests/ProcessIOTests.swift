//===----------------------------------------------------------------------===//
// Copyright © 2026 Apple Inc. and the container project authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//===----------------------------------------------------------------------===//

import ContainerizationOS
import Foundation
import Testing

@testable import ContainerAPIClient

struct ProcessIOTests {
    private func rawTerminal() throws -> (parent: Terminal, child: Terminal) {
        let pty = try Terminal.create()
        try pty.child.setraw()
        try pty.child.disableOutputProcessing()
        return pty
    }

    @Test func testDisableOutputProcessingClearsOPOST() throws {
        let pty = try rawTerminal()
        defer {
            try? pty.parent.close()
            try? pty.child.close()
        }

        var attr = termios()
        try #require(tcgetattr(pty.child.handle.fileDescriptor, &attr) == 0)
        #expect((attr.c_oflag & tcflag_t(OPOST)) == 0)
    }

    @Test func testRawTerminalPassesLineFeedThrough() throws {
        let pty = try rawTerminal()
        defer {
            try? pty.parent.close()
            try? pty.child.close()
        }

        let written = Array("A\nB\r\n".utf8)
        try pty.child.write(Data(written))

        var received = [UInt8]()
        var buffer = [UInt8](repeating: 0, count: 64)
        while received.count < written.count {
            var pfd = pollfd(fd: pty.parent.handle.fileDescriptor, events: Int16(POLLIN), revents: 0)
            try #require(poll(&pfd, 1, 2000) == 1, "timed out waiting for the pty")
            let n = read(pty.parent.handle.fileDescriptor, &buffer, buffer.count)
            try #require(n > 0)
            received.append(contentsOf: buffer[0..<n])
        }
        #expect(received == written)
    }
}
