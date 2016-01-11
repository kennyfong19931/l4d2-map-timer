#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

/* Make the admin menu plugin optional */
#undef REQUIRE_PLUGIN
#include <adminmenu>

#define PLUGIN_AUTHOR "kennyfong"
#define PLUGIN_VERSION "1.1"

#define MAX_LINE_WIDTH 64
#define TEAM_SURVIVOR	2

#define DB_NAME	"Timer"
#define Difficulty_Easy	1
#define Difficulty_Normal	2
#define Difficulty_Hard	3
#define Difficulty_Expert	4

// for timer
new Handle:cvar_Gamemode = INVALID_HANDLE;
new Handle:cvar_Difficulty = INVALID_HANDLE;
new Float:MapTimingStartTime = 0.0;
new bool:MapTimingDisabled = false;
//for cvar
new Handle:cvar_MapTimingDisabled = INVALID_HANDLE;
//for DB
new Handle:dbTimer = INVALID_HANDLE;

public Plugin myinfo = 
{
	name = "[L4D2] Map Timer",
	author = PLUGIN_AUTHOR,
	description = "A map timer for L4D2, only avaliable for coop",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	// Require Left 4 Dead 2
	decl String: game_name[64];
	GetGameFolderName(game_name, sizeof(game_name));
	if (!StrEqual(game_name, "left4dead2", false))
	{
		SetFailState("Use this in Left 4 Dead 2 only.");
	}
	
	// cvar
	cvar_MapTimingDisabled = CreateConVar("l4d_timer_disable", "0", "Disable the plugin", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	MapTimingDisabled = GetConVarBool(cvar_MapTimingDisabled);
	AutoExecConfig(true, "l4d2_map_timer");
	
	// Map start/end event
	HookEvent("round_start", event_RoundStart);
	HookEvent("door_open", event_DoorOpen);
	HookEvent("player_left_start_area", event_StartArea, EventHookMode_Post);
	HookEvent("finale_vehicle_leaving", event_MapEnd);
	HookEvent("map_transition", event_MapEnd);
	
	// When difficulty changed
	cvar_Difficulty = FindConVar("z_difficulty");
	HookConVarChange(cvar_Difficulty, action_DifficultyChanged);
	
	RegConsoleCmd("sm_list", CmdGetClientList, "List all survivor in the server");
	RegConsoleCmd("sm_time", CmdGetMapTime, "Show current map time");
	RegConsoleCmd("sm_best", CmdGetMapBestTime, "Show best time on current map");
	RegConsoleCmd("sm_timerstart", CmdStartTimer, "Start map timer", ADMFLAG_ROOT);
	RegConsoleCmd("sm_timerstop", CmdStopTimer, "Stop map timer", ADMFLAG_ROOT);
	RegConsoleCmd("sm_timerenable", CmdEnableTimer, "Enable map timer", ADMFLAG_ROOT);
	RegConsoleCmd("sm_timerdisable", CmdDisableTimer, "Disable map timer", ADMFLAG_ROOT);
	RegConsoleCmd("sm_cleartimeall", CmdClearTimeAll, "Clear all record", ADMFLAG_ROOT);
	RegConsoleCmd("sm_cleartime", CmdClearTime, "Clear record for current map", ADMFLAG_ROOT);
	
	// init SQLite Database
	ConnectDB();
}

// Start CMD
public Action CmdGetMapTime(int client, int args){
	if (client == 0 || !IsClientConnected(client) && !IsClientInGame(client))
		return Plugin_Handled;
		
	if(MapTimingDisabled)
	{
		PrintToChat(client, "\x04[\x03Timer\x04] \x01Timer is disabled.");
		return Plugin_Handled;
	}
		
	float TotalTime = GetEngineTime() - MapTimingStartTime;
	int IntTotalTime = RoundToNearest(TotalTime);
	
	if (MapTimingStartTime == 0.0)
		PrintToChat(client, "\x04[\x03Timer\x04] \x01Timer has not started yet.");
	else if (IntTotalTime > 3600) 
		PrintToChat(client, "\x04[\x03Timer\x04] \x01Time Passed: %iH:%iM:%iS", (IntTotalTime/3600)%24, (IntTotalTime/60)%60, IntTotalTime%60);
	else
		PrintToChat(client, "\x04[\x03Timer\x04] \x01Time Passed: %iM:%iS", (IntTotalTime/60)%60, IntTotalTime%60);
	
	
	return Plugin_Handled;
}

public Action CmdGetMapBestTime(int client, int args){
	if (client == 0 || !IsClientConnected(client) && !IsClientInGame(client))
		return Plugin_Handled;
	
	if(MapTimingDisabled)
	{
		PrintToChat(client, "\x04[\x03Timer\x04] \x01Timer is disabled.");
		return Plugin_Handled;
	}
	
	new String:CurrentMapName[MAX_LINE_WIDTH];
	CurrentMapName = getMapName();
	new String:Difficulty[MAX_LINE_WIDTH];
	Difficulty = getDifficulty();
	int IntDifficulty = getDifficultyInt();
	
	new String:error[255];
	dbTimer = SQL_Connect(DB_NAME, true, error, sizeof(error));
	if (dbTimer == INVALID_HANDLE)
	{
		PrintToServer("[Timer] Could not connect to db: %s", error);
	} else {
		int mapId = DBCheckMapExist(dbTimer, CurrentMapName, IntDifficulty);
		if(mapId != 0){
			int BestTime = DBGetMapTime(dbTimer, CurrentMapName, IntDifficulty);
			if(BestTime == 0)
			{
				PrintToChat(client, "\x04[\x03Timer\x04] \x01Best time on %s(%s): NONE", CurrentMapName, Difficulty);
			}
			else
			{			
				new String:BestPlayers[1024];
				
				BestPlayers = DBGetBestPlayer(dbTimer, mapId, IntDifficulty);
				
				if (BestTime > 3600)
				{
					PrintToChat(client, "\x04[\x03Timer\x04] \x01Best time on %s(%s): %iH:%iM:%iS\nAchieved by:\n%s", CurrentMapName, Difficulty, (BestTime/3600)%24, (BestTime/60)%60, BestTime%60, BestPlayers);
				}
				else
				{
					PrintToChat(client, "\x04[\x03Timer\x04] \x01Best time on %s(%s): %iM:%iS\nAchieved by:\n%s", CurrentMapName, Difficulty, (BestTime/60)%60, BestTime%60, BestPlayers);
				}
			}
		}
		else
		{
			PrintToChat(client, "\x04[\x03Timer\x04] \x01Best time on %s(%s): NONE", CurrentMapName, Difficulty);
		}
		CloseHandle(dbTimer);			// close db handle
	}
	
	return Plugin_Handled;
}

public Action CmdGetClientList(int client, int args){
	if (client == 0 || !IsClientConnected(client) && !IsClientInGame(client))
		return Plugin_Handled;
	
	PrintToChat(client, "Current players in the server:\n%s", getClientList());
	
	return Plugin_Handled;
}

public Action CmdStartTimer(int client, int args){
	if (client == 0 || !IsClientConnected(client) && !IsClientInGame(client))
		return Plugin_Handled;
	
	if(MapTimingDisabled)
	{
		PrintToChat(client, "\x04[\x03Timer\x04] \x01Timer is disabled. Type !timerenable to use this plugin");
		return Plugin_Handled;
	}
	
	StartTimer();
	
	return Plugin_Handled;
}

public Action CmdStopTimer(int client, int args){
	if (client == 0 || !IsClientConnected(client) && !IsClientInGame(client))
		return Plugin_Handled;
	
	if(MapTimingDisabled)
	{
		PrintToChat(client, "\x04[\x03Timer\x04] \x01Timer is disabled. Type !timerenable to use this plugin");
		return Plugin_Handled;
	}
	
	StopTimer(false);
	
	return Plugin_Handled;
}

public Action CmdEnableTimer(int client, int args){
	if (client == 0 || !IsClientConnected(client) && !IsClientInGame(client))
		return Plugin_Handled;
	
	MapTimingDisabled = false;
	
	return Plugin_Handled;
}

public Action CmdDisableTimer(int client, int args){
	if (client == 0 || !IsClientConnected(client) && !IsClientInGame(client))
		return Plugin_Handled;
	
	MapTimingDisabled = true;
	
	return Plugin_Handled;
}

public Action CmdClearTimeAll(int client, int args){
	if (client == 0 || !IsClientConnected(client) && !IsClientInGame(client))
		return Plugin_Handled;
	
	DBClearTimer(true);
	
	return Plugin_Handled;
}

public Action CmdClearTime(int client, int args){
	if (client == 0 || !IsClientConnected(client) && !IsClientInGame(client))
		return Plugin_Handled;
	
	DBClearTimer(false);
	
	return Plugin_Handled;
}
// End CMD

// Start Events
public Action:event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	MapTimingStartTime = 0.0;
	MapTimingDisabled = false;
}

