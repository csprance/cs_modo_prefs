#perl
#BY: Seneca Menard
#version 2.42

#This script will select all of the elements on the object under your mouse.  I made it so I could quickly select a mesh from another layer without having to look thru the layer list or having to switch to item mode and back.
#So what you do is just hold your mouse over an element and it'll put you in that element's layer and select the rest of the elements for you, all in one click.  :)  Also, I just added a new feature that'll let you hide any objects
#that might be in the way before hte selection's made, such as background items.

#SCRIPT ARGUMENTS :
# "no" : if you use that argument, it'll select the item under the mouse, but won't select all of it's elements.
# "backdrop" "light" "camera" "meshInst" "txtrLocator" "groupLocator" etc.  Just type in any entity type names you wish to hide before the selection is made.  (the names have to be modo's exact names)

#(9-15-07 bugfix) : before, it would only select the verts or edges of the mesh under your mouse if your mouse was directly over one, now you can hold your mouse over the center of a poly and it'll still get it's verts or edges.
#(10-21-07 bugfix) : If you were in polygon mode and ran the script, it would accidentally put you in edge mode.  All fixed.
#(2-10-2008 feature) : sometimes, other items get in the way of what you're trying to select and so now the script has a way around that problem.  Just append any types of items you'd want to hide to the end of the script and
	#it'll temporarily hide those before it does the selections.  Here's an example : "@selectThatMesh.pl backdrop light"   That will hide all backdrops and light entities that might have been in the way before it selects the mesh.
#(4-28-08 bugfix) : if you use the arguments that lets you hide objects of certain types, it won't unhide all of the objects of that type anymore.
#(2-10-09 fix) : The script now forces visibility of the mainlayer and any of it's parents if they're hidden so the item selection will not fail.
#(3-31-09 bugfix) : found it's possible to have an active layer that's neither selected nor visible and put in a fix.
#(10-29-09 bugfix) : attempted to silence a modo complaint.  note : dunno if the error it's reporting can actually be silenced or not yet though..
#(3-19-11 feature) : now when you use this script on an instance, it will select the polys on the source of the instance, so it's a fast way to find the polys, even on instances.

#setup user value
userValueTools(sen_STM_mode,integer,config,"Selection mode:","mesh;part","","",0,10,"",0);
my $scriptMode = lxq("user.value sen_STM_mode ?");
my $mainlayer = lxq("query layerservice layers ? main");
my $mainlayerID = lxq("query layerservice layer.id ? main");
if (lxq("query sceneservice item.isSelected ? $mainlayerID") == 0){lx("!!select.subItem {$mainlayerID} add mesh;triSurf;meshInst;camera;light;backdrop;groupLocator;replicator;locator;deform;locdeform;chanModify;chanEffect 0 0");}

#verify that the mainlayer and it's parents are not hidden
my @verifyMainlayerVisibilityList = verifyMainlayerVisibility();	#to collect hidden parents and show them
my @hideTypes;
foreach my $arg (@ARGV){
	if 		($arg eq "no")		{our $no = 1;			}
	else						{push(@hideTypes,$arg);	}
}

#selection modes
if( lxq( "select.typeFrom {vertex;edge;polygon;item} ?" ) ) 	{	our $selType = "vertex";	}
elsif( lxq( "select.typeFrom {edge;polygon;item;vertex} ?" ) )	{	our $selType = "edge";		}
else															{	our $selType = "polygon";	}

#hide the obstructions
if (@hideTypes > 0){
	our @hidItems;
	my $itemCount = lxq("query sceneservice item.n ? all");
	for (my $i=0; $i<$itemCount; $i++){
		my $type = lxq("query sceneservice item.type ? $i");
		foreach my $hideType (@hideTypes){
			if ($type eq $hideType){
				my $id = lxq("query sceneservice item.id ? $i");

				if (visibleQuery($id) == 1){
					lx("!!layer.setVisibility {$id} visible:0");
					push(@hidItems,$id);
					next;
				}
			}
		}
	}
}

#select the mesh
lx("!!select.type item");
lx("!!select.3DElementUnderMouse set");
my @itemSel = lxq("query sceneservice selection ? all");
my @videoStillSelection = lxq("query sceneservice selection ? videoStill");
lx("select.subItem {$_} remove mediaClip") for @videoStillSelection;

