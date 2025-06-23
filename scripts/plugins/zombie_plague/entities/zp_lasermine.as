// LaserMine
// Not an actual custom entity

namespace LASERMINE
{
    enum Activity
    {
        LASERMINE_DEPLOY = 0,
        LASERMINE_ACTIVATE,
        LASERMINE_BEAM_THINK
    }

    enum Sequence
    {
        TRIPMINE_IDLE1 = 0,
        TRIPMINE_IDLE2,
        TRIPMINE_ARM1,
        TRIPMINE_ARM2,
        TRIPMINE_FIDGET,
        TRIPMINE_HOLSTER,
        TRIPMINE_DRAW,
        TRIPMINE_WORLD,
        TRIPMINE_GROUND,
    };

    string LASERMINE_MDL = "models/zombie_plague/LaserMines/v_laser_mine.mdl";

    const string ACTIVATE_SND = "weapons/mine_activate.wav";
    const string DEPLOY_SND = "weapons/mine_deploy.wav";
    const string CHARGE_SND = "weapons/mine_charge.wav";
    const string HIT_SND = "items/suitchargeok1.wav";

    void Precache()
    {
        g_Game.PrecacheModel( LASERMINE_MDL );

        g_SoundSystem.PrecacheSound( ACTIVATE_SND );
        g_SoundSystem.PrecacheSound( DEPLOY_SND );
        g_SoundSystem.PrecacheSound( CHARGE_SND );
        g_SoundSystem.PrecacheSound( HIT_SND );

        g_SoundSystem.PrecacheSound( "debris/bustglass1.wav" );
        g_SoundSystem.PrecacheSound( "debris/bustglass2.wav" );
    }

    void DrawBeam(CBaseEntity@ pEntity, Vector vecColor)
    {
        NetworkMessage message( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, pEntity.pev.origin, null );
            message.WriteByte( TE_BEAMENTPOINT ); // TE id
            message.WriteShort( pEntity.entindex() ); // x
            message.WriteCoord( pEntity.pev.vuser1.x ); // x
            message.WriteCoord( pEntity.pev.vuser1.y ); // y
            message.WriteCoord( pEntity.pev.vuser1.z ); // z
            message.WriteShort( g_trailSpr ); // sprite
            message.WriteByte( 0 ); // startframe
            message.WriteByte( 0 ); // framerate
            message.WriteByte( 5 ); // life
            message.WriteByte( 5 ); // width 
            message.WriteByte( 0 ); // noise
            message.WriteByte( int( vecColor.x ) ); // red
            message.WriteByte( int( vecColor.y ) ); // green
            message.WriteByte( int( vecColor.z ) ); // blue
            message.WriteByte( 100 ); // brightness
            message.WriteByte( 3 ); // speed
        message.End();
    }

