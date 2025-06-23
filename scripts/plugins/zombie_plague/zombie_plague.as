/** [SZP] Sven Zombie Plague BETA
 * Conversion of Zombie Plague mod for Sven Co-op
 * Huge Thanks to MeRcyLeZZ for the best Mod ever
 * Author: Sw1ft
 * Original Author: MeRcyLeZZ
 * Source code of custom weapons was taken from KernCore's CS 1.6 Weapons Project, all credits belong to him and people who worked on his project
 * It was a mistake to use procedural programming bruh
*/

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//
//                          Zombie Plague Core
//
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Include additional scripts
//-----------------------------------------------------------------------------

#include "cs16/cs16_register"

#include "weapons/weapon_executioner_axe"
#include "weapons/weapon_zombieknife"
#include "weapons/weapon_firegrenade"
#include "weapons/weapon_frostgrenade"
#include "weapons/weapon_flaregrenade"
#include "weapons/weapon_infectgrenade"
#include "weapons/weapon_holygrenade"
#include "weapons/weapon_jumpgrenade"
#include "weapons/weapon_force_field_grenade"

#include "entities/zp_force_field"
#include "entities/zp_lasermine"
#include "entities/zp_sandbags"

#include "commands"
#include "weapons_selection"
#include "classes"
#include "extras"

#include "rtv"

//-----------------------------------------------------------------------------
// CVars / ConCommands
//-----------------------------------------------------------------------------

CCVar@ zp_mode; // force game mode
CCVar@ zp_lighting; // map lighting
CCVar@ zp_fog; // map fog

//-----------------------------------------------------------------------------
// Classes
//-----------------------------------------------------------------------------

funcdef void CommandCallback(CBasePlayer@);
funcdef void ExtraBuyCallback(CExtraItem@, CBasePlayer@);

class CUserCommand
{
	CUserCommand(string sChatCommand, string sConsoleCommand, CommandCallback@ pfnCommandCallback, bool bHide)
	{
		m_sChatCommand = sChatCommand;
		m_sConsoleCommand = sConsoleCommand;
        m_bHide = bHide;
		@m_pfnCommandCallback = pfnCommandCallback;
	}

	string m_sChatCommand;
	string m_sConsoleCommand;
    bool m_bHide;
    CommandCallback@ m_pfnCommandCallback;
}

class CExtraItem
{
	CExtraItem(string sName, int iCost, ExtraBuyCallback@ pfnExtraBuyCallback)
	{
		m_sName = sName;
		m_iCost = iCost;
		@m_pfnExtraBuyCallback = pfnExtraBuyCallback;
	}

	string m_sName;
	int m_iCost;
    ExtraBuyCallback@ m_pfnExtraBuyCallback;
}

class CZombieClass
{
	CZombieClass(string sName, string sInfo, string sModel, float flHealth, int iSpeed, float flGravity, float flKnockback, int iUserData = 0, float flUserData = 0.0f)
	{
		m_sName = sName;
		m_sInfo = sInfo;
		m_sModel = sModel;
		m_flHealth = flHealth;
		m_iSpeed = iSpeed;
		m_flGravity = flGravity;
		m_flKnockback = flKnockback;

        m_iUserData = iUserData;
        m_flUserData = flUserData;
	}

	string m_sName;
	string m_sInfo;
	string m_sModel;
	float m_flHealth;
	int m_iSpeed;
	float m_flGravity;
	float m_flKnockback;

    int m_iUserData;
    float m_flUserData;
}

class CPrimaryWeapon
{
	CPrimaryWeapon(string sName, string sEntityName)
	{
		m_sName = sName;
		m_sEntityName = sEntityName;
	}

	string m_sName;
	string m_sEntityName;
}

class CSecondaryWeapon
{
	CSecondaryWeapon(string sName, string sEntityName)
	{
		m_sName = sName;
		m_sEntityName = sEntityName;
	}

	string m_sName;
	string m_sEntityName;
}

//-----------------------------------------------------------------------------
// Constants & enums
//-----------------------------------------------------------------------------

enum State
{
    ZP_STATE_HIBERNATION = 0,
    ZP_STATE_WAITING_PLAYERS,
    ZP_STATE_GAME_PREPARING,
    ZP_STATE_GAME_STARTED,
    ZP_STATE_GAME_END
}

enum Mode
{
    ZP_MODE_NONE = 0, // invalid mode
    ZP_MODE_SINGLE_INFECTION, // first infected Player
    ZP_MODE_MULTIPLE_INFECTION, // multiple infected Players
    ZP_MODE_PLAGUE, // 50 % Humans (+1 Survivor), 50 % Zombies (+1 Nemesis)
    ZP_MODE_SWARM, // 50 % Humans (can't be infected), 50 % Zombies
    ZP_MODE_NEMESIS, // 1 Nemesis against Humans
    ZP_MODE_ASSASSIN, // 1 Assassin against Humans
    ZP_MODE_SURVIVOR, // 1 Survivor against Zombies
    ZP_MODE_SNIPER, // 1 Sniper against Zombies
    ZP_MODE_ARMAGEDDON, // 50 % Survivors, 50 % Nemesis
    ZP_MODE_APOCALYPSE, // 50 % Snipers, 50 % Assassins
    ZP_MODE_NIGHTMARE // 25 % Snipers, 25 % Survivors, 25 % Nemesis, 25 % Assassins
}

enum HumanType
{
    ZP_HUMAN_DEFAULT = 0,
    ZP_HUMAN_SURVIVOR,
    ZP_HUMAN_SNIPER
}

enum ZombieType
{
    ZP_ZOMBIE_DEFAULT = 0,
    ZP_ZOMBIE_NEMESIS,
    ZP_ZOMBIE_ASSASSIN
}

enum NadeMode
{
    NADE_MODE_NORMAL = 0,
    NADE_MODE_PROXIMITY,
    NADE_MODE_IMPACT,
    NADE_MODE_TRIP,
    NADE_MODE_MOTION,
    NADE_MODE_SATCHEL,
    NADE_MODE_HOMING,
    NADE_MODE_LAST = NADE_MODE_HOMING
}

// TODO: convert these constants to cvars
// Misc
const int UNIT_SECOND = ( 1 << 12 );
const int HUD_CHAN_TIMER = 0;
const int HUD_CHAN_COUNTDOWN = 2;
const int HUD_CHAN_STATS = 4;
const int HUD_CHAN_SPECT = 5;
const int HUD_CHAN_INFECT = 6;
const int HUD_CHAN_EVENT = 7;
const float HUD_COUNTDOWN_X = -1.0f;
const float HUD_COUNTDOWN_Y = 0.32f;
const float HUD_EVENT_X = -1.0f;
const float HUD_EVENT_Y = 0.17f;
const float HUD_INFECT_X = 0.05f;
const float HUD_INFECT_Y = 0.45f;
const float HUD_SPECT_X = 0.6f;
const float HUD_SPECT_Y = 0.8f;
const float HUD_STATS_X = 0.02f;
const float HUD_STATS_Y = 0.9f;

// Zombie Escape
const float ZP_ZE_PREPARATION_TIME = 11.0f;
const float ZP_ZE_ZOMBIE_RESPAWN_DELAY = 10.0f;
const float ZP_ZE_ZOMBIE_HP_MULTI = 2.0f;
const float ZP_ZE_MULTI_RATIO = 0.25f; // Multiple Infection mode, zombie infect ratio for Zombie Escape

// General
const float ZP_WAITING_PLAYERS_TIME = 20.0f;
const float ZP_PREPARATION_TIME = 20.0f;
const float ZP_GAME_TIME = 300.0f;
const int ZP_GAME_TIME_WARNING = 30;
const float ZP_THUNDER_CLAP = 90.0f;
const int ZP_START_AMMO_PACKS = 0;
const bool ZP_DAMAGE_WHILE_FROZEN = false;
const bool ZP_DAMAGE_INDICATOR = true;

const int ZP_TEAM_HUMAN = CLASS_PLAYER;
const int ZP_TEAM_ZOMBIE = CLASS_TEAM2;

// Hostname
const bool ZP_CHANGE_HOSTNAME = true;
const string ZP_HOSTNAME = "Half-Life A - Zombie Plague OG";
const string ZP_HOSTNAME_DEFAULT = "Half-Life A";

// Wootguy's Anti-Cheat frfr
const bool ZP_ENABLE_ANTICHEAT = true;

// Anti-Bunnyhop
const bool ZP_ANTIBUNNYHOP = true;
const float ZP_ANTIBUNNYHOP_SLOWDOWN_FACTOR = 0.87f;
const float ZP_ANTIBUNNYHOP_DUCK_SLOWDOWN_FACTOR = 0.7f;

// Weather
const int ZP_FOG_COLOR_R = 128;
const int ZP_FOG_COLOR_G = 128;
const int ZP_FOG_COLOR_B = 128;
const int ZP_FOG_START_DIST = 600;
const int ZP_FOG_END_DIST = 1200;

// Force field
const bool ZP_FORCE_FIELD_RANDOM_COLOR = true;
const float ZP_FORCE_FIELD_PUSH_STRENGTH = 5.0f;
const float ZP_FORCE_FIELD_DURATION = 15.0f;

// Laser mine
const int ZP_LASERMINE_MAX_CARRY_LIMIT = 2;
const float ZP_LASERMINE_HEALTH = 2000.0f;
const float ZP_LASERMINE_HIT_DAMAGE = 100.0f;
const float ZP_LASERMINE_BEAM_HIT_INTERVAL = 1.0f;
const float ZP_LASERMINE_HUMAN_COLOR_R = 0.0f;
const float ZP_LASERMINE_HUMAN_COLOR_G = 0.0f;
const float ZP_LASERMINE_HUMAN_COLOR_B = 255.0f;
const float ZP_LASERMINE_ZOMBIE_COLOR_R = 0.0f;
const float ZP_LASERMINE_ZOMBIE_COLOR_G = 255.0f;
const float ZP_LASERMINE_ZOMBIE_COLOR_B = 0.0f;

// Sandbags
const int ZP_SANDBAGS_MAX_CARRY_LIMIT = 1;
const float ZP_SANDBAGS_HEALTH = 3000.0f;
const float ZP_SANDBAGS_PLACE_COOLDOWN = 3.0f;

// Humans
const float ZP_HUMAN_START_HP = 100.0f;
const float ZP_HUMAN_START_ARMOR = 0.0f;
const float ZP_HUMAN_MAX_ARMOR = 200.0f;
const float ZP_HUMAN_SPEED = 240;
const float ZP_HUMAN_GRAVITY = 1.0f;
const bool ZP_HUMAN_ARMOR_PROTECT = true;
const bool ZP_HUMAN_FLASHLIGHT_AURA = true;
const int ZP_HUMAN_FLASHLIGHT_AURA_BRIGHTNESS = 50; // 0 - 255
const float ZP_HUMAN_FLASHLIGHT_AURA_SIZE = 25.0f;
const int ZP_HUMAN_KILL_REWARD = 2; // reward ammo packs for killing one Zombie
const float ZP_HUMAN_DAMAGE_REWARD = 700.0f; // how much damage a Human must deal to a Zombie to receive 1 Ammo Pack

// Zombies
const float ZP_ZOMBIE_FIRST_HP_MULTI = 2.0f; // first zombie hp multiplier
const float ZP_ZOMBIE_INFECT_HP = 500.0f; // hp regain amount with every infection
const float ZP_ZOMBIE_MADNESS_DURATION = 5.0f;
const float ZP_ZOMBIE_RESPAWN_DELAY = 20.0f;
const bool ZP_ZOMBIE_SILENT_STEPS = true;
const bool ZP_ZOMBIE_BLEEDING = true;
const int ZP_ZOMBIE_KILL_REWARD = 2; // reward for killing last Human, or Survivor / Sniper
const int ZP_ZOMBIE_INFECT_REWARD = 1;
const int ZP_ZOMBIE_MAX_RESPAWNS = 20;

// Rewards for killing
const bool ZP_HUMAN_KILL_NEMESIS_ALLOW_REWARD = true;
const bool ZP_HUMAN_KILL_ASSASSIN_ALLOW_REWARD = true;
const int ZP_HUMAN_KILL_NEMESIS_REWARD = 25; // reward ammo packs for killing Nemesis
const int ZP_HUMAN_KILL_ASSASSIN_REWARD = 25; // reward ammo packs for killing Assassin
const bool ZP_SURVIVOR_KILL_ALLOW_REWARD = true;
const bool ZP_SNIPER_KILL_ALLOW_REWARD = true;
const int ZP_SURVIVOR_KILL_REWARD = 1; // Survivor's reward ammo packs for killing a Zombie
const int ZP_SNIPER_KILL_REWARD = 1; // Sniper's reward ammo packs for killing a Zombie

const bool ZP_ZOMBIE_KILL_SURVIVOR_ALLOW_REWARD = true;
const bool ZP_ZOMBIE_KILL_SNIPER_ALLOW_REWARD = true;
const int ZP_ZOMBIE_KILL_SURVIVOR_REWARD = 10; // reward ammo packs for killing Survivor
const int ZP_ZOMBIE_KILL_SNIPER_REWARD = 10; // reward ammo packs for killing Sniper
const bool ZP_NEMESIS_KILL_ALLOW_REWARD = true;
const bool ZP_ASSASSIN_KILL_ALLOW_REWARD = true;
const int ZP_NEMESIS_KILL_REWARD = 1; // Nemesis' reward ammo packs for killing a Human
const int ZP_ASSASSIN_KILL_REWARD = 1; // Assassin's reward ammo packs for killing a Human

// Nemesis
const int ZP_NEMESIS_ENABLED = 1; // 0 or 1
const int ZP_NEMESIS_CHANCE = 20;
const float ZP_NEMESIS_HEALTH = 15000.0f; // Health [0 - human count*base health] // 50k by default
const float ZP_NEMESIS_BASE_HEALTH = 0.0f; // Base health [0 - use first zombie's health]
const float ZP_NEMESIS_SPEED = 250; // Base health [0 - use first zombie's health]
const float ZP_NEMESIS_GRAVITY = 0.6f;
const float ZP_NEMESIS_DAMAGE = 250.0f;

// Assassin
const int ZP_ASSASSIN_ENABLED = 1; // 0 or 1
const int ZP_ASSASSIN_CHANCE = 20;
const float ZP_ASSASSIN_HEALTH = 7500.0f; // Health [0 - human count*base health] // 15k by default
const float ZP_ASSASSIN_BASE_HEALTH = 0.0f; // Base health [0 - use first zombie's health]
const float ZP_ASSASSIN_SPEED = 380; // Base health [0 - use first zombie's health]
const float ZP_ASSASSIN_GRAVITY = 0.5f;
const float ZP_ASSASSIN_DAMAGE = 250.0f;

// Survivor
const int ZP_SURVIVOR_ENABLED = 1; // 0 or 1
const int ZP_SURVIVOR_CHANCE = 20;
const float ZP_SURVIVOR_HEALTH = 3000.0f; // Health [0 - human count*base health]
const float ZP_SURVIVOR_BASE_HEALTH = 0.0f; // Base health [0 - use first zombie's health]
const float ZP_SURVIVOR_SPEED = 230; // Base health [0 - use first zombie's health]
const float ZP_SURVIVOR_GRAVITY = 1.25f;
const float ZP_SURVIVOR_AURA_SIZE = 40.0f;
const float ZP_SURVIVOR_AURA_R = 0.0f;
const float ZP_SURVIVOR_AURA_G = 0.0f;
const float ZP_SURVIVOR_AURA_B = 100.0f;
const string ZP_SURVIVOR_WEAPON = "weapon_m249"; // weapon_minigun

// Sniper
const int ZP_SNIPER_ENABLED = 1; // 0 or 1
const int ZP_SNIPER_CHANCE = 20;
const float ZP_SNIPER_HEALTH = 2500.0f; // Health [0 - human count*base health]
const float ZP_SNIPER_BASE_HEALTH = 0.0f; // Base health [0 - use first zombie's health]
const float ZP_SNIPER_SPEED = 230; // Base health [0 - use first zombie's health]
const float ZP_SNIPER_GRAVITY = 0.5f;
const float ZP_SNIPER_DAMAGE = 3000.0f;
const float ZP_SNIPER_AURA_SIZE = 40.0f;
const float ZP_SNIPER_AURA_R = 0.0f;
const float ZP_SNIPER_AURA_G = 100.0f;
const float ZP_SNIPER_AURA_B = 0.0f;

// Leap (long jumping)
const bool ZP_LEAP_NEMESIS = true;
const float ZP_LEAP_NEMESIS_FORCE = 500.0f;
const float ZP_LEAP_NEMESIS_HEIGHT = 300.0f;
const float ZP_LEAP_NEMESIS_COOLDOWN = 5.0f;

// Swarm
const int ZP_SWARM_ENABLED = 1; // 0 or 1
const int ZP_SWARM_CHANCE = 20;

// Multiple Infection
const int ZP_MULTI_ENABLED = 1; // 0 or 1
const int ZP_MULTI_CHANCE = 20;
const float ZP_MULTI_RATIO = 0.15f;

// Plague
const int ZP_PLAGUE_ENABLED = 1; // 0 or 1
const int ZP_PLAGUE_CHANCE = 30;
const float ZP_PLAGUE_RATIO = 0.5f;
const float ZP_PLAGUE_NEMESIS_HP_MULTI = 0.5f;
const float ZP_PLAGUE_SURVIVOR_HP_MULTI = 0.75f;

// Armageddon
const int ZP_ARMAGEDDON_ENABLED = 1; // 0 or 1
const int ZP_ARMAGEDDON_CHANCE = 30;
const float ZP_ARMAGEDDON_RATIO = 0.5f;
const float ZP_ARMAGEDDON_NEMESIS_HP_MULTI = 0.5f;
const float ZP_ARMAGEDDON_SURVIVOR_HP_MULTI = 2.0f;

// Apocalypse
const int ZP_APOCALYPSE_ENABLED = 1; // 0 or 1
const int ZP_APOCALYPSE_CHANCE = 30;
const float ZP_APOCALYPSE_RATIO = 0.5f;
const float ZP_APOCALYPSE_ASSASSIN_HP_MULTI = 1.25f;
const float ZP_APOCALYPSE_SNIPER_HP_MULTI = 2.0f;

// Nightmare
const int ZP_NIGHTMARE_ENABLED = 1; // 0 or 1
const int ZP_NIGHTMARE_CHANCE = 40;
const float ZP_NIGHTMARE_RATIO = 0.5f;
const float ZP_NIGHTMARE_NEMESIS_HP_MULTI = 1.25f;
const float ZP_NIGHTMARE_SURVIVOR_HP_MULTI = 2.0f;
const float ZP_NIGHTMARE_ASSASSIN_HP_MULTI = 0.5f;
const float ZP_NIGHTMARE_SNIPER_HP_MULTI = 2.0f;

// Pain shock
const bool ZP_PAIN_SHOCK = true; // slowdowns player after taking the damage
const float ZP_PAIN_SHOCK_FIRST_ZOMBIE_VEL_MOD_RATIO = 0.25f; // 1 - disable pain shock at all, 0 - don't affect pain shock
const float ZP_PAIN_SHOCK_VEL_MOD = 0.5f; // velocity modifier fraction [0 - 1]
const float ZP_PAIN_SHOCK_LARGE_FLINCH_VEL_KNOCKBACK = 170.0f;
const float ZP_PAIN_SHOCK_LARGE_FLINCH_VEL_MOD = 0.65f;
const float ZP_PAIN_SHOCK_NEMESIS_VEL_MOD_RATIO = 0.75f; // 1 - disable pain shock at all, 0 - don't affect pain shock
const float ZP_PAIN_SHOCK_ASSASSIN_VEL_MOD_RATIO = 0.7f; // 1 - disable pain shock at all, 0 - don't affect pain shock
const bool ZP_PAIN_SHOCK_FREE_SURVIVOR = true;
const bool ZP_PAIN_SHOCK_FREE_SNIPER = false;

// Knockback
const bool ZP_KNOCKBACK = false;
const bool ZP_KNOCKBACK_DAMAGE = true; // use taken damage for knockback calculations
const bool ZP_KNOCKBACK_POWER = true; // use weapon power for knockback calculations
const float ZP_KNOCKBACK_MAX_VEL = 700.0f; // don't exceed a specified limit of speed [0-disable the limit]
const float ZP_KNOCKBACK_DUCKING = 0.25f; // knockback multiplier for crouched zombies [0-knockback disabled when ducking]
const float ZP_KNOCKBACK_DISTANCE = 500.0f; // max distance for knockback to take effect
const float ZP_KNOCKBACK_NEMESIS = 0.55f; // Nemesis knockback multiplier [0-disable knockback for nemesis] ( FIXME: it was 0.25 but knockback's meaningless )
const float ZP_KNOCKBACK_ASSASSIN = 0.7f; // Assassin knockback multiplier [0-disable knockback for assassin]

// Night vision
const float ZP_NVG_SIZE = 80.0f;
const float ZP_NVG_HUMAN_COLOR_R = 0.0f;
const float ZP_NVG_HUMAN_COLOR_G = 150.0f;
const float ZP_NVG_HUMAN_COLOR_B = 0.0f;
const float ZP_NVG_ZOMBIE_COLOR_R = 0.0f; // default: 0
const float ZP_NVG_ZOMBIE_COLOR_G = 150.0f; // default: 150
const float ZP_NVG_ZOMBIE_COLOR_B = 150.0f; // default: 0
const float ZP_NVG_NEMESIS_COLOR_R = 150.0f;
const float ZP_NVG_NEMESIS_COLOR_G = 0.0f;
const float ZP_NVG_NEMESIS_COLOR_B = 0.0f;
const float ZP_NVG_ASSASSIN_COLOR_R = 0.0f;
const float ZP_NVG_ASSASSIN_COLOR_G = 150.0f;
const float ZP_NVG_ASSASSIN_COLOR_B = 90.0f;

// Custom grenades
const float ZP_NADE_EXPLOSION_RADIUS = 240.0f;
const float ZP_NADE_FIRE_DURATION = 10.0f;
const float ZP_NADE_FIRE_DAMAGE = 5.0f; // per 0.2 sec
const float ZP_NADE_FIRE_SLOWDOWN = 0.5f; // slowdown multiplier
const float ZP_NADE_FROST_DURATION = 3.0f;
const float ZP_NADE_FLARE_DURATION = 60.0f;
const float ZP_NADE_FLARE_SIZE = 25.0f;
const int ZP_NADE_FLARE_COLOR = 4; // 0-white // 1-red // 2-green // 3-blue // 4-full random // 5-random between r,g,b
const float ZP_NADE_HOLY_DAMAGE = 1500.0f;
const float ZP_NADE_JUMP_DAMAGE = 15.0f;
const float ZP_NADE_JUMP_PUSH_FORCE = 500.0f;

// Models
const string ZP_ZOMBIE_MODEL = "zombie_source_v1_2"; // zombie_source_v1_2, origzombie
const string ZP_NEMESIS_MODEL = "zp_executioner_b";
const string ZP_ASSASSIN_MODEL = "archdevil";

// Thunder lights
const array<string> ZP_THUNDER_LIGHTS =
{
    "ijklmnonmlkjihgfedcb",
    "klmlkjihgfedcbaabcdedcb",
    "bcdefedcijklmlkjihgfedcb"  
};

// Skyboxes
const bool ZP_SKYBOXES_ENABLE = true;
const array<string> ZP_SKYBOXES =
{
    "space"
};

// Decals
const array<int> ZP_ZOMBIE_DECAL_BLOOD =
{
    // 99, 107, 108, 184, 185, 186, 187, 188, 189
    120, 128, 129, 204, 205, 207, 208, 209, /* next decals may be useless */ 210, 211, 212, 213, 214, 215, 216, 217
};

// Weapon damage multiplier
const array<float> WEAPON_DAMAGE_MULTIPLIER =
{
    1.0f, // WEAPON_NONE (0)
    5.0f, // WEAPON_CROWBAR (1)
    2.1f, // WEAPON_GLOCK (2) | 2.0
    1.6f, // WEAPON_PYTHON (3) | 1.5
    3.5f, // WEAPON_MP5 (4) | 3.25
    1.0f, // WEAPON_CHAINGUN (5)
    1.6667f, // WEAPON_CROSSBOW (6)
    1.75f, // WEAPON_SHOTGUN (7)
    3.4f, // WEAPON_RPG (8)
    4.0f, // WEAPON_GAUSS (9)
    1.0f, // WEAPON_EGON (10)
    1.0f, // WEAPON_HORNETGUN (11)
    1.0f, // WEAPON_HANDGRENADE (12)
    1.0f, // WEAPON_TRIPMINE (13)
    1.0f, // WEAPON_SATCHEL (14)
    1.0f, // WEAPON_SNARK (15)
    1.0f, // UNKNOWN (16)
    2.0f, // WEAPON_UZI (17) | 1.75
    1.0f, // WEAPON_MEDKIT (18)
    1.0f, // WEAPON_CROWBAR_ELECTRIC (19)
    1.0f, // WEAPON_PIPEWRENCH (20)
    1.0f, // WEAPON_MINIGUN (21)
    1.0f, // WEAPON_GRAPPLE (22)
    2.5f, // WEAPON_SNIPERRIFLE (23)
    2.5f, // WEAPON_M249 (24) | 2.25
    2.5f, // WEAPON_M16 (25) | 2.25
    1.0f, // WEAPON_SPORELAUNCHER (26)
    1.9f, // WEAPON_DESERT_EAGLE (27) | 1.6
    1.0f, // WEAPON_SHOCKRIFLE (28)
    1.0f, // WEAPON_DISPLACER (29)
};

// Weapon power for knockback calculations
const array<float> WEAPON_POWER =
{
    2.0f, // WEAPON_NONE (0)
    2.0f, // WEAPON_CROWBAR (1)
    8.5f, // WEAPON_GLOCK (2)
    7.0f, // WEAPON_PYTHON (3)
    5.0f, // WEAPON_MP5 (4)
    2.0f, // WEAPON_CHAINGUN (5)
    15.0f, // WEAPON_CROSSBOW (6)
    8.0f, // WEAPON_SHOTGUN (7)
    5.0f, // WEAPON_RPG (8)
    5.0f, // WEAPON_GAUSS (9)
    5.0f, // WEAPON_EGON (10)
    2.0f, // WEAPON_HORNETGUN (11)
    2.0f, // WEAPON_HANDGRENADE (12)
    2.0f, // WEAPON_TRIPMINE (13)
    2.0f, // WEAPON_SATCHEL (14)
    2.0f, // WEAPON_SNARK (15)
    2.0f, // UNKNOWN (16)
    5.0f, // WEAPON_UZI (17)
    2.0f, // WEAPON_MEDKIT (18)
    2.0f, // WEAPON_CROWBAR_ELECTRIC (19)
    2.0f, // WEAPON_PIPEWRENCH (20)
    2.5f, // WEAPON_MINIGUN (21)
    2.0f, // WEAPON_GRAPPLE (22)
    5.0f, // WEAPON_SNIPERRIFLE (23)
    5.0f, // WEAPON_M249 (24)
    5.0f, // WEAPON_M16 (25)
    5.0f, // WEAPON_SPORELAUNCHER (26)
    7.0f, // WEAPON_DESERT_EAGLE (27)
    2.0f, // WEAPON_SHOCKRIFLE (28)
    3.0f, // WEAPON_DISPLACER (29)
};

// Weapons with allowed tracers
array<bool> WEAPON_HAS_TRACER = {};

// Sounds
const string ZP_AMBIENCE_SND = "zombie_plague/ambience.wav";
const string ZP_ARMOR_EQUIP_SND = "zombie_plague/cs/tr_kevlar.wav";
const string ZP_ARMOR_HIT_SND = "zombie_plague/cs/bhit_helmet-1.wav";

const string ZP_PICKUP_SND = "items/gunpickup2.wav";

const string ZP_NADEMODE_PROXIMITY_BELL_SND = "buttons/button9.wav";
const string ZP_NADEMODE_TRIP_ACTIVATE_SND = "weapons/mine_activate.wav";
const string ZP_NADEMODE_TRIP_DEPLOY_SND = "weapons/mine_deploy.wav";
const string ZP_NADEMODE_TRIP_CHARGE_SND = "weapons/mine_charge.wav";
const string ZP_NADEMODE_MOTION_GEIGER_SND = "player/geiger1.wav";
const string ZP_NADEMODE_HOMING_PING_SND = "turret/tu_ping.wav";

array<string> ZP_COUNTDOWN_SND =
{
    "one.wav",
    "two.wav",
    "three.wav",
    "four.wav",
    "five.wav",
    "six.wav",
    "seven.wav",
    "eight.wav",
    "nine.wav",
    "ten.wav"
};

const array<string> ZP_COUNTDOWN_DEFAULT_SND =
{
    "one.wav",
    "two.wav",
    "three.wav",
    "four.wav",
    "five.wav",
    "six.wav",
    "seven.wav",
    "eight.wav",
    "nine.wav",
    "ten.wav"
};

const array<string> ZP_WIN_ZOMBIES_SND =
{
    "ambience/the_horror1.wav",
    "ambience/the_horror3.wav",
    "ambience/the_horror4.wav"
};

const array<string> ZP_WIN_HUMANS_SND =
{
    "zombie_plague/win_humans1.wav",
    "zombie_plague/win_humans2.wav"
};

const array<string> ZP_WIN_NO_ONE_SND =
{
    "ambience/3dmstart.wav"
};

const array<string> ZP_ZOMBIE_INFECT_SND =
{
    "zombie_plague/zombie_infec1.wav",
    "zombie_plague/zombie_infec2.wav",
    "zombie_plague/zombie_infec3.wav",
    "zombie_plague/hl/scientist/c1a0_sci_catscream.wav",
    "zombie_plague/hl/scientist/scream01.wav"
};

const array<string> ZP_ZOMBIE_PAIN_SND =
{
    "zombie_plague/zombie_pain1.wav",
    "zombie_plague/zombie_pain2.wav",
    "zombie_plague/zombie_pain3.wav",
    "zombie_plague/zombie_pain4.wav",
    "zombie_plague/zombie_pain5.wav"
};

const array<string> ZP_NEMESIS_PAIN_SND =
{
    "zombie_plague/nemesis_pain1.wav",
    "zombie_plague/nemesis_pain2.wav",
    "zombie_plague/nemesis_pain3.wav"
};

const array<string> ZP_ASSASSIN_PAIN_SND =
{
    "zombie_plague/nemesis_pain1.wav",
    "zombie_plague/nemesis_pain2.wav",
    "zombie_plague/nemesis_pain3.wav"
};

const array<string> ZP_ZOMBIE_DIE_SND =
{
    "zombie_plague/zombie_die1.wav",
    "zombie_plague/zombie_die2.wav",
    "zombie_plague/zombie_die3.wav",
    "zombie_plague/zombie_die4.wav",
    "zombie_plague/zombie_die5.wav"
};

const array<string> ZP_ZOMBIE_FALL_SND =
{
    "zombie_plague/zombie_fall1.wav"
};

const array<string> ZP_ZOMBIE_IDLE_SND =
{
    "zombie_plague/hl/nihilanth/nil_now_die.wav",
    "zombie_plague/hl/nihilanth/nil_slaves.wav",
    "zombie_plague/hl/nihilanth/nil_alone.wav",
    "zombie_plague/zombie_brains1.wav",
    "zombie_plague/zombie_brains2.wav"
};

const array<string> ZP_ZOMBIE_IDLE_LAST_SND =
{
    "zombie_plague/hl/nihilanth/nil_thelast.wav"
};

const array<string> ZP_ZOMBIE_MADNESS_SND =
{
    "zombie_plague/zombie_madness1.wav"
};

const array<string> ZP_ROUND_NEMESIS_SND =
{
    "zombie_plague/nemesis1.wav",
    "zombie_plague/nemesis2.wav"
};

const array<string> ZP_ROUND_ASSASSIN_SND =
{
    "zombie_plague/nemesis1.wav",
    "zombie_plague/nemesis2.wav"
};

const array<string> ZP_ROUND_SURVIVOR_SND =
{
    "zombie_plague/survivor1.wav",
    "zombie_plague/survivor2.wav"
};

const array<string> ZP_ROUND_SNIPER_SND =
{
    "zombie_plague/survivor1.wav",
    "zombie_plague/survivor2.wav"
};

const array<string> ZP_ROUND_SWARM_SND =
{
    "ambience/the_horror2.wav"
};

const array<string> ZP_ROUND_MULTI_SND =
{
    "ambience/the_horror2.wav"
};

const array<string> ZP_ROUND_PLAGUE_SND =
{
    "zombie_plague/nemesis1.wav",
    "zombie_plague/survivor1.wav"
};

const array<string> ZP_ROUND_ARMAGEDDON_SND =
{
    "zombie_plague/nemesis1.wav",
    "zombie_plague/survivor1.wav"
};

const array<string> ZP_ROUND_APOCALYPSE_SND =
{
    "zombie_plague/nemesis1.wav",
    "zombie_plague/survivor1.wav"
};

const array<string> ZP_ROUND_NIGHTMARE_SND =
{
    "zombie_plague/nemesis1.wav",
    "zombie_plague/survivor1.wav"
};

const array<string> ZP_GRENADE_HOLY_EXPLODE_SND =
{
    "zombie_plague/weapons/holy.wav",
    "zombie_plague/weapons/holyexplosion.wav"
};

const array<string> ZP_GRENADE_INFECT_EXPLODE_SND =
{
    "zombie_plague/grenade_infect.wav"
};

const array<string> ZP_GRENADE_INFECT_PLAYER_SND =
{
    "zombie_plague/hl/scientist/scream20.wav",
    "zombie_plague/hl/scientist/scream22.wav",
    "zombie_plague/hl/scientist/scream05.wav"
};

const array<string> ZP_GRENADE_JUMP_EXPLODE_SND =
{
	"nst_zombie/zombi_bomb_exp.wav",
};

const array<string> ZP_GRENADE_JUMP_SND =
{
	"nst_zombie/zombi_bomb_pull_1.wav", 
	"nst_zombie/zombi_bomb_deploy.wav",
	"nst_zombie/zombi_bomb_throw.wav"
};

const array<string> ZP_GRENADE_JUMP_IDLE_SND =
{ 
	"nst_zombie/zombi_bomb_idle_1.wav", 
	"nst_zombie/zombi_bomb_idle_2.wav", 
	"nst_zombie/zombi_bomb_idle_3.wav", 
	"nst_zombie/zombi_bomb_idle_4.wav"
};

const array<string> ZP_GRENADE_FIRE_EXPLODE_SND =
{
    "zombie_plague/grenade_explode.wav"
};

const array<string> ZP_GRENADE_FIRE_PLAYER_SND =
{
    "zombie_plague/zombie_burn3.wav",
    "zombie_plague/zombie_burn4.wav",
    "zombie_plague/zombie_burn5.wav",
    "zombie_plague/zombie_burn6.wav",
    "zombie_plague/zombie_burn7.wav"
};

const array<string> ZP_GRENADE_FROST_EXPLODE_SND =
{
    "warcraft3/frostnova.wav"
};

const array<string> ZP_GRENADE_FROST_PLAYER_SND =
{
    "warcraft3/impalehit.wav"
};

const array<string> ZP_GRENADE_FROST_BREAK_SND =
{
    "warcraft3/impalelaunch1.wav"
};

const array<string> ZP_GRENADE_FLARE_SND =
{
    "items/nvg_on.wav"
};

const array<string> ZP_ANTIDOTE_SND =
{
    "items/smallmedkit1.wav"
};

const array<string> ZP_THUNDER_SND =
{
    "zombie_plague/thunder1.wav",
    "zombie_plague/thunder2.wav"
};

//-----------------------------------------------------------------------------
// Menus
//-----------------------------------------------------------------------------

array<CTextMenu@> g_MainMenu(33, null);
array<CTextMenu@> g_PrimaryWeaponsMenu(33, null);
array<CTextMenu@> g_SecondaryWeaponsMenu(33, null);
array<CTextMenu@> g_HumanExtrasMenu(33, null);
array<CTextMenu@> g_ZombieExtrasMenu(33, null);
array<CTextMenu@> g_ClassesMenu(33, null);
array<CTextMenu@> g_ExtrasManagementMenu(33, null);

//-----------------------------------------------------------------------------
// Variables
//-----------------------------------------------------------------------------

bool g_bDebug = false;
bool g_bEnabled = false;
bool g_bZombieEscape = false;

int g_iGameState = ZP_STATE_HIBERNATION;
int g_iGameMode = ZP_MODE_NONE;
int g_iPrevGameMode = ZP_MODE_NONE;

float g_flGameStartTime = -1.0f;
float g_flGameEndTime = -1.0f;

float g_flHelpMessage = -1.0f;

float g_flStatsUpdate = -1.0f;
float g_flStatsSave = -1.0f;

int g_iAliveHumans = 0;
int g_iAliveZombies = 0;

int g_iAllowedRespawns = 0;
bool g_bKillLatePlayers = true;

// Thunder
float g_flThunderClapTime = -1.0f;
int g_iLightsIterator = 0;
int g_iLightsCycleLength = 0;
string g_sLightsCycle = "";

// User Commands
array<CUserCommand@> g_userCommands;

// Zombie Classes
array<CZombieClass@> g_zombieClasses;

// Extras
array<CExtraItem@> g_humanExtras;
array<CExtraItem@> g_zombieExtras;

// Weapons Menu
array<CPrimaryWeapon@> g_primaryWeapons;
array<CSecondaryWeapon@> g_secondaryWeapons;

int ZP_CLASS_LAST = -1;

