namespace FORCE_FIELD
{

string AURA_MODEL = "models/zombie_plague/aura8.mdl";

class CZpForceField : ScriptBaseEntity
{
	void Spawn()
	{
		Precache();

		// self.pev.movetype = MOVETYPE_NONE;
		self.pev.solid = SOLID_TRIGGER;

        if ( ZP_FORCE_FIELD_RANDOM_COLOR )
        {
            Vector vecColor;

            switch ( RandomInt(0, 4) )
            {
                case 0: // white
                {
                    vecColor.x = 255; // r
                    vecColor.y = 255; // g
                    vecColor.z = 255; // b
                    break;
                }
                case 1: // red
                {
                    vecColor.x = RandomInt(100, 200); // r
                    vecColor.y = 0; // g
                    vecColor.z = 0; // b
                    break;
                }
                case 2: // green
                {
                    vecColor.x = 0; // r
                    vecColor.y = RandomInt(100, 200); // g
                    vecColor.z = 0; // b
                    break;
                }
                case 3: // yellow
                {
                    vecColor.x = RandomInt(100, 200); // r
                    vecColor.y = RandomInt(100, 200); // g
                    vecColor.z = 0; // b
                    break;
                }
                case 4: // random (all colors)
                {
                    vecColor.x = RandomInt(50, 200); // r
                    vecColor.y = RandomInt(50, 200); // g
                    vecColor.z = RandomInt(50, 200); // b
                    break;
                }
            }

            self.pev.rendercolor = vecColor;
        }
        else
        {
            self.pev.rendercolor = Vector(255, 0, 0);
        }

		self.pev.renderfx = kRenderFxGlowShell;
    	self.pev.rendermode = kRenderTransAlpha;
    	self.pev.renderamt = 50.0f;

		self.pev.mins = Vector(-100, -100, -100);
		self.pev.maxs = Vector(100, 100, 100);

		g_EntityFuncs.SetModel( self, AURA_MODEL );
		g_EntityFuncs.SetSize( self.pev, Vector(-100, -100, -100), Vector(100, 100, 100) );
	}

	void Precache()
	{
		g_Game.PrecacheModel( AURA_MODEL );
	}

	void Touch( CBaseEntity@ pOther )
	{
		int idx = pOther.entindex();

		if ( idx > 0 && idx <= g_Engine.maxClients )
		{
            if ( g_bAlive[ idx ] && g_bIsZombie[ idx ] && g_iClassType[ idx ] == ZP_ZOMBIE_DEFAULT )
			{
                Vector vecPush = ( pOther.pev.origin - self.pev.origin ) * ZP_FORCE_FIELD_PUSH_STRENGTH;

			    // pOther.pev.velocity.x = vecPush.x;
			    // pOther.pev.velocity.y = vecPush.y;
                vecPush.z *= 0.75f;

			    pOther.pev.velocity = vecPush;
            }
		}
        else if ( ( pOther.pev.iuser1 & 1024 ) != 0 && pOther.pev.classname == "zp_projectile" )
        {
            Vector vecPush = ( pOther.pev.origin - self.pev.origin ) * ZP_FORCE_FIELD_PUSH_STRENGTH;
        
            vecPush.z *= 0.75f;

            pOther.pev.velocity = vecPush;
        }
	}
}

CBaseEntity@ SpawnForceField( edict_t@ owner, Vector vecOrigin )
{
    CBaseEntity@ pForceFieldBase = g_EntityFuncs.CreateEntity( GetName() );
	CZpForceField@ pForceField = cast<CZpForceField@>( CastToScriptClass( pForceFieldBase ) );

    g_EntityFuncs.SetOrigin( pForceField.self, vecOrigin );
	g_EntityFuncs.DispatchSpawn( pForceField.self.edict() );

    @pForceField.pev.owner = owner;

	// pForceField.SetTouch( TouchFunction( pForceField.Touch ) );

    return pForceFieldBase;
}

string GetName()
{
	return "zp_force_field";
}

void Register()
{
	if( g_CustomEntityFuncs.IsCustomEntity( GetName() ) )
		return;

	g_CustomEntityFuncs.RegisterCustomEntity( "FORCE_FIELD::CZpForceField", GetName() );
	g_Game.PrecacheOther( GetName() );
}

}