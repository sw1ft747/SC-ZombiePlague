// Counter-Strike 1.6's Grenade Projectile Base [Redacted as Grenade's Projectile for Zombie Plague Mod]
// Author: KernCore

namespace ZP_PROJECTILE
{

funcdef void ProjectileSpawnHook(CBaseMonster@);
funcdef bool ProjectileImpactHook(CBaseMonster@);
funcdef bool ProjectileDetonateHook(CBaseMonster@);

string DEFAULT_PROJ_NAME 	= "zp_projectile";
string BOUNCE_SOUND      	= "zombie_plague/cs/grenade/bounce.wav";

ProjectileSpawnHook@ pfnProjectileSpawnHook = null;
ProjectileImpactHook@ pfnProjectileImpactHook = null;
ProjectileDetonateHook@ pfnProjectileDetonateHook = null;

class CZpProjectile : ScriptBaseMonsterEntity
{
	private float m_flBounceTime = 0, m_flNextAttack = 0;
	private bool m_bRegisteredSound = false;
	private bool m_bTumbleThinkStarted = false;
	// private int m_iExplodeSprite;
	// private int m_iExplodeSprite2;
	// private int m_iWaterExSprite;
	// private int m_iSteamSprite;

	void Spawn()
	{
		Precache();
		self.pev.movetype = MOVETYPE_BOUNCE;
		self.pev.solid = SOLID_BBOX;

		self.pev.gravity = 0.55f;
		self.pev.friction = 0.7f;
		self.pev.framerate = 1.0f;

		SetThink( ThinkFunction( this.TumbleThink ) );
		self.pev.nextthink = g_Engine.time + 0.1;

		g_EntityFuncs.SetSize( self.pev, Vector( -1, -1, -1 ), Vector( 1, 1, 1 ) );

		// if ( pfnProjectileSpawnHook !is null )
		// {
		// 	pfnProjectileSpawnHook( self );
		// }
	}

	void Precache()
	{
		//Models
		// m_iExplodeSprite 	= g_Game.PrecacheModel( "sprites/eexplo.spr" );
		// m_iExplodeSprite2	= g_Game.PrecacheModel( "sprites/fexplo.spr" );
		// m_iSteamSprite   	= g_Game.PrecacheModel( "sprites/steam1.spr" );
		// m_iWaterExSprite 	= g_Game.PrecacheModel( "sprites/WXplo1.spr" );

		//Sounds
		g_SoundSystem.PrecacheSound( BOUNCE_SOUND );
		g_Game.PrecacheGeneric( "sound/" + BOUNCE_SOUND );
	}

	void BounceTouch( CBaseEntity@ pOther )
	{
		// don't hit the guy that launched this grenade
		if ( @pOther.edict() == @self.pev.owner )
			return;

		// Only do damage if we're moving fairly fast
		// if( m_flNextAttack < g_Engine.time && self.pev.velocity.Length() > 100 )
		// {
		// 	entvars_t@ pevOwner = @self.pev.owner.vars;
		// 	if( pevOwner !is null )
		// 	{
		// 		TraceResult tr = g_Utility.GetGlobalTrace();
		// 		g_WeaponFuncs.ClearMultiDamage();
		// 		pOther.TraceAttack( pevOwner, 1, g_Engine.v_forward, tr, DMG_CLUB );
		// 		g_WeaponFuncs.ApplyMultiDamage( self.pev, pevOwner );
		// 	}
		// 	m_flNextAttack = g_Engine.time + 1.0; // debounce
		// }

		/*if( pOther.pev.ClassNameIs( "func_breakable" ) && pOther.pev.rendermode != kRenderNormal )
		{
			self.pev.velocity = self.pev.velocity * -2.0f;
			return;
		}*/

		bool bRemove = false;
		Vector vecTestVelocity;
		// this is my heuristic for modulating the grenade velocity because grenades dropped purely vertical
		// or thrown very far tend to slow down too quickly for me to always catch just by testing velocity.
		// trimming the Z velocity a bit seems to help quite a bit.
		vecTestVelocity = self.pev.velocity;
		vecTestVelocity.z *= 0.7f;

		if ( m_bRegisteredSound == false && vecTestVelocity.Length() <= 60.0f )
		{
			// grenade is moving really slow. It's probably very close to where it will ultimately stop moving.
			// go ahead and emit the danger sound.

			// register a radius louder than the explosion, so we make sure everyone gets out of the way
			GetSoundEntInstance().InsertSound( bits_SOUND_DANGER, self.pev.origin, int(self.pev.dmg / 0.5), 0.3, self );
			//CSoundEnt::InsertSound ( bits_SOUND_DANGER, pev->origin, pev->dmg / 0.5, 0.3, this );
			m_bRegisteredSound = true;
		}

		if ( self.pev.flags & FL_ONGROUND != 0 )
		{
			self.pev.velocity = self.pev.velocity * 0.8f;
			self.pev.sequence = 1;//Math.RandomLong( 1, 3 );

			if ( pfnProjectileImpactHook !is null )
			{
				bRemove = pfnProjectileImpactHook( self );
			}
		}
		else
		{
			self.pev.flags |= EF_NOINTERP;

			if ( pfnProjectileImpactHook !is null )
			{
				bRemove = pfnProjectileImpactHook( self );
			}

			if ( !bRemove )
				BounceSounds();
		}

		self.pev.framerate = self.pev.velocity.Length() / 200.0f;

		if ( self.pev.framerate > 1 )
			self.pev.framerate = 1.0f;
		else if ( self.pev.framerate < 0.5f )
			self.pev.framerate = 0;
		
		if ( bRemove )
		{
			g_EntityFuncs.Remove( self );
		}
	}

