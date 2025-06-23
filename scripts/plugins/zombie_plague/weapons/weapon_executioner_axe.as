// Counter-Strike 1.6 Badlands Bowie Knife [Redacted as Executioner Axe for Zombie Plague Mod]
/* Model Sounds: Valve
/ Model Sprites: Valve, R4to0
/ Misc: Valve, D.N.I.O. 071 (Player Model Fix)
/ Script: KernCore
*/

namespace EXECUTIONER_AXE
{

// Animations
enum Executioner_Axe_Animation
{
	KNIFE_IDLE1 = 0,
	KNIFE_ATTACK2HIT,
	KNIFE_ATTACK3HIT,
	KNIFE_DRAW,
	KNIFE_ATTACK2,
	KNIFE_ATTACK1MISS,
	KNIFE_ATTACK1,
	KNIFE_ATTACK3
};

// Models
string W_MODEL  	= "models/zombie_plague/null.mdl";
string V_MODEL  	= "models/zombie_plague/v_executioner_axe.mdl";
string P_MODEL  	= "models/zombie_plague/null.mdl";

// Sounds
string STAB_S   	= "zombie_plague/weapons/executioner_axe/stab1.wav"; //stab
string DEPLOY_S 	= "zombie_plague/weapons/executioner_axe/deploy.wav"; //deploy1
string HITWALL_S 	= "zombie_plague/weapons/executioner_axe/hitwall1.wav"; //hitwall1
array<string> 		KnifeHitFleshSounds =
{
					"zombie_plague/weapons/executioner_axe/hit1.wav",
					"zombie_plague/weapons/executioner_axe/hit2.wav",
					"zombie_plague/weapons/executioner_axe/hit3.wav"
};
array<string> 		KnifeSlashSounds =
{
					"zombie_plague/weapons/executioner_axe/slash1.wav", //slash1
					"zombie_plague/weapons/executioner_axe/slash2.wav"  //slash2
};

// Information
int MAX_CARRY   	= -1;
int MAX_CLIP    	= WEAPON_NOCLIP;
int DEFAULT_GIVE 	= 0;
int WEIGHT      	= 5;
int FLAGS       	= -1;
uint DAMAGE_SLASH 	= 45;
uint DAMAGE_STAB 	= 60;
uint SLOT       	= 0;
uint POSITION   	= 6;
string AMMO_TYPE 	= "";
float SLASH_DIST 	= 48.0f;
float STAB_DIST  	= 32.0f;

class weapon_executioner_axe : ScriptBasePlayerWeaponEntity
{
    protected TraceResult m_trHit;
	protected int m_iSwing = 0;

