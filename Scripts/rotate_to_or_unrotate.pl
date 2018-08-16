#perl
#AUTHOR: Seneca Menard  : TEMP : if you're rotating to other geometry, flip doesn't work because flip is not coded with the workplane querying
#version 1.21
#This script is for moving and rotating meshes to other meshes.  It's also for duplicating the current mesh and pasting it onto the other mesh under the mouse.  It's like a combination
#of the tack tool and mesh paint tool, but has additional features specifically so you can properly control the up/down orientation of the mesh AND so you can define an up/down orientation
#for multiple meshes with two single edges or 3 single verts...  Neither of those can be done with those two modo tools and that's why I thought this script was very important, is because I
#can't really use those two modo tools for those two reasons.

#SCRIPT ARGUMENTS
#1) "flip" : There's a bunch of special code to try to get your object facing upright every time, but there'll be a few times when you'll want to flip the object.  To do that, just append this cvar.
#2) "duplicate" : If you use this argument, I'll copy/paste the original selection to where your mouse is.  This cvar is so you can take an object and paste it all over other objects.
#3) "workplane" : If you want to immediately scale and rotate the mesh you just moved or pasted, you can use this argument to have me set the custom workplane and set the actr to origin so
#you can easily rotate and scale from the exact bottom of the new mesh.  Just don't forget that I have to change the actr to pivot and turn on a custom workplan in order to do that..

#VERT MODE :
#1) if you have verts selected, but no polys selected, it'll use the verts to determine the axis, and move the rest of the mesh connected to those verts.
#2) if you have verts selected, AND some polys selected, it'll use the verts to determine the axis, but move the selected polys.
#a) if your mouse is not over the geometry that's going to be moved, but other geometry, I'll move+rotate to that geometry's point in space.
#b) if your mouse is over the geometry that will be moved, I'll not rotateTo where your mouse is because you're telling it to rotateTo itself.  So, I unrotate the designated mesh instead.
#c) if your mouse is over no geometry, then I'll unrotate.

#EDGE MODE :
#1) if you have edges selected, but no polys selected, it'll use the edges to determine the axis, and move the rest of the mesh connected to those edges.
#2) if you have edges selected, AND some polys selected, it'll use the edges to determine the axis, but move the selected polys.
#a) if your mouse is not over the geometry that's going to be moved, but other geometry, I'll move+rotate to that geometry's point in space.
#b) if your mouse is over the geometry that will be moved, I'll not rotateTo where your mouse is because you're telling it to rotateTo itself.  So, I unrotate the designated mesh instead.
#c) if your mouse is over no geometry, then I'll unrotate.

#POLY MODE :
#1) if you have no polys selected : if your mouse is over a mesh, I'll use the axis of the poly your mouse is over and unrotate that mesh using that axis.
#2) if you have one poly selected : I'll use that one selected polygon to determine the axis, and then move/rotate the connected geometry.
#2a) if your mouse is over the mesh connected to that one selected poly, I'll unrotate that mesh using the selected poly's axis.
#2b) if your mouse is over no meshes, I'll unrotate the mesh connected to that selected poly using the selected poly's axis.
#3) if you have more than one poly selected : There's no way for me to determine the axis, so I assume Y up is up.  But, there's a special case.  When you perform the move/rotate, I
#write a special variable out to your cfg that describes what you had selected.  Next time you run the script, if you're going to perform the same type of edit to the same mesh, I'll use the
#last "UP" that was written to the cfg last time you used the script on that geometry.  This is really handy because you can now use the script multiple times with multiple polygons selected
#and it'll still know what is "UP".  The catch is, if you edit that mesh and then select it again and run the script, the variable could now be corrupt because what was up is now no longer up
#because you edited the mesh by yourself.  Plus, it only stores one variable to the config, so if you edit move/rotate meshA, then move/rotate meshB, you can't select meshA and move/rotate
#it again properly, because the variable's been overwritten with meshB's up axis.  But oh well.  If you really need to move/rotate meshA again and it's not pointing up anymore, you can just
#use one of the other selection modes and define up by yourself..   It's no big deal..
#3a) if your mouse is over unselected geometry, I'll move/rotate the selected geometry to that point in space.
#3b) if your mouse is over the selected geometry, I'll use the axis of the polygon that your mouse is over and unrotate the mesh connected to that polygon.
#3c) if your mouse is over no geometry, it'll unrotate the selected mesh by using the variable's up axis. (and only if the variable was written for that specific geometry, of course..)

#(8-21-07 bugfix) : if the last used viewport was the UV window, the rotate script would do a uv move instead of moving the object. That's fixed.
#(10-10-07 hack fix) : running select.expand twice on the conversion from edge sel to poly sel.
#(12-18-08 fix) : I went and removed the square brackets so that the numbers will always be read as metric units and also because my prior safety check would leave the unit system set to metric system if the script was canceled because changing that preference doesn't get undone if a script is cancelled.
#(2-10-09 fix) : The script now forces visibility of the mainlayer and any of it's parents if they're hidden so the item selection will not fail.
#(3-31-09 bugfix) : found it's possible to have an active layer that's neither selected nor visible and put in a fix.
#(6-25-09 bugfix) : found a bug with the vertex unrotate functions

#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================
#===																SAFETY CHECKS																	====
#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================



my $pi=3.14159265358979323;
my $Xcenter;
my $Ycenter;
my $Zcenter;
my $Xrotate;
my $Yrotate;
my $Zrotate;
my @wpBackup;
my @bbox=();
my $bbXcenter;
my $bbYbottom;
my $bbZcenter;
my @disp=();
my @WPmem;
my $selType;
#new
my $restoreSelection;
my $rotateTo;
my $headingFlip;
my @rotation;
my @objectBottom;
my $destType;

#mainlayer
my $mainlayer = lxq("query layerservice layers ? main");
my $mainlayerID = lxq("query layerservice layer.id ? $mainlayer");
if (lxq("query sceneservice item.isSelected ? $mainlayerID") == 0){lx("select.subItem {$mainlayerID} add mesh;triSurf;meshInst;camera;light;backdrop;groupLocator;replicator;locator;deform;locdeform;chanModify;chanEffect 0 0");}

#symm
our $symmAxis = lxq("select.symmetryState ?");
if 		($symmAxis eq "none")	{	$symmAxis = 3;	}
elsif	($symmAxis eq "x")		{	$symmAxis = 0;	}
elsif	($symmAxis eq "y")		{	$symmAxis = 1;	}
elsif	($symmAxis eq "z")		{	$symmAxis = 2;	}
if ($symmAxis != 3){
	lx("select.symmetryState none");
}

#save tool preset
lx("!!tool.makePreset name:tool.previous");
lx("tool.viewType xyz");

#Remember what the workplane was
@WPmem[0] = lxq ("workPlane.edit cenX:? ");
@WPmem[1] = lxq ("workPlane.edit cenY:? ");
@WPmem[2] = lxq ("workPlane.edit cenZ:? ");
@WPmem[3] = lxq ("workPlane.edit rotX:? ");
@WPmem[4] = lxq ("workPlane.edit rotY:? ");
@WPmem[5] = lxq ("workPlane.edit rotZ:? ");
lx("workPlane.reset ");

#layer reference (modded.  only references if not in item mode)
my $layerReference = lxq("layer.setReference ?");
if(lxq("select.typeFrom {item;vertex;edge;polygon;ptag} ?")){}else{lx("!!layer.setReference $mainlayerID");}

#make sure main layer is visible.  (to show the hidden mainlayer and/or it's parents and collect a list for later.)
my @verifyMainlayerVisibilityList = verifyMainlayerVisibility();


#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#REMEMBER SELECTION SETTINGS and then set it to selectauto  ((MODO2 FIX))
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#sets the ACTR preset
our $seltype;
our $selAxis;
our $selCenter;
our $actr = 1;
if( lxq( "tool.set actr.select ?") eq "on")				{	$seltype = "actr.select";		}
elsif( lxq( "tool.set actr.selectauto ?") eq "on")		{	$seltype = "actr.selectauto";	}
elsif( lxq( "tool.set actr.element ?") eq "on")			{	$seltype = "actr.element";		}
elsif( lxq( "tool.set actr.screen ?") eq "on")			{	$seltype = "actr.screen";		}
elsif( lxq( "tool.set actr.origin ?") eq "on")			{	$seltype = "actr.origin";		}
elsif( lxq( "tool.set actr.local ?") eq "on")			{	$seltype = "actr.local";		}
elsif( lxq( "tool.set actr.pivot ?") eq "on")			{	$seltype = "actr.pivot";		}
elsif( lxq( "tool.set actr.auto ?") eq "on")			{	$seltype = "actr.auto";			}
else
{
	$actr = 0;
	lxout("custom Action Center");
	if( lxq( "tool.set axis.select ?") eq "on")			{	 $selAxis = "select";			}
	elsif( lxq( "tool.set axis.element ?") eq "on")		{	 $selAxis = "element";			}
	elsif( lxq( "tool.set axis.view ?") eq "on")		{	 $selAxis = "view";				}
	elsif( lxq( "tool.set axis.origin ?") eq "on")		{	 $selAxis = "origin";			}
	elsif( lxq( "tool.set axis.local ?") eq "on")		{	 $selAxis = "local";			}
	elsif( lxq( "tool.set axis.pivot ?") eq "on")		{	 $selAxis = "pivot";			}
	elsif( lxq( "tool.set axis.auto ?") eq "on")		{	 $selAxis = "auto";				}
	else												{	 $actr = 1;  $seltype = "actr.auto"; lxout("You were using an action AXIS that I couldn't read");}

	if( lxq( "tool.set center.select ?") eq "on")		{	 $selCenter = "select";			}
	elsif( lxq( "tool.set center.element ?") eq "on")	{	 $selCenter = "element";		}
	elsif( lxq( "tool.set center.view ?") eq "on")		{	 $selCenter = "view";			}
	elsif( lxq( "tool.set center.origin ?") eq "on")	{	 $selCenter = "origin";			}
	elsif( lxq( "tool.set center.local ?") eq "on")		{	 $selCenter = "local";			}
	elsif( lxq( "tool.set center.pivot ?") eq "on")		{	 $selCenter = "pivot";			}
	elsif( lxq( "tool.set center.auto ?") eq "on")		{	 $selCenter = "auto";			}
	else												{ 	 $actr = 1;  $seltype = "actr.auto"; lxout("You were using an action CENTER that I couldn't read");}
}
lx("tool.set actr.auto on");



#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================
#===																SCRIPT ARGUMENTS																====
#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================
foreach my $arg (@ARGV){
	if		($arg eq "flip")		{	our $flipNormal = 1;	}
	elsif	($arg eq "duplicate")	{	our $duplicate = 1;		}
	elsif	($arg eq "workplane")	{	our $workplane = 1;		}
}


#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================
#===																		CVARS																		====
#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================
#create the sene_texMove variable if it didn't already exist.
if (lxq("query scriptsysservice userValue.isdefined ? sene_rotToObjHistory") == 0)
{
	lxout("-The sene_rotToObjHistory cvar didn't exist so I just created one");
	lx( "user.defNew sene_rotToObjHistory type:[string] life:[temporary]");
	#twelve characters total.
	#layer
	#selection mode
	#selection (0,1,-2,-1)
	#bbox notes (Xcen,Ybot,Zcen)
	#rotation notes (X,Y,Z)
	lx("user.value sene_rotToObjHistory [0,0,0,0,0,0,0,0,0,0,0,0]");
}
my $lastRunHistory = lxq("user.value sene_rotToObjHistory ?");
my @hist = split(/,/,$lastRunHistory);
#lxout("hist = @hist[0]<>@hist[1]<>@hist[2]<>@hist[3]<>@hist[4]<>@hist[5]<>@hist[6]<>@hist[7]<>@hist[8]<>@hist[9]<>@hist[10]<>@hist[11]");






#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================
#===																	SELECTION MODES																====
#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================

