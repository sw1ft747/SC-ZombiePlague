/** [SZP] Sven Zombie Plague BETA
 * Weapons Selection
 * Author: Sw1ft
*/

//-----------------------------------------------------------------------------
// Purpose: register weapons menu
//-----------------------------------------------------------------------------

void ZP_RegisterWeaponsMenu()
{
	// Function's signature:
    // void ZP_RegisterPrimaryWeapon( string name, string classname )
    // void ZP_RegisterSecondaryWeapon( string name, string classname )

    // "SG-550 Auto-Sniper" weapon_sg550
    // "AWP Magnum Sniper" weapon_awp
    // "M249 Para Machinegun" weapon_csm249
    // "G3SG1 Auto-Sniper" weapon_g3sg1

    // Primary weapons
    // ZP_RegisterPrimaryWeapon( "IMI Galil", "weapon_galil" );
    // ZP_RegisterPrimaryWeapon( "Famas", "weapon_famas" );
    ZP_RegisterPrimaryWeapon( "M4A1 Carbine", "weapon_m4a1" );
    // ZP_RegisterPrimaryWeapon( "AK-47 Kalashnikov", "weapon_ak47" );
    // ZP_RegisterPrimaryWeapon( "SG-552 Commando", "weapon_sg552" );
    // ZP_RegisterPrimaryWeapon( "Steyr AUG A1", "weapon_aug" );
    // ZP_RegisterPrimaryWeapon( "Schmidt Scout", "weapon_scout" );
    // ZP_RegisterPrimaryWeapon( "M3 Super 90", "weapon_m3" );
    // ZP_RegisterPrimaryWeapon( "XM1014 M4", "weapon_xm1014" );
    // ZP_RegisterPrimaryWeapon( "Schmidt TMP", "weapon_tmp" );
    // ZP_RegisterPrimaryWeapon( "Ingram MAC-10", "weapon_mac10" );
    // ZP_RegisterPrimaryWeapon( "UMP 45", "weapon_ump45" );
    // ZP_RegisterPrimaryWeapon( "MP5 Navy", "weapon_mp5navy" );
    // ZP_RegisterPrimaryWeapon( "ES P90", "weapon_p90" );

    ZP_RegisterPrimaryWeapon( "Uzi", "weapon_uzi" );
    ZP_RegisterPrimaryWeapon( "MP5", "weapon_9mmAR" );
    // ZP_RegisterPrimaryWeapon( "MP5 Navy", "weapon_9mmAR" );
    ZP_RegisterPrimaryWeapon( "Auto Shotgun", "weapon_shotgun" );
    ZP_RegisterPrimaryWeapon( "M16 Carbine", "weapon_m16" );

    // Secondary weapons
    // ZP_RegisterSecondaryWeapon( "Glock 18C", "weapon_csglock18" );
    // ZP_RegisterSecondaryWeapon( "USP .45 ACP Tactical", "weapon_usp" );
    // ZP_RegisterSecondaryWeapon( "P228 Compact", "weapon_p228" );
    // ZP_RegisterSecondaryWeapon( "Desert Eagle .50 AE", "weapon_csdeagle" );
    // ZP_RegisterSecondaryWeapon( "FiveseveN", "weapon_fiveseven" );
    // ZP_RegisterSecondaryWeapon( "Dual Elite Berettas", "weapon_dualelites" );

    ZP_RegisterSecondaryWeapon( "Glock 17", "weapon_9mmhandgun" );
    ZP_RegisterSecondaryWeapon( "Desert Eagle Hawk", "weapon_eagle" );
    // ZP_RegisterSecondaryWeapon( "Desert Eagle .50 AE", "weapon_eagle" );
    ZP_RegisterSecondaryWeapon( ".357 Magnum", "weapon_357" );
}