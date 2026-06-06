pragma ComponentBehavior: Bound

import "./dms-common"
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: rootSettings
    pluginId: "desktopWidgetToggle"

    property var groups: {
        settingChanged;
        return loadValue("groups", [
            { "id": "g1", "name": "Group 1", "icon": "widgets", "widgets": [] }
        ]);
    }

    property int selectedGroupIndex: 0

    property var tabModel: {
        let list = [];
        for (let i = 0; i < groups.length; i++) {
            list.push({
                "text": groups[i].name || "Group " + (i + 1),
                "icon": groups[i].icon || "widgets",
                "isAction": false
            });
        }
        list.push({
            "text": "",
            "icon": "add",
            "isAction": true
        });
        return list;
    }

    function saveGroups(newGroups) {
        saveValue("groups", newGroups);
    }

    function renameGroup(index, newName) {
        let updated = JSON.parse(JSON.stringify(groups));
        updated[index].name = newName;
        saveGroups(updated);
    }

    function changeGroupIcon(index, newIcon) {
        let updated = JSON.parse(JSON.stringify(groups));
        updated[index].icon = newIcon;
        saveGroups(updated);
    }

    function updateGroupControl(index, key, value) {
        let updated = JSON.parse(JSON.stringify(groups));
        updated[index][key] = value;
        saveGroups(updated);
    }

    function addGroup() {
        let updated = JSON.parse(JSON.stringify(groups));
        const newId = "g_" + Date.now() + "_" + Math.random().toString(36).substr(2, 9);
        updated.push({
            "id": newId,
            "name": "New Group",
            "icon": "widgets",
            "widgets": []
        });
        saveGroups(updated);
        selectedGroupIndex = updated.length - 1;
    }

    function deleteGroup(index) {
        if (groups.length <= 1)
            return;
        let updated = JSON.parse(JSON.stringify(groups));
        const deletedId = updated[index].id;
        
        let activeIds = loadValue("activeGroupIds", []);
        if (activeIds.includes(deletedId)) {
            const deletedGroup = updated[index];
            if (deletedGroup && deletedGroup.widgets) {
                deletedGroup.widgets.forEach(wId => {
                    const otherActiveIds = activeIds.filter(id => id !== deletedId);
                    const isInOtherActive = updated.some((g, idx) => idx !== index && otherActiveIds.includes(g.id) && g.widgets && g.widgets.includes(wId));
                    if (!isInOtherActive) {
                        SettingsData.updateDesktopWidgetInstanceConfig(wId, {
                            showOnOverlay: false,
                            showOnOverview: false,
                            showOnOverviewOnly: false,
                            clickThrough: false
                        });
                        if (loadValue("hideWhenInactive", false)) {
                            SettingsData.updateDesktopWidgetInstance(wId, {
                                enabled: false
                            });
                        }
                    }
                });
            }
            activeIds = activeIds.filter(id => id !== deletedId);
            saveValue("activeGroupIds", activeIds);
            saveValue("activeGroupId", activeIds.length > 0 ? activeIds[0] : "");
        }
        
        updated.splice(index, 1);
        saveGroups(updated);

        if (selectedGroupIndex >= updated.length) {
            selectedGroupIndex = updated.length - 1;
        }
    }

    function toggleWidgetInGroup(groupIndex, widgetId, isChecked) {
        let updated = JSON.parse(JSON.stringify(groups));
        let widgetList = updated[groupIndex].widgets || [];
        if (isChecked) {
            if (!widgetList.includes(widgetId)) {
                widgetList.push(widgetId);
            }
        } else {
            widgetList = widgetList.filter(id => id !== widgetId);
        }
        updated[groupIndex].widgets = widgetList;
        saveGroups(updated);

        const activeIds = loadValue("activeGroupIds", []);
        if (activeIds.includes(updated[groupIndex].id)) {
            if (!isChecked) {
                const isInOtherActive = updated.some((g, idx) => idx !== groupIndex && activeIds.includes(g.id) && g.widgets && g.widgets.includes(widgetId));
                if (!isInOtherActive) {
                    SettingsData.updateDesktopWidgetInstanceConfig(widgetId, {
                        showOnOverlay: false,
                        showOnOverview: false,
                        showOnOverviewOnly: false,
                        clickThrough: false
                    });
                    if (loadValue("hideWhenInactive", false)) {
                        SettingsData.updateDesktopWidgetInstance(widgetId, {
                            enabled: false
                        });
                    }
                }
            }
        }
    }

    SettingsCard {
        id: groupsSection

        SectionTitle {
            text: I18n.tr("Widget Groups")
            icon: "widgets"
        }

        DankTabBar {
            id: groupTabBar
            width: parent.width
            tabHeight: 48
            model: rootSettings.tabModel
            currentIndex: rootSettings.selectedGroupIndex
            equalWidthTabs: false
            showIcons: true

            onTabClicked: index => {
                rootSettings.selectedGroupIndex = index;
            }

            onActionTriggered: index => {
                rootSettings.addGroup();
            }
        }

        Column {
            id: activeGroupDetails
            width: parent.width
            spacing: Theme.spacingM

            readonly property var currentGroup: (rootSettings.groups && rootSettings.selectedGroupIndex >= 0 && rootSettings.selectedGroupIndex < rootSettings.groups.length) ? rootSettings.groups[rootSettings.selectedGroupIndex] : null

            visible: currentGroup !== null

            Row {
                width: parent.width
                spacing: Theme.spacingM

                Column {
                    width: (parent.width - deleteBtn.width - Theme.spacingM * 2) * 0.6
                    spacing: Theme.spacingXS
                    anchors.bottom: parent.bottom

                    StyledText {
                        text: I18n.tr("Group Name")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    DankTextField {
                        width: parent.width
                        height: 40
                        text: activeGroupDetails.currentGroup ? (activeGroupDetails.currentGroup.name || "") : ""
                        placeholderText: I18n.tr("e.g. Work Widgets")
                        onEditingFinished: {
                            if (activeGroupDetails.currentGroup) {
                                rootSettings.renameGroup(rootSettings.selectedGroupIndex, text.trim());
                            }
                        }
                    }
                }

                Column {
                    width: (parent.width - deleteBtn.width - Theme.spacingM * 2) * 0.4
                    spacing: Theme.spacingXS
                    anchors.bottom: parent.bottom

                    StyledText {
                        text: I18n.tr("Icon")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    DankIconPicker {
                        width: parent.width
                        height: 40
                        currentIcon: activeGroupDetails.currentGroup ? (activeGroupDetails.currentGroup.icon || "widgets") : "widgets"
                        onIconSelected: (iconName, type) => {
                            if (activeGroupDetails.currentGroup) {
                                rootSettings.changeGroupIcon(rootSettings.selectedGroupIndex, iconName);
                            }
                        }
                    }
                }

                DankButton {
                    id: deleteBtn
                    text: I18n.tr("Delete")
                    iconName: "delete"
                    backgroundColor: Theme.error
                    textColor: Theme.onError
                    buttonHeight: 40
                    enabled: rootSettings.groups.length > 1
                    anchors.bottom: parent.bottom
                    onClicked: {
                        rootSettings.deleteGroup(rootSettings.selectedGroupIndex);
                    }
                }
            }

            Separator {}

            Column {
                width: parent.width
                spacing: Theme.spacingXS
                leftPadding: Theme.spacingM

                StyledText {
                    text: I18n.tr("Group Control Options")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                DankToggle {
                    width: parent.width
                    text: I18n.tr("Show on Overlay")
                    description: I18n.tr("Show widgets in this group in the desktop overlay layer")
                    checked: activeGroupDetails.currentGroup ? (activeGroupDetails.currentGroup.toggleOverlay !== false) : true
                    onToggled: isChecked => {
                        if (activeGroupDetails.currentGroup) {
                            rootSettings.updateGroupControl(rootSettings.selectedGroupIndex, "toggleOverlay", isChecked);
                        }
                    }
                }

                DankToggle {
                    visible: CompositorService.isNiri
                    width: parent.width
                    text: I18n.tr("Show on Overview")
                    description: I18n.tr("Show widgets in this group during workspace overview")
                    checked: activeGroupDetails.currentGroup ? !!activeGroupDetails.currentGroup.toggleOverview : false
                    onToggled: isChecked => {
                        if (activeGroupDetails.currentGroup) {
                            rootSettings.updateGroupControl(rootSettings.selectedGroupIndex, "toggleOverview", isChecked);
                        }
                    }
                }

                DankToggle {
                    visible: CompositorService.isNiri
                    width: parent.width
                    text: I18n.tr("Show on Overview Only")
                    description: I18n.tr("Show widgets in this group only during workspace overview")
                    checked: activeGroupDetails.currentGroup ? !!activeGroupDetails.currentGroup.toggleOverviewOnly : false
                    onToggled: isChecked => {
                        if (activeGroupDetails.currentGroup) {
                            rootSettings.updateGroupControl(rootSettings.selectedGroupIndex, "toggleOverviewOnly", isChecked);
                        }
                    }
                }

                DankToggle {
                    width: parent.width
                    text: I18n.tr("Click Through")
                    description: I18n.tr("Allow clicks to pass through widgets in this group")
                    checked: activeGroupDetails.currentGroup ? !!activeGroupDetails.currentGroup.toggleClickThrough : false
                    onToggled: isChecked => {
                        if (activeGroupDetails.currentGroup) {
                            rootSettings.updateGroupControl(rootSettings.selectedGroupIndex, "toggleClickThrough", isChecked);
                        }
                    }
                }
            }

            Separator {}

            Column {
                width: parent.width
                spacing: Theme.spacingXS
                leftPadding: Theme.spacingM

                StyledText {
                    text: I18n.tr("Select Widgets")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                StyledText {
                    text: I18n.tr("No desktop widgets found. Go to Desktop Widgets tab to create some.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    visible: (SettingsData.desktopWidgetInstances || []).length === 0
                }

                Repeater {
                    model: SettingsData.desktopWidgetInstances || []

                    delegate: DankToggle {
                        required property var modelData
                        width: parent.width
                        text: modelData.name || modelData.widgetType
                        description: "Type: " + modelData.widgetType + " | ID: " + modelData.id
                        checked: {
                            if (!activeGroupDetails.currentGroup)
                                return false;
                            const widgetList = activeGroupDetails.currentGroup.widgets || [];
                            return widgetList.includes(modelData.id);
                        }
                        onToggled: isChecked => {
                            if (activeGroupDetails.currentGroup) {
                                rootSettings.toggleWidgetInGroup(rootSettings.selectedGroupIndex, modelData.id, isChecked);
                            }
                        }
                    }
                }
            }
        }
    }

    SettingsCard {
        id: behaviorSection
        SectionTitle {
            id: behaviorTitle
            text: I18n.tr("Behavior")
            icon: "settings"
            showReset: autoDismissDuration.isDirty || hideWhenInactiveSetting.isDirty || conflictModeSetting.isDirty
            onResetClicked: {
                autoDismissDuration.resetToDefault();
                hideWhenInactiveSetting.resetToDefault();
                conflictModeSetting.resetToDefault();
            }
        }

        SelectionSettingPlus {
            id: conflictModeSetting
            settingKey: "conflictMode"
            label: I18n.tr("Toggle Mode")
            description: I18n.tr("Choose how widget groups can be toggled simultaneously.")
            defaultValue: "single"
            options: [
                { "value": "single", "label": I18n.tr("Single Active Group") },
                { "value": "overlap", "label": I18n.tr("Block Overlap") },
                { "value": "all", "label": I18n.tr("Allow All") }
            ]
        }

        SliderSettingPlus {
            id: autoDismissDuration
            settingKey: "autoDismissDuration"
            label: I18n.tr("Auto-dismiss Overlay")
            description: I18n.tr("Automatically turn off the active overlay group after this duration. Set to 0 to keep active.")
            defaultValue: 0
            minimum: 0
            maximum: 15
            unit: "s"
            leftLabel: I18n.tr("Off")
            rightLabel: "15s"
        }

        ToggleSettingPlus {
            id: hideWhenInactiveSetting
            settingKey: "hideWhenInactive"
            label: I18n.tr("Hide when inactive")
            description: I18n.tr("Hide the widgets in inactive groups entirely from the desktop, showing them only when their group is activated.")
            defaultValue: false
        }
    }

    SettingsCard {
        SectionTitle {
            id: usageTitle
            text: I18n.tr("Usage Guide")
            icon: "menu_book"
            collapsible: true
            settingKey: "usageGuideExpanded"
        }

        UsageGuide {
            expanded: usageTitle.isExpanded
            items: [
                I18n.tr("<b>Click</b> a group button on the status bar to show its widgets on top of all windows (overlay)."),
                I18n.tr("<b>Click it again</b> to return the widgets to the desktop background layer."),
                I18n.tr("Depending on the Toggle Mode setting, you can activate one or multiple groups concurrently.")
            ]
        }
    }

    PluginAbout {
        repoUrl: "https://github.com/hthienloc/dms-desktop-widget-toggle"
    }
}