array<bool> g_bFirstConnect(33, true);
array<bool> g_bIsHuman(33, false);
array<bool> g_bIsZombie(33, false);
array<bool> g_bAlive(33, false);
array<int> g_iAmmopacks(33, 0);
array<int> g_iZombieClass(33, ZP_CLASS_CLASSIC_ZOMBIE);
array<int> g_iCurrentZombieClass(33, ZP_CLASS_CLASSIC_ZOMBIE);
array<int> g_iClassType(33, ZP_HUMAN_DEFAULT); // General Human & Zombie classes (Human, Survivor, Sniper, Zombie, Nemesis, Assassin..)

array<float> g_flVelocityModifier(33, 1.0f);
array<float> g_flCommandCooldown(33, 0.0f);
array<float> g_flBurningDuration(33, 0.0f);
array<float> g_flDealenDamage(33, 0.0f);
array<float> g_flLastLeapTime(33, 0.0f);
array<float> g_flRespawnTime(33, -1.0f);
array<bool> g_bCanBuyPrimaryWeapons(33, false);
array<bool> g_bCanBuySecondaryWeapons(33, false);
array<bool> g_bFirstZombie(33, false);
array<bool> g_bFrozen(33, false);
array<bool> g_bNightvision(33, false);
array<bool> g_bHasNightvision(33, false);
array<bool> g_bAura(33, false);
array<bool> g_bNoDamage(33, false);
array<bool> g_bInfiniteClipAmmo(33, false);
array<bool> g_bIncendiaryAmmo(33, false);
array<int> g_iNadeMode(33, NADE_MODE_NORMAL);
array<int> g_iLaserMinesCount(33, 0);
array<array<CInventorySandBags@>> g_iSandBagsCount(33);
array<float> g_flMakeBlood(33, 0.0f);
array<float> g_flZombieIdle(33, 0.0f);
array<float> g_flSwitchNadeModeTime(33, 0.0f); // I can't fucking figure out with m_afButtonPressed in PlayerPreThink
array<bool> g_bOnGround(33, true);
array<bool> g_bOneRoundForceField(33, false);
array<CBasePlayerWeapon@> g_pCurrentWeapon(33, null);
array<string> g_sSavedPlayerModels(33, "");

// Infinite ammo related
array<int> g_iAmmoIndex;
array<string> g_pAmmo =
{
    "9mm",
    "357",
    "buckshot",
    "bolts",
    "556",
    "m40a1",
    // "health",
    // "argrenades",
    // "rockets",
    "uranium",
    // "hornets",
    // "hand grenade",
    // "satchel charge",
    // "trip mine",
    // "snarks",
    "sporeclip",
    "shock charges"
};

// Custom entities related
array<edict_t@> g_pCustomGrenades;
array<edict_t@> g_pForceFields;
array<edict_t@> g_pLaserMines;
array<edict_t@> g_pSandBags;

int WEAPON_FIREGRENADE = 0;
int WEAPON_FROSTGRENADE = 0;
int WEAPON_FLAREGRENADE = 0;
int WEAPON_INFECTGRENADE = 0;
int WEAPON_HOLYGRENADE = 0;
int WEAPON_JUMPGRENADE = 0;
int WEAPON_FORCE_FIELD_GRENADE = 0;
int WEAPON_EXECUTIONER_AXE = 0;
int WEAPON_ZOMBIEKNIFE = 0;

int g_trailSpr = 0;
int g_tracerSpr = 0;
int g_exploSpr = 0;
int g_flameSpr = 0;
int g_fexploSpr = 0;
int g_zombieBombExploSpr = 0;
int g_smokeSpr = 0;
int g_glassSpr = 0;

//-----------------------------------------------------------------------------
// Timers
//-----------------------------------------------------------------------------

CScheduledFunction@ Scheduler_InitNewGame = null;
CScheduledFunction@ Scheduler_Think = null;
CScheduledFunction@ Scheduler_Think50 = null;
CScheduledFunction@ Scheduler_Think100 = null;
CScheduledFunction@ Scheduler_BeginInfection = null;
CScheduledFunction@ Scheduler_CountdownTask = null;
CScheduledFunction@ Scheduler_AmbienceSound = null;
CScheduledFunction@ Scheduler_MapLighting = null;
CScheduledFunction@ Scheduler_ThunderClap = null;

//-----------------------------------------------------------------------------
// Purpose: gets state of the plugin
//-----------------------------------------------------------------------------

bool ZP_IsRunning()
{
    return g_bEnabled;
}

//-----------------------------------------------------------------------------
// Purpose: check if map is supported
//-----------------------------------------------------------------------------

bool ZP_IsMapSupported(const string sMapname)
{
    return sMapname.StartsWith("zm_") || sMapname.StartsWith("zp_") || sMapname.StartsWith("ze_");
}

//-----------------------------------------------------------------------------
// Purpose: initialize the plugin
//-----------------------------------------------------------------------------

void ZP_Init()
{
    if ( g_bDebug ) zp_log("ZP_Init()");

    // Reset globals to default values
    ZP_ResetState();

    // Register custom weapons / items / entities
    ZP_InitializeCustomEntities();

    // Force cvars
    ZP_SetCvars();

    // Register hooks
	ZP_RegisterHooks();

    // Register custom hooks
    ZP_PROJECTILE::RegisterProjectileSpawnHook( @OnProjectileSpawn );
    ZP_PROJECTILE::RegisterProjectileImpactHook( @OnProjectileImpact );
    ZP_PROJECTILE::RegisterProjectileDetonateHook( @OnProjectileDetonate );

    // Acquire custom weapons IDs
    WEAPON_FIREGRENADE = g_ItemRegistry.GetIdForName( "weapon_firegrenade" );
    WEAPON_FROSTGRENADE = g_ItemRegistry.GetIdForName( "weapon_frostgrenade" );
    WEAPON_FLAREGRENADE = g_ItemRegistry.GetIdForName( "weapon_flaregrenade" );
    WEAPON_INFECTGRENADE = g_ItemRegistry.GetIdForName( "weapon_infectgrenade" );
    WEAPON_HOLYGRENADE = g_ItemRegistry.GetIdForName( "weapon_holygrenade" );
    WEAPON_JUMPGRENADE = g_ItemRegistry.GetIdForName( "weapon_jumpgrenade" );
    WEAPON_FORCE_FIELD_GRENADE = g_ItemRegistry.GetIdForName( "weapon_force_field_grenade" );

    WEAPON_EXECUTIONER_AXE = g_ItemRegistry.GetIdForName( "weapon_executioner_axe" );
    WEAPON_ZOMBIEKNIFE = g_ItemRegistry.GetIdForName( "weapon_zombieknife" );

    // Fill table of tracers
    ZP_InitializeTracersTable();
}

//-----------------------------------------------------------------------------
// Purpose: register custom cvars
//-----------------------------------------------------------------------------

void ZP_RegisterCVars()
{
    @zp_mode = CCVar("zp_mode", 0, "Force ZP mode:\n0 - Disabled\n1 - Single Infection\n2 - Multiple Infection\n3 - Plague\n4 - Swarm\n5 - Nemesis\n6 - Assassin\n7 - Survivor\n8 - Sniper\n9 - Armageddon\n10 - Apocalypse\n11 - Nightmare", ConCommandFlag::AdminOnly);
    @zp_lighting = CCVar("zp_lighting", "f", "Map lighting [a-z]: a - darkest, z - brightest", ConCommandFlag::AdminOnly);
    @zp_fog = CCVar("zp_fog", "0", "Map fog", ConCommandFlag::AdminOnly);
}

//-----------------------------------------------------------------------------
// Purpose: set cvars
//-----------------------------------------------------------------------------

void ZP_SetCvars()
{
    g_EngineFuncs.ServerCommand("mp_timelimit 60\n");
    g_EngineFuncs.ServerCommand("mp_dropweapons 0\n");
    g_EngineFuncs.ServerCommand("mp_weapon_droprules 0\n");
    g_EngineFuncs.ServerCommand("mp_hevsuit_voice 0\n");
    g_EngineFuncs.ServerCommand("mp_disable_pcbalancing 1\n");
    g_EngineFuncs.ServerCommand("mp_survival_nextmap \"\"\n");
    g_EngineFuncs.ServerCommand("mp_survival_supported 1\n");
    g_EngineFuncs.ServerCommand("mp_survival_mode 1\n");
    g_EngineFuncs.ServerCommand("mp_survival_starton 1\n");
    g_EngineFuncs.ServerCommand("mp_survival_retries -1\n");
    g_EngineFuncs.ServerCommand("mp_survival_startdelay " + ZP_WAITING_PLAYERS_TIME + "\n");
    g_EngineFuncs.ServerCommand("mp_survival_voteallow 0\n");
    g_EngineFuncs.ServerCommand("mp_nextmap_ignore_mapcfg 0\n");
    g_EngineFuncs.ServerCommand("mp_flashlight 1\n");
    g_EngineFuncs.ServerCommand("mp_footsteps 1\n");
    g_EngineFuncs.ServerCommand("sv_accelerate 8\n"); // NOTE: don't make value of cvar 'sv_accelerate' too low (7 is perfect playable minimum), otherwise players won't be able to move when ducked!
    g_EngineFuncs.ServerCommand("sv_airaccelerate 9\n");
    g_EngineFuncs.ServerCommand("sv_maxspeed 999\n");

    if ( ZP_SKYBOXES_ENABLE && !g_bZombieEscape )
        g_EngineFuncs.ServerCommand("sv_skyname \"" + UTIL_GetRandomStringFromArray( ZP_SKYBOXES ) + "\"\n");

    g_EngineFuncs.ServerCommand("skill 1\n");
	g_EngineFuncs.ServerExecute();
}

//-----------------------------------------------------------------------------
// Purpose: change map entities
//-----------------------------------------------------------------------------

void ZP_ChangeEntities()
{
    CBaseEntity@ pEntity = null;

    // Remove light_environment
    while ( ( @pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "light_environment") ) !is null )
    {
        g_EntityFuncs.Remove( pEntity );
    }

    @pEntity = null;

    // Replace info_player_start with info_player_deathmatch
    while ( ( @pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "info_player_start") ) !is null )
    {
        CBaseEntity@ pSpawn = g_EntityFuncs.CreateEntity( "info_player_deathmatch", null, true );

		pSpawn.pev.origin = pEntity.pev.origin;
		pSpawn.pev.angles = pEntity.pev.angles;
		pSpawn.pev.spawnflags = pEntity.pev.spawnflags;
		pSpawn.pev.targetname = pEntity.pev.targetname;

        g_EntityFuncs.Remove( pEntity );
    }
}

//-----------------------------------------------------------------------------
// Purpose: initialize custom entities / weapons / items
//-----------------------------------------------------------------------------

void ZP_InitializeCustomEntities()
{
    // Init CS16 Weapons
    CS16_MapInit();

    EXECUTIONER_AXE::Register();
    ZOMBIE_KNIFE::Register();
	FIRE_GRENADE::Register();
	FROST_GRENADE::Register();
	FLARE_GRENADE::Register();
	INFECT_GRENADE::Register();
	HOLY_GRENADE::Register();
	JUMP_GRENADE::Register();
	FORCE_FIELD_GRENADE::Register();
	FORCE_FIELD::Register();

    LASERMINE::Precache();
    SANDBAGS::Precache();
}

//-----------------------------------------------------------------------------
// Purpose: initialize tracers table
//-----------------------------------------------------------------------------

void ZP_InitializeTracersTable()
{
    int iWeaponID = -1;

    WEAPON_HAS_TRACER.resize( 0 );

    WEAPON_HAS_TRACER =
    {
        false, // WEAPON_NONE (0)
        false, // WEAPON_CROWBAR (1)
        true, // WEAPON_GLOCK (2)
        true, // WEAPON_PYTHON (3)
        true, // WEAPON_MP5 (4)
        true, // WEAPON_CHAINGUN (5)
        false, // WEAPON_CROSSBOW (6)
        true, // WEAPON_SHOTGUN (7)
        false, // WEAPON_RPG (8)
        false, // WEAPON_GAUSS (9)
        false, // WEAPON_EGON (10)
        false, // WEAPON_HORNETGUN (11)
        false, // WEAPON_HANDGRENADE (12)
        false, // WEAPON_TRIPMINE (13)
        false, // WEAPON_SATCHEL (14)
        false, // WEAPON_SNARK (15)
        false, // UNKNOWN (16)
        true, // WEAPON_UZI (17)
        false, // WEAPON_MEDKIT (18)
        false, // WEAPON_CROWBAR_ELECTRIC (19)
        false, // WEAPON_PIPEWRENCH (20)
        true, // WEAPON_MINIGUN (21)
        false, // WEAPON_GRAPPLE (22)
        true, // WEAPON_SNIPERRIFLE (23)
        true, // WEAPON_M249 (24)
        true, // WEAPON_M16 (25)
        false, // WEAPON_SPORELAUNCHER (26)
        true, // WEAPON_DESERT_EAGLE (27)
        false, // WEAPON_SHOCKRIFLE (28)
        false, // WEAPON_DISPLACER (29)
    };

    for ( uint i = 0; i < 256 - WEAPON_HAS_TRACER.length(); i++ )
    {
        WEAPON_HAS_TRACER.insertLast( false );
    }

    iWeaponID = g_ItemRegistry.GetIdForName( "weapon_m4a1" );

    if ( iWeaponID > 0 )
    {
        WEAPON_HAS_TRACER[ iWeaponID ] = true;
    }
}

//-----------------------------------------------------------------------------
// Purpose: register chat & console command
//-----------------------------------------------------------------------------

int ZP_RegisterUserCommand(string sChatCommand, string sConsoleCommand, CommandCallback@ pfnCommandCallback, bool bHide)
{
    g_userCommands.insertLast( CUserCommand( sChatCommand, sConsoleCommand, pfnCommandCallback, bHide ) );

    return int( g_userCommands.length() ) - 1;
}

//-----------------------------------------------------------------------------
// Purpose: register Zombie class
//-----------------------------------------------------------------------------

int ZP_RegisterZombieClass(string sName, string sInfo, string sModel, float flHealth, int iSpeed, float flGravity, float flKnockback, int iUserData = 0, float flUserData = 0)
{
    g_zombieClasses.insertLast( CZombieClass( sName, sInfo, sModel, flHealth, iSpeed, flGravity, flKnockback, iUserData, flUserData ) );

    ZP_CLASS_LAST = int( g_zombieClasses.length() ) - 1;
    return ZP_CLASS_LAST;
}

//-----------------------------------------------------------------------------
// Purpose: register Zombie's extra item
//-----------------------------------------------------------------------------

int ZP_RegisterZombieExtra(string sName, int iCost, ExtraBuyCallback@ pfnExtraBuyCallback)
{
    g_zombieExtras.insertLast( CExtraItem( sName, iCost, pfnExtraBuyCallback ) );

    return int( g_zombieExtras.length() ) - 1;
}

//-----------------------------------------------------------------------------
// Purpose: register Human's extra item
//-----------------------------------------------------------------------------

int ZP_RegisterHumanExtra(string sName, int iCost, ExtraBuyCallback@ pfnExtraBuyCallback)
{
    g_humanExtras.insertLast( CExtraItem( sName, iCost, pfnExtraBuyCallback ) );

    return int( g_humanExtras.length() ) - 1;
}

//-----------------------------------------------------------------------------
// Purpose: register primary weapon for menu selection
//-----------------------------------------------------------------------------

int ZP_RegisterPrimaryWeapon(string sName, string sEntityName)
{
    g_primaryWeapons.insertLast( CPrimaryWeapon( sName, sEntityName ) );

    return int( g_primaryWeapons.length() ) - 1;
}

//-----------------------------------------------------------------------------
// Purpose: register secondary weapon for menu selection
//-----------------------------------------------------------------------------

int ZP_RegisterSecondaryWeapon(string sName, string sEntityName)
{
    g_secondaryWeapons.insertLast( CSecondaryWeapon( sName, sEntityName ) );

    return int( g_secondaryWeapons.length() ) - 1;
}

//-----------------------------------------------------------------------------
// Purpose: register hooks
//-----------------------------------------------------------------------------

void ZP_RegisterHooks()
{
	g_Hooks.RegisterHook( Hooks::Game::MapChange, @MapChange );
	g_Hooks.RegisterHook( Hooks::Player::PlayerTakeDamage, @OnPlayerTakeDamage );
	g_Hooks.RegisterHook( Hooks::Player::PlayerKilled, @OnPlayerKilled );
    g_Hooks.RegisterHook( Hooks::Player::PlayerPreThink, @OnPlayerPreThink );
    g_Hooks.RegisterHook( Hooks::Player::PlayerPostThink, @OnPlayerPostThink );
    g_Hooks.RegisterHook( Hooks::Player::PlayerUse, @OnPlayerUse );
    g_Hooks.RegisterHook( Hooks::Player::PlayerSpawn, @OnPlayerSpawn );
    // g_Hooks.RegisterHook( Hooks::Player::ClientPutInServer, @OnClientPutInServer );
	g_Hooks.RegisterHook( Hooks::Player::ClientDisconnect, @OnClientDisconnect );
    // g_Hooks.RegisterHook( Hooks::Player::ClientSay, @OnClientSay );
}

//-----------------------------------------------------------------------------
// Purpose: register hooks only once
//-----------------------------------------------------------------------------

void ZP_RegisterHooksOnce()
{
    g_Hooks.RegisterHook( Hooks::Player::ClientPutInServer, @OnClientPutInServer );
    g_Hooks.RegisterHook( Hooks::Player::ClientSay, @OnClientSay );
}

//-----------------------------------------------------------------------------
// Purpose: precache all models, sounds, etc..
//-----------------------------------------------------------------------------

void ZP_Precache()
{
    if ( g_bDebug ) zp_log("ZP_Precache()");

    // Precache models of zombie classes
    for (uint i = 0; i < g_zombieClasses.length(); i++)
    {
        string sModel = g_zombieClasses[i].m_sModel;
        
        g_Game.PrecacheModel( "models/player/" + sModel + "/" + sModel + ".mdl" );
    }

    // Precache models
    // g_Game.PrecacheModel( "models/player/zp_zombie_source/zp_zombie_source.mdl" );
    g_Game.PrecacheModel( "models/player/" + ZP_NEMESIS_MODEL + "/" + ZP_NEMESIS_MODEL + ".mdl" );
    g_Game.PrecacheModel( "models/player/" + ZP_ASSASSIN_MODEL + "/" + ZP_ASSASSIN_MODEL + ".mdl" );

    g_Game.PrecacheModel( "models/zombie_plague/v_grenade_fire_lefthanded.mdl" );
    g_Game.PrecacheModel( "models/zombie_plague/v_grenade_flare_lefthanded.mdl" );
    g_Game.PrecacheModel( "models/zombie_plague/v_grenade_frost_lefthanded.mdl" );
    g_Game.PrecacheModel( "models/zombie_plague/v_grenade_infect_lefthanded.mdl" );
    g_Game.PrecacheModel( "models/zombie_plague/cs/p_flashbang.mdl" );
    g_Game.PrecacheModel( "models/zombie_plague/cs/p_hegrenade.mdl" );
    g_Game.PrecacheModel( "models/zombie_plague/cs/p_smokegrenade.mdl" );
    g_Game.PrecacheModel( "models/zombie_plague/cs/w_flashbang.mdl" );
    g_Game.PrecacheModel( "models/zombie_plague/cs/w_hegrenade.mdl" );
    g_Game.PrecacheModel( "models/zombie_plague/cs/w_smokegrenade.mdl" );

    g_Game.PrecacheModel( "models/zombie_plague/v_knife_zombie.mdl" );
    g_Game.PrecacheModel( "models/zombie_plague/null.mdl" );

    g_Game.PrecacheModel( "models/zombie_plague/op4/v_m40a1.mdl" );
    g_Game.PrecacheModel( "models/zombie_plague/op4/v_saw.mdl" );
    g_Game.PrecacheModel( "models/zombie_plague/op4/v_uzi.mdl" );

    // Precache sprites
    g_trailSpr = g_Game.PrecacheModel("sprites/laserbeam.spr");
    g_tracerSpr = g_Game.PrecacheModel("sprites/dot.spr");
    g_exploSpr = g_Game.PrecacheModel("sprites/shockwave.spr");
    g_flameSpr = g_Game.PrecacheModel("sprites/flame.spr");
    g_fexploSpr = g_Game.PrecacheModel("sprites/zombie_plague/fexplo.spr");
    g_zombieBombExploSpr = g_Game.PrecacheModel("sprites/zombie_plague/zombiebomb_exp.spr");
    g_smokeSpr = g_Game.PrecacheModel("sprites/black_smoke3.spr");
    g_glassSpr = g_Game.PrecacheModel("models/glassgibs.mdl");

    // Precache sounds
    g_SoundSystem.PrecacheSound( "zombie_plague/cs/knife/hit1.wav" );
    g_SoundSystem.PrecacheSound( "zombie_plague/cs/knife/hit2.wav" );
    g_SoundSystem.PrecacheSound( "zombie_plague/cs/knife/hit3.wav" );
    g_SoundSystem.PrecacheSound( "zombie_plague/cs/knife/hit4.wav" );
    g_SoundSystem.PrecacheSound( "zombie_plague/cs/knife/hitwall1.wav" );
    g_SoundSystem.PrecacheSound( "zombie_plague/cs/knife/slash1.wav" );
    g_SoundSystem.PrecacheSound( "zombie_plague/cs/knife/slash2.wav" );
    g_SoundSystem.PrecacheSound( "zombie_plague/cs/knife/stab.wav" );

    g_SoundSystem.PrecacheSound( "zombie_plague/cs/grenade/bounce.wav" );
    g_SoundSystem.PrecacheSound( "zombie_plague/cs/grenade/pin.wav" );

    g_SoundSystem.PrecacheSound( ZP_AMBIENCE_SND );
    g_SoundSystem.PrecacheSound( ZP_ARMOR_EQUIP_SND );
    g_SoundSystem.PrecacheSound( ZP_ARMOR_HIT_SND );

    g_SoundSystem.PrecacheSound( ZP_PICKUP_SND );

    g_SoundSystem.PrecacheSound( ZP_NADEMODE_PROXIMITY_BELL_SND );
    g_SoundSystem.PrecacheSound( ZP_NADEMODE_TRIP_ACTIVATE_SND );
    g_SoundSystem.PrecacheSound( ZP_NADEMODE_TRIP_DEPLOY_SND );
    g_SoundSystem.PrecacheSound( ZP_NADEMODE_TRIP_CHARGE_SND );
    g_SoundSystem.PrecacheSound( ZP_NADEMODE_MOTION_GEIGER_SND );
    g_SoundSystem.PrecacheSound( ZP_NADEMODE_HOMING_PING_SND );

    // Precache countdown
    // ZP_PrecacheSounds( ZP_COUNTDOWN_SND );
    int pickVoice = RandomInt( 1, 6 );

    for (uint i = 0; i < ZP_COUNTDOWN_SND.length(); i++)
    {
        if ( pickVoice == 1 ) // CSO VOX
            ZP_COUNTDOWN_SND[ i ] = "zombie_plague/countdown/" + ZP_COUNTDOWN_DEFAULT_SND[ i ];
        else if ( pickVoice <= 4 )
            ZP_COUNTDOWN_SND[ i ] = "zombie_plague/countdown" + string( pickVoice ) + "/" + ZP_COUNTDOWN_DEFAULT_SND[ i ];
        else if ( pickVoice == 5 ) // VOX
            ZP_COUNTDOWN_SND[ i ] = "vox/" + ZP_COUNTDOWN_DEFAULT_SND[ i ];
        else // female VOX
            ZP_COUNTDOWN_SND[ i ] = "fvox/" + ZP_COUNTDOWN_DEFAULT_SND[ i ];

        g_SoundSystem.PrecacheSound( ZP_COUNTDOWN_SND[ i ] );
    }

    ZP_PrecacheSounds( ZP_WIN_ZOMBIES_SND );
    ZP_PrecacheSounds( ZP_WIN_HUMANS_SND );
    ZP_PrecacheSounds( ZP_WIN_NO_ONE_SND );
    ZP_PrecacheSounds( ZP_ZOMBIE_INFECT_SND );
    ZP_PrecacheSounds( ZP_ZOMBIE_PAIN_SND );
    ZP_PrecacheSounds( ZP_NEMESIS_PAIN_SND );
    ZP_PrecacheSounds( ZP_ASSASSIN_PAIN_SND );
    ZP_PrecacheSounds( ZP_ZOMBIE_DIE_SND );
    ZP_PrecacheSounds( ZP_ZOMBIE_FALL_SND );
    ZP_PrecacheSounds( ZP_ZOMBIE_IDLE_SND );
    ZP_PrecacheSounds( ZP_ZOMBIE_IDLE_LAST_SND );
    ZP_PrecacheSounds( ZP_ZOMBIE_MADNESS_SND );
    ZP_PrecacheSounds( ZP_ROUND_NEMESIS_SND );
    ZP_PrecacheSounds( ZP_ROUND_ASSASSIN_SND );
    ZP_PrecacheSounds( ZP_ROUND_SURVIVOR_SND );
    ZP_PrecacheSounds( ZP_ROUND_SNIPER_SND );
    ZP_PrecacheSounds( ZP_ROUND_SWARM_SND );
    ZP_PrecacheSounds( ZP_ROUND_MULTI_SND );
    ZP_PrecacheSounds( ZP_ROUND_PLAGUE_SND );
    ZP_PrecacheSounds( ZP_ROUND_ARMAGEDDON_SND );
    ZP_PrecacheSounds( ZP_ROUND_APOCALYPSE_SND );
    ZP_PrecacheSounds( ZP_ROUND_NIGHTMARE_SND );
    ZP_PrecacheSounds( ZP_GRENADE_HOLY_EXPLODE_SND );
    ZP_PrecacheSounds( ZP_GRENADE_INFECT_EXPLODE_SND );
    ZP_PrecacheSounds( ZP_GRENADE_INFECT_PLAYER_SND );
    ZP_PrecacheSounds( ZP_GRENADE_JUMP_EXPLODE_SND );
    ZP_PrecacheSounds( ZP_GRENADE_JUMP_SND );
    ZP_PrecacheSounds( ZP_GRENADE_JUMP_IDLE_SND );
    ZP_PrecacheSounds( ZP_GRENADE_FIRE_EXPLODE_SND );
    ZP_PrecacheSounds( ZP_GRENADE_FIRE_PLAYER_SND );
    ZP_PrecacheSounds( ZP_GRENADE_FROST_EXPLODE_SND );
    ZP_PrecacheSounds( ZP_GRENADE_FROST_PLAYER_SND );
    ZP_PrecacheSounds( ZP_GRENADE_FROST_BREAK_SND );
    ZP_PrecacheSounds( ZP_GRENADE_FLARE_SND );
    ZP_PrecacheSounds( ZP_ANTIDOTE_SND );
    ZP_PrecacheSounds( ZP_THUNDER_SND );
}

//-----------------------------------------------------------------------------
// Purpose: precache array of sounds
//-----------------------------------------------------------------------------

void ZP_PrecacheSounds(const array<string> aSounds)
{
    if ( g_bDebug ) zp_log("ZP_PrecacheSounds()");

    for (uint i = 0; i < aSounds.length(); i++)
	{
		g_SoundSystem.PrecacheSound( aSounds[i] );
		g_Game.PrecacheGeneric( "sound/" + aSounds[i] );
	}
}

//-----------------------------------------------------------------------------
// Purpose: map initialization
//-----------------------------------------------------------------------------

void MapInit()
{
    if ( g_bDebug ) zp_log("MapInit()");

    string sMapName = g_Engine.mapname;
    CBaseEntity@ pWorld = g_EntityFuncs.Instance( 0 );

    g_bEnabled = ZP_IsMapSupported( sMapName );

    // Zombie Escape support
    if ( sMapName.StartsWith("ze_") )
    {
        g_bZombieEscape = true;
    }
    else
    {
        g_bZombieEscape = false;
    }

    // Tell to the world / map (whatever) that Zombie Plague is enabled (same for ZE)
    if ( pWorld !is null )
    {
        CustomKeyvalues@ pCustomKV = pWorld.GetCustomKeyvalues();

        if ( pCustomKV !is null )
        {
            pCustomKV.SetKeyvalue( "$d_zombie_plague", g_bEnabled ? 1 : 0 );
            pCustomKV.SetKeyvalue( "$d_zombie_escape", ( g_bEnabled && g_bZombieEscape ) ? 1 : 0 );
        }
    }

    // Remove timer of a new game
    if ( Scheduler_InitNewGame !is null )
    {
        if ( !Scheduler_InitNewGame.HasBeenRemoved() )
            g_Scheduler.RemoveTimer( Scheduler_InitNewGame );
        
        @Scheduler_InitNewGame = null;
    }

    ZP_RemoveThinkTimers();

    if ( g_bEnabled )
    {
        RTV_MapInit();

        ZP_Init();
        ZP_Precache();

        // Enable wootguy's anticheat frfr
        if ( ZP_ENABLE_ANTICHEAT )
            g_EngineFuncs.ServerCommand("anticheat.enable 1\n");

        if ( ZP_CHANGE_HOSTNAME )
            g_EngineFuncs.ServerCommand("hostname \"" + ZP_HOSTNAME + "\"\n");
    }
    else
    {
        if ( ZP_ENABLE_ANTICHEAT )
            g_EngineFuncs.ServerCommand("anticheat.enable 0\n");

        if ( ZP_CHANGE_HOSTNAME )
            g_EngineFuncs.ServerCommand("hostname \"" + ZP_HOSTNAME_DEFAULT + "\"\n");
    }
}

//-----------------------------------------------------------------------------
// Purpose: map activation
//-----------------------------------------------------------------------------

void MapActivate()
{
    if ( g_bDebug ) zp_log("MapActivate()");

    if ( g_bEnabled )
    {
        if ( Scheduler_AmbienceSound is null )
            @Scheduler_AmbienceSound = g_Scheduler.SetTimeout("ZP_AmbienceSound", 2.0f);

        if ( Scheduler_MapLighting is null )
            @Scheduler_MapLighting = g_Scheduler.SetTimeout("ZP_MapLighting", 2.0f);
        
        // Do some changes of map entities
        ZP_ChangeEntities();
    }

    ZP_RemoveThinkTimers();
}

//-----------------------------------------------------------------------------
// Purpose: map start
//-----------------------------------------------------------------------------

void MapStart()
{
	if ( g_iAmmoIndex.length() > 0 )
		g_iAmmoIndex.resize( 0 );

	for (uint i = 0; i < g_pAmmo.length(); i++)
	{
        g_iAmmoIndex.insertLast( g_PlayerFuncs.GetAmmoIndex( g_pAmmo[i] ) );
    }
}

//-----------------------------------------------------------------------------
// Purpose: MapChange hook
//-----------------------------------------------------------------------------

HookReturnCode MapChange()
{
    if ( !g_bEnabled )
        return HOOK_CONTINUE;

    // Save player stats
    for (int i = 1; i <= g_Engine.maxClients; i++)
    {
        CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

        if ( pPlayer is null || !pPlayer.IsConnected() )
            continue;
        
        ZP_SaveStats( pPlayer );
        ZP_ResetPlayerModel( pPlayer, false );
    }

    // Remove timer of new game
    if ( Scheduler_InitNewGame !is null )
    {
        if ( !Scheduler_InitNewGame.HasBeenRemoved() )
            g_Scheduler.RemoveTimer( Scheduler_InitNewGame );
        
        @Scheduler_InitNewGame = null;
    }

    ZP_ResetState();
    ZP_RemoveThinkTimers();

    return HOOK_CONTINUE;
}

//-----------------------------------------------------------------------------
// Purpose: reset states
//-----------------------------------------------------------------------------

void ZP_ResetState()
{
    if ( g_bDebug ) zp_log("ZP_ResetState()");

    ZP_RemoveTimers();

    g_iGameState = ZP_STATE_HIBERNATION;
    g_iGameMode = ZP_MODE_NONE;
    g_iPrevGameMode = ZP_MODE_NONE;

    g_flHelpMessage = -1.0f;

    g_flStatsUpdate = -1.0f;
    g_flStatsSave = -1.0f;

    g_flThunderClapTime = -1.0f;

    g_iAliveHumans = 0;
    g_iAliveZombies = 0;

    for (int i = 0; i < 33; i++)
    {
        g_bFirstConnect[i] = true;
        g_bIsHuman[i] = false;
        g_bIsZombie[i] = false;
        g_bAlive[i] = false;
        g_iClassType[i] = ZP_HUMAN_DEFAULT;
        g_flVelocityModifier[i] = 1.0f;
        g_flBurningDuration[i] = 0.0f;
        g_flLastLeapTime[i] = 0.0f;
        g_flRespawnTime[i] = -1.0f;
        g_bCanBuyPrimaryWeapons[i] = false;
        g_bCanBuySecondaryWeapons[i] = false;
        g_bFrozen[i] = false;
        g_bFirstZombie[i] = false;
        g_bNightvision[i] = false;
        g_bHasNightvision[i] = false;
        g_bAura[i] = false;
        g_bNoDamage[i] = false;
        g_bInfiniteClipAmmo[i] = false;
        g_bIncendiaryAmmo[i] = false;
        g_iLaserMinesCount[i] = 0;
        g_iSandBagsCount[i].resize(0);
        g_flMakeBlood[i] = 0.0f;
        g_flZombieIdle[i] = 0.0f;
        @g_pCurrentWeapon[i] = null;
        g_sSavedPlayerModels[i] = "";
    }
}

//-----------------------------------------------------------------------------
// Purpose: reset states of a client
//-----------------------------------------------------------------------------

void ZP_ResetClientState(int index, bool bResetModel = true)
{
    if ( g_bDebug ) zp_log("ZP_ResetClientState(): " + string(bResetModel));

    g_bIsHuman[index] = true;
    g_bIsZombie[index] = false;
    g_bAlive[index] = false;
    g_iClassType[index] = ZP_HUMAN_DEFAULT;

    ZP_ResetExtraStates( index );

    if ( bResetModel )
        g_sSavedPlayerModels[index] = "";
}

//-----------------------------------------------------------------------------
// Purpose: reset extra states of a client
//-----------------------------------------------------------------------------

void ZP_ResetExtraStates(int index)
{
    if ( g_bDebug ) zp_log("ZP_ResetExtraStates()");

    g_flVelocityModifier[index] = 1.0f;
    g_flBurningDuration[index] = 0.0f;
    g_flLastLeapTime[index] = 0.0f;
    g_flRespawnTime[index] = -1.0f;
    g_bCanBuyPrimaryWeapons[index] = false;
    g_bCanBuySecondaryWeapons[index] = false;
    g_bFrozen[index] = false;
    g_bFirstZombie[index] = false;
    g_bNightvision[index] = false;
    g_bHasNightvision[index] = false;
    g_bAura[index] = false;
    g_bNoDamage[index] = false;
    g_bInfiniteClipAmmo[index] = false;
    g_bIncendiaryAmmo[index] = false;
    g_flMakeBlood[index] = 0.0f;
    g_flZombieIdle[index] = 0.0f;
}

//-----------------------------------------------------------------------------
// Purpose: remove all timers
//-----------------------------------------------------------------------------

void ZP_RemoveTimers()
{
    if ( g_bDebug ) zp_log("ZP_RemoveTimers()");

    if ( Scheduler_BeginInfection !is null )
    {
        if ( !Scheduler_BeginInfection.HasBeenRemoved() )
            g_Scheduler.RemoveTimer( Scheduler_BeginInfection );
        
        @Scheduler_BeginInfection = null;
    }

    if ( Scheduler_CountdownTask !is null )
    {
        if ( !Scheduler_CountdownTask.HasBeenRemoved() )
            g_Scheduler.RemoveTimer( Scheduler_CountdownTask );
        
        @Scheduler_CountdownTask = null;
    }
}

//-----------------------------------------------------------------------------
// Purpose: remove think timers
//-----------------------------------------------------------------------------

void ZP_RemoveThinkTimers()
{
    if ( g_bDebug ) zp_log("ZP_RemoveThinkTimers()");

    if ( Scheduler_Think !is null )
    {
        if ( !Scheduler_Think.HasBeenRemoved() )
            g_Scheduler.RemoveTimer( Scheduler_Think );
        
        @Scheduler_Think = null;
    }

    if ( Scheduler_Think50 !is null )
    {
        if ( !Scheduler_Think50.HasBeenRemoved() )
            g_Scheduler.RemoveTimer( Scheduler_Think50 );
        
        @Scheduler_Think50 = null;
    }

    if ( Scheduler_Think100 !is null )
    {
        if ( !Scheduler_Think100.HasBeenRemoved() )
            g_Scheduler.RemoveTimer( Scheduler_Think100 );
        
        @Scheduler_Think100 = null;
    }
}

//-----------------------------------------------------------------------------
// Purpose: remove all unnecessary entities
//-----------------------------------------------------------------------------

