// Sandbags
// Not an actual custom entity

class CInventorySandBags
{
	CInventorySandBags(float flHealth, float flCurrentTime)
	{
		m_flHealth = flHealth;
		m_flLastActionTime = flCurrentTime;
	}

	float m_flHealth;
	float m_flLastActionTime;
}

namespace SANDBAGS
{
    string SANDBAGS_MDL = "models/zombie_plague/sandbags.mdl";
    Vector PALLET_MINS( -27.260000, -22.280001, -22.290001 );
    Vector PALLET_MAXS( 27.340000,  26.629999,  29.020000 );

    void Precache()
    {
        g_Game.PrecacheModel( SANDBAGS_MDL );
    }

    CBaseEntity@ SpawnSandbags(CBasePlayer@ pPlayer, float flHealth, Vector vecOrigin, Vector vecAngles, Vector vecPlaneNormal)
    {
        TraceResult traceResult;
        Vector vecBeamEnd = vecOrigin + vecPlaneNormal * 8192.0f;

        g_Utility.TraceLine( vecOrigin, vecBeamEnd, ignore_monsters, pPlayer.edict(), traceResult );

        CBaseEntity@ pSandbags = g_EntityFuncs.CreateEntity( "func_breakable" );

        pSandbags.KeyValue( "material", matNone );

        g_EntityFuncs.SetOrigin( pSandbags, vecOrigin );
        g_EntityFuncs.SetModel( pSandbags, SANDBAGS_MDL );

        g_EntityFuncs.DispatchSpawn( pSandbags.edict() );

        pSandbags.pev.solid = SOLID_BBOX;
        pSandbags.pev.movetype = MOVETYPE_FLY;
        pSandbags.pev.body = 3;

        pSandbags.pev.takedamage = DAMAGE_YES;
        pSandbags.pev.dmg = 100.0f;
        pSandbags.pev.health = flHealth;
        // pSandbags.pev.health = ZP_SANDBAGS_HEALTH;

        pSandbags.pev.renderfx = kRenderFxGlowShell;
        pSandbags.pev.rendermode = kRenderNormal;
        pSandbags.pev.renderamt = 16;
        pSandbags.pev.rendercolor = Vector( 0, 255, 0 );

        pSandbags.pev.mins = PALLET_MINS;
        pSandbags.pev.maxs = PALLET_MAXS;

        vecAngles.x = 0.0f;
        pSandbags.pev.angles = vecAngles;

        g_EntityFuncs.SetSize( pSandbags.pev, PALLET_MINS, PALLET_MAXS );

        // Store owner
        @pSandbags.pev.euser1 = pPlayer.edict();

        // Store to which team belongs sandbags
        pSandbags.pev.iuser1 = g_bIsHuman[ pPlayer.entindex() ] ? 1 : 0;

        return pSandbags;
    }
}