/** [SZP] Sven Zombie Plague BETA
 * Zombie & Human Extras
 * Author: Sw1ft
*/

//-----------------------------------------------------------------------------
// Purpose: register all Zombie/Human extras
//-----------------------------------------------------------------------------

void ZP_RegisterExtras()
{
	// Function's signature:
    // void ZP_RegisterZombieExtra( string name, int cost, funcdef void ExtraBuyCallback(CExtraItem@, CBasePlayer@) )
    // void ZP_RegisterHumanExtra( string name, int cost, funcdef void ExtraBuyCallback(CExtraItem@, CBasePlayer@) )

    // Zombie extras
    ZP_RegisterZombieExtra( "T-Virus Antidote", 15, @ZP_BuyExtra_Antidote );
    ZP_RegisterZombieExtra( "Zombie Madness", 17, @ZP_BuyExtra_ZombieMadness );
    ZP_RegisterZombieExtra( "Infection Bomb", 25, @ZP_BuyExtra_InfectionBomb );
    ZP_RegisterZombieExtra( "Jump Bomb", 6, @ZP_BuyExtra_JumpBomb );
    ZP_RegisterZombieExtra( "Laser Mine", 5, @ZP_BuyExtra_LaserMine );

    // Humans extras
    ZP_RegisterHumanExtra( "NightVision", 7, @ZP_BuyExtra_NightVision );
    ZP_RegisterHumanExtra( "Napalm Nade", 5, @ZP_BuyExtra_NapalmNade );
    ZP_RegisterHumanExtra( "Frost Nade", 5, @ZP_BuyExtra_FrostNade );
    ZP_RegisterHumanExtra( "Flare Nade", 5, @ZP_BuyExtra_FlareNade );
    ZP_RegisterHumanExtra( "Anti-Infection Armor", 10, @ZP_BuyExtra_AntiInfectArmor );
    ZP_RegisterHumanExtra( "Laser Mine", 5, @ZP_BuyExtra_LaserMine );
    ZP_RegisterHumanExtra( "Sandbags", 8, @ZP_BuyExtra_SandBags );
    ZP_RegisterHumanExtra( "Holy Bomb", 15, @ZP_BuyExtra_HolyBomb );
    ZP_RegisterHumanExtra( "Force Field (Short-acting)", 15, @ZP_BuyExtra_ForceField );
    ZP_RegisterHumanExtra( "Force Field (One round)", 45, @ZP_BuyExtra_ForceFieldOneRound );
    ZP_RegisterHumanExtra( "Infinite Ammo Clip", 15, @ZP_BuyExtra_InfiniteAmmoClip );
    ZP_RegisterHumanExtra( "Incendiary Ammo", 17, @ZP_BuyExtra_IncendiaryAmmo );
    ZP_RegisterHumanExtra( "M40A1 Sniper", 18, @ZP_BuyExtra_M40A1 );
    ZP_RegisterHumanExtra( "M249 Para Machinegun", 17, @ZP_BuyExtra_M249 );
    ZP_RegisterHumanExtra( "M134 Minigun", 30, @ZP_BuyExtra_Minigun );
    ZP_RegisterHumanExtra( "Crossbow", 14, @ZP_BuyExtra_Crossbow );
    ZP_RegisterHumanExtra( "Double Uzis", 19, @ZP_BuyExtra_DoubleUzis );
    ZP_RegisterHumanExtra( "RPG Launcher", 22, @ZP_BuyExtra_RPG );
    ZP_RegisterHumanExtra( "Tau Cannon", 24, @ZP_BuyExtra_Gauss );
    ZP_RegisterHumanExtra( "Gluon Gun", 25, @ZP_BuyExtra_Egon );
    ZP_RegisterHumanExtra( "Spore Launcher", 28, @ZP_BuyExtra_SporeLauncher );
    ZP_RegisterHumanExtra( "Shock Rifle", 30, @ZP_BuyExtra_ShockRifle );
}

//-----------------------------------------------------------------------------
// Purpose: Zombie extras
//-----------------------------------------------------------------------------

