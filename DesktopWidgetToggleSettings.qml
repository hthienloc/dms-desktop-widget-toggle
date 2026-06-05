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
        if (loadValue("activeGroupId", "") === deletedId) {
            const deletedGroup = updated[index];
            if (deletedGroup && deletedGroup.widgets) {
                deletedGroup.widgets.forEach(wId => {
                    SettingsData.updateDesktopWidgetInstanceConfig(wId, {
                        showOnOverlay: false
                    });
                });
            }
            saveValue("activeGroupId", "");
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

        const activeId = loadValue("activeGroupId", "");
        if (activeId === updated[groupIndex].id) {
            SettingsData.updateDesktopWidgetInstanceConfig(widgetId, {
                showOnOverlay: isChecked
            });
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
            showReset: autoDismissDuration.isDirty || hideWhenInactiveSetting.isDirty
            onResetClicked: {
                autoDismissDuration.resetToDefault();
                hideWhenInactiveSetting.resetToDefault();
            }
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
                I18n.tr("Only one group can be active at a time. Other groups are disabled when a group is active.")
            ]
        }
    }

    PluginAbout {
        repoUrl: "https://github.com/hthienloc/dms-desktop-widget-toggle"
    }
}
