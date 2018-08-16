#perl
#AUTHOR: Seneca Menard
#version 1.93
#This tool is for welding verts and EDGE ROWS!

#It welds (n) edge row(s) to the last selected edge row.  It works only for edges or edge rows, not edge loops.
#If you wanna weld edge loops, just deselect one edge from each row.
#(new feature 8-11-05) when you're welding verts, it will now remove all illegal polygons for you.  If you don't want it to do that, just append "keep2pts" to the script
#(bugfix 8-13-05) this tool now works in SYMMETRY MODE.  :)
#(bugfix 7-23-06) it now only merges the verts that were effected by the edge weld, and properly removes the illegal polygons again.
#(new feature 8-15-06) this script now works in the UV window, so you can select multiple UVs and weld 'em to the last selected UV.
#(bugfix 9-7-07) : the keep2pts option now works when you're welding edges as well.
#(new feature 9-16-07) : you ever wanna do a vert weld, but not have the uvs be welded?  Well, just run this script with "leaveUVs" appended and it'll do that.  Damn handy.
#(12-18-08 fix) : I went and removed the square brackets so that the numbers will always be read as metric units and also because my prior safety check would leave the unit system set to metric system if the script was canceled because changing that preference doesn't get undone if a script is cancelled.
#(3-25-11 fix) : 501 sp2 had an annoying syntax change.  grrr.

#SCRIPT ARGUMENTS :
# "$keep2Pts" : append that and the script won't delete the 2 pt polys anymore.
# "leaveUVs" : for vert welding that will weld the verts, but not weld their uvs.


my $mainLayer = lxq("query layerservice layers ? main");
my $modoBuild = lxq("query platformservice appbuild ?");
if ($modoBuild > 41320){our $selectPolygonArg = "psubdiv";}else{our $selectPolygonArg = "curve";}

#this is the uv command I'll need.  vertMap.setValue [1] [0] [0 m]


#------------------------------------------------------------------------------------------------------------
#SCRIPT ARGUMENTS
#------------------------------------------------------------------------------------------------------------
foreach my $arg (@ARGV){
	if ($arg =~ /keep2pts/i)	{our $keep2Pts = 1;}
	if ($arg =~ /leaveUVs/i)	{our $leaveUVs = 1;}
}

#------------------------------------------------------------------------------------------------------------
#SAFETY CHECKS
#------------------------------------------------------------------------------------------------------------
#Remember what the workplane was and turn it off
my @WPmem;
@WPmem[0] = lxq ("workPlane.edit cenX:? ");
@WPmem[1] = lxq ("workPlane.edit cenY:? ");
@WPmem[2] = lxq ("workPlane.edit cenZ:? ");
@WPmem[3] = lxq ("workPlane.edit rotX:? ");
@WPmem[4] = lxq ("workPlane.edit rotY:? ");
@WPmem[5] = lxq ("workPlane.edit rotZ:? ");
lx("workPlane.reset ");


