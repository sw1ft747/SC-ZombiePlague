//Counter-Strike 1.6 High Explosive Grenade [Redacted as Napalm Grenade for Zombie Plague Mod]
/* Model Credits
/ Model: Valve
/ Textures: Valve
/ Animations: Valve
/ Sounds: Valve
/ Sprites: Valve
/ Misc: Valve, D.N.I.O. 071 (Player Model Fix)
/ Script: KernCore, original base from Nero
*/

#include "../entities/zp_projectile"

namespace FIRE_GRENADE
{

// Animations
enum Fire_Grenade_Animations 
{
	IDLE = 0,
	PULLPIN,
	THROW,
	DRAW
};

int ZP_GRENADE_ID	= 1;

// Models
string W_MODEL  	= "models/zombie_plague/cs/w_hegrenade.mdl";
string V_MODEL  	= "models/zombie_plague/v_grenade_fire_lefthanded.mdl";
string P_MODEL  	= "models/zombie_plague/cs/p_hegrenade.mdl";

// Sounds
array<string> 		WeaponSoundEvents = {
					"zombie_plague/cs/grenade/pin.wav"
};
// Information
int MAX_CARRY   	= 1;
int MAX_CLIP    	= WEAPON_NOCLIP;
int DEFAULT_GIVE 	= 1;
int WEIGHT      	= 5;
int FLAGS       	= ITEM_FLAG_LIMITINWORLD | ITEM_FLAG_EXHAUSTIBLE;
uint DAMAGE     	= 100;
uint SLOT       	= 4;
uint POSITION   	= 4;
string AMMO_TYPE 	= GetName();
float TIMER      	= 1.5;

class weapon_firegrenade : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer
	{
		get const 	{ return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
		set       	{ self.m_hPlayer = EHandle( @value ); }
	}
	private bool m_bInAttack, m_bThrown;
	private float m_fAttackStart, m_flStartThrow;
	private int GetBodygroup()
	{
		return 0;
	}

	protected float WeaponTimeBase() // map time
	{
		return g_Engine.time;
	}

	void Spawn()
	{
		Precache();

		self.pev.dmg = DAMAGE;

		g_EntityFuncs.SetModel( self, self.GetW_Model( W_MODEL ) );
		self.m_iDefaultAmmo = DEFAULT_GIVE;
		self.pev.scale = 1.4;

		self.FallInit();
		
		self.pev.scale = 1;
	}

	void Precache()
	{
		self.PrecacheCustomModels();

		//Models
		g_Game.PrecacheModel( W_MODEL );
		g_Game.PrecacheModel( V_MODEL );
		g_Game.PrecacheModel( P_MODEL );

		//Entities
		g_Game.PrecacheOther( ZP_PROJECTILE::DEFAULT_PROJ_NAME );

		//Sounds
		for (uint i = 0; i < WeaponSoundEvents.length(); i++)
        {
            g_SoundSystem.PrecacheSound( WeaponSoundEvents[i] );
            g_Game.PrecacheGeneric( "sound/" + WeaponSoundEvents[i] );
        }
		
		//Sprites
		g_Game.PrecacheGeneric( "sprites/zombie_plague/cs/640hud3.spr" );
		g_Game.PrecacheGeneric( "sprites/zombie_plague/cs/640hud6.spr" );
		g_Game.PrecacheGeneric( "sprites/zombie_plague/cs/640hud7.spr" );

		g_Game.PrecacheGeneric( "sprites/zombie_plague/weapons/weapon_firegrenade.txt" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= MAX_CARRY;
		info.iMaxAmmo2 	= -1;
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

	// Better ammo extraction --- Anggara_nothing
	bool CanHaveDuplicates()
	{
		return true;
	}

	private int m_iAmmoSave;
	bool Deploy()
	{
		m_iAmmoSave = 0; // Zero out the ammo save

		self.DefaultDeploy( self.GetV_Model( V_MODEL ), self.GetP_Model( P_MODEL ), DRAW, "gren", 0, GetBodygroup() );
		self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flNextTertiaryAttack = WeaponTimeBase() + (22.0/30.0);

		return true;
	}

	bool CanHolster()
	{
		if( m_fAttackStart != 0 )
			return false;

		return true;
	}

	bool CanDeploy()
	{
		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType) == 0 )
			return false;

		return true;
	}

	private CBasePlayerItem@ DropItem() // never drop
	{
		// m_iAmmoSave = m_pPlayer.AmmoInventory( self.m_iPrimaryAmmoType ); //Save the player's ammo pool in case it has any in DropItem

		// return self;

		return null;
	}

