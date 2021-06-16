///
///		A vending machine
///

//
//	ALL THE VENDING MACHINES ARE IN vending_machines.dm now!
//

/obj/machinery/vending
	name = "Vendomat"
	desc = "A generic vending machine."
	icon = 'icons/obj/vending.dmi'
	icon_state = "generic"
	anchored = TRUE
	density = TRUE

	layer = 2.9
	// Power
	use_power = IDLE_POWER_USE
	idle_power_usage = 10
	var/vend_power_usage = 150 //actuators and stuff
	var/light_range_on = 3
	var/light_power_on = 1
	// Vending-related
	var/active = 1 //No sales pitches if off!
	var/vend_ready = 1 //Are we ready to vend?? Is it time??
	var/vend_delay = 10 //How long does it take to vend?
	var/categories = CAT_NORMAL // Bitmask of cats we're currently showing
	var/datum/stored_item/vending_product/currently_vending = null // What we're requesting payment for right now


	/*
		Variables used to initialize the product list
		These are used for initialization only, and so are optional if
		product_records is specified
	*/
	var/list/products	= list() // For each, use the following pattern:
	var/list/contraband	= list() // list(/type/path = amount,/type/path2 = amount2)
	var/list/premium 	= list() // No specified amount = only one in stock
	var/list/prices     = list() // Prices for each item, list(/type/path = price), items not in the list don't have a price.

	// List of vending_product items available.
	var/list/product_records = list()


	// Variables used to initialize advertising
	var/product_slogans = "" //String of slogans spoken out loud, separated by semicolons
	var/product_ads = "" //String of small ad messages in the vending screen

	var/list/ads_list = list()

	// Stuff relating vocalizations
	var/list/slogan_list = list()
	var/shut_up = 1 //Stop spouting those godawful pitches!
	var/vend_reply //Thank you for shopping!
	var/last_reply = 0
	var/last_slogan = 0 //When did we last pitch?
	var/slogan_delay = 6000 //How long until we can pitch again?
	var/icon_deny
	var/icon_vend
	var/icon_hacked
	var/extended_inventory = 0
	var/customer_account

	// Things that can go wrong
	emagged = 0 //Ignores if somebody doesn't have card access to that machine.
	var/seconds_electrified = 0 //Shock customers like an airlock.
	var/shoot_inventory = 0 //Fire items at customers! We're broken!

	var/scan_id = 1
	var/obj/item/weapon/coin/coin
	var/datum/wires/vending/wires = null
	var/obj/item/weapon/vending_refill/refill_canister = null

	var/list/log = list()
	var/req_log_access = list(31) //default access for checking logs is cargo
	var/has_logs = 0 //defaults to 0, set to anything else for vendor to have logs
	var/can_rotate = 1 //Defaults to yes, can be set to 0 for vendors without or with unwanted directionals.


/obj/machinery/vending/atom_init()
	. = ..()
	wires = new(src)
	src.anchored = TRUE
	component_parts = list()
	component_parts += new /obj/item/weapon/circuitboard/vendor(null)

	if(product_slogans)
		slogan_list += splittext(product_slogans, ";")

		// So not all machines speak at the exact same time.
		// The first time this machine says something will be at slogantime + this random value,
		// so if slogantime is 10 minutes, it will say it at somewhere between 10 and 20 minutes after the machine is crated.
		last_slogan = world.time + rand(0, slogan_delay)

	if(product_ads)
		ads_list += splittext(product_ads, ";")

	build_inventory()
	power_change()

GLOBAL_LIST_EMPTY(vending_products)
/**
 *  Build produdct_records from the products lists
 *
 *  products, contraband, premium, and prices allow specifying
 *  products that the vending machine is to carry without manually populating
 *  product_records.
 */
