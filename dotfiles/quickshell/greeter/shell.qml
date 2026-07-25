import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Greetd

ShellRoot {
    id: root

    function submit() {
        statusText.text = "";
        Greetd.createSession(userField.text);
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

        Column {
            anchors.centerIn: parent
            spacing: 12
            width: 240

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#c0caf5"
                font.pixelSize: 22
                text: "Log in"
            }

            Rectangle {
                width: parent.width
                height: 32
                color: "transparent"
                border.color: "#565f89"

                TextInput {
                    id: userField
                    anchors.fill: parent
                    anchors.margins: 6
                    color: "#c0caf5"
                    font.pixelSize: 16
                    focus: true
                    Keys.onReturnPressed: passField.forceActiveFocus()
                }
            }

            Rectangle {
                width: parent.width
                height: 32
                color: "transparent"
                border.color: "#565f89"

                TextInput {
                    id: passField
                    anchors.fill: parent
                    anchors.margins: 6
                    color: "#c0caf5"
                    font.pixelSize: 16
                    echoMode: TextInput.Password
                    Keys.onReturnPressed: root.submit()
                }
            }

            Text {
                id: statusText
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#f7768e"
                wrapMode: Text.WordWrap
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: text.length > 0
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
                Greetd.respond(passField.text);
            } else if (error) {
                statusText.text = message;
            }
        }

        function onAuthFailure(message) {
            statusText.text = message || "Login failed";
            passField.text = "";
        }

        function onReadyToLaunch() {
            Greetd.launch(["Hyprland"]);
        }

        function onError(errorMessage) {
            statusText.text = errorMessage;
        }
    }
}