my $itemType = lxq("query sceneservice item.type ? {$itemSel[-1]}");
if ($itemType eq "meshInst"){
	while (1){
		lx("select.itemSourceSelected");
		@itemSel = lxq("query sceneservice selection ? all");
		my $newSelItemType = lxq("query sceneservice item.type ? {$itemSel[-1]}");
		if ($newSelItemType eq "mesh"){last;}
	}
	lx("!!select.drop $selType");
	lx("!!select.all");
}elsif (@ARGV[0] ne "no"){
	if ($scriptMode eq "part"){
		lx("!!select.type polygon");
		lx("!!select.3DElementUnderMouse set");
		my $currentMainLayer = lxq("query layerservice layers ? main");
		my @polys = lxq("query layerservice polys ? selected");
		my $part = lxq("query layerservice poly.part ? $polys[-1]");
		if ($part ne "Default"){
			lx("!!select.polygon add part face {$part}");
		}else{
			lx("!!select.connect");
		}
	}else{
		lx("!!select.type polygon");
		lx("!!select.3DElementUnderMouse set");
		if ($selType ne "polygon"){lx("!!select.convert {$selType}");}
		lx("!!select.connect");
	}
}else{
	lx("!!select.type {$selType}");
}

#unhide the obstructions
if (@hidItems > 0){foreach my $id (@hidItems){lx("!!layer.setVisibility {$id} visible:1");}}

#restore the hidden items again.
verifyMainlayerVisibility(\@verifyMainlayerVisibilityList);		#to hide the hidden parents (and mainlayer) again.


#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#REMOVE ITEMS OF CERTAIN TYPES FROM ARRAY
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#usage : remItemTypesFromArray(\@itemList,mesh,meshInst,etc);
sub remItemTypesFromArray{
	my @newArray;
	foreach my $id (@{$_[0]}){
		my $keep = 1;
		my $itemType = lxq("query sceneservice item.type ? {$id}");
		for (my $i=1; $i<@_; $i++){
			if ($itemType eq $_[$i]){
				$keep = 0;
				last;
			}
		}
		if ($keep == 1){
			push(@newArray,$id);
		}
	}
	@{$_[0]} = @newArray;
}

#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#ITEM VISIBILITY QUERY
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#USAGE : if (visibleQuery(mesh024) == 1){}
sub visibleQuery{
	my $name = lxq("query sceneservice item.name ? @_[0]");
	my $channelCount = lxq("query sceneservice channel.n ?");
	for (my $i=0; $i<$channelCount; $i++){
		if (lxq("query sceneservice channel.name ? $i") eq "visible"){
			if (lxq("query sceneservice channel.value ? $i") ne "off"){
				return 1;
			}else{
				return 0;
			}
		}
	}
}

#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#MAINLAYER VISIBILITY ASSURANCE SUBROUTINE (toggles vis of mainlayer and/or parents if any are hidden)
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
# USAGE : (requires mainlayerID)
# my @verifyMainlayerVisibilityList = verifyMainlayerVisibility();	#to collect hidden parents and show them
# verifyMainlayerVisibility(\@verifyMainlayerVisibilityList);		#to hide the hidden parents (and mainlayer) again.
sub verifyMainlayerVisibility{
	my @hiddenParents;

	#hide the items again.
	if (@_ > 0){
		foreach my $id (@{@_[0]}){
			lxout("[->] : hiding $id");
			lx("!!layer.setVisibility {$id} visible:0");
		}
	}

	#show the mainlayer and all the mainlayer parents that are hidden (and retain a list for later use)
	else{
		if( lxq( "select.typeFrom {vertex;edge;polygon;item} ?" ) ){	our $tempSelMode = "vertex";	}
		if( lxq( "select.typeFrom {edge;polygon;item;vertex} ?" ) ){	our $tempSelMode = "edge";		}
		if( lxq( "select.typeFrom {polygon;item;vertex;edge} ?" ) ){	our $tempSelMode = "polygon";	}
		if( lxq( "select.typeFrom {item;vertex;edge;polygon} ?" ) ){	our $tempSelMode = "item";		}
		lx("!!select.type item");
		if (lxq("!!layer.setVisibility {$mainlayerID} visible:?") == 0){
			lxout("[->] : showing $mainlayerID");
			lx("!!layer.setVisibility {$mainlayerID} visible:1");
			push(@hiddenParents,$mainlayerID);
		}
		lx("!!select.type $tempSelMode");

		my $parentFind = 1;
		my $currentID = $mainlayerID;
		while ($parentFind == 1){
			my $parent = lxq("query sceneservice item.parent ? {$currentID}");
			if ($parent ne ""){
				$currentID = $parent;

				if (lxq("!!layer.setVisibility {$parent} visible:?") == 0){
					lxout("[->] : showing $parent");
					lx("!!layer.setVisibility {$parent} visible:1");
					push(@hiddenParents,$parent);
				}
			}else{
				$parentFind = 0;
			}
		}

		return(@hiddenParents);
	}
}


