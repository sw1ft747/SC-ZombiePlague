/** [SZP] Sven Zombie Plague BETA
 * RockTheVote
 * Author: Sw1ft
*/

//-----------------------------------------------------------------------------
// Vars
//-----------------------------------------------------------------------------

const float RTV_MAP_CHANGE_PLAYERS_PERCENTAGE = 0.5f; // 50 %

bool g_bMapChangingRTV = false;

array<bool> g_bVotedInRTV(33, false);
array<int> g_iVotedMap(33, -1);
array<CTextMenu@> g_MenuRTV(33, null);
array<string> g_sMapsRTV;

const array<string> RTV_COUNTDOWN_SND =
{
    "fvox/one.wav",
    "fvox/two.wav",
    "fvox/three.wav",
    "fvox/four.wav",
    "fvox/five.wav",
    "fvox/six.wav",
    "fvox/seven.wav",
    "fvox/eight.wav",
    "fvox/nine.wav",
    "fvox/ten.wav"
};

//-----------------------------------------------------------------------------
// Purpose: countdown voice notification
//-----------------------------------------------------------------------------

void RTV_CountdownTask(string sMap, int iNumber)
{
    if ( iNumber > 0 )
    {
        // Play notification
        if ( iNumber <= 10 )
            UTIL_PlaySound( RTV_COUNTDOWN_SND[iNumber - 1] );

        g_Scheduler.SetTimeout("RTV_CountdownTask", 1.0f, sMap, iNumber - 1);
    }
    // else if ( ZP_IsRunning() && sMap == "choose_campaign_4" )
    // {
    //     ZP_TogglePlugin( null, true, 0, true, "choose_campaign_4" );
    // }
    // else if ( !ZP_IsRunning() && sMap != "choose_campaign_4" )
    // {
    //     ZP_TogglePlugin( null, true, 1, true, sMap );
    // }
    else
    {
        g_EngineFuncs.ServerCommand("changelevel \"" + sMap + "\"\n");
        g_bMapChangingRTV = false;
    }
}

//-----------------------------------------------------------------------------
// Purpose: nominate map
//-----------------------------------------------------------------------------

void RTV_Nominate( CBasePlayer@ pPlayer, int iMap, string sMap )
{
    if ( g_bMapChangingRTV )
        return;

    int idx = pPlayer.entindex();

    if ( g_iVotedMap[ idx ] == iMap )
    {
        g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[RTV] You have already nominated map \"" + sMap + "\".\n" );
        return;
    }

    g_bVotedInRTV[ idx ] = true;
    g_iVotedMap[ idx ] = iMap;

    CBasePlayer@ plr = null;

    float iPlayersCount = 0.0f;
    float iNominatedPlayersCount = 0.0f;

    float flPercentage = 0.0f;

	for (int i = 1; i <= g_Engine.maxClients; ++i)
	{
		@plr = g_PlayerFuncs.FindPlayerByIndex(i);
	
		if ( plr is null || !plr.IsConnected() )
			continue;
		
		if ( plr.pev.netname == "SvenCoopFishy" )
			continue;
		
		iPlayersCount += 1.0f;

        if ( g_bVotedInRTV[ i ] )
            iNominatedPlayersCount += 1.0f;
	}

    flPercentage = iNominatedPlayersCount / iPlayersCount;

    if ( flPercentage >= RTV_MAP_CHANGE_PLAYERS_PERCENTAGE )
    {
        int iMapWithMostVotes = 0;
        array<int> iVotesCount;

        // Init votes count
        for (uint i = 0; i < g_sMapsRTV.length(); i++)
        {
            iVotesCount.insertLast( 0 );
        }

        // Count all votes
        for (int i = 1; i <= g_Engine.maxClients; ++i)
        {
            if ( g_bVotedInRTV[ i ] && g_iVotedMap[ i ] >= 0 )
            {
                iVotesCount[ g_iVotedMap[ i ] ]++;
            }
        }

        // Find map with highest vote count
        for (uint i = 0; i < iVotesCount.length(); i++)
        {
            if ( iVotesCount[ i ] > iVotesCount[ iMapWithMostVotes ] )
                iMapWithMostVotes = i;
        }

        // Notify
        g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[RTV] Player " + pPlayer.pev.netname + " nominated map \"" + sMap + "\".\n" );
        g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[RTV] Vote for map \"" + g_sMapsRTV[ iMapWithMostVotes ] + "\" was successful. Changing the map in 20 seconds.\n" );

        // Start countdown
        RTV_CountdownTask( g_sMapsRTV[ iMapWithMostVotes ], 20 );

        // Votes aren't allowed anymore
        g_bMapChangingRTV = true;
    }
    else
    {
        int iNeededVotes = int( Math.Ceil( iPlayersCount * RTV_MAP_CHANGE_PLAYERS_PERCENTAGE ) ) - int( iNominatedPlayersCount );

        g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[RTV] Player " + pPlayer.pev.netname + " nominated map \"" + sMap + "\".\n" );
        g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[RTV] " + string(iNeededVotes) + " more votes to change the map.\n" );
    }
}

//-----------------------------------------------------------------------------
// Purpose: chat notification
//-----------------------------------------------------------------------------

void RTV_Notification()
{
    if ( !g_bEnabled )
        return;

    g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[RTV] Type in the chat \"rtv\" to vote for a map to change (\"unrtv\" to remove your vote).\n" );
}

//-----------------------------------------------------------------------------
// Purpose: PluginInit
//-----------------------------------------------------------------------------

