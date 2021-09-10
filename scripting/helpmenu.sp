/*
 * In-game Help Menu
 * Written by chundo (chundo@mefightclub.com)
 * v0.4 Edit by emsit -> Transitional Syntax, added command sm_commands, added command sm_helpmenu_reload, added cvar sm_helpmenu_autoreload, added cvar sm_helpmenu_config_path, added panel/PrintToChat when command does not exist or item value is text
 * v0.5 Edit by JoinedSenses -> Additional syntax updating, bug fixes, and an additional CommandExists check for the custom menu handler.
 * Licensed under the GPL version 2 or above
 */

#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#define PLUGIN_VERSION "0.0.8"

enum HelpMenuType {
	HelpMenuType_List,
	HelpMenuType_Text
}

enum struct HelpMenu {
	char name[32];
	char title[128];
	HelpMenuType type;
	DataPack items;
	int itemCount;
}

// CVars
ConVar
	  g_cvarWelcome
	, g_cvarAdmins
	, g_cvarRotation
	, g_cvarReload
	, g_cvarConfigPath;

// Help menus
ArrayList g_helpMenus;

// Map cache
ArrayList g_mapArray;
int g_mapSerial = -1;

// Config parsing
int g_configLevel = -1;

public Plugin myinfo = {
	name = "In-game Help Menu",
	author = "chundo, emsit, joinedsenses",
	description = "Display a help menu to users",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=637467"
};