#------------------------------------------------------------------------------------------------------------
#IF IN VERT OR POLY MODE, DO THE NORMAL WELD
#------------------------------------------------------------------------------------------------------------
if( lxq( "select.typeFrom {vertex;edge;polygon;item} ?" ) || lxq( "select.typeFrom {polygon;item;vertex;edge} ?" ))
{
	#------------------------------------------------------
	#UV WELD!
	#------------------------------------------------------
	if (lxq("tool.viewType ?") eq "uv"){
		lxout("[->] UV Weld");
		my @UVs = lxq("query layerservice uvs ? selected");
		if (@UVs > 0){
			my @UVPos = lxq("query layerservice uv.pos ? @UVs[-1]");

			&actrRemember;
			lx("tool.set xfrm.stretch on");
			lx("tool.reset ");
			lx("tool.setAttr center.auto cenU {@UVPos[0]}");
			lx("tool.setAttr center.auto cenV {@UVPos[1]}");
			lx("tool.setAttr xfrm.stretch factX {0}");
			lx("tool.setAttr xfrm.stretch factY {0}");
			lx("tool.setAttr xfrm.stretch factZ {1}");
			lx("tool.doApply");
			lx("tool.set xfrm.stretch off");
			&actrRestore;
		}
		else{ die("You don't have any uvs selected so I can't weld them.");}
	}

	#------------------------------------------------------
	#VERT WELD!
	#------------------------------------------------------
	else{
		if ($leaveUVs == 1){
			lxout("[->] Vert Weld that doesn't weld UVs.");

			my @verts = lxq("query layerservice verts ? selected");

			if (@verts > 1){
				#CHECK IF SYMMETRY IS ON or OFF, CONVERT THE SYMM AXIS TO MY OLDSCHOOL NUMBER, TURN IT OFF.
				our $symmAxis = lxq("select.symmetryState ?");
				if 		($symmAxis eq "none")	{	$symmAxis = 3;	}
				elsif	($symmAxis eq "x")		{	$symmAxis = 0;	}
				elsif	($symmAxis eq "y")		{	$symmAxis = 1;	}
				elsif	($symmAxis eq "z")		{	$symmAxis = 2;	}

				my @pos1 = lxq("query layerservice vert.pos ? @verts[-1]");
				my @pos2 = lxq("query layerservice vert.pos ? @verts[-2]");

				if ($symmAxis != 3){
					lxout("flipping axis because of asymmetrical selection");
					@pos1[$symmAxis] = abs(@pos1[$symmAxis]);
				}

				lx("vert.set x {@pos1[0]}");
				lx("vert.set y {@pos1[1]}");
				lx("vert.set z {@pos1[2]}");
				lx("!!vert.merge auto [0] [1 um]");
				lx("select.drop vertex");
			}
		}else{
			lxout("[->] Normal Vert Weld");
			lx("!!vert.join [0] [0]");
		}

		if ($keep2Pts == 0)
		{
			#MESH CLEANUP
			#SELECT and delete 0 poly points
			lx("!!select.drop vertex");
			lx("!!select.vertex add poly equal 0");
			if (lxq("select.count vertex ?")){
				lx("delete");
			}

			#SELECT 2pt and 1pt polygons and delete 'em
			lx("select.drop polygon");
			lx("!!select.polygon add vertex {$selectPolygonArg} 2");
			lx("!!select.polygon add vertex {$selectPolygonArg} 1");
			if (lxq("select.count polygon ?")){
				lx("delete");
			}

			#SELECT 3+ edge polygons and delete 'em
			lx("select.drop edge");
			lx("!!select.edge add poly more 2");
			lx("!!select.convert polygon");
			if (lxq("select.count polygon ?")){
				lx("delete");
			}

			#Put selection settings back
			lx("select.type vertex");
		}
	}
}