/obj/machinery/vending/proc/build_inventory()
	var/list/all_products = list(
		list(products, CAT_NORMAL),
		list(contraband, CAT_HIDDEN),
		list(premium, CAT_COIN))

	for(var/current_list in all_products)
		var/category = current_list[2]

		for(var/entry in current_list[1])
			var/datum/stored_item/vending_product/product = new/datum/stored_item/vending_product(src, entry)

			product.price = (entry in prices) ? prices[entry] : 0
			product.amount = (current_list[1][entry]) ? current_list[1][entry] : 1
			product.category = category

			product_records.Add(product)
			global.vending_products[entry] = 1

/obj/machinery/vending/Destroy()
	qdel(wires)
	wires = null
	qdel(coin)
	coin = null
	for(var/datum/stored_item/vending_product/R in product_records)
		qdel(R)
	product_records = null
	return ..()

/obj/machinery/vending/ex_act(severity)
	switch(severity)
		if(1.0)
			qdel(src)
			return
		if(2.0)
			if(prob(50))
				qdel(src)
				return
		if(3.0)
			if(prob(25))
				spawn(0)
					malfunction()
					return
				return
		else
	return

/obj/machinery/vending/proc/set_extended_inventory(state)
	extended_inventory = state
	if(state && icon_hacked)
		icon_state = icon_hacked
	else
		icon_state = initial(icon_state)

/obj/machinery/vending/proc/shock(mob/user, prb)
	if(stat & (BROKEN|NOPOWER))		// unpowered, no shock
		return 0
	if(!prob(prb))
		return 0
	var/datum/effect/effect/system/spark_spread/s = new /datum/effect/effect/system/spark_spread
	s.set_up(5, 1, src)
	s.start()
	if (electrocute_mob(user, get_area(src), src, 0.7))
		return 1
	else
		return 0

/obj/machinery/vending/emag_act(remaining_charges, mob/user)
	if(!emagged)
		src.emagged = 1
		to_chat(user, "You short out \the [src]'s product lock.")
		return 1

/obj/machinery/vending/attackby(obj/item/weapon/W as obj, mob/user as mob)
	var/obj/item/weapon/card/id/I = W.GetID()

	if(I || istype(W, /obj/item/weapon/spacecash))
		attack_hand(user)
		return
	else if(isscrewdriver(W) && anchored)
		src.panel_open = !src.panel_open
		to_chat(user, "You [src.panel_open ? "open" : "close"] the maintenance panel.")
		cut_overlays()
		if(src.panel_open)
			add_overlay(image(src.icon, "[initial(icon_state)]-panel"))
		updateUsrDialog()
		SStgui.update_uis(src)  // Speaker switch is on the main UI, not wires UI
		return

	else if(is_wire_tool(W) && panel_open && wires.interact(user))
		return

	else if(istype(W, /obj/item/weapon/coin) && premium.len > 0)
		user.drop_item()
		W.forceMove(src)
		coin = W
		categories |= CAT_COIN
		to_chat(user, "<span class='notice'>You insert \the [W] into \the [src].</span>")
		SStgui.update_uis(src)
		return

	else if(iswrench(W))	//unwrenching vendomats
		var/turf/T = user.loc
		if(user.is_busy(src))
			return
		to_chat(user, "<span class='notice'>You begin [anchored ? "unwrenching" : "wrenching"] the [src].</span>")
		if(W.use_tool(src, user, 20, volume = 50))
			if(!istype(src, /obj/machinery/vending) || !user || !W || !T)
				return
			if(user.loc == T && user.get_active_hand() == W)
				anchored = !anchored
				to_chat(user, "<span class='notice'>You [anchored ? "wrench" : "unwrench"] \the [src].</span>")
				if (!(src.anchored & powered()))
					src.icon_state = "[initial(icon_state)]-off"
					stat |= NOPOWER
					set_light(0)
				else
					icon_state = initial(icon_state)
					stat &= ~NOPOWER
					set_light(light_range_on, light_power_on)
				wrenched_change()

	else if(istype(W, refill_canister) && refill_canister != null)
		if(stat & (BROKEN|NOPOWER))
			to_chat(user, "<span class='notice'>It does nothing.</span>")
		else if(panel_open)
			//if the panel is open we attempt to refill the machine
			var/obj/item/weapon/vending_refill/canister = W
			if(canister.charges == 0)
				to_chat(user, "<span class='notice'>This [canister.name] is empty!</span>")
			else
				var/transfered = refill_inventory(canister, user)
				if(transfered)
					to_chat(user, "<span class='notice'>You loaded [transfered] items in \the [name].</span>")
				else
					to_chat(user, "<span class='notice'>The [name] is fully stocked.</span>")
			return;
		else
			to_chat(user, "<span class='notice'>You should probably unscrew the service panel first.</span>")
	else

		for(var/datum/stored_item/vending_product/R in product_records)
			if(istype(W, R.item_path) && (W.name == R.item_name))
				stock(W, R, user)
				return
		..()