public void OnPluginStart() {
	CreateConVar("sm_helpmenu_version", PLUGIN_VERSION, "Help menu version", FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_NOTIFY).SetString(PLUGIN_VERSION);
	g_cvarWelcome = CreateConVar("sm_helpmenu_welcome", "1", "Show welcome message to newly connected users.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarAdmins = CreateConVar("sm_helpmenu_admins", "1", "Show a list of online admins in the menu.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarRotation = CreateConVar("sm_helpmenu_rotation", "1", "Shows the map rotation in the menu.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarReload = CreateConVar("sm_helpmenu_autoreload", "0", "Automatically reload the configuration file when changing the map.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarConfigPath = CreateConVar("sm_helpmenu_config_path", "configs/helpmenu.cfg", "Path to configuration file.");

	RegConsoleCmd("sm_helpmenu", Command_HelpMenu, "Display the help menu.");
	RegConsoleCmd("sm_commands", Command_HelpMenu, "Display the help menu.");
	RegAdminCmd("sm_helpmenu_reload", Command_HelpMenuReload, ADMFLAG_ROOT, "Reload the configuration file");

	g_mapArray = new ArrayList(ByteCountToCells(80));
	g_helpMenus = new ArrayList(sizeof(HelpMenu));

	char hc[PLATFORM_MAX_PATH];
	char buffer[PLATFORM_MAX_PATH];

	g_cvarConfigPath.GetString(buffer, sizeof(buffer));
	BuildPath(Path_SM, hc, sizeof(hc), "%s", buffer);
	ParseConfigFile(hc);

	// /cfg/sourcemod/plugin.helpmenu.cfg
	AutoExecConfig();
}

public void OnMapStart() {
	if (g_cvarReload.BoolValue) {
		char hc[PLATFORM_MAX_PATH];
		char buffer[PLATFORM_MAX_PATH];

		g_cvarConfigPath.GetString(buffer, sizeof(buffer));
		BuildPath(Path_SM, hc, sizeof(hc), "%s", buffer);
		ParseConfigFile(hc);
	}
}

public void OnClientPutInServer(int client) {
	if (g_cvarWelcome.BoolValue) {
		CreateTimer(15.0, Timer_WelcomeMessage, GetClientUserId(client));
	}
}

public Action Timer_WelcomeMessage(Handle timer, int userid) {
	int client = GetClientOfUserId(userid);
	if (client && !IsFakeClient(client)) {
		PrintToChat(client, "\x05[SM] \x01For help, type \x04!helpmenu\x01 in chat");
	}
}

bool ParseConfigFile(const char[] file) {
	g_helpMenus.Clear();

	SMCParser parser = new SMCParser();
	parser.OnEnterSection = Config_NewSection;
	parser.OnLeaveSection = Config_EndSection;
	parser.OnKeyValue = Config_KeyValue;
	parser.OnEnd = Config_End;

	int line = 0;
	int col = 0;
	char error[128];
	SMCError result = parser.ParseFile(file, line, col);
	if (result != SMCError_Okay) {
		parser.GetErrorString(result, error, sizeof(error));
		LogError("%s on line %d, col %d of %s", error, line, col, file);
	}
	delete parser;
	return (result == SMCError_Okay);
}

public SMCResult Config_NewSection(SMCParser parser, const char[] section, bool quotes) {
	++g_configLevel;
	if (g_configLevel == 1) {
		HelpMenu hmenu;
		strcopy(hmenu.name, sizeof(HelpMenu::name), section);
		hmenu.items = new DataPack();
		hmenu.itemCount = 0;
		if (g_helpMenus == null) {
			g_helpMenus = new ArrayList(sizeof(HelpMenu));
		}
		g_helpMenus.PushArray(hmenu);
	}

	return SMCParse_Continue;
}

public SMCResult Config_KeyValue(SMCParser parser, const char[] key, const char[] value, bool key_quotes, bool value_quotes) {
	int msize = g_helpMenus.Length;
	HelpMenu hmenu;
	g_helpMenus.GetArray(msize-1, hmenu);
	switch (g_configLevel) {
		case 1: {
			if (strcmp(key, "title", false) == 0) {
				strcopy(hmenu.title, sizeof(HelpMenu::title), value);
			}
			if (strcmp(key, "type", false) == 0) {
				if (strcmp(value, "text", false) == 0) {
					hmenu.type = HelpMenuType_Text;
				}
				else {
					hmenu.type = HelpMenuType_List;
				}
			}
		}
		case 2: {
			hmenu.items.WriteString(key);
			hmenu.items.WriteString(value);
			++hmenu.itemCount;
		}
	}
	g_helpMenus.SetArray(msize-1, hmenu);

	return SMCParse_Continue;
}
public SMCResult Config_EndSection(SMCParser parser) {
	--g_configLevel;
	
	if (g_configLevel == 1) {
		HelpMenu hmenu;
		int msize = g_helpMenus.Length;
		g_helpMenus.GetArray(msize-1, hmenu);
		hmenu.items.Reset();
	}

	return SMCParse_Continue;
}

public void Config_End(SMCParser parser, bool halted, bool failed) {
	if (failed) {
		SetFailState("Plugin configuration error");
	}
}

public Action Command_HelpMenu(int client, int args) {
	if (client) {
		Help_ShowMainMenu(client);
	}
	return Plugin_Handled;
}

public Action Command_HelpMenuReload(int client, int args) {
	char hc[PLATFORM_MAX_PATH];
	char buffer[PLATFORM_MAX_PATH];

	g_cvarConfigPath.GetString(buffer, sizeof(buffer));
	BuildPath(Path_SM, hc, sizeof(hc), "%s", buffer);
	ParseConfigFile(hc);

	ReplyToCommand(client, "%sConfiguration file has been reloaded", GetCmdReplySource() == SM_REPLY_TO_CHAT ? "\x05[SM] \x01" : "[SM] ");

	return Plugin_Handled;
}

void Help_ShowMainMenu(int client) {
	Menu menu = new Menu(Help_MainMenuHandler);
	menu.SetTitle("Help Menu");

	int msize = g_helpMenus.Length;
	HelpMenu hmenu;
	char menuid[10];

	for (int i = 0; i < msize; ++i) {
		FormatEx(menuid, sizeof(menuid), "helpmenu_%d", i);
		g_helpMenus.GetArray(i, hmenu);
		menu.AddItem(menuid, hmenu.name);
	}

	if (g_cvarRotation.BoolValue) {
		menu.AddItem("maplist", "Map Rotation");
	}
	if (g_cvarAdmins.BoolValue) {
		menu.AddItem("admins", "List Online Admins");
	}

	menu.ExitBackButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Help_MainMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch(action) {
		case MenuAction_Select: {
			char buf[64];
			int msize = g_helpMenus.Length;
			if (param2 == msize) { // Maps
				ReadMapList(g_mapArray, g_mapSerial, "default");

				if (g_mapArray != null) {
					Menu mapMenu = new Menu(Help_MenuHandler);
					mapMenu.ExitBackButton = true;
					
					int mapct = g_mapArray.Length;

					FormatEx(buf, sizeof(buf), "Current Rotation (%d maps)\n ", mapct);
					mapMenu.SetTitle(buf);
					
					char mapname[64];
					for (int i = 0; i < mapct; ++i) {
						g_mapArray.GetString(i, mapname, sizeof(mapname));
						mapMenu.AddItem(mapname, mapname, ITEMDRAW_DISABLED);
					}

					mapMenu.Display(param1, MENU_TIME_FOREVER);
				}
			}
			else if (param2 == msize+1) { // Admins
				Menu adminMenu = new Menu(Help_MenuHandler);
				adminMenu.ExitBackButton = true;
				adminMenu.SetTitle("Online Admins");
				char aname[64];

				for (int i = 1; i < MaxClients; ++i) {
					// override helpmenu_admin to change who shows in menu
					if (Client_IsValidHuman(i, true, false, true) && CheckCommandAccess(i, "helpmenu_admin", ADMFLAG_KICK)) {
						GetClientName(i, aname, sizeof(aname));
						adminMenu.AddItem(aname, aname, ITEMDRAW_DISABLED);
					}
				}
				adminMenu.Display(param1, MENU_TIME_FOREVER);
			}
			else { // Menu from config file
				if (param2 <= msize) {
					HelpMenu hmenu;
					g_helpMenus.GetArray(param2, hmenu);
					char mtitle[512];
					FormatEx(mtitle, sizeof(mtitle), "%s\n ", hmenu.title);
					if (hmenu.type == HelpMenuType_Text) {
						Panel cpanel = new Panel();
						cpanel.SetTitle(mtitle);
						char text[128];
						char junk[128];

						int count = hmenu.itemCount;
						for (int i = 0; i < count; ++i) {
							hmenu.items.ReadString(junk, sizeof(junk));
							hmenu.items.ReadString(text, sizeof(text));
							cpanel.DrawText(text);
						}
						for (int j = 0; j < 7; ++j) {
							cpanel.DrawItem(" ", ITEMDRAW_NOTEXT);
						}

						cpanel.DrawText(" ");
						cpanel.DrawItem("Back", ITEMDRAW_CONTROL);
						cpanel.DrawItem(" ", ITEMDRAW_NOTEXT);
						cpanel.DrawText(" ");
						cpanel.DrawItem("Exit", ITEMDRAW_CONTROL);
						hmenu.items.Reset();
						cpanel.Send(param1, Help_MenuHandler, MENU_TIME_FOREVER);
						delete cpanel;
					}
					else {
						Menu cmenu = new Menu(Help_CustomMenuHandler);
						cmenu.ExitBackButton = true;
						cmenu.SetTitle(mtitle);
						char cmd[128];
						char desc[128];

						int count = hmenu.itemCount;
						for (int i = 0; i < count; ++i) {
							hmenu.items.ReadString(cmd, sizeof(cmd));
							hmenu.items.ReadString(desc, sizeof(desc));
							int drawstyle = ITEMDRAW_DEFAULT;
							if (strlen(cmd) == 0) {
								drawstyle = ITEMDRAW_DISABLED;
							}
							cmenu.AddItem(cmd, desc, drawstyle);
						}

						hmenu.items.Reset();
						cmenu.Display(param1, MENU_TIME_FOREVER);
					}
				}
			}
		}
		//case MenuAction_Cancel: {
		//	if (param2 == MenuCancel_ExitBack) {
		//		Help_ShowMainMenu(param1);
		//	}
		//}
		case MenuAction_End: {
			delete menu;
		}
	}
}

int Help_MenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch(action) {
		case MenuAction_Select: {
			if (menu == null && param2 == 8) {
				Help_ShowMainMenu(param1);
			}
		}
		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				Help_ShowMainMenu(param1);
			}
		}
		case MenuAction_End: {
			delete menu;
		}
	}
}