// Extra: Antidote
void ZP_BuyExtra_Antidote(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        if ( g_iAliveZombies == 1 )
        {
            g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] The last zombie cannot use Antidote.\n" );
            return;
        }

        if ( g_iClassType[ idx ] == ZP_ZOMBIE_NEMESIS || g_iClassType[ idx ] == ZP_ZOMBIE_ASSASSIN )
        {
            g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] Nemesis/Assassin cannot use Antidote.\n" );
            return;
        }

        if ( g_bFrozen[idx] )
        {
            // Gradually remove screen's blue tint if we're frozen
            {
                NetworkMessage message( MSG_ONE, NetworkMessages::ScreenFade, pPlayer.edict() );
                    message.WriteShort( UNIT_SECOND ); // duration
                    message.WriteShort( 0 ); // hold time
                    message.WriteShort( FFADE_IN ); // fade type
                    message.WriteByte( 0 ); // red
                    message.WriteByte( 50 ); // green
                    message.WriteByte( 200 ); // blue
                    message.WriteByte( 100 ); // alpha
                message.End();
            }

            // g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_BODY, UTIL_GetRandomStringFromArray( ZP_GRENADE_FROST_BREAK_SND ), 1.0f, ATTN_NORM, 0, PITCH_NORM );

            // Glass shatter
            // {
            //     NetworkMessage message( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecOrigin, null );
            //         message.WriteByte( TE_BREAKMODEL ); // TE id
            //         message.WriteCoord( vecOrigin.x ); // x
            //         message.WriteCoord( vecOrigin.y ); // y
            //         message.WriteCoord( vecOrigin.z + 24.0f ); // z
            //         message.WriteCoord( 16 ); // size x
            //         message.WriteCoord( 16 ); // size y
            //         message.WriteCoord( 16 ); // size z
            //         message.WriteCoord( RandomInt(-50, 50) ); // velocity x
            //         message.WriteCoord( RandomInt(-50, 50) ); // velocity y
            //         message.WriteCoord( 25 ); // velocity z
            //         message.WriteByte( 10 ); // random velocity
            //         message.WriteShort( g_glassSpr ); // model
            //         message.WriteByte( 10 ); // count
            //         message.WriteByte( 25 ); // life
            //         message.WriteByte( BREAK_GLASS ); // flags
            //     message.End();
            // }
        }

        ZP_ResetClientState( idx, false );

        pPlayer.SetClassification( ZP_TEAM_HUMAN );
        pPlayer.RemoveAllItems( false );

        ZP_ResetPlayerModel( pPlayer );

        ZP_DeployHumanItems( pPlayer );

        g_iAliveHumans++;
        g_iAliveZombies--;

        // Remove any glow
        UTIL_SetRenderMode( pPlayer, kRenderFxNone, Vector(255, 255, 255), kRenderNormal, 255 );

        pPlayer.pev.health = ZP_HUMAN_START_HP;
        pPlayer.pev.max_health = ZP_HUMAN_START_HP;

        pPlayer.pev.armorvalue = ZP_HUMAN_START_ARMOR;
        pPlayer.pev.armortype = ZP_HUMAN_MAX_ARMOR;

        g_bIsHuman[idx] = true;
        g_bAlive[idx] = true;

        g_bCanBuyPrimaryWeapons[idx] = true;
        g_bCanBuySecondaryWeapons[idx] = true;

        g_Scheduler.SetTimeout("ZP_OpenPrimaryWeaponsMenu", 0.5f, EHandle(pPlayer));

        g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_ITEM, UTIL_GetRandomStringFromArray( ZP_ANTIDOTE_SND ), 1.0f, ATTN_NORM, 0, PITCH_NORM );
        UTIL_HudMessageAll( "" + pPlayer.pev.netname + " has used an antidote...", 0, 155, 255, HUD_INFECT_X, HUD_INFECT_Y, 0, 0.0f, 5.0f, 1.0f, 1.0f, HUD_CHAN_INFECT );

        UTIL_UpdateScoreInfo( pPlayer.edict() );

        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

// Extra: Zombie Madness
void ZP_BuyExtra_ZombieMadness(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

		if ( g_iClassType[ idx ] == ZP_ZOMBIE_NEMESIS || g_iClassType[ idx ] == ZP_ZOMBIE_ASSASSIN )
        {
            g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] Nemesis/Assassin cannot use Zombie Madness.\n" );
            return;
        }

        g_bNoDamage[idx] = true;
        g_bAura[idx] = true;

        g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_VOICE, UTIL_GetRandomStringFromArray( ZP_ZOMBIE_MADNESS_SND ), 1.0f, ATTN_NORM, 0, PITCH_NORM );

        g_Scheduler.SetTimeout("MadnessOver", ZP_ZOMBIE_MADNESS_DURATION, EHandle(pPlayer));

        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