void ZP_RemoveEntities()
{
    if ( g_bDebug ) zp_log("ZP_RemoveEntities()");

    CBaseEntity@ pEntity = null;

    // Remove custom grenades
    for (uint i = 0; i < g_pCustomGrenades.length(); i++)
    {
        if ( g_EntityFuncs.IsValidEntity( g_pCustomGrenades[i] ) )
        {
            g_EntityFuncs.Remove( g_EntityFuncs.Instance( g_pCustomGrenades[i] ) );
        }

        g_pCustomGrenades.removeAt(i);
        i--;
    }

    // Remove force fields
    for (uint i = 0; i < g_pForceFields.length(); i++)
    {
        if ( g_EntityFuncs.IsValidEntity( g_pForceFields[i] ) )
        {
            g_EntityFuncs.Remove( g_EntityFuncs.Instance( g_pForceFields[i] ) );
        }

        g_pForceFields.removeAt(i);
        i--;
    }

    // Remove laser mines
    for (uint i = 0; i < g_pLaserMines.length(); i++)
    {
        if ( g_EntityFuncs.IsValidEntity( g_pLaserMines[i] ) )
        {
            g_EntityFuncs.Remove( g_EntityFuncs.Instance( g_pLaserMines[i] ) );
        }

        g_pLaserMines.removeAt(i);
        i--;
    }

    // Remove sandbags
    for (uint i = 0; i < g_pSandBags.length(); i++)
    {
        if ( g_EntityFuncs.IsValidEntity( g_pSandBags[i] ) )
        {
            g_EntityFuncs.Remove( g_EntityFuncs.Instance( g_pSandBags[i] ) );
        }

        g_pSandBags.removeAt(i);
        i--;
    }

    // Remove all weapons
    while ( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "weapon_*")) !is null )
    {
        if ( pEntity.pev.owner is null )
        {
            if ( g_bDebug ) zp_log(pEntity.pev.classname);

            g_EntityFuncs.Remove( pEntity );
        }
    }

    g_pCustomGrenades.resize( 0 );
    g_pForceFields.resize( 0 );
    g_pLaserMines.resize( 0 );
    g_pSandBags.resize( 0 );
}

//-----------------------------------------------------------------------------
// Purpose: watchdog custom entities
//-----------------------------------------------------------------------------

void ZP_CustomEntitiesWatchdog()
{
    if ( g_bDebug ) zp_log("ZP_CustomEntitiesWatchdog()");

    // Custom grenades watchdog
    for (uint i = 0; i < g_pCustomGrenades.length(); i++)
    {
        if ( !g_EntityFuncs.IsValidEntity( g_pCustomGrenades[i] ) )
        {
            g_pCustomGrenades.removeAt( i );
            i--;
        }
    }

    // Force fields watchdog
    for (uint i = 0; i < g_pForceFields.length(); i++)
    {
        if ( !g_EntityFuncs.IsValidEntity( g_pForceFields[i] ) )
        {
            g_pForceFields.removeAt( i );
            i--;
        }
    }

    // Laser mines watchdog
    for (uint i = 0; i < g_pLaserMines.length(); i++)
    {
        if ( !g_EntityFuncs.IsValidEntity( g_pLaserMines[i] ) )
        {
            g_pLaserMines.removeAt( i );
            i--;
        }
    }

    // Laser mines watchdog
    for (uint i = 0; i < g_pSandBags.length(); i++)
    {
        if ( !g_EntityFuncs.IsValidEntity( g_pSandBags[i] ) )
        {
            g_pSandBags.removeAt( i );
            i--;
        }
    }
}

//-----------------------------------------------------------------------------
// Purpose: turn on/off the plugin
//-----------------------------------------------------------------------------

void ZP_TogglePlugin(CBasePlayer@ pPlayer, bool bHasState, int iState, bool bHasMap, string sMap)
{
    if ( bHasState )
    {
        bool state = ( iState != 0 );

        if ( state != g_bEnabled )
        {
            g_bEnabled = state;

            if ( pPlayer !is null )
                g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "[ZP] Zombie Plague plugin was " + string(g_bEnabled ? "enabled\n" : "disabled\n") );

            if ( !g_bEnabled )
            {
                ZP_ResetState();

                ZP_RemoveTimers();
                ZP_RemoveThinkTimers();

                // Not gonna remove 'ClientPutInServer' hook, needed to reset array g_flCommandCooldown
                g_Hooks.RemoveHook( Hooks::Game::MapChange );
                g_Hooks.RemoveHook( Hooks::Player::PlayerTakeDamage );
                g_Hooks.RemoveHook( Hooks::Player::PlayerKilled );
                g_Hooks.RemoveHook( Hooks::Player::PlayerPreThink );
                g_Hooks.RemoveHook( Hooks::Player::PlayerPostThink );
                g_Hooks.RemoveHook( Hooks::Player::PlayerUse );
                g_Hooks.RemoveHook( Hooks::Player::PlayerSpawn );
                g_Hooks.RemoveHook( Hooks::Player::ClientDisconnect );
                // g_Hooks.RemoveHook( Hooks::Player::ClientSay );
            }

            if ( bHasMap )
            {
                if ( !g_bEnabled || ZP_IsMapSupported( sMap ) )
                {
                    g_EngineFuncs.ServerCommand("changelevel \"" + sMap + "\"\n");
                }
                else
                {
                    g_EngineFuncs.ServerCommand("changelevel \"" + g_Engine.mapname + "\"\n");
                }
            }
            else
            {
                g_EngineFuncs.ServerCommand("changelevel \"" + g_Engine.mapname + "\"\n");
            }
        }
        else if ( pPlayer !is null )
        {
            g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "[ZP] Zombie Plague plugin already " + string(g_bEnabled ? "enabled\n" : "disabled\n") );
        }
    }
    else if ( pPlayer !is null )
    {
        g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "[ZP] Zombie Plague plugin is " + string(g_bEnabled ? "enabled\n" : "disabled\n") );
    }
}

//-----------------------------------------------------------------------------
// Purpose: save player's model
//-----------------------------------------------------------------------------

void ZP_SavePlayerModel(CBasePlayer@ pPlayer)
{
    KeyValueBuffer@ pInfoBuffer = g_EngineFuncs.GetInfoKeyBuffer( pPlayer.edict() );

    string sModel = pInfoBuffer.GetValue("model");

    int iZombieClass = g_iZombieClass[ pPlayer.entindex() ];
    int iCurrentZombieClass = g_iCurrentZombieClass[ pPlayer.entindex() ];

    if ( sModel == ZP_NEMESIS_MODEL ||
        sModel == ZP_ASSASSIN_MODEL ||
        ( iZombieClass >= 0 && sModel == g_zombieClasses[iZombieClass].m_sModel ) ||
        ( iCurrentZombieClass >= 0 && sModel == g_zombieClasses[iCurrentZombieClass].m_sModel ) )
    {
        g_sSavedPlayerModels[pPlayer.entindex()] = "";
    }
    else
    {
        g_sSavedPlayerModels[pPlayer.entindex()] = pInfoBuffer.GetValue("model");
    }
}

//-----------------------------------------------------------------------------
// Purpose: reset player's model
//-----------------------------------------------------------------------------

void ZP_ResetPlayerModel(CBasePlayer@ pPlayer, bool bForceReset = true)
{
    int idx = pPlayer.entindex();

    pPlayer.ResetOverriddenPlayerModel( true, true );

    KeyValueBuffer@ pInfoBuffer = g_EngineFuncs.GetInfoKeyBuffer( pPlayer.edict() );
    string sModel = pInfoBuffer.GetValue("model");

    int iZombieClass = g_iZombieClass[ pPlayer.entindex() ];
    int iCurrentZombieClass = g_iCurrentZombieClass[ pPlayer.entindex() ];

    if ( sModel == ZP_NEMESIS_MODEL ||
        sModel == ZP_ASSASSIN_MODEL ||
        ( iZombieClass >= 0 && sModel == g_zombieClasses[iZombieClass].m_sModel ) ||
        ( iCurrentZombieClass >= 0 && sModel == g_zombieClasses[iCurrentZombieClass].m_sModel ) )
    {
        if ( g_sSavedPlayerModels[idx] != "" )
        {
            pInfoBuffer.SetValue( "model", g_sSavedPlayerModels[idx] );
            string sChooseModel = "model \"" + g_sSavedPlayerModels[idx] + "\"";
            UTIL_ClientCommand( pPlayer.edict(), sChooseModel );
        }
        else if ( bForceReset )
        {
            pInfoBuffer.SetValue( "model", "player" );
            g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] Your model has been changed to default due to a plugin issue\n" );
        }
    }
}

//-----------------------------------------------------------------------------
// Purpose: wrapper function to initialize new game
//-----------------------------------------------------------------------------

void ZP_InitNewGame_Wrapper()
{
    if ( g_bZombieEscape )
    {
        // I tried my best to respawn map entities when a game round ends but most entities have broken rotation angles...
        g_EngineFuncs.ServerCommand("restart\n");
    }
    else
    {
        ZP_InitNewGame();
    }
}

//-----------------------------------------------------------------------------
// Purpose: initialize new game
//-----------------------------------------------------------------------------

void ZP_InitNewGame()
{
    if ( g_bDebug ) zp_log("ZP_InitNewGame()");

    if ( g_flThunderClapTime == -1.0f && ZP_THUNDER_CLAP > 0.0f )
    {
        g_flThunderClapTime = g_Engine.time + ZP_THUNDER_CLAP;
    }

    const float flCountdown = ( g_bZombieEscape ? ZP_ZE_PREPARATION_TIME : ZP_PREPARATION_TIME );

    g_flHelpMessage = g_Engine.time + 5.0f;

    @Scheduler_InitNewGame = null;

    g_flGameStartTime = -1.0f;
    g_flGameEndTime = -1.0f;

    g_iPrevGameMode = g_iGameMode;
    g_iGameMode = ZP_MODE_NONE;

    ZP_RemoveTimers();
    ZP_RemoveEntities();
    ZP_BeginGamePreparation();
    ZP_CountdownTask( int( Math.Floor(flCountdown) ) );

    // Start think functions
    if ( Scheduler_Think is null )
        ZP_Think();

    if ( Scheduler_Think50 is null )
        ZP_Think50();

    if ( Scheduler_Think100 is null )
        ZP_Think100();

    @Scheduler_BeginInfection = g_Scheduler.SetTimeout("ZP_BeginInfection", flCountdown + 0.5f);

    UTIL_HudMessageAll( "The T-Virus has been set loose...", 0, 125, 200, HUD_EVENT_X, HUD_EVENT_Y, 0, 0.0f, 3.0f, 2.0f, 1.0f, HUD_CHAN_EVENT );
}

//-----------------------------------------------------------------------------
// Purpose: countdown voice notification
//-----------------------------------------------------------------------------

void ZP_CountdownTask(int iNumber)
{
    if ( g_bDebug ) zp_log("ZP_CountdownTask(): " + string(iNumber));

    if ( g_iGameState >= ZP_STATE_GAME_STARTED )
        return;

    if ( iNumber > 0 )
    {
        // Play notification
        if ( iNumber <= 10 )
            UTIL_PlaySound( ZP_COUNTDOWN_SND[iNumber - 1] );

        UTIL_HudMessageAll( "Infection in " + string(iNumber), 200, 0, 0, HUD_COUNTDOWN_X, HUD_COUNTDOWN_Y, 1, 0.25f, 1.5f, 0.05f, 0.05f, HUD_CHAN_COUNTDOWN );

        @Scheduler_CountdownTask = g_Scheduler.SetTimeout("ZP_CountdownTask", 1.0f, iNumber - 1);
    }
    else
    {
        @Scheduler_CountdownTask = null;
    }
}

//-----------------------------------------------------------------------------
// Purpose: begin preparation before infection starts
//-----------------------------------------------------------------------------

void ZP_BeginGamePreparation()
{
    if ( g_bDebug ) zp_log("ZP_BeginGamePreparation()");

    g_iAliveHumans = 0;
    g_iAliveZombies = 0;

    g_iGameState = ZP_STATE_GAME_PREPARING;

    // Show fog
    UTIL_FogAll( zp_fog.GetInt(), ZP_FOG_COLOR_R, ZP_FOG_COLOR_G, ZP_FOG_COLOR_B, ZP_FOG_START_DIST, ZP_FOG_END_DIST );

    for (int i = 1; i <= g_Engine.maxClients; i++)
    {
        CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
		
        // Reset states
        ZP_ResetClientState( i, false );

		if ( pPlayer !is null && pPlayer.IsConnected() )
		{
            pPlayer.pev.flags &= ~FL_FROZEN;

            ZP_RespawnAsHuman( pPlayer, i );
            g_iAliveHumans++;
        }
        else
        {
            g_bIsHuman[i] = true;
            g_bAlive[i] = false;
        }
    }

    UTIL_UpdateScoreInfoAll();
}

//-----------------------------------------------------------------------------
// Purpose: ambience sound
//-----------------------------------------------------------------------------

void ZP_AmbienceSound()
{
    if ( g_bDebug ) zp_log("ZP_AmbienceSound()");

    if ( !g_bEnabled )
    {
        @Scheduler_AmbienceSound = null;
        return;
    }

    UTIL_PlaySound( "zombie_plague/ambience.wav" );

    @Scheduler_AmbienceSound = g_Scheduler.SetTimeout("ZP_AmbienceSound", 17.0f);
}

//-----------------------------------------------------------------------------
// Purpose: map lighting
//-----------------------------------------------------------------------------

void ZP_MapLighting()
{
    if ( g_bDebug ) zp_log("ZP_MapLighting()");

    if ( !g_bEnabled )
    {
        @Scheduler_MapLighting = null;
        return;
    }

    string lighting = ( g_iGameMode == ZP_MODE_ASSASSIN ? 'a' : zp_lighting.GetString() );

    if ( lighting[0] != '0' )
    {
        // Darkest light settings?
        if ( lighting[0] >= 'a' && lighting[0] <= 'd' )
        {
            if ( g_flThunderClapTime > 0.0f && g_flThunderClapTime <= g_Engine.time )
            {
                if ( Scheduler_ThunderClap is null )
                {
                    g_iLightsIterator = 0;
                    g_sLightsCycle = UTIL_GetRandomStringFromArray( ZP_THUNDER_LIGHTS );
                    g_iLightsCycleLength = int( g_sLightsCycle.Length() );

                    ZP_ThunderClap();
                }
            }
            else
            {
                g_EngineFuncs.LightStyle( 0, lighting );
            }
        }
        else
        {
            g_EngineFuncs.LightStyle( 0, lighting );
        }
    }

    @Scheduler_MapLighting = g_Scheduler.SetTimeout("ZP_MapLighting", 5.0f);
}

//-----------------------------------------------------------------------------
// Purpose: thunder clap
//-----------------------------------------------------------------------------

void ZP_ThunderClap()
{
    if ( !g_bEnabled )
    {
        if ( g_bDebug ) zp_log("ZP_ThunderClap()");

        @Scheduler_ThunderClap = null;
        return;
    }

    if ( g_iLightsIterator == 0 )
    {
        UTIL_PlaySound( UTIL_GetRandomStringFromArray( ZP_THUNDER_SND ) );
    }

    if ( g_iLightsIterator >= g_iLightsCycleLength )
    {
        if ( g_bDebug ) zp_log("ZP_ThunderClap(): END");

        g_EngineFuncs.LightStyle( 0, g_iGameMode == ZP_MODE_ASSASSIN ? 'a' : zp_lighting.GetString() );

        g_flThunderClapTime = g_Engine.time + ZP_THUNDER_CLAP;

        @Scheduler_ThunderClap = null;
        return;
    }

    string light = g_sLightsCycle[g_iLightsIterator];

    if ( g_bDebug ) zp_log("ZP_ThunderClap(): " + light);

    g_EngineFuncs.LightStyle( 0, light );

    g_iLightsIterator++;

    @Scheduler_ThunderClap = g_Scheduler.SetTimeout("ZP_ThunderClap", 0.1f);
}

//-----------------------------------------------------------------------------
// Purpose: choose and start one of infection modes
//-----------------------------------------------------------------------------

void ZP_BeginInfection()
{
    if ( g_bDebug ) zp_log("ZP_BeginInfection()");
    if ( g_bDebug ) zp_log("Previous game mode: " + string(g_iPrevGameMode));

    @Scheduler_BeginInfection = null;
    
    int iAliveHumans = 0;

    g_flGameStartTime = g_Engine.time;
    g_flGameEndTime = g_Engine.time + ZP_GAME_TIME;

    g_iGameState = ZP_STATE_GAME_STARTED;
    g_iGameMode = zp_mode.GetInt();

    g_iAllowedRespawns = ZP_ZOMBIE_MAX_RESPAWNS;

    for (int i = 1; i <= g_Engine.maxClients; i++)
    {
        if ( g_bAlive[i] && g_bIsHuman[i] )
        {
            iAliveHumans++;
        }
    }

    if ( iAliveHumans == 0 )
    {
        g_iGameMode = ZP_MODE_SINGLE_INFECTION;

        ZP_CheckTeams();
        return;
    }

    if ( g_bZombieEscape )
    {
        g_iGameMode = ZP_MODE_MULTIPLE_INFECTION;
    }

    // Survivor mode
    if ( g_iGameMode == ZP_MODE_SURVIVOR || (g_iGameMode == ZP_MODE_NONE && g_iPrevGameMode != ZP_MODE_SURVIVOR && RandomInt(1, ZP_SURVIVOR_CHANCE) == ZP_SURVIVOR_ENABLED) )
    {
        g_iGameMode = ZP_MODE_SURVIVOR;

        int choosenPlayer = UTIL_PickRandomHuman();

        if ( choosenPlayer != -1 )
        {
            CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(choosenPlayer);

            ZP_MakeSurvivor( pPlayer );

            UTIL_HudMessageAll( "" + pPlayer.pev.netname + " is a Survivor !!!", 20, 20, 255, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0f, 5.0f, 1.0f, 1.0f, HUD_CHAN_EVENT );
            UTIL_PlaySound( UTIL_GetRandomStringFromArray( ZP_ROUND_SURVIVOR_SND ) );

            for (int i = 1; i <= g_Engine.maxClients; i++)
            {
                if ( i != choosenPlayer && g_bAlive[i] && g_bIsHuman[i] )
                {
                    ZP_InfectHuman( g_PlayerFuncs.FindPlayerByIndex(i), null, false, true );
                }
            }
        }
    }
    // Sniper mode
    else if ( g_iGameMode == ZP_MODE_SNIPER || (g_iGameMode == ZP_MODE_NONE && g_iPrevGameMode != ZP_MODE_SNIPER && RandomInt(1, ZP_SNIPER_CHANCE) == ZP_SNIPER_ENABLED) )
    {
        g_iGameMode = ZP_MODE_SNIPER;

        int choosenPlayer = UTIL_PickRandomHuman();

        if ( choosenPlayer != -1 )
        {
            CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(choosenPlayer);

            ZP_MakeSniper( pPlayer );

            UTIL_HudMessageAll( "" + pPlayer.pev.netname + " is a Sniper !!!", 20, 20, 255, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0f, 5.0f, 1.0f, 1.0f, HUD_CHAN_EVENT );
            UTIL_PlaySound( UTIL_GetRandomStringFromArray( ZP_ROUND_SNIPER_SND ) );

            for (int i = 1; i <= g_Engine.maxClients; i++)
            {
                if ( i != choosenPlayer && g_bAlive[i] && g_bIsHuman[i] )
                {
                    ZP_InfectHuman( g_PlayerFuncs.FindPlayerByIndex(i), null, false, true );
                }
            }
        }
    }
    // Swarm mode
    else if ( g_iGameMode == ZP_MODE_SWARM || (g_iGameMode == ZP_MODE_NONE && g_iPrevGameMode != ZP_MODE_SWARM && iAliveHumans >= 2 && RandomInt(1, ZP_SWARM_CHANCE) == ZP_SWARM_ENABLED) )
    {
        g_iGameMode = ZP_MODE_SWARM;

        array<int> aHumans;

        int iZombiesCount = iAliveHumans / 2;

        for (int i = 1; i <= g_Engine.maxClients; i++)
        {
            if ( g_bAlive[i] && g_bIsHuman[i] )
            {
                aHumans.insertLast(i);
            }
        }

        do
        {
            uint index = RandomInt( 0, aHumans.length() - 1 );

            CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( aHumans[index] );
            ZP_InfectHuman( pPlayer, null, false, true );

            aHumans.removeAt( index );
            iZombiesCount--;

        } while ( iZombiesCount > 0 );

        UTIL_HudMessageAll( "Swarm Mode !!!", 20, 255, 20, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0f, 5.0f, 1.0f, 1.0f, HUD_CHAN_EVENT );
        UTIL_PlaySound( UTIL_GetRandomStringFromArray( ZP_ROUND_SWARM_SND ) );
    }
    // Multiple Infection mode
    else if ( g_iGameMode == ZP_MODE_MULTIPLE_INFECTION || (g_iGameMode == ZP_MODE_NONE && g_iPrevGameMode != ZP_MODE_MULTIPLE_INFECTION && iAliveHumans >= 2 && RandomInt(1, ZP_MULTI_CHANCE) == ZP_MULTI_ENABLED) )
    {
        g_iGameMode = ZP_MODE_MULTIPLE_INFECTION;

        array<int> aHumans;
        array<Vector> vecSpawnPoints;

        int iZombiesCount = int( Math.Floor(iAliveHumans * ( g_bZombieEscape ? ZP_ZE_MULTI_RATIO : ZP_MULTI_RATIO )) );

        if ( iZombiesCount < 1 )
            iZombiesCount = 1;

        if ( iZombiesCount == 1 && iAliveHumans >= 6 )
            iZombiesCount = 2;
        
        if ( g_bZombieEscape )
        {
            CBaseEntity@ pEntity = null;

            while ( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "info_player_deathmatch")) !is null )
            {
                // No "Start off" flag, actually need to check if an entity is enabled or not..
                if ( pEntity.pev.spawnflags & 2 == 0 )
                    vecSpawnPoints.insertLast( pEntity.pev.origin );
            }

            @pEntity = null;

            while ( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "info_player_start")) !is null )
            {
                // No "Start off" flag, actually need to check if an entity is enabled or not..
                if ( pEntity.pev.spawnflags & 2 == 0 )
                    vecSpawnPoints.insertLast( pEntity.pev.origin );
            }
        }

        for (int i = 1; i <= g_Engine.maxClients; i++)
        {
            if ( g_bAlive[i] && g_bIsHuman[i] )
            {
                aHumans.insertLast(i);
            }
        }

        while ( iZombiesCount > 0 && aHumans.length() > 0 )
        {
            uint index = RandomInt( 0, aHumans.length() - 1 );

            CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( aHumans[index] );

            if ( g_bZombieEscape && vecSpawnPoints.length() > 0 )
            {
                pPlayer.pev.origin = vecSpawnPoints[ RandomInt(0, vecSpawnPoints.length() - 1) ];
            }

            ZP_InfectHuman( pPlayer, null, false, true );

            aHumans.removeAt( index );
            iZombiesCount--;
        }

        UTIL_HudMessageAll( g_bZombieEscape ? "Zombies are coming !!!" : "Multiple Infection !!!", 200, 50, 0, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0f, 5.0f, 1.0f, 1.0f, HUD_CHAN_EVENT );
        UTIL_PlaySound( UTIL_GetRandomStringFromArray( ZP_ROUND_MULTI_SND ) );
    }
    // Plague mode
    else if ( g_iGameMode == ZP_MODE_PLAGUE || (g_iGameMode == ZP_MODE_NONE && g_iPrevGameMode != ZP_MODE_PLAGUE && iAliveHumans >= 4 && RandomInt(1, ZP_PLAGUE_CHANCE) == ZP_PLAGUE_ENABLED) )
    {
        g_iGameMode = ZP_MODE_PLAGUE;

        uint randomIndex;
        int choosenSurvivor;
        int choosenNemesis;

        CBasePlayer@ pSurvivor;
        CBasePlayer@ pNemesis;

        array<int> aHumans;

        int iZombiesCount = int( Math.Floor(iAliveHumans * ZP_PLAGUE_RATIO) ) - 1; // Minus Nemesis

        for (int i = 1; i <= g_Engine.maxClients; i++)
        {
            if ( g_bAlive[i] && g_bIsHuman[i] )
            {
                aHumans.insertLast(i);
            }
        }

        // Choose random Survivor & Nemesis
        randomIndex = RandomInt( 0, aHumans.length() - 1 );

        choosenSurvivor = aHumans[ randomIndex ];
        aHumans.removeAt( randomIndex );

        randomIndex = RandomInt( 0, aHumans.length() - 1 );

        choosenNemesis = aHumans[ randomIndex ];
        aHumans.removeAt( randomIndex );

        @pSurvivor = g_PlayerFuncs.FindPlayerByIndex( choosenSurvivor );
        @pNemesis = g_PlayerFuncs.FindPlayerByIndex( choosenNemesis );

        // Infect some Humans
        while ( iZombiesCount > 0 && aHumans.length() > 0 )
        {
            uint index = RandomInt( 0, aHumans.length() - 1 );

            CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( aHumans[index] );
            ZP_InfectHuman( pPlayer, null, false, true );

            aHumans.removeAt( index );
            iZombiesCount--;
        }

        ZP_MakeSurvivor( pSurvivor );
        ZP_MakeNemesis( pNemesis );

        // HP multiplier
        pSurvivor.pev.health = pSurvivor.pev.max_health = pSurvivor.pev.health * ZP_PLAGUE_SURVIVOR_HP_MULTI;
        pNemesis.pev.health = pNemesis.pev.max_health = pNemesis.pev.health * ZP_PLAGUE_NEMESIS_HP_MULTI;

        UTIL_HudMessageAll( "Plague Mode !!!", 0, 50, 200, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0f, 5.0f, 1.0f, 1.0f, HUD_CHAN_EVENT );
        UTIL_PlaySound( UTIL_GetRandomStringFromArray( ZP_ROUND_PLAGUE_SND ) );
    }
    // Armageddon mode
    else if ( g_iGameMode == ZP_MODE_ARMAGEDDON || (g_iGameMode == ZP_MODE_NONE && g_iPrevGameMode != ZP_MODE_ARMAGEDDON && iAliveHumans >= 2 && RandomInt(1, ZP_ARMAGEDDON_CHANCE) == ZP_ARMAGEDDON_ENABLED) )
    {
        g_iGameMode = ZP_MODE_ARMAGEDDON;

        array<int> aHumans;

        int iNemesisCount = int( Math.Floor(iAliveHumans * ZP_ARMAGEDDON_RATIO) );

        for (int i = 1; i <= g_Engine.maxClients; i++)
        {
            if ( g_bAlive[i] && g_bIsHuman[i] )
            {
                aHumans.insertLast(i);
            }
        }

        // Make Nemesis
        while ( iNemesisCount > 0 && aHumans.length() > 0 )
        {
            uint index = RandomInt( 0, aHumans.length() - 1 );

            CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( aHumans[index] );

            ZP_MakeNemesis( pPlayer );

            // HP multiplier
            pPlayer.pev.health = pPlayer.pev.max_health = pPlayer.pev.health * ZP_ARMAGEDDON_NEMESIS_HP_MULTI;

            aHumans.removeAt( index );
            iNemesisCount--;
        }

        // Make rest as Survivors
        for (uint i = 0; i < aHumans.length(); i++)
        {
            CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( aHumans[i] );

            ZP_MakeSurvivor( pPlayer );

            // HP multiplier
            pPlayer.pev.health = pPlayer.pev.max_health = pPlayer.pev.health * ZP_ARMAGEDDON_SURVIVOR_HP_MULTI;
        }

        UTIL_HudMessageAll( "Armageddon Mode !!!", 181, 62, 244, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0f, 5.0f, 1.0f, 1.0f, HUD_CHAN_EVENT );
        UTIL_PlaySound( UTIL_GetRandomStringFromArray( ZP_ROUND_ARMAGEDDON_SND ) );
    }
    // Apocalypse mode
    else if ( g_iGameMode == ZP_MODE_APOCALYPSE || (g_iGameMode == ZP_MODE_NONE && g_iPrevGameMode != ZP_MODE_APOCALYPSE && iAliveHumans >= 2 && RandomInt(1, ZP_APOCALYPSE_CHANCE) == ZP_APOCALYPSE_ENABLED) )
    {
        g_iGameMode = ZP_MODE_APOCALYPSE;

        array<int> aHumans;

        int iAssassinCount = int( Math.Floor(iAliveHumans * ZP_APOCALYPSE_RATIO) );

        for (int i = 1; i <= g_Engine.maxClients; i++)
        {
            if ( g_bAlive[i] && g_bIsHuman[i] )
            {
                aHumans.insertLast(i);
            }
        }

        // Make Assassin
        while ( iAssassinCount > 0 && aHumans.length() > 0 )
        {
            uint index = RandomInt( 0, aHumans.length() - 1 );

            CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( aHumans[index] );

            ZP_MakeAssassin( pPlayer );

            // HP multiplier
            pPlayer.pev.health = pPlayer.pev.max_health = pPlayer.pev.health * ZP_APOCALYPSE_ASSASSIN_HP_MULTI;

            aHumans.removeAt( index );
            iAssassinCount--;
        }

        // Make rest as Snipers
        for (uint i = 0; i < aHumans.length(); i++)
        {
            CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( aHumans[i] );

            ZP_MakeSniper( pPlayer );

            // HP multiplier
            pPlayer.pev.health = pPlayer.pev.max_health = pPlayer.pev.health * ZP_APOCALYPSE_SNIPER_HP_MULTI;
        }

        UTIL_HudMessageAll( "Apocalypse Mode !!!", 181, 62, 244, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0f, 5.0f, 1.0f, 1.0f, HUD_CHAN_EVENT );
        UTIL_PlaySound( UTIL_GetRandomStringFromArray( ZP_ROUND_APOCALYPSE_SND ) );
    }
    // Nightmare mode
    else if ( g_iGameMode == ZP_MODE_NIGHTMARE || (g_iGameMode == ZP_MODE_NONE && g_iPrevGameMode != ZP_MODE_NIGHTMARE && iAliveHumans >= 4 && RandomInt(1, ZP_NIGHTMARE_CHANCE) == ZP_NIGHTMARE_ENABLED) )
    {
        g_iGameMode = ZP_MODE_NIGHTMARE;

        array<int> aHumans;
        array<int> aZombies;

        int iZombiesCount = int( Math.Floor(iAliveHumans * ZP_NIGHTMARE_RATIO) );

        for (int i = 1; i <= g_Engine.maxClients; i++)
        {
            if ( g_bAlive[i] && g_bIsHuman[i] )
            {
                aHumans.insertLast(i);
            }
        }

        // Collect Zombies
        while ( iZombiesCount > 0 && aHumans.length() > 0 )
        {
            uint index = RandomInt( 0, aHumans.length() - 1 );

            aZombies.insertLast( aHumans[index] );

            aHumans.removeAt( index );
            iZombiesCount--;
        }

        int iAssassinCount = aZombies.length() / 2;

        // Make Assassin
        while ( iAssassinCount > 0 && aZombies.length() > 0 )
        {
            uint index = RandomInt( 0, aZombies.length() - 1 );

            CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( aZombies[index] );

            ZP_MakeAssassin( pPlayer );

            // HP multiplier
            pPlayer.pev.health = pPlayer.pev.max_health = pPlayer.pev.health * ZP_NIGHTMARE_ASSASSIN_HP_MULTI;

            aZombies.removeAt( index );
            iAssassinCount--;
        }

        // Make rest as Nemesis'
        for (uint i = 0; i < aZombies.length(); i++)
        {
            CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( aZombies[i] );

            ZP_MakeNemesis( pPlayer );

            // HP multiplier
            pPlayer.pev.health = pPlayer.pev.max_health = pPlayer.pev.health * ZP_NIGHTMARE_NEMESIS_HP_MULTI;
        }

        int iSniperCount = aHumans.length() / 2;

        // Make Sniper
        while ( iSniperCount > 0 && aHumans.length() > 0 )
        {
            uint index = RandomInt( 0, aHumans.length() - 1 );

            CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( aHumans[index] );

            ZP_MakeSniper( pPlayer );

            // HP multiplier
            pPlayer.pev.health = pPlayer.pev.max_health = pPlayer.pev.health * ZP_NIGHTMARE_SNIPER_HP_MULTI;

            aHumans.removeAt( index );
            iSniperCount--;
        }

        // Make rest as Survivors
        for (uint i = 0; i < aHumans.length(); i++)
        {
            CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( aHumans[i] );

            ZP_MakeSurvivor( pPlayer );

            // HP multiplier
            pPlayer.pev.health = pPlayer.pev.max_health = pPlayer.pev.health * ZP_NIGHTMARE_SURVIVOR_HP_MULTI;
        }

        UTIL_HudMessageAll( "Nightmare Mode !!!", 181, 62, 244, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0f, 5.0f, 1.0f, 1.0f, HUD_CHAN_EVENT );
        UTIL_PlaySound( UTIL_GetRandomStringFromArray( ZP_ROUND_NIGHTMARE_SND ) );
    }
    // Nemesis
    else if ( g_iGameMode == ZP_MODE_NEMESIS || (g_iGameMode == ZP_MODE_NONE && g_iPrevGameMode != ZP_MODE_NEMESIS && RandomInt(1, ZP_NEMESIS_CHANCE) == ZP_NEMESIS_ENABLED) )
    {
        g_iGameMode = ZP_MODE_NEMESIS;

        CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( UTIL_PickRandomHuman() );

        ZP_MakeNemesis( pPlayer );

        UTIL_HudMessageAll( "" + pPlayer.pev.netname + " is a Nemesis !!!", 255, 20, 20, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0f, 5.0f, 1.0f, 1.0f, HUD_CHAN_EVENT );
        UTIL_PlaySound( UTIL_GetRandomStringFromArray( ZP_ROUND_NEMESIS_SND ) );
    }
    // Assassin
    else if ( g_iGameMode == ZP_MODE_ASSASSIN || (g_iGameMode == ZP_MODE_NONE && g_iPrevGameMode != ZP_MODE_ASSASSIN && RandomInt(1, ZP_ASSASSIN_CHANCE) == ZP_ASSASSIN_ENABLED) )
    {
        g_iGameMode = ZP_MODE_ASSASSIN;

        CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( UTIL_PickRandomHuman() );

        ZP_MakeAssassin( pPlayer );

        UTIL_HudMessageAll( "" + pPlayer.pev.netname + " is an Assassin !!!", 255, 255, 20, HUD_EVENT_X, HUD_EVENT_Y, 1, 0.0f, 5.0f, 1.0f, 1.0f, HUD_CHAN_EVENT );
        UTIL_PlaySound( UTIL_GetRandomStringFromArray( ZP_ROUND_ASSASSIN_SND ) );
    }
    // Single Infection
    else
    {
        g_iGameMode = ZP_MODE_SINGLE_INFECTION;

        CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( UTIL_PickRandomHuman() );

        ZP_InfectHuman( pPlayer, null, false, true );

        UTIL_HudMessageAll( "" + pPlayer.pev.netname + " is the first zombie !!", 255, 0, 0, HUD_EVENT_X, HUD_EVENT_Y, 0, 0.0f, 5.0f, 1.0f, 1.0f, HUD_CHAN_EVENT );
    }
}

//-----------------------------------------------------------------------------
// Purpose: think function
//-----------------------------------------------------------------------------

void ZP_Think()
{
    // if ( g_bDebug ) zp_log("ZP_Think()");

    @Scheduler_Think = g_Scheduler.SetTimeout("ZP_Think", 0.0f);
}

//-----------------------------------------------------------------------------
// Purpose: think function (50 ms)
//-----------------------------------------------------------------------------