	private CBasePlayer@ m_pPlayer
	{
		get const 	{ return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
		set       	{ self.m_hPlayer = EHandle( @value ); }
	}
	private int GetBodygroup()
	{
		return 0;
	}

    protected float WeaponTimeBase() // map time
	{
		return g_Engine.time;
	}

	CBasePlayerItem@ DropItem() // never drop
	{
		return null;
	}

	void Spawn()
	{
		Precache();
		//self.m_iClip = -1;
		self.m_flCustomDmg = self.pev.dmg;

        g_EntityFuncs.SetModel( self, self.GetW_Model( W_MODEL ) );
		self.m_iDefaultAmmo = DEFAULT_GIVE;
		self.pev.scale = 1.4;

		self.FallInit();
	}

	void Precache()
	{
		self.PrecacheCustomModels();

		//Models
		g_Game.PrecacheModel( W_MODEL );
		g_Game.PrecacheModel( V_MODEL );
		g_Game.PrecacheModel( P_MODEL );

		//Sounds
        g_SoundSystem.PrecacheSound( DEPLOY_S );
	    g_Game.PrecacheGeneric( "sound/" + DEPLOY_S );

        g_SoundSystem.PrecacheSound( STAB_S );
	    g_Game.PrecacheGeneric( "sound/" + STAB_S );

        g_SoundSystem.PrecacheSound( HITWALL_S );
	    g_Game.PrecacheGeneric( "sound/" + HITWALL_S );

        for (uint i = 0; i < KnifeHitFleshSounds.length(); i++)
        {
            g_SoundSystem.PrecacheSound( KnifeHitFleshSounds[i] );
            g_Game.PrecacheGeneric( "sound/" + KnifeHitFleshSounds[i] );
        }

        for (uint i = 0; i < KnifeSlashSounds.length(); i++)
        {
            g_SoundSystem.PrecacheSound( KnifeSlashSounds[i] );
            g_Game.PrecacheGeneric( "sound/" + KnifeSlashSounds[i] );
        }

		//Sprites
		//HUD
		g_Game.PrecacheGeneric( "sprites/zombie_plague/cs/640hud7.spr" );
		g_Game.PrecacheGeneric( "sprites/zombie_plague/cs/640hud10.spr" );
		g_Game.PrecacheGeneric( "sprites/zombie_plague/cs/640hud11.spr" );

		g_Game.PrecacheGeneric( "sprites/zombie_plague/weapons/weapon_executioner_axe.txt" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= MAX_CARRY;
		info.iAmmo1Drop	= MAX_CLIP;
		info.iMaxAmmo2 	= -1;
		info.iAmmo2Drop	= -1;
		info.iMaxClip 	= MAX_CLIP;
		info.iSlot  	= SLOT;
		info.iPosition 	= POSITION;
		info.iId     	= g_ItemRegistry.GetIdForName( self.pev.classname );
		info.iFlags 	= FLAGS;
		info.iWeight 	= WEIGHT;

		return true;
	}

	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( !BaseClass.AddToPlayer( pPlayer ) )
			return false;

		NetworkMessage weapon( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
			weapon.WriteShort( g_ItemRegistry.GetIdForName( self.pev.classname ) );
		weapon.End();

		return true;
	}

	bool Deploy()
	{
		g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_ITEM, DEPLOY_S, 1, ATTN_NORM );

        self.DefaultDeploy( self.GetV_Model( V_MODEL ), self.GetP_Model( P_MODEL ), KNIFE_DRAW, "crowbar", 0, GetBodygroup() );
		self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flNextTertiaryAttack = WeaponTimeBase() + 1.45f;
		return true;
	}

	void Holster( int skiplocal = 0 )
	{
		self.m_fInReload = false;
		SetThink( null );

		m_pPlayer.pev.fuser4 = 0;

		ResetFoV();

		BaseClass.Holster( skiplocal );
	}

	void PrimaryAttack()
	{
		Swing( DAMAGE_SLASH, KnifeSlashSounds[Math.RandomLong( 0, KnifeSlashSounds.length() - 1)], KnifeHitFleshSounds[Math.RandomLong( 0, KnifeHitFleshSounds.length() - 1)], HITWALL_S,
			KNIFE_ATTACK2HIT, KNIFE_ATTACK3HIT, GetBodygroup(), SLASH_DIST );
	}

	void SecondaryAttack()
	{
		Stab( DAMAGE_STAB, KnifeSlashSounds[Math.RandomLong( 0, KnifeSlashSounds.length() - 1)], STAB_S, HITWALL_S, KNIFE_ATTACK2, KNIFE_ATTACK1MISS, GetBodygroup(), STAB_DIST );
	}

	void WeaponIdle()
	{
		if( self.m_flTimeWeaponIdle > WeaponTimeBase() )
			return;

		self.SendWeaponAnim( KNIFE_IDLE1, 0, GetBodygroup() );

		self.m_flTimeWeaponIdle = WeaponTimeBase() + 4.03f;
	}

	void SetFOV( int fov )
	{
		m_pPlayer.pev.fov = m_pPlayer.m_iFOV = fov;
	}
	
	void ToggleZoom( int zoomedFOV )
	{
		if ( self.m_fInZoom == true )
		{
			SetFOV( 0 ); // 0 means reset to default fov
		}
		else if ( self.m_fInZoom == false )
		{
			SetFOV( zoomedFOV );
		}
	}

    void ResetFoV( string& in szAnimExtension = "sniper" )
	{
		m_pPlayer.ResetVModelPos();
		ToggleZoom( 0 );

		m_pPlayer.SetMaxSpeedOverride( -1 ); //m_pPlayer.pev.maxspeed = 0;

		m_pPlayer.m_szAnimExtension = szAnimExtension;
	}

    bool Swing( float flDamage, string szSwingSound, string szHitFleshSound, string szHitWallSound, int& in iAnimAtk1, int& in iAnimAtk2, int& in iBodygroup, 
		float flHitDist = 48.0f, float flMissNextPriAtk = 0.35f, float flHitNextPriAtk = 0.4f, float flNextSecAtk = 0.5f )
	{
		TraceResult tr;
		bool fDidHit = false;

		Math.MakeVectors( m_pPlayer.pev.v_angle );
		Vector vecSrc	= m_pPlayer.GetGunPosition();
		Vector vecEnd	= vecSrc + g_Engine.v_forward * flHitDist;

		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

		if( tr.flFraction >= 1.0 )
		{
			g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, m_pPlayer.edict(), tr );
			if( tr.flFraction < 1.0 )
			{
				// Calculate the point of intersection of the line (or hull) and the object we hit
				// This is and approximation of the "best" intersection
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
				if( pHit is null || pHit.IsBSPModel() == true )
					g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, m_pPlayer.edict() );

				vecEnd = tr.vecEndPos;	// This is the point on the actual surface (the hull could have hit space)
			}
		}