// Saferoom door opens.
public Action:event_DoorOpen(Handle:event, String:name[], bool:dontBroadcast)
{
	if(MapTimingDisabled || MapTimingStartTime != 0.0 || !GetEventBool(event, "checkpoint") || !GetEventBool(event, "closed") || !IsGamemodeCoop())
	{
		return Plugin_Continue;
	}

	StartTimer();

	return Plugin_Continue;
}

public Action:event_StartArea(Handle:event, String:name[], bool:dontBroadcast)
{
	if(MapTimingDisabled || MapTimingStartTime != 0.0 || !IsGamemodeCoop())
	{
		return Plugin_Continue;
	}

	StartTimer();

	return Plugin_Continue;
}

public Action:event_MapEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	StopTimer(true);
	
	return;
}

public action_DifficultyChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (convar == cvar_Difficulty && MapTimingStartTime > 0.0)
	{
		MapTimingStartTime = 0.0;
		MapTimingDisabled = true;
	}
	
	if(MapTimingDisabled)
		PrintToChatAll("\x04[\x03Timer\x04] \x01Difficulty changed, map timer stopped.");
}
// End Events


// Start Timer
public void StartTimer(){
	if (MapTimingDisabled || MapTimingStartTime != 0.0 || !IsGamemodeCoop())
	{
		return;
	}
	
	MapTimingStartTime = GetEngineTime();
	PrintToChatAll("\x04[\x03Timer\x04] \x01Map Timer started.");
}

