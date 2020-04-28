#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Vortéx!"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <store>
#include <sdkhooks>
#include <clientprefs>
#include <smlib>
#include <cstrike>
#include <multicolors>
#include "emitsoundany.inc"


char resim[MAXPLAYERS + 1][256];
char ses[MAXPLAYERS + 1][256];

Database h_dbConnection = null;
Handle mincredits = INVALID_HANDLE;

char SOUNDS_PACK[][] = {
"TurkModders/Donate/ses_1.mp3",
"TurkModders/Donate/ses_2.mp3",
"TurkModders/Donate/ses_3.mp3",
"TurkModders/Donate/ses_4.mp3",
"TurkModders/Donate/ses_5.mp3",
"TurkModders/Donate/ses_6.mp3",
"TurkModders/Donate/ses_7.mp3",
"TurkModders/Donate/ses_8.mp3",
"TurkModders/Donate/ses_9.mp3",
"TurkModders/Donate/ses_10.mp3",};

public Plugin myinfo = 
{
	name = "Donate Plugin",
	author = PLUGIN_AUTHOR,
	description = "Market plugini aracılığıyla oyuncular birbirine bağışta bulunabilir.",
	version = PLUGIN_VERSION,
	url = "turkmodders.com"
};

public void OnPluginStart()
{
	dbConnect();
	mincredits = CreateConVar("turkmodders_min_donate", "10", "Minimum donate miktari");
	RegConsoleCmd("sm_donate", donate);
	RegConsoleCmd("sm_bagis", donate);
}

public OnMapStart() {
	char file[256];
	BuildPath(Path_SM, file, 255, "configs/donate_resimler.ini");
	Handle fileh = OpenFile(file, "r");
	if (fileh != INVALID_HANDLE)
	{
		char buffer[256];
		char buffer_full[PLATFORM_MAX_PATH];

		while(ReadFileLine(fileh, buffer, sizeof(buffer)))
		{
			TrimString(buffer);
			if ( (StrContains(buffer, "//") == -1) && (!StrEqual(buffer, "")) )
			{
				PrintToServer("Reading overlay_downloads line :: %s", buffer);
				Format(buffer_full, sizeof(buffer_full), "%s", buffer);
				if (FileExists(buffer_full))
				{
					PrintToServer("Precaching %s", buffer);
					PrecacheDecal(buffer, true);
					AddFileToDownloadsTable(buffer_full);
				}
			}
		}
	}
	
	for(new i = 0;i<sizeof(SOUNDS_PACK);i++){
		PrecacheSound(SOUNDS_PACK[i]);
	}
}

public void dbConnect() {
	
		char szError[200];
		
		KeyValues hKv = CreateKeyValues("donate-turkmodders", "", "");
		hKv.SetString("driver", "sqlite");
		hKv.SetString("database", "donate-turkmodders");
		
		h_dbConnection = SQL_ConnectCustom(hKv, szError, 200, false); delete hKv;
		
		if (h_dbConnection != null) {
			LogError("DONATE :: %s", szError);
			dbCreateTables();
		}
}

public void dbConnectCallback(Database dbConn, const char[] error, any data) {

  if (dbConn != null) {
    h_dbConnection = dbConn;
    dbCreateTables();
  } else {
    h_dbConnection = null;
    LogError("DONATE :: %s", error);
  }
}

