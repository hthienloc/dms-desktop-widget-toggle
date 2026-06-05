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

        OutlineButton {
            text: I18n.tr("Add Group")
            iconName: "add"
            onClicked: rootSettings.addGroup()
        }

        Separator {
            visible: rootSettings.groups.length > 0
        }

        Column {
            width: parent.width
            spacing: Theme.spacingM
            visible: rootSettings.groups.length > 0

            Repeater {
                model: rootSettings.groups

                delegate: Column {
                    id: groupRowContainer
                    required property var modelData
                    required property int index

                    width: parent.width
                    spacing: Theme.spacingS

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
                                text: groupRowContainer.modelData.name || ""
                                placeholderText: I18n.tr("e.g. Work Widgets")
                                onEditingFinished: {
                                    rootSettings.renameGroup(groupRowContainer.index, text.trim());
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
                                currentIcon: groupRowContainer.modelData.icon || "widgets"
                                onIconSelected: (iconName, type) => {
                                    rootSettings.changeGroupIcon(groupRowContainer.index, iconName);
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
                                rootSettings.deleteGroup(groupRowContainer.index);
                            }
                        }
                    }

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
                                    const widgetList = groupRowContainer.modelData.widgets || [];
                                    return widgetList.includes(modelData.id);
                                }
                                onToggled: isChecked => {
                                    rootSettings.toggleWidgetInGroup(groupRowContainer.index, modelData.id, isChecked);
                                }
                            }
                        }
                    }

                    Separator {
                        visible: groupRowContainer.index < rootSettings.groups.length - 1
                    }
                }
            }
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