#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#VERTEX MODE
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
if( lxq( "select.typeFrom {vertex;edge;polygon;item} ?" ) ){
	$selType = vertex;
	our @verts = lxq("query layerservice verts ? selected");
	our @polys = lxq("query layerservice polys ? selected");

	if ($duplicate == 1){	&duplicate("vertex");	}

	#------------------------------------------------------------------------------------------------------------
	#SYMM OFF---------------------------------
	#------------------------------------------------------------------------------------------------------------
	if ($symmAxis == 3){
		#force poly selection if none are selected
		if (@polys == ""){
			$restoreSelection = 1;
			lx("select.expand");
			lx("select.expand");
			lx("select.convert polygon");
			lx("select.connect");
			@polys = lxq("query layerservice polys ? selected");
		}

		if ($duplicate != 1){&determineRotationMode;}
		&getVertsNormal(@verts);
		unrotate(@rotation);

		#edit the workplane if you're pointing to a poly pointing up.
		lxout("Xrotate=$Xrotate Yrotate=$Yrotate <> Zrotate=$Zrotate <> rotation=@rotation");
		if ((abs($Xrotate) < 0.1) && (abs($Zrotate) < 0.1) && (abs(@rotation[1]) < 0.1) && (abs(@rotation[2]) < 0.1)){ $Yrotate = -@rotation[0];  lxout("[->] removed the rotation"); }
		if ($rotateTo == 1){	&rotateTo;	}
		lx("select.type vertex");

		#restore original selection if I altered it.
		if ($restoreSelection == 1){
			lx("select.drop polygon");
			lx("select.drop vertex");
			foreach my $vert (@verts){  lx("select.element $mainlayer vertex add $vert");  }
		}
		&cleanup;
	}

	#------------------------------------------------------------------------------------------------------------
	#SYMM ON---------------------------------
	#------------------------------------------------------------------------------------------------------------
	else{
		#force poly selection if none are selected
		if (@polys == ""){
			$restoreSelection = 1;
		}

		#sort verts into symmetrical halves.
		our ($vertsPos,$vertsNeg) = sortSymm(vert,@verts);
		@vertsBak = @verts;

		#if polys were selected, then sort the polys
		if ($restoreSelection != 1){  our ($polysPos,$polysNeg) = sortSymm(poly,@polys);  }

		#--------------------------------------------------------------
		#run the script on the POSITIVE half
		#--------------------------------------------------------------
		if (@$vertsPos > 0){
			lxout("[->] running on POSITIVE half------------------------------------");
			@verts = @$vertsPos;

			#select polys : if SOME polys were selected
			if ($restoreSelection != 1){
				lx("select.drop polygon");
				foreach my $poly (@$polysPos){
					lx("select.element $mainlayer polygon add $poly");
				}
			}
			#select polys : if  NO polys were selected
			else{
				lx("select.drop vertex");
				foreach my $vert (@verts){
					lx("select.element $mainlayer vertex add $vert");
				}
				lx("select.expand");
				lx("select.expand");
				lx("select.convert polygon");
				lx("select.connect");
			}

			#now run the true script
			if ($duplicate != 1){&determineRotationMode;}
			&getVertsNormal(@verts);
			unrotate(@rotation);

			#edit the workplane if you're pointing to a poly pointing up.
			if ((abs($Xrotate) < 0.1) && (abs($Zrotate) < 0.1) && (abs(@rotation[1]) < 0.1) && (abs(@rotation[2]) < 0.1)){ $Yrotate = -@rotation[0];  lxout("[->] removed the rotation"); }
			if ($rotateTo == 1){	&rotateTo;	}
		}

		#--------------------------------------------------------------
		#run the script on the NEGATIVE half
		#--------------------------------------------------------------
		if (@$vertsNeg > 0){
			lxout("[->] running on NEG half------------------------------------");
			@verts = @$vertsNeg;

			#select polys : if SOME polys were selected
			if ($restoreSelection != 1){
				lx("select.drop polygon");
				foreach my $poly (@$polysNeg){
					lx("select.element $mainlayer polygon add $poly");
				}
			}
			#select polys : if  NO polys were selected
			else{
				lx("select.drop vertex");
				foreach my $vert (@verts){
					lx("select.element $mainlayer vertex add $vert");
				}
				lx("select.expand");
				lx("select.expand");
				lx("select.convert polygon");
				lx("select.connect");
			}

			#now run the true script
			if (  (@$vertsNeg > 1) && (@$vertsPos > 1)  ){
				@wpBackup = ($Xcenter,$Ycenter,$Zcenter,$Xrotate,$Yrotate,$Zrotate);  #backup the workplane so I can set it when the script ends

				if ($symmAxis == 0){
					@objectBottom = arrMath(@objectBottom,-1,1,1,mult);
					@rotation = arrMath(@rotation,-1,-1,1,mult);
					$Xcenter *= -1;
					$Yrotate *= -1;
					$Zrotate *= -1;
				}
				elsif ($symmAxis == 1){
					@objectBottom = arrMath(@objectBottom,1,-1,1,mult);
					@rotation = arrMath(@rotation,1,-1,-1,mult);
					$Ycenter *= -1;
					$Xrotate *= -1;
					$Zrotate *= -1;
				}
				elsif ($symmAxis == 2){
					@objectBottom = arrMath(@objectBottom,1,1,-1,mult);
					@rotation = arrMath(@rotation,-1,1,-1,mult);
					$Zcenter *= -1;
					$Yrotate *= -1;
					$Xrotate *= -1;
				}
			}else{
				lxout("[-->] NOT USING THE POSITIVE TRANSLATION FROM LAST ROUND");
				if ($duplicate != 1){&determineRotationMode;}
				&getVertsNormal(@verts);
			}
			unrotate(@rotation);
			#edit the workplane if you're pointing to a poly pointing up.
			if ((abs($Xrotate) < 0.1) && (abs($Zrotate) < 0.1) && (abs(@rotation[1]) < 0.1) && (abs(@rotation[2]) < 0.1)){ $Yrotate = -@rotation[0];  lxout("[->] removed the rotation"); }
			if ($rotateTo == 1){	&rotateTo;	}
		}

		#--------------------------------------------------------------
		#IF no polys were selected, I forced them selected and also forced verts.  So I need to drop polys and reselect original verts.
		#--------------------------------------------------------------
		if ($restoreSelection == 1){
			lx("select.drop polygon");
			lx("select.drop vertex");
			foreach my $vert (@vertsBak){  lx("select.element $mainlayer vertex add $vert");  }
		}
		#--------------------------------------------------------------
		#IF SOME polys were selected and the script was run on both symmetrical halves, I need to restore the pos poly half (verts are fine)
		#--------------------------------------------------------------
		elsif (  (@$vertsNeg > 1) && (@$vertsPos > 1)  ){
			foreach my $poly (@$polysPos){
				lx("select.element $mainlayer polygon add $poly");
			}
		}

		lx("select.type vertex");
		&cleanup;
	}
}










