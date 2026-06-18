import Quickshell

PopupPanel {
    id: root

    title: "Power"
    subtitle: "Session controls"
    panelWidth: 300

    function run(command) {
        root.dismissRequested()
        Quickshell.execDetached(command)
    }

    ActionButton {
        icon: "󰌾"
        label: "Lock"
        sublabel: "Quickshell lockscreen"
        fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
        onClicked: root.run(["bash", "/home/arch/.local/share/quickshell-lockscreen/lock.sh"])
    }

    ActionButton {
        icon: "󰤄"
        label: "Suspend"
        sublabel: "Sleep now"
        fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
        onClicked: root.run(["systemctl", "suspend"])
    }

    ActionButton {
        icon: "󰍃"
        label: "Log out"
        sublabel: "Exit Hyprland"
        fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
        onClicked: root.run(["hyprctl", "dispatch", "exit"])
    }

    ActionButton {
        icon: "󰜉"
        label: "Reboot"
        sublabel: "Restart machine"
        danger: true
        fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
        onClicked: root.run(["systemctl", "reboot"])
    }

    ActionButton {
        icon: "󰐥"
        label: "Power off"
        sublabel: "Shut down machine"
        danger: true
        fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
        onClicked: root.run(["systemctl", "poweroff"])
    }
}
