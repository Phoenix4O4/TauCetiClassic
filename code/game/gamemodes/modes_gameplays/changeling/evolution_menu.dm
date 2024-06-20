var/global/list/sting_paths
// totally stolen from the new player panel.  YAYY

/obj/effect/proc_holder/changeling/evolution_menu
	name = "-Evolution Menu-" //Dashes are so it's listed before all the other abilities.
	desc = "Choose our method of subjugation."
	button_icon_state = "evolution"
	genomecost = 0


/obj/effect/proc_holder/changeling/evolution_menu/Click()
	if(!usr || !ischangeling(usr))
		return
	sting_action(usr)

/obj/effect/proc_holder/changeling/evolution_menu/can_sting(mob/user)
	return TRUE

/obj/effect/proc_holder/changeling/evolution_menu/sting_action(mob/user)
	var/datum/role/changeling/changeling = user.mind.GetRoleByType(/datum/role/changeling)

	if(!sting_paths)
		sting_paths = init_paths(/obj/effect/proc_holder/changeling)

	var/dat = create_menu(changeling)
	var/datum/browser/popup = new(user, "window=powers", "Evolution menu", 600, 700, ntheme = CSS_THEME_LIGHT)
	popup.set_content(dat)
	popup.open()


/obj/effect/proc_holder/changeling/evolution_menu/proc/create_menu(datum/role/changeling/changeling)
	var/dat
	dat +="<html><head><title>Changling Evolution Menu</title></head>"

	//javascript, the part that does most of the work~
	dat += {"

		<head>
			<meta http-equiv='Content-Type' content='text/html; charset=utf-8'>
			<script type='text/javascript'>

				var locked_tabs = new Array();

				function updateSearch(){


					var filter_text = document.getElementById('filter');
					var filter = filter_text.value.toLowerCase();

					if(complete_list != null && complete_list != ""){
						var mtbl = document.getElementById("maintable_data_archive");
						mtbl.innerHTML = complete_list;
					}

					if(filter.value == ""){
						return;
					}else{

						var maintable_data = document.getElementById('maintable_data');
						var ltr = maintable_data.getElementsByTagName("tr");
						for ( var i = 0; i < ltr.length; ++i )
						{
							try{
								var tr = ltr\[i\];
								if(tr.getAttribute("id").indexOf("data") != 0){
									continue;
								}
								var ltd = tr.getElementsByTagName("td");
								var td = ltd\[0\];
								var lsearch = td.getElementsByTagName("b");
								var search = lsearch\[0\];
								//var inner_span = li.getElementsByTagName("span")\[1\] //Should only ever contain one element.
								//document.write("<p>"+search.innerText+"<br>"+filter+"<br>"+search.innerText.indexOf(filter))
								if ( search.innerText.toLowerCase().indexOf(filter) == -1 )
								{
									//document.write("a");
									//ltr.removeChild(tr);
									td.innerHTML = "";
									i--;
								}
							}catch(err) {   }
						}
					}

					var count = 0;
					var index = -1;
					var debug = document.getElementById("debug");

					locked_tabs = new Array();

				}

				function expand(id,name,desc,helptext,power,ownsthis){

					clearAll();

					var span = document.getElementById(id);

					body = "<table><tr><td>";

					body += "</td><td align='center'>";

					body += "<font size='2'><b>"+desc+"</b></font> <BR>"

					body += "<font size='2'><font color = 'red'><b>"+helptext+"</b></font></font> <BR>"

					if(!ownsthis)
					{
						body += "<a href='?src=\ref[src];P="+power+"'>Evolve</a>"
					}
					body += "</td><td align='center'>";

					body += "</td></tr></table>";


					span.innerHTML = body
				}

				function clearAll(){
					var spans = document.getElementsByTagName('span');
					for(var i = 0; i < spans.length; i++){
						var span = spans\[i\];

						var id = span.getAttribute("id");

						if(!(id.indexOf("item")==0))
							continue;

						var pass = 1;

						for(var j = 0; j < locked_tabs.length; j++){
							if(locked_tabs\[j\]==id){
								pass = 0;
								break;
							}
						}

						if(pass != 1)
							continue;




						span.innerHTML = "";
					}
				}

				function addToLocked(id,link_id,notice_span_id){
					var link = document.getElementById(link_id);
					var decision = link.getAttribute("name");
					if(decision == "1"){
						link.setAttribute("name","2");
					}else{
						link.setAttribute("name","1");
						removeFromLocked(id,link_id,notice_span_id);
						return;
					}

					var pass = 1;
					for(var j = 0; j < locked_tabs.length; j++){
						if(locked_tabs\[j\]==id){
							pass = 0;
							break;
						}
					}
					if(!pass)
						return;
					locked_tabs.push(id);
					var notice_span = document.getElementById(notice_span_id);
					notice_span.innerHTML = "<font color='red'>Locked</font> ";
					//link.setAttribute("onClick","attempt('"+id+"','"+link_id+"','"+notice_span_id+"');");
					//document.write("removeFromLocked('"+id+"','"+link_id+"','"+notice_span_id+"')");
					//document.write("aa - "+link.getAttribute("onClick"));
				}

				function attempt(ab){
					return ab;
				}

				function removeFromLocked(id,link_id,notice_span_id){
					//document.write("a");
					var index = 0;
					var pass = 0;
					for(var j = 0; j < locked_tabs.length; j++){
						if(locked_tabs\[j\]==id){
							pass = 1;
							index = j;
							break;
						}
					}
					if(!pass)
						return;
					locked_tabs\[index\] = "";
					var notice_span = document.getElementById(notice_span_id);
					notice_span.innerHTML = "";
					//var link = document.getElementById(link_id);
					//link.setAttribute("onClick","addToLocked('"+id+"','"+link_id+"','"+notice_span_id+"')");
				}

				function selectTextField(){
					var filter_text = document.getElementById('filter');
					filter_text.focus();
					filter_text.select();
				}

			</script>
		</head>


	"}

	//body tag start + onload and onkeypress (onkeyup) javascript event calls
	dat += "<body onload='selectTextField(); updateSearch();' onkeyup='updateSearch();'>"

	//title + search bar
	dat += {"

		<table width='560' align='center' cellspacing='0' cellpadding='5' id='maintable'>
			<tr id='title_tr'>
				<td align='center'>
					<font size='5'><b>Changeling Evolution Menu</b></font><br>
					Hover over a power to see more information<br>
					Current evolution points left to evolve with: [changeling.geneticpoints]<br>
					Absorb genomes to acquire more evolution points
					<p>
				</td>
			</tr>
			<tr id='search_tr'>
				<td align='center'>
					<b>Search:</b> <input type='text' id='filter' value='' style='width:300px;'>
				</td>
			</tr>
	</table>

	"}

	//player table header
	dat += {"
		<span id='maintable_data_archive'>
		<table width='560' align='center' cellspacing='0' cellpadding='5' id='maintable_data'>"}

	var/i = 1
	for(var/path in sting_paths)

		var/obj/effect/proc_holder/changeling/P = new path()
		if(P.genomecost <= 0) //Let's skip the crap we start with. Keeps the evolution menu uncluttered.
			continue

		var/ownsthis = changeling.has_sting(P)

		var/color
		if(ownsthis)
			if(i%2 == 0)
				color = "#d8ebd8"
			else
				color = "#c3dec3"
		else
			if(i%2 == 0)
				color = "#f2f2f2"
			else
				color = "#e6e6e6"


		dat += {"

			<tr id='data[i]' name='[i]' onClick="addToLocked('item[i]','data[i]','notice_span[i]')">
				<td align='center' bgcolor='[color]'>
					<span id='notice_span[i]'></span>
					<a id='link[i]'
					onmouseover='expand("item[i]","[P.name]","[P.desc]","[P.helptext]","[P]",[ownsthis])'
					>
					<span id='search[i]'><b>Evolve [P][ownsthis ? " - Purchased" : " - Cost: [P.genomecost]"]</b></span>
					</a>
					<br><span id='item[i]'></span>
				</td>
			</tr>

		"}

		i++


	//player table ending
	dat += {"
		</table>
		</span>

		<script type='text/javascript'>
			var maintable = document.getElementById("maintable_data_archive");
			var complete_list = maintable.innerHTML;
		</script>
	</body></html>
	"}
	return dat

/obj/effect/proc_holder/changeling/evolution_menu/Topic(href, href_list)
	..()
	if(!(iscarbon(usr) && ischangeling(usr)))
		return

	var/datum/role/changeling/C = usr.mind.GetRoleByType(/datum/role/changeling)
	if(href_list["P"])
		C.purchasePower(usr, href_list["P"])
	var/dat = create_menu(C)
	var/datum/browser/popup = new(usr, "window=powers", "Evolution menu", 600, 700, ntheme = CSS_THEME_LIGHT)
	popup.set_content(dat)
	popup.open()

/datum/role/changeling/proc/purchasePower(mob/living/carbon/user, sting_name)

	var/obj/effect/proc_holder/changeling/thepower = null

	if(!sting_paths)
		sting_paths = init_paths(/obj/effect/proc_holder/changeling)
	for(var/path in sting_paths)
		var/obj/effect/proc_holder/changeling/S = new path()
		if(S.name == sting_name)
			thepower = S

	if(thepower == null)
		to_chat(user, "This is awkward. Changeling power purchase failed, please report this bug to a coder!")
		return

	if(has_sting(thepower))
		to_chat(user, "We have already evolved this ability!")
		return

	if(geneticpoints < thepower.genomecost)
		to_chat(user, "We cannot evolve this... yet.  We must acquire more DNA.")
		return

	if(user.status_flags & FAKEDEATH)//To avoid potential exploits by buying new powers while in stasis, which clears your verblist.
		to_chat(user, "We lack the energy to evolve new abilities right now.")
		return

	geneticpoints -= thepower.genomecost
	purchasedpowers += thepower
	thepower.on_purchase(user)

//Call this proc after changeling mind-transfers (ex. lesserform)
/mob/proc/make_changeling()
	if(!mind)
		return

	if(!ishuman(src) && !ismonkey(src))
		return

	var/datum/role/changeling/C = mind.GetRoleByType(/datum/role/changeling)
	if(!C)
		create_and_setup_role(/datum/role/changeling, src, TRUE)
		return

	if(!sting_paths)
		sting_paths = init_paths(/obj/effect/proc_holder/changeling)
	if(C.purchasedpowers)
		remove_changeling_powers(TRUE)
	// purchase free powers.
	for(var/path in sting_paths)
		var/obj/effect/proc_holder/changeling/S = new path()
		if(!S.genomecost)
			if(!C.has_sting(S))
				C.purchasedpowers+=S
				S.on_purchase(src)

	C.absorbed_dna |= dna

	var/mob/living/carbon/human/H = src
	if(istype(H))
		C.absorbed_species += H.species.name

	for(var/language in languages)
		if(!(language in C.absorbed_languages))
			C.absorbed_languages += language

//Used to dump the languages from the changeling datum into the actual mob.
/mob/proc/changeling_update_languages(updated_languages)
	for(var/language in updated_languages)
		add_language(language)

/datum/role/changeling/proc/reset()
	chosen_sting = null
	geneticpoints = initial(geneticpoints)
	sting_range = initial(sting_range)
	chem_storage = initial(chem_storage)
	chem_recharge_rate = initial(chem_recharge_rate)
	chem_charges = min(chem_charges, chem_storage)
	mimicing = ""
	if(isliving(antag.current))
		var/mob/living/L = antag.current
		L.changeling_aug = FALSE

/mob/proc/remove_changeling_powers(keep_free_powers=0)
	if(ishuman(src) || ismonkey(src))
		if(ischangeling(src))
			var/datum/role/changeling/C = mind.GetRoleByType(/datum/role/changeling)
			C.reset()
			for(var/obj/effect/proc_holder/changeling/p in C.purchasedpowers)
				if(!(p.genomecost == 0 && keep_free_powers))
					qdel(p)
			if(hud_used)
				C.lingstingdisplay.invisibility = INVISIBILITY_ABSTRACT

/datum/role/changeling/proc/has_sting(obj/effect/proc_holder/changeling/power)
	for(var/obj/effect/proc_holder/changeling/P in purchasedpowers)
		if(power.type == P.type)
			return TRUE
	return FALSE