void MadnessOver(EHandle hPlayer)
{
	CBasePlayer@ pPlayer = cast<CBasePlayer@>(hPlayer.GetEntity());
	
	if ( pPlayer is null )
		return;
    
    int idx = pPlayer.entindex();

    if ( g_bAlive[idx] && g_bIsZombie[idx] && g_iClassType[idx] == ZP_ZOMBIE_DEFAULT )
    {
        g_bNoDamage[idx] = false;
        g_bAura[idx] = false;
    }
}

// Extra: Infection Bomb
void ZP_BuyExtra_InfectionBomb(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

		if ( g_iClassType[ idx ] == ZP_ZOMBIE_NEMESIS || g_iClassType[ idx ] == ZP_ZOMBIE_ASSASSIN )
        {
            g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] Nemesis/Assassin cannot use Infection Bomb.\n" );
            return;
        }

        pPlayer.GiveNamedItem( "weapon_infectgrenade" );

        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

// Extra: Jump Bomb
void ZP_BuyExtra_JumpBomb(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

		if ( g_iClassType[ idx ] == ZP_ZOMBIE_NEMESIS || g_iClassType[ idx ] == ZP_ZOMBIE_ASSASSIN )
        {
            g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] Nemesis/Assassin cannot buy Jump Bomb.\n" );
            return;
        }

        pPlayer.GiveNamedItem( "weapon_jumpgrenade" );

        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

//-----------------------------------------------------------------------------
// Purpose: Human extras
//-----------------------------------------------------------------------------

// Extra: Night Vision
void ZP_BuyExtra_NightVision(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        g_bHasNightvision[idx] = true;

        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

// Extra: Napalm Nade
void ZP_BuyExtra_NapalmNade(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        pPlayer.GiveNamedItem( "weapon_firegrenade" );

        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

// Extra: Frost Nade
void ZP_BuyExtra_FrostNade(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        pPlayer.GiveNamedItem( "weapon_frostgrenade" );

        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

// Extra: Flare Nade
void ZP_BuyExtra_FlareNade(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        pPlayer.GiveNamedItem( "weapon_flaregrenade" );

        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

// Extra: Anti-Infection Armor
void ZP_BuyExtra_AntiInfectArmor(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        const float flArmor = 100.0f;

        if ( pPlayer.pev.armorvalue + flArmor > pPlayer.pev.armortype )
        {
            pPlayer.pev.armorvalue = pPlayer.pev.armortype;
        }
        else
        {
            pPlayer.pev.armorvalue += flArmor;
        }

        g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_BODY, ZP_ARMOR_EQUIP_SND, 1.0f, ATTN_NORM, 0, PITCH_NORM );
        
        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

// Extra: Laser Mine
void ZP_BuyExtra_LaserMine(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        if ( g_iLaserMinesCount[ idx ] >= ZP_LASERMINE_MAX_CARRY_LIMIT )
        {
            g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] You already have maximum count of Laser Mines.\n" );
            return;
        }

        g_iLaserMinesCount[ idx ]++;

        g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_WEAPON, ZP_PICKUP_SND, 1.0f, ATTN_NORM, 0, PITCH_NORM );
        
        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);

        g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] You have " + string(g_iLaserMinesCount[ idx ]) + "/" + string(ZP_LASERMINE_MAX_CARRY_LIMIT) + " Laser Mines.\n" );
        g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] Type in the chat /zpsetlaser to place a Laser Mine (or type in the console .zp_setlaser).\n" );
        g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] Type in the chat /zpdellaser to take a Laser Mine (or type in the console .zp_dellaser).\n" );
    }
}

// Extra: Sandbags
void ZP_BuyExtra_SandBags(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        if ( g_iSandBagsCount[ idx ].length() >= ZP_SANDBAGS_MAX_CARRY_LIMIT )
        {
            g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] You already have maximum count of Sandbags.\n" );
            return;
        }

        g_iSandBagsCount[ idx ].insertLast( CInventorySandBags( ZP_SANDBAGS_HEALTH, -1.0f ) );

        g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_WEAPON, ZP_PICKUP_SND, 1.0f, ATTN_NORM, 0, PITCH_NORM );
        
        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);

        g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] You have " + string(g_iSandBagsCount[ idx ].length()) + "/" + string(ZP_SANDBAGS_MAX_CARRY_LIMIT) + " Sandbags.\n" );
        g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] Type in the chat /zpsetsandbags to place Sandbags (or type in the console .zp_setsandbags).\n" );
        g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] Type in the chat /zpdelsandbags to take Sandbags (or type in the console .zp_delsandbags).\n" );
    }
}

