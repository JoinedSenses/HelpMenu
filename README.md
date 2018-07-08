# HelpMenu
Original plugin by chundo. Thread here: https://forums.alliedmods.net/showthread.php?t=72576


# Help Menu v0.3 (7/10)

Displays a help menu to users when they type "!helpmenu" in chat. Help menus can be fully customized via a config file. Also displays two standard help menus: Current Map Rotation, and Online Admins.

Configuration is in `configs/helpmenu.cfg`.

The new configuration format removes the old "standard" menus for Rules, Clan Info, and Chat Commands and instead lets you specify arbitrary custom help menus. Each section of the file is its own menu, using the following format:

## Code:
```
"Menu Name"
{
    "title"      "Menu Title"
    "type"     "list"
    "items"
    {
        ""      "Here's an informational item"
        "sm_browse www.mysite.com"  "This launches a client command when selected"
    }
}
```
You can also specify a "text" type to avoid displaying line numbers in the menu if you just want a wall of text and don't need to execute any commands. Please look through the attached configuration for examples.

## CVars:

sm_helpmenu_version // Plugin version.
sm_helpmenu_welcome // Display a welcome message when users connect, telling them they can type "!helpmenu" to view the menu. 1 is on, 0 is off. (default 1)
sm_helpmenu_admins // Display a list of online admins in the help menu. 1 is on, 0 is off. (default 1)

## Commands:

sm_helpmenu // Show the help menu.

## Installing:

helpmenu.smx -> addons/sourcemod/plugins/
helpmenu.sp -> addons/sourcemod/scripting/
helpmenu.cfg -> addons/sourcemod/configs/
plugin.helpmenu.cfg (optional, create if you need to customize cvars) -> cfg/sourcemod/