#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#EDGE MODE
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
elsif( lxq( "select.typeFrom {edge;polygon;item;vertex} ?" ) ){
	$selType = edge;
	our @edges=();
	our @polys = lxq("query layerservice polys ? selected");
	my @tempEdgeList = lxq("query layerservice selection ? edge");
	foreach my $edge (@tempEdgeList){	if ($edge =~ /\($mainlayer/){push(@edges,$edge);}	}
	s/\(\d{0,},/\(/  for @edges;

	if ($duplicate == 1){	&duplicate("edge");	}

	#force poly selection if none are selected
	if (@polys == ""){
		$restoreSelection = 1;
		lx("select.expand");
		lx("select.expand");
		lx("select.convert polygon");
		lx("select.connect");
		@polys = lxq("query layerservice polys ? selected");
	}

	#------------------------------------------------------------------------------------------------------------
	#SYMM OFF---------------------------------
	#------------------------------------------------------------------------------------------------------------
	if ($symmAxis == 3){
		if ($duplicate != 1){&determineRotationMode;}
		@objectBottom = getCorrectAvgEdgePos(@edges);
		&getEdgesNormal(@edges);
		unrotate(@rotation);

		lxout("Xrotate=$Xrotate Yrotate=$Yrotate <> Zrotate=$Zrotate <> rotation=@rotation");
		if ((abs($Xrotate) < 0.1) && (abs($Zrotate) < 0.1) && (abs(@rotation[1]) < 0.1) && (abs(@rotation[2]) < 0.1)){ $Yrotate = -@rotation[0];  lxout("[->] removed the rotation"); }
		if ($rotateTo == 1){	&rotateTo;	}
		lx("select.type edge");

		#restore original selection if I altered it.
		if ($restoreSelection == 1){
			lx("select.drop polygon");
			lx("select.drop edge");
			foreach my $edge (@edges){
				my @verts = split(/[^0-9]/, $edge);
				lx("select.element $mainlayer edge add @verts[1] @verts[2]");
			}
		}
		&cleanup;
	}

	#------------------------------------------------------------------------------------------------------------
	#SYMM ON---------------------------------
	#------------------------------------------------------------------------------------------------------------
	else{
		#force poly selection if none are selected
		if (@polys == ""){
			$restoreSelection = 1;
		}

		#sort verts into symmetrical halves.
		our ($edgesPos,$edgesNeg) = sortSymm(edge,@edges);
		@edgesBak = @edges;

		#if polys were selected, then sort the polys
		if ($restoreSelection != 1){  our ($polysPos,$polysNeg) = sortSymm(poly,@polys);  }

		#--------------------------------------------------------------
		#run the script on the POSITIVE half
		#--------------------------------------------------------------
		if (@$edgesPos > 0){
			lxout("[->] running on POSITIVE half------------------------------------");
			@edges = @$edgesPos;

			#select polys : if SOME polys were selected
			if ($restoreSelection != 1){
				lx("select.drop polygon");
				foreach my $poly (@$polysPos){
					lx("select.element $mainlayer polygon add $poly");
				}
			}
			#select polys : if  NO polys were selected
			else{
				lx("select.drop edge");
				foreach my $edge (@edges){
					my @verts = split(/[^0-9]/, $edge);
					lx("select.element $mainlayer edge add @verts[1] @verts[2]");
				}
				lx("select.expand");
				lx("select.expand");
				lx("select.convert polygon");
				lx("select.connect");
			}

			#now run the true script
			if ($duplicate != 1){&determineRotationMode;}
			@objectBottom = getCorrectAvgEdgePos(@edges);
			&getEdgesNormal(@edges);
			unrotate(@rotation);

			#edit the workplane if you're pointing to a poly pointing up.
			if ((abs($Xrotate) < 0.1) && (abs($Zrotate) < 0.1) && (abs(@rotation[1]) < 0.1) && (abs(@rotation[2]) < 0.1)){ $Yrotate = -@rotation[0];  lxout("[->] removed the rotation"); }
			if ($rotateTo == 1){	&rotateTo;	}
		}

		#--------------------------------------------------------------
		#run the script on the NEGATIVE half
		#--------------------------------------------------------------
		if (@$edgesNeg > 0){
			lxout("[->] running on NEGATIVE half------------------------------------");
			@edges = @$edgesNeg;

			#select polys : if SOME polys were selected
			if ($restoreSelection != 1){
				lx("select.drop polygon");
				foreach my $poly (@$polysNeg){
					lx("select.element $mainlayer polygon add $poly");
				}
			}
			#select polys : if  NO polys were selected
			else{
				lx("select.drop edge");
				foreach my $edge (@edges){
					my @verts = split(/[^0-9]/, $edge);
					lx("select.element $mainlayer edge add @verts[1] @verts[2]");
				}
				lx("select.expand");
				lx("select.expand");
				lx("select.convert polygon");
				lx("select.connect");
			}

			#now run the true script
			if (  (@$edgesNeg > 1) && (@$edgesPos > 1)  ){
				@wpBackup = ($Xcenter,$Ycenter,$Zcenter,$Xrotate,$Yrotate,$Zrotate);  #backup the workplane so I can set it when the script ends
				if ($symmAxis == 0){
					@objectBottom = arrMath(@objectBottom,-1,1,1,mult);
					@rotation = arrMath(@rotation,-1,-1,1,mult);
					$Xcenter *= -1;
					$Yrotate *= -1;
					$Zrotate *= -1;
				}
				elsif ($symmAxis == 1){
					@objectBottom = arrMath(@objectBottom,1,-1,1,mult);
					@rotation = arrMath(@rotation,1,-1,-1,mult);
					$Ycenter *= -1;
					$Xrotate *= -1;
					$Zrotate *= -1;
				}
				elsif ($symmAxis == 2){
					@objectBottom = arrMath(@objectBottom,1,1,-1,mult);
					@rotation = arrMath(@rotation,-1,1,-1,mult);
					$Zcenter *= -1;
					$Yrotate *= -1;
					$Xrotate *= -1;
				}
			}else{
				lxout("[-->] NOT USING THE POSITIVE TRANSLATION FROM LAST ROUND");
				if ($duplicate != 1){&determineRotationMode;}
				@objectBottom = getCorrectAvgEdgePos(@edges);
				&getEdgesNormal(@edges);
			}

			unrotate(@rotation);
			#edit the workplane if you're pointing to a poly pointing up.
			if ((abs($Xrotate) < 0.1) && (abs($Zrotate) < 0.1) && (abs(@rotation[1]) < 0.1) && (abs(@rotation[2]) < 0.1)){ $Yrotate = -@rotation[0];  lxout("[->] removed the rotation"); }
			if ($rotateTo == 1){	&rotateTo;	}
		}



		#--------------------------------------------------------------
		#IF no polys were selected, I forced them selected and also forced verts.  So I need to drop polys and reselect original verts.
		#--------------------------------------------------------------
		if ($restoreSelection == 1){
			lx("select.drop polygon");
			lx("select.drop edge");
			foreach my $edge (@edgesBak){
				my @verts = split(/[^0-9]/, $edge);
				lx("select.element $mainlayer edge add @verts[1] @verts[2]");
			}
		}
		#--------------------------------------------------------------
		#IF SOME polys were selected and the script was run on both symmetrical halves, I need to restore the pos poly half (verts are fine)
		#--------------------------------------------------------------
		elsif (  (@$edgesNeg > 1) && (@$edgesPos > 1)  ){
			foreach my $poly (@$polysPos){
				lx("select.element $mainlayer polygon add $poly");
			}
		}
		lx("select.type edge");
		&cleanup;
	}
}








#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#POLY MODE
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
elsif( lxq( "select.typeFrom {polygon;item;vertex;edge} ?" ) ){
	$selType = polygon;
	our @initialPolys = lxq("query layerservice polys ? selected");
	our @initialPolysBak = @initialPolys;
	my @polys;
	my $useSymmetry=0;

	if ($duplicate == 1){	&duplicate("polygon");	}

	#if symmetry is on and actual symmetrical geometry is selected, then run script on pos half and neg half.
	if ($symmAxis != 3){
		our ($polysPos,$polysNeg) = sortSymm(poly,@initialPolys);
		if (@$polysPos == @$polysNeg){
			$useSymmetry = 1;
			@initialPolys = @$polysPos;
			foreach my $poly (@$polysNeg){
				lx("select.element $mainlayer polygon remove $poly");
			}
		}
	}

	#------------------------------------------------------------------------------------------------------------
	#ONE POLY SELECTED
	#------------------------------------------------------------------------------------------------------------
	if (@initialPolys == 1){
		#[------------------------------------------]
		#SIDE ONE
		#[------------------------------------------]
		lx("select.connect");
		if ($duplicate != 1){$destType = &polyDetermineRotationMode;}
		getRotationFromSinglePoly(@initialPolys[0]);
		unrotate(@rotation);
		#rotate To
		if ($destType eq "new"){
			#edit the workplane if you're pointing to a poly pointing up.
			if ((abs($Xrotate) < 0.1) && (abs($Zrotate) < 0.1) && (abs(@rotation[1]) < 0.1) && (abs(@rotation[2]) < 0.1)){ $Yrotate = -@rotation[0];  lxout("[->] removed the rotation"); }
			&rotateTo;
		}

		#[------------------------------------------]
		#SIDE TWO
		#[------------------------------------------]
		if ($useSymmetry == 1){
			@wpBackup = ($Xcenter,$Ycenter,$Zcenter,$Xrotate,$Yrotate,$Zrotate);  #backup the workplane so I can set it when the script ends
			@initialPolys = @$polysNeg;
			lx("select.element $mainlayer polygon set @initialPolys[0]");
			lx("select.connect");
			&correctTheSymmValues;
			unrotate(@rotation);

			#rotate To
			if ($destType eq "new"){
				#edit the workplane if you're pointing to a poly pointing up.
				if ((abs($Xrotate) < 0.1) && (abs($Zrotate) < 0.1) && (abs(@rotation[1]) < 0.1) && (abs(@rotation[2]) < 0.1)){ $Yrotate = -@rotation[0];  lxout("[->] removed the rotation"); }
				&rotateTo;
			}
		}

		#[------------------------------------------]
		#SIDE 1+2 (restore + cleanup)
		#[------------------------------------------]
		#restore selections
		if ($useSymmetry == 1){
			lx("select.element $mainlayer polygon set @initialPolysBak[0]");
			lx("select.element $mainlayer polygon add @initialPolysBak[1]");
		}else{
			lx("select.element $mainlayer polygon set @initialPolys[0]");
		}
		&cleanup;
	}







	#------------------------------------------------------------------------------------------------------------
	#OVER 1 POLY SELECTED
	#------------------------------------------------------------------------------------------------------------
	elsif (@initialPolys > 1){
		if ($duplicate != 1){$destType = &polyDetermineRotationMode;}

		#[----------------------------------------------------------------------------------]
		#mouse over new geometry : so unrotate if can, then rotate to
		#[----------------------------------------------------------------------------------]
		if ($destType eq "new"){
			#[------------------------------------------]
			#SIDE ONE
			#[------------------------------------------]
			lxout("[->] POLY MODE : (>1 polys selected) : mouse over new geometry, so I'll try to history unrotate, then rotate to");

			#use history
			if (($mainlayer==@hist[0]) && ($selType eq @hist[1]) && (@initialPolysBak[0]==@hist[2]) && (@initialPolysBak[1]==@hist[3]) && (@initialPolysBak[-2]==@hist[4]) && (@initialPolysBak[-1]==@hist[5])){
				lxout("[->] I was able to history unrotate");
				our $historyAccept = 1;

				#if the object was rotated to the opposite side and there's two symmetrical halves, then flip the history
				if (($symmAxis != 3) && (@$polysPos > 0) && (@$polysNeg > 0)){
					if 		(($symmAxis == 0) && (@hist[6] < 0))	{	&correctTheSymmValues;		}
					elsif	(($symmAxis == 1) && (@hist[7] < 0))	{	&correctTheSymmValues;		}
					elsif	(($symmAxis == 2) && (@hist[8] < 0))	{	&correctTheSymmValues;		}
				}

				&removeRotation;
				@objectBottom = (@hist[6],@hist[7],@hist[8]);
			}

			#get bbox manually instead.
			else{
				my %vertTable;
				foreach my $poly (@initialPolys){
					my @verts = lxq("query layerservice poly.vertList ? $poly");
					foreach my $vert (@verts){
						$vertTable{$vert} = 1;
					}
				}

				my @bbox = boundingbox(keys %vertTable);
				@objectBottom = (  (@bbox[0]+@bbox[3])*0.5 , @bbox[1] , (@bbox[2]+@bbox[5])*0.5  );
			}

			#edit the workplane if you're pointing to a poly pointing up.  (this is for objects facing up but at weird angle)
			if ((abs($Xrotate) < 0.1) && (abs($Zrotate) < 0.1) && (abs(@rotation[1]) < 0.1) && (abs(@rotation[2]) < 0.1)){ $Yrotate = -@rotation[0];  lxout("[->] removed the rotation"); }
			&rotateTo;
			if ($duplicate == 1)	{	lx("user.value sene_rotToObjHistory [$mainlayer,$selType,@duplicateInitialPolys[0],@duplicateInitialPolys[1],@duplicateInitialPolys[2],@duplicateInitialPolys[3],$Xcenter,$Ycenter,$Zcenter,$Xrotate,$Yrotate,$Zrotate]");						}
			else					{	lx("user.value sene_rotToObjHistory [$mainlayer,$selType,@initialPolysBak[0],@initialPolysBak[1],@initialPolysBak[-2],@initialPolysBak[-1],$Xcenter,$Ycenter,$Zcenter,$Xrotate,$Yrotate,$Zrotate]");	}

			#[------------------------------------------]
			#SIDE TWO
			#[------------------------------------------]
			if ($useSymmetry == 1){
				@wpBackup = ($Xcenter,$Ycenter,$Zcenter,$Xrotate,$Yrotate,$Zrotate);  #backup the workplane so I can set it when the script ends
				@initialPolys = @$polysNeg;
				lx("select.drop polygon");
				foreach my $poly (@initialPolys){		lx("select.element $mainlayer polygon add $poly");	}
				&correctTheSymmValues;

				if ($historyAccept == 1){	&removeRotation;	}
				if ((abs($Xrotate) < 0.1) && (abs($Zrotate) < 0.1) && (abs(@rotation[1]) < 0.1) && (abs(@rotation[2]) < 0.1)){ $Yrotate = -@rotation[0];  lxout("[->] removed the rotation"); }
				&rotateTo;

				#restore selection
				lx("select.drop polygon");
				foreach my $poly (@initialPolysBak){	lx("select.element $mainlayer polygon add $poly");	}
			}

			&cleanup;
		}

		#[----------------------------------------------------------------------------------]
		#mouse over selected geometry, so unrotate
		#[----------------------------------------------------------------------------------]
		elsif ($destType eq "self"){
			lxout("[->] POLY MODE : (>1 polys selected) : mouse over itself, so I'll unrotate");
			#[------------------------------------------]
			#SIDE ONE
			#[------------------------------------------]
			my @newPolys = lxq("query layerservice polys ? selected");
			getRotationFromSinglePoly(@newPolys[-1]);
			unrotate(@rotation);
			if ($duplicate == 1)	{	lx("user.value sene_rotToObjHistory [$mainlayer,$selType,@duplicateInitialPolys[0],@duplicateInitialPolys[1],@duplicateInitialPolys[-2],@duplicateInitialPolys[-1],@objectBottom[0],@objectBottom[1],@objectBottom[2],0,0,0]");	}
			else					{	lx("user.value sene_rotToObjHistory [$mainlayer,$selType,@initialPolysBak[0],@initialPolysBak[1],@initialPolysBak[-2],@initialPolysBak[-1],@objectBottom[0],@objectBottom[1],@objectBottom[2],0,0,0]");	}


			#[------------------------------------------]
			#SIDE TWO
			#[------------------------------------------]
			if ($useSymmetry == 1){
				@initialPolys = @$polysNeg;
				lx("select.drop polygon");
				foreach my $poly (@initialPolys){		lx("select.element $mainlayer polygon add $poly");  }
				&correctTheSymmValues;
				unrotate(@rotation);

				#restore selection
				lx("select.drop polygon");
				foreach my $poly (@initialPolysBak){	lx("select.element $mainlayer polygon add $poly");	}
			}

			&cleanup;
		}

		#[----------------------------------------------------------------------------------]
		#mouse over nothing, so unrotate if can.
		#[----------------------------------------------------------------------------------]
		else{
			lxout("[->] POLY MODE : (>1 polys selected) : mouse over nothing, so I'll try to history unrotate");

			#[------------------------------------------]
			#SIDE ONE
			#[------------------------------------------]
			if	(($mainlayer==@hist[0]) && ($selType eq @hist[1]) && (@initialPolysBak[0]==@hist[2]) && (@initialPolysBak[1]==@hist[3]) && (@initialPolysBak[-2]==@hist[4]) && (@initialPolysBak[-1]==@hist[5])){
				lxout("[->] I was able to history unrotate");
				&removeRotation;
				if ($duplicate == 1)	{	lx("user.value sene_rotToObjHistory [$mainlayer,$selType,@duplicateInitialPolys[0],@duplicateInitialPolys[1],@duplicateInitialPolys[-2],@duplicateInitialPolys[-1],@hist[6],@hist[7],@hist[8],0,0,0]");	}
				else					{	lx("user.value sene_rotToObjHistory [$mainlayer,$selType,@initialPolysBak[0],@initialPolysBak[1],@initialPolysBak[-2],@initialPolysBak[-1],@hist[6],@hist[7],@hist[8],0,0,0]");	}

				#[------------------------------------------]
				#SIDE TWO
				#[------------------------------------------]
				if ($useSymmetry == 1){
					@initialPolys = @$polysNeg;
					lx("select.drop polygon");
					foreach my $poly (@initialPolys){		lx("select.element $mainlayer polygon add $poly");  }
					&correctTheSymmValues;
					&removeRotation;

					#restore selection
					lx("select.drop polygon");
					foreach my $poly (@initialPolysBak){	lx("select.element $mainlayer polygon add $poly");	}
				}
			}
			&cleanup;
		}
	}




	#------------------------------------------------------------------------------------------------------------
	#ZERO POLY SELECTED
	#------------------------------------------------------------------------------------------------------------
	elsif (@initialPolys == 0){
		lxout("[->] POLY MODE : (0 polys selected) : I'll try to unrotate the mesh under the mouse if there is one.");
		my @polys;

		#[------------------------------------------]
		#SIDE 1+2
		#[------------------------------------------]
		if ($useSymmetry == 1){
			if 		($symmAxis == 0){	our $symmState = "x";  }
			elsif	($symmAxis == 1){	our $symmState = "y";  }
			elsif	($symmAxis == 2){	our $symmState = "z";  }
			lx("select.symmetryState $symmState");
			lx("select.3DElementUnderMouse add");
			lx("select.symmetryState none");
			@polys = lxq("query layerservice polys ? selected");
			($polysPos,$polysNeg) = sortSymm(poly,@polys);
			if (@$polysPos == @$polysNeg){
				@polys = @$polysPos;
				lx("select.element $mainlayer polygon remove @$polysNeg[0]");
			}else{
				$useSymmetry = 0;
			}
		}

		#[------------------------------------------]
		#SIDE ONE
		#[------------------------------------------]
		else{
			lx("select.3DElementUnderMouse add");
			@polys = lxq("query layerservice polys ? selected");
		}
		if (@polys > 0){
			lxout("[->] found a mesh, so I'm unrotating it.");
			getRotationFromSinglePoly(@polys[-1]);
			lx("select.connect");
			unrotate(@rotation);
		}

		#[------------------------------------------]
		#SIDE TWO
		#[------------------------------------------]
		if ($useSymmetry == 1){
			@initialPolys = @$polysNeg;
			lx("select.element $mainlayer polygon set @$polysNeg[0]");
			lx("select.connect");
			&correctTheSymmValues;
			unrotate(@rotation);
		}

		#set the workplane variables
		$Xcenter = @objectBottom[0];  $Ycenter = @objectBottom[1];  $Zcenter = @objectBottom[2];  $Xrotate = 0;  $Yrotate = 0;  $Zrotate = 0;
		if 	(($symmAxis == 0) && (@objectBottom[0] < 0) && (@$polysPos > 0) && (@$polysNeg > 0))	{$Xcenter *= -1;}
		elsif (($symmAxis == 1) && (@objectBottom[1] < 0) && (@$polysPos > 0) && (@$polysNeg > 0))	{$Ycenter *= -1;}
		elsif (($symmAxis == 2) && (@objectBottom[2] < 0) && (@$polysPos > 0) && (@$polysNeg > 0))	{$Zcenter *= -1;}

		lx("select.drop polygon");
		&cleanup;
	}
}
















#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#ITEM MODE
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
elsif(lxq("select.typeFrom {item;vertex;edge;polygon;ptag} ?")){
	#make sure that an item is selected
	&verifyItemSelection;

	my $id = lxq("query layerservice layer.id ? $mainlayer");
	my @pos = lxq("query sceneservice item.pos ? $id");
	my @pivPos = lxq("query sceneservice item.pivPos ? $id");
	#popup("pos = @pos");
	#popup("pivPos = @pivPos");

	my $fgLayerCount1 = lxq("query layerservice layer.n ? fg");
	lx("select.3DElementUnderMouse add");
	my $fgLayerCount2 = lxq("query layerservice layer.n ? fg");

	#turn on and remember the workplane, then off again.
	lx("workplane.fitGeometry");
	$Xcenter = lxq ("workPlane.edit cenX:? ");
	$Ycenter = lxq ("workPlane.edit cenY:? ");
	$Zcenter = lxq ("workPlane.edit cenZ:? ");
	$Xrotate = lxq ("workPlane.edit rotX:? ");
	$Yrotate = lxq ("workPlane.edit rotY:? ");
	$Zrotate = lxq ("workPlane.edit rotZ:? ");
	lx("workPlane.reset ");

	#deselect that other item
	if ($fgLayerCount2 > $fgLayerCount1){
		lx("select.3DElementUnderMouse remove");
	}

	#if the mouse was over nothing, reset the rotation
	if (  ($Xcenter == 0) && ($Ycenter == 0) && ($Zcenter == 0)  ){
		lxout("[->] Mouse was over nothing, so I just reset the rotation");
		lx("item.channel locator\$rot.X {0}");
		lx("item.channel locator\$rot.Y {0}");
		lx("item.channel locator\$rot.Z {0}");
	}

	#if the mouse was over something, then move and rotate to it.
	else{
		lxout("[->] Mouse was over other geometry, so I moved/rotated to that point");
		my @disp = arrMath($Xcenter,$Ycenter,$Zcenter,@pivPos,subt);
		lxout("item rotation = $Xrotate,$Yrotate,$Zrotate");
		#$Xrotate *= -1;
		#if (  (abs($Yrotate) > 179) && (abs($Yrotate) < 181)  )	{	$Yrotate = 0;	}
		#elsif (  (abs($Yrotate) > 89) && (abs($Yrotate) < 91)  )	{	$Yrotate = 0;	}
		#$Zrotate += 180;
		if (abs($Yrotate)  > 90){	$Xrotate *= -1;	}
		lx("item.channel locator\$pos.X {@disp[0]}");
		lx("item.channel locator\$pos.Y {@disp[1]}");
		lx("item.channel locator\$pos.Z {@disp[2]}");
		lx("item.channel locator\$rot.Y {$Yrotate}");
		lx("item.channel locator\$rot.X {$Xrotate}");
		lx("item.channel locator\$rot.Z {$Zrotate}");
	}
	&cleanup;
}

else{die("\n.\n[------------------------------------------You're not in vert, edge, polygon  or item mode.----------------------------------------]\n[--PLEASE TURN OFF THIS WARNING WINDOW by clicking on the (In the future) button and choose (Hide Message)--] \n[-----------------------------------This window is not supposed to come up, but I can't control that.---------------------------]\n.\n");}











#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================
#===																MAIN ROUTINES																		====
#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================


#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
# DUPLICATE : RESELECT NEW VERTS
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub reselectNewElements{
	my %vertTable;
	foreach my $poly (@{$_[1]}){
		my @verts = lxq("query layerservice poly.vertList ? $poly");
		foreach my $vert (@verts) {  $vertTable{$vert} = 1;  }
	}
	#now sort the %vertTable and rebuild it.
	my @sortedArray = sort { $a <=> $b } (keys %vertTable);
	%vertTable = ();
	for (my $i=0; $i<@sortedArray; $i++){
		$vertTable{@sortedArray[$i]} = $i;
	}

	#now reselect the new verts by renaming the old ones.
	my $vertCount = lxq("query layerservice vert.n ? all");
	my @newSelectionList;

	#VERTEX CODE
	if (@_[2] eq "vertex"){
		lx("select.drop vertex");
		foreach my $vert (@{$_[0]}){
			my $newVert = ($vertCount-(keys %vertTable)+$vertTable{$vert});
			lx("select.element $mainlayer vertex add $newVert");
			push(@newSelectionList,$vert);
		}

		#now recreate the selected verts and selected polys arrays.
		@verts = @newSelectionList;
		if (@polys != ""){	@polys = lxq("query layerservice polys ? selected");	lxout("overwriting original polys array with copy/paste polys array");	}
	}

	#EDGE CODE
	if (@_[2] eq "edge"){
		lx("select.drop edge");
		foreach my $edge (@{$_[0]}){
			my @verts = split(/[^0-9]/,$edge);
			my $vert1 = $vertCount-(keys %vertTable)+$vertTable{@verts[1]};
			my $vert2 = $vertCount-(keys %vertTable)+$vertTable{@verts[2]};
			lx("select.element $mainlayer edge add $vert1 $vert2");
			push(@newSelectionList,"(".$vert1.",".$vert2.")");
		}

		#now recreate the selected verts and selected polys arrays.
		@edges = @newSelectionList;
		if (@polys != ""){	@polys = lxq("query layerservice polys ? selected");	lxout("overwriting original polys array with copy/paste polys array");	}
	}
}


#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
# DUPLICATE : RESELECT NEW POLYS
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub reselectNewPolys{
	my $polyCount = lxq("query layerservice poly.n ? all");
	my %polyTable;
	my @newPolys;

	for (my $i=0; $i<@{$_[1]}; $i++){
		$polyTable{@{$_[1]}[$i]} = $i;
	}

	lx("select.drop polygon");
	foreach my $poly (@{$_[0]}){
		my $newPoly = ($polyCount-(keys %polyTable)+$polyTable{$poly});
		push(@newPolys,$newPoly);
		lx("select.element $mainlayer polygon add $newPoly");
	}

	#now recreate the selected verts and selected polys arrays.
	@initialPolys = @newPolys;
	our @duplicateInitialPolys = (@newPolys[0], @newPolys[1], @newPolys[-2], @newPolys[-1]);
}


#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
# DUPLICATE : MAIN SUBROUTINE FOR COPYING/PASTING GEOMETRY.
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub duplicate{

	#[------------------------------------------]
	#VERTEX MODE
	#[------------------------------------------]
	if (@_[0] eq "vertex"){
		if (@verts == 0){die("\n.\n[------------------------------------You didn't have any verts selected so I'm killing the script------------------------------------]\n[--PLEASE TURN OFF THIS WARNING WINDOW by clicking on the (In the future) button and choose (Hide Message)--] \n[-----------------------------------This window is not supposed to come up, but I can't control that.---------------------------]\n.\n");}

		&determineRotationMode;
		lx("select.type vertex");

		if (@polys == 0){
			lx("select.expand");
			lx("select.expand");
			lx("select.convert polygon");
			lx("select.connect");
			our @polys = lxq("query layerservice polys ? selected");
			#TEMP : do I wanna drop the polys or keep 'em selected?  drop=slower, but better
		}else{
			lx("select.type polygon");
		}
		lx("select.copy");
		lx("select.drop polygon");
		lx("select.invert");
		lx("select.paste");
		lx("select.invert");

		#now reselect the verts
		&reselectNewElements(\@verts,\@polys,vertex);
	}

	#[------------------------------------------]
	#EDGE MODE
	#[------------------------------------------]
	elsif (@_[0] eq "edge"){
		if (@edges == 0){die("\n.\n[------------------------------------You didn't have any edges selected so I'm killing the script-----------------------------------]\n[--PLEASE TURN OFF THIS WARNING WINDOW by clicking on the (In the future) button and choose (Hide Message)--] \n[-----------------------------------This window is not supposed to come up, but I can't control that.---------------------------]\n.\n");}

		&determineRotationMode;
		lx("select.type edge");

		if (@polys == 0){
			lx("select.expand");
			lx("select.expand");
			lx("select.convert polygon");
			lx("select.connect");
			our @polys = lxq("query layerservice polys ? selected");
			#TEMP : do I wanna drop the polys or keep 'em selected?  drop=slower, but better
		}else{
			lx("select.type polygon");
		}
		lx("select.copy");
		lx("select.drop polygon");
		lx("select.invert");
		lx("select.paste");
		lx("select.invert");

		#now reselect the edges
		&reselectNewElements(\@edges,\@polys,edge);
	}

	#[------------------------------------------]
	#POLY MODE
	#[------------------------------------------]
	elsif (@_[0] eq "polygon"){
		if (@initialPolys == 0){die("\n.\n[------------------------------------You didn't have any polys selected so I'm killing the script------------------------------------]\n[--PLEASE TURN OFF THIS WARNING WINDOW by clicking on the (In the future) button and choose (Hide Message)--] \n[-----------------------------------This window is not supposed to come up, but I can't control that.---------------------------]\n.\n");}

		$destType = &polyDetermineRotationMode;

		lx("select.connect");
		my @newPolys = lxq("query layerservice polys ? selected");
		lx("select.copy");
		lx("select.drop polygon");
		lx("select.invert");
		lx("select.paste");
		lx("select.invert");

		#now reselect the polys
		&reselectNewPolys(\@initialPolys,\@newPolys);
	}
	else{
		popup("failed to use the duplicate subroutine properly");
	}
}





#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
# MAKE SURE THAT A LAYER ITEM IS SELECTED, IF NOT KILL SCRIPT.
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub verifyItemSelection{
	my $items = lxq("query sceneservice item.N ? all");
	my $meshItem=0;
	for (my $i=0; $i<$items; $i++){
		my $type = lxq("query sceneservice item.type ? $i");
		if ($type eq "mesh"){
			my $selected = lxq("query sceneservice item.isSelected ? $i");
			if ($selected == 1){
				$meshItem = 1;
				last;
			}
		}
	}

	if ($meshItem == 0){
		die("\n.\n[------------------------------------You didn't have an object selected so I'm killing the script------------------------------------]\n[--PLEASE TURN OFF THIS WARNING WINDOW by clicking on the (In the future) button and choose (Hide Message)--] \n[-----------------------------------This window is not supposed to come up, but I can't control that.---------------------------]\n.\n");
	}
}


#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
# CORRECT THE SYMMETRY VALUES FOR THE OTHER HALF
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub correctTheSymmValues{
	if ($symmAxis == 0){
		@objectBottom = arrMath(@objectBottom,-1,1,1,mult);
		@rotation = arrMath(@rotation,-1,-1,1,mult);
		$Xcenter *= -1;
		$Yrotate *= -1;
		$Zrotate *= -1;
		@hist[6] *= -1;
		@hist[10] *= -1;
		@hist[11] *= -1;
	}
	elsif ($symmAxis == 1){
		@objectBottom = arrMath(@objectBottom,1,-1,1,mult);
		@rotation = arrMath(@rotation,1,-1,-1,mult);
		$Ycenter *= -1;
		$Xrotate *= -1;
		$Zrotate *= -1;
		@hist[7] *= -1;
		@hist[9] *= -1;
		@hist[11] *= -1;
	}
	elsif ($symmAxis == 2){
		@objectBottom = arrMath(@objectBottom,1,1,-1,mult);
		@rotation = arrMath(@rotation,-1,1,-1,mult);
		$Zcenter *= -1;
		$Yrotate *= -1;
		$Xrotate *= -1;
		@hist[8] *= -1;
		@hist[10] *= -1;
		@hist[9] *= -1;
	}
}


#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
# GET A ROTATION FROM A SINGLE POLY
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub getRotationFromSinglePoly{
	@normal = lxq("query layerservice poly.normal ? @_");
	#flip the normal if the user says to. (and because I need it flipped, I'll do the inverse)
	if ($flipNormal != 1){@normal = arrMath(@normal,-1,-1,-1,mult);}
	@objectBottom = lxq("query layerservice poly.pos ? @_");
	lxout("objectBottom = @objectBottom");
	my @verts = lxq("query layerservice poly.vertList ? @_");
	my @pos1 = lxq("query layerservice vert.pos ? @verts[0]");
	my @pos2 = lxq("query layerservice vert.pos ? @verts[1]");
	my @pos3 = lxq("query layerservice vert.pos ? @verts[-1]");
	my @disp1 = arrMath(@pos2,@pos1,subt);
	my @disp2 = arrMath(@pos3,@pos1,subt);
	my $dist1 = sqrt((@disp1[0]*@disp1[0])+(@disp1[1]*@disp1[1])+(@disp1[2]*@disp1[2]));
	my $dist2 = sqrt((@disp2[0]*@disp2[0])+(@disp2[1]*@disp2[1])+(@disp2[2]*@disp2[2]));
	my @vector1;
	if ($dist2 > $dist1)	{	@vector1 = unitVector(@disp2);	}
	else					{	@vector1 = unitVector(@disp1);	}
	my @vector3 = crossProduct(\@vector1,\@normal);

	@rotation = matrixToEuler(\@vector1,\@normal,\@vector3);
	@rotation = ((@rotation[0]*180)/$pi,(@rotation[1]*180)/$pi,(@rotation[2]*180)/$pi);
}

#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
# POLY MODE : determine whether or not the user wants to unrotate or rotateTo
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub polyDetermineRotationMode{
	#check if mouse is over a new layer, if so make it active.
	my $fgLayerCount1 = lxq("query layerservice layer.n ? fg");
	lx("select.type item");
	if (lxq("layer.setVisibility $mainlayerID ?") == 0){lx("layer.setVisibility $mainlayerID 1");}
	lx("select.3DElementUnderMouse add");
	my $fgLayerCount2 = lxq("query layerservice layer.n ? fg");

	#turn on and remember the workplane, then off again.
	lx("workplane.fitGeometry");
	$Xcenter = lxq ("workPlane.edit cenX:? ");
	$Ycenter = lxq ("workPlane.edit cenY:? ");
	$Zcenter = lxq ("workPlane.edit cenZ:? ");
	$Xrotate = lxq ("workPlane.edit rotX:? ");
	$Yrotate = lxq ("workPlane.edit rotY:? ");
	$Zrotate = lxq ("workPlane.edit rotZ:? ");
	lx("workPlane.reset ");

	#now check the polys under the mouse to see if you're over old or new geometry.
	my $polyCount1 = lxq("select.count polygon ?");
	#popup("polyCount1 = $polyCount1");
	lx("select.type polygon");
	lx("select.3DElementUnderMouse remove");
	my $polyCount2 = lxq("select.count polygon ?");
	#popup("polyCount2 = $polyCount2");
	lx("select.3DElementUnderMouse add");
	my $polyCount3 = lxq("select.count polygon ?");
	#popup("polyCount3 = $polyCount3");

	#if I selected a new layer, deselect it now.
	if ($fgLayerCount2 > $fgLayerCount1){
		lx("select.type item");
		lx("select.3DElementUnderMouse remove");
	}

	#return the answer
	if (($polyCount1 == $polyCount2) && ($polyCount1 == $polyCount3)){
		lxout("[->] Mouse is over NOTHING");
		return("nothing");
	}
	elsif ($polyCount3 > $polyCount1){
		lxout("[->] Mouse is over NEW GEOMETRY");
		lx("select.type polygon");
		lx("select.3DElementUnderMouse remove");
		$rotateTo = 1;
		return("new");
	}
	elsif ($polyCount3 == $polyCount1){
		lxout("[->] Mouse is over SELF");
		return("self");
	}
}


#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#rotate to subroutine
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub rotateTo{
	my @disp = arrMath($Xcenter,$Ycenter,$Zcenter,@objectBottom,subt);

	#ROTATION
	if (($Xrotate != 0) || ($Yrotate != 0) || ($Zrotate != 0)){
		lx("tool.set xfrm.rotate on");
		lx("tool.reset");
		lx("tool.setAttr center.auto cenX {@objectBottom[0]}");
		lx("tool.setAttr center.auto cenY {@objectBottom[1]}");
		lx("tool.setAttr center.auto cenZ {@objectBottom[2]}");
		#rotate selectionY
		lx("tool.setAttr axis.auto axisY {1}");
		lx("tool.setAttr axis.auto axis {1}");
		lx("tool.setAttr xfrm.rotate angle {$Yrotate}");
		lx("tool.doapply");
		#rotate selectionX
		lx("tool.setAttr axis.auto axisX {1}");
		lx("tool.setAttr axis.auto axis {0}");
		lx("tool.setAttr xfrm.rotate angle {$Xrotate}");
		lx("tool.doApply");
		#rotate selectionZ
		lx("tool.setAttr axis.auto axisZ {1}");
		lx("tool.setAttr axis.auto axis {2}");
		lx("tool.setAttr xfrm.rotate angle {$Zrotate}");
		lx("tool.doApply");
		lx("tool.set xfrm.rotate off");
	}

	#MOVE
	lx("tool.set xfrm.move on");
	lx("tool.reset");
	lx("tool.attr xfrm.move X {@disp[0]}");
	lx("tool.attr xfrm.move Y {@disp[1]}");
	lx("tool.attr xfrm.move Z {@disp[2]}");
	lx("tool.doApply");
	lx("tool.set xfrm.move off");
}


#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#unrotate the selected polygons.
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub unrotate{
	my ($heading,$altitude,$bank) = @_;
	#my @rotationPrint = (int($heading),int($altitude),int($bank));
	#lxout("heading=@rotationPrint[0]\naltitude=@rotationPrint[1]\nbank=@rotationPrint[2]");



	lx("select.type polygon");
	lx("tool.set xfrm.rotate on");
	lx("tool.reset");
	lx("tool.setAttr center.auto cenX {@objectBottom[0]}");
	lx("tool.setAttr center.auto cenY {@objectBottom[1]}");
	lx("tool.setAttr center.auto cenZ {@objectBottom[2]}");
	#rotate selectionX
	lx("tool.setAttr axis.auto axisX {1}");
	lx("tool.setAttr axis.auto axis {0}");
	lx("tool.setAttr xfrm.rotate angle {$bank}");
	lx("tool.doApply");
	#rotate selectionZ
	lx("tool.setAttr axis.auto axisZ {1}");
	lx("tool.setAttr axis.auto axis {2}");
	lx("tool.setAttr xfrm.rotate angle {$altitude}");
	lx("tool.doApply");
	#rotate selectionY
	lx("tool.setAttr axis.auto axisY {1}");
	lx("tool.setAttr axis.auto axis {1}");
	lx("tool.setAttr xfrm.rotate angle {$heading}");
	lx("tool.doapply");
	lx("tool.set xfrm.rotate off");
}


#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#get the normal (VERT MODE)
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub getVertsNormal{
	my @verts = @_;
	my @importantVerts;

	#get object bottom
	@objectBottom = getCorrectAvgVertPos(@verts);
	#lxout("objectBottom = @objectBottom");

	#collect the important verts
	if (@verts > 4){
		@importantVerts[0] = @verts[0];
		@importantVerts[1] = @verts[int(@verts*.33)];
		@importantVerts[2] = @verts[int(@verts*.66)];
	}else{
		@importantVerts = @verts;
	}
lxout("importantVerts = @importantVerts");
	my @pos1 = lxq("query layerservice vert.pos ? @importantVerts[0]");
	my @pos2 = lxq("query layerservice vert.pos ? @importantVerts[1]");
	my @pos3 = lxq("query layerservice vert.pos ? @importantVerts[2]");

	#force reordering of the selected verts to get the best axis  (note it's actually reordering the @pos1,2,3 values so they no longer pay attention to the vert order)
	my @disp1a = unitVector(arrMath(@pos1,@pos2,subt));
	my @disp1b = unitVector(arrMath(@pos1,@pos3,subt));
	my @disp2a = unitVector(arrMath(@pos2,@pos1,subt));
	my @disp2b = unitVector(arrMath(@pos2,@pos3,subt));
	my @disp3a = unitVector(arrMath(@pos3,@pos1,subt));
	my @disp3b = unitVector(arrMath(@pos3,@pos2,subt));

	my $dp1 = dotProduct(\@disp1a,\@disp1b);
	my $dp2 = dotProduct(\@disp2a,\@disp2b);
	my $dp3 = dotProduct(\@disp3a,\@disp3b);
	my $greatestDP;
	my $greatestDPIndice;
	if (abs($dp1) < abs($dp2))			{	$greatestDP = $dp1;	$greatestDPIndice = 0;	}
	else								{	$greatestDP = $dp2;	$greatestDPIndice = 1;	}
	if(abs($dp3) < abs($greatestDP))	{	$greatestDP = $dp3;	$greatestDPIndice = 2;	}

	if		($greatestDPIndice == 0)	{
		lxout("most important vert = @importantVerts[0]");

	}elsif	($greatestDPIndice == 1)	{
		lxout("most important vert = @importantVerts[1]");
		@pos1Bak = @pos1;
		@pos1 = @pos2;
		@pos2 = @pos1Bak;
		@importantVerts = ($importantVerts[1],$importantVerts[0],$importantVerts[2]);
	}else{
		lxout("most important vert = @importantVerts[2]");
		@pos1Bak = @pos1;
		@pos1 = @pos3;
		@pos3 = @pos1Bak;
		@importantVerts = ($importantVerts[2],$importantVerts[0],$importantVerts[1]);
	}
	lxout("importantVerts = @importantVerts");


	#define the vectors
	my @vector1 = unitVector(arrMath(@pos2,@pos1,subt));
	my @vector2 = unitVector(arrMath(@pos3,@pos1,subt));
	my @normal = unitVector(crossProduct(\@vector1,\@vector2));
	my @vector1a = unitVector(crossProduct(\@vector2,\@normal));

#createPipe(@pos1,@vector1,60,1);
#createPipe(@pos1,@vector2,60,2);
#createPipe(@pos1,@normal,60,3);
#createPipe(@pos1,@vector1a,60,4);
#return;


	#determine whether or not the verts are on a boundary or not.
	my $nonBorder=0;
	foreach my $vert (@importantVerts){
		if ($nonBorder == 1){last;}
		my @connectedVerts = lxq("query layerservice vert.vertList ? $vert");
		for (my $i=0; $i<@connectedVerts; $i++){
			#lxout("[[BOUNDARY CHECK]]  vert=($vert) edge=($vert,@connectedVerts[$i])");
			my @currEdgePolys = lxq("query layerservice edge.polyList ? [($vert,@connectedVerts[$i])]");
			if (  (@currEdgePolys > 1) && ($i == $#connectedVerts)  ){
				#lxout("     The loop is done and I couldn't find an edge with a border, so this vert ($vert) is nonborder");
				$nonBorder = 1;
			}
		}
	}

	#now check the nearest polys' centers to find which direction is "up"
	my @nearestPolys = lxq("query layerservice vert.polyList ? @importantVerts[0]");
	my @centerToPoly = ();
	for (my $i=0; $i<@nearestPolys; $i++){
		our @polyPos = lxq("query layerservice poly.pos ? @nearestPolys[$i]");
		lxout("nearestPolys[$i] = @nearestPolys[$i]");
		@centerToPoly = arrMath(@polyPos,@objectBottom,subt);
		lxout("centerToPoly = @centerToPoly");

		#IF POLY POS THE SAME
		if (  (abs(@centerToPoly[0]) <  0.001) && (abs(@centerToPoly[1]) <  0.001) && (abs(@centerToPoly[2]) <  0.001)  ){
			#IF THIS IS LAST POLY, END
			if ($i == $#nearestPolys){
				lxout("[<>] POLY POS == OBJECT BOTTOM (matching poly normal) [<>]");
				my @polyNormal = lxq("query layerservice poly.normal ? @nearestPolys[$i]");
				if (dotProduct(\@normal,\@polyNormal) < 0){arrMath(@normal,-1,-1,-1,mult);}

				#IF NONBORDER VERTS, FLIP NORMAL
				if ($nonBorder == 1){
					lxout("[<>] FLIPPING POLY NORMAL (because coplanar and NOT boundary) [<>]");
					@normal = arrMath(@normal,-1,-1,-1,mult);
					@vector1a = arrMath(@vector1a,-1,-1,-1,mult);
					@vector2 = arrMath(@vector2,-1,-1,-1,mult);
				}
			}
			#IF NOT LAST POLY, NEXT
			else{
				lxout("[<>] poly (@nearestPolys[$i]) in same place as edges, but not last poly so skipping [<>]");
				next;
			}
		}

		#IF POLY POS NOT THE SAME
		else{
			@centerToPoly = unitVector(@centerToPoly);
			my $dp = dotProduct(\@normal,\@centerToPoly);
			lxout("dp = $dp");

			#(ABOVE)  : IF ABS(DP) < 0
			if ($dp > 0.02){
				lxout("[<>] NORMAL > (using normal) [<>]");
				last;
			}
			#(BELOW) : IF ABS(DP) > 0
			elsif ($dp < -0.02){
				lxout("[<>] NORMAL < (using neg normal) [<>]");
				lxout("normal = @normal");
				lxout("vector1a = @vector1a");
				lxout("vector2 = @vector2");
				@normal = arrMath(@normal,-1,-1,-1,mult);
				#@vector1a = arrMath(@vector1a,-1,-1,-1,mult);
				@vector2 = arrMath(@vector2,-1,-1,-1,mult);
				lxout("normal = @normal");
				lxout("vector1a = @vector1a");
				lxout("vector2 = @vector2");

				last;
			}
			#(COPLANAR) : ELSE
			else{
				#IF THIS IS LAST POLY, END
				if ($i == $#nearestPolys){
					lxout("[<>] NORMAL COPLANAR (matching poly normal)[<>]");
					my @polyNormal = lxq("query layerservice poly.normal ? @nearestPolys[$i]");
					if (dotProduct(\@normal,\@polyNormal) < 0){arrMath(@normal,-1,-1,-1,mult);}

					#IF NONBORDER VERTS, FLIP NORMAL
					if ($nonBorder == 1){
						lxout("[<>] FLIPPING POLY NORMAL (because coplanar and NOT boundary) [<>]");
						@normal = arrMath(@normal,-1,-1,-1,mult);
					}
				}
				#IF NOT LAST POLY, NEXT
				else{
					lxout("[<>] poly (@nearestPolys[$i]) is coplanar, but not last poly so skipping [<>]");
					next;
				}
			}
		}
	}

	#now flip the axis if the flipArg said to.
	if ($flipNormal == 1){
		lxout("flipping normal because user argument said I should");
		@normal = arrMath(@normal,-1,-1,-1,mult);
	}

#createPipe(@pos1,@vector1,60,1);
#createPipe(@pos1,@vector2,60,2);
#createPipe(@pos1,@normal,60,3);
#createPipe(@pos1,@vector1a,60,4);
#return;


	#now convert the vectors into a world-aligned matrix
	@rotation = matrixToEuler(\@vector2,\@normal,\@vector1a);
	@rotation = ((@rotation[0]*180)/$pi,(@rotation[1]*180)/$pi,(@rotation[2]*180)/$pi);
}




#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#get the normal (EDGE MODE)
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub getEdgesNormal{
	my @edges = @_;
	my $safetyCheckFail;

	my @edgeVerts1 = split(/[^0-9]/,@edges[0]);
	my @edgeVerts2;
	if (@edges < 5)	{																@edgeVerts2 = split(/[^0-9]/,@edges[1]);					}
	else			{																@edgeVerts2 = split(/[^0-9]/,@edges[int((@edges-1)/2)]);	}
	if ((@edgeVerts2[1] != @edgeVerts1[1]) && (@edgeVerts2[1] != @edgeVerts1[2])){	@verts = (@edgeVerts1[1],@edgeVerts1[2],@edgeVerts2[1]);	}
	else{																			@verts = (@edgeVerts1[1],@edgeVerts1[2],@edgeVerts2[2]);	}

	my @pos1 = lxq("query layerservice vert.pos ? @verts[0]");
	my @pos2 = lxq("query layerservice vert.pos ? @verts[1]");
	my @pos3 = lxq("query layerservice vert.pos ? @verts[2]");
	my @vector1 = unitVector((@pos1[0]-@pos2[0],@pos1[1]-@pos2[1],@pos1[2]-@pos2[2]));
	my @vector2 = unitVector((@pos1[0]-@pos3[0],@pos1[1]-@pos3[1],@pos1[2]-@pos3[2]));

	#create the normal and decide whether or not to flip it.
	my @normal = unitVector(crossProduct(\@vector1,\@vector2));
	my @nearestPolys = lxq("query layerservice edge.polyList ? @edges[0]");
	@polyPos = lxq("query layerservice poly.pos ? @nearestPolys[0]");
	my @centerToPoly = arrMath(@polyPos,@objectBottom,subt);
	#safety check : (if (disp start==disp end), don't use the vector because it's illegal.  so, just use the neg polynormal
	if (  (abs(@centerToPoly[0]) <  0.0001) && (abs(@centerToPoly[1]) <  0.0001) && (abs(@centerToPoly[2]) <  0.0001)  ){
		#lxout("[[1]-------------------------the center of the edges and the nearest poly are in the same space.--------------------------]");
		@centerToPoly = lxq("query layerservice poly.normal ? @nearestPolys[0]");
		@centerToPoly = arrMath(@centerToPoly,-1,-1,-1,mult);
		$safetyCheckFail=1;
	}
	@centerToPoly = unitVector(@centerToPoly);
	my $dp = dotProduct(\@centerToPoly,\@normal);


	#There were two polys and the first one was coplanar so I'm trying again.
	if ((@nearestPolys > 1) && ($dp > -0.02) && ($dp < 0.02)){
		#lxout("[--------------------There were two polys and the first one was coplanar so I'm trying again.-----------------]");
		@polyPos = lxq("query layerservice poly.pos ? @nearestPolys[1]");
		@centerToPoly = arrMath(@polyPos,@objectBottom,subt);
		#safety check : (if (disp start==disp end), don't use the vector because it's illegal.  so, just use the neg polynormal
		if (  (abs(@centerToPoly[0]) <  0.0001) && (abs(@centerToPoly[1]) <  0.0001) && (abs(@centerToPoly[2]) <  0.0001)  ){
			#lxout("[[2]-------------------------the center of the edges and the nearest poly are in the same space.--------------------------]");
			@centerToPoly = lxq("query layerservice poly.normal ? @nearestPolys[1]");

			@centerToPoly = arrMath(@centerToPoly,-1,-1,-1,mult);
			$safetyCheckFail=1;
		}

		@centerToPoly = unitVector(@centerToPoly);
		$dp = dotProduct(\@centerToPoly,\@normal);
	}

	#------------------------------------------------------------------------
	#FAILED VECTORS-------------
	if ($safetyCheckFail == 1){
		#BORDER EDGES :
		if (@nearestPolys == 1){
			#ABOVE
			if ($dp > 0){
				lxout("[<>] SAFETY FAIL + BORDER + ABOVE [<>]");
				#poly center is neg.  and this means normal is thus neg, so flip it.
				@normal = arrMath(@normal,-1,-1,-1,mult);
			}
			#BELOW
			else{
				lxout("[<>] SAFETY FAIL + BORDER + BELOW [<>]");
				#poly center is neg.  and this means normal is thus neg.  keep it.
			}
		}
		#NON-BORDER EDGES
		else{
			#ABOVE
			if ($dp > 0){
				lxout("[<>] SAFETY FAIL + NOT BORDER + ABOVE [<>]");
				#poly center is neg.  and this means normal is thus neg.  keep it.
			}
			#BELOW
			else{
				lxout("[<>] SAFETY FAIL + NOT BORDER + BELOW [<>]");
				@normal = arrMath(@normal,-1,-1,-1,mult);
				#poly center is neg.  and this means normal is thus pos. and we want it neg, so flip it.
			}
		}
	}
	#REGULAR VECTORS -----------
	else{
		#BORDER EDGES :
		if (@nearestPolys == 1){
			#COPLANAR
			if (($dp > -0.02) && ($dp < 0.02)){
				lxout("[<>] BORDER + COPLANAR [<>]");
				@normal = lxq("query layerservice poly.normal ? @nearestPolys[1]");
			}
			#NOT COPLANAR
			else{
				#ABOVE
				if ($dp > 0){
					lxout("[<>] BORDER + NOT COPLANAR + ABOVE [<>]");
				}
				#BELOW
				else{
					lxout("[<>] BORDER + NOT COPLANAR + BELOW [<>]");
					@normal = arrMath(@normal,-1,-1,-1,mult);
				}
			}
		}
		#NON-BORDER EDGES
		else{
			#COPLANAR
			if (($dp > -0.02) && ($dp < 0.02)){
				lxout("[<>] NOT BORDER + COPLANAR [<>]");
				@normal = lxq("query layerservice poly.normal ? @nearestPolys[1]");
				@normal = arrMath(@normal,-1,-1,-1,mult);
			}
			#NOT COPLANAR
			else{
				#ABOVE
				if ($dp > 0){
					lxout("[<>] NOT BORDER + NOT COPLANAR + ABOVE [<>]");
				}
				#BELOW
				else{
					lxout("[<>] NOT BORDER + NOT COPLANAR + BELOW [<>]");
					@normal = arrMath(@normal,-1,-1,-1,mult);
				}
			}
		}
	}
	#------------------------------------------------------------------------

	#now flip the axis if the flipArg said to.
	if ($flipNormal == 1){
		lxout("flipping normal because user argument said I should");
		@normal = arrMath(@normal,-1,-1,-1,mult);
	}

	#build the 3 vector axis from the 1st vector and the found normal.
	my @vector3 = crossProduct(\@vector1,\@normal);
	my $vector1DP = dotProduct(@vector1,@normal);
	if ($vector1DP != 0){
		lxout("The first vector and normal weren't at a perfect 90 degree angle and so I rebuilt vector1");
		@vector1 = crossProduct(\@vector3,\@normal);
	}

	#now convert the vectors into a world-aligned matrix
	@rotation = matrixToEuler(\@vector1,\@normal,\@vector3);
	@rotation = ((@rotation[0]*180)/$pi,(@rotation[1]*180)/$pi,(@rotation[2]*180)/$pi);
}

#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#DETERMINE WHETHER TO UNROTATE OR NOT subroutine
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub determineRotationMode{
	#check if mouse is over a new layer, if so make it active.
	my $fgLayerCount1 = lxq("query layerservice layer.n ? fg");
	lx("select.type item");
	lx("select.3DElementUnderMouse add");
	my $fgLayerCount2 = lxq("query layerservice layer.n ? fg");

	#turn on and remember the workplane, then off again.
	lx("workplane.fitGeometry");
	$Xcenter = lxq ("workPlane.edit cenX:? ");
	$Ycenter = lxq ("workPlane.edit cenY:? ");
	$Zcenter = lxq ("workPlane.edit cenZ:? ");
	$Xrotate = lxq ("workPlane.edit rotX:? ");
	$Yrotate = lxq ("workPlane.edit rotY:? ");
	$Zrotate = lxq ("workPlane.edit rotZ:? ");
	lx("workPlane.reset ");


	#now check the polys under the mouse to see if you're over old or new geometry.
	my $polyCount1 = lxq("select.count polygon ?");
	#popup("polyCount1 = $polyCount1");
	lx("select.type polygon");
	lx("select.3DElementUnderMouse remove");
	my $polyCount2 = lxq("select.count polygon ?");
	#popup("polyCount2 = $polyCount2");
	lx("select.3DElementUnderMouse add");
	my $polyCount3 = lxq("select.count polygon ?");
	#popup("polyCount3 = $polyCount3");

	#if I selected a new layer, deselect it now.
	if ($fgLayerCount2 > $fgLayerCount1){
		lx("select.type item");
		lx("select.3DElementUnderMouse remove");
	}

	#if mouse is over original mesh or nothing  AND  mouse is not over other geometry, then unrotate
	#special case if we're duplicating.
	if ($duplicate == 1){
		lxout("[->] Duplicate is on, so I'm forcing the mouse to think you're over new geometry");
		if ($polyCount3 > $polyCount1){lx("select.3DElementUnderMouse remove");}
		$rotateTo = 1;
	}
	else{
		if (($polyCount1 >= $polyCount2) && ($polyCount3 == $polyCount1)){
			lxout("[->] Determined the mouse IS NOT over new geometry");
			$rotateTo = 0;
		}else{
			lxout("[->] Determined the mouse IS over new geometry");
			lx("select.3DElementUnderMouse remove");
			$rotateTo = 1;
		}
	}
}

#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#CLEANUP SUB
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub cleanup{
	#Set the layer reference back
	lx("!!layer.setReference [$layerReference]");

	#put the tool back
	lx("!!tool.set tool.previous on");

	#put the WORKPLANE and UNIT MODE back to what you were in before.
	if ($workplane == 1){
		lxout("workplane is on....");
		if (($symmAxis != 3) && (@wpBackup[$symmAxis] > 0))	{	lx("workPlane.edit {@wpBackup[0]} {@wpBackup[1]} {@wpBackup[2]} {@wpBackup[3]} {@wpBackup[4]} {@wpBackup[5]}");		lxout("[->] Restoring backup workplane");	}
		else												{	lx("workPlane.edit {$Xcenter} {$Ycenter} {$Zcenter} {$Xrotate} {$Yrotate} {$Zrotate}");								lxout("[->] Restoring regular workplane");	}
		lx("tool.set actr.origin on");
	}else{
		lx("workPlane.edit {@WPmem[0]} {@WPmem[1]} {@WPmem[2]} {@WPmem[3]} {@WPmem[4]} {@WPmem[5]}");
		#Set the action center settings back
		if ($actr == 1) {	lx( "tool.set {$seltype} on" ); }
		else { lx("tool.set center.$selCenter on"); lx("tool.set axis.$selAxis on"); }
	}

	#Set Symmetry back
	if ($symmAxis != 3)
	{
		#CONVERT MY OLDSCHOOL SYMM AXIS TO MODO's NEWSCHOOL NAME
		if 		($symmAxis == "3")	{	$symmAxis = "none";	}
		elsif	($symmAxis == "0")	{	$symmAxis = "x";		}
		elsif	($symmAxis == "1")	{	$symmAxis = "y";		}
		elsif	($symmAxis == "2")	{	$symmAxis = "z";		}
		lxout("turning symm back on ($symmAxis)"); lx("!!select.symmetryState $symmAxis");
	}

	#to hide the hidden parents (and mainlayer) again.
	verifyMainlayerVisibility(\@verifyMainlayerVisibilityList);
}

#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#REMOVE THE HISTORY'S ROTATION
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub removeRotation{
	lxout("[->] Running rotation removal");
	my $Xrotate = @hist[9]*-1;
	my $Yrotate = @hist[10]*-1;
	my $Zrotate = @hist[11]*-1;

	lx("tool.set xfrm.rotate on");
	lx("tool.reset");
	lx("tool.setAttr center.auto cenX {@hist[6]}");
	lx("tool.setAttr center.auto cenY {@hist[7]}");
	lx("tool.setAttr center.auto cenZ {@hist[8]}");
	#rotate selectionZ
	lx("tool.setAttr axis.auto axisZ {1}");
	lx("tool.setAttr axis.auto axis {2}");
	lx("tool.setAttr xfrm.rotate angle {$Zrotate}");
	lx("tool.doApply");
	#rotate selectionX
	lx("tool.setAttr axis.auto axisX {1}");
	lx("tool.setAttr axis.auto axis {0}");
	lx("tool.setAttr xfrm.rotate angle {$Xrotate}");
	lx("tool.doApply");
	#rotate selectionY
	lx("tool.setAttr axis.auto axisY {1}");
	lx("tool.setAttr axis.auto axis {1}");
	lx("tool.setAttr xfrm.rotate angle {$Yrotate}");
	lx("tool.doapply");
	lx("tool.set xfrm.rotate off");
}


#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================
#===																SUBROUTINES																		====
#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================
#=====================================================================================================================================

#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#BOUNDING BOX
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub boundingbox #minX-Y-Z-then-maxX-Y-Z
{
	lxout("[->] Boundingbox subroutine");
	my @bbVerts = @_;
	my $firstVert = @bbVerts[0];
	my @firstVertPos = lxq("query layerservice vert.pos ? $firstVert");
	my $minX = @firstVertPos[0];
	my $minY = @firstVertPos[1];
	my $minZ = @firstVertPos[2];
	my $maxX = @firstVertPos[0];
	my $maxY = @firstVertPos[1];
	my $maxZ = @firstVertPos[2];
	my @bbVertPos;

	foreach my $bbVert(@bbVerts)
	{
		@bbVertPos = lxq("query layerservice vert.pos ? $bbVert");
		#minX
		if (@bbVertPos[0] < $minX)	{	$minX = @bbVertPos[0];	}

		#minY
		if (@bbVertPos[1] < $minY)	{	$minY = @bbVertPos[1];	}

		#minZ
		if (@bbVertPos[2] < $minZ)	{	$minZ = @bbVertPos[2];	}

		#maxX
		if (@bbVertPos[0] > $maxX)	{	$maxX = @bbVertPos[0];	}

		#maxY
		if (@bbVertPos[1] > $maxY)	{	$maxY = @bbVertPos[1];	}

		#maxZ
		if (@bbVertPos[2] > $maxZ)	{	$maxZ = @bbVertPos[2];	}
	}
	my @bbox = ($minX,$minY,$minZ,$maxX,$maxY,$maxZ);
	return @bbox;
}

#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#SORT THE ELEMENTS INTO SYMMETRICAL HALVES (requires $symmAxis)
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub sortSymm{
	my $selType = shift(@_);
	my @positive;
	my @negative;

	foreach my $elem (@_){
		my @pos = lxq("query layerservice $selType.pos ? $elem");
		if (@pos[$symmAxis] > 0 )	{  push(@positive,$elem);		}
		else						{  push(@negative,$elem);	}

	}
	return(\@positive,\@negative);
}


#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#CONVERT MATRIX TO EULER (9char matrix)
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#USAGE : my @rotations = matrixToEuler(\@vector1,\@vector2,\@vector3);
sub matrixToEuler{
	my @x = @{$_[0]};
	my @y = @{$_[1]};
	my @z = @{$_[2]};

	##TEMP : BUILD THE VERTS for the vector matrix
	#my @vert1 = arrMath(@x,30,30,30,mult);
	#my @vert2 = arrMath(@y,30,30,30,mult);
	#my @vert3 = arrMath(@z,30,30,30,mult);
	#@vert1 = arrMath(@objectBottom,@vert1,add);
	#@vert2 = arrMath(@objectBottom,@vert2,add);
	#@vert3 = arrMath(@objectBottom,@vert3,add);
	#lx("vert.new @objectBottom");
	#createSphere(@vert1);
	#createCube(@vert2);
	#lx("vert.new @vert3");

	my ($heading,$altitude,$bank);
	my $pi = 3.14159265358979323;

	if (@y[0] > 0.998){						#except when M10=1 (north pole)
		$heading = atan2(@x[2],@z[2]);		#heading = atan2(M02,M22)
		$altitude = asin(@y[0]);		 	#
		$bank = 0;							#bank = 0
	}elsif (@y[0] < -0.998){				#except when M10=-1 (south pole)
		$heading = atan2(@x[2],@z[2]);		#heading = atan2(M02,M22)
		$altitude = asin(@y[0]);			#
		$bank = 0;							#bank = 0
	}else{
		$heading = atan2(-@z[0],@x[0]);		#heading = atan2(-m20,m00)
		$altitude = asin(@y[0]);		  	#attitude = asin(m10)
		$bank = atan2(-@y[2],@y[1]);		#bank = atan2(-m12,m11)
	}

	return ($heading,$altitude,$bank);
}


#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#CORRECT THE 3D VECTOR DIRECTION SUBROUTINE
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#USAGE : @vector = correct3DVectorDir(@vector[0],@vector[1],@vector[2]);
sub correct3DVectorDir{
	my @vector = @_;

	#find important axis
	if ((abs(@vector[0]) > abs(@vector[1])) && (abs(@vector[0]) > abs(@vector[2])))		{	our $importantAxis = 0;	}
	elsif ((abs(@vector[1]) > abs(@vector[0])) && (abs(@vector[1]) > abs(@vector[2])))	{	our $importantAxis = 1;	}
	else																				{	our $importantAxis = 2;	}

	#special check for vectors at 45 degree angles (if X=Y or X=Z, and X is neg, then flip)
	if ((int(abs(@vector[0]*1000000)+.5) == int(abs(@vector[1]*1000000)+.5)) || (int(abs(@vector[0]*1000000)+.5) == int(abs(@vector[2]*1000000)+.5))){
		if (@vector[0] < 0){
			@vector[0] *= -1;
			@vector[1] *= -1;
			@vector[2] *= -1;
		}
	}

	#else if the important axis is negative, flip it.
	elsif (@vector[$importantAxis]<0){
		@vector[0] *= -1;
		@vector[1] *= -1;
		@vector[2] *= -1;
	}

	return @vector;
}



#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#GET AN AVERAGE VERT POSITION from a poly.
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub truePolyPos{
	my @verts = lxq("query layerservice poly.vertList ? @_[0]");
	my @avgPos;

	foreach my $vert (@verts){
		my @pos = lxq("query layerservice vert.pos ? $vert");
		@avgPos = (@avgPos[0]+@pos[0] , @avgPos[1]+@pos[1] , @avgPos[2]+@pos[2]);
	}

	@avgPos = (@avgPos[0]/@verts , @avgPos[1]/@verts , @avgPos[2]/@verts);
	return @avgPos;
}

#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#GET AN AVERAGE VERT POSITION (if only 3 verts, build quad and average)
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub getCorrectAvgVertPos{
	my @verts;
	my @avgPos;

	if (@_ == 3){
		#lxout("[->]getCorrectAvgVertPos : averaging skewed plane verts");
		#lxout("============================================================");
		my @pos1 = lxq("query layerservice vert.pos ? @_[0]");
		my @pos2 = lxq("query layerservice vert.pos ? @_[1]");
		my @pos3 = lxq("query layerservice vert.pos ? @_[2]");
		my @avgPosVec1 = arrMath(arrMath(@pos2,@pos1,add),2,2,2,div);
		my @avgPosVec2 = arrMath(arrMath(@pos3,@pos1,subt),.5,.5,.5,mult);
		my @avgPos = arrMath(@avgPosVec1,@avgPosVec2,add);
		#lxout("vert1=@_[0] <> vert3=@_[2]\npos1=@pos1 <> pos3=@pos3\navgPos=@avgPos");
		return @avgPos;
	}
	else{
		#lxout("[->]getCorrectAvgVertPos : just averaging verts");
		#lxout("============================================================");
		foreach my $vert(@_){
			my @pos = lxq("query layerservice vert.pos ? $vert");
			@avgPos = (@avgPos[0]+@pos[0],@avgPos[1]+@pos[1],@avgPos[2]+@pos[2]);
		}
		@avgPos = (@avgPos[0]/@_,@avgPos[1]/@_,@avgPos[2]/@_);
		return @avgPos;
	}
}


#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#GET AN AVERAGE EDGE POSITION (if only 3 verts, build quad and average)
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub getCorrectAvgEdgePos{
	my %vertTable;
	my @verts;
	my $keyVert;

	#if there are 2 edges, then build the list of verts
	if (@_ == 2){
		foreach my $edge(@_){
			my @verts = split(/[^0-9]/,$edge);
			if ($vertTable{@verts[1]} == "")	{	$vertTable{@verts[1]} = 1;								}
			else								{	$keyVert = @verts[1];	delete $vertTable{@verts[1]};	}
			if ($vertTable{@verts[2]} == "")	{	$vertTable{@verts[2]} = 1;								}
			else								{	$keyVert = @verts[2];	delete $vertTable{@verts[2]};	}
		}
		@verts = (keys %vertTable);
		unshift(@verts,$keyVert);
	}

	#if there are 3 verts, then get the planar average
	if (@verts == 3){
		my @pos1 = lxq("query layerservice vert.pos ? @verts[0]");
		my @pos2 = lxq("query layerservice vert.pos ? @verts[1]");
		my @pos3 = lxq("query layerservice vert.pos ? @verts[2]");
		my @pos4 = arrMath(@pos2,@pos1,subt);
		      @pos4 = arrMath(@pos4,@pos3,add);
		my @avgPos = (	(@pos1[0]+@pos2[0]+@pos3[0]+@pos4[0])*.25,
						(@pos1[1]+@pos2[1]+@pos3[1]+@pos4[1])*.25,
						(@pos1[2]+@pos2[2]+@pos3[2]+@pos4[2])*.25	);
		return @avgPos;
	}

	#if there are more than 3 verts, then just get the real average
	else{
		my @avgEdgePos;
		foreach my $edge(@_){
			my @pos = lxq("query layerservice edge.pos ? $edge");
			@avgEdgePos = (@avgEdgePos[0]+@pos[0],@avgEdgePos[1]+@pos[1],@avgEdgePos[2]+@pos[2]);
		}
		@avgEdgePos = (@avgEdgePos[0]/@_,@avgEdgePos[1]/@_,@avgEdgePos[2]/@_);
		return @avgEdgePos;
	}
}


#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#GET AN AVERAGE POSITION FROM A NUMBER OF EDGES
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#USAGE : 	my @bbox = edgeBBOX(@edges);
#			my @bboxCenter = edgeBBOX(center,@edges);
sub edgeBBOX{
	my $onlyExportCenter;
	my %vertTable;

	if (@_[0] eq "center"){
		lxout("[->] EDGE BBOX : only exporting bbox center");
		$onlyExportCenter = 1;
		shift(@_);
	}

	foreach my $edge(@_){
		my @verts = split(/[^0-9]/,$edge);
		$vertTable{@verts[1]} = 1;
		$vertTable{@verts[2]} = 1;
	}

	my @verts = (keys %vertTable);
	my @firstVertPos = lxq("query layerservice vert.pos ? @verts[0]");
	my $minX = @firstVertPos[0];
	my $minY = @firstVertPos[1];
	my $minZ = @firstVertPos[2];
	my $maxX = @firstVertPos[0];
	my $maxY = @firstVertPos[1];
	my $maxZ = @firstVertPos[2];

	foreach my $bbVert (keys %vertTable){
		@bbVertPos = lxq("query layerservice vert.pos ? $bbVert");
		#minX
		if (@bbVertPos[0] < $minX)		{	$minX = @bbVertPos[0];	}
		#maxX
		elsif (@bbVertPos[0] > $maxX)	{	$maxX = @bbVertPos[0];	}
		#minY
		if (@bbVertPos[1] < $minY)		{	$minY = @bbVertPos[1];	}
		#maxY
		elsif (@bbVertPos[1] > $maxY)	{	$maxY = @bbVertPos[1];	}
		#minZ
		if (@bbVertPos[2] < $minZ)		{	$minZ = @bbVertPos[2];	}
		#maxZ
		elsif (@bbVertPos[2] > $maxZ)	{	$maxZ = @bbVertPos[2];	}
	}
	my @bbox = ($minX,$minY,$minZ,$maxX,$maxY,$maxZ);


	if ($onlyExportCenter == 1){
		my @bboxCenter = (   (@bbox[0]+@bbox[3])*0.5 , (@bbox[1]+@bbox[4])*0.5 , (@bbox[2]+@bbox[5])*0.5   );
		return @bboxCenter;
	}else{
		return @bbox;
	}
}


#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#GET AN AVERAGE POSITION FROM A NUMBER OF EDGES
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub avgEdgePos{
	my @avgEdgePos;
	foreach my $edge(@_){
		my @pos = lxq("query layerservice edge.pos ? $edge");
		@avgEdgePos = (@avgEdgePos[0]+@pos[0],@avgEdgePos[1]+@pos[1],@avgEdgePos[2]+@pos[2]);
	}
	@avgEdgePos = (@avgEdgePos[0]/@_,@avgEdgePos[1]/@_,@avgEdgePos[2]/@_);
	return @avgEdgePos;
}

#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#AVERAGE OUT A NUMBER OF ARRAYS subroutine
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub average{
	my $count = $#_+1;
	my @avgArray=();
	foreach my $array(@_){
		@avgArray=(@avgArray[0]+@$array[0],@avgArray[1]+@$array[1],@avgArray[2]+@$array[2]);
	}
	@avgArray = (@avgArray[0]/$count,@avgArray[1]/$count,@avgArray[2]/$count);
	return @avgArray;
}

#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#PERFORM MATH FROM ONE ARRAY TO ANOTHER subroutine
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub arrMath{
	my @array1 = (@_[0],@_[1],@_[2]);
	my @array2 = (@_[3],@_[4],@_[5]);
	my $math = @_[6];

	my @newArray;
	if ($math eq "add")		{	@newArray = (@array1[0]+@array2[0],@array1[1]+@array2[1],@array1[2]+@array2[2]);	}
	elsif ($math eq "subt")	{	@newArray = (@array1[0]-@array2[0],@array1[1]-@array2[1],@array1[2]-@array2[2]);	}
	elsif ($math eq "mult")	{	@newArray = (@array1[0]*@array2[0],@array1[1]*@array2[1],@array1[2]*@array2[2]);	}
	elsif ($math eq "div")	{	@newArray = (@array1[0]/@array2[0],@array1[1]/@array2[1],@array1[2]/@array2[2]);	}
	return @newArray;
}

#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#CROSSPRODUCT SUBROUTINE (in=4pos out=1vec)
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#USAGE : my @crossProduct = crossProduct(\@vector1,\@vector2);

sub crossProduct{
	my @vector1 = @{$_[0]};
	my @vector2 = @{$_[1]};

	#create the crossproduct
	my @cp;
	@cp[0] = (@vector1[1]*@vector2[2])-(@vector2[1]*@vector1[2]);
	@cp[1] = (@vector1[2]*@vector2[0])-(@vector2[2]*@vector1[0]);
	@cp[2] = (@vector1[0]*@vector2[1])-(@vector2[0]*@vector1[1]);
	return @cp;
}

#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#DOT PRODUCT subroutine
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#USAGE : my $dp = dotProduct(\@vector1,\@vector2);
sub dotProduct{
	my @array1 = @{$_[0]};
	my @array2 = @{$_[1]};
	my $dp = (	(@array1[0]*@array2[0])+(@array1[1]*@array2[1])+(@array1[2]*@array2[2])	);
	return $dp;
}

#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#ASIN subroutine (does this work?)
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub asin {
	atan2($_[0], sqrt(1 - $_[0] * $_[0]));
	#tan(-$_[0] / sqrt(-$_[0] * $_[0] + 1)) + 2 * tan(1);  #can't find TAN anywhere, damnit.
}

#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#ACOS subroutine (radians)
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#USAGE :
sub acos {
	atan2(sqrt(1 - $_[0] * $_[0]), $_[0]);
}

#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#UNIT VECTOR SUBROUTINE
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#USAGE : my @unitVector = unitVector(@vector);
sub unitVector{
	#lxout("       unit vector sub=@_");
	my $dist1 = sqrt((@_[0]*@_[0])+(@_[1]*@_[1])+(@_[2]*@_[2]));
	@_ = ((@_[0]/$dist1),(@_[1]/$dist1),(@_[2]/$dist1));
	return @_;
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


#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#CREATE A PIPE AT THE SPECIFIED PLACE/VECTOR/LENGTH/THICKNESS
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#USAGE : createPipe(@origin,@vector,$length,$thickness);
sub createPipe{
	if (@_[6] == ""){@_[6] = 1;}
	if (@_[7] == ""){@_[7] = 1;}

	my $dist1 = sqrt((@_[3]*@_[3])+(@_[4]*@_[4])+(@_[5]*@_[5]));
	my @unitVector = ((@_[3]/$dist1),(@_[4]/$dist1),(@_[5]/$dist1));
	my @vector = ( $unitVector[0]*@_[6] , $unitVector[1]*@_[6] , $unitVector[2]*@_[6] );
	@vector = ( @_[0]+$vector[0] , @_[1]+$vector[1] , @_[2]+$vector[2] );

	lx("tool.set prim.tube on");
	lx("tool.reset");
	lx("tool.setAttr prim.tube mode add");
	lx("tool.attr prim.tube radius {@_[7]}");
	lx("tool.attr prim.tube sides 4");
	lx("tool.attr prim.tube segments 1");

	lx("tool.setAttr prim.tube number {1}");
	lx("tool.setAttr prim.tube ptX {@_[0]}");
	lx("tool.setAttr prim.tube ptY {@_[1]}");
	lx("tool.setAttr prim.tube ptZ {@_[2]}");

	lx("tool.setAttr prim.tube number {2}");
	lx("tool.setAttr prim.tube ptX {@vector[0]}");
	lx("tool.setAttr prim.tube ptY {@vector[1]}");
	lx("tool.setAttr prim.tube ptZ {@vector[2]}");

	lx("tool.doApply");
	lx("tool.set prim.tube off");
}

#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#CREATE A SPHERE AT THE SPECIFIED PLACE/SCALE
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub createSphere{
	if (@_[3] == ""){@_[3] = 5;}
	lx("tool.set prim.sphere on");
	lx("tool.reset");
	lx("tool.setAttr prim.sphere cenX {@_[0]}");
	lx("tool.setAttr prim.sphere cenY {@_[1]}");
	lx("tool.setAttr prim.sphere cenZ {@_[2]}");
	lx("tool.setAttr prim.sphere sizeX {@_[3]}");
	lx("tool.setAttr prim.sphere sizeY {@_[3]}");
	lx("tool.setAttr prim.sphere sizeZ {@_[3]}");
	lx("tool.doApply");
	lx("tool.set prim.sphere off");
}

#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#CREATE A CUBE AT THE SPECIFIED PLACE/SCALE
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
sub createCube{
	if (@_[3] == ""){@_[3] = 5;}
	lx("tool.set prim.cube on");
	lx("tool.reset");
	lx("tool.setAttr prim.cube cenX {@_[0]}");
	lx("tool.setAttr prim.cube cenY {@_[1]}");
	lx("tool.setAttr prim.cube cenZ {@_[2]}");
	lx("tool.setAttr prim.cube sizeX {@_[3]}");
	lx("tool.setAttr prim.cube sizeY {@_[3]}");
	lx("tool.setAttr prim.cube sizeZ {@_[3]}");
	lx("tool.doApply");
	lx("tool.set prim.cube off");
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
			lx("layer.setVisibility {$id} 0");
		}
	}

	#show the mainlayer and all the mainlayer parents that are hidden (and retain a list for later use)
	else{
		if( lxq( "select.typeFrom {vertex;edge;polygon;item} ?" ) ){	our $tempSelMode = "vertex";	}
		if( lxq( "select.typeFrom {edge;polygon;item;vertex} ?" ) ){	our $tempSelMode = "edge";		}
		if( lxq( "select.typeFrom {polygon;item;vertex;edge} ?" ) ){	our $tempSelMode = "polygon";	}
		if( lxq( "select.typeFrom {item;vertex;edge;polygon} ?" ) ){	our $tempSelMode = "item";		}
		lx("select.type item");
		if (lxq("layer.setVisibility $mainlayerID ?") == 0){
			lxout("[->] : showing $mainlayerID");
			lx("layer.setVisibility $mainlayerID 1");
			push(@hiddenParents,$mainlayerID);
		}
		lx("select.type $tempSelMode");

		my $parentFind = 1;
		my $currentID = $mainlayerID;
		while ($parentFind == 1){
			my $parent = lxq("query sceneservice item.parent ? {$currentID}");
			if ($parent ne ""){
				$currentID = $parent;

				if (lxq("layer.setVisibility {$parent} ?") == 0){
					lxout("[->] : showing $parent");
					lx("layer.setVisibility {$parent} 1");
					push(@hiddenParents,$parent);
				}
			}else{
				$parentFind = 0;
			}
		}

		return(@hiddenParents);
	}
}