		if( tr.flFraction >= 1.0 ) //Missed
		{
			switch( (m_iSwing++) % 2 )
			{
				case 0:
				{
					self.SendWeaponAnim( iAnimAtk1, 0, iBodygroup );
					break;
				}

				case 1:
				{
					self.SendWeaponAnim( iAnimAtk2, 0, iBodygroup );
					break;
				}
			}

			self.m_flNextPrimaryAttack = g_Engine.time + flMissNextPriAtk;
			self.m_flNextSecondaryAttack = g_Engine.time + flNextSecAtk;
			self.m_flTimeWeaponIdle = g_Engine.time + 2.3f;

			// play wiff or swish sound
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, szSwingSound, 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
			m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); // player "shoot" animation
		}
		else
		{
			// hit
			fDidHit = true;
			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

			switch( (m_iSwing++) % 2 )
			{
				case 0:
				{
					self.SendWeaponAnim( iAnimAtk1, 0, iBodygroup );
					break;
				}

				case 1:
				{
					self.SendWeaponAnim( iAnimAtk2, 0, iBodygroup );
					break;
				}
			}

			self.m_flNextPrimaryAttack = g_Engine.time + flHitNextPriAtk;
			self.m_flNextSecondaryAttack = g_Engine.time + flNextSecAtk;
			self.m_flTimeWeaponIdle = g_Engine.time + 2.3f;

			// player "shoot" animation
			m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

			// AdamR: Custom damage option
			if( self.m_flCustomDmg > 0 )
				flDamage = self.m_flCustomDmg;
			// AdamR: End

			g_WeaponFuncs.ClearMultiDamage();

			if( self.m_flNextPrimaryAttack + 0.4f < g_Engine.time )
				pEntity.TraceAttack( m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_SLASH | DMG_CLUB ); // first swing does full damage
			else
				pEntity.TraceAttack( m_pPlayer.pev, flDamage * 0.75, g_Engine.v_forward, tr, DMG_SLASH | DMG_CLUB ); // subsequent swings do 75% (Changed -Sniper)

			g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );

			// play thwack, smack, or dong sound
			float flVol = 1.0;
			bool fHitWorld = true;

			if( pEntity !is null )
			{
				if( pEntity.Classify() != CLASS_NONE && pEntity.Classify() != CLASS_MACHINE && pEntity.BloodColor() != DONT_BLEED )
				{
					if( pEntity.IsPlayer() ) // aone: lets pull them
					{
						pEntity.pev.velocity = pEntity.pev.velocity + (self.pev.origin - pEntity.pev.origin).Normalize() * 120;
					} // aone: end

					// play thwack or smack sound
					g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, szHitFleshSound, 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
					m_pPlayer.m_iWeaponVolume = 128;

					if( !pEntity.IsAlive() )
						return true;
					else
						flVol = 0.1;

					fHitWorld = false;
				}
			}

			// play texture hit sound
			// UNDONE: Calculate the correct point of intersection when we hit with the hull instead of the line