#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#POPUP SUB
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#USAGE : popup("What I wanna print");
sub popup #(MODO2 FIX)
{
	lx("dialog.setup yesNo");
	lx("dialog.msg {@_}");
	lx("dialog.open");
	my $confirm = lxq("dialog.result ?");
	if($confirm eq "no"){die;}
}

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#SET UP THE USER VALUE OR VALIDATE IT   (no popups)
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#userValueTools(name,type,life,username,list,listnames,argtype,min,max,action,value);
sub userValueTools{
	if (lxq("query scriptsysservice userValue.isdefined ? @_[0]") == 0){
		lxout("Setting up @_[0]--------------------------");
		lxout("Setting up @_[0]--------------------------");
		lxout("0=@_[0],1=@_[1],2=@_[2],3=@_[3],4=@_[4],5=@_[6],6=@_[6],7=@_[7],8=@_[8],9=@_[9],10=@_[10]");
		lxout("@_[0] didn't exist yet so I'm creating it.");
		lx( "user.defNew name:[@_[0]] type:[@_[1]] life:[@_[2]]");
		if (@_[3] ne "")	{	lxout("running user value setup 3");	lx("user.def [@_[0]] username [@_[3]]");	}
		if (@_[4] ne "")	{	lxout("running user value setup 4");	lx("user.def [@_[0]] list [@_[4]]");		}
		if (@_[5] ne "")	{	lxout("running user value setup 5");	lx("user.def [@_[0]] listnames [@_[5]]");	}
		if (@_[6] ne "")	{	lxout("running user value setup 6");	lx("user.def [@_[0]] argtype [@_[6]]");		}
		if (@_[7] ne "xxx")	{	lxout("running user value setup 7");	lx("user.def [@_[0]] min @_[7]");			}
		if (@_[8] ne "xxx")	{	lxout("running user value setup 8");	lx("user.def [@_[0]] max @_[8]");			}
		if (@_[9] ne "")	{	lxout("running user value setup 9");	lx("user.def [@_[0]] action [@_[9]]");		}
		if (@_[1] eq "string"){
			if (@_[10] eq ""){lxout("woah.  there's no value in the userVal sub!");							}		}
		elsif (@_[10] == ""){lxout("woah.  there's no value in the userVal sub!");									}
								lx("user.value [@_[0]] [@_[10]]");		lxout("running user value setup 10");
	}else{
		#STRING-------------
		if (@_[1] eq "string"){
			if (lxq("user.value @_[0] ?") eq ""){
				lxout("user value @_[0] was a blank string");
				lx("user.value [@_[0]] [@_[10]]");
			}
		}
		#BOOLEAN------------
		elsif (@_[1] eq "boolean"){

		}
		#LIST---------------
		elsif (@_[4] ne ""){
			if (lxq("user.value @_[0] ?") == -1){
				lxout("user value @_[0] was a blank list");
				lx("user.value [@_[0]] [@_[10]]");
			}
		}
		#ALL OTHER TYPES----
		elsif (lxq("user.value @_[0] ?") == ""){
			lxout("user value @_[0] was a blank number");
			lx("user.value [@_[0]] [@_[10]]");
		}
	}
}
