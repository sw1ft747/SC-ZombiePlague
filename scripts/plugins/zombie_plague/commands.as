/** [SZP] Sven Zombie Plague BETA
 * Chat & Console Commands
 * Author: Sw1ft
*/

//-----------------------------------------------------------------------------
// Console Commands
//-----------------------------------------------------------------------------

// Admin commands
CClientCommand zp_enable("zp_enable", "Turn on/off Zombie Plague plugin:\nzp_enable - prints state of the plugin\nzp_enable 1 - enables the plugin\nzp_enable 0 - disables the plugin", @ZP_CmdEnable, ConCommandFlag::AdminOnly);
CClientCommand zp_setcvar("zp_setcvar", "Executes in server console as_command zp.<cvarname> <value>", @ZP_CmdSetCvar, ConCommandFlag::AdminOnly);
CClientCommand zp_changemap("zp_changemap", "Changes the current map: zp_changemap <mapname>", @ZP_CmdChangemap, ConCommandFlag::AdminOnly);
CClientCommand zp_kill("zp_kill", "Kill player: zp_kill <index>", @ZP_CmdKill, ConCommandFlag::AdminOnly);
CClientCommand zp_giveap("zp_giveap", "Give ammo packs to player: zp_giveap <index> <amount>", @ZP_GiveAP, ConCommandFlag::AdminOnly);

// Client commands
CClientCommand zp_menu("zp_menu", "Show Zombie Plague menu", @ZP_ClientCommand_Wrapper);
CClientCommand zp_nightvision("zp_nightvision", "Turn on/off nightvision", @ZP_ClientCommand_Wrapper);
CClientCommand zp_setlaser("zp_setlaser", "Place Laser Mine", @ZP_ClientCommand_Wrapper);
CClientCommand zp_dellaser("zp_dellaser", "Take Laser Mine", @ZP_ClientCommand_Wrapper);
CClientCommand zp_setsandbags("zp_setsandbags", "Place Sandbags", @ZP_ClientCommand_Wrapper);
CClientCommand zp_delsandbags("zp_delsandbags", "Take Sandbags", @ZP_ClientCommand_Wrapper);

//-----------------------------------------------------------------------------
// Purpose: register all user commands
//-----------------------------------------------------------------------------

void ZP_RegisterUserCommands()
{
    ZP_RegisterUserCommand( "/zpmenu", ".zp_menu", @ZP_CommandCallback_Menu, true );
    ZP_RegisterUserCommand( "/zpnv", ".zp_nightvision", @ZP_CommandCallback_NightVision, true );
    ZP_RegisterUserCommand( "/zpsetlaser", ".zp_setlaser", @ZP_CommandCallback_SetLaser, true );
    ZP_RegisterUserCommand( "/zpdellaser", ".zp_dellaser", @ZP_CommandCallback_DelLaser, true );
    ZP_RegisterUserCommand( "/zpsetsandbags", ".zp_setsandbags", @ZP_CommandCallback_SetSandBags, true );
    ZP_RegisterUserCommand( "/zpdelsandbags", ".zp_delsandbags", @ZP_CommandCallback_DelSandBags, true );
}

//-----------------------------------------------------------------------------
// Purpose: commands wrappers for both chat & console ones
//-----------------------------------------------------------------------------

// /zpmenu
void ZP_CommandCallback_Menu(CBasePlayer@ pPlayer)
{
    ZP_OpenMainMenu( EHandle( pPlayer ) );
}

// /zpnv
void ZP_CommandCallback_NightVision(CBasePlayer@ pPlayer)
{
    int idx = pPlayer.entindex();

    if ( g_bAlive[idx] )
    {
        if ( g_bIsZombie[idx] || (g_bIsHuman[idx] && g_bHasNightvision[idx]) )
        {
            g_bNightvision[idx] = !g_bNightvision[idx];
        }
    }
    else
    {
        g_bNightvision[idx] = !g_bNightvision[idx];
    }
}

// /zpsetlaser
void ZP_CommandCallback_SetLaser(CBasePlayer@ pPlayer)
{
    int idx = pPlayer.entindex();

    if ( g_bAlive[idx] )
    {
        if ( g_iLaserMinesCount[ idx ] > 0 )
        {
            TraceResult traceResult;

            Vector vecAiming = pPlayer.GetAutoaimVector( 0.0f );
            
            Vector vecSrc = pPlayer.GetGunPosition();
            Vector vecEnd = vecSrc + vecAiming * 8192.0f;

            g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, pPlayer.edict(), traceResult );

            if ( traceResult.flFraction * 8192.0f <= 70.0f )
            {
                Vector vecPlane = traceResult.vecPlaneNormal * 8.0f;

                Vector vecOrigin = traceResult.vecEndPos + vecPlane;
                Vector vecAngles = Math.VecToAngles( vecPlane );

                g_pLaserMines.insertLast( LASERMINE::SpawnLaserMine( pPlayer, vecOrigin, vecAngles, traceResult.vecPlaneNormal ).edict() );

                g_iLaserMinesCount[ idx ]--;
            }
            else
            {
                g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] You're too far from the wall to place the Laser Mine.\n" );
            }
        }
        else
        {
            g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] You don't have any Laser Mine.\n" );
        }
    }
}