    void Think(EHandle hEntity, int activity)
    {
        CBaseEntity@ pEntity = hEntity.GetEntity();

        if ( pEntity !is null )
        {
            float flNextThink = 0.2f;

            switch ( activity )
            {
                case LASERMINE_DEPLOY:
                {
                    g_SoundSystem.PlaySound( pEntity.edict(), CHAN_WEAPON, DEPLOY_SND, 1.0f, ATTN_NORM, 0, PITCH_NORM );

                    // Delay charge sound
                    g_Scheduler.SetTimeout( "ZP_ChargeLaserMine", 0.1f, hEntity );

                    activity = LASERMINE_ACTIVATE;
                    flNextThink = 2.5f;

                    break;
                }

                case LASERMINE_ACTIVATE:
                {
                    g_SoundSystem.PlaySound( pEntity.edict(), CHAN_WEAPON, ACTIVATE_SND, 1.0f, ATTN_NORM, 0, PITCH_NORM );
                    
                    DrawBeam( pEntity, pEntity.pev.rendercolor );

                    activity = LASERMINE_BEAM_THINK;
                    break;
                }

                case LASERMINE_BEAM_THINK:
                {
                    if ( g_Engine.time - pEntity.pev.fuser1 >= ZP_LASERMINE_BEAM_HIT_INTERVAL )
                    {
                        TraceResult traceResult;

                        g_Utility.TraceLine( pEntity.pev.origin, pEntity.pev.vuser1, dont_ignore_monsters, pEntity.edict(), traceResult );

                        // Did hit something
                        if ( traceResult.flFraction < 1.0f )
                        {
                            CBaseEntity@ pHit = null;

                            if ( traceResult.pHit !is null && ( @pHit = g_EntityFuncs.Instance( traceResult.pHit ) ) !is null )
                            {
                                CBasePlayer@ pPlayer = cast<CBasePlayer@>( pHit );

                                if ( pPlayer !is null )
                                {
                                    int idx = pPlayer.entindex();

                                    // Different teams
                                    if ( ( g_bIsHuman[ idx ] ? 1 : 0 ) != pEntity.pev.iuser1 )
                                    {
                                        CBaseEntity@ pOwner = g_EntityFuncs.Instance( pEntity.pev.euser1 );
                                        float flRemainingHealth = pPlayer.pev.health - ZP_LASERMINE_HIT_DAMAGE;

                                        if ( flRemainingHealth <= 0.0f )
                                        {
                                            pPlayer.Killed( pOwner !is null ? pOwner.pev : null, GIB_NEVER );
                                        }
                                        else
                                        {
                                            if ( flRemainingHealth < 1.0f )
                                                flRemainingHealth = 1.0f;
                                            
                                            pPlayer.pev.health = flRemainingHealth;
                                        }

                                        g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_WEAPON, HIT_SND, 1.0f, ATTN_NORM, 0, PITCH_NORM );

                                        NetworkMessage message( MSG_ONE_UNRELIABLE, NetworkMessages::Damage, pPlayer.edict() );
                                            message.WriteByte( 0 ); // damage save
                                            message.WriteByte( 255 ); // damage take
                                            message.WriteLong( DMG_BULLET ); // damage type
                                            message.WriteCoord( traceResult.vecEndPos.x ); // x
                                            message.WriteCoord( traceResult.vecEndPos.y ); // y
                                            message.WriteCoord( traceResult.vecEndPos.z ); // z
                                        message.End();

                                        // Show damage
                                        if ( ZP_DAMAGE_INDICATOR )
                                        {
                                            UTIL_ShowDamage( pPlayer, pOwner !is null ? cast<CBasePlayer@>( pOwner ) : null, int( ZP_LASERMINE_HIT_DAMAGE ) );
                                        }

                                        // Play random pain sound
                                        if ( RandomInt(1, 3) == 1 )
                                        {
                                            ZP_PlayPainSound( pPlayer, g_iClassType[ pPlayer.entindex() ] );
                                        }

                                        // Punch a bit
                                        pPlayer.pev.punchangle.x = -2.0f;
                                    }
                                }
                            }
                        }

                        pEntity.pev.fuser1 = g_Engine.time; // Last beam think time
                    }

                    DrawBeam( pEntity, pEntity.pev.rendercolor );

                    break;
                }
            }

            g_Scheduler.SetTimeout( "ZP_LaserMine_Think", flNextThink, hEntity, activity );
        }
    }

    CBaseEntity@ SpawnLaserMine(CBasePlayer@ pPlayer, Vector vecOrigin, Vector vecAngles, Vector vecPlaneNormal)
    {
        TraceResult traceResult;
        Vector vecBeamEnd = vecOrigin + vecPlaneNormal * 8192.0f;

        g_Utility.TraceLine( vecOrigin, vecBeamEnd, ignore_monsters, pPlayer.edict(), traceResult );

        CBaseEntity@ pLaserMine = g_EntityFuncs.CreateEntity( "func_breakable" );

        g_EntityFuncs.SetOrigin( pLaserMine, vecOrigin );
        g_EntityFuncs.SetModel( pLaserMine, LASERMINE_MDL );

        g_EntityFuncs.DispatchSpawn( pLaserMine.edict() );

        pLaserMine.pev.solid = SOLID_BBOX;
        pLaserMine.pev.movetype = MOVETYPE_FLY;
        pLaserMine.pev.frame = 0;
        pLaserMine.pev.body = 3;
        pLaserMine.pev.framerate = 0;
        pLaserMine.pev.sequence = TRIPMINE_WORLD;

        pLaserMine.pev.takedamage = DAMAGE_YES;
        pLaserMine.pev.dmg = 100.0f;
        pLaserMine.pev.health = ZP_LASERMINE_HEALTH;

        pLaserMine.pev.renderfx = kRenderFxGlowShell;
        pLaserMine.pev.rendermode = kRenderNormal;
        pLaserMine.pev.renderamt = 16;

        if ( g_bIsHuman[ pPlayer.entindex() ] )
            pLaserMine.pev.rendercolor = Vector(ZP_LASERMINE_HUMAN_COLOR_R, ZP_LASERMINE_HUMAN_COLOR_G, ZP_LASERMINE_HUMAN_COLOR_B);
        else
            pLaserMine.pev.rendercolor = Vector(ZP_LASERMINE_ZOMBIE_COLOR_R, ZP_LASERMINE_ZOMBIE_COLOR_G, ZP_LASERMINE_ZOMBIE_COLOR_B);

        pLaserMine.pev.mins = Vector(-4, -4, -4);
        pLaserMine.pev.maxs = Vector(4, 4, 4);

        pLaserMine.pev.angles = vecAngles;

        g_EntityFuncs.SetSize( pLaserMine.pev, Vector(-4, -4, -4), Vector(4, 4, 4) );

        // Store owner
        @pLaserMine.pev.euser1 = pPlayer.edict();

        // Store to which team belongs this laser mine
        pLaserMine.pev.iuser1 = g_bIsHuman[ pPlayer.entindex() ] ? 1 : 0;

        // Last beam think time
        pLaserMine.pev.fuser1 = 0.0f;

        // Beam end point
        pLaserMine.pev.vuser1 = traceResult.vecEndPos;

        // Do thinking
        Think( EHandle( pLaserMine ), LASERMINE_DEPLOY );

        return pLaserMine;
    }
}

void ZP_LaserMine_Think(EHandle hEntity, int activity)
{
    LASERMINE::Think( hEntity, activity );
}

void ZP_ChargeLaserMine(EHandle hEntity)
{
    CBaseEntity@ pEntity = hEntity.GetEntity();

    if ( pEntity !is null )
    {
        g_SoundSystem.PlaySound( pEntity.edict(), CHAN_WEAPON, LASERMINE::CHARGE_SND, 1.0f, ATTN_NORM, 0, PITCH_NORM );
    }
}