public void StopTimer(bool isAuto){
	if (MapTimingDisabled || MapTimingStartTime <= 0.0 || !IsGamemodeCoop())
	{
		return;
	}
	
	float TotalTime = GetEngineTime() - MapTimingStartTime;
	int IntTotalTime = RoundToNearest(TotalTime);
	
	new String:CurrentMapName[MAX_LINE_WIDTH];
	CurrentMapName = getMapName();
	new String:Difficulty[MAX_LINE_WIDTH];
	Difficulty = getDifficulty();
	
	if (IntTotalTime > 3600) 
		("\x04[\x03Timer\x04] \x01Map Timer Stopped. Time for %s(%s): %iH:%iM:%iS\nBy:\n%s", CurrentMapName, Difficulty, (IntTotalTime/3600)%24, (IntTotalTime/60)%60, IntTotalTime%60, getClientList());
	else
		PrintToChatAll("\x04[\x03Timer\x04] \x01Map Timer Stopped. Time for %s(%s): %iM:%iS\nBy:\n%s", CurrentMapName, Difficulty, (IntTotalTime/60)%60, IntTotalTime%60, getClientList());
	
	if(isAuto){
		int IntDifficulty = getDifficultyInt();
			
		// save data to DB
		new String:error[255];
		dbTimer = SQL_Connect(DB_NAME, true, error, sizeof(error));
		if (dbTimer == INVALID_HANDLE)
		{
			PrintToServer("[Timer] Could not connect to db: %s", error);
		} else {
			int mapId = DBCheckMapExist(dbTimer, CurrentMapName, IntDifficulty);
			if(mapId != 0){
				// Check best time
				int BestTime = DBGetMapTime(dbTimer, CurrentMapName, IntDifficulty);
				if(IntTotalTime < BestTime || BestTime == 0)
				{
					DBUpdate(dbTimer, mapId, IntDifficulty, IntTotalTime);
				}
				else
				{
					PrintToChatAll("You did not break the old record.");
				}
			}
			else
			{
				DBInsertMap(dbTimer, CurrentMapName, IntDifficulty);
				mapId = DBCheckMapExist(dbTimer, CurrentMapName, IntDifficulty);
				
				DBUpdate(dbTimer, mapId, IntDifficulty, IntTotalTime);
			}
			CloseHandle(dbTimer);			// close db handle
		}
	}
	
	MapTimingStartTime = 0.0;
}
// End Timer