// /zpdellaser
void ZP_CommandCallback_DelLaser(CBasePlayer@ pPlayer)
{
    int idx = pPlayer.entindex();

    if ( g_bAlive[idx] )
    {
        TraceResult traceResult;

        Vector vecAiming = pPlayer.GetAutoaimVector( 0.0f );
        
        Vector vecSrc = pPlayer.GetGunPosition();
        Vector vecEnd = vecSrc + vecAiming * 70.0f;

        g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, pPlayer.edict(), traceResult );

        CBaseEntity@ pHit = null;

        if ( traceResult.pHit !is null && ( @pHit = g_EntityFuncs.Instance( traceResult.pHit ) ) !is null )
        {
            if ( pHit.pev.classname == "func_breakable" && pHit.pev.euser1 is pPlayer.edict() && pHit.pev.model == LASERMINE::LASERMINE_MDL )
            {
                if ( ( g_bIsHuman[ idx ] ? 1 : 0 ) == pHit.pev.iuser1 )
                {
                    if ( g_iLaserMinesCount[ idx ] < ZP_LASERMINE_MAX_CARRY_LIMIT )
                    {
                        g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_WEAPON, ZP_PICKUP_SND, 1.0f, ATTN_NORM, 0, PITCH_NORM );
                        g_EntityFuncs.Remove( pHit );

                        g_iLaserMinesCount[ idx ]++;
                    }
                    else
                    {
                        g_PlayerFuncs.ClientPrint( pPlayer,
                                                HUD_PRINTTALK,
                                                "[ZP] You have exceeded limit of Laser Mines to carry (" + string(g_iLaserMinesCount[ idx ]) + "/" + string(ZP_LASERMINE_MAX_CARRY_LIMIT) + ").\n" );
                    }
                }
            }
        }
    }
}

// /zpsetsandbags
void ZP_CommandCallback_SetSandBags(CBasePlayer@ pPlayer)
{
    int idx = pPlayer.entindex();

    if ( g_bAlive[idx] && g_bIsHuman[ idx ] )
    {
        if ( g_iSandBagsCount[ idx ].length() > 0 )
        {
            if ( g_Engine.time - g_iSandBagsCount[ idx ][ 0 ].m_flLastActionTime <= ZP_SANDBAGS_PLACE_COOLDOWN )
            {
                return;
            }

            TraceResult traceResult;

            Vector vecAiming = pPlayer.GetAutoaimVector( 0.0f );
            
            Vector vecSrc = pPlayer.GetGunPosition();
            Vector vecEnd = vecSrc + vecAiming * 8192.0f;

            g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, pPlayer.edict(), traceResult );

            if ( traceResult.flFraction * 8192.0f <= 128.0f )
            {
                Vector vecPlane = traceResult.vecPlaneNormal * 8.0f;

                Vector vecOrigin = traceResult.vecEndPos + vecPlane;
                Vector vecAngles = Math.VecToAngles( vecPlane );

                g_pSandBags.insertLast( SANDBAGS::SpawnSandbags( pPlayer, g_iSandBagsCount[ idx ][ 0 ].m_flHealth, vecOrigin, vecAngles, traceResult.vecPlaneNormal ).edict() );

                g_iSandBagsCount[ idx ].removeAt( 0 );
            }
            else
            {
                g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] You're too far from the wall to place the Sandbags.\n" );
            }
        }
        else
        {
            g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] You don't have any Sandbags.\n" );
        }
    }
}

// /zpdelsandbags
void ZP_CommandCallback_DelSandBags(CBasePlayer@ pPlayer)
{
    int idx = pPlayer.entindex();

    if ( g_bAlive[idx] && g_bIsHuman[ idx ] )
    {
        TraceResult traceResult;

        Vector vecAiming = pPlayer.GetAutoaimVector( 0.0f );
        
        Vector vecSrc = pPlayer.GetGunPosition();
        Vector vecEnd = vecSrc + vecAiming * 128.0f;

        g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, pPlayer.edict(), traceResult );

        CBaseEntity@ pHit = null;

        if ( traceResult.pHit !is null && ( @pHit = g_EntityFuncs.Instance( traceResult.pHit ) ) !is null )
        {
            if ( pHit.pev.classname == "func_breakable" && pHit.pev.euser1 is pPlayer.edict() && pHit.pev.model == SANDBAGS::SANDBAGS_MDL )
            {
                if ( ( g_bIsHuman[ idx ] ? 1 : 0 ) == pHit.pev.iuser1 )
                {
                    if ( g_iSandBagsCount[ idx ].length() < ZP_SANDBAGS_MAX_CARRY_LIMIT )
                    {
                        // g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_WEAPON, ZP_PICKUP_SND, 1.0f, ATTN_NORM, 0, PITCH_NORM );
                        
                        g_iSandBagsCount[ idx ].insertLast( CInventorySandBags( pHit.pev.health, g_Engine.time ) );
                        g_EntityFuncs.Remove( pHit );
                    }
                    else
                    {
                        g_PlayerFuncs.ClientPrint( pPlayer,
                                                HUD_PRINTTALK,
                                                "[ZP] You have exceeded limit of Sandbags to carry (" + string(g_iSandBagsCount[ idx ].length()) + "/" + string(ZP_SANDBAGS_MAX_CARRY_LIMIT) + ").\n" );
                    }
                }
            }
        }
    }
}

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//
//                             Client Commands
//
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Purpose: wrapper for registered user commands
//-----------------------------------------------------------------------------