			if( fHitWorld )
			{
				float fvolbar = g_SoundSystem.PlayHitSound( tr, vecSrc, vecSrc + ( vecEnd - vecSrc ) * 2, BULLET_PLAYER_CROWBAR );
				//self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.35; //0.25

				fvolbar = 1;

				// also play melee strike
				g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, szHitWallSound, fvolbar, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) );
			}

			// delay the decal a bit
			m_trHit = tr;
			SetThink( ThinkFunction( Smack ) );
			self.pev.nextthink = g_Engine.time + 0.2;

			m_pPlayer.m_iWeaponVolume = int(flVol * 512);
		}

		return fDidHit;
	}

	void Smack()
	{
		g_WeaponFuncs.DecalGunshot( m_trHit, BULLET_PLAYER_CROWBAR );
	}

	bool Stab( float flDamage, string szSwingSound, string szHitFleshSound, string szHitWallSound, int& in iAnimAtkMiss, int& in iAnimAtkHit, int& in iBodygroup, 
		float flHitDist = 32.0f, float flMissNextAtk = 2.0f, float flHitNextAtk = 2.1f )
	{
		TraceResult tr;
		bool fDidHit = false;

		Math.MakeVectors( m_pPlayer.pev.v_angle );
		Vector vecSrc	= m_pPlayer.GetGunPosition();
		Vector vecEnd	= vecSrc + g_Engine.v_forward * flHitDist;

		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

		if( tr.flFraction >= 1.0 )
		{
			g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, m_pPlayer.edict(), tr );
			if( tr.flFraction < 1.0 )
			{
				// Calculate the point of intersection of the line (or hull) and the object we hit
				// This is and approximation of the "best" intersection
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
				if( pHit is null || pHit.IsBSPModel() == true )
					g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, m_pPlayer.edict() );

				vecEnd = tr.vecEndPos;	// This is the point on the actual surface (the hull could have hit space)
			}
		}

		if( tr.flFraction >= 1.0 ) //Missed
		{
			self.SendWeaponAnim( iAnimAtkMiss, 0, iBodygroup );

			self.m_flNextPrimaryAttack = g_Engine.time + flMissNextAtk;
			self.m_flNextSecondaryAttack = g_Engine.time + flMissNextAtk;
			self.m_flTimeWeaponIdle = g_Engine.time + 2.0f;

			// play wiff or swish sound
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, szSwingSound, 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
			m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); // player "shoot" animation
		}
		else
		{
			// hit
			fDidHit = true;
			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

			self.SendWeaponAnim( iAnimAtkHit, 0, iBodygroup );

			self.m_flNextPrimaryAttack = g_Engine.time + flHitNextAtk;
			self.m_flNextSecondaryAttack = g_Engine.time + flHitNextAtk;
			self.m_flTimeWeaponIdle = g_Engine.time + 2.0f;

			// player "shoot" animation
			m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

			// AdamR: Custom damage option
			if( self.m_flCustomDmg > 0 )
				flDamage = self.m_flCustomDmg;
			// AdamR: End

			if( pEntity !is null && pEntity.IsAlive() && !pEntity.IsBSPModel() && (pEntity.BloodColor() != DONT_BLEED || pEntity.Classify() != CLASS_MACHINE) )
			{
				Vector2D vec2LOS;
				float flDot;
				Vector vMyForward = g_Engine.v_forward;

				Math.MakeVectors( pEntity.pev.angles );

				vec2LOS = vMyForward.Make2D();
				vec2LOS = vec2LOS.Normalize();

				flDot = DotProduct( vec2LOS, g_Engine.v_forward.Make2D() );

				//Triple the damage if we are stabbing them in the back.
				if( flDot > 0.80f )
				{
					flDamage *= 3.0f;
				}
			}

			g_WeaponFuncs.ClearMultiDamage();
			pEntity.TraceAttack( m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_SLASH | DMG_CLUB );
			g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );

			// play thwack, smack, or dong sound
			float flVol = 1.0;
			bool fHitWorld = true;

			if( pEntity !is null )
			{
				if( pEntity.Classify() != CLASS_NONE && pEntity.Classify() != CLASS_MACHINE && pEntity.BloodColor() != DONT_BLEED )
				{
					if( pEntity.IsPlayer() ) // aone: lets pull them
					{
						pEntity.pev.velocity = pEntity.pev.velocity + (self.pev.origin - pEntity.pev.origin).Normalize() * 120;
					} // aone: end

					// play thwack or smack sound
					g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, szHitFleshSound, 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
					m_pPlayer.m_iWeaponVolume = 128;

					if( !pEntity.IsAlive() )
						return true;
					else
						flVol = 0.1;

					fHitWorld = false;
				}
			}

			// play texture hit sound
			// UNDONE: Calculate the correct point of intersection when we hit with the hull instead of the line

			if( fHitWorld )
			{
				float fvolbar = g_SoundSystem.PlayHitSound( tr, vecSrc, vecSrc + ( vecEnd - vecSrc ) * 2, BULLET_PLAYER_CROWBAR );
				//self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.35; //0.25

				fvolbar = 1;

				// also play melee strike
				g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, szHitWallSound, fvolbar, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) );
			}

			// delay the decal a bit
			m_trHit = tr;
			SetThink( ThinkFunction( Smack ) );
			self.pev.nextthink = g_Engine.time + 0.2;

			m_pPlayer.m_iWeaponVolume = int(flVol * 512);
		}

		return fDidHit;
	}
}

string GetName()
{
	return "weapon_executioner_axe";
}

void Register()
{
    // Check if the Weapon Entity Name doesn't exist yet
	if( !g_CustomEntityFuncs.IsCustomEntity( GetName() ) )
	{
		g_CustomEntityFuncs.RegisterCustomEntity( "EXECUTIONER_AXE::weapon_executioner_axe", GetName() ); // Register the weapon entity
		g_ItemRegistry.RegisterWeapon( GetName(), "zombie_plague/weapons/", AMMO_TYPE, "", "" ); // Register the weapon
	}
}

}