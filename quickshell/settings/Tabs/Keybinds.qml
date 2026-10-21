import "../"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: page

    property string sourceText: ""
    // $terminal, $fileManager etc. live in environment.conf; used for titles only.
    property string mainConfigText: ""
    property string statusMessage: "Loading shortcuts..."
    property var bindings: []
    property string searchText: ""
    property string categoryFilter: "All"
    property var selectedBinding: null
    property string editKey: ""
    property string editCommand: ""
    property bool fileReady: false
    property bool saveInProgress: false
    property bool queuedSave: false
    property string queuedSaveText: ""
    readonly property var categories: ["All", "Apps", "Windows", "Workspaces", "Media", "Capture", "Other"]

    // Bindings are the `bind[flags] = MODS, KEY, dispatcher[, args]` lines of
    // ~/.config/hypr/modules/keybinds.conf. Commented-out lines are skipped.
    function mainModifier(source) {
        var text = source === undefined ? sourceText : source;
        var match = text.match(/^\s*\$mainMod\s*=\s*([^\s#]+)/m);
        return match ? match[1].trim().toUpperCase() : "SUPER";
    }

    // "$mainMod SHIFT", "F" -> "SUPER + SHIFT + F"
    function displayKey(mods, key, source) {
        var parts = mods.split(/[\s_]+/).filter(function(m) {
            return m.length > 0;
        }).map(function(m) {
            return m === "$mainMod" ? mainModifier(source) : m.toUpperCase();
        });
        if (key.length)
            parts.push(key.length === 1 ? key.toUpperCase() : key);

        return parts.join(" + ");
    }

    // "SUPER + SHIFT + F" -> "$mainMod SHIFT, F"
    function confKey(text, source) {
        var parts = text.split("+").map(function(p) {
            return p.trim();
        }).filter(function(p) {
            return p.length > 0;
        });
        if (!parts.length)
            return "";

        var key = parts.pop();
        var main = mainModifier(source);
        var mods = parts.map(function(m) {
            return m.toUpperCase() === main ? "$mainMod" : m.toUpperCase();
        });
        return mods.join(" ") + ", " + key;
    }

    function variables(source) {
        var vars = {}, re = /^\s*\$(\w+)\s*=\s*(.*?)\s*$/gm, m;
        while ((m = re.exec(source)) !== null)vars[m[1]] = m[2]
        return vars;
    }

    function expand(command, vars) {
        return command.replace(/\$(\w+)/g, function(match, name) {
            return vars[name] !== undefined ? vars[name] : match;
        });
    }

    function getCategory(key, command, raw) {
        var value = (key + " " + command + " " + raw).toLowerCase();
        if (/xf86audio|xf86monbrightness|wpctl|playerctl|brightnessctl|pactl|pamixer/.test(value))
            return "Media";

        if (/wf-recorder|hyprshot|grim|screenshot|screen.record/.test(value))
            return "Capture";

        if (/workspace/.test(value))
            return "Workspaces";

        if (/killactive|togglefloating|fullscreen|pseudo|layoutmsg|movefocus|movewindow|resizewindow|centerwindow|togglesplit/.test(value))
            return "Windows";

        if (/^exec/.test(raw.toLowerCase()))
            return "Apps";

        return "Other";
    }

    function getTitle(key, command, raw) {
        var cmd = command.trim().toLowerCase();
        var known = [["kitty", "Terminal"], ["thunar", "File Manager"], ["dolphin", "File Manager"], ["nautilus", "File Manager"], ["code", "Visual Studio Code"], ["spotify", "Spotify"], ["hyprlock", "Lock screen"], ["qylock", "Lock screen"], ["lockscreen", "Lock screen"], ["hyprshot", "Screenshot"], ["wf-recorder", "Screen recorder"], ["playerctl", "Media controls"], ["wpctl", "Audio controls"], ["brightnessctl", "Brightness"], ["switchxkblayout", "Switch keyboard layout"], ["powermenu", "Power menu"], ["app-launcher", "Application launcher"], ["wofi", "Application launcher"], ["notifications", "Notifications"], ["swaync", "Notifications"], ["wallpaper", "Wallpaper"], ["waybar", "Waybar theme"], ["dock-bar", "Toggle Dock"], ["settings", "Settings"], ["ani-cli", "Anime (ani-cli)"], ["toggle-monitor-mode", "Monitor mode"], ["esc-close", "Close panels"]];
        if (cmd.length) {
            for (var k = 0; k < known.length; k++)
                if (cmd.indexOf(known[k][0]) >= 0)
                    return known[k][1];

            return command.length > 42 ? command.slice(0, 39) + "..." : command;
        }
        var m = raw.match(/^(\w+)\s*(?:,\s*(.*))?$/);
        var dispatcher = m ? m[1] : raw, arg = m && m[2] ? m[2].trim() : "";
        var dirs = {"l": "left", "r": "right", "u": "up", "d": "down"};
        switch (dispatcher) {
        case "killactive":
            return "Close window";
        case "exit":
            return "Exit session";
        case "togglefloating":
            return "Toggle floating";
        case "fullscreen":
            return arg === "1" ? "Maximize window" : "Toggle fullscreen";
        case "pseudo":
            return "Pseudo-tile window";
        case "layoutmsg":
            return "Layout: " + arg;
        case "movefocus":
            return "Focus " + (dirs[arg] || arg);
        case "movewindow":
            return arg ? "Move window " + (dirs[arg] || arg) : "Move window (drag)";
        case "resizewindow":
            return "Resize window (drag)";
        case "workspace":
            return arg === "e+1" ? "Next workspace" : arg === "e-1" ? "Previous workspace" : "Go to workspace " + arg;
        case "movetoworkspace":
            return "Move window to workspace " + arg;
        case "togglespecialworkspace":
            return "Toggle scratchpad";
        }
        return raw.length > 42 ? raw.slice(0, 39) + "..." : raw;
    }

    function parseBindings(s) {
        var parsed = [], lines = s.split("\n"), offset = 0;
        var vars = variables(mainConfigText + "\n" + s);
        // Groups: prefix, mods, sep, key, sep, action. Positions are summed
        // from the group lengths so edits land on exactly the right span.
        var re = /^(\s*bind[a-z]*\s*=\s*)([^,]*?)(\s*,\s*)([^,]*?)(\s*,\s*)(.*?)\s*$/;
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i], m = line.match(re);
            if (m) {
                var keyStart = offset + m[1].length;
                var keyEnd = keyStart + m[2].length + m[3].length + m[4].length;
                var actionStart = keyEnd + m[5].length;
                var actionRaw = m[6].replace(/,\s*$/, "");
                var exec = actionRaw.match(/^exec\s*,\s*(.*)$/);
                var command = exec ? exec[1] : "";
                var key = displayKey(m[2], m[4], s);
                parsed.push({
                    "id": parsed.length,
                    "key": key,
                    "title": getTitle(key, expand(command, vars), actionRaw),
                    "command": command,
                    "category": getCategory(key, expand(command, vars), actionRaw),
                    "keyEditable": true,
                    "commandEditable": !!exec,
                    "keyStart": keyStart,
                    "keyEnd": keyEnd,
                    "actionStart": actionStart,
                    "actionEnd": actionStart + m[6].length,
                    "rawAction": actionRaw
                });
            }
            offset += line.length + 1;
        }
        return parsed;
    }

    function loadBindings(text) {
        sourceText = text;
        bindings = parseBindings(text);
    }

    function visibleBindings() {
        var result = [], query = searchText.trim().toLowerCase();
        for (var i = 0; i < bindings.length; i++) {
            var b = bindings[i];
            if (categoryFilter !== "All" && b.category !== categoryFilter)
                continue;

            var searchable = (b.key + " " + b.title + " " + b.command + " " + b.category).toLowerCase();
            if (query.length && searchable.indexOf(query) < 0)
                continue;

            result.push(b);
        }
        return result;
    }

    function openEditor(binding) {
        selectedBinding = binding;
        editKey = binding.keyEditable ? binding.key : "";
        editCommand = binding.command;
        editDialog.open();
    }

    function saveSource(text) {
        sourceText = text;
        statusMessage = "Saving keybinds.conf...";
        if (saveInProgress) {
            queuedSave = true;
            queuedSaveText = text;
            return ;
        }
        saveInProgress = true;
        keybindFile.setText(text);
    }

    function applyEdit() {
        if (!selectedBinding)
            return ;

        var replacements = [], b = selectedBinding;
        var keyChanged = editKey.trim().length > 0 && editKey.trim() !== b.key;
        if (keyChanged) {
            var formattedKey = confKey(editKey.trim(), sourceText);
            if (!formattedKey || /,\s*$/.test(formattedKey)) {
                statusMessage = "Enter a key, e.g. SUPER + SHIFT + F";
                return ;
            }
            var candidateKey = editKey.trim().replace(/\s*\+\s*/g, " + ").toUpperCase();
            for (var duplicateIndex = 0; duplicateIndex < bindings.length; duplicateIndex++) {
                var existing = bindings[duplicateIndex];
                if (existing.id === b.id)
                    continue;

                if (candidateKey === existing.key.trim().replace(/\s*\+\s*/g, " + ").toUpperCase()) {
                    statusMessage = "That shortcut is already assigned to another action";
                    return ;
                }
            }
            replacements.push({
                "start": b.keyStart,
                "end": b.keyEnd,
                "text": formattedKey
            });
        }
        if (b.commandEditable && editCommand.trim() !== b.command) {
            if (!editCommand.trim()) {
                statusMessage = "The command can't be empty";
                return ;
            }
            replacements.push({
                "start": b.actionStart,
                "end": b.actionEnd,
                "text": "exec, " + editCommand.trim().replace(/\n/g, " ")
            });
        }
        if (!replacements.length) {
            statusMessage = "No changes to save";
            return ;
        }
        replacements.sort(function(x, y) {
            return y.start - x.start;
        });
        var updated = sourceText;
        for (var i = 0; i < replacements.length; i++) {
            var r = replacements[i];
            updated = updated.slice(0, r.start) + r.text + updated.slice(r.end);
        }
        sourceText = updated;
        bindings = parseBindings(updated);
        saveSource(updated);
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/modules/environment.conf"
        preload: true
        printErrors: false
        onLoaded: {
            page.mainConfigText = text();
            if (page.fileReady)
                page.bindings = page.parseBindings(page.sourceText);
        }
    }

    FileView {
        id: keybindFile

        path: Quickshell.env("HOME") + "/.config/hypr/modules/keybinds.conf"
        preload: true
        watchChanges: false
        atomicWrites: true
        onLoaded: {
            page.loadBindings(keybindFile.text());
            page.fileReady = true;
            page.statusMessage = page.bindings.length + " keybindings detected";
        }
        onLoadFailed: (error) => {
            page.fileReady = false;
            page.statusMessage = "Unable to load keybinds.conf";
        }
        onSaved: {
            page.saveInProgress = false;
            if (page.queuedSave) {
                var nextText = page.queuedSaveText;
                page.queuedSave = false;
                page.queuedSaveText = "";
                page.saveInProgress = true;
                keybindFile.setText(nextText);
                return ;
            }
            page.statusMessage = "Changes saved to keybinds.conf";
            page.loadBindings(keybindFile.text());
        }
        onSaveFailed: (error) => {
            page.saveInProgress = false;
            if (page.queuedSave) {
                var nextText = page.queuedSaveText;
                page.queuedSave = false;
                page.queuedSaveText = "";
                page.saveInProgress = true;
                keybindFile.setText(nextText);
                return ;
            }
            page.statusMessage = "Could not save keybinds.conf; reloading saved file...";
            keybindFile.reload();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "Keybind Manager"
                    color: Theme.text
                    font.family: Theme.displayFont
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }

                Text {
                    text: page.bindings.length + " shortcuts · keybinds.conf"
                    color: Theme.textFaint
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                }

            }

            Button {
                text: "Reload"
                enabled: page.fileReady
                onClicked: {
                    keybindFile.reload();
                    page.statusMessage = "Reloading shortcuts...";
                }

                background: Rectangle {
                    radius: 9
                    color: parent.hovered ? Theme.bgPanel : Theme.bgCard
                    border.width: 1
                    border.color: Theme.border
                }

                contentItem: Text {
                    text: parent.text
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

            }

        }

        TextField {
            Layout.fillWidth: true
            placeholderText: "Search by shortcut, action or command..."
            color: Theme.text
            font.family: Theme.fontFamily
            selectByMouse: true
            onTextChanged: page.searchText = text

            background: Rectangle {
                color: Theme.bgCard
                radius: 11
                border.width: 1
                border.color: parent.activeFocus ? Theme.accent : Theme.border
            }

        }

        Flickable {
            Layout.fillWidth: true
            implicitHeight: 36
            contentWidth: categoryRow.implicitWidth
            contentHeight: categoryRow.implicitHeight
            clip: true

            Row {
                id: categoryRow

                spacing: 7

                Repeater {
                    model: page.categories

                    delegate: Button {
                        required property string modelData

                        text: modelData
                        onClicked: page.categoryFilter = modelData

                        background: Rectangle {
                            radius: 9
                            color: page.categoryFilter === modelData ? Theme.bgPanel : "transparent"
                            border.width: 1
                            border.color: page.categoryFilter === modelData ? Theme.accent : Theme.border
                        }

                        contentItem: Text {
                            text: modelData
                            color: page.categoryFilter === modelData ? Theme.text : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                    }

                }

            }

        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            clip: true

            ScrollView {
                anchors.fill: parent
                clip: true

                GridLayout {
                    id: cardsGrid

                    width: parent.width
                    columns: width >= 620 ? 2 : 1
                    columnSpacing: 10
                    rowSpacing: 10

                    Repeater {
                        model: page.visibleBindings()

                        delegate: Rectangle {
                            id: shortcutCard

                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredWidth: (cardsGrid.width - cardsGrid.columnSpacing) / 2
                            Layout.preferredHeight: 132
                            radius: 14
                            color: cardHover.hovered ? Theme.bgPanel : Theme.bgCard
                            border.width: 1
                            border.color: cardHover.hovered ? Theme.accent : Theme.border

                            HoverHandler {
                                id: cardHover
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 13
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 9

                                    Rectangle {
                                        Layout.preferredWidth: 36
                                        Layout.preferredHeight: 36
                                        radius: 10
                                        color: Theme.bgPanel
                                        border.width: 1
                                        border.color: Theme.border

                                        Text {
                                            anchors.centerIn: parent
                                            text: {
                                                switch (shortcutCard.modelData.category) {
                                                case "Apps":
                                                    return "󰀻";
                                                case "Windows":
                                                    return "󰖯";
                                                case "Workspaces":
                                                    return "󰓓";
                                                case "Media":
                                                    return "󰎆";
                                                case "Capture":
                                                    return "󰄀";
                                                default:
                                                    return "󰌌";
                                                }
                                            }
                                            color: Theme.accent
                                            font.family: Theme.iconFont
                                            font.pixelSize: 18
                                        }

                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3

                                        Text {
                                            Layout.fillWidth: true
                                            text: shortcutCard.modelData.title
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: shortcutCard.modelData.category
                                            color: Theme.textFaint
                                            font.family: Theme.monoFont
                                            font.pixelSize: 10
                                        }

                                    }

                                    Button {
                                        id: editButton

                                        implicitWidth: 34
                                        implicitHeight: 34
                                        hoverEnabled: true
                                        onClicked: page.openEditor(shortcutCard.modelData)
                                        ToolTip.visible: hovered
                                        ToolTip.text: "Edit shortcut"
                                        ToolTip.delay: 500

                                        background: Rectangle {
                                            radius: 10
                                            color: editButton.hovered ? Theme.bgCard : "transparent"
                                            border.width: 1
                                            border.color: editButton.hovered ? Theme.accent : "transparent"

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 140
                                                }

                                            }

                                        }

                                        contentItem: Text {
                                            text: "󰏫"
                                            color: editButton.hovered ? Theme.accent : Theme.textFaint
                                            font.family: Theme.iconFont
                                            font.pixelSize: 17
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                    }

                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 5

                                    Repeater {
                                        model: shortcutCard.modelData.key.split(" + ")

                                        delegate: Rectangle {
                                            required property string modelData

                                            implicitWidth: keyLabel.implicitWidth + 18
                                            implicitHeight: 26
                                            radius: 6
                                            color: Theme.bgPanel
                                            border.width: 1
                                            border.color: Theme.border

                                            Text {
                                                id: keyLabel

                                                anchors.centerIn: parent
                                                text: modelData
                                                color: Theme.textSoft
                                                font.family: Theme.monoFont
                                                font.pixelSize: 10
                                            }

                                        }

                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: shortcutCard.modelData.command.length ? shortcutCard.modelData.command : shortcutCard.modelData.rawAction
                                    color: Theme.textDim
                                    font.family: Theme.monoFont
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 140
                                }

                            }

                        }

                    }

                }

            }

            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: page.fileReady && page.visibleBindings().length === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰌌"
                    color: Theme.textFaint
                    font.family: Theme.iconFont
                    font.pixelSize: 32
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No matching shortcuts"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

            }

        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 7
                Layout.preferredHeight: 7
                radius: 4
                color: page.fileReady ? "#70c98b" : "#e5b567"
            }

            Text {
                Layout.fillWidth: true
                text: page.statusMessage
                color: Theme.textFaint
                font.family: Theme.monoFont
                font.pixelSize: 10
                elide: Text.ElideRight
            }

        }

    }

    Dialog {
        id: editDialog

        modal: true
        anchors.centerIn: parent
        width: Math.min(470, page.width - 28)
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: "#202228"
            radius: 18
            border.width: 1
            border.color: "#3a3d46"
        }

        contentItem: ColumnLayout {
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 20
                spacing: 13

                Rectangle {
                    Layout.preferredWidth: 46
                    Layout.preferredHeight: 46
                    radius: 14
                    color: "#2b2e37"
                    border.width: 1
                    border.color: "#444853"

                    Text {
                        anchors.centerIn: parent
                        text: "󰌌"
                        color: Theme.accent
                        font.family: Theme.iconFont
                        font.pixelSize: 22
                    }

                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        text: page.selectedBinding ? page.selectedBinding.title : "Edit shortcut"
                        color: Theme.text
                        font.family: Theme.displayFont
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Customize this keybinding"
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                }

            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#383b44"
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 20
                spacing: 17

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: page.selectedBinding ? page.selectedBinding.keyEditable : false

                    Label {
                        text: "KEY COMBINATION"
                        color: Theme.textFaint
                        font.family: Theme.monoFont
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: 11
                        color: "#17191f"
                        border.width: keyField.activeFocus ? 1.5 : 1
                        border.color: keyField.activeFocus ? Theme.accent : "#3a3d46"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 13
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                text: "󰌌"
                                color: Theme.accent
                                font.family: Theme.iconFont
                                font.pixelSize: 16
                            }

                            TextField {
                                id: keyField

                                Layout.fillWidth: true
                                text: page.editKey
                                placeholderText: "SUPER + T"
                                color: Theme.text
                                font.family: Theme.monoFont
                                font.pixelSize: 12
                                selectByMouse: true
                                onTextChanged: page.editKey = text

                                background: Item {
                                }

                            }

                        }

                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Use SUPER, SHIFT, CTRL, ALT and the key name."
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        wrapMode: Text.Wrap
                    }

                }

                Text {
                    Layout.fillWidth: true
                    visible: page.selectedBinding ? !page.selectedBinding.keyEditable : false
                    text: "This shortcut is generated dynamically in Lua and cannot be edited here."
                    color: Theme.textFaint
                    wrapMode: Text.Wrap
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: page.selectedBinding ? page.selectedBinding.commandEditable : false

                    Label {
                        text: "COMMAND"
                        color: Theme.textFaint
                        font.family: Theme.monoFont
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: 11
                        color: "#17191f"
                        border.width: commandField.activeFocus ? 1.5 : 1
                        border.color: commandField.activeFocus ? Theme.accent : "#3a3d46"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 13
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                text: ">_"
                                color: Theme.accent
                                font.family: Theme.monoFont
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }

                            TextField {
                                id: commandField

                                Layout.fillWidth: true
                                text: page.editCommand
                                placeholderText: "Command to execute"
                                color: Theme.text
                                font.family: Theme.monoFont
                                font.pixelSize: 12
                                selectByMouse: true
                                onTextChanged: page.editCommand = text

                                background: Item {
                                }

                            }

                        }

                    }

                }

                Text {
                    Layout.fillWidth: true
                    visible: page.selectedBinding ? !page.selectedBinding.commandEditable : false
                    text: "Custom Lua action · Original code will be preserved."
                    color: Theme.textFaint
                    wrapMode: Text.Wrap
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }

            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#383b44"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 9
                layoutDirection: Qt.RightToLeft
                Layout.margins: 16

                Button {
                    text: "Save changes"
                    implicitHeight: 38
                    implicitWidth: 116
                    onClicked: {
                        page.applyEdit();
                        editDialog.close();
                    }

                    background: Rectangle {
                        radius: 10
                        color: parent.down ? Qt.darker(Theme.accent, 1.12) : parent.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
                        border.width: 1
                        border.color: Qt.lighter(Theme.accent, 1.12)
                    }

                    contentItem: Text {
                        text: parent.text
                        color: "#101116"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                }

                Button {
                    text: "Cancel"
                    implicitHeight: 38
                    implicitWidth: 86
                    onClicked: editDialog.close()

                    background: Rectangle {
                        radius: 10
                        color: parent.hovered ? "#2b2e36" : "#24262d"
                        border.width: 1
                        border.color: "#41444e"
                    }

                    contentItem: Text {
                        text: parent.text
                        color: Theme.textSoft
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                }

            }

        }

    }

}