void ZP_Think50()
{
    // if ( g_bDebug ) zp_log("ZP_Think50()");

    bool bUpdateStats = ( g_flStatsUpdate <= g_Engine.time );
    bool bSaveStats = ( g_flStatsSave <= g_Engine.time );

    // Iterate through all players
    for (int i = 1; i <= g_Engine.maxClients; i++)
    {
        CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

        if ( pPlayer is null || !pPlayer.IsConnected() )
            continue;
        
        if ( bUpdateStats )
        {
            ZP_ShowStats( pPlayer );
        }

        if ( bSaveStats )
        {
            ZP_SaveStats( pPlayer );
        }

        if ( g_bAlive[i] )
        {
            // Aura
            if ( g_bAura[i] )
            {
                Vector vOrigin = pPlayer.pev.origin;

                NetworkMessage message( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vOrigin );
                    message.WriteByte( TE_DLIGHT ); // TE id
                    message.WriteCoord( vOrigin.x ); // x
                    message.WriteCoord( vOrigin.y ); // y
                    message.WriteCoord( vOrigin.z ); // z
                    if ( g_bIsHuman[i] )
                    {
                        if ( g_iClassType[i] == ZP_HUMAN_SNIPER )
                        {
                            message.WriteByte( ZP_SNIPER_AURA_SIZE );
                            message.WriteByte( ZP_SNIPER_AURA_R );
                            message.WriteByte( ZP_SNIPER_AURA_G );
                            message.WriteByte( ZP_SNIPER_AURA_B );
                        }
                        else
                        {
                            message.WriteByte( ZP_SURVIVOR_AURA_SIZE );
                            message.WriteByte( ZP_SURVIVOR_AURA_R );
                            message.WriteByte( ZP_SURVIVOR_AURA_G );
                            message.WriteByte( ZP_SURVIVOR_AURA_B );
                        }
                    }
                    else if ( g_bIsZombie[i] )
                    {
                        message.WriteByte( 20 ); // radius

                        if ( g_iClassType[i] == ZP_ZOMBIE_ASSASSIN )
                        {
                            message.WriteByte( ZP_NVG_ASSASSIN_COLOR_R );
                            message.WriteByte( ZP_NVG_ASSASSIN_COLOR_G );
                            message.WriteByte( ZP_NVG_ASSASSIN_COLOR_B );
                        }
                        else
                        {
                            message.WriteByte( ZP_NVG_NEMESIS_COLOR_R );
                            message.WriteByte( ZP_NVG_NEMESIS_COLOR_G );
                            message.WriteByte( ZP_NVG_NEMESIS_COLOR_B );
                        }
                    }
                    message.WriteByte( 2 ); // life
                    message.WriteByte( 3 ); // decay rate
                message.End();
            }

            if ( g_bIsHuman[i] )
            {
                // Infinite flashlight
                pPlayer.m_iFlashBattery = 100;

                // Infinite ammo
                for (uint j = 0; j < g_iAmmoIndex.length(); j++)
                {
                    int iAmmoIndex = g_iAmmoIndex[j];
                    
                    if ( iAmmoIndex == -1 )
                        continue;

                    int iMaxAmmo = pPlayer.GetMaxAmmo( iAmmoIndex );
                    int iAmmoInventory = pPlayer.AmmoInventory( iAmmoIndex );
                    
                    if ( iMaxAmmo == iAmmoInventory )
                        continue;

                    pPlayer.m_rgAmmo( iAmmoIndex, iMaxAmmo );
                }

                // Infinite clip ammo
                if ( g_bInfiniteClipAmmo[i] )
                {
                    CBasePlayerWeapon@ pWeapon = cast<CBasePlayerWeapon@>( pPlayer.m_hActiveItem.GetEntity() );

                    if ( pWeapon !is null && pWeapon.m_iClip != -1 )
                    {
                        pWeapon.m_iClip = pWeapon.iMaxClip();
                    }
                }

                if ( g_iClassType[i] == ZP_HUMAN_DEFAULT )
                {
                    // Flashlight aura
                    if ( ZP_HUMAN_FLASHLIGHT_AURA && pPlayer.FlashlightIsOn() )
                    {
                        Vector vEye = pPlayer.EyePosition();

                        for (int j = 1; j <= g_Engine.maxClients; j++)
                        {
                            // Don't show on yourself
                            if ( i == j )
                                continue;

                            CBasePlayer@ plr = g_PlayerFuncs.FindPlayerByIndex( j );

                            if ( plr is null || !plr.IsConnected() )
                                continue;

                            NetworkMessage message( MSG_ONE_UNRELIABLE, NetworkMessages::SVC_TEMPENTITY, plr.edict() );
                                message.WriteByte( TE_DLIGHT ); // TE id
                                message.WriteCoord( vEye.x ); // x
                                message.WriteCoord( vEye.y ); // y
                                message.WriteCoord( vEye.z ); // z
                                message.WriteByte( ZP_HUMAN_FLASHLIGHT_AURA_SIZE ); // radius
                                message.WriteByte( ZP_HUMAN_FLASHLIGHT_AURA_BRIGHTNESS ); // r
                                message.WriteByte( ZP_HUMAN_FLASHLIGHT_AURA_BRIGHTNESS ); // g
                                message.WriteByte( ZP_HUMAN_FLASHLIGHT_AURA_BRIGHTNESS ); // b
                                message.WriteByte( 2 ); // life
                                message.WriteByte( 0 ); // decay rate
                            message.End();
                        }
                    }

                    UTIL_SetRenderMode( pPlayer, kRenderFxNone, Vector(255, 255, 255), kRenderNormal, 255 );
                }
                else if ( g_iClassType[i] == ZP_HUMAN_SURVIVOR )
                {
                    UTIL_SetRenderMode( pPlayer, kRenderFxGlowShell, Vector(0, 0, 255), kRenderNormal, 25 );
                }
                else
                {
                    UTIL_SetRenderMode( pPlayer, kRenderFxGlowShell, Vector(0, 255, 0), kRenderNormal, 25 );
                }
            }
            else if ( g_bIsZombie[i] )
            {
                CBasePlayerWeapon@ pWeapon = cast<CBasePlayerWeapon@>( pPlayer.m_hActiveItem.GetEntity() );

                if ( pWeapon !is null )
                {
                    // Not a custom weapon
                    if ( pWeapon.m_iId <= 30 )
                    {
                        pPlayer.DropItem( pWeapon.pev.classname );
                    }
                }

                // Force glow and other shit
                if ( g_iClassType[i] == ZP_ZOMBIE_DEFAULT )
                {
                    if ( ZP_ZOMBIE_BLEEDING && g_flMakeBlood[i] <= g_Engine.time )
                    {
                        UTIL_MakeBlood( pPlayer );

                        g_flMakeBlood[i] = g_Engine.time + 0.7f;
                    }

                    if ( g_flZombieIdle[i] <= g_Engine.time )
                    {
                        if ( g_iAliveZombies == 1 )
                        {
                            g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_VOICE, UTIL_GetRandomStringFromArray( ZP_ZOMBIE_IDLE_LAST_SND ), 1.0f, ATTN_NORM, 0, PITCH_NORM );
                        }
                        else
                        {
                            g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_VOICE, UTIL_GetRandomStringFromArray( ZP_ZOMBIE_IDLE_SND ), 1.0f, ATTN_NORM, 0, PITCH_NORM );
                        }

                        g_flZombieIdle[i] = g_Engine.time + RandomFloat(50.0f, 70.0f);
                    }

                    if ( !g_bFrozen[i] )
                        UTIL_SetRenderMode( pPlayer, kRenderFxNone, Vector(255, 255, 255), kRenderNormal, 255 );
                    
                    pPlayer.SetOverriddenPlayerModel( g_zombieClasses[ g_iCurrentZombieClass[ i ] ].m_sModel );
                }
                else if ( g_iClassType[i] == ZP_ZOMBIE_NEMESIS )
                {
                    UTIL_SetRenderMode( pPlayer, kRenderFxGlowShell, Vector(255, 0, 0), kRenderNormal, 25 );
                    pPlayer.SetOverriddenPlayerModel( ZP_NEMESIS_MODEL );
                }
                else // Assassin
                {
                    UTIL_SetRenderMode( pPlayer, kRenderFxGlowShell, Vector(255, 255, 0), kRenderNormal, 25 );
                    pPlayer.SetOverriddenPlayerModel( ZP_ASSASSIN_MODEL );
                }
            }
        }
        else
        {
            if ( g_bIsZombie[i] )
            {
                if ( g_flRespawnTime[i] > 0.0f && g_flRespawnTime[i] <= g_Engine.time && g_iGameState == ZP_STATE_GAME_STARTED )
                {
                    g_bKillLatePlayers = false;

                    ZP_RespawnAsHuman( pPlayer, i, false );
                    g_iAliveHumans++;

                    ZP_InfectHuman( pPlayer, null ); // UTIL_UpdateScoreInfo is called here

                    g_bKillLatePlayers = true;

                    g_flRespawnTime[i] = -1.0f;
                }
            }
        }

        // Nightvision
        if ( g_bNightvision[i] )
        {
            Vector vEye = pPlayer.EyePosition();

            NetworkMessage message( MSG_ONE_UNRELIABLE, NetworkMessages::SVC_TEMPENTITY, pPlayer.edict() );
                message.WriteByte( TE_DLIGHT ); // TE id
                message.WriteCoord( vEye.x ); // x
                message.WriteCoord( vEye.y ); // y
                message.WriteCoord( vEye.z ); // z
                message.WriteByte( ZP_NVG_SIZE ); // radius
                if ( g_bAlive[i] )
                {
                    if ( g_bIsHuman[i] )
                    {
                        message.WriteByte( ZP_NVG_ZOMBIE_COLOR_R ); // r
                        message.WriteByte( ZP_NVG_ZOMBIE_COLOR_G ); // g
                        message.WriteByte( ZP_NVG_ZOMBIE_COLOR_B ); // b
                    }
                    else if ( g_bIsZombie[i] )
                    {
                        if ( g_iClassType[i] == ZP_ZOMBIE_DEFAULT )
                        {
                            message.WriteByte( ZP_NVG_ZOMBIE_COLOR_R );
                            message.WriteByte( ZP_NVG_ZOMBIE_COLOR_G );
                            message.WriteByte( ZP_NVG_ZOMBIE_COLOR_B );
                        }
                        else if ( g_iClassType[i] == ZP_ZOMBIE_NEMESIS )
                        {
                            message.WriteByte( ZP_NVG_NEMESIS_COLOR_R );
                            message.WriteByte( ZP_NVG_NEMESIS_COLOR_G );
                            message.WriteByte( ZP_NVG_NEMESIS_COLOR_B );
                        }
                        else
                        {
                            message.WriteByte( ZP_NVG_ASSASSIN_COLOR_R );
                            message.WriteByte( ZP_NVG_ASSASSIN_COLOR_G );
                            message.WriteByte( ZP_NVG_ASSASSIN_COLOR_B );
                        }
                    }
                    else
                    {
                        message.WriteByte( ZP_NVG_ZOMBIE_COLOR_R );
                        message.WriteByte( ZP_NVG_ZOMBIE_COLOR_G );
                        message.WriteByte( ZP_NVG_ZOMBIE_COLOR_B );
                    }
                }
                else
                {
                    message.WriteByte( ZP_NVG_ZOMBIE_COLOR_R );
                    message.WriteByte( ZP_NVG_ZOMBIE_COLOR_G );
                    message.WriteByte( ZP_NVG_ZOMBIE_COLOR_B );
                }
                message.WriteByte( 2 ); // life
                message.WriteByte( 0 ); // decay rate
            message.End();
        }
    }

    if ( bUpdateStats )
        g_flStatsUpdate = g_Engine.time + 1.0f;
    
    if ( bSaveStats )
        g_flStatsSave = g_Engine.time + 30.0f; // save every 30 sec

    @Scheduler_Think50 = g_Scheduler.SetTimeout("ZP_Think50", 0.1f);
}

//-----------------------------------------------------------------------------
// Purpose: think function (100 ms)
//-----------------------------------------------------------------------------

void ZP_Think100()
{
    // if ( g_bDebug ) zp_log("ZP_Think100()");

    // Check teams after 30 seconds when the game started
    if ( g_iGameState == ZP_STATE_GAME_STARTED && g_Engine.time - g_flGameStartTime >= 30.0f )
        ZP_CheckTeams();
    
    // Show help message
    if ( g_flHelpMessage > 0.0f && g_flHelpMessage <= g_Engine.time )
    {
        if ( g_iGameState != ZP_STATE_GAME_END )
        {
            g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "**** Zombie Plague BETA ****\n" );
            g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[ZP] Type in the chat /zpmenu to show the game menu (command .zp_menu)\n" );
            g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[ZP] Press F or type in the chat /zpnv to turn on/off night vision (command .zp_nightvision)\n" );
            g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[ZP] Press E to swap places with a teammate\n" );
        }

        g_flHelpMessage = g_Engine.time + RandomFloat(50.0f, 90.0f);
    }

    // Show timer
    if ( !g_bZombieEscape )
        ZP_ShowTimer();

    ZP_CustomEntitiesWatchdog();

    @Scheduler_Think100 = g_Scheduler.SetTimeout("ZP_Think100", 0.1f);
}

//-----------------------------------------------------------------------------
// Purpose: humans win callback
//-----------------------------------------------------------------------------

void ZP_OnHumansWin()
{
    if ( g_bDebug ) zp_log("ZP_OnHumansWin()");

    // Notifications
    UTIL_HudMessageAll( g_bZombieEscape ? "Escape Success!" : "Humans defeated the plague!", 0, 0, 200, HUD_EVENT_X, HUD_EVENT_Y, 0, 0.0f, 3.0f, 2.0f, 1.0f, HUD_CHAN_EVENT );
    UTIL_PlaySound( UTIL_GetRandomStringFromArray( ZP_WIN_HUMANS_SND ) );
}

//-----------------------------------------------------------------------------
// Purpose: zombie win callback
//-----------------------------------------------------------------------------

void ZP_OnZombiesWin()
{
    if ( g_bDebug ) zp_log("ZP_OnZombiesWin()");

    // Notifications
    UTIL_HudMessageAll( g_bZombieEscape ? "Escape Failed!" : "Zombies have taken over the world!", 200, 0, 0, HUD_EVENT_X, HUD_EVENT_Y, 0, 0.0f, 3.0f, 2.0f, 1.0f, HUD_CHAN_EVENT );
    UTIL_PlaySound( UTIL_GetRandomStringFromArray( ZP_WIN_ZOMBIES_SND ) );
}

//-----------------------------------------------------------------------------
// Purpose: no one wins callback
//-----------------------------------------------------------------------------

void ZP_OnNoOneWin()
{
    if ( g_bDebug ) zp_log("ZP_OnNoOneWin()");

    // Notifications
    UTIL_HudMessageAll( "No one won...", 0, 200, 0, HUD_EVENT_X, HUD_EVENT_Y, 0, 0.0f, 3.0f, 2.0f, 1.0f, HUD_CHAN_EVENT );
    UTIL_PlaySound( UTIL_GetRandomStringFromArray( ZP_WIN_NO_ONE_SND ) );
}

//-----------------------------------------------------------------------------
// Purpose: check if one of sides won
//-----------------------------------------------------------------------------

void ZP_CheckTeams()
{
    // if ( g_bDebug ) zp_log("ZP_CheckTeams()");

    if ( g_iAliveHumans == 0 )
    {
        ZP_OnZombiesWin();
    }
    else if ( g_iAliveZombies == 0 )
    {
        ZP_OnHumansWin();
    }
    else
    {
        return;
    }

    g_flGameStartTime = -1.0f;
    g_flGameEndTime = -1.0f;

    g_iGameState = ZP_STATE_GAME_END;
    @Scheduler_InitNewGame = g_Scheduler.SetTimeout("ZP_InitNewGame_Wrapper", 10.0f);
}

//-----------------------------------------------------------------------------
// Purpose: show timer to all players
//-----------------------------------------------------------------------------

void ZP_ShowTimer()
{
    float flTimeLeft;

    if ( g_iGameState >= ZP_STATE_GAME_STARTED )
    {
        flTimeLeft = g_flGameEndTime - g_Engine.time;
    }
    else
    {
        flTimeLeft = ZP_GAME_TIME;
    }

    if ( flTimeLeft < 0.0f )
    {
        if ( g_iGameState != ZP_STATE_GAME_END )
        {
            ZP_OnNoOneWin();

            g_iGameState = ZP_STATE_GAME_END;
            @Scheduler_InitNewGame = g_Scheduler.SetTimeout("ZP_InitNewGame_Wrapper", 10.0f);
        }

        flTimeLeft = 0.0f;
    }

    bool bTimeWarning = Math.max( -1, int( Math.Floor( flTimeLeft ) ) ) <= ZP_GAME_TIME_WARNING;
    
    HUDNumDisplayParams params;
    
    params.channel = HUD_CHAN_TIMER;
    params.flags = HUD_ELEM_SCR_CENTER_X | HUD_ELEM_DEFAULT_ALPHA | HUD_TIME_MINUTES | HUD_TIME_SECONDS | HUD_TIME_COUNT_DOWN;
    params.value = flTimeLeft;
    params.x = 0;
    params.y = 0.9795;
    params.color1 = bTimeWarning ? RGBA(255, 25, 25, 200) : RGBA_SVENCOOP; 
    params.spritename = "stopwatch";
    
    g_PlayerFuncs.HudTimeDisplay( null, params );
}

//-----------------------------------------------------------------------------
// Purpose: show stats of player
//-----------------------------------------------------------------------------

void ZP_ShowStats(CBasePlayer@ pPlayer)
{
    int idx = pPlayer.entindex();

    if ( !g_bAlive[idx] )
    {
        int iSpecTarget = pPlayer.pev.iuser2;

        if ( iSpecTarget != 0 )
        {
            CBasePlayer@ pSpecTarget = g_PlayerFuncs.FindPlayerByIndex( iSpecTarget );

            if ( pSpecTarget !is null )
            {
                string sClass;

                if ( g_bIsZombie[iSpecTarget] )
                {
                    if ( g_iClassType[iSpecTarget] == ZP_ZOMBIE_DEFAULT )
                    {
                        CZombieClass@ zombieClass = g_zombieClasses[ g_iCurrentZombieClass[iSpecTarget] ];

                        sClass = zombieClass.m_sName;
                    }
                    else if ( g_iClassType[iSpecTarget] == ZP_ZOMBIE_NEMESIS )
                    {
                        sClass = "Nemesis";
                    }
                    else
                    {
                        sClass = "Assassin";
                    }
                }
                else
                {
                    if ( g_iClassType[iSpecTarget] == ZP_HUMAN_DEFAULT )
                    {
                        sClass = "Human";
                    }
                    else if ( g_iClassType[iSpecTarget] == ZP_HUMAN_SURVIVOR )
                    {
                        sClass = "Survivor";
                    }
                    else
                    {
                        sClass = "Sniper";
                    }
                }

                string sHealth = string( int(pSpecTarget.pev.health) );
                string sAmmopacks = string( g_iAmmopacks[iSpecTarget] );
                string sArmor = string( int(pSpecTarget.pev.armorvalue) );

                string sMsg = "Spectating: " + pSpecTarget.pev.netname + "\nHP: " + sHealth + " - Class: " + sClass + " - Ammo packs: " + sAmmopacks + " - Armor: " + sArmor;

                UTIL_HudMessage( pPlayer, sMsg, 255, 255, 255, HUD_SPECT_X, HUD_SPECT_Y, 0, 6.0f, 2.0f, 0.0f, 0.0f, HUD_CHAN_SPECT );
            }
        }

        return;
    }

    int r, g, b;
    string sClass;

    if ( g_bIsZombie[idx] )
    {
        if ( g_iClassType[idx] == ZP_ZOMBIE_DEFAULT )
        {
            CZombieClass@ zombieClass = g_zombieClasses[ g_iCurrentZombieClass[idx] ];

            sClass = zombieClass.m_sName;
        }
        else if ( g_iClassType[idx] == ZP_ZOMBIE_NEMESIS )
        {
            sClass = "Nemesis";
        }
        else
        {
            sClass = "Assassin";
        }

        r = 200;
        g = 250;
        b = 0;
    }
    else
    {
        if ( g_iClassType[idx] == ZP_HUMAN_DEFAULT )
        {
            sClass = "Human";
        }
        else if ( g_iClassType[idx] == ZP_HUMAN_SURVIVOR )
        {
            sClass = "Survivor";
        }
        else
        {
            sClass = "Sniper";
        }

        r = 0;
        g = 180; // 0
        b = 255;
    }

    string sHealth = string( int(pPlayer.pev.health) );
    string sAmmopacks = string( g_iAmmopacks[idx] );
    string sArmor = string( int(pPlayer.pev.armorvalue) );

    string sMsg = "HP: " + sHealth + " - Class: " + sClass + " - Ammo packs: " + sAmmopacks + " - Armor: " + sArmor;

    UTIL_HudMessage( pPlayer, sMsg, r, g, b, HUD_STATS_X, HUD_STATS_Y, 0, 6.0f, 2.0f, 0.0f, 0.0f, HUD_CHAN_STATS );
}

//-----------------------------------------------------------------------------
// Purpose: load player stats based on their SteamID
//-----------------------------------------------------------------------------

bool ZP_LoadStats(CBasePlayer@ pPlayer)
{
    string sSteamID = g_EngineFuncs.GetPlayerAuthId( pPlayer.edict() );

    // Invalid ID
    if ( sSteamID.StartsWith("STEAM_ID_") || sSteamID.StartsWith("VALVE_ID_") || sSteamID == "BOT" )
    {
        return false;
    }

    for (uint i = 0; i < sSteamID.Length(); i++)
    {
        if ( sSteamID[i] == ":" )
        {
            sSteamID.SetCharAt( i, ';' );
        }
    }

    bool bFoundAmmopacks = false;
    bool bFoundZombieclass = false;

    string szFilePath = "scripts/plugins/store/zombie_plague/players/" + sSteamID + ".txt";
    File@ pFile = g_FileSystem.OpenFile( szFilePath, OpenFile::READ );

    if ( pFile !is null && pFile.IsOpen() )
    {
        string sLine;

		while ( !pFile.EOFReached() )
		{
			pFile.ReadLine(sLine);
			
			if ( sLine.Length() == 0 )
				continue;
			
			array<string>@ data = sLine.Split("=");

            if ( data.length() == 2 )
            {
                string sKey = data[0];
                string sValue = data[1];

                sKey.Trim(' ');
                sValue.Trim(' ');

                if ( sKey == "Ammopacks" )
                {
                    g_iAmmopacks[ pPlayer.entindex() ] = atoi(sValue);
                    bFoundAmmopacks = true;
                }
                else if ( sKey == "Zombieclass" )
                {
                    g_iZombieClass[ pPlayer.entindex() ] = atoi(sValue);
                    bFoundZombieclass = true;
                }
            }
		}

        pFile.Close();
    }

    // Save stats if something is missing
    if ( !bFoundAmmopacks || !bFoundZombieclass )
    {
        ZP_SaveStats( pPlayer );
    }

    return true;
}

//-----------------------------------------------------------------------------
// Purpose: save player stats based on their SteamID
//-----------------------------------------------------------------------------

bool ZP_SaveStats(CBasePlayer@ pPlayer)
{
    string sSteamID = g_EngineFuncs.GetPlayerAuthId( pPlayer.edict() );

    // Invalid ID
    if ( sSteamID.StartsWith("STEAM_ID_") || sSteamID.StartsWith("VALVE_ID_") || sSteamID == "BOT" )
    {
        return false;
    }

    for (uint i = 0; i < sSteamID.Length(); i++)
    {
        if ( sSteamID[i] == ":" )
        {
            sSteamID.SetCharAt( i, ';' );
        }
    }

    string szFilePath = "scripts/plugins/store/zombie_plague/players/" + sSteamID + ".txt";
    File@ pFile = g_FileSystem.OpenFile( szFilePath, OpenFile::WRITE );

    if ( pFile !is null && pFile.IsOpen() )
    {
        pFile.Write("// " + pPlayer.pev.netname + "\n");
        pFile.Write("Ammopacks = " + string( g_iAmmopacks[ pPlayer.entindex() ] ) + "\n");
        pFile.Write("Zombieclass = " + string( g_iZombieClass[ pPlayer.entindex() ] ));

        pFile.Close();
    }

    return true;
}

//-----------------------------------------------------------------------------
// Purpose: respawn a player as a Human during preparation time
//-----------------------------------------------------------------------------

void ZP_RespawnAsHuman(CBasePlayer@ pPlayer, int index, bool bDeployItems = true)
{
    if ( g_bDebug ) zp_log("ZP_RespawnAsHuman()");

    bool bWasAlive = pPlayer.IsAlive();

    pPlayer.SetClassification( ZP_TEAM_HUMAN );
    pPlayer.RemoveAllItems( false );

    ZP_ResetPlayerModel( pPlayer );

    // Force respawn
    g_PlayerFuncs.RespawnPlayer( pPlayer, true, true );

    if ( bWasAlive && bDeployItems )
    {
        ZP_DeployHumanItems( pPlayer );
    }

    // Remove any glow
    UTIL_SetRenderMode( pPlayer, kRenderFxNone, Vector(255, 255, 255), kRenderNormal, 255 );

    pPlayer.pev.health = ZP_HUMAN_START_HP;
    pPlayer.pev.max_health = ZP_HUMAN_START_HP;

    pPlayer.pev.armorvalue = ZP_HUMAN_START_ARMOR;
    pPlayer.pev.armortype = ZP_HUMAN_MAX_ARMOR;

    g_bIsHuman[index] = true;
    g_bAlive[index] = true;

    if ( bDeployItems )
    {
        g_bCanBuyPrimaryWeapons[index] = true;
        g_bCanBuySecondaryWeapons[index] = true;

        g_Scheduler.SetTimeout("ZP_OpenPrimaryWeaponsMenu", 0.1f, EHandle(pPlayer));
    }
}

//-----------------------------------------------------------------------------
// Purpose: infect a Human
//-----------------------------------------------------------------------------

void ZP_InfectHuman(CBasePlayer@ pPlayer, CBasePlayer@ pInflictor, bool bInfectGrenade = false, bool bSilentMode = false)
{
    if ( g_bDebug ) zp_log("ZP_InfectHuman()");

    int idx = pPlayer.entindex();

    // Zombie class
    g_iCurrentZombieClass[idx] = g_iZombieClass[idx];
    CZombieClass@ zombieClass = g_zombieClasses[ g_iCurrentZombieClass[idx] ];

    ZP_SavePlayerModel( pPlayer );

    pPlayer.SetClassification( ZP_TEAM_ZOMBIE );
    pPlayer.SetOverriddenPlayerModel( zombieClass.m_sModel );
    pPlayer.RemoveAllItems( false );

    // Turn off flashlight
    if ( pPlayer.FlashlightIsOn() )
    {
        pPlayer.FlashlightTurnOff();
    }

    ZP_DeployZombieItems( pPlayer );

    // Remove any glow
    UTIL_SetRenderMode( pPlayer, kRenderFxNone, Vector(255, 255, 255), kRenderNormal, 255 );

    g_bIsHuman[idx] = false;
    g_bIsZombie[idx] = true;
    g_iClassType[idx] = ZP_ZOMBIE_DEFAULT;

    ZP_ResetExtraStates( idx );

    g_bNightvision[idx] = true;

    g_iAliveHumans--;
    g_iAliveZombies++;

    // Set up health
    pPlayer.pev.health = zombieClass.m_flHealth;
    pPlayer.pev.max_health = zombieClass.m_flHealth;
    pPlayer.pev.armorvalue = 0.0f;

    g_flZombieIdle[idx] = g_Engine.time + RandomFloat(50.0f, 70.0f);

    if ( g_bZombieEscape )
    {
        pPlayer.pev.health = pPlayer.pev.max_health = pPlayer.pev.health * ZP_ZE_ZOMBIE_HP_MULTI;
    }
    else if ( g_iAliveZombies == 1 )
    {
        pPlayer.pev.health = pPlayer.pev.max_health = pPlayer.pev.health * ZP_ZOMBIE_FIRST_HP_MULTI;

        if ( g_iGameMode == ZP_MODE_SINGLE_INFECTION || g_iGameMode == ZP_MODE_MULTIPLE_INFECTION )
        {
            g_bFirstZombie[idx] = true;
        }
    }

    if ( pInflictor !is null )
    {
        if ( !bInfectGrenade )
        {
            UTIL_HudMessageAll( "" + string(pPlayer.pev.netname) + "'s brains has been eaten by " + string(pInflictor.pev.netname) + "...",
                                255, 0, 0, HUD_INFECT_X, HUD_INFECT_Y, 0, 0.0f, 5.0f, 1.0f, 1.0f, HUD_CHAN_INFECT );
        }

        g_iAmmopacks[ pInflictor.entindex() ] += ZP_ZOMBIE_INFECT_REWARD;

        // If zombie class is Leech Zombie, then give to inflictor reward HP for infection
        if ( g_iCurrentZombieClass[ pInflictor.entindex() ] == ZP_CLASS_LEECH_ZOMBIE )
        {
            CZombieClass@ inflictorClass = g_zombieClasses[ g_iCurrentZombieClass[ pInflictor.entindex() ] ];

            float newHealth = pInflictor.pev.health + inflictorClass.m_flUserData;

            if ( newHealth > pInflictor.pev.max_health )
                pInflictor.pev.max_health = newHealth;
            
            pInflictor.pev.health = newHealth;
        }
    }
    else
    {
        if ( !bSilentMode )
            UTIL_HudMessageAll( "" + string(pPlayer.pev.netname) + "'s brains has been eaten...", 255, 0, 0, HUD_INFECT_X, HUD_INFECT_Y, 0, 0.0f, 5.0f, 1.0f, 1.0f, HUD_CHAN_INFECT );
    }

    if ( !bInfectGrenade )
        g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_VOICE, UTIL_GetRandomStringFromArray( ZP_ZOMBIE_INFECT_SND ), 1.0f, ATTN_NORM, 0, PITCH_NORM );
    
    ZP_InfectionEffects( pPlayer );

    UTIL_UpdateScoreInfo( pPlayer.edict() );
}

//-----------------------------------------------------------------------------
// Purpose: make as Survivor
//-----------------------------------------------------------------------------

void ZP_MakeSurvivor(CBasePlayer@ pPlayer)
{
    if ( g_bDebug ) zp_log("ZP_MakeSurvivor()");

    int idx = pPlayer.entindex();

    // Make the Player pickup a weapon without delay
    pPlayer.SetItemPickupTimes( 0.0f );

    pPlayer.SetClassification( ZP_TEAM_HUMAN );
    pPlayer.RemoveAllItems( false );

    ZP_ResetPlayerModel( pPlayer );

    // Glow
    UTIL_SetRenderMode( pPlayer, kRenderFxGlowShell, Vector(0, 0, 255), kRenderNormal, 25 );

    // Give Survivor items
    pPlayer.GiveNamedItem(ZP_SURVIVOR_WEAPON);
    pPlayer.GiveNamedItem("weapon_crowbar");

    pPlayer.pev.health = ZP_SURVIVOR_HEALTH;
    pPlayer.pev.max_health = ZP_SURVIVOR_HEALTH;

    pPlayer.pev.armorvalue = ZP_HUMAN_START_ARMOR;
    pPlayer.pev.armortype = ZP_HUMAN_MAX_ARMOR;

    g_bIsHuman[idx] = true;
    g_bIsZombie[idx] = false;
    g_bAlive[idx] = true;
    g_iClassType[idx] = ZP_HUMAN_SURVIVOR;

    ZP_ResetExtraStates( idx );

    g_bAura[idx] = true;
    g_bInfiniteClipAmmo[idx] = true;

    UTIL_UpdateScoreInfo( pPlayer.edict() );
}

//-----------------------------------------------------------------------------
// Purpose: make as Sniper
//-----------------------------------------------------------------------------

void ZP_MakeSniper(CBasePlayer@ pPlayer)
{
    if ( g_bDebug ) zp_log("ZP_MakeSniper()");

    int idx = pPlayer.entindex();

    // Make the Player pickup a weapon without delay
    pPlayer.SetItemPickupTimes( 0.0f );

    pPlayer.SetClassification( ZP_TEAM_HUMAN );
    pPlayer.RemoveAllItems( false );

    ZP_ResetPlayerModel( pPlayer );

    // Glow
    UTIL_SetRenderMode( pPlayer, kRenderFxGlowShell, Vector(0, 255, 0), kRenderNormal, 25 );

    // Give Sniper items
    pPlayer.GiveNamedItem("weapon_sniperrifle");
    pPlayer.GiveNamedItem("weapon_crowbar");

    pPlayer.pev.health = ZP_SNIPER_HEALTH;
    pPlayer.pev.max_health = ZP_SNIPER_HEALTH;

    pPlayer.pev.armorvalue = ZP_HUMAN_START_ARMOR;
    pPlayer.pev.armortype = ZP_HUMAN_MAX_ARMOR;

    g_bIsHuman[idx] = true;
    g_bIsZombie[idx] = false;
    g_bAlive[idx] = true;
    g_iClassType[idx] = ZP_HUMAN_SNIPER;

    ZP_ResetExtraStates( idx );

    g_bAura[idx] = true;
    g_bInfiniteClipAmmo[idx] = true;

    UTIL_UpdateScoreInfo( pPlayer.edict() );
}

//-----------------------------------------------------------------------------
// Purpose: make as Nemesis
//-----------------------------------------------------------------------------

void ZP_MakeNemesis(CBasePlayer@ pPlayer)
{
    if ( g_bDebug ) zp_log("ZP_MakeNemesis()");

    int idx = pPlayer.entindex();

    ZP_SavePlayerModel( pPlayer );

    // Make the Player pickup a weapon without delay
    pPlayer.SetItemPickupTimes( 0.0f );

    pPlayer.SetClassification( ZP_TEAM_ZOMBIE );
    pPlayer.SetOverriddenPlayerModel( ZP_NEMESIS_MODEL );
    pPlayer.RemoveAllItems( false );

    // Turn off flashlight
    if ( pPlayer.FlashlightIsOn() )
    {
        pPlayer.FlashlightTurnOff();
    }

    // Glow
    UTIL_SetRenderMode( pPlayer, kRenderFxGlowShell, Vector(255, 0, 0), kRenderNormal, 25 );

    // Give melee weapon
    pPlayer.GiveNamedItem("weapon_executioner_axe");
    pPlayer.GiveNamedItem("weapon_jumpgrenade");

    pPlayer.SelectItem("weapon_executioner_axe");

    pPlayer.pev.health = ZP_NEMESIS_HEALTH;
    pPlayer.pev.max_health = ZP_NEMESIS_HEALTH;

    pPlayer.pev.armorvalue = 0.0f;

    g_bIsHuman[idx] = false;
    g_bIsZombie[idx] = true;
    g_iClassType[idx] = ZP_ZOMBIE_NEMESIS;

    ZP_ResetExtraStates( idx );

    g_bNightvision[idx] = true;
    g_bAura[idx] = true;

    g_iAliveHumans--;
    g_iAliveZombies++;

    ZP_InfectionEffects( pPlayer );

    UTIL_UpdateScoreInfo( pPlayer.edict() );
}

//-----------------------------------------------------------------------------
// Purpose: make as Assassin
//-----------------------------------------------------------------------------

void ZP_MakeAssassin(CBasePlayer@ pPlayer)
{
    if ( g_bDebug ) zp_log("ZP_MakeAssassin()");

    int idx = pPlayer.entindex();

    ZP_SavePlayerModel( pPlayer );

    // Make the Player pickup a weapon without delay
    pPlayer.SetItemPickupTimes( 0.0f );

    pPlayer.SetClassification( ZP_TEAM_ZOMBIE );
    pPlayer.SetOverriddenPlayerModel( ZP_ASSASSIN_MODEL );
    pPlayer.RemoveAllItems( false );

    // Turn off flashlight
    if ( pPlayer.FlashlightIsOn() )
    {
        pPlayer.FlashlightTurnOff();
    }

    // Glow
    UTIL_SetRenderMode( pPlayer, kRenderFxGlowShell, Vector(255, 255, 0), kRenderNormal, 25 );

    // Give claws
    pPlayer.GiveNamedItem("weapon_zombieknife");

    pPlayer.pev.health = ZP_ASSASSIN_HEALTH;
    pPlayer.pev.max_health = ZP_ASSASSIN_HEALTH;

    pPlayer.pev.armorvalue = 0.0f;

    g_bIsHuman[idx] = false;
    g_bIsZombie[idx] = true;
    g_iClassType[idx] = ZP_ZOMBIE_ASSASSIN;

    ZP_ResetExtraStates( idx );

    g_bNightvision[idx] = true;
    g_bAura[idx] = true;

    g_iAliveHumans--;
    g_iAliveZombies++;

    ZP_InfectionEffects( pPlayer );

    UTIL_UpdateScoreInfo( pPlayer.edict() );
}

//-----------------------------------------------------------------------------
// Purpose: deploy default items for a Human
//-----------------------------------------------------------------------------

void ZP_DeployHumanItems(CBasePlayer@ pPlayer)
{
    if ( g_bDebug ) zp_log("ZP_DeployHumanItems()");

    // Make the Player pickup a weapon without delay
    pPlayer.SetItemPickupTimes( 0.0f );

    // Give default items to a Human
    pPlayer.GiveNamedItem("weapon_firegrenade");
    pPlayer.GiveNamedItem("weapon_frostgrenade");
    pPlayer.GiveNamedItem("weapon_flaregrenade");
    pPlayer.GiveNamedItem("weapon_crowbar");

    if ( g_bDebug )
    {
        pPlayer.GiveNamedItem("weapon_9mmhandgun");
        pPlayer.GiveNamedItem("weapon_357");
        pPlayer.GiveNamedItem("weapon_uzi");
        pPlayer.GiveNamedItem("weapon_eagle");
        pPlayer.GiveNamedItem("weapon_9mmAR");
        pPlayer.GiveNamedItem("weapon_shotgun");
        pPlayer.GiveNamedItem("weapon_m16");
        pPlayer.GiveNamedItem("weapon_crossbow");
        pPlayer.GiveNamedItem("weapon_sniperrifle");
        pPlayer.GiveNamedItem("weapon_m249");
        pPlayer.GiveNamedItem("weapon_holygrenade");
        pPlayer.GiveNamedItem("weapon_force_field_grenade");
    }

    pPlayer.SelectItem("weapon_crowbar");
}

//-----------------------------------------------------------------------------
// Purpose: deploy default items for a Zombie
//-----------------------------------------------------------------------------

void ZP_DeployZombieItems(CBasePlayer@ pPlayer)
{
    if ( g_bDebug ) zp_log("ZP_DeployZombieItems()");

    // Make the Player pickup a weapon without delay
    pPlayer.SetItemPickupTimes( 0.0f );

    // Give default items to a Zombie
    pPlayer.GiveNamedItem("weapon_zombieknife");
    pPlayer.GiveNamedItem("weapon_jumpgrenade");

    if ( g_bDebug )
    {
        pPlayer.GiveNamedItem("weapon_infectgrenade");
    }

    pPlayer.SelectItem("weapon_zombieknife");
}

//-----------------------------------------------------------------------------
// Purpose: infection effects
//-----------------------------------------------------------------------------