#------------------------------------------------------------------------------------------------------------
#IF IN EDGE MODE, DO THE CRAZY EDGE WELD
#------------------------------------------------------------------------------------------------------------
elsif( lxq( "select.typeFrom {edge;polygon;item;vertex} ?" ) )
{
	lxout("[->]SUPER WELD SCRIPT----------------------------------------------------------------------");
	our @origEdgeList_edit;
	our @vertRow;
	our @vertRowList;

	our @vertList;
	our %vertPosTable;

	our @vertMergeOrder;
	our @edgesToRemove;
	our $removeEdges;

	#Get and edit the original edge list *throw away all edges that aren't in mainlayer* (FIXED FOR MODO2)
	our @origEdgeList = lxq("query layerservice selection ? edge");
	my @tempEdgeList;
	foreach my $edge (@origEdgeList){	if ($edge =~ /\($mainLayer/){	push(@tempEdgeList,$edge);		}	}
	#[remove layer info] [remove ( ) ]
	@origEdgeList = @tempEdgeList;
	s/\(\d{0,},/\(/  for @origEdgeList;
	tr/()//d for @origEdgeList;



	#CHECK IF SYMMETRY IS ON or OFF
	our $symmAxis = lxq("select.symmetryState ?");

	#CONVERT THE SYMM AXIS TO MY OLDSCHOOL NUMBER
	if 		($symmAxis eq "none")	{	$symmAxis = 3;	}
	elsif	($symmAxis eq "x")		{	$symmAxis = 0;	}
	elsif	($symmAxis eq "y")		{	$symmAxis = 1;	}
	elsif	($symmAxis eq "z")		{	$symmAxis = 2;	}

	#SYMM OFF
	if ($symmAxis == 3)
	{
		lxout("[->] SYMMETRY IS OFF");
		&edgeWelding;
		&cleanup;
	}



	#SYMM ON
	else
	{
		#time to sort the selected edges into each symmetrical half
		lxout("[->] SYMMETRY IS ON");
		our $allVertsOnAxis = 1;
		lx("select.symmetryState none");
		our $symmetry = 1;
		my $count = 0;
		our @edgeListPos;
		our @edgeListNeg;

		foreach my $edge (@origEdgeList)
		{
			my @verts = split(/,/, $edge);
			#lxout("[$count]:verts = @verts");

			#TIME TO CHECK VERT0---------------------------------
			#vert0 POSITIVE check
			my @vert0Pos = lxq("query layerservice vert.pos ? @verts[0]");
			#lxout("--[@verts[0]]vert0Pos = @vert0Pos");
			if (@vert0Pos[$symmAxis] > 0.00000001)
			{
				#lxout("[$count]0 = POS");
				push(@edgeListPos, "$edge");
				$allVertsOnAxis = 0;
			}
			#vert0 NEGATIVE check
			elsif (@vert0Pos[$symmAxis] < -0.00000001)
			{
				#lxout("[$count]0 = NEG");
				push(@edgeListNeg, "$edge");
				$allVertsOnAxis = 0;
			}

			else #TIME TO CHECK VERT1---------------------------------
			{
				#vert1 POSITIVE check
				my @vert1Pos = lxq("query layerservice vert.pos ? @verts[1]");
				#lxout("--[@verts[1]]vert1Pos = @vert1Pos");
				if (@vert1Pos[$symmAxis] > 0.00000001)
				{
					#lxout("[$count]1 = POS");
					push(@edgeListPos, "$edge");
					$allVertsOnAxis = 0;
				}
				#vert1 NEGATIVE check
				elsif (@vert1Pos[$symmAxis] < -0.00000001)
				{
					#lxout("[$count]1 = NEG");
					push(@edgeListNeg, "$edge");
					$allVertsOnAxis = 0;
				}

				#I guess both verts are on ZERO then.
				else
				{
					#lxout("[$count]NEITHER");
					push(@edgeListPos, "$edge");
					push(@edgeListNeg, "$edge");
				}
			}
			$count++;
		}

		#lxout("ALL DONE: ");
		#lxout("EDGES ABOVE symm: [$#edgeListPos]@edgeListPos");
		#lxout("EDGES BELOW symm: [$#edgeListNeg]@edgeListNeg");

		#ask the user if they still wanna run the script if the model's symmetry appears to be off
		#if ($#edgeListPos != $#edgeListNeg)	{	popup("There aren't an even number of edges selected on both sides of the model.  Do you still want to run the script?");	}


		#all verts on 0 message
		if ($allVertsOnAxis == 1)	{lxout("[->] ALL the verts are ON the symm axis, so i'm not using symmetry");}

		#TIME TO DO THE EDGEWELDING!
		#round 1
		if ($#edgeListPos > 0)
		{
			@origEdgeList = @edgeListPos;
			&edgeWelding;
		}
		else
		{
			lxout("[->]NOT RUNNING the script on POS half of model");
		}

		#round 2
		if ((@edgeListNeg > 0) && ($allVertsOnAxis == 0))
		{
			@origEdgeList = @edgeListNeg;
			&edgeWelding;
		}
		else
		{
			lxout("[->]NOT RUNNING the script on NEG half of model");
		}

		#cleanup time
		&cleanup;
	}
}

#------------------------------------------------------------------------------------------------------------
#CLEANUP
#------------------------------------------------------------------------------------------------------------
#Put workplane back
lx("workPlane.edit {@WPmem[0]} {@WPmem[1]} {@WPmem[2]} {@WPmem[3]} {@WPmem[4]} {@WPmem[5]}");















#----------------------------------------------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------------------------------------------
#THE EDGE MOVING CODE
#----------------------------------------------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------------------------------------------
sub edgeWelding()
{
	lxout("[->]Using EDGEWELDING subroutine");
	@origEdgeList_edit = @origEdgeList;
	$removeEdges = 0;
	undef(@vertRowList);

	#-----------------------------------------------------------------------------------------------------------
	#Begin sorting the [edge list] into different [vert rows].
	#-----------------------------------------------------------------------------------------------------------
	while (($#origEdgeList_edit + 1) != 0)
	{
		#this is a loop to go thru and sort the edge loops
		@vertRow = split(/,/, @origEdgeList_edit[0]);
		shift(@origEdgeList_edit);
		&sortRow;

		#take the new edgesort array and add it to the big list of edges.
		push(@vertRowList, "@vertRow");
	}




	#-----------------------------------------------------------------------------------------------------------
	#Print out the DONE list   [this should normally go in the sorting sub]
	#-----------------------------------------------------------------------------------------------------------
	#lxout("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - ");
	#lxout("- - -This is the new vertRow: @vertRow");
	#lxout("- - -DONE: There are ($#vertRowList+1) edge rows total");
	for ($i = 0; $i < ($#vertRowList + 1) ; $i++) {	lxout("- - -vertRow # ($i) = @vertRowList[$i]"); }
	#lxout("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - ");
	#@poo = split (/[^0-9]/, @arrayOfArrays[0]);




	#-----------------------------------------------------------------------------------------------------------
	#Get [vert position] hash table
	#-----------------------------------------------------------------------------------------------------------
	#grab ALL verts from every array and put it in one global vert list.
	undef(@vertList);
	for ($i = 0; $i < ($#vertRowList + 1) ; $i++)
	{
		my @verts = split (/[^0-9]/, @vertRowList[$i]);
		push(@vertList,@verts);
	}

	#take that global vert list and put every one of it's vert positions into a table.
	foreach my $vert(@vertList)
	{
		my @pos = lxq("query layerservice vert.pos ? $vert");
		$vertPosTable{$vert} = \@pos;
	}

	#foreach my $vert(@vertList)
	#{
		#lxout("vert $vert array : X = $vertPosTable{$vert}->[0] Y = $vertPosTable{$vert}->[1] Z = $vertPosTable{$vert}->[2]");
	#}



	#-----------------------------------------------------------------------------------------------------------
	#Find the direction the first and last verts of each row are going to determine which verts to merge to which
	#-----------------------------------------------------------------------------------------------------------

	#lxout("-----------------------------------------------------------------------------------------------------------");
	#lxout("Find the direction the first and last verts of each row are going to determine which verts to merge to which");
	#lxout("-----------------------------------------------------------------------------------------------------------");

	my @lastRowVerts = split (/[^0-9]/, @vertRowList[$#vertRowList]);
	my @lastRowDP = unitVector(@lastRowVerts[0],@lastRowVerts[-1]);


	#go through every vertRow except the last and check which of it's vectors is closest to the last vertRow's a
	for ($i = 0; $i < $#vertRowList ; $i++)
	{

		my @verts = split (/[^0-9]/, @vertRowList[$i]);

		#lxout("Checking the endPoint Vector Diffs -----------                   --------------------------");
		#lxout("this is the vertRow I'm looking at: $i");

		my @thisRowDP1 = unitVector(@verts[0],@verts[-1]);
		my @thisRowDP2= unitVector(@verts[-1],@verts[0]);

		#lxout("dp 1 = @lastRowDP");
		#lxout("dp 2 = @thisRowDP1");
		#lxout("dp 3 = @thisRowDP2");

		my @dispDiff1 = ((@lastRowDP[0]-@thisRowDP1[0]),(@lastRowDP[1]-@thisRowDP1[1]),(@lastRowDP[2]-@thisRowDP1[2]));
		my @dispDiff2 = ((@lastRowDP[0]-@thisRowDP2[0]),(@lastRowDP[1]-@thisRowDP2[1]),(@lastRowDP[2]-@thisRowDP2[2]));
		my $dispDiff1_abs = (abs(@dispDiff1[0])+abs(@dispDiff1[1])+abs(@dispDiff1[2]));
		my $dispDiff2_abs = (abs(@dispDiff2[0])+abs(@dispDiff2[1])+abs(@dispDiff2[2]));

		#lxout("dispdiff1_abs = $dispDiff1_abs");
		#lxout("dispdiff2_abs = $dispDiff2_abs");

		if ($dispDiff1_abs < $dispDiff2_abs)
		{
			#lxout("[-]-[-] merge @verts[0] to @lastRowVerts[0]");
			@vertMergeOrder[$i] = 0;

		}
		else
		{
			#lxout("[-]-[-]REVERSE");
			#lxout("[-]-[-] merge @verts[-1] to @lastRowVerts[0]");
			@vertMergeOrder[$i] = 1;
		}
	}




	#-----------------------------------------------------------------------------------------------------------
	#Vert Move Time
	#-----------------------------------------------------------------------------------------------------------


	for(my $currEdge = 0; $currEdge < $#vertRowList ; $currEdge++)
	{
		#lxout("-----------------------------------------------------------------------------------------------------------");
		#lxout("Vert Merge Time");
		#lxout("-----------------------------------------------------------------------------------------------------------");

		my @verts = split (/[^0-9]/, @vertRowList[$currEdge]);

		#set the proper vertRow direction.
		if (@vertMergeOrder[$currEdge] == 1)
		{
			#lxout("Reversing this vertRowList $currEdge");
			#lxout("verts = @verts");
			@verts = reverse @verts;
			#lxout("verts = @verts");
		}

		#--------------------------------------------------------------------
		#This is what's to run if the vertRow numbers of verts are the same.
		#--------------------------------------------------------------------
		if ($#verts == $#lastRowVerts)
		{
			#lxout("< - > this vertRow has the *SAME* num of verts as [merge-to-Row]");
			for (my $i = 0; $i < ($#verts + 1) ; $i++)
			{
				my @moveToPos = ($vertPosTable{@lastRowVerts[$i]}->[0],$vertPosTable{@lastRowVerts[$i]}->[1],$vertPosTable{@lastRowVerts[$i]}->[2]);
				lx("!!select.drop vertex");
				lx("!!select.element [$mainLayer] vertex add index:@verts[$i]");
				lx("!!vert.set x {@moveToPos[0]}");
				lx("!!vert.set y {@moveToPos[1]}");
				lx("!!vert.set z {@moveToPos[2]}");
				#lxout("blah <:> @moveToPos vert(@verts[$i])  vert(@lastRowVerts[$i])");
			}
		}
		#--------------------------------------------------------------------
		#This is what's to run if the vertRow numbers of verts are greater.
		#--------------------------------------------------------------------
		elsif ($#verts > $#lastRowVerts)
		{
			#lxout("< - > this vertRow has *MORE* verts than the [merge-to-Row]");
			for (my $i = 0; $i < ($#verts + 1) ; $i++)
			{
				my $roundedMoveTo = int((($#lastRowVerts/$#verts)* $i) + 0.5);
				my @moveToPos = ($vertPosTable{@lastRowVerts[$roundedMoveTo]}->[0],$vertPosTable{@lastRowVerts[$roundedMoveTo]}->[1],$vertPosTable{@lastRowVerts[$roundedMoveTo]}->[2]);

				lx("!!select.drop vertex");
				lx("!!select.element [$mainLayer] vertex add index:@verts[$i]");
				lx("!!vert.set x {@moveToPos[0]}");
				lx("!!vert.set y {@moveToPos[1]}");
				lx("!!vert.set z {@moveToPos[2]}");
				#lxout("blah <:> @moveToPos vert(@verts[$i])  vert($roundedMoveTo)");
			}
		}
		#--------------------------------------------------------------------
		#This is what's to run if the vertRow numbers of verts are less.
		#--------------------------------------------------------------------
		elsif ($#verts < $#lastRowVerts)
		{
			#lxout("< - > this vertRow has *LESS* verts than the [merge-to-Row]");

			#----------                                                          -------
			#make a list of every vert that isn't getting welded to---------------------
			#----------                                                          -------
			my @lastRowVertsEdit;
			for (my $i = 0; $i < ($#lastRowVerts + 1) ; $i++)
			{
				@lastRowVertsEdit[$i] = $i;
			}


			#----------                                                          -------
			#This will move row 1's verts to the most similar in row 2------------------
			#----------                                                          -------
			my $reverseCount = 0;
			for (my $i = 0; $i < ($#verts + 1) ; $i++)
			{
				my $roundedMoveTo = int((($#lastRowVerts/$#verts)* $i) + 0.5);
				my @moveToPos = ($vertPosTable{@lastRowVerts[$roundedMoveTo]}->[0],$vertPosTable{@lastRowVerts[$roundedMoveTo]}->[1],$vertPosTable{@lastRowVerts[$roundedMoveTo]}->[2]);
				#make a list of every vert that isn't getting welded to:
				splice(@lastRowVertsEdit, ($roundedMoveTo - $reverseCount),1);

				lx("!!select.drop vertex");
				lx("!!select.element [$mainLayer] vertex add index:@verts[$i]");
				lx("!!vert.set x {@moveToPos[0]}");
				lx("!!vert.set y {@moveToPos[1]}");
				lx("!!vert.set z {@moveToPos[2]}");
				#lxout("blah <:> vert(@verts[$i]) merge to vert(@lastRowVerts[$roundedMoveTo])");
				$reverseCount = $reverseCount + 1;
			}
			#lxout("verts that didn't get welded to: @lastRowVertsEdit");


			#lxout("lastRowVerts = @lastRowVerts");
			#lxout("lastRowVertsEdit = @lastRowVertsEdit");
			my @lastRowVertsEditCopy = @lastRowVertsEdit;
			#lxout("lastRowVertsEditCopy = $#lastRowVertsEditCopy+1");

			#sort the unwelded verts into chains that'll be made into polygons.
			while (($#lastRowVertsEditCopy+1) > 0)
			{
				my @lastRowVertChain = @lastRowVertsEditCopy[0];
				shift @lastRowVertsEditCopy;
				#lxout("blah");

				#sort the chains
				my @loopCount = @lastRowVertsEditCopy;
				foreach (@loopCount)
				{
					#lxout("lastRowVertChain[-1] = @lastRowVertChain[-1] <><> lastRowVertsEditCopy[0] = @lastRowVertsEditCopy[0]");
					if (@lastRowVertChain[-1] == @lastRowVertsEditCopy[0] - 1)
					{
						push(@lastRowVertChain,@lastRowVertsEditCopy[0]);
						shift @lastRowVertsEditCopy;
						#lxout("lastRowVertChain = @lastRowVertChain <><> lastRowVertsEditCopy = @lastRowVertsEditCopy");
					}
					else
					{
						#lxout("lastRowVertChain is hitting an end (@lastRowVertChain)");
						last;
					}
				}


				#select the chains and make the polygons
				lx("!!select.drop vertex");
				#lxout("first in chain = @lastRowVerts[@lastRowVertChain[0]-1]");
				lx("!!select.element [$mainLayer] vertex add index:{@lastRowVerts[@lastRowVertChain[0]-1]}");
				foreach my $vert (@lastRowVertChain)
				{
					lx("!!select.element [$mainLayer] vertex add index:@lastRowVerts[$vert]");
				}
				#lxout("last in chain = @lastRowVerts[@lastRowVertChain[-1]+1]");
				lx("!!select.element [$mainLayer] vertex add index:{@lastRowVerts[@lastRowVertChain[-1]+1]}");
				lx("!!poly.make face");

				#remember the edges so we can remove 'em later.
				$removeEdges = 1;
				lx("!!select.drop vertex");
				lx("!!select.element [$mainLayer] vertex add index:{@lastRowVerts[@lastRowVertChain[0]-1]}");
				lx("!!select.element [$mainLayer] vertex add index:{@lastRowVerts[@lastRowVertChain[-1]+1]}");
				lx("!!select.editSet superTempEdges add");
			}
		}
	}
}










#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
#--------------------------------------------SUBROUTINES---------------------------------------
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------



#-----------------------------------------------------------------------------------------------------------
#POPUP SUBROUTINE
#-----------------------------------------------------------------------------------------------------------
sub popup #(MODO2 FIX)
{
	lx("dialog.setup yesNo");
	lx("dialog.msg {@_}");
	lx("dialog.open");
	my $confirm = lxq("dialog.result ?");
	if($confirm eq "no"){die;}
}


#-----------------------------------------------------------------------------------------------------------
#UNIT VECTOR subroutine
#-----------------------------------------------------------------------------------------------------------
sub unitVector
{
	#lxout("--------------------endPointVector--------------------------");
	my ($vert1,$vert2) = @_;
	my @vertPos1 = ($vertPosTable{$vert1}[0],$vertPosTable{$vert1}[1],$vertPosTable{$vert1}[2]);
	my @vertPos2 = ($vertPosTable{$vert2}[0],$vertPosTable{$vert2}[1],$vertPosTable{$vert2}[2]);
	#lxout("[->] USING axisunitVector subroutine on these verts:($vert1,$vert2)");
	#lxout("alert vertPos1 @vertPos1[0] + @vertPos1[1] + @vertPos1[2]");
	#lxout("unitVector vert1Pos = @vertPos1");
	#lxout("unitVector vert2Pos = @vertPos2");


	#might wanna put in a special case check if the dist is zero
	my @disp;
	@disp[0,1,2] = (@vertPos2[0]-@vertPos1[0],@vertPos2[1]-@vertPos1[1],@vertPos2[2]-@vertPos1[2]);
	#lxout("WTF disp @disp");
	my $dist = sqrt((@disp[0]*@disp[0])+(@disp[1]*@disp[1])+(@disp[2]*@disp[2]));
	#lxout("WTF dist $dist");
	#normalize displacement vector
	@disp[0,1,2] = ((@disp[0]/$dist),(@disp[1]/$dist),(@disp[2]/$dist));
	#lxout("	alert disp @disp[0] + @disp[1] + @disp[2]");
	#lxout("------          -------------          ---------");
	return @disp;
}



#-----------------------------------------------------------------------------------------------------------
#sort Rows subroutine
#-----------------------------------------------------------------------------------------------------------
sub sortRow
{
	#this first part is stupid.  I need it to loop thru one more time than it will:
	my @loopCount = @origEdgeList_edit;
	unshift (@loopCount,1);
	#lxout("How many fucking times will I go thru the loop!? = $#loopCount");

	foreach(@loopCount)
	{
		#lxout("[->] USING sortRow subroutine----------------------------------------------");
		#lxout("original edge list = @origEdgeList");
		#lxout("edited edge list =  @origEdgeList_edit");
		#lxout("vertRow = @vertRow");
		my $i=0;
		foreach my $thisEdge(@origEdgeList_edit)
		{
			#break edge into an array  and remove () chars from array
			@thisEdgeVerts = split(/,/, $thisEdge);
			#lxout("-        origEdgeList_edit[$i] Verts: @thisEdgeVerts");

			if (@vertRow[0] == @thisEdgeVerts[0])
			{
				#lxout("edge $i is touching the vertRow");
				unshift(@vertRow,@thisEdgeVerts[1]);
				splice(@origEdgeList_edit, $i,1);
				last;
			}
			elsif (@vertRow[0] == @thisEdgeVerts[1])
			{
				#lxout("edge $i is touching the vertRow");
				unshift(@vertRow,@thisEdgeVerts[0]);
				splice(@origEdgeList_edit, $i,1);
				last;
			}
			elsif (@vertRow[-1] == @thisEdgeVerts[0])
			{
				#lxout("edge $i is touching the vertRow");
				push(@vertRow,@thisEdgeVerts[1]);
				splice(@origEdgeList_edit, $i,1);
				last;
			}
			elsif (@vertRow[-1] == @thisEdgeVerts[1])
			{
				#lxout("edge $i is touching the vertRow");
				push(@vertRow,@thisEdgeVerts[0]);
				splice(@origEdgeList_edit, $i,1);
				last;
			}
			else
			{
				$i++;
			}
		}
	}
}



#-----------------------------------------------------------------------------------------------------------
#Displacement subroutine
#-----------------------------------------------------------------------------------------------------------
#my $fakeDist = fakeDistance(@vertSelected[0],@vertSelected[-1]);
sub fakeDistance
{
	#lxout("[->] USING displacement subroutine");
	my ($vert1,$vert2) = @_;
	my @vertPos1 = ($vertPosTable{$vert1}->[0],$vertPosTable{$vert1}->[1],$vertPosTable{$vert1}->[2]);
	my @vertPos2 = ($vertPosTable{$vert2}->[0],$vertPosTable{$vert2}->[1],$vertPosTable{$vert2}->[2]);

	#lxout("$vert1 Pos = @vertPos1");
	#lxout("$vert2 Pos = @vertPos2");

	my $disp0 = @vertPos1[0] - @vertPos2[0];
	my $disp1 = @vertPos1[1] - @vertPos2[1];
	my $disp2 = @vertPos1[2] - @vertPos2[2];

	my $fakeDist = (abs($disp0)+abs($disp1)+abs($disp2));
	return $fakeDist;
}



#-----------------------------------------------------------------------------------------------------------
#CLEANUP
#-----------------------------------------------------------------------------------------------------------
sub cleanup()
{
	#drop selection
	lxout("[->]CLEANUP subroutine");
	my $selected;
	lx("select.drop polygon");
	lx("select.drop vertex");

	#vert merging is fucking up my "memory" of which edges to remove, so I'm swapping vert selSets for edge selSets
	lx("!!select.useSet superTempEdges select");
	lx("!!select.editSet superTempEdges remove");
	lx("select.convert edge");
	if (lxq("select.count edge ?") != 0) {	lx("!!select.editSet superTempEdges add");	}
	lx("select.drop edge");
	lx("select.drop vertex");

	#vert MERGE only the verts that were related to the edges.
	foreach my $vert (keys %vertPosTable){
		lx("!!select.element [$mainLayer] vertex add $vert");
	}
	lx("!!vert.merge fixed dist:[1 um]");
	lx("!!select.drop polygon");
	lx("!!select.drop vertex");

	#SELECT and delete 0 poly points
	lx("!!select.vertex add poly equal 0"); #CORRECT way to select o poly points
	$selected = lxq("select.count vertex ?");
	if ($selected != "0"){
		lx("!!delete");
	}

	#SELECT 2pt and 1pt polygons and delete 'em
	if ($keep2Pts == 0){
		lx("!!select.polygon add vertex {$selectPolygonArg} 2");
		lx("!!select.polygon add vertex {$selectPolygonArg} 1");
		$selected = lxq("select.count polygon ?");
		if ($selected != "0"){	lx("!!delete");	}
	}

	#now remove those added edges
	if ($removeEdges == 1)
	{
		lx("select.drop edge");
		lx("!!select.useSet superTempEdges select");
		lx("!!select.editSet superTempEdges remove");
		if (lxq("select.count edge ?") != 0)	{	lx("!!remove");	}
	}

	#SELECT 3+ edge polygons and delete 'em
	lx("select.edge add poly more 2");
	lx("select.convert vertex");  #in M1, I didn't need this but I do in M2.
	lx("select.convert polygon");
	$selected = lxq("select.count polygon ?");
	if ($selected != "0"){
	lx("delete");
	}

	#set the selection mode back to EDGE
	lx("select.drop edge");

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
}







#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------SUBROUTINES--------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#REMEMBER SELECTION SETTINGS and then set it to selectauto  ((MODO2 FIX))
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#sets the ACTR preset
sub actrRemember{
	our $seltype;
	our $selAxis;
	our $selCenter;
	our $actr = 1;
	if( lxq( "tool.set actr.select ?") eq "on")				{	$seltype = "actr.select";		}
	elsif( lxq( "tool.set actr.selectauto ?") eq "on")		{	$seltype = "actr.selectauto";	}
	elsif( lxq( "tool.set actr.element ?") eq "on")			{	$seltype = "actr.element";		}
	elsif( lxq( "tool.set actr.screen ?") eq "on")			{	$seltype = "actr.screen";		}
	elsif( lxq( "tool.set actr.origin ?") eq "on")			{	$seltype = "actr.origin";		}
	elsif( lxq( "tool.set actr.local ?") eq "on")				{	$seltype = "actr.local";		}
	elsif( lxq( "tool.set actr.pivot ?") eq "on")				{	$seltype = "actr.pivot";			}
	elsif( lxq( "tool.set actr.auto ?") eq "on")				{	$seltype = "actr.auto";			}
	else
	{
		$actr = 0;
		lxout("custom Action Center");
		if( lxq( "tool.set axis.select ?") eq "on")			{	 $selAxis = "select";			}
		elsif( lxq( "tool.set axis.element ?") eq "on")		{	 $selAxis = "element";			}
		elsif( lxq( "tool.set axis.view ?") eq "on")			{	 $selAxis = "view";			}
		elsif( lxq( "tool.set axis.origin ?") eq "on")		{	 $selAxis = "origin";			}
		elsif( lxq( "tool.set axis.local ?") eq "on")			{	 $selAxis = "local";			}
		elsif( lxq( "tool.set axis.pivot ?") eq "on")			{	 $selAxis = "pivot";			}
		elsif( lxq( "tool.set axis.auto ?") eq "on")			{	 $selAxis = "auto";			}
		else										{	 $actr = 1;  $seltype = "actr.auto"; lxout("You were using an action AXIS that I couldn't read");}

		if( lxq( "tool.set center.select ?") eq "on")		{	 $selCenter = "select";		}
		elsif( lxq( "tool.set center.element ?") eq "on")	{	 $selCenter = "element";		}
		elsif( lxq( "tool.set center.view ?") eq "on")		{	 $selCenter = "view";			}
		elsif( lxq( "tool.set center.origin ?") eq "on")		{	 $selCenter = "origin";		}
		elsif( lxq( "tool.set center.local ?") eq "on")		{	 $selCenter = "local";			}
		elsif( lxq( "tool.set center.pivot ?") eq "on")		{	 $selCenter = "pivot";			}
		elsif( lxq( "tool.set center.auto ?") eq "on")		{	 $selCenter = "auto";			}
		else										{ 	 $actr = 1;  $seltype = "actr.auto"; lxout("You were using an action CENTER that I couldn't read");}
	}
	lx("tool.set actr.auto on");
}


#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#SET THE ACTION CENTER SETTINGS BACK
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
sub actrRestore{
	if ($actr == 1) {	lx( "tool.set {$seltype} on" ); }
	else { lx("tool.set center.$selCenter on"); lx("tool.set axis.$selAxis on"); }
}




