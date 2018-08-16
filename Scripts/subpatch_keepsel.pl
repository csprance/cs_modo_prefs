#perl
#AUTHOR: Seneca Menard
#version 1.83
#This script will convert the model you have partially selected to subDs while retaining your selection
#(7-29-07) : M3 broke my optimization, so I had to revert to the slower method again.  :(
#(12-18-10) : I put in a hack to support pixar subds.  Just run the script with the "psub" argument appended.
#(9-16-12) : added a user.value that lets you flip whether you use subds or psubs.  The reason why i added this is because i always use subds for games because they look better because of the edge pinching, but psubs for modo renders because they look better because of the faceting of the edges and the sharp corners.  i wanted a new option that i could toggle that would have my tab use either subds if it's off or psubs if it's on, because i used to just have two hotkeys, one for psubs and one for subds, but found that i pretty much ALWAYS forget to use the psubs one because i've been using the regular tab hotkey for so many years...  So to use this flip option, just create a button bound to this : "user.value subPatch_keepSel_typeFlip ?" and then the next time you fire "@subpatch_keepsel.pl", it'll flip whether to use psubs or subds if you actually pressed that button to turn it on.

#SCRIPT ARGUMENTS :
# psub : this argument is to tell the script that you want to toggle between pixar subds and back.  If you don't use this argument, then it will continue to use regular subds.

#A BUTTON TO ADD TO YOUR MODO GUI :
# "user.value subPatch_keepSel_typeFlip ?" : read the #(9-16-12) update notes a couple of lines above this one to see what this is for.

my $modoVer = lxq("query platformservice appversion ?");
my $mainlayer = lxq("query layerservice layers ? main");
my @fgLayers = lxq("query layerservice layers ? fg");
my %polyList;
my $psub = 0;

#SELECTION TYPE SAFETY CHECk.
if		(lxq( "select.typeFrom {vertex;edge;polygon;item} ?" ))	{}
elsif	(lxq( "select.typeFrom {edge;polygon;item;vertex} ?" ))	{}
elsif	(lxq( "select.typeFrom {polygon;vertex;edge;item} ?" ))	{}
else	{die("\n.\n[---------------------------------------------You're not in vert, edge, or polygon mode.--------------------------------------------]\n[--PLEASE TURN OFF THIS WARNING WINDOW by clicking on the (In the future) button and choose (Hide Message)--] \n[-----------------------------------This window is not supposed to come up, but I can't control that.---------------------------]\n.\n");}

#USER VALUES
userValueTools(subPatch_keepSel_typeFlip,boolean,config,"Flip whether subds or psubs are used","","","",xxx,xxx,"",0);

#SCRIPT ARGUMENTS
foreach my $arg (@ARGV){
	if ($arg =~ /psub/i)	{	$psub = 1;	}
}

if (lxq("user.value subPatch_keepSel_typeFlip ?") == 1){
	if ($psub == 1)	{	$psub = 0;	}
	else			{	$psub = 1;	}
}

#-----------------------------------------------------------------------------------
#MAIN ROUTINE
#-----------------------------------------------------------------------------------
#VERT MODE
if(lxq( "select.typeFrom {vertex;edge;polygon;item} ?" ) && lxq( "select.count vertex ?" )){
	my @verts = lxq("query layerservice verts ? selected");
	foreach my $vert (@verts){
		my @polys = lxq("query layerservice vert.polyList ? $vert");
		$polyList{@polys[0]} = 1;
	}
	selConnectedPolys("vertex");
}

#EDGE MODE
elsif(lxq( "select.typeFrom {edge;vertex;polygon;item} ?" ) && lxq( "select.count edge ?" )){
	my @edges = lxq("query layerservice edges ? selected");
	foreach my $edge (@edges){
		my @polys = lxq("query layerservice edge.polyList ? $edge");
		$polyList{@polys[0]} = 1;
	}
	selConnectedPolys("edge");
}

#POLY MODE
elsif(lxq( "select.typeFrom {polygon;vertex;edge;item} ?" ) && lxq( "select.count polygon ?" )){
	$sel_type = polygon;
	lx("select.editSet supertempBLAH add");
	lx("select.connect");
	toggleSubdivision();
	lx("select.drop polygon");
	lx("select.useSet supertempBLAH select");
	lx("select.editSet supertempBLAH remove");
}

#NOTHING'S SELECTED
else{
	lxout("Nothing's selected, so I'm subDing everything.");
	toggleSubdivision();
}



#-----------------------------------------------------------------------------------
#TOGGLE SUBDIVISION SUBROUTINE
#-----------------------------------------------------------------------------------
sub toggleSubdivision{
	if ( ($modoVer > 500) && ($psub == 1) ){
		lx("poly.convert face psubdiv true");
	}else{
		lx("poly.convert face subpatch true");
	}
}



#-----------------------------------------------------------------------------------
#CONVERT SUBROUTINE
#-----------------------------------------------------------------------------------
sub selConnectedPolys{
	lx("!!select.drop polygon");
	foreach my $poly (keys %polyList){lx("select.element $mainlayer polygon add $poly");}
	lx("!!select.connect");
	toggleSubdivision();
	lx("!!select.type @_[0]");
}

#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#SET UP THE USER VALUE OR VALIDATE IT   (no popups)
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
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

#-----------------------------------------------------------------------------------
#POPUP WINDOW subroutine
#-----------------------------------------------------------------------------------
sub popup #(MODO2 FIX)
{
	lx("dialog.setup yesNo");
	lx("dialog.msg {@_}");
	lx("dialog.open");
	my $confirm = lxq("dialog.result ?");
	if($confirm eq "no"){die;}
}