/obj/machinery/vending/default_deconstruction_crowbar(obj/item/O)
	var/list/all_products = CAT_NORMAL + CAT_HIDDEN + CAT_COIN
	for(var/datum/stored_item/vending_product/machine_content in all_products)
		while(machine_content.amount !=0)
			var/safety = 0 //to avoid infinite loop
			for(var/obj/item/weapon/vending_refill/VR in component_parts)
				safety++
				if(VR.charges < initial(VR.charges))
					VR.charges++
					machine_content.amount--
					if(!machine_content.amount)
						break
				else
					safety--
			if(safety <= 0)
				break
	..()
/**
 *  Receive payment with cashmoney.
 *
 *  usr is the mob who gets the change.
 */
/obj/machinery/vending/proc/pay_with_cash(var/obj/item/weapon/spacecash/cashmoney, mob/user)
	if(currently_vending.price > cashmoney.worth)

		// This is not a status display message, since it's something the character
		// themselves is meant to see BEFORE putting the money in
		to_chat(usr, "[bicon(cashmoney)] <span class='warning'>That is not enough money.</span>")
		return 0

	if(istype(cashmoney, /obj/item/weapon/spacecash))

		visible_message("<span class='info'>\The [usr] inserts some cash into \the [src].</span>")
		cashmoney.worth -= currently_vending.price

		if(cashmoney.worth <= 0)
			usr.drop_from_inventory(cashmoney)
			qdel(cashmoney)
		else
			cashmoney.update_icon()

	// Vending machines have no idea who paid with cash
	credit_purchase("(cash)")
	return 1

/**
 * Scan a chargecard and deduct payment from it.
 *
 * Takes payment for whatever is the currently_vending item. Returns 1 if
 * successful, 0 if failed.
 */
/obj/machinery/vending/proc/pay_with_ewallet(obj/item/weapon/spacecash/ewallet/wallet)
	visible_message("<span class='info'>\The [usr] swipes \the [wallet] through \the [src].</span>")
	if(currently_vending.price > wallet.worth)
		to_chat(usr, "<span class='warning'>Insufficient funds on chargecard.</span>")
		return 0
	else
		wallet.worth -= currently_vending.price
		credit_purchase("[wallet.owner_name] (chargecard)")
		return 1

/**
 * Scan a card and attempt to transfer payment from associated account.
 *
 * Takes payment for whatever is the currently_vending item. Returns 1 if
 * successful, 0 if failed
 */