	void Holster( int skipLocal = 0 )
	{
		m_bThrown = false;
		m_bInAttack = false;
		m_fAttackStart = 0;
		m_flStartThrow = 0;

		self.m_fInReload = false;
		SetThink( null );

		m_pPlayer.pev.fuser4 = 0;

		ResetFoV();

		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) > 0 ) //Save the player's ammo pool in case it has any in Holster
		{
			m_iAmmoSave = m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType );
		}

		if( m_iAmmoSave <= 0 )
		{
			SetThink( ThinkFunction( DestroyThink ) );
			self.pev.nextthink = g_Engine.time + 0.1;
		}

		BaseClass.Holster( skipLocal );
	}

	void PrimaryAttack()
	{
		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0  )
			return;

		if( m_fAttackStart < 0 || m_fAttackStart > 0 )
			return;

		self.m_flNextPrimaryAttack = WeaponTimeBase() + (20.0/41.0);
		self.SendWeaponAnim( PULLPIN, 0, GetBodygroup() );

		m_bInAttack = true;
		m_fAttackStart = g_Engine.time + (20.0/41.0);

		self.m_flTimeWeaponIdle = g_Engine.time + (20.0/41.0) + (23.0/30.0);
	}

	void LaunchThink()
	{
		//g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_VOICE, SHOOT_S, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
		Vector angThrow = m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle;

		if ( angThrow.x < 0 )
			angThrow.x = -10 + angThrow.x * ( (90 - 10) / 90.0 );
		else
			angThrow.x = -10 + angThrow.x * ( (90 + 10) / 90.0 );

		float flVel = (90.0f - angThrow.x) * 6;

		if ( flVel > 750.0f )
			flVel = 750.0f;

		Math.MakeVectors( angThrow );

		Vector vecSrc = m_pPlayer.pev.origin + m_pPlayer.pev.view_ofs + g_Engine.v_forward * 16;
		Vector vecThrow = g_Engine.v_forward * flVel + m_pPlayer.pev.velocity;

		int iUserData = ZP_GRENADE_ID;

		if ( g_bIsZombie[m_pPlayer.entindex()] )
			iUserData = iUserData | 1024;

		ZP_PROJECTILE::CZpProjectile@ pZpProjectile = ZP_PROJECTILE::TossGrenade( m_pPlayer.pev, vecSrc, vecThrow, TIMER, DAMAGE, W_MODEL, iUserData, g_iNadeMode[m_pPlayer.entindex()] );

		m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) - 1 );
		m_fAttackStart = 0;
	}

	void DestroyThink() // destroys the item
	{
		SetThink( null );
		self.DestroyItem();
		//g_Game.AlertMessage( at_console, "Item Destroyed.\n" );
	}

	void ItemPreFrame()
	{
		if( m_fAttackStart == 0 && m_bThrown == true && m_bInAttack == false && self.m_flTimeWeaponIdle - 0.1 < g_Engine.time )
		{
			if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) == 0 )
			{
				self.Holster();
			}
			else
			{
				self.Deploy();
				m_bThrown = false;
				m_bInAttack = false;
				m_fAttackStart = 0;
				m_flStartThrow = 0;
			}
		}

		if( !m_bInAttack || CheckButton() || g_Engine.time < m_fAttackStart )
			return;

		self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flNextTertiaryAttack = WeaponTimeBase() + (17.0/30.0);
		self.SendWeaponAnim( THROW, 0, GetBodygroup() );
		m_bThrown = true;
		m_bInAttack = false;
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		// SetThink( ThinkFunction( this.LaunchThink ) );
		// self.pev.nextthink = g_Engine.time + 0.0;

		BaseClass.ItemPreFrame();
		
		LaunchThink();
	}

	void WeaponIdle()
	{
		if( self.m_flTimeWeaponIdle > WeaponTimeBase() )
			return;

		self.SendWeaponAnim( IDLE, 0, GetBodygroup() );
		self.m_flTimeWeaponIdle = WeaponTimeBase() + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 5, 7 );
	}

	bool CheckButton() // returns which key the player is pressing (that might interrupt the reload)
	{
		return m_pPlayer.pev.button & (IN_ATTACK | IN_ATTACK2 | IN_ALT1) != 0;
	}

	void ResetFoV( string& in szAnimExtension = "sniper" )
	{
		m_pPlayer.ResetVModelPos();
		ToggleZoom( 0 );

		m_pPlayer.SetMaxSpeedOverride( -1 ); //m_pPlayer.pev.maxspeed = 0;

		m_pPlayer.m_szAnimExtension = szAnimExtension;
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
}

string GetName()
{
	return "weapon_firegrenade";
}

void Register()
{
	ZP_PROJECTILE::Register();

	// Check if the Weapon Entity Name doesn't exist yet
	if( !g_CustomEntityFuncs.IsCustomEntity( GetName() ) )
	{
		g_CustomEntityFuncs.RegisterCustomEntity( "FIRE_GRENADE::weapon_firegrenade", GetName() ); // Register the weapon entity
		g_ItemRegistry.RegisterWeapon( GetName(), "zombie_plague/weapons/", AMMO_TYPE, "", "" ); // Register the weapon
	}
}

}