int Help_CustomMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch(action) {
		case MenuAction_Select: {
			char itemval[128];
			menu.GetItem(param2, itemval, sizeof(itemval));
			if (strlen(itemval) > 0) {
				char command[64];
				SplitString(itemval, " ", command, sizeof(command));

				if (CommandExist(command, sizeof(command)) || CommandExist(itemval, sizeof(itemval))) {
					FakeClientCommand(param1, itemval);
				}
				else {
					Panel panel = new Panel();
					panel.SetTitle("Description\n ");

					panel.DrawText(itemval);

					for (int j = 0; j < 7; ++j) {
						panel.DrawItem(" ", ITEMDRAW_NOTEXT);
					}

					panel.DrawText(" ");
					panel.DrawItem("Back", ITEMDRAW_CONTROL);
					panel.DrawItem(" ", ITEMDRAW_NOTEXT);
					panel.DrawText(" ");
					panel.DrawItem("Exit", ITEMDRAW_CONTROL);
					panel.Send(param1, Help_MenuHandler, MENU_TIME_FOREVER);
					delete panel;

					PrintToChat(param1, "\x05[SM] \x01%s", itemval);
				}
			}
		}
		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				Help_ShowMainMenu(param1);
			}
		}
		case MenuAction_End: {
			delete menu;
		}
	}
}


bool Client_IsValidHuman(int client, bool connected = true, bool nobots = true, bool InGame = false) {
	if (!Client_IsValid(client, connected)) {
		return false;
	}

	if (nobots && IsFakeClient(client)) {
		return false;
	}

	if (InGame) {
		return IsClientInGame(client);
	}

	return true;
}

bool Client_IsValid(int client, bool checkConnected = true) {
	if (client > 4096) {
		client = EntRefToEntIndex(client);
	}

	if (client < 1 || client > MaxClients) {
		return false;
	}

	if (checkConnected && !IsClientConnected(client)) {
		return false;
	}

	return true;
}

stock bool CommandExist(char[] command, int commandLen) {
	//remove the character '!' from the beginning of the command
	if (command[0] == '!') {
		strcopy(command, commandLen, command[1]);
	}

	if (CommandExists(command)) {
		return true;
	}

	//if the command does not exist and has a prefix 'sm_'
	if (!strncmp(command, "sm_", 3)) {
		return false;
	}

	//add the prefix 'sm_' to the beginning of the command
	Format(command, commandLen, "sm_%s", command);

	return CommandExists(command);
}