bool:IsClientBot(client)
{
	if (client == 0 || !IsClientConnected(client))
		return true;
	
	return false;
}
bool:IsGamemodeCoop()
{
	new String:CurrentMode[16];
	cvar_Gamemode = FindConVar("mp_gamemode");
	GetConVarString(cvar_Gamemode, CurrentMode, sizeof(CurrentMode));
	if (StrEqual(CurrentMode, "coop", false))
	{
		return true;
	}

	return false;
}

String:getClientList(){
	int maxplayers = GetMaxClients();
	new String:ClientList[1024];
	
	for (new i = 1; i <= maxplayers; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && !IsClientBot(i) && GetClientTeam(i) == TEAM_SURVIVOR)
		{
			decl String:ClientUserName[MAX_TARGET_LENGTH];
			GetClientName(i, ClientUserName, sizeof(ClientUserName));
			StrCat(ClientList, 1024, ClientUserName);
			StrCat(ClientList, 1024, ",");
		}
	}
	
	// if the last char is ",", remove it
	int len = strlen(ClientList);
	if(StrEqual(ClientList[len-1], ",", true))
		ClientList[len - 1] = 0;
		
	return ClientList;
}

String:getMapName(){
	new String:CurrentMapName[MAX_LINE_WIDTH];
	GetCurrentMap(CurrentMapName, sizeof(CurrentMapName));
	return CurrentMapName;
}

String:getDifficulty(){
	new String:Difficulty[MAX_LINE_WIDTH];
	GetConVarString(cvar_Difficulty, Difficulty, sizeof(Difficulty));
	return Difficulty;
}

int getDifficultyInt(){
	new String:Difficulty[MAX_LINE_WIDTH];
	Difficulty = getDifficulty();
	int IntDifficulty = 2;
	if(StrEqual(Difficulty, "Easy", false))
		IntDifficulty = Difficulty_Easy;
	if(StrEqual(Difficulty, "Normal", false))
		IntDifficulty = Difficulty_Normal;
	if(StrEqual(Difficulty, "Hard", false))
		IntDifficulty = Difficulty_Hard;
	if(StrEqual(Difficulty, "Impossible", false))
		IntDifficulty = Difficulty_Expert;
	return IntDifficulty;
}

// Start DB
ConnectDB(){
	new String:error[255];
	new String:query[512];
	
	dbTimer = SQL_Connect(DB_NAME, true, error, sizeof(error));
	if (dbTimer == INVALID_HANDLE)
	{
		PrintToServer("[Timer] Could not connect to db: %s", error);
	} else {
		// Create table 'Map' if not exist
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS 'Map' ( 'id' INTEGER PRIMARY KEY AUTOINCREMENT, 'name' VARCHAR(255) NOT NULL, 'difficulty' INTEGER NOT NULL, 'time' INTEGER)");
		if (!SQL_Query(dbTimer, query))
		{
			SQL_GetError(dbTimer, error, sizeof(error));
			PrintToServer("[Timer] Failed to query (Error: %s)", error);
		}
		else
		{
			PrintToServer("[Timer] Table Map created if not exist");
		}
	
		// Create table 'Player' if not exist
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS 'Player' ( 'id' INTEGER PRIMARY KEY AUTOINCREMENT, 'name' VARCHAR(255) NOT NULL)");
		if (!SQL_Query(dbTimer, query))
		{
			SQL_GetError(dbTimer, error, sizeof(error));
			PrintToServer("[Timer] Failed to query (Error: %s)", error);
		}
		else
		{
			PrintToServer("[Timer] Table Player created if not exist");
		}
	
		// Create table 'Record' if not exist
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS 'Record' ( 'id' INTEGER PRIMARY KEY AUTOINCREMENT, 'map_id' INTEGER NOT NULL, 'player_id' INTEGER NOT NULL, 'difficulty' INTEGER NOT NULL)");
		if (!SQL_Query(dbTimer, query))
		{
			SQL_GetError(dbTimer, error, sizeof(error));
			PrintToServer("[Timer] Failed to query (Error: %s)", error);
		}
		else
		{
			PrintToServer("[Timer] Table Record created if not exist");
		}
		CloseHandle(dbTimer);			// close db handle
	}
}

int DBCheckPlayerExist(Handle:db, char[] name){
	new String:query[100];
	int result = 0;
	Format(query, sizeof(query), "SELECT id FROM Player WHERE name = '%s'", name);
	
	new Handle:hQuery = SQL_Query(db, query);
	if (hQuery == INVALID_HANDLE)
	{
		return 0;
	}
	
	if (SQL_FetchRow(hQuery))
	{
		result = SQL_FetchInt(hQuery, 0, result);
	}
	
	return result;
}