public void dbCreateTables() {

  char query[512];

  Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `turkmodders_donate` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `steamid` VARCHAR(18), `resim` VARCHAR(255), `ses` VARCHAR(255), `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP);");
  SQL_FastQuery(h_dbConnection, query); 
}

public void dbCreateTablesCallback(Database dbConn, DBResultSet results, const char[] error, any data) {

  if (results == null) {
    h_dbConnection = null;
    LogError("DONATE :: %s", error);
  }
}

public void dbGetClientData(int client) {

  if (!IsValidClient(client) || h_dbConnection == null)
    return;

  char query[512];
  char steamId[18];

  GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId));

  Format(query, sizeof(query), "SELECT resim, ses FROM turkmodders_donate WHERE steamid = '%s'", steamId);
  h_dbConnection.Query(dbGetClientDataCallback, query, client);
}

public void dbGetClientDataCallback(Database dbConn, DBResultSet results, const char[] error, int client) {
  if (results.FetchRow()) {
	results.FetchString(0, resim[client], sizeof(resim[]));
	results.FetchString(1, ses[client], sizeof(ses[]));
  } else {
    dbCreateNewClient(client);
  }
}

public void dbCreateNewClient(int client) {

  if (!IsValidClient(client) || h_dbConnection == null)
    return;

  char query[512];
  char steamId[18];

  GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId));


  Format(query, sizeof(query), "INSERT INTO turkmodders_donate (`steamid`, `resim`, `ses`) VALUES ('%s', '', '')", steamId);
  h_dbConnection.Query(dbNothingCallback, query, client);
  resim[client] = "";
  ses[client] = "";
  FormatEx(resim[client], sizeof(resim[]), "");
  FormatEx(ses[client], sizeof(ses[]), "");
}

public void dbSaveClientData(int client) {

  if (IsValidClient(client, false) && h_dbConnection != null) {

    char query[512];
    char steamId[18];

    GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId));

    Format(query, sizeof(query), "UPDATE `turkmodders_donate` SET `resim`= %s, `ses`= %s, `updated_at` = datetime('now') WHERE steamid = '%s'", resim[client], ses[client], steamId);
    h_dbConnection.Query(dbNothingCallback, query, client);

  }
}

public void dbNothingCallback(Database dbConn, DBResultSet results, const char[] error, int client) {

  if (results == null) {

      LogError("DONATE :: %s", error);
  }
}

public void OnClientPostAdminCheck(int client) {

    dbGetClientData(client);
}

public void OnClientDisconnect(int client)
{
	if(!IsFakeClient(client)) dbSaveClientData(client);
}

public void OnPluginEnd()
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			OnClientDisconnect(client);
		}
	}
}

public Action donate(int client, int args) {
	if(args < 2)
	{
		donatemenu(client);
	}
	else
	{
		char name[256];
		GetClientName(client, name, sizeof(name));
		char arg1[32];
		GetCmdArg(1, arg1, sizeof(arg1));
		char arg2[32];
		GetCmdArg(2, arg2, sizeof(arg2));
		int target = FindTarget(client, arg1);
		char hedef[64];
		GetClientName(target, hedef, sizeof(hedef));
		
		if (target == -1)
		{
			CPrintToChat(client, "{darkred}[TurkModders] {darkblue}Hedef bulunamadı.");
			return Plugin_Handled;
		}
		
		
		int miktar = StringToInt(arg2);
		if(miktar < GetConVarInt(mincredits))
		{
			CPrintToChat(client, "{darkred}[TurkModders] {darkblue}Minimum %i kredi bağış yapabilirsiniz.", GetConVarInt(mincredits));
			return Plugin_Handled;
		}
		
		if(Store_GetClientCredits(client) < miktar)
		{
			CPrintToChat(client, "{darkred}[TurkModders] {darkblue}Hesabınızda yeterli kredi bulunmuyor.");
			return Plugin_Handled;
		}
		
		
		Store_SetClientCredits(client, miktar - Store_GetClientCredits(client));
		Store_SetClientCredits(target, miktar + Store_GetClientCredits(target));
		
		if(!StrEqual(ses[target], "") && !StrEqual(resim[target], ""))
		{
			EmitSoundToAll(ses[target]); 
			ShowOverlayToAll(resim[target]);
			CreateTimer(7.0, sil);
		}
		else 
		{ 
			CPrintToChat(target, "{darkred}[TurkModders] {darkblue}Donate için resim ve ses dosyası seçmediğiniz için sadece ekranda donate bildiri mesajı görüntülendi. !donate yazıp seçebilirsiniz."); 
		}
		
		char mesaj[256];
		Format(mesaj, sizeof(mesaj), "%s tarafından %i kredi %s'e bağış yapıldı!", name, miktar, hedef);
		for (new x = 1; x <= MaxClients; x++)
		{
			if (IsClientInGame(x) && !IsFakeClient(x))
			{
				int ent = CreateEntityByName("game_text");
				DispatchKeyValue(ent, "channel", "1");
				DispatchKeyValue(ent, "color", "255 165 0");
				DispatchKeyValue(ent, "color2", "0 0 0");
				DispatchKeyValue(ent, "effect", "0");
				DispatchKeyValue(ent, "fadein", "1.5");
				DispatchKeyValue(ent, "fadeout", "0.5");
				DispatchKeyValue(ent, "fxtime", "0.25"); 		
				DispatchKeyValue(ent, "holdtime", "7.0");
				DispatchKeyValue(ent, "message", mesaj);
				DispatchKeyValue(ent, "spawnflags", "0"); 	
				DispatchKeyValue(ent, "x", "-1.0");
				DispatchKeyValue(ent, "y", "1.0"); 		
				DispatchSpawn(ent);
				SetVariantString("!activator");
				AcceptEntityInput(ent,"display",x);
			}
		}
		
		
	}
	return Plugin_Handled;
}

public Action sil(Handle timer)
{
	ShowOverlayToAll("");
}

public Action donatemenu(int client)
{
    Handle menu = CreateMenu(MenuCallBack);
    SetMenuTitle(menu, "★ Bağış (Donate) Sistemi ★");
    char opcionmenu[124];

    Format(opcionmenu, 124, "✦ Bağış Yap");
    AddMenuItem(menu, "option0", opcionmenu);
    
    if(StrEqual(resim[client], ""))
    {
    	Format(opcionmenu, 124, "✦ Bağış Resmi Seç");
   	}
   	else if(StrEqual(resim[client], "TurkModders/Donate/resim_1"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Resmi Seç: Altın İçinde");
   	}
   	else if(StrEqual(resim[client], "TurkModders/Donate/resim_2"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Resmi Seç: Para Yağmuru");
   	}
   	else if(StrEqual(resim[client], "TurkModders/Donate/resim_3"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Resmi Seç: Para Fırlatan Kız");
   	}
   	else if(StrEqual(resim[client], "TurkModders/Donate/resim_4"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Resmi Seç: Jahrein");
   	}
   	else if(StrEqual(resim[client], "TurkModders/Donate/resim_5"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Resmi Seç: Avuç İçinde Para");
   	}
   	else if(StrEqual(resim[client], "TurkModders/Donate/resim_6"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Resmi Seç: Zombi");
   	}
   	else if(StrEqual(resim[client], "TurkModders/Donate/resim_7"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Resmi Seç: Dolar");
   	}
   	else if(StrEqual(resim[client], "TurkModders/Donate/resim_8"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Resmi Seç: Dolar 2");
   	}
   	else if(StrEqual(resim[client], "TurkModders/Donate/resim_9"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Resmi Seç: Sen Milyar Milyon");
   	}
   	else if(StrEqual(resim[client], "TurkModders/Donate/resim_10"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Resmi Seç: Para Fırlatan Anime");
   	}
   	else if(StrEqual(resim[client], "TurkModders/Donate/resim_11"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Resmi Seç: Cep");
   	}
   	else if(StrEqual(resim[client], "TurkModders/Donate/resim_12"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Resmi Seç: WOW");
   	}
   	else if(StrEqual(resim[client], "TurkModders/Donate/resim_13"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Resmi Seç: Ekmek Reis");
   	}
    
    AddMenuItem(menu, "option1", opcionmenu);
    
    if(StrEqual(ses[client], ""))
    {
    	Format(opcionmenu, 124, "✦ Bağış Müziği Seç");
   	}
    else if(StrEqual(ses[client], "TurkModders/Donate/ses_1.mp3"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Müziği Seç: Money Money Money");
   	}
   	else if(StrEqual(ses[client], "TurkModders/Donate/ses_2.mp3"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Müziği Seç: Twitch Bit");
   	}
   	else if(StrEqual(ses[client], "TurkModders/Donate/ses_3.mp3"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Müziği Seç: Biling");
   	}
   	else if(StrEqual(ses[client], "TurkModders/Donate/ses_4.mp3"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Müziği Seç: Adam");
   	}
   	else if(StrEqual(ses[client], "TurkModders/Donate/ses_5.mp3"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Müziği Seç: Teşekkür Ederim Allahım");
   	}
   	else if(StrEqual(ses[client], "TurkModders/Donate/ses_6.mp3"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Müziği Seç: New Donation");
   	}
   	else if(StrEqual(ses[client], "TurkModders/Donate/ses_7.mp3"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Müziği Seç: Allah Razı Olsun");
   	}
   	else if(StrEqual(ses[client], "TurkModders/Donate/ses_8.mp3"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Müziği Seç: Cash Register");
   	}
   	else if(StrEqual(ses[client], "TurkModders/Donate/ses_9.mp3"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Müziği Seç: Donation Remix");
   	}
   	else if(StrEqual(ses[client], "TurkModders/Donate/ses_10.mp3"))
    {
    	Format(opcionmenu, 124, "✦ Bağış Müziği Seç: Allah Tuttuğunuzu Altın Etsin");
   	}
   	
    AddMenuItem(menu, "option2", opcionmenu);

    SetMenuExitBackButton(menu, true);
    SetMenuPagination(menu, MENU_NO_PAGINATION);
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

public MenuCallBack(Handle menu, MenuAction:action, client, itemNum)
{
    if ( action == MenuAction_Select )
    {
        char info[32];

        GetMenuItem(menu, itemNum, info, sizeof(info));
        if ( strcmp(info,"option0") == 0 )
        {
			CPrintToChat(client, "{darkred}[TurkModders] {darkblue}!donate <isim> <miktar>");
        }
        else if ( strcmp(info,"option1") == 0 )
        {
			if(StrEqual(resim[client], ""))
			{
				FormatEx(resim[client], sizeof(resim[]), "TurkModders/Donate/resim_1");
			}
			else if(StrEqual(resim[client], "TurkModders/Donate/resim_1"))
			{
				FormatEx(resim[client], sizeof(resim[]), "TurkModders/Donate/resim_2");
			}
			else if(StrEqual(resim[client], "TurkModders/Donate/resim_2"))
			{
				FormatEx(resim[client], sizeof(resim[]), "TurkModders/Donate/resim_3");
			}
			else if(StrEqual(resim[client], "TurkModders/Donate/resim_3"))
			{
				FormatEx(resim[client], sizeof(resim[]), "TurkModders/Donate/resim_4");
			}
			else if(StrEqual(resim[client], "TurkModders/Donate/resim_4"))
			{
				FormatEx(resim[client], sizeof(resim[]), "TurkModders/Donate/resim_5");
			}
			else if(StrEqual(resim[client], "TurkModders/Donate/resim_5"))
			{
				FormatEx(resim[client], sizeof(resim[]), "TurkModders/Donate/resim_6");
			}
			else if(StrEqual(resim[client], "TurkModders/Donate/resim_6"))
			{
				FormatEx(resim[client], sizeof(resim[]), "TurkModders/Donate/resim_7");
			}
			else if(StrEqual(resim[client], "TurkModders/Donate/resim_7"))
			{
				FormatEx(resim[client], sizeof(resim[]), "TurkModders/Donate/resim_8");
			}
			else if(StrEqual(resim[client], "TurkModders/Donate/resim_8"))
			{
				FormatEx(resim[client], sizeof(resim[]), "TurkModders/Donate/resim_9");
			}
			else if(StrEqual(resim[client], "TurkModders/Donate/resim_9"))
			{
				FormatEx(resim[client], sizeof(resim[]), "TurkModders/Donate/resim_10");
			}
			else if(StrEqual(resim[client], "TurkModders/Donate/resim_10"))
			{
				FormatEx(resim[client], sizeof(resim[]), "TurkModders/Donate/resim_11");
			}
			else if(StrEqual(resim[client], "TurkModders/Donate/resim_11"))
			{
				FormatEx(resim[client], sizeof(resim[]), "TurkModders/Donate/resim_12");
			}
			else if(StrEqual(resim[client], "TurkModders/Donate/resim_12"))
			{
				FormatEx(resim[client], sizeof(resim[]), "TurkModders/Donate/resim_13");
			}
			else if(StrEqual(resim[client], "TurkModders/Donate/resim_13"))
			{
				FormatEx(resim[client], sizeof(resim[]), "TurkModders/Donate/resim_1");
			}
			
			donatemenu(client);
			
        }
        else if ( strcmp(info,"option2") == 0 )
        {
			
			if(StrEqual(ses[client], ""))
			{
				FormatEx(ses[client], sizeof(ses[]), "TurkModders/Donate/ses_1.mp3");
			}
			else if(StrEqual(ses[client], "TurkModders/Donate/ses_1.mp3"))
			{
				FormatEx(ses[client], sizeof(ses[]), "TurkModders/Donate/ses_2.mp3");
			}
			else if(StrEqual(ses[client], "TurkModders/Donate/ses_2.mp3"))
			{
				FormatEx(ses[client], sizeof(ses[]), "TurkModders/Donate/ses_3.mp3");
			}
			else if(StrEqual(ses[client], "TurkModders/Donate/ses_3.mp3"))
			{
				FormatEx(ses[client], sizeof(ses[]), "TurkModders/Donate/ses_4.mp3");
			}
			else if(StrEqual(ses[client], "TurkModders/Donate/ses_4.mp3"))
			{
				FormatEx(ses[client], sizeof(ses[]), "TurkModders/Donate/ses_5.mp3");
			}
			else if(StrEqual(ses[client], "TurkModders/Donate/ses_5.mp3"))
			{
				FormatEx(ses[client], sizeof(ses[]), "TurkModders/Donate/ses_6.mp3");
			}
			else if(StrEqual(ses[client], "TurkModders/Donate/ses_6.mp3"))
			{
				FormatEx(ses[client], sizeof(ses[]), "TurkModders/Donate/ses_7.mp3");
			}
			else if(StrEqual(ses[client], "TurkModders/Donate/ses_7.mp3"))
			{
				FormatEx(ses[client], sizeof(ses[]), "TurkModders/Donate/ses_8.mp3");
			}
			else if(StrEqual(ses[client], "TurkModders/Donate/ses_8.mp3"))
			{
				FormatEx(ses[client], sizeof(ses[]), "TurkModders/Donate/ses_9.mp3");
			}
			else if(StrEqual(ses[client], "TurkModders/Donate/ses_9.mp3"))
			{
				FormatEx(ses[client], sizeof(ses[]), "TurkModders/Donate/ses_10.mp3");
			}
			else if(StrEqual(ses[client], "TurkModders/Donate/ses_10.mp3"))
			{
				FormatEx(ses[client], sizeof(ses[]), "TurkModders/Donate/ses_1.mp3");
			}
			
			donatemenu(client);
			
        }
    }
    
}

ShowOverlayToAll(const char[] overlaypath)
{
	for (new x = 1; x <= MaxClients; x++)
	{
		if (IsClientInGame(x) && !IsFakeClient(x))
		{
			ShowOverlayToClient(x, overlaypath);
		}
	}
}

ShowOverlayToClient(client, const char[] overlaypath)
{
	ClientCommand(client, "r_screenoverlay \"%s\"", overlaypath);
}

bool IsValidClient(int client, bool connected = true) {

  return (client > 0 && client <= MaxClients && (connected  == false || IsClientConnected(client))  && IsClientInGame(client) && !IsFakeClient(client));
}