	void BounceSounds()
	{
		if( g_Engine.time < m_flBounceTime )
			return;

		m_flBounceTime = g_Engine.time + Math.RandomFloat( 0.2, 0.3 );

		if( g_Utility.GetGlobalTrace().flFraction < 1.0 )
		{
			if( g_Utility.GetGlobalTrace().pHit !is null )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( g_Utility.GetGlobalTrace().pHit );
				if( pHit.IsBSPModel() )
				{
					g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_ITEM, BOUNCE_SOUND, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
				}
			}
		}
	}

	void TumbleThink()
	{
		if( !self.IsInWorld() )
		{
			g_EntityFuncs.Remove( self );
			return;
		}

		self.StudioFrameAdvance();
		self.pev.nextthink = g_Engine.time + 0.1;

		// if ( self.pev.dmgtime != 0 )
		// {
			if ( !m_bTumbleThinkStarted )
			{
				if ( pfnProjectileSpawnHook !is null )
				{
					pfnProjectileSpawnHook( self );
				}

				m_bTumbleThinkStarted = true;
			}
		// }

		if ( self.pev.dmgtime <= g_Engine.time )
		{
			// SetThink( ThinkFunction( this.Detonate ) );

			if ( pfnProjectileDetonateHook !is null )
			{
				if ( pfnProjectileDetonateHook( self ) )
				{
					g_EntityFuncs.Remove( self );
					return;
				}
			}
			else
			{
				g_EntityFuncs.Remove( self );
				return;
			}
		}

		if( self.pev.waterlevel != WATERLEVEL_DRY && self.pev.iuser2 != NADE_MODE_IMPACT && self.pev.iuser2 != NADE_MODE_TRIP )
		{
			self.pev.velocity = self.pev.velocity * 0.5;
			self.pev.framerate = 0.2;

			self.pev.angles = Math.VecToAngles( self.pev.velocity );
		}
	}

	// void ExplodeMsg( Vector& in origin, float scale, int framerate )
	// {
	// 	int iContents = g_EngineFuncs.PointContents( origin );
	// 	NetworkMessage exp_msg( MSG_PAS, NetworkMessages::SVC_TEMPENTITY, self.GetOrigin(), null );
	// 		exp_msg.WriteByte( TE_EXPLOSION ); //MSG type enum
	// 		exp_msg.WriteCoord( origin.x ); //pos
	// 		exp_msg.WriteCoord( origin.y ); //pos
	// 		exp_msg.WriteCoord( origin.z ); //pos
	// 		if( iContents == CONTENTS_WATER || iContents == CONTENTS_SLIME || iContents == CONTENTS_LAVA ) //check if entity is in a liquid
	// 			exp_msg.WriteShort( m_iWaterExSprite );
	// 		else
	// 			exp_msg.WriteShort( m_iExplodeSprite2 );
	// 		exp_msg.WriteByte( int(scale) ); //scale
	// 		exp_msg.WriteByte( framerate ); //framerate
	// 		exp_msg.WriteByte( TE_EXPLFLAG_NONE ); //flag
	// 	exp_msg.End();
	// }