void ZP_ClientCommand_Wrapper(const CCommand@ pArgs)
{
    if ( !g_bEnabled )
        return;

	CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();

    if ( UTIL_CanUseCommand( pPlayer ) )
    {
        string sCommandName = pArgs[ 0 ];

        for (uint i = 0; i < g_userCommands.length(); i++)
        {
            if ( g_userCommands[ i ].m_sConsoleCommand == sCommandName )
            {
                g_userCommands[ i ].m_pfnCommandCallback( pPlayer );
                break;
            }
        }

        UTIL_CooldownCommand( pPlayer );
    }
}

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//
//                        Client Commands for Admins
//
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Purpose: [ADMIN] enable/disable the plugin
//-----------------------------------------------------------------------------

void ZP_CmdEnable(const CCommand@ pArgs)
{
    CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();

    if ( UTIL_CanUseCommand( pPlayer ) )
    {
        ZP_TogglePlugin( pPlayer,
                        pArgs.ArgC() > 1,
                        ( pArgs.ArgC() > 1 ? atoi( pArgs[ 1 ] ) : 0 ),
                        pArgs.ArgC() > 2,
                        ( pArgs.ArgC() > 2 ? pArgs[ 2 ] : "" ) );

        UTIL_CooldownCommand( pPlayer );
    }
}

//-----------------------------------------------------------------------------
// Purpose: [ADMIN] sets plugin's cvar value
//-----------------------------------------------------------------------------

void ZP_CmdSetCvar(const CCommand@ pArgs)
{
    CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();

    if ( UTIL_CanUseCommand( pPlayer ) )
    {
        if ( pArgs.ArgC() > 2 )
        {
            string sCvar = pArgs[1];
            string sValue = pArgs[2];

            g_EngineFuncs.ServerCommand("as_command \"zp." + sCvar + "\" \"" + sValue + "\"\n");
        }

        UTIL_CooldownCommand( pPlayer );
    }
}

//-----------------------------------------------------------------------------
// Purpose: [ADMIN] changes the map
//-----------------------------------------------------------------------------

void ZP_CmdChangemap(const CCommand@ pArgs)
{
    CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();

    if ( UTIL_CanUseCommand( pPlayer ) )
    {
        if ( pArgs.ArgC() > 1 )
        {
            string sMapname = pArgs[1];

            if ( sMapname == "choose_campaign_4" || ZP_IsMapSupported( sMapname ) )
            {
                g_EngineFuncs.ServerCommand("changelevel \"" + sMapname + "\"\n");
            }
            else
            {
                g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "[ZP] The given map is not supported\n" );
            }
        }

        UTIL_CooldownCommand( pPlayer );
    }
}

//-----------------------------------------------------------------------------
// Purpose: [ADMIN] kill player
//-----------------------------------------------------------------------------

void ZP_CmdKill(const CCommand@ pArgs)
{
    if ( !g_bEnabled )
        return;

    CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();

    if ( UTIL_CanUseCommand( pPlayer ) )
    {
        if ( pArgs.ArgC() > 1 )
        {
            int index = atoi(pArgs[1]);

            CBasePlayer@ pTarget = g_PlayerFuncs.FindPlayerByIndex(index);

            if ( pTarget !is null && pTarget.IsConnected() )
            {
                pTarget.Killed( pTarget.pev, GIB_NEVER );
            }
        }

        UTIL_CooldownCommand( pPlayer );
    }
}

//-----------------------------------------------------------------------------
// Purpose: [ADMIN] give ammo packs
//-----------------------------------------------------------------------------

void ZP_GiveAP(const CCommand@ pArgs)
{
    if ( !g_bEnabled )
        return;

    CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();

    if ( UTIL_CanUseCommand( pPlayer ) )
    {
        if ( pArgs.ArgC() > 2 )
        {
            int index = atoi(pArgs[1]);
            int ammopacks = atoi(pArgs[2]);

            CBasePlayer@ pTarget = g_PlayerFuncs.FindPlayerByIndex(index);

            if ( pTarget !is null && pTarget.IsConnected() )
            {
                g_iAmmopacks[ index ] += ammopacks;
            }
        }

        UTIL_CooldownCommand( pPlayer );
    }
}