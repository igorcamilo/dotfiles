import QtQuick
import Quickshell.Services.Pam

QtObject {
    id: root

    property bool busy: false
    property string failureMessage: ""
    property string pendingPassword: ""

    signal unlocked

    function tryPassword(password) {
        if (busy)
            return;
        busy = true;
        failureMessage = "";
        pendingPassword = password;
        if (!pam.start()) {
            pendingPassword = "";
            busy = false;
            failureMessage = "Could not start authentication";
        }
    }

    property PamContext pam: PamContext {
        // config/configDirectory left at their defaults ("login" in
        // /etc/pam.d), which NixOS always provides.
        onPamMessage: {
            if (responseRequired) {
                const response = root.pendingPassword;
                root.pendingPassword = "";
                respond(response);
            } else if (messageIsError) {
                root.failureMessage = message;
            }
        }

        onCompleted: result => {
            root.pendingPassword = "";
            root.busy = false;
            if (result === PamResult.Success) {
                root.failureMessage = "";
                root.unlocked();
            } else {
                root.failureMessage = "Incorrect password";
            }
        }

        onError: error => {
            root.pendingPassword = "";
            root.busy = false;
            root.failureMessage = "Authentication error";
        }
    }
}