int DBCheckMapExist(Handle:db, char[] map, int difficulty){
	new String:query[100];
	int result = 0;
	Format(query, sizeof(query), "SELECT id FROM Map WHERE name = '%s' AND difficulty = %i", map, difficulty);
	
	new Handle:hQuery = SQL_Query(db, query);
	if (hQuery == INVALID_HANDLE)
	{
		return 0;
	}
	
	if (SQL_FetchRow(hQuery))
	{
		result = SQL_FetchInt(hQuery, 0, result);
	}
	
	return result;
}

int DBGetMapTime(Handle:db, char[] map, int difficulty){
	new String:query[100];
	int result;
	Format(query, sizeof(query), "SELECT time FROM Map WHERE name = '%s' AND difficulty = %i", map, difficulty);
	
	new Handle:hQuery = SQL_Query(db, query);
	if (hQuery == INVALID_HANDLE)
	{
		return 0;
	}
	if(SQL_FetchRow(hQuery))
	{
		result = SQL_FetchInt(hQuery, 0, result);
	}
	return result;
}

String:DBGetBestPlayer(Handle:db, int mapId, int difficulty){
	new String:ClientList[1024];
	new String:query[200];
	new String:temp[255];
	Format(query, sizeof(query), "SELECT Player.name FROM Record JOIN Player ON Record.player_id = Player.id JOIN Map ON Map.id = Record.map_id WHERE Map.id = '%i' AND Map.difficulty = %i", mapId, difficulty);
	
	new Handle:hQuery = SQL_Query(db, query);
	if (hQuery == INVALID_HANDLE)
	{
		return ClientList;
	}
	while(SQL_FetchRow(hQuery))
	{
		SQL_FetchString(hQuery, 0, temp, 255);
		StrCat(ClientList, 1024, temp);
		StrCat(ClientList, 1024, ",");
	}
	// if the last char is ",", remove it
	int len = strlen(ClientList);
	if(StrEqual(ClientList[len-1], ",", true))
		ClientList[len - 1] = 0;
	
	return ClientList;
}

DBInsertPlayer(Handle:db, char[] name){
	new String:query[100];
	Format(query, sizeof(query), "INSERT INTO Player ('name') VALUES ('%s')", name);
	if (!SQL_FastQuery(db, query))
	{
		new String:error[255];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("[Timer] Failed to query (error: %s)", error);
	}
}

DBInsertMap(Handle:db, char[] name, int difficulty){
	new String:query[100];
	Format(query, sizeof(query), "INSERT INTO Map ('name', 'difficulty') VALUES ('%s', %i)", name, difficulty);
	if (!SQL_FastQuery(db, query))
	{
		new String:error[255];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("[Timer] Failed to query (error: %s)", error);
	}
}

DBUpdate(Handle:db, int mapId, int difficulty, int bestTime){
	new String:query[128];
	// Update best time
	Format(query, sizeof(query), "UPDATE Map SET 'time' = %i WHERE id = %i", bestTime, mapId);
	if (!SQL_FastQuery(db, query))
	{
		new String:error[255];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("[Timer] Failed to query (error: %s)", error);
	}
	
	
	// Delete exist record
	Format(query, sizeof(query), "DELETE FROM Record WHERE map_id = %i and difficulty = %i", mapId, difficulty);
	if (!SQL_FastQuery(db, query))
	{
		new String:error[255];
		SQL_GetError(db, error, sizeof(error));
		PrintToServer("[Timer] Failed to query (error: %s)", error);
	}
	
	// Add new record
	int maxplayers = GetMaxClients();
	for (new i = 1; i <= maxplayers; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && !IsClientBot(i) && GetClientTeam(i) == TEAM_SURVIVOR)
		{
			decl String:ClientUserName[MAX_TARGET_LENGTH];
			GetClientName(i, ClientUserName, sizeof(ClientUserName));
			int playerId = DBCheckPlayerExist(db, ClientUserName);
			if(playerId == 0){
				DBInsertPlayer(db, ClientUserName);
				playerId = DBCheckPlayerExist(db, ClientUserName);
			}
			
			Format(query, sizeof(query), "INSERT INTO Record ('map_id', 'player_id', 'difficulty') VALUES (%i, %i, %i)", mapId, playerId, difficulty);
			if (!SQL_FastQuery(db, query))
			{
				new String:error[255];
				SQL_GetError(db, error, sizeof(error));
				PrintToServer("[Timer] Failed to query (error: %s)", error);
			}
		}
	}
	PrintToServer("[Timer] Map Record Updated");
	PrintToChatAll("You set a new record.");
}

