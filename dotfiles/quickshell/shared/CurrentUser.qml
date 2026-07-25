import QtQuick
import Quickshell.Io

// Used by the lock screen, which (unlike the greeter) always
// authenticates the single already-logged-in user.
QtObject {
    id: root

    property string username: ""

    property Process proc: Process {
        command: ["whoami"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.username = this.text.trim()
        }
    }
}
