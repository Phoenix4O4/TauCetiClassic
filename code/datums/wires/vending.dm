var/const/VENDING_WIRE_THROW      = 1
var/const/VENDING_WIRE_CONTRABAND = 2
var/const/VENDING_WIRE_ELECTRIFY  = 4
var/const/VENDING_WIRE_IDSCAN     = 8
var/const/VENDING_WIRE_SHUT_UP    = 16

/datum/wires/vending
	holder_type = /obj/machinery/vending
	wire_count = 5

/datum/wires/vending/can_use()
	var/obj/machinery/vending/V = holder
	return V.panel_open

/datum/wires/vending/interactable(mob/user)
	var/obj/machinery/vending/V = holder
	if(iscarbon(user) && V.seconds_electrified && V.shock(user, 100))
		return FALSE
	if(V.panel_open)
		return TRUE
	return FALSE

/datum/wires/vending/get_status()
	var/obj/machinery/vending/V = holder
	. = ..()
	. += "The orange light is [V.seconds_electrified ? "on" : "off"]."
	. += "The red light is [V.shoot_inventory ? "off" : "blinking"]."
	. += "The green light is [(V.categories & CAT_HIDDEN) ? "on" : "off"]."
	. += "A [V.scan_id ? "purple" : "yellow"] light is on."
	. += "The blue light is [V.shut_up ? "off" : "on"]."


/datum/wires/vending/update_cut(index, mended)
	var/obj/machinery/vending/V = holder

	switch(index)
		if(VENDING_WIRE_THROW)
			V.shoot_inventory = !mended

		if(VENDING_WIRE_CONTRABAND)
			V.categories &= ~CAT_HIDDEN

		if(VENDING_WIRE_ELECTRIFY)
			if(mended)
				V.seconds_electrified = 0
			else
				V.seconds_electrified = -1

		if(VENDING_WIRE_IDSCAN)
			V.scan_id = 1

		if(VENDING_WIRE_SHUT_UP)
			V.shut_up = !mended
	..()

/datum/wires/vending/update_pulsed(index)
	var/obj/machinery/vending/V = holder

	switch(index)
		if(VENDING_WIRE_THROW)
			V.shoot_inventory = !V.shoot_inventory

		if(VENDING_WIRE_CONTRABAND)
			V.categories ^= CAT_HIDDEN

		if(VENDING_WIRE_ELECTRIFY)
			V.seconds_electrified = 30

		if(VENDING_WIRE_IDSCAN)
			V.scan_id = !V.scan_id

		if(VENDING_WIRE_SHUT_UP)
			V.shut_up = !V.shut_up
	..()


/datum/wires/proc/Interact(mob/user)
	if(user && istype(user) && holder && interactable(user))
		tgui_interact(user)

/**
 * Base proc, intended to be overriden. Wire datum specific checks you want to run before the TGUI is shown to the user should go here.
 */
/datum/wires/proc/interactable(mob/user)
	return TRUE
