import QtQuick
import Quickshell
import Quickshell.Services.Pam

Item {
    id: shim
    
    property string themePath: ""
    property var config: ({})

    function loadConfig(path) {
        if (!path) return;
        var url = "file://" + path + "/theme.conf";
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.status === 0) {
                    var lines = xhr.responseText.split("\n");
                    var newConfig = {};
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i].trim();
                        if (line.startsWith("[") || line === "" || line.startsWith("#")) continue;
                        var parts = line.split("=");
                        if (parts.length === 2) {
                            newConfig[parts[0].trim()] = parts[1].trim();
                        }
                    }
                    config = newConfig;
                }
            }
        };
        xhr.open("GET", url, true);
        xhr.send();
    }

    property var userModel: ListModel {
        id: internalUserModel
        property string lastUser: Quickshell.env("USER") || "traveler"
        property int lastIndex: 0
        
        function index(row, col) {
            return row;
        }

        function data(row, role) {
            var item = get(row);
            if (!item) return "";
            if (role === (Qt.UserRole + 1)) return item.name;
            if (role === (Qt.UserRole + 2)) return item.realName;
            return item.name;
        }

        Component.onCompleted: {
            append({
                name: Quickshell.env("USER") || "traveler",
                realName: Quickshell.env("USER") || "Traveler",
                icon: "",
                homeDir: "/home/" + (Quickshell.env("USER") || "traveler")
            })
        }
    }

    property var sessionModel: ListModel {
        ListElement { name: "Qtile"; file: "qtile.desktop" }
        property int lastIndex: 0
    }

    property var sddm: QtObject {
        signal loginFailed()
        signal loginSucceeded()

        function login(user, password, sessionIndex) {
            pam.user = user;
            pam.pendingPassword = password;
            pam.start();
        }

        function reboot() { Quickshell.execDetached(["systemctl", "reboot"]); }
        function powerOff() { Quickshell.execDetached(["systemctl", "poweroff"]); }
    }

    PamContext {
        id: pam
        property string pendingPassword: ""

        onResponseRequiredChanged: {
            if (responseRequired && pendingPassword !== "") {
                respond(pendingPassword);
                pendingPassword = "";
            }
        }

        onCompleted: (result) => {
            if (result === PamResult.Success) {
                shim.sddm.loginSucceeded();
                Quickshell.execDetached(["loginctl", "unlock-session"]);
                // Both emitting the signal for lock_shell.qml and calling
                // loginctl to satisfy any external session monitors.
            } else {
                shim.sddm.loginFailed();
            }
        }
    }

    onThemePathChanged: loadConfig(themePath)
}