	// void ExplodeMsg2( Vector& in origin, float scale, int framerate )
	// {
	// 	int iContents = g_EngineFuncs.PointContents( origin );
	// 	NetworkMessage exp_msg( MSG_PAS, NetworkMessages::SVC_TEMPENTITY, self.GetOrigin(), null );
	// 		exp_msg.WriteByte( TE_EXPLOSION ); //MSG type enum
	// 		exp_msg.WriteCoord( origin.x ); //pos
	// 		exp_msg.WriteCoord( origin.y ); //pos
	// 		exp_msg.WriteCoord( origin.z ); //pos
	// 		if( iContents == CONTENTS_WATER || iContents == CONTENTS_SLIME || iContents == CONTENTS_LAVA ) //check if entity is in a liquid
	// 			exp_msg.WriteShort( m_iWaterExSprite );
	// 		else
	// 			exp_msg.WriteShort( m_iExplodeSprite );
	// 		exp_msg.WriteByte( int(scale) ); //scale
	// 		exp_msg.WriteByte( framerate ); //framerate
	// 		exp_msg.WriteByte( TE_EXPLFLAG_NONE ); //flag
	// 	exp_msg.End();
	// }

	// void Explode( TraceResult pTrace )
	// {
	// 	self.pev.model = string_t();
	// 	self.pev.solid = SOLID_NOT;
	// 	self.pev.takedamage = DAMAGE_NO;

	// 	entvars_t@ pevOwner;
	// 	if( self.pev.owner !is null )
	// 		@pevOwner = @self.pev.owner.vars;
	// 	else
	// 		@pevOwner = self.pev;

	// 	// Pull out of the wall a bit
	// 	if( pTrace.flFraction != 1.0 )
	// 	{
	// 		self.pev.origin = pTrace.vecEndPos + (pTrace.vecPlaneNormal * (self.pev.dmg - 24.0f) * 0.6f);
	// 	}

	// 	int iContents = g_EngineFuncs.PointContents( self.GetOrigin() );

	// 	ExplodeMsg( Vector( self.GetOrigin().x, self.GetOrigin().y, self.GetOrigin().z + 20.0f ), 25, 30 );
	// 	ExplodeMsg2( Vector( self.GetOrigin().x + Math.RandomFloat( -32, 32 ), self.GetOrigin().y + Math.RandomFloat( -32, 32 ), self.GetOrigin().z + Math.RandomFloat( 30, 35 ) ), 30, 30 );

	// 	g_Utility.Sparks( self.GetOrigin() );
	// 	GetSoundEntInstance().InsertSound( bits_SOUND_COMBAT, self.pev.origin, NORMAL_EXPLOSION_VOLUME, 3, self );

	// 	g_WeaponFuncs.RadiusDamage( self.GetOrigin(), self.pev, pevOwner, self.pev.dmg, self.pev.dmg * 2, CLASS_NONE, DMG_BLAST );
	// 	g_Utility.DecalTrace( pTrace, (Math.RandomLong( 0, 1 ) < 0.5) ? DECAL_SCORCH1 : DECAL_SCORCH2 );

	// 	self.pev.effects |= EF_NODRAW;
	// 	self.pev.velocity = g_vecZero;
	// 	SetThink( ThinkFunction( this.Smoke ) );
	// 	self.pev.nextthink = g_Engine.time + 0.55f;

	// 	if( iContents != CONTENTS_WATER )
	// 	{
	// 		int sparkCount = Math.RandomLong( 1, 3 );
	// 		for( int i = 0; i < sparkCount; i++ )
	// 			g_EntityFuncs.Create( "spark_shower", self.pev.origin, pTrace.vecPlaneNormal, false );
	// 	}
	// }

	// void Smoke()
	// {
	// 	int iContents = g_EngineFuncs.PointContents( self.GetOrigin() );
	// 	if( iContents == CONTENTS_WATER || iContents == CONTENTS_SLIME || iContents == CONTENTS_LAVA )
	// 	{
	// 		g_Utility.Bubbles( self.GetOrigin() - Vector( 64, 64, 64 ), self.GetOrigin() + Vector( 64, 64, 64 ), 100 );
	// 	}
	// 	else
	// 	{
	// 		NetworkMessage smk_msg( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, self.GetOrigin(), null );
	// 			smk_msg.WriteByte( TE_SMOKE ); //MSG type enum
	// 			smk_msg.WriteCoord( self.GetOrigin().x ); //pos
	// 			smk_msg.WriteCoord( self.GetOrigin().y ); //pos
	// 			smk_msg.WriteCoord( self.GetOrigin().z - 5.0f ); //pos
	// 			smk_msg.WriteShort( m_iSteamSprite );
	// 			smk_msg.WriteByte( 35 + Math.RandomLong( 0, 10 ) ); //scale
	// 			smk_msg.WriteByte( 5 ); //framerate
	// 		smk_msg.End();
	// 	}

