import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Greetd
import "../shared"

ShellRoot {
    id: root

    property string selectedUser: ""
    property string selectedFullName: ""
    property string pendingPassword: ""
    property string statusMessage: ""
    property bool busy: false

    SystemUsers {
        id: systemUsers
    }

    PanelWindow {
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        // Quickshell's PanelWindow needs its contentItem explicitly
        // focused before any nested Item's focus: true takes effect.
        contentItem.focus: true
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "#1a1b26"

        Image {
            anchors.fill: parent
            source: "file:///etc/wallpaper.jpg"
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        Rectangle {
            anchors.fill: parent
            color: "#1a1b26aa"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.15
            color: "#c0caf5"
            font.pixelSize: 48
            text: Qt.formatDateTime(new Date(), "HH:mm")
        }

        UserPicker {
            anchors.centerIn: parent
            visible: root.selectedUser.length === 0
            users: systemUsers.users
            onUserSelected: (username, fullName) => {
                root.selectedUser = username;
                root.selectedFullName = fullName;
                root.statusMessage = "";
            }
        }

        AuthCard {
            anchors.centerIn: parent
            visible: root.selectedUser.length > 0
            username: root.selectedUser
            fullName: root.selectedFullName
            busy: root.busy
            failureMessage: root.statusMessage
            onSubmitted: password => {
                root.statusMessage = "";
                root.busy = true;
                root.pendingPassword = password;
                Greetd.createSession(root.selectedUser);
            }
        }

        Text {
            visible: root.selectedUser.length > 0 && !root.busy
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 24
            color: "#c0caf5"
            text: "‹ Back"

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.selectedUser = "";
                    root.statusMessage = "";
                }
            }
        }
    }

    Connections {
        target: Greetd

        // Fires once per PAM prompt. This assumes a single
        // password-only prompt (NixOS's default "login" PAM service),
        // not a multi-step or multi-factor conversation.
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                Greetd.respond(root.pendingPassword);
            } else if (error) {
                root.busy = false;
                root.statusMessage = message;
            }
        }

        function onAuthFailure(message) {
            root.busy = false;
            root.statusMessage = message || "Login failed";
        }

        function onReadyToLaunch() {
            Greetd.launch(["Hyprland"]);
        }

        function onError(errorMessage) {
            root.busy = false;
            root.statusMessage = errorMessage;
        }
    }
}