void ZP_InfectionEffects(CBasePlayer@ pPlayer)
{
    int idx = pPlayer.entindex();
    Vector vecOrigin = pPlayer.pev.origin;

    // Is it necessary? lol
    if ( !g_bFrozen[idx] )
	{
        NetworkMessage message( MSG_ONE_UNRELIABLE, NetworkMessages::ScreenFade, pPlayer.edict() );
            message.WriteShort( UNIT_SECOND ); // duration
            message.WriteShort( 0 ); // hold time
            message.WriteShort( FFADE_IN ); // fade type
            if ( g_iClassType[idx] == ZP_ZOMBIE_NEMESIS )
            {
                message.WriteByte( ZP_NVG_NEMESIS_COLOR_R ); // r
                message.WriteByte( ZP_NVG_NEMESIS_COLOR_G ); // g
                message.WriteByte( ZP_NVG_NEMESIS_COLOR_B ); // b
            }
            else if ( g_iClassType[idx] == ZP_ZOMBIE_ASSASSIN )
            {
                message.WriteByte( ZP_NVG_ASSASSIN_COLOR_R );
                message.WriteByte( ZP_NVG_ASSASSIN_COLOR_G );
                message.WriteByte( ZP_NVG_ASSASSIN_COLOR_B );
            }
            else
            {
                message.WriteByte( ZP_NVG_ZOMBIE_COLOR_R );
                message.WriteByte( ZP_NVG_ZOMBIE_COLOR_G );
                message.WriteByte( ZP_NVG_ZOMBIE_COLOR_B );
            }
            message.WriteByte( 255 ); // alpha
        message.End();
	}
    
    {
        NetworkMessage message( MSG_ONE_UNRELIABLE, NetworkMessages::ScreenShake, pPlayer.edict() );
            message.WriteShort( UNIT_SECOND * 4 ); // amplitude
            message.WriteShort( UNIT_SECOND * 2 ); // duration
            message.WriteShort( int16(UNIT_SECOND * 10) ); // frequency
        message.End();
    }
    
    {
        NetworkMessage message( MSG_ONE_UNRELIABLE, NetworkMessages::Damage, pPlayer.edict() );
            message.WriteByte( 0 ); // damage save
            message.WriteByte( 0 ); // damage take
            message.WriteLong( DMG_POISON ); // damage type - DMG_RADIATION / DMG_POISON
            message.WriteCoord( 0 ); // x
            message.WriteCoord( 0 ); // y
            message.WriteCoord( 0 ); // z
        message.End();
    }

    {
        NetworkMessage message( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecOrigin, null );
            message.WriteByte( TE_IMPLOSION ); // TE id
            message.WriteCoord( vecOrigin.x ); // x
            message.WriteCoord( vecOrigin.y ); // y
            message.WriteCoord( vecOrigin.z ); // z
            message.WriteByte( 128 ); // radius
            message.WriteByte( 20 ); // count
            message.WriteByte( 3 ); // duration
        message.End();
    }
        
    {
        NetworkMessage message( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecOrigin, null );
            message.WriteByte( TE_PARTICLEBURST ); // TE id
            message.WriteCoord( vecOrigin.x ); // x
            message.WriteCoord( vecOrigin.y ); // y
            message.WriteCoord( vecOrigin.z ); // z
            message.WriteShort( 50 ); // radius
            message.WriteByte( 70 ); // color
            message.WriteByte( 3 ); // duration (will be randomized a bit)
        message.End();
    }
	
    {
        NetworkMessage message( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecOrigin, null );
            message.WriteByte( TE_DLIGHT ); // TE id
            message.WriteCoord( vecOrigin.x ); // x
            message.WriteCoord( vecOrigin.y ); // y
            message.WriteCoord( vecOrigin.z ); // z
            message.WriteByte( 20 ); // radius
            message.WriteByte( 0 ); // r
            message.WriteByte( 150. ); // g
            message.WriteByte( 0 ); // b
            // FIXME
            // message.WriteByte( ZP_NVG_ZOMBIE_COLOR_R ); // r
            // message.WriteByte( ZP_NVG_ZOMBIE_COLOR_G ); // g
            // message.WriteByte( ZP_NVG_ZOMBIE_COLOR_B ); // b
            message.WriteByte( 2 ); // life
            message.WriteByte( 0 ); // decay rate
        message.End();
    }
}

//-----------------------------------------------------------------------------
// Purpose: play a pain sound on Zombie
//-----------------------------------------------------------------------------

void ZP_PlayPainSound(CBasePlayer@ pPlayer, int iClass)
{
    if ( iClass == ZP_ZOMBIE_DEFAULT )
    {
        g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_VOICE, UTIL_GetRandomStringFromArray( ZP_ZOMBIE_PAIN_SND ), 1.0f, ATTN_NORM, 0, PITCH_NORM );
    }
    else if ( iClass == ZP_ZOMBIE_NEMESIS )
    {
        g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_VOICE, UTIL_GetRandomStringFromArray( ZP_NEMESIS_PAIN_SND ), 1.0f, ATTN_NORM, 0, PITCH_NORM );
    }
    else // Assassin
    {
        g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_VOICE, UTIL_GetRandomStringFromArray( ZP_ASSASSIN_PAIN_SND ), 1.0f, ATTN_NORM, 0, PITCH_NORM );
    }
}

//-----------------------------------------------------------------------------
// Purpose: set Zombie on fire
//-----------------------------------------------------------------------------

void ZP_SetOnFire(CBasePlayer@ pPlayer, bool bAddBurningDuration = true)
{
    int idx = pPlayer.entindex();

    if ( g_bIsZombie[idx] && g_bAlive[idx] && !g_bNoDamage[idx] )
    {
        // Heat icon
        NetworkMessage message( MSG_ONE_UNRELIABLE, NetworkMessages::Damage, pPlayer.edict() );
            message.WriteByte( 0 ); // damage save
            message.WriteByte( 0 ); // damage take
            message.WriteLong( DMG_BURN ); // damage type
            message.WriteCoord( 0 ); // x
            message.WriteCoord( 0 ); // y
            message.WriteCoord( 0 ); // z
        message.End();

        // Create schedule if not burning
        if ( g_flBurningDuration[idx] == 0.0f )
            g_Scheduler.SetTimeout("ZP_FireGrenadeBurningTask", 0.2f, idx, EHandle(pPlayer));

        // Nemesis and Assassin are fire resistant
        if ( g_iClassType[idx] != ZP_ZOMBIE_DEFAULT )
        {
            if ( bAddBurningDuration )
                g_flBurningDuration[idx] += ZP_NADE_FIRE_DURATION;
            else
                g_flBurningDuration[idx] = ZP_NADE_FIRE_DURATION;
        }
        else
        {
            if ( bAddBurningDuration )
                g_flBurningDuration[idx] += ZP_NADE_FIRE_DURATION * 5.0f;
            else
                g_flBurningDuration[idx] = ZP_NADE_FIRE_DURATION * 5.0f;

            // Play pain sound
            g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_VOICE, UTIL_GetRandomStringFromArray( ZP_GRENADE_FIRE_PLAYER_SND ), 1.0f, ATTN_NORM, 0, PITCH_NORM );
        }
    }
}

//-----------------------------------------------------------------------------
// Purpose: fire grenade explosion
//-----------------------------------------------------------------------------

void ZP_FireGrenadeExplosion(CBaseEntity@ pGrenade)
{
    if ( g_bDebug ) zp_log("ZP_FireGrenadeExplosion()");

    Vector vecOrigin = pGrenade.pev.origin;

    UTIL_CreateBlastRing( vecOrigin,
                        200, 100, 0, // smallest ring [rgb]
                        200, 50, 0, // medium ring [rgb]
                        200, 0, 0 ); // largest ring [rgb]

    g_SoundSystem.PlaySound( pGrenade.edict(), CHAN_WEAPON, UTIL_GetRandomStringFromArray( ZP_GRENADE_FIRE_EXPLODE_SND ), 1.0f, ATTN_NORM, 0, PITCH_NORM );

    if ( g_iGameState != ZP_STATE_GAME_STARTED )
        return;
    
    edict_t@ pEdictOwner = pGrenade.pev.owner;

    if ( pEdictOwner is null )
        return;
    
    CBaseEntity@ pOwner = g_EntityFuncs.Instance( pEdictOwner );

    if ( pOwner is null )
        return;

    CBasePlayer@ pPlayer = cast<CBasePlayer@>( pOwner );

    if ( pPlayer is null )
        return;
    
    CBaseEntity@ pVictim = null;

    while ( (@pVictim = g_EntityFuncs.FindEntityInSphere(pVictim, vecOrigin, ZP_NADE_EXPLOSION_RADIUS, "player", "classname")) !is null )
    {
        ZP_SetOnFire( cast<CBasePlayer@>( pVictim ) );
    }
}

void ZP_FireGrenadeBurningTask(int idx, EHandle hPlayer)
{
    if ( g_bAlive[idx] && g_bIsZombie[idx] )
    {
        CBasePlayer@ pPlayer = cast<CBasePlayer@>(hPlayer.GetEntity());

        if ( pPlayer !is null )
        {
            Vector vecOrigin = pPlayer.pev.origin;

            if ( g_bNoDamage[idx] || (pPlayer.pev.flags & FL_INWATER != 0) || g_flBurningDuration[idx] < 1.0f )
            {
                if ( g_bDebug ) zp_log("ZP_FireGrenadeBurningTask(): END");

                // Smoke sprite
                NetworkMessage message( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecOrigin, null );
                    message.WriteByte( TE_SMOKE ); // TE id
                    message.WriteCoord( vecOrigin.x ); // x
                    message.WriteCoord( vecOrigin.y ); // y
                    message.WriteCoord( vecOrigin.z - 50.0f ); // z
                    message.WriteShort( g_smokeSpr ); // sprite
                    message.WriteByte( RandomInt(15, 20) ); // scale
                    message.WriteByte( RandomInt(10, 20) ); // framerate
                message.End();

                g_flBurningDuration[idx] = 0.0f;
                return;
            }

            // Randomly play burning zombie scream sounds (not for nemesis and assassin)
            if ( g_iClassType[idx] == ZP_ZOMBIE_DEFAULT && RandomInt(1, 8) == 1 )
            {
                g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_VOICE, UTIL_GetRandomStringFromArray( ZP_GRENADE_FIRE_PLAYER_SND ), 1.0f, ATTN_NORM, 0, PITCH_NORM );
            }

            // Fire slow down, unless nemesis and assassin
            if ( g_iClassType[idx] == ZP_ZOMBIE_DEFAULT && (pPlayer.pev.flags & FL_ONGROUND != 0) && ZP_NADE_FIRE_SLOWDOWN > 0.0f )
            {
                pPlayer.pev.velocity = pPlayer.pev.velocity * ZP_NADE_FIRE_SLOWDOWN;
            }

            // Take damage from the fire
            if ( pPlayer.pev.health - ZP_NADE_FIRE_DAMAGE >= 1.0f )
            {
                pPlayer.pev.health -= ZP_NADE_FIRE_DAMAGE;
            }

            // Flame sprite
            NetworkMessage message( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecOrigin, null );
                message.WriteByte( TE_SPRITE ); // TE id
                message.WriteCoord( vecOrigin.x + RandomInt(-5, 5) ); // x
                message.WriteCoord( vecOrigin.y + RandomInt(-5, 5) ); // y
                message.WriteCoord( vecOrigin.z + RandomInt(-10, 10) ); // z
                message.WriteShort( g_flameSpr ); // sprite
                message.WriteByte( RandomInt(5, 10) ); // scale
                message.WriteByte( 200 ); // brightness
            message.End();

            g_flBurningDuration[idx] -= 1.0f;

            // Create schedule for unfreeze
            g_Scheduler.SetTimeout("ZP_FireGrenadeBurningTask", 0.2f, idx, hPlayer);
        }
        else
        {
            g_flBurningDuration[idx] = 0.0f;
        }
    }
    else
    {
        g_flBurningDuration[idx] = 0.0f;
    }
}

//-----------------------------------------------------------------------------
// Purpose: frost grenade explosion
//-----------------------------------------------------------------------------

void ZP_FrostGrenadeExplosion(CBaseEntity@ pGrenade)
{
    if ( g_bDebug ) zp_log("ZP_FrostGrenadeExplosion()");

    Vector vecOrigin = pGrenade.pev.origin;

    UTIL_CreateBlastRing( vecOrigin,
                        0, 100, 200, // smallest ring [rgb]
                        0, 100, 200, // medium ring [rgb]
                        0, 100, 200 ); // largest ring [rgb]

    g_SoundSystem.PlaySound( pGrenade.edict(), CHAN_WEAPON, UTIL_GetRandomStringFromArray( ZP_GRENADE_FROST_EXPLODE_SND ), 1.0f, ATTN_NORM, 0, PITCH_NORM );

    if ( g_iGameState != ZP_STATE_GAME_STARTED )
        return;
    
    edict_t@ pEdictOwner = pGrenade.pev.owner;

    if ( pEdictOwner is null )
        return;
    
    CBaseEntity@ pOwner = g_EntityFuncs.Instance( pEdictOwner );

    if ( pOwner is null )
        return;

    CBasePlayer@ pPlayer = cast<CBasePlayer@>( pOwner );

    if ( pPlayer is null )
        return;
    
    CBaseEntity@ pVictim = null;

    while ( (@pVictim = g_EntityFuncs.FindEntityInSphere(pVictim, vecOrigin, ZP_NADE_EXPLOSION_RADIUS, "player", "classname")) !is null )
    {
        int idx = pVictim.entindex();

        if ( g_bIsZombie[idx] && g_bAlive[idx] )
        {
            if ( g_bFrozen[idx] || g_bNoDamage[idx] )
                continue;
            
            // Nemesis and Assassin can't be frozen
            if ( g_iClassType[idx] != ZP_ZOMBIE_DEFAULT )
            {
                Vector origin = pVictim.pev.origin;

                // Play sound
                g_SoundSystem.PlaySound( pVictim.edict(), CHAN_BODY, UTIL_GetRandomStringFromArray( ZP_GRENADE_FROST_BREAK_SND ), 1.0f, ATTN_NORM, 0, PITCH_NORM );

                // Glass shatter
                NetworkMessage message( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, origin, null );
                    message.WriteByte( TE_BREAKMODEL ); // TE id
                    message.WriteCoord( origin.x ); // x
                    message.WriteCoord( origin.y ); // y
                    message.WriteCoord( origin.z + 24.0f ); // z
                    message.WriteCoord( 16 ); // size x
                    message.WriteCoord( 16 ); // size y
                    message.WriteCoord( 16 ); // size z
                    message.WriteCoord( RandomInt(-50, 50) ); // velocity x
                    message.WriteCoord( RandomInt(-50, 50) ); // velocity y
                    message.WriteCoord( 25 ); // velocity z
                    message.WriteByte( 10 ); // random velocity
                    message.WriteShort( g_glassSpr ); // model
                    message.WriteByte( 10 ); // count
                    message.WriteByte( 25 ); // life
                    message.WriteByte( BREAK_GLASS ); // flags
                message.End();

                continue;
            }

            // Freeze icon
            {
                NetworkMessage message( MSG_ONE_UNRELIABLE, NetworkMessages::Damage, pVictim.edict() );
                    message.WriteByte( 0 ); // damage save
                    message.WriteByte( 0 ); // damage take
                    message.WriteLong( DMG_FREEZE ); // damage type
                    message.WriteCoord( 0 ); // x
                    message.WriteCoord( 0 ); // y
                    message.WriteCoord( 0 ); // z
                message.End();
            }

            // Light blue glow while frozen
            UTIL_SetRenderMode( pVictim, kRenderFxGlowShell, Vector(0, 100, 200), kRenderNormal, 25 );

            // Freeze sound
            g_SoundSystem.PlaySound( pVictim.edict(), CHAN_BODY, UTIL_GetRandomStringFromArray( ZP_GRENADE_FROST_PLAYER_SND ), 1.0f, ATTN_NORM, 0, PITCH_NORM );

            // Add a blue tint to their screen
            {
                NetworkMessage message( MSG_ONE, NetworkMessages::ScreenFade, pVictim.edict() );
                    message.WriteShort( 0 ); // duration
                    message.WriteShort( 0 ); // hold time
                    message.WriteShort( FFADE_STAYOUT ); // fade type
                    message.WriteByte( 0 ); // red
                    message.WriteByte( 50 ); // green
                    message.WriteByte( 200 ); // blue
                    message.WriteByte( 100 ); // alpha
                message.End();
            }

            // Prevent from jumping
            if ( pVictim.pev.flags & FL_ONGROUND != 0 )
                pVictim.pev.gravity = 999999.9f; // set really high
            else
                pVictim.pev.gravity = 0.000001f; // no gravity
            
            g_bFrozen[idx] = true;

            g_Scheduler.SetTimeout("ZP_FrostGrenadeUnfreezeTask", ZP_NADE_FROST_DURATION, idx, EHandle(pVictim));
        }
    }
}

void ZP_FrostGrenadeUnfreezeTask(int idx, EHandle hPlayer)
{
    if ( g_bDebug ) zp_log("ZP_FrostGrenadeUnfreezeTask()");

    if ( g_bAlive[idx] && g_bFrozen[idx] && g_bIsZombie[idx] )
    {
        CBasePlayer@ pPlayer = cast<CBasePlayer@>(hPlayer.GetEntity());

        if ( pPlayer !is null )
        {
            Vector vecOrigin = pPlayer.pev.origin;

            g_bFrozen[idx] = false;

            // Restore gravity and glowing
            if ( g_bIsZombie[idx] )
            {
                if ( g_iClassType[idx] == ZP_ZOMBIE_DEFAULT )
                {
                    CZombieClass@ zombieClass = g_zombieClasses[ g_iCurrentZombieClass[idx] ];

                    pPlayer.pev.gravity = zombieClass.m_flGravity;
                    UTIL_SetRenderMode( pPlayer, kRenderFxNone, Vector(255, 255, 255), kRenderNormal, 255 );
                }
                else if ( g_iClassType[idx] == ZP_ZOMBIE_NEMESIS )
                {
                    pPlayer.pev.gravity = ZP_NEMESIS_GRAVITY;
                    UTIL_SetRenderMode( pPlayer, kRenderFxGlowShell, Vector(255, 0, 0), kRenderNormal, 25 );
                }
                else // Assassin
                {
                    pPlayer.pev.gravity = ZP_ASSASSIN_GRAVITY;
                    UTIL_SetRenderMode( pPlayer, kRenderFxGlowShell, Vector(255, 255, 0), kRenderNormal, 25 );
                }
            }
            else
            {
                if ( g_iClassType[idx] == ZP_HUMAN_DEFAULT )
                {
                    pPlayer.pev.gravity = ZP_HUMAN_GRAVITY;
                    UTIL_SetRenderMode( pPlayer, kRenderFxNone, Vector(255, 255, 255), kRenderNormal, 255 );
                }
                else if ( g_iClassType[idx] == ZP_HUMAN_SURVIVOR )
                {
                    pPlayer.pev.gravity = ZP_SURVIVOR_GRAVITY;
                    UTIL_SetRenderMode( pPlayer, kRenderFxGlowShell, Vector(0, 0, 255), kRenderNormal, 25 );
                }
                else // Sniper
                {
                    pPlayer.pev.gravity = ZP_SNIPER_GRAVITY;
                    UTIL_SetRenderMode( pPlayer, kRenderFxGlowShell, Vector(0, 255, 0), kRenderNormal, 25 );
                }
            }

            // Gradually remove screen's blue tint
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

            g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_BODY, UTIL_GetRandomStringFromArray( ZP_GRENADE_FROST_BREAK_SND ), 1.0f, ATTN_NORM, 0, PITCH_NORM );

            // Glass shatter
            {
                NetworkMessage message( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecOrigin, null );
                    message.WriteByte( TE_BREAKMODEL ); // TE id
                    message.WriteCoord( vecOrigin.x ); // x
                    message.WriteCoord( vecOrigin.y ); // y
                    message.WriteCoord( vecOrigin.z + 24.0f ); // z
                    message.WriteCoord( 16 ); // size x
                    message.WriteCoord( 16 ); // size y
                    message.WriteCoord( 16 ); // size z
                    message.WriteCoord( RandomInt(-50, 50) ); // velocity x
                    message.WriteCoord( RandomInt(-50, 50) ); // velocity y
                    message.WriteCoord( 25 ); // velocity z
                    message.WriteByte( 10 ); // random velocity
                    message.WriteShort( g_glassSpr ); // model
                    message.WriteByte( 10 ); // count
                    message.WriteByte( 25 ); // life
                    message.WriteByte( BREAK_GLASS ); // flags
                message.End();
            }
        }
        else
        {
            g_bFrozen[idx] = false;
        }
    }
    else
    {
        if ( g_bFrozen[idx] )
        {
            CBasePlayer@ pPlayer = cast<CBasePlayer@>(hPlayer.GetEntity());

            if ( pPlayer !is null )
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
        }

        g_bFrozen[idx] = false;
    }
}

//-----------------------------------------------------------------------------
// Purpose: infection grenade explosion
//-----------------------------------------------------------------------------

void ZP_InfectionGrenadeExplosion(CBaseEntity@ pGrenade)
{
    if ( g_bDebug ) zp_log("ZP_InfectionGrenadeExplosion()");

    Vector vecOrigin = pGrenade.pev.origin;

    UTIL_CreateBlastRing( vecOrigin,
                        0, 200, 0, // smallest ring [rgb]
                        0, 200, 0, // medium ring [rgb]
                        0, 200, 0 ); // largest ring [rgb]
    
    g_SoundSystem.PlaySound( pGrenade.edict(), CHAN_WEAPON, UTIL_GetRandomStringFromArray( ZP_GRENADE_INFECT_EXPLODE_SND ), 1.0f, ATTN_NORM, 0, PITCH_NORM );
    
    if ( g_iGameState != ZP_STATE_GAME_STARTED )
        return;
    
    edict_t@ pEdictOwner = pGrenade.pev.owner;

    if ( pEdictOwner is null )
        return;
    
    CBaseEntity@ pOwner = g_EntityFuncs.Instance( pEdictOwner );

    if ( pOwner is null )
        return;

    CBasePlayer@ pPlayer = cast<CBasePlayer@>( pOwner );

    if ( pPlayer is null )
        return;
    
    CBaseEntity@ pVictim = null;

    while ( (@pVictim = g_EntityFuncs.FindEntityInSphere(pVictim, vecOrigin, ZP_NADE_EXPLOSION_RADIUS, "player", "classname")) !is null )
    {
        int idx = pVictim.entindex();

        if ( g_bIsHuman[idx] && g_bAlive[idx] )
        {
            if ( g_iAliveHumans == 1 || g_iClassType[idx] == ZP_HUMAN_SURVIVOR || g_iClassType[idx] == ZP_HUMAN_SNIPER )
            {
                pVictim.pev.armorvalue = 0.0f;
                pVictim.Killed( pPlayer.pev, GIB_NEVER );
                // pVictim.TakeDamage( pPlayer.pev, pPlayer.pev, pVictim.pev.health + 1.0f, 0 );
                continue;
            }

            ZP_InfectHuman( cast<CBasePlayer@>(pVictim), pPlayer, true );
            g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_VOICE, UTIL_GetRandomStringFromArray( ZP_GRENADE_INFECT_PLAYER_SND ), 1.0f, ATTN_NORM, 0, PITCH_NORM );
        }
    }
}

//-----------------------------------------------------------------------------
// Purpose: holy grenade explosion
//-----------------------------------------------------------------------------

void ZP_HolyGrenadeExplosion(CBaseEntity@ pGrenade)
{
    if ( g_bDebug ) zp_log("ZP_HolyGrenadeExplosion()");
	
    Vector vecOrigin = pGrenade.pev.origin;

    // Explosion sprite
    NetworkMessage message( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecOrigin, null );
        message.WriteByte( TE_EXPLOSION ); // TE id
        message.WriteCoord( vecOrigin.x ); // x
        message.WriteCoord( vecOrigin.y ); // y
        message.WriteCoord( vecOrigin.z ); // z
        message.WriteShort( g_fexploSpr ); // sprite
        message.WriteByte( 50 ); // scale in 0.1's
        message.WriteByte( 30 ); // framerate
        message.WriteByte( 4 ); // flags
    message.End();

    // Blast ring
    UTIL_CreateBlastRing( vecOrigin,
                        255, 215, 0, // smallest ring [rgb]
                        255, 215, 0, // medium ring [rgb]
                        255, 215, 0 ); // largest ring [rgb]
    
    g_SoundSystem.PlaySound( pGrenade.edict(), CHAN_WEAPON, ZP_GRENADE_HOLY_EXPLODE_SND[ 1 ], 1.0f, ATTN_NORM, 0, PITCH_NORM );
    
    if ( g_iGameState != ZP_STATE_GAME_STARTED )
        return;
    
    edict_t@ pEdictOwner = pGrenade.pev.owner;

    if ( pEdictOwner is null )
        return;
    
    CBaseEntity@ pOwner = g_EntityFuncs.Instance( pEdictOwner );

    if ( pOwner is null )
        return;

    CBasePlayer@ pPlayer = cast<CBasePlayer@>( pOwner );

    if ( pPlayer is null )
        return;
    
    float flRemainingHealth;
    CBaseEntity@ pVictim = null;

    while ( (@pVictim = g_EntityFuncs.FindEntityInSphere(pVictim, vecOrigin, ZP_NADE_EXPLOSION_RADIUS, "player", "classname")) !is null )
    {
        int idx = pVictim.entindex();

        if ( g_bIsZombie[idx] && g_bAlive[idx] )
        {
            // pVictim.TakeDamage( pGrenade.pev, pPlayer.pev, ZP_NADE_HOLY_DAMAGE, DMG_BLAST );

            flRemainingHealth = pVictim.pev.health - ZP_NADE_HOLY_DAMAGE;

            if ( flRemainingHealth <= 0.0f )
            {
                pVictim.Killed( pPlayer.pev, GIB_NEVER );
            }
            else
            {
                // idk
                if ( flRemainingHealth < 1.0f )
                    flRemainingHealth = 1.0f;

                pVictim.pev.health = flRemainingHealth;

                ZP_PlayPainSound( cast<CBasePlayer@>( pVictim ), g_iClassType[ idx ] );
            }

            NetworkMessage message2( MSG_ONE_UNRELIABLE, NetworkMessages::Damage, pVictim.edict() );
                message2.WriteByte( 0 ); // damage save
                message2.WriteByte( 255 ); // damage take
                message2.WriteLong( DMG_BLAST ); // damage type
                message2.WriteCoord( vecOrigin.x ); // x
                message2.WriteCoord( vecOrigin.y ); // y
                message2.WriteCoord( vecOrigin.y ); // z
            message2.End();

            // Show damage
            if ( ZP_DAMAGE_INDICATOR )
            {
                UTIL_ShowDamage( cast<CBasePlayer@>( pVictim ), pPlayer, int( ZP_NADE_HOLY_DAMAGE ) );
            }

            pVictim.pev.punchangle.x = -10.0f;
        }
    }
}

//-----------------------------------------------------------------------------
// Purpose: jump grenade explosion
//-----------------------------------------------------------------------------

void ZP_JumpGrenadeExplosion(CBaseEntity@ pGrenade)
{
    if ( g_bDebug ) zp_log("ZP_JumpGrenadeExplosion()");
	
    Vector vecOrigin = pGrenade.pev.origin;

    // Explosion sprite
    NetworkMessage message( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecOrigin, null );
        message.WriteByte( TE_SPRITE ); // TE id
        message.WriteCoord( vecOrigin.x ); // x
        message.WriteCoord( vecOrigin.y ); // y
        message.WriteCoord( vecOrigin.z + 45.0f ); // z
        message.WriteShort( g_zombieBombExploSpr ); // sprite
        message.WriteByte( 35 ); // scale in 0.1's
        message.WriteByte( 186 ); // brightness
    message.End();
    
    g_SoundSystem.PlaySound( pGrenade.edict(), CHAN_WEAPON, ZP_GRENADE_JUMP_EXPLODE_SND[ 0 ], 1.0f, ATTN_NORM, 0, PITCH_NORM );
    
    if ( g_iGameState != ZP_STATE_GAME_STARTED )
        return;
    
    edict_t@ pEdictOwner = pGrenade.pev.owner;

    if ( pEdictOwner is null )
        return;
    
    CBaseEntity@ pOwner = g_EntityFuncs.Instance( pEdictOwner );

    if ( pOwner is null )
        return;

    CBasePlayer@ pPlayer = cast<CBasePlayer@>( pOwner );

    if ( pPlayer is null )
        return;
    
    float flRemainingHealth;
    int owneridx = pPlayer.entindex();
    CBaseEntity@ pVictim = null;

    while ( (@pVictim = g_EntityFuncs.FindEntityInSphere(pVictim, vecOrigin, ZP_NADE_EXPLOSION_RADIUS, "player", "classname")) !is null )
    {
        bool blyat = false;
        int idx = pVictim.entindex();

        if ( g_bIsHuman[idx] && g_bAlive[idx] || ( blyat = ( owneridx == idx && g_bIsZombie[idx] && g_bAlive[idx] ) ) )
        {
            Vector vecNewVelocity = pVictim.pev.origin - vecOrigin;
            float flDistanceFraction = ( 1.0f - ( (pVictim.pev.origin - vecOrigin).Length() / ZP_NADE_EXPLOSION_RADIUS ) );
            float flNewSpeed = ZP_NADE_JUMP_PUSH_FORCE * flDistanceFraction;
            float flDamage = ZP_NADE_JUMP_DAMAGE * flDistanceFraction;
            float fraction = sqrt( flNewSpeed * flNewSpeed / UTIL_VectorLengthSqr( vecNewVelocity ) );

            vecNewVelocity = vecNewVelocity * fraction;

            pVictim.pev.velocity = vecNewVelocity;

            // Shake screen
            NetworkMessage message2( MSG_ONE_UNRELIABLE, NetworkMessages::ScreenShake, pVictim.edict() );
                message2.WriteShort( 32767 ); // ammount | ( 1 << 12 ) * 10 => 40960
                message2.WriteShort( 32767 ); // lasts this long
                message2.WriteShort( 32767 ); // frequency
            message2.End();

            flRemainingHealth = pVictim.pev.health - flDamage;

            if ( flRemainingHealth <= 0.0f )
            {
                pVictim.Killed( pPlayer.pev, GIB_NEVER );
            }
            else
            {
                // idk
                if ( flRemainingHealth < 1.0f )
                    flRemainingHealth = 1.0f;

                pVictim.pev.health = flRemainingHealth;
            }

            NetworkMessage message3( MSG_ONE_UNRELIABLE, NetworkMessages::Damage, pVictim.edict() );
                message3.WriteByte( 0 ); // damage save
                message3.WriteByte( 255 ); // damage take
                message3.WriteLong( DMG_CRUSH ); // damage type
                message3.WriteCoord( vecOrigin.x ); // x
                message3.WriteCoord( vecOrigin.y ); // y
                message3.WriteCoord( vecOrigin.y ); // z
            message3.End();

            // Show damage
            if ( ZP_DAMAGE_INDICATOR && !blyat )
            {
                UTIL_ShowDamage( cast<CBasePlayer@>( pVictim ), pPlayer, int( flDamage ) );
            }

            pVictim.pev.punchangle.x = -12.0f * flDistanceFraction;
        }
    }
}

//-----------------------------------------------------------------------------
// Purpose: force field grenade explosion
//-----------------------------------------------------------------------------

void ZP_ForceFieldGrenadeExplosion(CBaseEntity@ pGrenade)
{
    if ( g_bDebug ) zp_log("ZP_ForceFieldGrenadeExplosion()");

    CBaseEntity@ pForceField = FORCE_FIELD::SpawnForceField( pGrenade.pev.owner, pGrenade.pev.origin );
    
    if ( pForceField !is null )
    {
        int iOwner = ( pGrenade.pev.owner is null ) ? 0 : g_EngineFuncs.IndexOfEdict( pGrenade.pev.owner );
        bool bOwnerIsPlayer = ( iOwner > 0 && iOwner <= g_Engine.maxClients );

        g_pForceFields.insertLast( pForceField.edict() );

        if ( !bOwnerIsPlayer || ( bOwnerIsPlayer && !g_bOneRoundForceField[ iOwner ] ) )
            g_Scheduler.SetTimeout( "UTIL_RemoveEntityByEHandle", ZP_FORCE_FIELD_DURATION, EHandle( pForceField ) );
    }
}

//-----------------------------------------------------------------------------
// Purpose: force field grenade explosion
//-----------------------------------------------------------------------------

bool ZP_ExplodeGrenade(CBaseEntity@ pEntity, int iNadeType, bool bModeImpact)
{
    // When grenades don't explode in one moment, then you need to add them in that check condition
    if ( iNadeType == 3 || iNadeType == 6 ) // flare grenade / holy grenade
    {
        if ( bModeImpact )
        {
            TraceResult traceResult = g_Utility.GetGlobalTrace();

            // Wait for another impact, can't place grenade on an entity that may move
            if ( traceResult.pHit !is null && !g_EntityFuncs.Instance( traceResult.pHit ).IsBSPModel() )
                return false;

            // Did impact, act as normal
            pEntity.pev.iuser2 = NADE_MODE_NORMAL;

            // Skip check ground condition
            pEntity.pev.iuser3 = 1;

            ZP_PROJECTILE::CZpProjectile@ pZpProjectile = cast<ZP_PROJECTILE::CZpProjectile@>( CastToScriptClass( pEntity ) );

            pEntity.pev.dmgtime = g_Engine.time;

            // Freeze grenade on the surface
            pEntity.pev.movetype = MOVETYPE_NONE;
            pEntity.pev.solid = SOLID_NOT;

            // pEntity.pev.origin = traceResult.vecEndPos - traceResult.vecPlaneNormal * 8;
            pEntity.pev.origin = traceResult.vecEndPos;
            pEntity.pev.angles = Math.VecToAngles( traceResult.vecPlaneNormal );
            pEntity.pev.velocity = g_vecZero;

            // pEntity.pev.vuser2 = traceResult.vecEndPos;

            pZpProjectile.SetTouch( null );

            return false;
        }
        else if ( iNadeType == 3 ) // flare grenade
        {
            float flDuration = pEntity.pev.fuser1;

            if ( flDuration > 0.0f ) // Started lighting
            {
                // Lighting ended
                if ( flDuration == 1.0f )
                {
                    return true;
                }

                Vector vecOrigin = pEntity.pev.origin;
                Vector vecColor = pEntity.pev.vuser1;
                
                // Lighting
                NetworkMessage message( MSG_PAS, NetworkMessages::SVC_TEMPENTITY, vecOrigin, null );
                    message.WriteByte( TE_DLIGHT ); // TE id
                    message.WriteCoord( vecOrigin.x ); // x
                    message.WriteCoord( vecOrigin.y ); // y
                    message.WriteCoord( vecOrigin.z ); // z
                    message.WriteByte( ZP_NADE_FLARE_SIZE ); // radius
                    message.WriteByte( int(vecColor.x) ); // r
                    message.WriteByte( int(vecColor.y) ); // g
                    message.WriteByte( int(vecColor.z) ); // b
                    message.WriteByte( 51 ); // life
                    message.WriteByte( (flDuration < 2.0f) ? 3 : 0 ); // decay rate
                message.End();

                // // uhhh
                // NetworkMessage message( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
                //     message.WriteByte( TE_ELIGHT ); // TE id
                //     message.WriteShort( pEntity.entindex() ); // entity
                //     message.WriteCoord( vecOrigin.x ); // x
                //     message.WriteCoord( vecOrigin.y ); // y
                //     message.WriteCoord( vecOrigin.z ); // z
                //     message.WriteCoord( 10 * ZP_NADE_FLARE_SIZE ); // radius
                //     message.WriteByte( int(vecColor.x) ); // r
                //     message.WriteByte( int(vecColor.y) ); // g
                //     message.WriteByte( int(vecColor.z) ); // b
                //     message.WriteByte( 51 ); // life
                //     message.WriteCoord( (flDuration < 2.0f) ? 3 : 0 ); // decay rate
                // message.End();

                // Sparks
                NetworkMessage message2( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecOrigin, null );
                    message2.WriteByte( TE_SPARKS ); // TE id
                    message2.WriteCoord( vecOrigin.x ); // x
                    message2.WriteCoord( vecOrigin.y ); // y
                    message2.WriteCoord( vecOrigin.z ); // z
                message2.End();

                pEntity.pev.fuser1 -= 1.0f;
                pEntity.pev.dmgtime += 5.0f;
            }
            else if ( (pEntity.pev.flags & FL_ONGROUND != 0 || pEntity.pev.iuser3 == 1) && UTIL_VectorLengthSqr(pEntity.pev.velocity) < 10.0f * 10.0f ) // Wait till grenade will stop on the ground
            {
                g_SoundSystem.PlaySound( pEntity.edict(), CHAN_WEAPON, UTIL_GetRandomStringFromArray( ZP_GRENADE_FLARE_SND ), 1.0f, ATTN_NORM, 0, PITCH_NORM );

                // Freeze grenade on the surface
                pEntity.pev.movetype = MOVETYPE_NONE;
                pEntity.pev.solid = SOLID_NOT;

                pEntity.pev.fuser1 = Math.Floor( 1.0f + ZP_NADE_FLARE_DURATION / 5.0f );
                pEntity.pev.dmgtime += 0.1f;
            }
            else // Wait a bit more
            {
                pEntity.pev.dmgtime += 0.5f;
            }

            // Return 'false' to keep grenade alive a bit more
            return false;
        }
        else if ( iNadeType == 6 ) // holy grenade
        {
            float flDuration = pEntity.pev.fuser1;

            if ( flDuration > 0.0f ) // Started lighting
            {
                // Lighting ended
                if ( flDuration == 1.0f )
                {
                    ZP_HolyGrenadeExplosion( pEntity );
                    return true;
                }
                else if ( flDuration == 3.0f )
                {
                    g_SoundSystem.PlaySound( pEntity.edict(), CHAN_WEAPON, ZP_GRENADE_HOLY_EXPLODE_SND[ 0 ], 1.0f, ATTN_NORM, 0, PITCH_NORM );
                }

                pEntity.pev.fuser1 -= 0.5f;
                pEntity.pev.dmgtime += 0.5f;
            }
            else if ( (pEntity.pev.flags & FL_ONGROUND != 0 || pEntity.pev.iuser3 == 1) && UTIL_VectorLengthSqr(pEntity.pev.velocity) < 10.0f * 10.0f ) // Wait till grenade will stop on the ground
            {
                // Freeze grenade on the surface
                pEntity.pev.movetype = MOVETYPE_NONE;
                pEntity.pev.solid = SOLID_NOT;

                pEntity.pev.fuser1 = 3.5f;
                pEntity.pev.dmgtime += 0.1f;
            }
            else // Wait a bit more
            {
                pEntity.pev.dmgtime += 0.5f;
            }

            // Return 'false' to keep grenade alive a bit more
            return false;
        }
    }
    else
    {
        if ( iNadeType == 1 ) // napalm grenade
        {
            ZP_FireGrenadeExplosion( pEntity );
        }
        else if ( iNadeType == 2 ) // frost grenade
        {
            ZP_FrostGrenadeExplosion( pEntity );
        }
        else if ( iNadeType == 4 ) // infection grenade
        {
            ZP_InfectionGrenadeExplosion( pEntity );
        }
        else if ( iNadeType == 5 ) // force field grenade
        {
            ZP_ForceFieldGrenadeExplosion( pEntity );
        }
        else if ( iNadeType == 7 ) // jump grenade
        {
            ZP_JumpGrenadeExplosion( pEntity );
        }
    }

    return true;
}

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//
//                              Custom Hooks
//
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// OnProjectileSpawn Hook
//-----------------------------------------------------------------------------

