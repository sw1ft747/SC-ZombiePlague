/** [SZP] Sven Zombie Plague BETA
 * Zombie Classes
 * Author: Sw1ft
*/

//-----------------------------------------------------------------------------
// IDs of zombie classes
//-----------------------------------------------------------------------------

int ZP_CLASS_CLASSIC_ZOMBIE = 0;
int ZP_CLASS_RAPTOR_ZOMBIE = 1;
int ZP_CLASS_POISON_ZOMBIE = 2;
int ZP_CLASS_BIG_ZOMBIE = 3;
int ZP_CLASS_LEECH_ZOMBIE = 4;

//-----------------------------------------------------------------------------
// Purpose: register all Zombie classes
//-----------------------------------------------------------------------------

void ZP_RegisterZombieClasses()
{
    // Add new classes here, if you want to handle some actions with your zombie class, assign to your @int variable @return value (class ID) of function @ZP_RegisterZombieClass
    // To understand handling of actions, look at zombie class @ZP_CLASS_LEECH_ZOMBIE in main script file

    // Function's signature:
    // int ZP_RegisterZombieClass( string name, string info, string model, float health, int speed, float gravity, float knockback, int userdata = 0, float userdata = 0.0f )

    ZP_CLASS_CLASSIC_ZOMBIE = ZP_RegisterZombieClass( "Classic Zombie", "=Balanced=", "zombie_source_v1_2", 2500.0f, 230.0f, 1.0f, 1.0f );
    ZP_CLASS_RAPTOR_ZOMBIE = ZP_RegisterZombieClass( "Raptor Zombie", "HP-- Speed++ Knockback++", "cso_zombie2", 1700.0f, 250.0f, 1.0f, 1.5f );
    ZP_CLASS_POISON_ZOMBIE = ZP_RegisterZombieClass( "Poison Zombie", "HP- Jump+ Knockback+", "infectedbusinessman", 2200.0f, 230.0f, 0.75f, 1.25f );
    ZP_CLASS_BIG_ZOMBIE = ZP_RegisterZombieClass( "Big Zombie", "HP++ Speed- Knockback--", "re3_zombiefat", 3200.0f, 210.0f, 1.0, 0.5f );
    ZP_CLASS_LEECH_ZOMBIE = ZP_RegisterZombieClass( "Leech Zombie", "HP- Knockback+ Leech++", "mr_zombo_v2", 2000.0f, 230.0f, 1.0, 1.25f, 0, 500.0f );
}