/obj/machinery/vending/proc/pay_with_card(obj/item/weapon/card/id/I, mob/M)
	visible_message("<span class='info'>[M] swipes a card through [src].</span>")

	var/datum/money_account/customer_account = get_account(I.associated_account_number)
	if(!customer_account)
		to_chat(M, "<span class='warning'>Error: Unable to access account. Please contact technical support if problem persists.</span>")
		return FALSE

	if(customer_account.suspended)
		to_chat(M, "<span class='warning'>Unable to access account: account suspended.</span>")
		return FALSE

	// Have the customer punch in the PIN before checking if there's enough money. Prevents people from figuring out acct is
	// empty at high security levels
	if(customer_account.security_level != 0) //If card requires pin authentication (ie seclevel 1 or 2)
		var/attempt_pin = input("Enter pin code", "Vendor transaction") as num
		customer_account = attempt_account_access(I.associated_account_number, attempt_pin, 2)

		if(!customer_account)
			to_chat(M, "<span class='warning'>Unable to access account: incorrect credentials.</span>")
			return FALSE

	if(currently_vending.price > customer_account.money)
		to_chat(M, "<span class='warning'>Insufficient funds in account.</span>")
		return FALSE

	// Okay to move the money at this point

	// debit money from the purchaser's account
	customer_account.money -= currently_vending.price

	// create entry in the purchaser's account log
	var/datum/transaction/T = new()
	T.target_name = "[vendor_account.owner_name] (via [name])"
	T.purpose = "Purchase of [currently_vending.item_name]"
	if(currently_vending.price > 0)
		T.amount = "([currently_vending.price])"
	else
		T.amount = "[currently_vending.price]"
	T.source_terminal = name
	T.date = current_date_string
	T.time = worldtime2text()
	customer_account.transaction_log.Add(T)

	// Give the vendor the money. We use the account owner name, which means
	// that purchases made with stolen/borrowed card will look like the card
	// owner made them
	credit_purchase(customer_account.owner_name)
	return 1

/**
 *  Add money for current purchase to the vendor account.
 *
 *  Called after the money has already been taken from the customer.
 */
/obj/machinery/vending/proc/credit_purchase(target as text)
	vendor_account.money += currently_vending.price

	var/datum/transaction/T = new()
	T.target_name = target
	T.purpose = "Purchase of [currently_vending.item_name]"
	T.amount = "[currently_vending.price]"
	T.source_terminal = name
	T.date = current_date_string
	T.time = worldtime2text()
	vendor_account.transaction_log.Add(T)

/obj/machinery/vending/attack_ghost(mob/user)
	return attack_hand(user)

/obj/machinery/vending/attack_ai(mob/user as mob)
	return attack_hand(user)

/obj/machinery/vending/attack_hand(mob/user as mob)
	if(stat & (BROKEN|NOPOWER))
		return

	if(seconds_electrified != 0)
		if(electrocute_mob(user, 100))
			return

	wires.Interact(user)
	tgui_interact(user)

/obj/machinery/vending/tgui_assets(mob/user)
	return list(
		get_asset_datum(/datum/asset/spritesheet/vending),
	)

/obj/machinery/vending/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "Vending", name)
		ui.open()

/obj/machinery/vending/tgui_data(mob/user)
	var/list/data = list()
	var/list/listed_products = list()

	data["chargesMoney"] = length(prices) > 0 ? TRUE : FALSE
	for(var/key = 1 to product_records.len)
		var/datum/stored_item/vending_product/I = product_records[key]

		if(!(I.category & categories))
			continue

		listed_products.Add(list(list(
			"key" = key,
			"name" = I.item_name,
			"desc" = I.item_desc,
			"price" = I.price,
			"color" = I.display_color,
			"isatom" = ispath(I.item_path, /atom),
			"path" = replacetext(replacetext("[I.item_path]", "/obj/item/", ""), "/", "-"),
			"amount" = I.get_amount()
		)))

	data["products"] = listed_products

	if(coin)
		data["coin"] = coin.name
	else
		data["coin"] = FALSE

	if(currently_vending)
		data["actively_vending"] = currently_vending.item_name
	else
		data["actively_vending"] = null

	if(panel_open)
		data["panel"] = 1
		data["speaker"] = shut_up ? 0 : 1
	else
		data["panel"] = 0

	var/mob/living/carbon/human/H
	var/obj/item/weapon/card/id/C

	data["guestNotice"] = "No valid ID card detected. Wear your ID, or present cash.";
	data["userMoney"] = 0
	data["user"] = null
	if(ishuman(user))
		H = user
		C = H.GetIdCard()
		var/obj/item/weapon/spacecash/S = H.get_active_hand()
		if(istype(S))
			data["userMoney"] = S.worth
			data["guestNotice"] = "Accepting [S.initial_name]. You have: $[S.worth]."
		else if(istype(C))
			var/datum/money_account/A = get_account(C.associated_account_number)
			if(istype(A))
				data["user"] = list()
				data["user"]["name"] = A.owner_name
				data["userMoney"] = A.money
				data["user"]["job"] = (istype(C) && C.rank) ? C.rank : "No Job"
			else
				data["guestNotice"] = "Unlinked ID detected. Present cash to pay.";

	return data