// Extra: Holy Bomb
void ZP_BuyExtra_HolyBomb(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        pPlayer.SetItemPickupTimes( 0.0f );
        pPlayer.GiveNamedItem( "weapon_holygrenade" );
        
        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

// Extra: Force Field
void ZP_BuyExtra_ForceField(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        g_bOneRoundForceField[idx] = false;

        pPlayer.SetItemPickupTimes( 0.0f );
        pPlayer.GiveNamedItem( "weapon_force_field_grenade" );
        
        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

// Extra: Force Field (One Round)
void ZP_BuyExtra_ForceFieldOneRound(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        g_bOneRoundForceField[idx] = true;

        pPlayer.SetItemPickupTimes( 0.0f );
        pPlayer.GiveNamedItem( "weapon_force_field_grenade" );
        
        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

// Extra: Infinite Ammo Clip
void ZP_BuyExtra_InfiniteAmmoClip(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        g_bInfiniteClipAmmo[idx] = true;
        
        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

// Extra: Incendiary Ammo
void ZP_BuyExtra_IncendiaryAmmo(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        g_bIncendiaryAmmo[idx] = true;
        
        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

// Extra: M40A1 Sniper Rifle
void ZP_BuyExtra_M40A1(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        pPlayer.SetItemPickupTimes( 0.0f );
        pPlayer.GiveNamedItem( "weapon_sniperrifle" );

        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

// Extra: M249
void ZP_BuyExtra_M249(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        pPlayer.SetItemPickupTimes( 0.0f );
        pPlayer.GiveNamedItem( "weapon_m249" );

        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

// Extra: Minigun
void ZP_BuyExtra_Minigun(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        pPlayer.SetItemPickupTimes( 0.0f );
        pPlayer.GiveNamedItem("weapon_minigun", 16384);

        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

// Extra: Crossbow
void ZP_BuyExtra_Crossbow(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        pPlayer.SetItemPickupTimes( 0.0f );
        pPlayer.GiveNamedItem("weapon_crossbow");

        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

// Extra: Double Uzis
void ZP_BuyExtra_DoubleUzis(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        pPlayer.SetItemPickupTimes( 0.0f );
        pPlayer.GiveNamedItem("weapon_uzi");

        g_Scheduler.SetTimeout("GiveUzi", 0.25f, EHandle(pPlayer));

        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

void GiveUzi(EHandle hPlayer)
{
	CBasePlayer@ pPlayer = cast<CBasePlayer@>(hPlayer.GetEntity());
	
	if ( pPlayer is null )
		return;
    
    int idx = pPlayer.entindex();

    if ( g_bAlive[idx] && g_bIsHuman[idx] && g_iClassType[idx] == ZP_HUMAN_DEFAULT )
    {
        pPlayer.SetItemPickupTimes( 0.0f );
        pPlayer.GiveNamedItem("weapon_uzi");
    }
}

// Extra: RPG Launcher
void ZP_BuyExtra_RPG(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        pPlayer.SetItemPickupTimes( 0.0f );
        pPlayer.GiveNamedItem("weapon_rpg");
        pPlayer.GiveNamedItem("ammo_rpgclip");

        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

// Extra: Tau Cannon
void ZP_BuyExtra_Gauss(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        pPlayer.SetItemPickupTimes( 0.0f );
        pPlayer.GiveNamedItem("weapon_gauss");

        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

// Extra: Gluon Gun
void ZP_BuyExtra_Egon(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        pPlayer.SetItemPickupTimes( 0.0f );
        pPlayer.GiveNamedItem("weapon_egon");

        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

// Extra: Spore Launcher
void ZP_BuyExtra_SporeLauncher(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        pPlayer.SetItemPickupTimes( 0.0f );
        pPlayer.GiveNamedItem("weapon_sporelauncher");

        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}

// Extra: Shock Rifle
void ZP_BuyExtra_ShockRifle(CExtraItem@ pExtraItem, CBasePlayer@ pPlayer)
{
    if ( ZP_Extras_IsEnoughAmmopacks(pPlayer, pExtraItem.m_iCost) )
    {
        int idx = pPlayer.entindex();

        pPlayer.SetItemPickupTimes( 0.0f );
        pPlayer.GiveNamedItem("weapon_shockrifle", 16384);

        ZP_Extras_ConfirmPurchase(pPlayer, pExtraItem);
    }
}