DBClearTimer(bool isAll){
	new String:error[255];
	new String:CurrentMapName[MAX_LINE_WIDTH];
	CurrentMapName = getMapName();
	new String:Difficulty[MAX_LINE_WIDTH];
	Difficulty = getDifficulty();
	int IntDifficulty = getDifficultyInt();
	int mapId;
	
	dbTimer = SQL_Connect(DB_NAME, true, error, sizeof(error));
	if (dbTimer == INVALID_HANDLE)
	{
		PrintToServer("[Timer] Could not connect to db: %s", error);
	} else {
		new String:query[100];
		// Delete best player from Record Table
		if(isAll)
		{
			query = "DELETE FROM Record";
		}
		else
		{
			mapId = DBCheckMapExist(dbTimer, CurrentMapName, IntDifficulty);
			
			Format(query, sizeof(query), "DELETE FROM Record WHERE map_id = %i AND difficulty = %i", mapId, IntDifficulty);
		}
		if (!SQL_FastQuery(dbTimer, query))
		{
			SQL_GetError(dbTimer, error, sizeof(error));
			PrintToServer("[Timer] Failed to query (error: %s)", error);
		}
		
		// Delete time record from Map table
		if(isAll)
		{
			query = "UPDATE 'Map' SET 'time' = 0";
		}
		else
		{
			mapId = DBCheckMapExist(dbTimer, CurrentMapName, IntDifficulty);
			
			Format(query, sizeof(query), "UPDATE 'Map' SET time = 0 WHERE id = %i AND difficulty = %i", mapId, IntDifficulty);
		}
		if (!SQL_FastQuery(dbTimer, query))
		{
			SQL_GetError(dbTimer, error, sizeof(error));
			PrintToServer("[Timer] Failed to query (error: %s)", error);
		}
		
		CloseHandle(dbTimer);			// close db handle
	}
}
// End DB

// Start Menu
public OnAdminMenuReady(Handle:topmenu)
{
	/* If the category is third party, it will have its own unique name. */
	new TopMenuObject:server_commands = FindTopMenuCategory(topmenu, ADMINMENU_SERVERCOMMANDS); 
	if (server_commands == INVALID_TOPMENUOBJECT)
	{
		/* Error! */
		LogError("server_commands == INVALID_TOPMENUOBJECT");
		return;
	}
 
	AddToTopMenu(topmenu, 
		"Map Timer",
		TopMenuObject_Item,
		AdminMenu_MapTimer,
		server_commands,
		"sm_admintimer",
		ADMFLAG_CONFIG);
} 

public AdminMenu_MapTimer(Handle:topmenu, 
			TopMenuAction:action,
			TopMenuObject:object_id,
			param,
			String:buffer[],
			maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Map Timer");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		Menu_MapTimer(param);
	}
}

public Action:Menu_MapTimer(client)
{
	new Handle:menu = CreateMenu(Menu_MapTimerHandler);
	SetMenuTitle(menu, "Map Timer:");
	AddMenuItem(menu, "Start Timer", "Start Timer");
	AddMenuItem(menu, "Start Timer", "Stop Timer");
	AddMenuItem(menu, "Enable Timer", "Enable Timer");
	AddMenuItem(menu, "Disable Timer", "Disable Timer");
	AddMenuItem(menu, "Clear record on current map and difficulty", "Clear record (current map)");
	AddMenuItem(menu, "Clear all record in the database", "Clear all record");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 20);
	return Plugin_Handled;
}

public Menu_MapTimerHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0:
		    	StartTimer();
			case 1:
		    	StopTimer(false);
			case 2:
				MapTimingDisabled = false;
			case 3:
				MapTimingDisabled = true;
			case 4:
				DBClearTimer(false);
			case 5:
				DBClearTimer(true);
		}
	}
	/* If the menu was cancelled, print a message to the server about it. */
	else if (action == MenuAction_Cancel)
	{
		PrintToServer("Client %d's menu was cancelled.  Reason: %d", param1, param2);
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}
// End Menu