/obj/machinery/vending/tgui_act(action, params)
	if(stat & (BROKEN|NOPOWER))
		return
	if(usr.stat || usr.restrained())
		return
	if(..())
		return TRUE

	. = TRUE
	switch(action)
		if("remove_coin")
			if(issilicon(usr))
				return FALSE

			if(!coin)
				to_chat(usr, "There is no coin in this machine.")
				return

			coin.forceMove(src.loc)
			if(!usr.get_active_hand())
				usr.put_in_hands(coin)

			to_chat(usr, "<span class='notice'>You remove \the [coin] from \the [src].</span>")
			coin = null
			categories &= ~CAT_COIN
			return TRUE
		if("vend")
			if(!vend_ready)
				to_chat(usr, "<span class='warning'>[src] is busy!</span>")
				return
			if(!allowed(usr) && !emagged && scan_id)
				to_chat(usr, "<span class='warning'>Access denied.</span>")	//Unless emagged of course
				flick("[icon_state]-deny",src)
				playsound(src, 'sound/machines/buzz-sigh.ogg', VOL_EFFECTS_MASTER, null, FALSE)
				return
			if(panel_open)
				to_chat(usr, "<span class='warning'>[src] cannot dispense products while its service panel is open!</span>")
				return

			var/key = text2num(params["vend"])
			var/datum/stored_item/vending_product/R = product_records[key]

			// This should not happen unless the request from NanoUI was bad
			if(!(R.category & categories))
				return

			if(!can_buy(R, usr))
				return

			if(R.price <= 0)
				vend(R, usr)
				add_fingerprint(usr)
				return TRUE

			if(issilicon(usr)) //If the item is not free, provide feedback if a synth is trying to buy something.
				to_chat(usr, "<span class='danger'>Lawed unit recognized.  Lawed units cannot complete this transaction.  Purchase canceled.</span>")
				return
			if(!ishuman(usr))
				return

			vend_ready = FALSE // From this point onwards, vendor is locked to performing this transaction only, until it is resolved.

			var/mob/living/carbon/human/H = usr
			var/obj/item/weapon/card/id/C = H.GetIdCard()

			if(!vendor_account || vendor_account.suspended)
				to_chat(usr, "Vendor account offline. Unable to process transaction.")
				flick("[icon_state]-deny",src)
				vend_ready = TRUE
				return

			currently_vending = R

			var/paid = FALSE

			if(istype(usr.get_active_hand(), /obj/item/weapon/spacecash))
				var/obj/item/weapon/spacecash/cash = usr.get_active_hand()
				paid = pay_with_cash(cash, usr)
			else if(istype(usr.get_active_hand(), /obj/item/weapon/spacecash/ewallet))
				var/obj/item/weapon/spacecash/ewallet/wallet = usr.get_active_hand()
				paid = pay_with_ewallet(wallet)
			else if(istype(C, /obj/item/weapon/card))
				paid = pay_with_card(C, usr)
			/*else if(usr.can_advanced_admin_interact())
				to_chat(usr, "<span class='notice'>Vending object due to admin interaction.</span>")
				paid = TRUE*/
			else
				to_chat(usr, "<span class='warning'>Payment failure: you have no ID or other method of payment.</span>")
				vend_ready = TRUE
				flick("[icon_state]-deny",src)
				return TRUE // we set this because they shouldn't even be able to get this far, and we want the UI to update.
			if(paid)
				vend(currently_vending, usr) // vend will handle vend_ready
				. = TRUE
			else
				to_chat(usr, "<span class='warning'>Payment failure: unable to process payment.</span>")
				vend_ready = TRUE

		if("togglevoice")
			if(!panel_open)
				return FALSE
			shut_up = !shut_up