	// 	g_EntityFuncs.Remove( self );
	// }

	// void Detonate()
	// {
	// 	self.pev.flags &= ~EF_NOINTERP;
	// 	TraceResult tr;
	// 	Vector vecSpot = self.GetOrigin() + Vector( 0, 0, 8 ); // trace starts here!
	// 	g_Utility.TraceLine( vecSpot, vecSpot + Vector( 0, 0, -40 ), ignore_monsters, self.pev.pContainingEntity, tr );
	// 	Explode( tr );
	// }

	// void Killed( entvars_t@ pevAttacker, int iGib )
	// {
	// 	Detonate();
	// }
}

CZpProjectile@ TossGrenade( entvars_t@ pevOwner, Vector vecStart, Vector vecVelocity, float flTime, float flDmg, string sModel, int iUserData = 0, int iUserData2 = 0, const string& in szName = DEFAULT_PROJ_NAME )
{
	CBaseEntity@ pZpProjectileBase = g_EntityFuncs.CreateEntity( szName );
	CZpProjectile@ pZpProjectile = cast<CZpProjectile@>( CastToScriptClass( pZpProjectileBase ) );

	g_EntityFuncs.SetOrigin( pZpProjectile.self, vecStart );
	g_EntityFuncs.SetModel( pZpProjectile.self, sModel );
	g_EntityFuncs.DispatchSpawn( pZpProjectile.self.edict() );

	pZpProjectile.pev.velocity = vecVelocity;
	pZpProjectile.pev.angles = Math.VecToAngles( pZpProjectile.pev.velocity );
	@pZpProjectile.pev.owner = pevOwner.pContainingEntity;

	pZpProjectile.pev.dmg = flDmg;
	pZpProjectile.pev.sequence = Math.RandomLong( 3, 6 );

	pZpProjectile.pev.iuser1 = iUserData;
	pZpProjectile.pev.iuser2 = iUserData2;

	pZpProjectile.SetTouch( TouchFunction( pZpProjectile.BounceTouch ) );

	if( flTime < 0.1 )
	{
		pZpProjectile.pev.nextthink = g_Engine.time;
		pZpProjectile.pev.velocity = g_vecZero;
	}

	if ( iUserData2 == NADE_MODE_IMPACT || iUserData2 == NADE_MODE_TRIP )
	{
		pZpProjectile.pev.dmgtime = g_Engine.time + 60.0f;
	}
	else if ( iUserData2 == NADE_MODE_HOMING )
	{
		pZpProjectile.pev.dmgtime = g_Engine.time;
	}
	else
	{
		pZpProjectile.pev.dmgtime = g_Engine.time + flTime;
	}

	return pZpProjectile;
}

bool RegisterProjectileSpawnHook(ProjectileSpawnHook@ func)
{
	if ( pfnProjectileSpawnHook !is null )
		return false;
	
	@pfnProjectileSpawnHook = @func;
	return true;
}

bool RegisterProjectileImpactHook(ProjectileImpactHook@ func)
{
	if ( pfnProjectileImpactHook !is null )
		return false;
	
	@pfnProjectileImpactHook = @func;
	return true;
}

bool RegisterProjectileDetonateHook(ProjectileDetonateHook@ func)
{
	if ( pfnProjectileDetonateHook !is null )
		return false;
	
	@pfnProjectileDetonateHook = @func;
	return true;
}

bool RemoveProjectileSpawnHook()
{
	if ( pfnProjectileSpawnHook is null )
		return false;
	
	@pfnProjectileSpawnHook = null;
	return true;
}

bool RemoveProjectileImpactHook()
{
	if ( pfnProjectileImpactHook is null )
		return false;
	
	@pfnProjectileImpactHook = null;
	return true;
}

bool RemoveProjectileDetonateHook()
{
	if ( pfnProjectileDetonateHook is null )
		return false;
	
	@pfnProjectileDetonateHook = null;
	return true;
}

void Register( const string& in szName = DEFAULT_PROJ_NAME )
{
	if( g_CustomEntityFuncs.IsCustomEntity( szName ) )
		return;

	g_CustomEntityFuncs.RegisterCustomEntity( "ZP_PROJECTILE::CZpProjectile", szName );
	g_Game.PrecacheOther( szName );
}

}