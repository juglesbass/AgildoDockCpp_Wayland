import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

RowLayout {
    id: sliderRow
    property string labelText: ""
    property string valueText: ""
    property real fromValue: 0
    property real toValue: 100
    property real stepValue: 1
    property real currentValue: 0
    
    // Properties from the main window
    property color uiTextPrimary: "#FFFFFF"
    property color uiAccent: "#3B82F6"
    property bool settingsDark: true
    
    signal moved(real val)

    spacing: 12
    Layout.fillWidth: true

    Text {
        text: sliderRow.labelText
        font.pixelSize: 13
        color: sliderRow.uiTextPrimary
        width: 170
        Layout.preferredWidth: 170
        Layout.minimumWidth: 170
        Layout.alignment: Qt.AlignVCenter
        elide: Text.ElideRight
    }

    Slider {
        id: innerSlider
        Layout.fillWidth: true
        from: sliderRow.fromValue
        to: sliderRow.toValue
        stepSize: sliderRow.stepValue
        value: sliderRow.currentValue
        onMoved: sliderRow.moved(value)

        background: Rectangle {
            x: innerSlider.leftPadding
            y: innerSlider.topPadding + innerSlider.availableHeight / 2 - height / 2
            implicitWidth: 200
            implicitHeight: 5
            width: innerSlider.availableWidth
            height: implicitHeight
            radius: 2.5
            color: sliderRow.settingsDark ? "#374151" : "#D1D5DB"

            Rectangle {
                width: innerSlider.visualPosition * parent.width
                height: parent.height
                color: sliderRow.uiAccent
                radius: 2.5
            }
        }

        handle: Rectangle {
            x: innerSlider.leftPadding + innerSlider.visualPosition * (innerSlider.availableWidth - width)
            y: innerSlider.topPadding + innerSlider.availableHeight / 2 - height / 2
            implicitWidth: 18
            implicitHeight: 18
            radius: 9
            color: innerSlider.pressed ? "#60A5FA" : (innerSlider.hovered ? "#4B5563" : "#374151")
            border.color: "#9CA3AF"
            border.width: 1.5
        }
    }

    Text {
        text: sliderRow.valueText
        font.pixelSize: 13
        color: sliderRow.uiTextPrimary
        horizontalAlignment: Text.AlignRight
        width: 65
        Layout.preferredWidth: 65
        Layout.minimumWidth: 65
        Layout.alignment: Qt.AlignVCenter
    }
}