void OnProjectileSpawn(CBaseMonster@ pMonster)
{
    if ( g_bDebug ) zp_log("OnProjectileSpawn(): " + pMonster.pev.classname);

    CBaseEntity@ pEntity = cast<CBaseEntity@>(pMonster);
    int iNadeType = pEntity.pev.iuser1 & ~1024; // 1024 - zombie flag team

    if ( iNadeType == 1 ) // napalm grenade
    {
        UTIL_SetRenderMode( pEntity, kRenderFxGlowShell, Vector(200, 0, 0), kRenderNormal, 16 );
        UTIL_SetTrail( pEntity, g_trailSpr, 200, 0, 0, 10, 200, 10 );
    }
    else if ( iNadeType == 2 ) // frost grenade
    {
        UTIL_SetRenderMode( pEntity, kRenderFxGlowShell, Vector(0, 100, 200), kRenderNormal, 16 );
        UTIL_SetTrail( pEntity, g_trailSpr, 0, 100, 200, 10, 200, 10 );
    }
    else if ( iNadeType == 3 ) // flare grenade
    {
        Vector vecColor;

		switch ( ZP_NADE_FLARE_COLOR )
		{
			case 1: // red
			{
				vecColor.x = RandomInt(50, 255); // r
				vecColor.y = 0; // g
				vecColor.z = 0; // b
                break;
			}
			case 2: // green
			{
				vecColor.x = 0; // r
				vecColor.y = RandomInt(50, 255); // g
				vecColor.z = 0; // b
                break;
			}
			case 3: // blue
			{
				vecColor.x = 0; // r
				vecColor.y = 0; // g
				vecColor.z = RandomInt(50, 255); // b
                break;
			}
			case 4: // random (all colors)
			{
				vecColor.x = RandomInt(70, 200); // r
				vecColor.y = RandomInt(70, 200); // g
				vecColor.z = RandomInt(70, 200); // b
                break;
			}
			case 5: // random (r,g,b)
			{
				switch (RandomInt(1, 3))
				{
					case 1: // red
					{
						vecColor.x = RandomInt(50, 255); // r
						vecColor.y = 0; // g
						vecColor.z = 0; // b
                        break;
					}
					case 2: // green
					{
						vecColor.x = 0; // r
						vecColor.y = RandomInt(50, 255); // g
						vecColor.z = 0; // b
                        break;
					}
					case 3: // blue
					{
						vecColor.x = 0; // r
						vecColor.y = 0; // g
						vecColor.z = RandomInt(50, 255); // b
                        break;
					}
				}

                break;
			}

            default: // white
			{
				vecColor.x = 255; // r
				vecColor.y = 255; // g
				vecColor.z = 255; // b
                break;
			}
		}

        UTIL_SetRenderMode( pEntity, kRenderFxGlowShell, vecColor, kRenderNormal, 16 );
        UTIL_SetTrail( pEntity, g_trailSpr, int(vecColor.x), int(vecColor.y), int(vecColor.z), 10, 200, 10 );

        pEntity.pev.vuser1 = vecColor;
    }
    else if ( iNadeType == 4 ) // infection grenade
    {
        UTIL_SetRenderMode( pEntity, kRenderFxGlowShell, Vector(0, 200, 0), kRenderNormal, 16 );
        UTIL_SetTrail( pEntity, g_trailSpr, 0, 200, 0, 10, 200, 10 );
    }
    else if ( iNadeType == 5 ) // force field grenade
    {
        UTIL_SetRenderMode( pEntity, kRenderFxGlowShell, Vector(0, 200, 200), kRenderNormal, 16 );
        UTIL_SetTrail( pEntity, g_trailSpr, 0, 200, 200, 10, 200, 10 );
    }
    else if ( iNadeType == 6 ) // holy grenade
    {
        UTIL_SetRenderMode( pEntity, kRenderFxGlowShell, Vector(255, 215, 0), kRenderNormal, 16 );
        UTIL_SetTrail( pEntity, g_trailSpr, 255, 215, 0, 10, 200, 10 );
    }
    else if ( iNadeType == 7 ) // jump grenade
    {
        UTIL_SetRenderMode( pEntity, kRenderFxGlowShell, Vector(200, 100, 0), kRenderNormal, 16 );
        UTIL_SetTrail( pEntity, g_trailSpr, 200, 100, 0, 10, 200, 10 );
    }

    g_pCustomGrenades.insertLast( pEntity.edict() );
}

//-----------------------------------------------------------------------------
// OnProjectileImpact Hook
//-----------------------------------------------------------------------------

bool OnProjectileImpact(CBaseMonster@ pMonster)
{
    if ( g_bDebug ) zp_log("OnProjectileImpact(): " + pMonster.pev.classname);

    CBaseEntity@ pEntity = cast<CBaseEntity@>(pMonster);

    int iNadeType = pEntity.pev.iuser1 & ~1024; // 1024 - zombie flag team
    int iNadeMode = pEntity.pev.iuser2;

    if ( iNadeMode == NADE_MODE_IMPACT )
    {
        return ZP_ExplodeGrenade( pEntity, iNadeType, true );
    }
    else if ( iNadeMode == NADE_MODE_TRIP )
    {
        TraceResult traceResult = g_Utility.GetGlobalTrace();

        // Wait for another impact, can't place grenade on an entity that may move
        if ( traceResult.pHit !is null && !g_EntityFuncs.Instance( traceResult.pHit ).IsBSPModel() )
            return false;
        
        // Skip check ground condition
        pEntity.pev.iuser3 = 1;

        ZP_PROJECTILE::CZpProjectile@ pZpProjectile = cast<ZP_PROJECTILE::CZpProjectile@>( CastToScriptClass( pEntity ) );

        pEntity.pev.dmgtime = g_Engine.time + 3.0f;

        // Freeze grenade on the surface
        pEntity.pev.movetype = MOVETYPE_NONE;
        pEntity.pev.solid = SOLID_NOT;

        // pEntity.pev.origin = traceResult.vecEndPos - traceResult.vecPlaneNormal * 8;
        pEntity.pev.origin = traceResult.vecEndPos;
        pEntity.pev.angles = Math.VecToAngles( traceResult.vecPlaneNormal );
        pEntity.pev.velocity = g_vecZero;

        // End point of the laser beam
        TraceResult traceResult2;
        Vector vecEnd = pEntity.pev.origin + traceResult.vecPlaneNormal * 8192.0f;
        
        g_Utility.TraceLine( pEntity.pev.origin, vecEnd, ignore_monsters, ignore_glass, pEntity.edict(), traceResult2 );
        
        pEntity.pev.vuser2 = traceResult2.vecEndPos;

        pZpProjectile.SetTouch( null );

        g_SoundSystem.PlaySound( pEntity.edict(), CHAN_WEAPON, ZP_NADEMODE_TRIP_DEPLOY_SND, 1.0f, ATTN_NORM, 0, PITCH_NORM );

        // Delay charge sound
        g_Scheduler.SetTimeout("ZP_ChargeTripNade", 0.1f, EHandle(pEntity));
    }
    else if ( iNadeMode == NADE_MODE_HOMING )
    {
        // Did impact, act as normal
        pEntity.pev.iuser2 = NADE_MODE_NORMAL;
    }
    
    // Return 'true' to remove grenade
    return false;
}

void ZP_ChargeTripNade(EHandle hEntity)
{
    CBaseEntity@ pEntity = hEntity.GetEntity();

    if ( pEntity !is null )
    {
        g_SoundSystem.PlaySound( pEntity.edict(), CHAN_WEAPON, ZP_NADEMODE_TRIP_CHARGE_SND, 1.0f, ATTN_NORM, 0, PITCH_NORM );
    }
}

//-----------------------------------------------------------------------------
// OnProjectileDetonate Hook
//-----------------------------------------------------------------------------

bool OnProjectileDetonate(CBaseMonster@ pMonster)
{
    // if ( g_bDebug ) zp_log("OnProjectileDetonate(): " + pMonster.pev.classname);

    CBaseEntity@ pEntity = cast<CBaseEntity@>(pMonster);

    int iNadeType = pEntity.pev.iuser1 & ~1024; // 1024 - zombie flag team
    int iNadeMode = pEntity.pev.iuser2;

    bool bOwnerIsHuman = ( pEntity.pev.iuser1 & 1024 == 0 );

    if ( iNadeMode != NADE_MODE_NORMAL )
    {
        if ( iNadeMode == NADE_MODE_PROXIMITY )
        {
            if ( (pEntity.pev.flags & FL_ONGROUND == 0) || UTIL_VectorLengthSqr(pEntity.pev.velocity) >= 10.0f * 10.0f )
            {
                pEntity.pev.dmgtime += 2.0f;
                return false;
            }

            // Freeze grenade on the surface
            pEntity.pev.movetype = MOVETYPE_NONE;
            pEntity.pev.solid = SOLID_NOT;

            if ( pEntity.pev.fuser2 <= g_Engine.time )
            {
                Vector vecOrigin = pEntity.pev.origin;

                NetworkMessage message( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecOrigin, null );
                    message.WriteByte( TE_BEAMCYLINDER ); // TE id
                    message.WriteCoord( vecOrigin.x ); // x
                    message.WriteCoord( vecOrigin.y ); // y
                    message.WriteCoord( vecOrigin.z ); // z
                    message.WriteCoord( vecOrigin.x ); // x axis
                    message.WriteCoord( vecOrigin.y ); // y axis
                    message.WriteCoord( vecOrigin.z + 385.0f ); // z axis
                    message.WriteShort( g_exploSpr ); // sprite
                    message.WriteByte( 0 ); // startframe
                    message.WriteByte( 0 ); // framerate
                    message.WriteByte( 5 ); // life
                    message.WriteByte( 60 ); // width 
                    message.WriteByte( 0 ); // noise
                    if ( bOwnerIsHuman )
                    {
                        message.WriteByte( 0 ); // red
                        message.WriteByte( 0 ); // green
                        message.WriteByte( 255 ); // blue
                    }
                    else
                    {
                        message.WriteByte( 255 ); // red
                        message.WriteByte( 0 ); // green
                        message.WriteByte( 0 ); // blue
                    }
                    message.WriteByte( 100 ); // brightness
                    message.WriteByte( 0 ); // speed
                message.End();

                g_SoundSystem.PlaySound( pEntity.edict(), CHAN_WEAPON, ZP_NADEMODE_PROXIMITY_BELL_SND, 1.0f, ATTN_NORM, 0, PITCH_NORM );

                pEntity.pev.fuser2 = g_Engine.time + 2.0f;
            }

            bool bFoundTarget = false;

            // UTIL_FindEntityInSphere (g_EntityFuncs.FindEntityInSphere) doesn't test Sphere-AABB intersection LOL (it's actually simple Sphere-Point intersection)
            // I expected it to be like in Source...

            // I could use g_EntityFuncs.FindEntityInSphere but can it be slower than the code below?
            for (int i = 1; i <= g_Engine.maxClients; i++)
            {
                if ( g_bAlive[i] )
                {
                    CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

                    if ( pPlayer is null )
                        continue;
                    
                    Vector vecDir = pPlayer.pev.origin - pEntity.pev.origin;

                    if ( g_bIsZombie[i] )
                    {
                        if ( bOwnerIsHuman && ( ZP_NADE_EXPLOSION_RADIUS * ZP_NADE_EXPLOSION_RADIUS >= UTIL_VectorLengthSqr(vecDir) ) )
                        {
                            bFoundTarget = true;
                            break;
                        }
                    }
                    else if ( g_bIsHuman[i] )
                    {
                        if ( !bOwnerIsHuman && ( ZP_NADE_EXPLOSION_RADIUS * ZP_NADE_EXPLOSION_RADIUS >= UTIL_VectorLengthSqr(vecDir) ) )
                        {
                            bFoundTarget = true;
                            break;
                        }
                    }
                }
            }

            if ( !bFoundTarget )
            {
                pEntity.pev.dmgtime += 0.5f;
                return false;
            }

            // Found target, act as normal
            pEntity.pev.iuser2 = NADE_MODE_NORMAL;
        }
        else if ( iNadeMode == NADE_MODE_IMPACT )
        {
            return false;
        }
        else if ( iNadeMode == NADE_MODE_TRIP )
        {
            TraceResult traceResult;

            bool bFoundTarget = false;

            if ( pEntity.pev.iuser4 == 0 )
            {
                g_SoundSystem.PlaySound( pEntity.edict(), CHAN_WEAPON, ZP_NADEMODE_TRIP_ACTIVATE_SND, 1.0f, ATTN_NORM, 0, PITCH_NORM );
                
                pEntity.pev.iuser4 = 1;
            }

            Vector vecHullMin, vecHullMax;

            // I could use g_Utility.TraceLine but can it be slower than the code below?
            for (int i = 1; i <= g_Engine.maxClients; i++)
            {
                if ( g_bAlive[i] )
                {
                    CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

                    if ( pPlayer is null )
                        continue;
                    
                    vecHullMin = pPlayer.pev.origin;
                    vecHullMax = pPlayer.pev.origin;

                    if ( pPlayer.pev.flags & FL_DUCKING == 0 )
                    {
                        vecHullMin = vecHullMin + VEC_HULL_MIN;
                        vecHullMax = vecHullMax + VEC_HULL_MAX;
                    }
                    else
                    {
                        vecHullMin = vecHullMin + VEC_DUCK_HULL_MIN;
                        vecHullMax = vecHullMax + VEC_DUCK_HULL_MAX;
                    }

                    if ( g_bIsZombie[i] )
                    {
                        if ( bOwnerIsHuman && UTIL_IsLineIntersectingAABB( pEntity.pev.origin, pEntity.pev.vuser2, vecHullMin, vecHullMax ) )
                        {
                            bFoundTarget = true;
                            break;
                        }
                    }
                    else if ( g_bIsHuman[i] )
                    {
                        if ( !bOwnerIsHuman && UTIL_IsLineIntersectingAABB( pEntity.pev.origin, pEntity.pev.vuser2, vecHullMin, vecHullMax ) )
                        {
                            bFoundTarget = true;
                            break;
                        }
                    }
                }
            }

            if ( !bFoundTarget )
            {
                NetworkMessage message( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, pEntity.pev.origin, null );
                    message.WriteByte( TE_BEAMENTPOINT ); // TE id
                    message.WriteShort( pEntity.entindex() ); // x
                    message.WriteCoord( pEntity.pev.vuser2.x ); // x
                    message.WriteCoord( pEntity.pev.vuser2.y ); // y
                    message.WriteCoord( pEntity.pev.vuser2.z ); // z
                    message.WriteShort( g_trailSpr ); // sprite
                    message.WriteByte( 0 ); // startframe
                    message.WriteByte( 0 ); // framerate
                    message.WriteByte( 5 ); // life
                    message.WriteByte( 10 ); // width 
                    message.WriteByte( 0 ); // noise
                    if ( bOwnerIsHuman )
                    {
                        message.WriteByte( 0 ); // red
                        message.WriteByte( 0 ); // green
                        message.WriteByte( 255 ); // blue
                    }
                    else
                    {
                        message.WriteByte( 255 ); // red
                        message.WriteByte( 0 ); // green
                        message.WriteByte( 0 ); // blue
                    }
                    message.WriteByte( 100 ); // brightness
                    message.WriteByte( 3 ); // speed
                message.End();

                pEntity.pev.dmgtime += 0.2f;
                return false;
            }

            // Found target, act as normal
            pEntity.pev.iuser2 = NADE_MODE_NORMAL;
        }
        else if ( iNadeMode == NADE_MODE_MOTION )
        {
            if ( (pEntity.pev.flags & FL_ONGROUND == 0) || UTIL_VectorLengthSqr(pEntity.pev.velocity) >= 10.0f * 10.0f )
            {
                pEntity.pev.dmgtime += 2.0f;
                return false;
            }

            // Freeze grenade on the surface
            pEntity.pev.movetype = MOVETYPE_NONE;
            pEntity.pev.solid = SOLID_NOT;

            bool bDoSound = false;
            bool bFoundTarget = false;

            // UTIL_FindEntityInSphere (g_EntityFuncs.FindEntityInSphere) doesn't test Sphere-AABB intersection LOL (it's actually simple Sphere-Point intersection)
            // I expected it to be like in Source...

            // I could use g_EntityFuncs.FindEntityInSphere but can it be slower than the code below?
            for (int i = 1; i <= g_Engine.maxClients; i++)
            {
                if ( g_bAlive[i] )
                {
                    CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

                    if ( pPlayer is null )
                        continue;
                    
                    Vector vecDir = pPlayer.pev.origin - pEntity.pev.origin;

                    if ( g_bIsZombie[i] )
                    {
                        if ( bOwnerIsHuman && ( ZP_NADE_EXPLOSION_RADIUS * ZP_NADE_EXPLOSION_RADIUS >= UTIL_VectorLengthSqr(vecDir) ) )
                        {
                            float flSpeedSqr = UTIL_VectorLengthSqr( pPlayer.pev.velocity );

                            if ( flSpeedSqr > 100.0f * 100.0f )
                            {
                                bFoundTarget = true;
                                break;
                            }
                            else if ( flSpeedSqr > 0.f )
                            {
                                bDoSound = true;
                            }
                        }
                    }
                    else if ( g_bIsHuman[i] )
                    {
                        if ( !bOwnerIsHuman && ( ZP_NADE_EXPLOSION_RADIUS * ZP_NADE_EXPLOSION_RADIUS >= UTIL_VectorLengthSqr(vecDir) ) )
                        {
                            float flSpeedSqr = UTIL_VectorLengthSqr( pPlayer.pev.velocity );

                            if ( flSpeedSqr > 100.0f * 100.0f )
                            {
                                bFoundTarget = true;
                                break;
                            }
                            else if ( flSpeedSqr > 0.f )
                            {
                                bDoSound = true;
                            }
                        }
                    }
                }
            }

            if ( !bFoundTarget )
            {
                if ( bDoSound )
                {
                    int r, g, b;

                    Vector vecOrigin = pEntity.pev.origin;

                    if ( bOwnerIsHuman )
                    {
                        r = 0;
                        g = 0;
                        b = 255;
                    }
                    else
                    {
                        r = 255;
                        g = 0;
                        b = 0;
                    }

                    UTIL_CreateRing( vecOrigin, vecOrigin + Vector(0, 0, 200.0f * 9.27f), 1, 60, 100, r, g, b );

                    g_SoundSystem.PlaySound( pEntity.edict(), CHAN_WEAPON, ZP_NADEMODE_MOTION_GEIGER_SND, 1.0f, ATTN_NORM, 0, PITCH_NORM );
                }

                pEntity.pev.dmgtime += 0.1f;
                return false;
            }

            // Found target, act as normal
            pEntity.pev.iuser2 = NADE_MODE_NORMAL;
        }
        else if ( iNadeMode == NADE_MODE_SATCHEL )
        {
            if ( (pEntity.pev.flags & FL_ONGROUND == 0) || UTIL_VectorLengthSqr(pEntity.pev.velocity) >= 10.0f * 10.0f )
            {
                pEntity.pev.dmgtime += 2.0f;
                return false;
            }

            // Freeze grenade on the surface
            pEntity.pev.movetype = MOVETYPE_NONE;
            pEntity.pev.solid = SOLID_NOT;

            // Ready for remote detonation
            pEntity.pev.iuser4 = 1;
            pEntity.pev.dmgtime += 60.0f;

            return false;
        }
        else if ( iNadeMode == NADE_MODE_HOMING )
        {
            if ( (pEntity.pev.flags & FL_ONGROUND != 0) )
            {
                pEntity.pev.iuser2 = NADE_MODE_NORMAL;
                return false;
            }

            // Set time when nade was thrown
            if ( pEntity.pev.fuser2 == 0.0f )
            {
                pEntity.pev.fuser2 = g_Engine.time;
            }

            if ( pEntity.pev.iuser4 != 0 )
            {
                // Follow a target maximum 5 seconds
                if ( g_Engine.time - pEntity.pev.fuser2 < 5.0f )
                {
                    bool bAbortExplode = true;
                    float flNextThink = 0.15f;

                    int idx = pEntity.pev.iuser4;
                    CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( idx );

                    // Target has left the game or just died
                    if ( pPlayer !is null && g_bAlive[idx] )
                    {
                        if ( g_bIsZombie[idx] )
                        {
                            if ( !bOwnerIsHuman )
                            {
                                bAbortExplode = false;
                            }
                        }
                        else if ( g_bIsHuman[idx] )
                        {
                            if ( bOwnerIsHuman )
                            {
                                bAbortExplode = false;
                            }
                        }

                        // Target is in enemy team, keep going
                        if ( bAbortExplode )
                        {
                            Vector dir = pPlayer.pev.origin - pEntity.pev.origin;
                            float distsqr = UTIL_VectorLengthSqr(dir);

                            // Follow the target until the distance will be close enough for detonation
                            if ( 48.0f * 48.0f < distsqr )
                            {
                                // Speed up thinking
                                if ( 100.0f * 100.0f >= distsqr )
                                {
                                    flNextThink = 0.05f;
                                }

                                const float dt = 0.35f;
                                const float speed_lerp = 0.25f;
                                const float speed = 300.0f;

                                float flSpeed = pEntity.pev.velocity.Length();

                                // Velocity direction
                                Vector vecVelDir = pEntity.pev.velocity.Normalize();

                                // Direction to target
                                Vector vecDir = (pPlayer.pev.origin - pEntity.pev.origin).Normalize();

                                // Lerp speed
                                float flNewSpeed = flSpeed + ( speed - flSpeed ) * speed_lerp;

                                // Spherical linear interpolation of new velocity vector
                                float flProjection = vecVelDir.x * vecDir.x + vecVelDir.y * vecDir.y + vecVelDir.z * vecDir.z;
                                float theta = acos( flProjection ) * dt;

                                Vector vecRelative = ( vecDir - vecVelDir * flProjection ).Normalize();

                                // Sum the legs to get the hypotenuse
                                Vector vecNewVelocity = vecVelDir * cos( theta ) + vecRelative * sin( theta );

                                pEntity.pev.velocity = vecNewVelocity * flNewSpeed;
                            }
                            else
                            {
                                bAbortExplode = false;
                            }

                            g_SoundSystem.PlaySound( pEntity.edict(), CHAN_WEAPON, ZP_NADEMODE_HOMING_PING_SND, 1.0f, ATTN_NORM, 0, PITCH_NORM );
                        }
                    }
                    else
                    {
                        bAbortExplode = false;
                    }
                    
                    if ( bAbortExplode )
                    {
                        pEntity.pev.dmgtime += flNextThink;
                        return false;
                    }
                }
            }
            else
            {
                // Keep seeking for any target maximum 1.5 seconds
                if ( g_Engine.time - pEntity.pev.fuser2 < 1.5f )
                {
                    Vector vecHullMin, vecHullMax;

                    // I could use g_EntityFuncs.FindEntityInSphere but can it be slower than the code below?
                    for (int i = 1; i <= g_Engine.maxClients; i++)
                    {
                        if ( g_bAlive[i] )
                        {
                            CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

                            if ( pPlayer is null )
                                continue;
                            
                            Vector vecDir = pPlayer.pev.origin - pEntity.pev.origin;

                            if ( g_bIsZombie[i] )
                            {
                                if ( bOwnerIsHuman && ( ZP_NADE_EXPLOSION_RADIUS * ZP_NADE_EXPLOSION_RADIUS >= UTIL_VectorLengthSqr(vecDir) ) )
                                {
                                    pEntity.pev.iuser4 = i;
                                    break;
                                }
                            }
                            else if ( g_bIsHuman[i] )
                            {
                                if ( !bOwnerIsHuman && ( ZP_NADE_EXPLOSION_RADIUS * ZP_NADE_EXPLOSION_RADIUS >= UTIL_VectorLengthSqr(vecDir) ) )
                                {
                                    pEntity.pev.iuser4 = i;
                                    break;
                                }
                            }
                        }
                    }

                    if ( pEntity.pev.iuser4 == 0.0f )
                        pEntity.pev.dmgtime += 0.15f;
                    else
                        g_SoundSystem.PlaySound( pEntity.edict(), CHAN_WEAPON, ZP_NADEMODE_HOMING_PING_SND, 1.0f, ATTN_NORM, 0, PITCH_NORM );
                    
                    return false;
                }
            }

            pEntity.pev.iuser2 = NADE_MODE_NORMAL;
        }
    }

    // Return 'true' to remove grenade
    return ZP_ExplodeGrenade( pEntity, iNadeType, false );
}

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//
//                         Engine / Server Hooks
//
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// OnPlayerTakeDamage Hook
//-----------------------------------------------------------------------------

HookReturnCode OnPlayerTakeDamage( DamageInfo@ pDamageInfo )
{
    if ( !g_bEnabled )
        return HOOK_CONTINUE;

    if ( g_bDebug )
        zp_log("OnPlayerTakeDamage(): " + pDamageInfo.pVictim.pev.netname + " | " + pDamageInfo.pAttacker.pev.netname + " | " + string(pDamageInfo.flDamage) + " | " + string(pDamageInfo.bitsDamageType));

    CBasePlayer@ pPlayer = cast<CBasePlayer@>(pDamageInfo.pVictim);
    CBasePlayer@ pAttacker = cast<CBasePlayer@>(pDamageInfo.pAttacker);

    if ( g_bIsZombie[pPlayer.entindex()] )
    {
        if ( pDamageInfo.bitsDamageType == DMG_FALL )
        {
            // Play fall sound
            g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_VOICE, UTIL_GetRandomStringFromArray( ZP_ZOMBIE_FALL_SND ), 1.0f, ATTN_NORM, 0, PITCH_NORM );
        }
        else if ( pDamageInfo.bitsDamageType == DMG_DROWN )
        {
            // Zombie can't drown
            pDamageInfo.flDamage = 0.0f;
            return HOOK_HANDLED;
        }
    }

    // Player attacked another player
    if ( g_iGameState == ZP_STATE_GAME_STARTED && pAttacker !is null && pPlayer !is pAttacker )
    {
        int victimidx = pPlayer.entindex(); // Victim
        int attackeridx = pAttacker.entindex(); // Attacker

        // May be a bug that appears, so consider it
        if ( (g_bIsHuman[victimidx] && g_bIsHuman[attackeridx]) || (g_bIsZombie[victimidx] && g_bIsZombie[attackeridx]) )
        {
            return HOOK_HANDLED;
        }

        // Our victim is a Human
        if ( g_bIsHuman[victimidx] )
        {
            // Set damage for Nemesis and Assassin
            if ( g_iClassType[attackeridx] != ZP_ZOMBIE_DEFAULT )
            {
                if ( g_iClassType[attackeridx] == ZP_ZOMBIE_NEMESIS )
                {
                    pDamageInfo.flDamage = ZP_NEMESIS_DAMAGE;
                }
                else if ( g_iClassType[attackeridx] == ZP_ZOMBIE_ASSASSIN )
                {
                    pDamageInfo.flDamage = ZP_ASSASSIN_DAMAGE;
                }
            }

            // Show damage
            if ( ZP_DAMAGE_INDICATOR )
            {
                UTIL_ShowDamage( pPlayer, pAttacker, int( pDamageInfo.flDamage ) );
            }

            // Block the infection if there's armor
            if ( ZP_HUMAN_ARMOR_PROTECT && pPlayer.pev.armorvalue > 0.0f )
            {
                float newArmor = pPlayer.pev.armorvalue - pDamageInfo.flDamage;

                if ( newArmor < 0.0f )
                    newArmor = 0.0f;
                
                pPlayer.pev.armorvalue = newArmor;
                pDamageInfo.flDamage = 0.0f; // zero damage

                g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_BODY, ZP_ARMOR_HIT_SND, 1.0f, ATTN_NORM, 0, PITCH_NORM );

                return HOOK_HANDLED;
            }

            if ( ZP_PAIN_SHOCK )
            {
                if ( g_iClassType[victimidx] == ZP_HUMAN_DEFAULT )
                {
                    g_flVelocityModifier[victimidx] = ZP_PAIN_SHOCK_VEL_MOD;
                }
                else if ( g_iClassType[victimidx] == ZP_HUMAN_SURVIVOR )
                {
                    if ( !ZP_PAIN_SHOCK_FREE_SURVIVOR )
                    {
                        g_flVelocityModifier[victimidx] = 1.0f;
                    }
                }
                else if ( !ZP_PAIN_SHOCK_FREE_SNIPER )
                {
                    g_flVelocityModifier[victimidx] = 1.0f;
                }
            }

            if ( g_iClassType[attackeridx] != ZP_ZOMBIE_DEFAULT )
            {
                if ( pPlayer.pev.health - pDamageInfo.flDamage < 0.0f )
                {
                    // pDamageInfo.flDamage = pPlayer.pev.health;

                    pPlayer.Killed( pAttacker.pev, g_iClassType[attackeridx] == ZP_ZOMBIE_NEMESIS ? GIB_NEVER : GIB_ALWAYS );
                    pDamageInfo.flDamage = 0.0f;
                }

                // Punch a bit
                pPlayer.pev.punchangle.x = -2.0f;

                UTIL_TakeDamageNoBoost( pPlayer, pDamageInfo );

                return HOOK_HANDLED;
            }

            // Never infect last Human, or Survivor / Sniper, or if the attacker is Nemesis / Assassin, or the current mode is Swarm
            if ( g_iAliveHumans == 1 || g_iClassType[victimidx] != ZP_HUMAN_DEFAULT || g_iGameMode == ZP_MODE_SWARM )
            {
                // Punch a bit
                pPlayer.pev.punchangle.x = -2.0f;

                UTIL_TakeDamageNoBoost( pPlayer, pDamageInfo );
            }
            else
            {
                ZP_InfectHuman( pPlayer, pAttacker );
                ZP_CheckTeams();

                pDamageInfo.flDamage = 0.0f;
            }
        }
        else if ( g_bIsZombie[victimidx] ) // Zombie
        {
            int iWeaponID = WEAPON_NONE;
            bool bOverrideDamage = true;

            if ( pAttacker.m_hActiveItem.GetEntity() !is null )
            {
                CBasePlayerWeapon@ pWeapon = cast<CBasePlayerWeapon@>( pAttacker.m_hActiveItem.GetEntity() );

                if ( pWeapon !is null )
                {
                    iWeaponID = pWeapon.m_iId;

                    if ( iWeaponID == WEAPON_SNIPERRIFLE )
                    {
                        // Sniper deals huge damage to any zombie
                        if ( g_iClassType[attackeridx] == ZP_HUMAN_SNIPER )
                        {
                            pDamageInfo.flDamage = ZP_SNIPER_DAMAGE;
                            bOverrideDamage = false;
                        }
                    }

                    if ( g_bIncendiaryAmmo[ attackeridx ] && WEAPON_HAS_TRACER[ iWeaponID ] )
                    {
                        Vector vecAttack = pAttacker.GetGunPosition();

                        NetworkMessage message( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecAttack, null );
                            message.WriteByte( TE_BEAMPOINTS ); // TE id
                            message.WriteCoord( vecAttack.x ); // x
                            message.WriteCoord( vecAttack.y ); // y
                            message.WriteCoord( vecAttack.z ); // z
                            message.WriteCoord( pPlayer.pev.origin.x + RandomInt( -5, 5 ) ); // x
                            message.WriteCoord( pPlayer.pev.origin.y + RandomInt( -5, 5 ) ); // y
                            message.WriteCoord( pPlayer.pev.origin.z + RandomInt( -5, 5 ) ); // z
                            message.WriteShort( g_tracerSpr ); // sprite
                            message.WriteByte( 1 ); // startframe
                            message.WriteByte( 5 ); // framerate
                            message.WriteByte( 2 ); // life
                            message.WriteByte( 10 ); // width 
                            message.WriteByte( 0 ); // noise
                            message.WriteByte( 255 ); // red
                            message.WriteByte( 215 ); // green
                            message.WriteByte( 0 ); // blue
                            message.WriteByte( 200 ); // brightness
                            message.WriteByte( 150 ); // speed
                        message.End();

                        ZP_SetOnFire( pPlayer, false );
                    }
                }
            }

            if ( bOverrideDamage )
            {
                if ( iWeaponID > WEAPON_NONE && iWeaponID <= WEAPON_DISPLACER )
                    pDamageInfo.flDamage *= WEAPON_DAMAGE_MULTIPLIER[iWeaponID];
            }

            float flDamage = pDamageInfo.flDamage;

            if ( g_iClassType[attackeridx] == ZP_HUMAN_DEFAULT )
            {
                // TODO: allow sniper or survivor receive rewards
                g_flDealenDamage[attackeridx] += flDamage;

                while ( g_flDealenDamage[attackeridx] >= ZP_HUMAN_DAMAGE_REWARD )
                {
                    g_flDealenDamage[attackeridx] -= ZP_HUMAN_DAMAGE_REWARD;
                    g_iAmmopacks[attackeridx]++;
                }
            }

            // Tilt screen
            if ( RandomInt(1, 10) == 1 )
            {
                pPlayer.pev.punchangle.z += ( RandomInt(0, 1) == 0 ? -15.0f : 15.0f );
            }

            // Punch a bit
            if ( !g_bNoDamage[victimidx] )
                pPlayer.pev.punchangle.x = -2.0f;

            // No damage if frozen
            if ( ( g_bFrozen[victimidx] && !ZP_DAMAGE_WHILE_FROZEN ) || g_bNoDamage[victimidx] )
            {
                pDamageInfo.flDamage = 0.0f;
                return HOOK_HANDLED;
            }

            UTIL_TakeDamageNoBoost( pPlayer, pDamageInfo );

            // Show damage
            if ( ZP_DAMAGE_INDICATOR )
            {
                UTIL_ShowDamage( pPlayer, pAttacker, int( flDamage ) );
            }

            // Play random pain sound
            if ( RandomInt(1, 6) == 1 )
            {
                ZP_PlayPainSound( pPlayer, g_iClassType[ victimidx ] );
            }

            // Pain shock
            if ( ZP_PAIN_SHOCK && !g_bZombieEscape )
            {
                if ( UTIL_ShouldDoLargeFlinch(pPlayer, iWeaponID) )
                {
                    if ( UTIL_VectorLengthSqr(pPlayer.pev.velocity) < 300.0f * 300.0f )
                    {
                        Vector attack_velocity = (pPlayer.pev.origin - pDamageInfo.pInflictor.pev.origin).Normalize() * ZP_PAIN_SHOCK_LARGE_FLINCH_VEL_KNOCKBACK;
                        pPlayer.pev.velocity = pPlayer.pev.velocity + attack_velocity;
                    }

                    if ( g_iClassType[victimidx] == ZP_ZOMBIE_DEFAULT )
                    {
                        g_flVelocityModifier[victimidx] = ( g_bFirstZombie[victimidx] ? UTIL_Lerp(ZP_PAIN_SHOCK_LARGE_FLINCH_VEL_MOD, 1.0f, ZP_PAIN_SHOCK_FIRST_ZOMBIE_VEL_MOD_RATIO) : ZP_PAIN_SHOCK_LARGE_FLINCH_VEL_MOD );
                    }
                    else if ( g_iClassType[victimidx] == ZP_ZOMBIE_NEMESIS )
                    {
                        g_flVelocityModifier[victimidx] = UTIL_Lerp(ZP_PAIN_SHOCK_LARGE_FLINCH_VEL_MOD, 1.0f, ZP_PAIN_SHOCK_NEMESIS_VEL_MOD_RATIO);
                    }
                    else
                    {
                        g_flVelocityModifier[victimidx] = UTIL_Lerp(ZP_PAIN_SHOCK_LARGE_FLINCH_VEL_MOD, 1.0f, ZP_PAIN_SHOCK_ASSASSIN_VEL_MOD_RATIO);
                    }
                }
                else
                {
                    if ( g_iClassType[victimidx] == ZP_ZOMBIE_DEFAULT )
                    {
                        g_flVelocityModifier[victimidx] = ( g_bFirstZombie[victimidx] ? UTIL_Lerp(ZP_PAIN_SHOCK_VEL_MOD, 1.0f, ZP_PAIN_SHOCK_FIRST_ZOMBIE_VEL_MOD_RATIO) : ZP_PAIN_SHOCK_VEL_MOD );
                    }
                    else if ( g_iClassType[victimidx] == ZP_ZOMBIE_NEMESIS )
                    {
                        g_flVelocityModifier[victimidx] = UTIL_Lerp(ZP_PAIN_SHOCK_VEL_MOD, 1.0f, ZP_PAIN_SHOCK_NEMESIS_VEL_MOD_RATIO);
                    }
                    else
                    {
                        g_flVelocityModifier[victimidx] = UTIL_Lerp(ZP_PAIN_SHOCK_VEL_MOD, 1.0f, ZP_PAIN_SHOCK_ASSASSIN_VEL_MOD_RATIO);
                    }
                }
            }

            // Calc knockback
            if ( ( ZP_KNOCKBACK || g_bZombieEscape ) && !g_bFrozen[victimidx] && ( pDamageInfo.bitsDamageType & DMG_BULLET ) != 0 )
            {
                bool ducking = ( pPlayer.pev.flags & (FL_DUCKING | FL_ONGROUND) == (FL_DUCKING | FL_ONGROUND) );

                if ( ducking && ZP_KNOCKBACK_DUCKING == 0.0f )
                    return HOOK_HANDLED;
                
                Vector vecDir;

                Vector vecAttackOrigin = pAttacker.EyePosition();
                Vector vecBodyTarget = pPlayer.BodyTarget( pPlayer.pev.origin );

                Vector vecAttackDir = (vecBodyTarget - vecAttackOrigin);
                float flDistanceSqr = UTIL_VectorLengthSqr( vecAttackDir );

                // if ( UTIL_VectorLengthSqr(pPlayer.pev.velocity) > 0.0f )
                // {
                //     vecDir = pPlayer.pev.velocity.Normalize() * -1.0f;
                // }
                // else
                // {
                    // Normalize direction
                    vecDir = vecAttackDir.Normalize();
                // }

                // Store normalized direction
                Vector dir = vecDir;

                if ( flDistanceSqr > ZP_KNOCKBACK_DISTANCE * ZP_KNOCKBACK_DISTANCE )
                    return HOOK_HANDLED;
                
                Vector vecVelocity = pPlayer.pev.velocity;

                if ( ZP_KNOCKBACK_DAMAGE )
                    vecDir = vecDir * flDamage;
                
                // Weapon power
                if ( ZP_KNOCKBACK_POWER && iWeaponID > WEAPON_NONE && iWeaponID <= WEAPON_DISPLACER )
                    vecDir = vecDir * WEAPON_POWER[iWeaponID];
                
                if ( ducking )
                    vecDir = vecDir * ZP_KNOCKBACK_DUCKING;
                
                if ( g_iClassType[victimidx] == ZP_ZOMBIE_DEFAULT )
                {
                    CZombieClass@ zombieClass = g_zombieClasses[ g_iCurrentZombieClass[victimidx] ];

                    vecDir = vecDir * zombieClass.m_flKnockback;
                }
                else if ( g_iClassType[victimidx] == ZP_ZOMBIE_NEMESIS )
                {
                    vecDir = vecDir * ZP_KNOCKBACK_NEMESIS;
                }
                else // Assassin
                {
                    vecDir = vecDir * ZP_KNOCKBACK_ASSASSIN;
                }

                // Don't exceed a limit of speed
                if ( ZP_KNOCKBACK_MAX_VEL != 0.0f && UTIL_VectorLengthSqr(vecDir) > ZP_KNOCKBACK_MAX_VEL * ZP_KNOCKBACK_MAX_VEL )
                    vecDir = dir * ZP_KNOCKBACK_MAX_VEL;
                
                // New velocity
                pPlayer.pev.velocity = vecVelocity + vecDir;
            }
        }

        return HOOK_HANDLED;
    }
    // else
    else if ( g_iGameState == ZP_STATE_GAME_END || ( g_iGameState == ZP_STATE_GAME_STARTED && pPlayer is pAttacker ) )
    {
        pDamageInfo.flDamage = 0.0f;
        return HOOK_HANDLED;
    }

    return HOOK_CONTINUE;
}

