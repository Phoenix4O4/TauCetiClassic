 //////////////
 //MAIN AREAS//
 //////////////

 // Respectful request when adding new zones, add RU cases. Since zones are starting to be actively used in translation.

/area/space
	name = "Space"
	cases = list("космическое пространство", "космического пространства", "космическому пространству", "космическое пространство", "космическим пространством", "космическом пространстве")
	icon_state = "space"
	requires_power = 1
	always_unpowered = 1
	power_light = 0
	power_equip = 0
	power_environ = 0
	valid_territory = 0
	looped_ambience = 'sound/ambience/loop_space.ogg'
	is_force_ambience = TRUE
	ambience = list(
		'sound/ambience/space_1.ogg',
		'sound/ambience/space_2.ogg',
		'sound/ambience/space_3.ogg',
		'sound/ambience/space_4.ogg',
		'sound/ambience/space_5.ogg',
		'sound/ambience/space_6.ogg',
		'sound/ambience/space_7.ogg',
		'sound/ambience/space_8.ogg'
	)
	outdoors = TRUE

/area/start            // will be unused once kurper gets his login interface patch done
	name = "start area"
	cases = list("стартовая локация", "стартовой локации", "стартовой локации", "стартовую локацию", "стартовой локацией", "стартовой локации")
	icon_state = "start"
	requires_power = 0
	dynamic_lighting = FALSE
	has_gravity = 1

// other environment areas
/area/space/snow
	name = "Snow field"
	cases = list("снежное поле", "снежного поля", "снежному полю", "снежное поле", "снежным полем", "снежном поле")
