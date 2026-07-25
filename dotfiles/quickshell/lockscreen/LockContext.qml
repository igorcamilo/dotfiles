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
        pam.start();
    }

    property PamContext pam: PamContext {
        // config/configDirectory left at their defaults ("login" in
        // /etc/pam.d), which NixOS always provides.
        onPamMessage: {
            if (responseRequired) {
                respond(root.pendingPassword);
            } else if (messageIsError) {
                root.failureMessage = message;
            }
        }

        onCompleted: result => {
            root.busy = false;
            if (result === PamResult.Success) {
                root.failureMessage = "";
                root.unlocked();
            } else {
                root.failureMessage = "Incorrect password";
            }
        }
    }
}