//-----------------------------------------------------------------------------
// OnPlayerKilled Hook
//-----------------------------------------------------------------------------

HookReturnCode OnPlayerKilled( CBasePlayer@ pPlayer, CBaseEntity@ pAttacker, int iGib )
{
    if ( !g_bEnabled )
        return HOOK_CONTINUE;

    if ( g_bDebug ) zp_log("OnPlayerKilled(): " + pPlayer.pev.netname + " | " + pAttacker.pev.netname + " | " + string(iGib));

    int victimidx = pPlayer.entindex();

    if ( g_bFrozen[victimidx] )
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

    if ( g_iGameState == ZP_STATE_GAME_STARTED )
    {
        if ( g_bAlive[victimidx] )
        {
            int attackeridx = pAttacker.entindex();

            // It's a Player
            if ( attackeridx > 0 && attackeridx <= g_Engine.maxClients && victimidx != attackeridx )
            {
                // Zombie
                if ( g_bIsZombie[attackeridx] )
                {
                    // Attacker is Assassin
                    if ( g_iClassType[attackeridx] == ZP_ZOMBIE_ASSASSIN )
                    {
                        // Explode victim of an Assassin
                        if ( iGib != GIB_ALWAYS )
                        {
                            pPlayer.GibMonster();

                            pPlayer.pev.solid = SOLID_NOT;
                            pPlayer.pev.deadflag = DEAD_DEAD;
                            pPlayer.pev.effects |= EF_NODRAW;
                        }

                        // Reward Assassin
                        if ( ZP_ASSASSIN_KILL_ALLOW_REWARD )
                            g_iAmmopacks[attackeridx] += ZP_ASSASSIN_KILL_REWARD;
                    }
                    else if ( g_iClassType[attackeridx] == ZP_ZOMBIE_NEMESIS )
                    {
                        // Reward Nemesis
                        if ( ZP_NEMESIS_KILL_ALLOW_REWARD )
                            g_iAmmopacks[attackeridx] += ZP_NEMESIS_KILL_REWARD;
                    }
                    else if ( g_iClassType[attackeridx] == ZP_ZOMBIE_DEFAULT )
                    {
                        g_iAmmopacks[attackeridx] += ZP_ZOMBIE_KILL_REWARD;
                    }

                    // Reward for killing Survivor or Sniper
                    if ( g_iClassType[victimidx] == ZP_HUMAN_SURVIVOR )
                    {
                        if ( g_iGameMode == ZP_MODE_SURVIVOR && ZP_ZOMBIE_KILL_SURVIVOR_ALLOW_REWARD )
                        {
                            g_iAmmopacks[attackeridx] += ZP_ZOMBIE_KILL_SURVIVOR_REWARD;
                            g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[ZP] Player " + pAttacker.pev.netname + " received " + ZP_ZOMBIE_KILL_SURVIVOR_REWARD + " ammo packs for killing the Survivor\n" );
                        }
                    }
                    else if ( g_iClassType[victimidx] == ZP_HUMAN_SNIPER )
                    {
                        if ( g_iGameMode == ZP_MODE_SNIPER && ZP_ZOMBIE_KILL_SNIPER_ALLOW_REWARD )
                        {
                            g_iAmmopacks[attackeridx] += ZP_ZOMBIE_KILL_SNIPER_REWARD;
                            g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[ZP] Player " + pAttacker.pev.netname + " received " + ZP_ZOMBIE_KILL_SNIPER_REWARD + " ammo packs for killing the Sniper\n" );
                        }
                    }
                }
                else if ( g_bIsHuman[attackeridx] )
                {
                    // Attacker is Sniper
                    if ( g_iClassType[attackeridx] == ZP_HUMAN_SNIPER )
                    {
                        // Explode zombie if Sniper did shoot them
                        CBasePlayer@ pAttackerPlayer = cast<CBasePlayer@>(pAttacker);

                        if ( pAttackerPlayer !is null )
                        {
                            CBasePlayerWeapon@ pWeapon = cast<CBasePlayerWeapon@>( pAttackerPlayer.m_hActiveItem.GetEntity() );

                            if ( pWeapon !is null )
                            {
                                if ( pWeapon.m_iId == WEAPON_SNIPERRIFLE )
                                {
                                    Vector vecOrigin = pPlayer.pev.origin;

                                    // Explode effect
                                    NetworkMessage message( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecOrigin, null );
                                        message.WriteByte( TE_LAVASPLASH ); // TE id
                                        message.WriteCoord( vecOrigin.x ); // x
                                        message.WriteCoord( vecOrigin.y ); // y
                                        message.WriteCoord( vecOrigin.z - 26.0f ); // z
                                    message.End();

                                    // Hide corpse
                                    pPlayer.pev.solid = SOLID_NOT;
                                    pPlayer.pev.deadflag = DEAD_DEAD;
                                    pPlayer.pev.effects |= EF_NODRAW;
                                }
                            }
                        }

                        // Reward Sniper
                        if ( ZP_SNIPER_KILL_ALLOW_REWARD )
                            g_iAmmopacks[attackeridx] += ZP_SNIPER_KILL_REWARD;
                    }
                    else if ( g_iClassType[attackeridx] == ZP_HUMAN_SURVIVOR )
                    {
                        // Reward Survivor
                        if ( ZP_SURVIVOR_KILL_ALLOW_REWARD )
                            g_iAmmopacks[attackeridx] += ZP_SURVIVOR_KILL_REWARD;
                    }
                    else if ( g_iClassType[attackeridx] == ZP_HUMAN_DEFAULT )
                    {
                        g_iAmmopacks[attackeridx] += ZP_HUMAN_KILL_REWARD;
                    }

                    // Reward for killing Nemesis or Assassin
                    if ( g_iClassType[victimidx] == ZP_ZOMBIE_NEMESIS )
                    {
                        if ( g_iGameMode == ZP_MODE_NEMESIS && ZP_HUMAN_KILL_NEMESIS_ALLOW_REWARD )
                        {
                            g_iAmmopacks[attackeridx] += ZP_HUMAN_KILL_NEMESIS_REWARD;
                            g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[ZP] Player " + pAttacker.pev.netname + " received " + ZP_HUMAN_KILL_NEMESIS_REWARD + " ammo packs for killing the Nemesis\n" );
                        }
                    }
                    else if ( g_iClassType[victimidx] == ZP_ZOMBIE_ASSASSIN )
                    {
                        if ( g_iGameMode == ZP_MODE_ASSASSIN && ZP_HUMAN_KILL_ASSASSIN_ALLOW_REWARD )
                        {
                            g_iAmmopacks[attackeridx] += ZP_HUMAN_KILL_ASSASSIN_REWARD;
                            g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[ZP] Player " + pAttacker.pev.netname + " received " + ZP_HUMAN_KILL_ASSASSIN_REWARD + " ammo packs for killing the Assassin\n" );
                        }
                    }
                }
            }

            if ( g_bIsZombie[victimidx] )
            {
                // Explode Nemesis or Assassin
                if ( g_iClassType[victimidx] != ZP_ZOMBIE_DEFAULT )
                {
                    pPlayer.GibMonster();

                    pPlayer.pev.solid = SOLID_NOT;
                    pPlayer.pev.deadflag = DEAD_DEAD;
                    pPlayer.pev.effects |= EF_NODRAW;
                }

                // Play death sound
                g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_VOICE, UTIL_GetRandomStringFromArray( ZP_ZOMBIE_DIE_SND ), 1.0f, ATTN_NORM, 0, PITCH_NORM );
            }

            if ( g_bIsHuman[victimidx] )
            {
                g_iAliveHumans--;
            }
            else if ( g_bIsZombie[victimidx] )
            {
                g_iAliveZombies--;
            }

            g_bAlive[victimidx] = false;

            ZP_ResetExtraStates( victimidx );

            g_bNightvision[victimidx] = true;

            // Infect a random player
            if ( attackeridx == victimidx && g_iAliveZombies == 0 && g_iAliveHumans > 1 && ( g_iGameMode == ZP_MODE_SINGLE_INFECTION || g_iGameMode == ZP_MODE_MULTIPLE_INFECTION ) )
            {
                int human = UTIL_PickRandomHuman();

                if ( human != -1 )
                {
                    ZP_InfectHuman( g_PlayerFuncs.FindPlayerByIndex(human), null );
                }
            }

            if ( g_bIsZombie[victimidx] && g_iAliveZombies > 0 && ( g_iGameMode == ZP_MODE_SINGLE_INFECTION || g_iGameMode == ZP_MODE_MULTIPLE_INFECTION ) && ( g_bZombieEscape || g_iAllowedRespawns > 0 ) )
            {
                const float flRespawnDelay = ( g_bZombieEscape ? ZP_ZE_ZOMBIE_RESPAWN_DELAY : ZP_ZOMBIE_RESPAWN_DELAY );

                g_bIsHuman[victimidx] = false;
                g_bIsZombie[victimidx] = true;
                g_bAlive[victimidx] = false;

                g_flRespawnTime[victimidx] = g_Engine.time + flRespawnDelay;

                g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] You will be respawned in " + string( int(flRespawnDelay) ) + " seconds\n" );

                if ( !g_bZombieEscape )
                    g_iAllowedRespawns--;
            }

            ZP_CheckTeams();

            return HOOK_HANDLED;
        }
    }
    else if ( g_bAlive[victimidx] )
    {
        if ( g_bIsHuman[victimidx] )
        {
            g_iAliveHumans--;
        }
        else if ( g_bIsZombie[victimidx] )
        {
            g_iAliveZombies--;
        }

        g_bAlive[victimidx] = false;

        ZP_ResetExtraStates( victimidx );

        g_bNightvision[victimidx] = true;

        return HOOK_HANDLED;
    }

    return HOOK_CONTINUE;
}

//-----------------------------------------------------------------------------
// OnPlayerPreThink Hook
//-----------------------------------------------------------------------------

HookReturnCode OnPlayerPreThink( CBasePlayer@ pPlayer, uint& out uiFlags )
{
    if ( !g_bEnabled )
        return HOOK_CONTINUE;

    int idx = pPlayer.entindex();

    CBasePlayerWeapon@ pWeapon = cast<CBasePlayerWeapon@>( pPlayer.m_hActiveItem.GetEntity() );

    // Show nade mode if a nade was selected
    if ( pWeapon !is null && pWeapon !is g_pCurrentWeapon[idx] )
    {
        int iWeaponID = pWeapon.m_iId;

        // A custom weapon
        if ( iWeaponID > 30 )
        {
            if ( iWeaponID == WEAPON_FIREGRENADE ||
                iWeaponID == WEAPON_FROSTGRENADE ||
                iWeaponID == WEAPON_FLAREGRENADE ||
                iWeaponID == WEAPON_INFECTGRENADE ||
                iWeaponID == WEAPON_HOLYGRENADE ||
                iWeaponID == WEAPON_JUMPGRENADE ||
                iWeaponID == WEAPON_FORCE_FIELD_GRENADE )
            {
                g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "Mode: " + UTIL_GetNadeModeAsString( g_iNadeMode[idx] ) );
            }
        }
    }

    if ( g_bAlive[idx] )
    {
        // Make us able to jump no matter what (minigun)
        pPlayer.pev.fuser4 = 0.0f;

        // Pain shock
        if ( ZP_PAIN_SHOCK && pPlayer.pev.flags & FL_ONGROUND != 0 )
        {
            if ( g_flVelocityModifier[idx] < 1.0f )
            {
                float modvel = g_flVelocityModifier[idx] + 0.01f;

                g_flVelocityModifier[idx] = modvel;
                pPlayer.pev.velocity = pPlayer.pev.velocity * modvel;
            }
            else
            {
                g_flVelocityModifier[idx] = 1.0f;
            }
        }

        // Switch nade mode
        if ( ( pPlayer.pev.button & IN_ATTACK2 != 0 ) && pWeapon !is null && pWeapon.m_iId > 30 && g_flSwitchNadeModeTime[idx] <= g_Engine.time )
        {
            int iWeaponID = pWeapon.m_iId;

            if ( iWeaponID == WEAPON_FIREGRENADE ||
                iWeaponID == WEAPON_FROSTGRENADE ||
                iWeaponID == WEAPON_FLAREGRENADE ||
                iWeaponID == WEAPON_INFECTGRENADE ||
                iWeaponID == WEAPON_HOLYGRENADE ||
                iWeaponID == WEAPON_JUMPGRENADE ||
                iWeaponID == WEAPON_FORCE_FIELD_GRENADE )
            {
                ++g_iNadeMode[idx];

                if ( g_iNadeMode[idx] > NADE_MODE_LAST )
                {
                    g_iNadeMode[idx] = NADE_MODE_NORMAL;
                }

                g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "Mode - " + UTIL_GetNadeModeAsString( g_iNadeMode[idx] ) );

                g_flSwitchNadeModeTime[idx] = g_Engine.time + 0.3f;
            }
        }

        if ( g_bIsZombie[idx] )
        {
            // Don't play any steps
            if ( ZP_ZOMBIE_SILENT_STEPS && g_iClassType[idx] != ZP_ZOMBIE_NEMESIS )
            {
                pPlayer.pev.flTimeStepSound = 999;
            }

            // Prevent from enabling flashlight, but try to toggle ZP's nightvision
            if ( pPlayer.pev.impulse == 100 )
            {
                ZP_CommandCallback_NightVision( pPlayer );
                pPlayer.pev.impulse = 0;
            }
        }

        if ( g_bFrozen[idx] )
        {
            pPlayer.pev.velocity = g_vecZero;
            pPlayer.SetMaxSpeedOverride( 1 );
            // pPlayer.pev.maxspeed = 1.0f;
        }
        else if ( g_bIsZombie[idx] )
        {
            if ( g_iClassType[idx] == ZP_ZOMBIE_DEFAULT )
            {
                CZombieClass@ zombieClass = g_zombieClasses[ g_iCurrentZombieClass[idx] ];

                pPlayer.SetMaxSpeedOverride( zombieClass.m_iSpeed );
                pPlayer.pev.gravity = zombieClass.m_flGravity;
            }
            else if ( g_iClassType[idx] == ZP_ZOMBIE_NEMESIS )
            {
                pPlayer.SetMaxSpeedOverride( ZP_NEMESIS_SPEED );
                pPlayer.pev.gravity = ZP_NEMESIS_GRAVITY;

                if ( ZP_LEAP_NEMESIS )
                {
                    if ( g_Engine.time - g_flLastLeapTime[idx] >= ZP_LEAP_NEMESIS_COOLDOWN )
                    {
                        if ( ( pPlayer.pev.flags & FL_ONGROUND != 0 ) && ( pPlayer.pev.button & (IN_JUMP | IN_DUCK) == (IN_JUMP | IN_DUCK) ) && UTIL_VectorLengthSqr(pPlayer.pev.velocity) >= 80.0f * 80.0f )
                        {
                            Vector vecDir;
                            Vector vecAngles = pPlayer.pev.v_angle;

                            vecAngles.x = 0.0f;

                            g_EngineFuncs.AngleVectors( vecAngles, vecDir, void, void );

                            vecDir = vecDir * ZP_LEAP_NEMESIS_FORCE;
                            vecDir.z = ZP_LEAP_NEMESIS_HEIGHT;

                            pPlayer.pev.velocity = vecDir;

                            g_flLastLeapTime[idx] = g_Engine.time;
                        }
                    }
                }
            }
            else // Assassin
            {
                pPlayer.SetMaxSpeedOverride( ZP_ASSASSIN_SPEED );
                pPlayer.pev.gravity = ZP_ASSASSIN_GRAVITY;
            }
        }
        else
        {
            if ( g_iClassType[idx] == ZP_HUMAN_DEFAULT )
            {
                if ( ZP_HUMAN_SPEED > 0.0f )
                    pPlayer.SetMaxSpeedOverride( ZP_HUMAN_SPEED );
                
                pPlayer.pev.gravity = ZP_HUMAN_GRAVITY;
            }
            else if ( g_iClassType[idx] == ZP_HUMAN_SURVIVOR )
            {
                pPlayer.SetMaxSpeedOverride( ZP_SURVIVOR_SPEED );
                pPlayer.pev.gravity = ZP_SURVIVOR_GRAVITY;
            }
            else // Sniper
            {
                pPlayer.SetMaxSpeedOverride( ZP_SNIPER_SPEED );
                pPlayer.pev.gravity = ZP_SNIPER_GRAVITY;
            }
        }
    }
    else if ( pPlayer.pev.impulse == 100 )
    {
        ZP_CommandCallback_NightVision( pPlayer );
        pPlayer.pev.impulse = 0;
    }

    @g_pCurrentWeapon[idx] = pWeapon;

    return HOOK_CONTINUE;
}

//-----------------------------------------------------------------------------
// OnPlayerPostThink Hook
//-----------------------------------------------------------------------------

HookReturnCode OnPlayerPostThink( CBasePlayer@ pPlayer )
{
    if ( !g_bEnabled )
        return HOOK_CONTINUE;

    if ( ZP_ANTIBUNNYHOP )
        UTIL_AntiBunnyhop( pPlayer );

    return HOOK_CONTINUE;
}

//-----------------------------------------------------------------------------
// OnPlayerUse Hook
//-----------------------------------------------------------------------------

HookReturnCode OnPlayerUse( CBasePlayer@ pPlayer, uint& out uiFlags )
{
    if ( !g_bEnabled )
        return HOOK_CONTINUE;

    // Detonate nade with satchel mode
    if ( g_bAlive[pPlayer.entindex()] && pPlayer.m_afButtonPressed & IN_USE != 0 )
    {
		for (uint i = 0; i < g_pCustomGrenades.length(); i++)
        {
            if ( g_EntityFuncs.IsValidEntity( g_pCustomGrenades[i] ) )
            {
                CBaseEntity@ pEntity = g_EntityFuncs.Instance( g_pCustomGrenades[i] );

                if ( pEntity.pev.iuser2 == NADE_MODE_SATCHEL && pEntity.pev.iuser4 == 1 )
                {
                    if ( pEntity.pev.owner is pPlayer.pev.pContainingEntity )
                    {
                        pEntity.pev.iuser2 = NADE_MODE_NORMAL;
                        pEntity.pev.iuser4 = 0;
                        pEntity.pev.dmgtime = g_Engine.time;
                        break;
                    }
                }
            }
        }
	}

    return HOOK_CONTINUE;
}

//-----------------------------------------------------------------------------
// OnPlayerSpawn Hook
//-----------------------------------------------------------------------------

HookReturnCode OnPlayerSpawn( CBasePlayer@ pPlayer )
{
    if ( !g_bEnabled )
        return HOOK_CONTINUE;

    if ( g_bDebug ) zp_log("OnPlayerSpawn(): " + pPlayer.pev.netname);

    int idx = pPlayer.entindex();

    if ( g_bFirstConnect[idx] )
    {
        ZP_SavePlayerModel( pPlayer );
        g_bFirstConnect[idx] = false;

        return HOOK_HANDLED;
    }

    pPlayer.SetMaxSpeedOverride( ZP_HUMAN_SPEED );

    if ( g_iGameState >= ZP_STATE_GAME_PREPARING )
    {
        if ( g_iGameState == ZP_STATE_GAME_PREPARING )
        {
            ZP_DeployHumanItems( pPlayer );
        }
        else if ( g_bKillLatePlayers )
        {
            ZP_ResetClientState( idx, false );

            pPlayer.Killed( pPlayer.pev, GIB_NEVER );
			pPlayer.pev.solid = SOLID_NOT;
			pPlayer.pev.deadflag = DEAD_DEAD;
			pPlayer.pev.effects |= EF_NODRAW;

            g_bNightvision[idx] = true;
        }
    }
    else if ( g_bZombieEscape )
    {
        pPlayer.pev.flags |= FL_FROZEN;
    }

    return HOOK_HANDLED;
}

//-----------------------------------------------------------------------------
// OnClientPutInServer Hook
//-----------------------------------------------------------------------------

HookReturnCode OnClientPutInServer( CBasePlayer@ pPlayer )
{
    if ( g_bDebug ) zp_log("OnClientPutInServer(): " + pPlayer.pev.netname);

    int idx = pPlayer.entindex();

    g_flCommandCooldown[idx] = 0.0f;
    g_flSwitchNadeModeTime[idx] = 0.0f;
    g_flDealenDamage[idx] = 0.0f;
    g_iNadeMode[idx] = NADE_MODE_NORMAL;

    if ( !g_bEnabled )
        return HOOK_CONTINUE;

    RTV_OnClientPutInServer( pPlayer );
    
    UTIL_Fog( pPlayer, zp_fog.GetInt(), ZP_FOG_COLOR_R, ZP_FOG_COLOR_G, ZP_FOG_COLOR_B, ZP_FOG_START_DIST, ZP_FOG_END_DIST );

    if ( !g_bFirstConnect[idx] )
    {
        OnPlayerSpawn( pPlayer );
    }

    if ( !ZP_LoadStats(pPlayer) )
    {
        g_iAmmopacks[idx] = ZP_START_AMMO_PACKS;
        g_iZombieClass[idx] = ZP_CLASS_CLASSIC_ZOMBIE;
        g_iCurrentZombieClass[idx] = ZP_CLASS_CLASSIC_ZOMBIE;
    }

    pPlayer.SetClassification( ZP_TEAM_HUMAN );
    pPlayer.SetMaxSpeedOverride( ZP_HUMAN_SPEED );

    if ( g_iGameState == ZP_STATE_HIBERNATION )
    {
        g_iGameState = ZP_STATE_WAITING_PLAYERS;
        @Scheduler_InitNewGame = g_Scheduler.SetTimeout("ZP_InitNewGame", ZP_WAITING_PLAYERS_TIME);
    }
    else if ( g_iGameState == ZP_STATE_GAME_PREPARING )
    {
        ZP_RespawnAsHuman( pPlayer, idx );
        g_iAliveHumans++;

        UTIL_UpdateScoreInfo( pPlayer.edict() );
    }
    else
    {
        ZP_ResetClientState( idx );

        if ( g_iGameState == ZP_STATE_GAME_STARTED && (g_iGameMode == ZP_MODE_SINGLE_INFECTION || g_iGameMode == ZP_MODE_MULTIPLE_INFECTION) && ( g_bZombieEscape || g_iAllowedRespawns > 0 ) )
        {
            pPlayer.SetClassification( ZP_TEAM_ZOMBIE );

            g_bIsHuman[idx] = false;
            g_bIsZombie[idx] = true;
            g_bAlive[idx] = false;
            g_iClassType[idx] = ZP_ZOMBIE_DEFAULT;

            g_flRespawnTime[idx] = g_Engine.time + ( g_bZombieEscape ? ZP_ZE_ZOMBIE_RESPAWN_DELAY : ZP_ZOMBIE_RESPAWN_DELAY );

            if ( !g_bZombieEscape )
                g_iAllowedRespawns--;

            UTIL_UpdateScoreInfo( pPlayer.edict() );
        }
    }

    ZP_SavePlayerModel( pPlayer );
    g_bFirstConnect[idx] = false;

    return HOOK_HANDLED;
}

//-----------------------------------------------------------------------------
// OnClientDisconnect Hook
//-----------------------------------------------------------------------------

HookReturnCode OnClientDisconnect( CBasePlayer@ pPlayer )
{
    if ( !g_bEnabled )
        return HOOK_CONTINUE;

    if ( g_bDebug ) zp_log("OnClientDisconnect(): " + pPlayer.pev.netname);

    int idx = pPlayer.entindex();

    ZP_SaveStats( pPlayer );

    if ( g_bAlive[idx] )
    {
        if ( g_bIsHuman[idx] )
        {
            g_iAliveHumans--;
        }
        else if ( g_bIsZombie[idx] )
        {
            g_iAliveZombies--;
        }

        // Infect a random player
        if ( g_iAliveZombies == 0 && g_iAliveHumans > 1 && g_iGameState == ZP_STATE_GAME_STARTED && ( g_iGameMode == ZP_MODE_SINGLE_INFECTION || g_iGameMode == ZP_MODE_MULTIPLE_INFECTION ) )
        {
            int human = UTIL_PickRandomHuman();

            if ( human != -1 )
            {
                ZP_InfectHuman( g_PlayerFuncs.FindPlayerByIndex(human), null );
            }
        }

        // No need?
        if ( g_iGameState == ZP_STATE_GAME_STARTED )
            ZP_CheckTeams();
    }

    ZP_ResetClientState( idx );
    g_bFirstConnect[ idx ] = true;

    return HOOK_CONTINUE;
}

//-----------------------------------------------------------------------------
// OnClientSay Hook
//-----------------------------------------------------------------------------

HookReturnCode OnClientSay(SayParameters@ pParams)
{
    if ( !g_bEnabled )
        return HOOK_CONTINUE;

	string sMessage = pParams.GetCommand();

	sMessage.ToLowercase();

    if ( sMessage == "rtv" )
        RTV_Command( pParams.GetPlayer(), false );
    else if ( sMessage == "unrtv" )
        RTV_Command( pParams.GetPlayer(), true );

    for (uint i = 0; i < g_userCommands.length(); i++)
    {
        if ( g_userCommands[ i ].m_sChatCommand == sMessage )
        {
            CBasePlayer@ pPlayer = pParams.GetPlayer();
            CUserCommand@ pCommand = g_userCommands[ i ];

            if ( UTIL_CanUseCommand( pPlayer ) )
            {
                pCommand.m_pfnCommandCallback( pPlayer );

                UTIL_CooldownCommand( pPlayer );
            }

            pParams.ShouldHide = pCommand.m_bHide;
            return HOOK_CONTINUE;
        }
    }

	return HOOK_CONTINUE;
}

//-----------------------------------------------------------------------------
// Purpose: plugin load
//-----------------------------------------------------------------------------

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor("Sw1ft");
	g_Module.ScriptInfo.SetContactInfo("https://steamcommunity.com/profiles/76561198397776991");

    // Init CS16 Weapons
    CS16_PluginInit();

    // Register Hooks
    ZP_RegisterHooksOnce();

    // Init CVars
    ZP_RegisterCVars();

    // Register Stuff
    ZP_RegisterUserCommands();
    ZP_RegisterZombieClasses();
    ZP_RegisterExtras();
    ZP_RegisterWeaponsMenu();

    // Init RTV
    RTV_PluginInit();
}

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//
//                                 Utils
//
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Purpose: anti bunnyhop; it works as an util I think??
//-----------------------------------------------------------------------------

void UTIL_AntiBunnyhop(CBasePlayer@ pPlayer)
{
    bool bOnGround = ( pPlayer.pev.flags & FL_ONGROUND != 0 );

    if ( bOnGround && !g_bOnGround[ pPlayer.entindex() ] )
    {
        if ( ( pPlayer.pev.flags & FL_DUCKING ) == 0 )
        {
            float flMaxSpeedSqr = pPlayer.pev.maxspeed * pPlayer.pev.maxspeed;

            if ( UTIL_VectorLengthSqr( pPlayer.pev.velocity ) > flMaxSpeedSqr )
            {
                float flSpeed = pPlayer.pev.velocity.Length();

                flSpeed *= ZP_ANTIBUNNYHOP_SLOWDOWN_FACTOR;

                if ( flSpeed < pPlayer.pev.maxspeed )
                    flSpeed = pPlayer.pev.maxspeed;
                
                pPlayer.pev.velocity = pPlayer.pev.velocity.Normalize() * flSpeed;
            }
        }
        else
        {
            float flMaxSpeedDucked = pPlayer.pev.maxspeed * 1.0 / 3.0;
            float flMaxSpeedDuckedSqr = flMaxSpeedDucked * flMaxSpeedDucked;

            if ( UTIL_VectorLengthSqr( pPlayer.pev.velocity ) > flMaxSpeedDuckedSqr )
            {
                float flSpeed = pPlayer.pev.velocity.Length();

                flSpeed *= ZP_ANTIBUNNYHOP_DUCK_SLOWDOWN_FACTOR;

                if ( flSpeed < flMaxSpeedDucked )
                    flSpeed = flMaxSpeedDucked;
                
                pPlayer.pev.velocity = pPlayer.pev.velocity.Normalize() * flSpeed;
            }
        }
    }

    g_bOnGround[ pPlayer.entindex() ] = bOnGround;
}

//-----------------------------------------------------------------------------
// Purpose: show received / dealt damage on the Player's screen
//-----------------------------------------------------------------------------

void UTIL_ShowDamage(CBasePlayer@ pPlayer, CBasePlayer@ pAttacker, int iDamage)
{
    string sDamage = string( iDamage );

    if ( pPlayer !is null && pPlayer.pev.fuser3 <= g_Engine.time )
    {
        UTIL_HudMessage( pPlayer, sDamage, 255, 0, 0, 0.45, 0.5, 2, 0.1f, 4.0f, 0.1f, 0.1f, HUD_CHAN_COUNTDOWN );
        pPlayer.pev.fuser3 = g_Engine.time + 0.2f;
    }

    if ( pAttacker !is null && pAttacker.pev.fuser3 <= g_Engine.time )
    {
        UTIL_HudMessage( pAttacker, sDamage, 0, 100, 200, -1, 0.55, 2, 0.1f, 4.0f, 0.02f, 0.02f, HUD_CHAN_COUNTDOWN );
        pAttacker.pev.fuser3 = g_Engine.time + 0.2f;
    }
}

//-----------------------------------------------------------------------------
// Purpose: remove entity by its handle
//-----------------------------------------------------------------------------

void UTIL_RemoveEntityByEHandle(EHandle hEntity)
{
    CBaseEntity@ pEntity = hEntity.GetEntity();

    if ( pEntity !is null )
    {
        g_EntityFuncs.Remove( pEntity );
    }
}

//-----------------------------------------------------------------------------
// Purpose: picks a random Human player
//-----------------------------------------------------------------------------

int UTIL_PickRandomHuman()
{
    array<int> aPlayers;

    // Collect players
    for (int i = 1; i <= g_Engine.maxClients; i++)
    {
        if ( g_bAlive[i] && g_bIsHuman[i] )
        {
            aPlayers.insertLast(i);
        }
    }

    if ( aPlayers.length() > 0 )
    {
        int index;

        if ( aPlayers.length() > 1 )
            index = aPlayers[ RandomInt(0, aPlayers.length() - 1) ]; // choose random player
        else
            index = aPlayers[ 0 ];
        
        return index;
    }

    return -1;
}

//-----------------------------------------------------------------------------
// Purpose: create blast of 3 rings
//-----------------------------------------------------------------------------

void UTIL_CreateBlastRing(Vector vecOrigin, int smallest_r, int smallest_g, int smallest_b, int medium_r, int medium_g, int medium_b, int largest_r, int largest_g, int largest_b)
{
	// Smallest ring
    NetworkMessage message( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecOrigin, null );
        message.WriteByte( TE_BEAMCYLINDER ); // TE id
        message.WriteCoord( vecOrigin.x ); // x
        message.WriteCoord( vecOrigin.y ); // y
        message.WriteCoord( vecOrigin.z ); // z
        message.WriteCoord( vecOrigin.x ); // x axis
        message.WriteCoord( vecOrigin.y ); // y axis
        message.WriteCoord( vecOrigin.z + 385.0f ); // z axis
        message.WriteShort( g_exploSpr ); // sprite
        message.WriteByte( 0 ); // startframe
        message.WriteByte( 0 ); // framerate
        message.WriteByte( 4 ); // life
        message.WriteByte( 60 ); // width 
        message.WriteByte( 0 ); // noise
        message.WriteByte( smallest_r ); // red
        message.WriteByte( smallest_g ); // green
        message.WriteByte( smallest_b ); // blue
        message.WriteByte( 200 ); // brightness
        message.WriteByte( 0 ); // speed
    message.End();
	
	// Medium ring
    NetworkMessage message2( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecOrigin, null );
        message2.WriteByte( TE_BEAMCYLINDER ); // TE id
        message2.WriteCoord( vecOrigin.x ); // x
        message2.WriteCoord( vecOrigin.y ); // y
        message2.WriteCoord( vecOrigin.z ); // z
        message2.WriteCoord( vecOrigin.x ); // x axis
        message2.WriteCoord( vecOrigin.y ); // y axis
        message2.WriteCoord( vecOrigin.z + 470.0f ); // z axis
        message2.WriteShort( g_exploSpr ); // sprite
        message2.WriteByte( 0 ); // startframe
        message2.WriteByte( 0 ); // framerate
        message2.WriteByte( 4 ); // life
        message2.WriteByte( 60 ); // width 
        message2.WriteByte( 0 ); // noise
        message2.WriteByte( medium_r ); // red
        message2.WriteByte( medium_g ); // green
        message2.WriteByte( medium_b ); // blue
        message2.WriteByte( 200 ); // brightness
        message2.WriteByte( 0 ); // speed
    message2.End();
	
	// Largest ring
    NetworkMessage message3( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecOrigin, null );
        message3.WriteByte( TE_BEAMCYLINDER ); // TE id
        message3.WriteCoord( vecOrigin.x ); // x
        message3.WriteCoord( vecOrigin.y ); // y
        message3.WriteCoord( vecOrigin.z ); // z
        message3.WriteCoord( vecOrigin.x ); // x axis
        message3.WriteCoord( vecOrigin.y ); // y axis
        message3.WriteCoord( vecOrigin.z + 555.0f ); // z axis
        message3.WriteShort( g_exploSpr ); // sprite
        message3.WriteByte( 0 ); // startframe
        message3.WriteByte( 0 ); // framerate
        message3.WriteByte( 4 ); // life
        message3.WriteByte( 60 ); // width 
        message3.WriteByte( 0 ); // noise
        message3.WriteByte( largest_r ); // red
        message3.WriteByte( largest_g ); // green
        message3.WriteByte( largest_b ); // blue
        message3.WriteByte( 200 ); // brightness
        message3.WriteByte( 0 ); // speed
    message3.End();
}