/obj/machinery/vending/proc/can_buy(datum/stored_item/vending_product/R, mob/user)
	if(!allowed(user) && !emagged && scan_id)
		to_chat(user, "<span class='warning'>Access denied.</span>")	//Unless emagged of course
		flick("[icon_state]-deny",src)
		playsound(src, 'sound/machines/buzz-sigh.ogg', VOL_EFFECTS_MASTER, null, FALSE)
		return FALSE
	return TRUE

/obj/machinery/vending/proc/vend(datum/stored_item/vending_product/R, mob/user)
	if(!can_buy(R, user))
		return

	if(!R.amount)
		to_chat(user, "<span class='warning'>[src] has ran out of that product.</span>")
		vend_ready = TRUE
		return

	vend_ready = FALSE //One thing at a time!!
	SStgui.update_uis(src)

	if(R.category & CAT_COIN)
		if(!coin)
			to_chat(user, "<span class='notice'>You need to insert a coin to get this item.</span>")
			return
		if(coin.string_attached)
			if(prob(50))
				to_chat(user, "<span class='notice'>You successfully pull the coin out before \the [src] could swallow it.</span>")
			else
				to_chat(user, "<span class='notice'>You weren't able to pull the coin out fast enough, the machine ate it, string and all.</span>")
				qdel(coin)
				coin = null
				categories &= ~CAT_COIN
		else
			qdel(coin)
			coin = null
			categories &= ~CAT_COIN

	if(((src.last_reply + (src.vend_delay + 200)) <= world.time) && src.vend_reply)
		spawn(0)
			src.speak(src.vend_reply)
			src.last_reply = world.time

	use_power(vend_power_usage)	//actuators and stuff
	flick("[icon_state]-vend",src)
	playsound(src, 'sound/items/vending.ogg', VOL_EFFECTS_MASTER)
	addtimer(CALLBACK(src, .proc/delayed_vend, R, user), vend_delay)

/obj/machinery/vending/proc/delayed_vend(datum/stored_item/vending_product/R, mob/user)
	R.get_product(get_turf(src))
	if(has_logs)
		do_logging(R, user, 1)
	if(prob(1))
		sleep(3)
		if(R.get_product(get_turf(src)))
			visible_message("<span class='notice'>\The [src] clunks as it vends an additional item.</span>")

	vend_ready = 1
	currently_vending = null
	SStgui.update_uis(src)


/obj/machinery/vending/proc/do_logging(datum/stored_item/vending_product/R, mob/user, vending = 0)
	if(user.GetIdCard())
		var/obj/item/weapon/card/id/tempid = user.GetIdCard()
		var/list/list_item = list()
		if(vending)
			list_item += "vend"
		else
			list_item += "stock"
		list_item += tempid.registered_name
		list_item += worldtime2text()
		list_item += R.item_name
		log[++log.len] = list_item

/obj/machinery/vending/proc/show_log(mob/user as mob)
	if(user.GetIdCard())
		var/obj/item/weapon/card/id/tempid = user.GetIdCard()
		if(req_log_access in tempid.GetAccess())
			var/datum/browser/popup = new(user, "vending_log", "Vending Log", 700, 500)
			var/dat = ""
			dat += "<center><span style='font-size:24pt'><b>[name] Vending Log</b></span></center>"
			dat += "<center><span style='font-size:16pt'>Welcome [user.name]!</span></center><br>"
			dat += "<span style='font-size:8pt'>Below are the recent vending logs for your vending machine.</span><br>"
			for(var/i in log)
				dat += json_encode(i)
				dat += ";<br>"
			popup.set_content(dat)
			popup.open()
	else
		to_chat(user,"<span class='warning'>You do not have the required access to view the vending logs for this machine.</span>")