void RTV_PluginInit()
{
    g_Scheduler.SetInterval("RTV_Notification", 90.0f, g_Scheduler.REPEAT_INFINITE_TIMES);
}

//-----------------------------------------------------------------------------
// Purpose: MapInit Hook
//-----------------------------------------------------------------------------

void RTV_MapInit()
{
    string sCurrentMap = g_Engine.mapname;

    sCurrentMap.ToLowercase();

    // Clear states
    for (uint i = 0; i < g_bVotedInRTV.length(); i++)
    {
        g_bVotedInRTV[ i ] = false;
        g_iVotedMap[ i ] = -1;
    }

    g_bMapChangingRTV = false;

    g_sMapsRTV.resize( 0 );

    // Precache countdown sounds
    // ZP_PrecacheSounds( RTV_COUNTDOWN_SND );

    // Load list of maps
    array<string> sMaps;

    string szFilePath = "scripts/plugins/store/zombie_plague/rtv_maps.txt";
    File@ pFile = g_FileSystem.OpenFile( szFilePath, OpenFile::READ );

    if ( pFile !is null && pFile.IsOpen() )
    {
        string sLine;
        string sMap;

		while ( !pFile.EOFReached() )
		{
			pFile.ReadLine(sLine);
			
			if ( sLine.Length() == 0 )
				continue;
            
            sMap = sLine;
            
            sMap.Trim("\n");
            sMap.Trim(" ");
            sMap.ToLowercase();
            
            if ( sCurrentMap == sMap )
                continue;

            sMaps.insertLast( sMap );
        }
    }

    uint iMaxMaps = ( ZP_IsRunning() ? 8 : 9 );
    uint iMapsCount = sMaps.length();

    if ( iMapsCount <= iMaxMaps )
    {
        for (uint i = 0; i < iMapsCount; i++)
        {
            g_sMapsRTV.insertLast( sMaps[ i ] );
        }
    }
    else
    {
        for (uint i = 0; i < iMaxMaps; i++)
        {
            int iRandomMap = RandomInt( 0, sMaps.length() - 1 );

            g_sMapsRTV.insertLast( sMaps[ iRandomMap ] );
            sMaps.removeAt( iRandomMap );
        }
    }

    if ( ZP_IsRunning() )
    {
        g_sMapsRTV.insertLast( "choose_campaign_4" );
    }
}

//-----------------------------------------------------------------------------
// Purpose: RTV menu
//-----------------------------------------------------------------------------

void RTV_MenuCallback(CTextMenu@ pMenu, CBasePlayer@ pPlayer, int itemNumber, const CTextMenuItem@ pItem)
{
	if ( pItem is null || pPlayer is null || !pPlayer.IsConnected() )
		return;
    
    int idx = pPlayer.entindex();

	uint iMap = 0;
	pItem.m_pUserData.retrieve( iMap );

	if ( iMap >= 0 && iMap < g_sMapsRTV.length() )
    {
        RTV_Nominate( pPlayer, int(iMap), g_sMapsRTV[ iMap ] );
    }
}

void RTV_OpenMenu(EHandle hPlayer)
{
	CBasePlayer@ pPlayer = cast<CBasePlayer@>(hPlayer.GetEntity());
	
	if ( pPlayer is null )
		return;

	const int idx = pPlayer.entindex();

	// Is it necessary?
	if ( g_MenuRTV[idx] !is null && g_MenuRTV[idx].IsRegistered() )
	{
		g_MenuRTV[idx].Unregister();
	}

	@g_MenuRTV[idx] = CTextMenu( @RTV_MenuCallback );

	g_MenuRTV[idx].SetTitle( "\\yNominate Map\\r" ); // Title

    uint iLastItem = g_sMapsRTV.length() - 1;

    for (uint i = 0; i < g_sMapsRTV.length(); i++)
    {
        if ( ZP_IsRunning() && i == iLastItem )
            g_MenuRTV[idx].AddItem( "\\w" + g_sMapsRTV[ i ] + " (disable ZP)\\y", any(i) );
        else
            g_MenuRTV[idx].AddItem( "\\w" + g_sMapsRTV[ i ] + ( i == iLastItem ? "\\y" : "\\r" ), any(i) );
    }

	g_MenuRTV[idx].Register();
	g_MenuRTV[idx].Open(0, 0, pPlayer);
}

//-----------------------------------------------------------------------------
// Purpose: OnClientPutInServer Hook
//-----------------------------------------------------------------------------

void RTV_OnClientPutInServer( CBasePlayer@ pPlayer )
{
    int idx = pPlayer.entindex();

    g_bVotedInRTV[ idx ] = false;
    g_iVotedMap[ idx ] = -1;
}

//-----------------------------------------------------------------------------
// Purpose: OnClientSay Hook
//-----------------------------------------------------------------------------

void RTV_Command( CBasePlayer@ pPlayer, bool bRemoveVote )
{
    if ( UTIL_CanUseCommand( pPlayer ) )
    {
        UTIL_CooldownCommand( pPlayer );

        if ( g_sMapsRTV.length() == 0 )
            return;

        if ( bRemoveVote )
        {
            int idx = pPlayer.entindex();

            if ( g_bVotedInRTV[ idx ] )
            {
                g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[RTV] Player " + pPlayer.pev.netname + " removed their vote.\n" );
            }
            else
            {
                g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[RTV] You haven't nominated any map yet.\n" );
            }

            g_bVotedInRTV[ idx ] = false;
            g_iVotedMap[ idx ] = -1;

            return;
        }

        RTV_OpenMenu( EHandle( pPlayer ) );
    }
}