//-----------------------------------------------------------------------------
// Purpose: create ring
//-----------------------------------------------------------------------------

void UTIL_CreateRing(Vector vecOrigin, Vector iDontKnow, int iLife, int iWidth, int iBrightness, int r, int g, int b)
{
    NetworkMessage message( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecOrigin, null );
        message.WriteByte( TE_BEAMCYLINDER ); // TE id
        message.WriteCoord( vecOrigin.x ); // x
        message.WriteCoord( vecOrigin.y ); // y
        message.WriteCoord( vecOrigin.z ); // z
        message.WriteCoord( iDontKnow.x ); // x axis
        message.WriteCoord( iDontKnow.y ); // y axis
        message.WriteCoord( iDontKnow.z + 385.0f ); // z axis
        message.WriteShort( g_exploSpr ); // sprite
        message.WriteByte( 0 ); // startframe
        message.WriteByte( 0 ); // framerate
        message.WriteByte( iLife ); // life
        message.WriteByte( 60 ); // width 
        message.WriteByte( 0 ); // noise
        message.WriteByte( r ); // red
        message.WriteByte( g ); // green
        message.WriteByte( b ); // blue
        message.WriteByte( iBrightness ); // brightness
        message.WriteByte( 0 ); // speed
    message.End();
}

//-----------------------------------------------------------------------------
// Purpose: make a blood decal
//-----------------------------------------------------------------------------

void UTIL_MakeBlood(CBasePlayer@ pPlayer)
{
    if ( (pPlayer.pev.flags & FL_ONGROUND == 0) || UTIL_VectorLengthSqr(pPlayer.pev.velocity) < 80.0f * 80.0f )
        return;

    Vector vecOrigin = pPlayer.pev.origin;

    if ( pPlayer.pev.flags & FL_DUCKING != 0 )
    {
        vecOrigin.z -= 18.0f;
    }
    else
    {
        vecOrigin.z -= 36.0f;
    }

    NetworkMessage message( MSG_PAS, NetworkMessages::SVC_TEMPENTITY, vecOrigin, null );
        message.WriteByte( TE_WORLDDECAL ); // TE id
        message.WriteCoord( vecOrigin.x ); // x
        message.WriteCoord( vecOrigin.y ); // y
        message.WriteCoord( vecOrigin.z ); // z
        message.WriteByte( ZP_ZOMBIE_DECAL_BLOOD[ RandomInt(0, ZP_ZOMBIE_DECAL_BLOOD.length() - 1) ] ); // decal number
    message.End();
}

//-----------------------------------------------------------------------------
// Purpose: gets a random string from a given array
//-----------------------------------------------------------------------------

string UTIL_GetRandomStringFromArray(array<string> arr)
{
    return arr[ RandomInt(0, arr.length() - 1) ];
}

//-----------------------------------------------------------------------------
// Purpose: sets render mode on entity
//-----------------------------------------------------------------------------

void UTIL_SetRenderMode(CBaseEntity@ pEntity, int renderfx, Vector color, int rendermode, float renderamt)
{
    pEntity.pev.renderfx = renderfx;
    pEntity.pev.rendercolor = color;
    pEntity.pev.rendermode = rendermode;
    pEntity.pev.renderamt = renderamt;
}

//-----------------------------------------------------------------------------
// Purpose: sets the following beam on entity
//-----------------------------------------------------------------------------

void UTIL_SetTrail(CBaseEntity@ pEntity, int sprite, int r, int g, int b, int width, int brightness, int life)
{
    NetworkMessage message( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
		message.WriteByte( TE_BEAMFOLLOW ); // TE id
		message.WriteShort( pEntity.entindex() ); // entity
		message.WriteShort( sprite ); // sprite
		message.WriteByte( life ); // life
		message.WriteByte( width ); // width
		message.WriteByte( r ); // r
		message.WriteByte( g ); // g
		message.WriteByte( b ); // b
		message.WriteByte( brightness ); // brightness
	message.End();
}

//-----------------------------------------------------------------------------
// Purpose: sets the following beam on entity
//-----------------------------------------------------------------------------

void UTIL_Fog(CBasePlayer@ pPlayer, int iEnable, int r, int g, int b, int iStartDistance, int iEndDistance)
{
    NetworkMessage message( MSG_ONE, NetworkMessages::Fog, pPlayer.edict() );
		message.WriteShort( 0 );
		message.WriteByte( iEnable );
		message.WriteCoord( 0.0f );
		message.WriteCoord( 0.0f );
		message.WriteCoord( 0.0f );
        message.WriteShort( 0 );
        message.WriteByte( r );
        message.WriteByte( g );
        message.WriteByte( b );
        message.WriteShort( iStartDistance );
        message.WriteShort( iEndDistance );
	message.End();
}

//-----------------------------------------------------------------------------
// Purpose: sets the following beam on entity
//-----------------------------------------------------------------------------

void UTIL_FogAll(int iEnable, int r, int g, int b, int iStartDistance, int iEndDistance)
{
    NetworkMessage message( MSG_BROADCAST, NetworkMessages::Fog );
		message.WriteShort( 0 );
		message.WriteByte( iEnable );
		message.WriteCoord( 0.0f );
		message.WriteCoord( 0.0f );
		message.WriteCoord( 0.0f );
        message.WriteShort( 0 );
        message.WriteByte( r );
        message.WriteByte( g );
        message.WriteByte( b );
        message.WriteShort( iStartDistance );
        message.WriteShort( iEndDistance );
	message.End();
}

//-----------------------------------------------------------------------------
// Purpose: update score info about the given player
//-----------------------------------------------------------------------------

void UTIL_UpdateScoreInfo(edict_t@ pEdict)
{
    for (int i = 1; i <= g_Engine.maxClients; i++)
    {
        CBasePlayer@ plr = g_PlayerFuncs.FindPlayerByIndex(i);
    
        if ( plr !is null && plr.IsConnected() )
        {
            plr.SendScoreInfo( pEdict );
        }
    }
}

//-----------------------------------------------------------------------------
// Purpose: update score info for all players
//-----------------------------------------------------------------------------

void UTIL_UpdateScoreInfoAll()
{
    for (int i = 1; i <= g_Engine.maxClients; i++)
    {
        CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
		
		if ( pPlayer !is null && pPlayer.IsConnected() )
		{
            pPlayer.SendScoreInfo( null );
        }
    }
}

//-----------------------------------------------------------------------------
// Purpose: send a hud message to a player
//-----------------------------------------------------------------------------

void UTIL_HudMessage(CBasePlayer@ pPlayer, const string& in sMessage, int r, int g, int b, float x, float y, int effect, float fxTime, float holdTime, float fadeinTime, float fadeoutTime, int channel)
{
    HUDTextParams params;

    params.r1 = params.r2 = r;
    params.g1 = params.g2 = g;
    params.b1 = params.b2 = b;

    params.x = x;
    params.y = y;

    params.effect = effect;
    params.fxTime = fxTime;
    params.holdTime = holdTime;
    params.fadeinTime = fadeinTime;
    params.fadeoutTime = fadeoutTime;

    params.channel = channel;

    g_PlayerFuncs.HudMessage( pPlayer, params, sMessage );
}

//-----------------------------------------------------------------------------
// Purpose: send a hud message to all players
//-----------------------------------------------------------------------------

void UTIL_HudMessageAll(const string& in sMessage, int r, int g, int b, float x, float y, int effect, float fxTime, float holdTime, float fadeinTime, float fadeoutTime, int channel)
{
    HUDTextParams params;

    params.r1 = params.r2 = r;
    params.g1 = params.g2 = g;
    params.b1 = params.b2 = b;

    params.x = x;
    params.y = y;

    params.effect = effect;
    params.fxTime = fxTime;
    params.holdTime = holdTime;
    params.fadeinTime = fadeinTime;
    params.fadeoutTime = fadeoutTime;

    params.channel = channel;

    g_PlayerFuncs.HudMessageAll( params, sMessage );
}

//-----------------------------------------------------------------------------
// Purpose: send a hud message to all players
//-----------------------------------------------------------------------------

void UTIL_HudMessageAll(edict_t@ pEdict, string sCommand)
{
    NetworkMessage message( MSG_ONE_UNRELIABLE, NetworkMessages::SVC_STUFFTEXT, pEdict );
		message.WriteString( sCommand );
	message.End();
}

//-----------------------------------------------------------------------------
// Purpose: send client command to a player
//-----------------------------------------------------------------------------

void UTIL_ClientCommand(edict_t@ pEdict, string sCommand)
{
    NetworkMessage message( MSG_ONE_UNRELIABLE, NetworkMessages::SVC_STUFFTEXT, pEdict );
		message.WriteString( sCommand );
	message.End();
}

//-----------------------------------------------------------------------------
// Purpose: send client command to all players
//-----------------------------------------------------------------------------

void UTIL_ClientCommandAll(string sCommand)
{
    NetworkMessage message( MSG_BROADCAST, NetworkMessages::SVC_STUFFTEXT );
		message.WriteString( sCommand );
	message.End();
}

//-----------------------------------------------------------------------------
// Purpose: deal damage to a Player without any boosting
//-----------------------------------------------------------------------------

void UTIL_TakeDamageNoBoost(CBasePlayer@ pPlayer, DamageInfo@ pDamageInfo)
{
    float newHealth = pPlayer.pev.health - pDamageInfo.flDamage;

    if ( newHealth <= 0.0f )
    {
        pPlayer.pev.health = 1.0f;
        pDamageInfo.flDamage = 1.0f;
    }
    else
    {
        pPlayer.pev.health = newHealth;
        pDamageInfo.flDamage = 0.0f;
    }
}

//-----------------------------------------------------------------------------
// Purpose: decide flinch for pain shock
//-----------------------------------------------------------------------------

bool UTIL_ShouldDoLargeFlinch(CBasePlayer@ pPlayer, int iWeaponID)
{
    if ( pPlayer.pev.flags & FL_DUCKING != 0 )
        return false;
    
    switch (iWeaponID)
    {
        case WEAPON_SHOTGUN:
        case WEAPON_M16:
        case WEAPON_RPG:
        case WEAPON_GAUSS:
        case WEAPON_EGON:
        case WEAPON_MINIGUN:
        case WEAPON_SNIPERRIFLE:
        case WEAPON_M249:
        case WEAPON_DISPLACER:
            return true;
    }

    return false;
}

//-----------------------------------------------------------------------------
// Purpose: plays sound on all players
//-----------------------------------------------------------------------------

void UTIL_PlaySound(string sSound)
{
    string sCommand = "spk " + sSound;

    // Play notification
    UTIL_ClientCommandAll( sCommand );
}

//-----------------------------------------------------------------------------
// Purpose: Line-AABB intersection test
//-----------------------------------------------------------------------------

bool UTIL_IsLineIntersectingAABB(const Vector p1, const Vector p2, const Vector vecBoxMins, const Vector vecBoxMaxs)
{
	Vector vecLineDir = (p2 - p1) * 0.5f;
	Vector vecBoxMid = (vecBoxMaxs - vecBoxMins) * 0.5f;
	Vector p3 = p1 + vecLineDir - (vecBoxMins + vecBoxMaxs) * 0.5f;
	Vector vecAbsLineMid = Vector(abs(vecLineDir.x), abs(vecLineDir.y), abs(vecLineDir.z));
	
	if ( abs(p3.x) > vecBoxMid.x + vecAbsLineMid.x || abs(p3.y) > vecBoxMid.y + vecAbsLineMid.y || abs(p3.z) > vecBoxMid.z + vecAbsLineMid.z )
		return false;
	
	if ( abs(vecLineDir.y * p3.z - vecLineDir.z * p3.y) > vecBoxMid.y * vecAbsLineMid.z + vecBoxMid.z * vecAbsLineMid.y )
		return false;
	
	if ( abs(vecLineDir.z * p3.x - vecLineDir.x * p3.z) > vecBoxMid.z * vecAbsLineMid.x + vecBoxMid.x * vecAbsLineMid.z )
		return false;
	
	if ( abs(vecLineDir.x * p3.y - vecLineDir.y * p3.x) > vecBoxMid.x * vecAbsLineMid.y + vecBoxMid.y * vecAbsLineMid.x )
		return false;
	
	return true;
}

//-----------------------------------------------------------------------------
// Purpose: yeah it's so cool not to add squared length of the vector in the AS API, fucking genius
//-----------------------------------------------------------------------------

float UTIL_VectorLengthSqr(const Vector v)
{
	return v.x * v.x + v.y * v.y + v.z * v.z;
}

//-----------------------------------------------------------------------------
// Purpose: linear interpolation
//-----------------------------------------------------------------------------

float UTIL_Lerp(float a, float b, float dt)
{
	return a + (b - a) * dt;
}

//-----------------------------------------------------------------------------
// Purpose: add cooldown for client when they used a client command; should prevent possible lag exploits
//-----------------------------------------------------------------------------

void UTIL_CooldownCommand(CBasePlayer@ pPlayer)
{
    g_flCommandCooldown[pPlayer.entindex()] = g_Engine.time + 0.1f; // 100 ms cooldown
}

//-----------------------------------------------------------------------------
// Purpose: checks if client can use any client command at this time
//-----------------------------------------------------------------------------

bool UTIL_CanUseCommand(CBasePlayer@ pPlayer)
{
    return g_flCommandCooldown[pPlayer.entindex()] <= g_Engine.time;
}

//-----------------------------------------------------------------------------
// Purpose: gets nade mode as string
//-----------------------------------------------------------------------------

string UTIL_GetNadeModeAsString(int mode)
{
    switch ( mode )
    {
        case NADE_MODE_NORMAL:
        {
            return "Normal";
        }
        
        case NADE_MODE_PROXIMITY:
        {
            return "Proximity";
        }
        
        case NADE_MODE_IMPACT:
        {
            return "Impact";
        }
        
        case NADE_MODE_TRIP:
        {
            return "Trip laser";
        }
        
        case NADE_MODE_MOTION:
        {
            return "Motion sensor";
        }
        
        case NADE_MODE_SATCHEL:
        {
            return "Satchel charge";
        }
        
        case NADE_MODE_HOMING:
        {
            return "Homing";
        }
    }

    return "Unknown";
}

//-----------------------------------------------------------------------------
// Purpose: gets random integer inclusive
//-----------------------------------------------------------------------------

int RandomInt(int min, int max)
{
    return Math.RandomLong(min, max); // valve's pity random
}

//-----------------------------------------------------------------------------
// Purpose: gets random float inclusive
//-----------------------------------------------------------------------------

float RandomFloat(float min, float max)
{
    return Math.RandomFloat(min, max);
}

//-----------------------------------------------------------------------------
// Purpose: debugging
//-----------------------------------------------------------------------------

void zp_log(string msg)
{
    string log = "[ZP Debug] " + msg + "\n";

    g_Game.AlertMessage(at_logged, log);
    g_PlayerFuncs.ClientPrintAll(HUD_PRINTTALK, log);
}

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//
//                                  Menus
//
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Purpose: main menu
//-----------------------------------------------------------------------------

void ZP_MainMenuCallback(CTextMenu@ pMenu, CBasePlayer@ pPlayer, int itemNumber, const CTextMenuItem@ pItem)
{
	if ( pItem is null || pPlayer is null || !pPlayer.IsConnected() )
		return;
    
    int idx = pPlayer.entindex();

	int iItem = 0;
	pItem.m_pUserData.retrieve( iItem );

	if ( iItem == 1 )
	{
		if ( g_bDebug ) zp_log("ZP_MainMenuCallback(): Buy Weapons");

        if ( !g_bAlive[idx] || !g_bIsHuman[idx] || g_iClassType[idx] != ZP_HUMAN_DEFAULT )
        {
            g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] You cannot buy weapons right now.\n" );
            return;
        }

        if ( !g_bCanBuyPrimaryWeapons[idx] && !g_bCanBuySecondaryWeapons[idx] )
        {
            g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] You already have weapons.\n" );
            return;
        }

        if ( g_bCanBuyPrimaryWeapons[idx] )
        {
            ZP_OpenPrimaryWeaponsMenu( EHandle(pPlayer) );
        }
        else
        {
            ZP_OpenSecondaryWeaponsMenu( EHandle(pPlayer) );
        }
	}
	else if ( iItem == 2 )
	{
		if ( g_bDebug ) zp_log("ZP_MainMenuCallback(): Extras");

        if ( ZP_Extras_IsAllowed(pPlayer) && ZP_Extras_IsAlive(pPlayer) )
        {
            if ( g_bIsHuman[idx] )
            {
                if ( ZP_Extras_IsHumanAllowedToBuy(pPlayer) )
                    ZP_OpenHumanExtrasMenu( EHandle(pPlayer) );
            }
            else if ( g_bIsZombie[idx] )
            {
                if ( ZP_Extras_IsZombieAllowedToBuy(pPlayer) )
                    ZP_OpenZombieExtrasMenu( EHandle(pPlayer) );
            }
        }
	}
	else if ( iItem == 3 )
	{
        if ( g_bDebug ) zp_log("ZP_MainMenuCallback(): Zombie Class");

        ZP_OpenChooseClassMenu( EHandle(pPlayer) );
	}
	else if ( iItem == 4 )
    {
        if ( g_bDebug ) zp_log("ZP_MainMenuCallback(): Extras Management");

        ZP_OpenExtrasManagementMenu( EHandle(pPlayer) );
    }
	else if ( iItem == 5 )
    {
        UTIL_ClientCommand( pPlayer.edict(), "unstuck" );
    }
	else if ( iItem == 6 )
	{
        // TODO: help info
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] Unavailable command.\n" );
	}
	else if ( iItem == 7 )
	{
        // TODO: admin menu
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] You have no access.\n" );
	}
	
	// g_Scheduler.SetTimeout("ZP_OpenMainMenu", 0.0f, EHandle(pPlayer));
}

void ZP_OpenMainMenu(EHandle hPlayer)
{
	CBasePlayer@ pPlayer = cast<CBasePlayer@>(hPlayer.GetEntity());
	
	if ( pPlayer is null )
		return;

	const int idx = pPlayer.entindex();

	// Is it necessary?
	if ( g_MainMenu[idx] !is null && g_MainMenu[idx].IsRegistered() )
	{
		g_MainMenu[idx].Unregister();
	}

	@g_MainMenu[idx] = CTextMenu( @ZP_MainMenuCallback );

	g_MainMenu[idx].SetTitle( "\\yZombie Plague BETA\\r" ); // Title

	g_MainMenu[idx].AddItem( "\\wBuy Weapons\\r", any(1) ); // Item name + Unique token
	g_MainMenu[idx].AddItem( "\\wBuy Extra Items\\r", any(2) );
	g_MainMenu[idx].AddItem( "\\wChoose Zombie Class\\r", any(3) );
	g_MainMenu[idx].AddItem( "\\wExtras Management\\r", any(4) );
	g_MainMenu[idx].AddItem( "\\wUnstuck\\r", any(5) );
	g_MainMenu[idx].AddItem( "\\wHelp\\r", any(6) );
	g_MainMenu[idx].AddItem( "\\wAdmin Menu\\y", any(7) );

	g_MainMenu[idx].Register();
	g_MainMenu[idx].Open(0, 0, pPlayer);
}

//-----------------------------------------------------------------------------
// Purpose: primary weapons menu
//-----------------------------------------------------------------------------

void ZP_PrimaryWeaponsMenuCallback(CTextMenu@ pMenu, CBasePlayer@ pPlayer, int itemNumber, const CTextMenuItem@ pItem)
{
	if ( pItem is null || pPlayer is null || !pPlayer.IsConnected() )
		return;
    
    int idx = pPlayer.entindex();

    if ( !g_bAlive[idx] || !g_bIsHuman[idx] || g_iClassType[idx] != ZP_HUMAN_DEFAULT )
    {
        g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] You cannot buy weapons right now.\n" );
        return;
    }

    if ( !g_bCanBuyPrimaryWeapons[idx] )
    {
        g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] You already have weapons.\n" );
        return;
    }

	string data = "";
	pItem.m_pUserData.retrieve(data);

	pPlayer.GiveNamedItem(data);
    g_bCanBuyPrimaryWeapons[pPlayer.entindex()] = false;

	ZP_OpenSecondaryWeaponsMenu( EHandle(pPlayer) );
}

void ZP_OpenPrimaryWeaponsMenu(EHandle hPlayer)
{
	CBasePlayer@ pPlayer = cast<CBasePlayer@>(hPlayer.GetEntity());
	
	if ( pPlayer is null )
		return;

	const int idx = pPlayer.entindex();

	// Is it necessary?
	if ( g_PrimaryWeaponsMenu[idx] !is null && g_PrimaryWeaponsMenu[idx].IsRegistered() )
	{
		g_PrimaryWeaponsMenu[idx].Unregister();
	}

	@g_PrimaryWeaponsMenu[idx] = CTextMenu( @ZP_PrimaryWeaponsMenuCallback );

	g_PrimaryWeaponsMenu[idx].SetTitle( "\\yPrimary Weapon\\r " ); // Title

	bool bOnePage = ( g_primaryWeapons.length() <= 9 );
	uint iLastItem = g_primaryWeapons.length() - 1;

	for (uint i = 0; i < g_primaryWeapons.length(); i++)
	{
		bool bLastItem; // last item in a single page

		if ( bOnePage )
		{
			bLastItem = ( iLastItem == i );
		}
		else
		{
			bLastItem = ( iLastItem == i || (i / 7 != (i + 1) / 7) );
		}

		string sItemName = "\\w" + g_primaryWeapons[i].m_sName + (bLastItem ? "\\y" : "\\r");

		g_PrimaryWeaponsMenu[idx].AddItem( sItemName, any(g_primaryWeapons[i].m_sEntityName) );
	}

	g_PrimaryWeaponsMenu[idx].Register();
	g_PrimaryWeaponsMenu[idx].Open(0, 0, pPlayer);
}

//-----------------------------------------------------------------------------
// Purpose: secondary weapons menu
//-----------------------------------------------------------------------------

void ZP_SecondaryWeaponsMenuCallback(CTextMenu@ pMenu, CBasePlayer@ pPlayer, int itemNumber, const CTextMenuItem@ pItem)
{
	if ( pItem is null || pPlayer is null || !pPlayer.IsConnected() )
		return;

    int idx = pPlayer.entindex();

    if ( !g_bAlive[idx] || !g_bIsHuman[idx] || g_iClassType[idx] != ZP_HUMAN_DEFAULT )
    {
        g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] You cannot buy weapons right now.\n" );
        return;
    }

    if ( !g_bCanBuySecondaryWeapons[idx] )
    {
        g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] You already have weapons.\n" );
        return;
    }

	string data = "";
	pItem.m_pUserData.retrieve(data);

	pPlayer.GiveNamedItem(data);
    g_bCanBuySecondaryWeapons[pPlayer.entindex()] = false;
}

void ZP_OpenSecondaryWeaponsMenu(EHandle hPlayer)
{
	CBasePlayer@ pPlayer = cast<CBasePlayer@>(hPlayer.GetEntity());
	
	if ( pPlayer is null )
		return;

	const int idx = pPlayer.entindex();

	// Is it necessary?
	if ( g_SecondaryWeaponsMenu[idx] !is null && g_SecondaryWeaponsMenu[idx].IsRegistered() )
	{
		g_SecondaryWeaponsMenu[idx].Unregister();
	}

	@g_SecondaryWeaponsMenu[idx] = CTextMenu( @ZP_SecondaryWeaponsMenuCallback );

	g_SecondaryWeaponsMenu[idx].SetTitle( "\\ySecondary Weapon\\r " ); // Title

	bool bOnePage = ( g_secondaryWeapons.length() <= 9 );
	uint iLastItem = g_secondaryWeapons.length() - 1;

	for (uint i = 0; i < g_secondaryWeapons.length(); i++)
	{
		bool bLastItem; // last item in a single page

		if ( bOnePage )
		{
			bLastItem = ( iLastItem == i );
		}
		else
		{
			bLastItem = ( iLastItem == i || (i / 7 != (i + 1) / 7) );
		}

		string sItemName = "\\w" + g_secondaryWeapons[i].m_sName + (bLastItem ? "\\y" : "\\r");

		g_SecondaryWeaponsMenu[idx].AddItem( sItemName, any(g_secondaryWeapons[i].m_sEntityName) );
	}

	g_SecondaryWeaponsMenu[idx].Register();
	g_SecondaryWeaponsMenu[idx].Open(0, 0, pPlayer);
}

//-----------------------------------------------------------------------------
// Purpose: zombie classes menu
//-----------------------------------------------------------------------------

void ZP_ChooseClassMenuCallback(CTextMenu@ pMenu, CBasePlayer@ pPlayer, int itemNumber, const CTextMenuItem@ pItem)
{
	if ( pItem is null || pPlayer is null || !pPlayer.IsConnected() )
		return;

	int iClassIndex = 0;
	pItem.m_pUserData.retrieve( iClassIndex );

    iClassIndex = iClassIndex - 1;

	if ( iClassIndex >= 0 && g_iZombieClass[ pPlayer.entindex() ] != iClassIndex && iClassIndex < int( g_zombieClasses.length() ) )
    {
        CZombieClass@ zombieClass = g_zombieClasses[ iClassIndex ];

        g_iZombieClass[ pPlayer.entindex() ] = iClassIndex;

        string sHealth = string( int(zombieClass.m_flHealth) );
        string sSpeed = string( zombieClass.m_iSpeed );
        string sGravity = string( int(zombieClass.m_flGravity * 800.0f) );
        string sKnockback = string( int(zombieClass.m_flKnockback * 100.0f) );

        g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] Your zombie class after the next infection will be: " + zombieClass.m_sName + "\n" );
        g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] Health: " + sHealth + " | Speed: " + sSpeed + " | Gravity: " + sGravity + " | Knockback: " + sKnockback + "\n" );
    }
}

void ZP_OpenChooseClassMenu(EHandle hPlayer)
{
	CBasePlayer@ pPlayer = cast<CBasePlayer@>(hPlayer.GetEntity());
	
	if ( pPlayer is null )
		return;

	const int idx = pPlayer.entindex();

	// Is it necessary?
	if ( g_ClassesMenu[idx] !is null && g_ClassesMenu[idx].IsRegistered() )
	{
		g_ClassesMenu[idx].Unregister();
	}

	@g_ClassesMenu[idx] = CTextMenu( @ZP_ChooseClassMenuCallback );

	g_ClassesMenu[idx].SetTitle( "\\yZombie Class\\r " ); // Title

	bool bOnePage = ( g_zombieClasses.length() <= 9 );
	uint iLastItem = g_zombieClasses.length() - 1;

	for (uint i = 0; i < g_zombieClasses.length(); i++)
	{
		bool bLastItem; // last item in a single page

		if ( bOnePage )
		{
			bLastItem = ( iLastItem == i );
		}
		else
		{
			bLastItem = ( iLastItem == i || (i / 7 != (i + 1) / 7) );
		}

		string sItemName = "\\w" + g_zombieClasses[i].m_sName + " \\y" + g_zombieClasses[i].m_sInfo + (bLastItem ? "\\y" : "\\r");

		g_ClassesMenu[idx].AddItem( sItemName, any(i + 1) );
	}

	g_ClassesMenu[idx].Register();
	g_ClassesMenu[idx].Open(0, 0, pPlayer);
}

//-----------------------------------------------------------------------------
// Purpose: extras management menu
//-----------------------------------------------------------------------------

void ZP_ExtrasManagementMenuCallback(CTextMenu@ pMenu, CBasePlayer@ pPlayer, int itemNumber, const CTextMenuItem@ pItem)
{
	if ( pItem is null || pPlayer is null || !pPlayer.IsConnected() )
		return;

	int iExtraManagement = 0;
	pItem.m_pUserData.retrieve( iExtraManagement );

    if ( iExtraManagement == 1 )
    {
        ZP_CommandCallback_SetLaser( pPlayer );
    }
    else if ( iExtraManagement == 2 )
    {
        ZP_CommandCallback_DelLaser( pPlayer );
    }
    else if ( iExtraManagement == 3 )
    {
        ZP_CommandCallback_SetSandBags( pPlayer );
    }
    else if ( iExtraManagement == 4 )
    {
        ZP_CommandCallback_DelSandBags( pPlayer );
    }

    g_Scheduler.SetTimeout( "ZP_OpenExtrasManagementMenu", 0.0f, EHandle(pPlayer) );
}

void ZP_OpenExtrasManagementMenu(EHandle hPlayer)
{
	CBasePlayer@ pPlayer = cast<CBasePlayer@>(hPlayer.GetEntity());
	
	if ( pPlayer is null )
		return;

	const int idx = pPlayer.entindex();

	// Is it necessary?
	if ( g_ExtrasManagementMenu[idx] !is null && g_ExtrasManagementMenu[idx].IsRegistered() )
	{
		g_ExtrasManagementMenu[idx].Unregister();
	}

	@g_ExtrasManagementMenu[idx] = CTextMenu( @ZP_ExtrasManagementMenuCallback );

	g_ExtrasManagementMenu[idx].SetTitle( "\\yExtras Management\\r " ); // Title

    const array<string> extras_management_menu =
    {
        "Place Laser Mine",
        "Take Laser Mine",
        "Place Sandbags",
        "Take Sandbags"
    };

	bool bOnePage = ( extras_management_menu.length() <= 9 );
	uint iLastItem = extras_management_menu.length() - 1;

	for (uint i = 0; i < extras_management_menu.length(); i++)
	{
		bool bLastItem; // last item in a single page

		if ( bOnePage )
		{
			bLastItem = ( iLastItem == i );
		}
		else
		{
			bLastItem = ( iLastItem == i || (i / 7 != (i + 1) / 7) );
		}

		string sItemName = "\\w" + extras_management_menu[i] + (bLastItem ? "\\y" : "\\r");

		g_ExtrasManagementMenu[idx].AddItem( sItemName, any(i + 1) );
	}

	g_ExtrasManagementMenu[idx].Register();
	g_ExtrasManagementMenu[idx].Open(0, 0, pPlayer);
}

//-----------------------------------------------------------------------------
// Purpose: human extras menu
//-----------------------------------------------------------------------------

void ZP_HumanExtrasMenuCallback(CTextMenu@ pMenu, CBasePlayer@ pPlayer, int itemNumber, const CTextMenuItem@ pItem)
{
	if ( pItem is null || pPlayer is null || !pPlayer.IsConnected() )
		return;
    
    if ( ZP_Extras_IsAllowed(pPlayer) && ZP_Extras_IsAlive(pPlayer) && ZP_Extras_IsHumanAllowedToBuy(pPlayer) )
    {
        int iExtraIndex = 0;
        pItem.m_pUserData.retrieve( iExtraIndex );

        iExtraIndex = iExtraIndex - 1;

        if ( iExtraIndex >= 0 && iExtraIndex < int( g_humanExtras.length() ) )
        {
            CExtraItem@ extraItem = g_humanExtras[ iExtraIndex ];

            extraItem.m_pfnExtraBuyCallback( extraItem, pPlayer );
        }
    }
}

void ZP_OpenHumanExtrasMenu(EHandle hPlayer)
{
	CBasePlayer@ pPlayer = cast<CBasePlayer@>(hPlayer.GetEntity());
	
	if ( pPlayer is null )
		return;

	const int idx = pPlayer.entindex();

	// Is it necessary?
	if ( g_HumanExtrasMenu[idx] !is null && g_HumanExtrasMenu[idx].IsRegistered() )
	{
		g_HumanExtrasMenu[idx].Unregister();
	}

	@g_HumanExtrasMenu[idx] = CTextMenu( @ZP_HumanExtrasMenuCallback );

	g_HumanExtrasMenu[idx].SetTitle( "\\yExtra Items [Human]\\r " ); // Title

	bool bOnePage = ( g_humanExtras.length() <= 9 );
	uint iLastItem = g_humanExtras.length() - 1;

	for (uint i = 0; i < g_humanExtras.length(); i++)
	{
		bool bLastItem; // last item in a single page

		if ( bOnePage )
		{
			bLastItem = ( iLastItem == i );
		}
		else
		{
			bLastItem = ( iLastItem == i || (i / 7 != (i + 1) / 7) );
		}

		string sItemName = "\\w" + g_humanExtras[i].m_sName + " \\y" + string(g_humanExtras[i].m_iCost) + " ammo packs" + (bLastItem ? "\\y" : "\\r");

		g_HumanExtrasMenu[idx].AddItem( sItemName, any(i + 1) );
	}

	g_HumanExtrasMenu[idx].Register();
	g_HumanExtrasMenu[idx].Open(0, 0, pPlayer);
}

//-----------------------------------------------------------------------------
// Purpose: zombie extras menu
//-----------------------------------------------------------------------------

void ZP_ZombieExtrasMenuCallback(CTextMenu@ pMenu, CBasePlayer@ pPlayer, int itemNumber, const CTextMenuItem@ pItem)
{
	if ( pItem is null || pPlayer is null || !pPlayer.IsConnected() )
		return;
    
    if ( ZP_Extras_IsAllowed(pPlayer) && ZP_Extras_IsAlive(pPlayer) && ZP_Extras_IsZombieAllowedToBuy(pPlayer) )
    {
        int iExtraIndex = 0;
        pItem.m_pUserData.retrieve( iExtraIndex );

        iExtraIndex = iExtraIndex - 1;

        if ( iExtraIndex >= 0 && iExtraIndex < int( g_zombieExtras.length() ) )
        {
            CExtraItem@ extraItem = g_zombieExtras[ iExtraIndex ];

            extraItem.m_pfnExtraBuyCallback( extraItem, pPlayer );
        }
    }
}

void ZP_OpenZombieExtrasMenu(EHandle hPlayer)
{
	CBasePlayer@ pPlayer = cast<CBasePlayer@>(hPlayer.GetEntity());
	
	if ( pPlayer is null )
		return;

	const int idx = pPlayer.entindex();

	// Is it necessary?
	if ( g_ZombieExtrasMenu[idx] !is null && g_ZombieExtrasMenu[idx].IsRegistered() )
	{
		g_ZombieExtrasMenu[idx].Unregister();
	}

	@g_ZombieExtrasMenu[idx] = CTextMenu( @ZP_ZombieExtrasMenuCallback );

	g_ZombieExtrasMenu[idx].SetTitle( "\\yExtra Items [Zombie]\\r " ); // Title

	bool bOnePage = ( g_zombieExtras.length() <= 9 );
	uint iLastItem = g_zombieExtras.length() - 1;

	for (uint i = 0; i < g_zombieExtras.length(); i++)
	{
		bool bLastItem; // last item in a single page

		if ( bOnePage )
		{
			bLastItem = ( iLastItem == i );
		}
		else
		{
			bLastItem = ( iLastItem == i || (i / 7 != (i + 1) / 7) );
		}

		string sItemName = "\\w" + g_zombieExtras[i].m_sName + " \\y" + string(g_zombieExtras[i].m_iCost) + " ammo packs" + (bLastItem ? "\\y" : "\\r");

		g_ZombieExtrasMenu[idx].AddItem( sItemName, any(i + 1) );
	}

	g_ZombieExtrasMenu[idx].Register();
	g_ZombieExtrasMenu[idx].Open(0, 0, pPlayer);
}

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//
//                                  Extras
//
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Purpose: utils
//-----------------------------------------------------------------------------

bool ZP_Extras_IsAllowed(CBasePlayer@ pPlayer)
{
    bool bAllowed = !( g_iGameMode == ZP_MODE_SURVIVOR || g_iGameMode == ZP_MODE_SNIPER || g_iGameMode == ZP_MODE_APOCALYPSE || g_iGameMode == ZP_MODE_ARMAGEDDON || g_iGameMode == ZP_MODE_NIGHTMARE );
    // bool bAllowed = ( g_iGameMode == ZP_MODE_NONE || g_iGameMode == ZP_MODE_SINGLE_INFECTION || g_iGameMode == ZP_MODE_MULTIPLE_INFECTION );

    if ( !bAllowed )
    {
        g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] Extras are disabled in this round.\n" );
    }

    return bAllowed;
}

bool ZP_Extras_IsAlive(CBasePlayer@ pPlayer)
{
    bool bAlive = ( g_bAlive[pPlayer.entindex()] && pPlayer.IsAlive() );

    if ( !bAlive )
    {
        g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] Cannot buy extras while dead.\n" );
    }

    return bAlive;
}

bool ZP_Extras_IsHumanAllowedToBuy(CBasePlayer@ pPlayer)
{
    bool bAllowed = ( g_bIsHuman[pPlayer.entindex()] && g_iClassType[pPlayer.entindex()] == ZP_HUMAN_DEFAULT );

    if ( !bAllowed )
    {
        g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] Unavailable command.\n" );
    }

    return bAllowed;
}

bool ZP_Extras_IsZombieAllowedToBuy(CBasePlayer@ pPlayer)
{
    bool bAllowed = ( g_bIsZombie[pPlayer.entindex()] && g_iClassType[pPlayer.entindex()] == ZP_ZOMBIE_DEFAULT );

    if ( !bAllowed )
    {
        g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] Unavailable command.\n" );
    }

    return bAllowed;
}

bool ZP_Extras_IsEnoughAmmopacks(CBasePlayer@ pPlayer, int iCost)
{
    bool bEnough = ( g_iAmmopacks[pPlayer.entindex()] - iCost >= 0 );

    if ( !bEnough )
    {
        g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] Not enough ammopacks.\n" );
    }

    return bEnough;
}

void ZP_Extras_ConfirmPurchase(CBasePlayer@ pPlayer, CExtraItem@ pExtraItem)
{
    g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[ZP] You bought: " + pExtraItem.m_sName + "\n" );
    g_iAmmopacks[ pPlayer.entindex() ] -= pExtraItem.m_iCost;
}