/**
 * Add item to the machine
 *
 * Checks if item is vendable in this machine should be performed before
 * calling. W is the item being inserted, R is the associated vending_product entry.
 */
/obj/machinery/vending/proc/stock(obj/item/weapon/W, datum/stored_item/vending_product/R, mob/user)
	if(!user.unEquip(W))
		return

	to_chat(user, "<span class='notice'>You insert \the [W] in the product receptor.</span>")
	R.add_product(W)
	if(has_logs)
		do_logging(R, user)

	SStgui.update_uis(src)

/obj/machinery/vending/process()
	if(stat & (BROKEN|NOPOWER))
		return

	if(!active)
		return

	if(seconds_electrified > 0)
		seconds_electrified--

	//Pitch to the people!  Really sell it!
	if(((last_slogan + slogan_delay) <= world.time) && (slogan_list.len > 0) && (!shut_up) && prob(5))
		var/slogan = pick(slogan_list)
		speak(slogan)
		last_slogan = world.time

	if(shoot_inventory && prob(2))
		throw_item()

	return

/obj/machinery/vending/proc/speak(message)
	if(stat & NOPOWER)
		return

	if(!message)
		return

	for(var/mob/O in hearers(src, null))
		O.show_message("<span class='game say'><span class='name'>\The [src]</span> beeps, \"[message]\"</span>",2)
	return

/obj/machinery/vending/power_change()
	..()
	if(stat & BROKEN)
		icon_state = "[initial(icon_state)]-broken"
	else
		if(!(stat & NOPOWER))
			icon_state = initial(icon_state)
		else
			spawn(rand(0, 15))
				icon_state = "[initial(icon_state)]-off"

//Oh no we're malfunctioning!  Dump out some product and break.
/obj/machinery/vending/proc/malfunction()
	for(var/datum/stored_item/vending_product/R in product_records)
		while(R.get_amount()>0)
			R.get_product(loc)
		break

	stat |= BROKEN
	icon_state = "[initial(icon_state)]-broken"
	return

//Somebody cut an important wire and now we're following a new definition of "pitch."
/obj/machinery/vending/proc/throw_item()
	var/obj/throw_item = null
	var/mob/living/target = locate() in view(7,src)
	if(!target)
		return 0

	for(var/datum/stored_item/vending_product/R in product_records)
		throw_item = R.get_product(loc)
		if(!throw_item)
			continue
		break
	if(!throw_item)
		return 0
	spawn(0)
		throw_item.throw_at(target, 16, 3, src)
	visible_message("<span class='warning'>\The [src] launches \a [throw_item] at \the [target]!</span>")
	return 1

//Actual machines are in vending_machines.dm

/obj/machinery/vending/proc/refill_inventory(obj/item/weapon/vending_refill/refill, mob/user)  //Restocking from TG
	var/total = 0

	var/to_restock = 0
	for(var/datum/stored_item/vending_product/machine_content in product_records)
		to_restock += machine_content.amount - machine_content.max_amount

	if(to_restock <= refill.charges)
		for(var/datum/stored_item/vending_product/machine_content in product_records)
			if(machine_content.amount != machine_content.max_amount)
				to_chat(usr, "<span class='notice'>[machine_content.amount - machine_content.max_amount] of [machine_content.item_name]</span>")
				machine_content.amount = machine_content.max_amount
		refill.charges -= to_restock
		total = to_restock
	else
		var/tmp_charges = refill.charges
		for(var/datum/stored_item/vending_product/machine_content in product_records)
			var/restock = CEIL(((machine_content.amount - machine_content.max_amount) / to_restock) * tmp_charges)
			if(restock > refill.charges)
				restock = refill.charges
			machine_content.amount += restock
			refill.charges -= restock
			total += restock
			if(restock)
				to_chat(usr, "<span class='notice'>[restock] of [machine_content.item_name]</span>")
			if(refill.charges == 0) //due to rounding, we ran out of refill charges, exit.
				break
	return total
