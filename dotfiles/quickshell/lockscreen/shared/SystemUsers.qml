import QtQuick
import Quickshell.Io

// Real local accounts, read straight from /etc/passwd (world-readable,
// no extra binary beyond `cat`) so new users show up in the login
// picker without any QML change.
QtObject {
    id: root

    property var users: []

    property Process proc: Process {
        command: ["cat", "/etc/passwd"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const result = [];
                for (const line of this.text.split("\n")) {
                    const fields = line.split(":");
                    if (fields.length < 7)
                        continue;
                    const uid = parseInt(fields[2], 10);
                    const shell = fields[6];
                    if (uid < 1000 || uid >= 60000)
                        continue;
                    if (shell.endsWith("nologin") || shell.endsWith("false"))
                        continue;
                    result.push({
                        username: fields[0],
                        fullName: fields[4].split(",")[0] || fields[0]
                    });
                }
                root.users = result;
            }
        }
    }
}
