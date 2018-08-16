#perl
#AUTHOR: Seneca Menard
#version 1.2
#Stretch  snap to zero script.
#(9-9-06 bugfix) : I had code in the script to snap any stretches that were below 0% to -100%, but that was failing because modo's script system doesn't allow us to modify the currently active transfmation, it
# only allows us to apply new transformations.. :(  So, if you were stretched to -40%X, it'd apply that and another -100%X and so you'd get an end transform of 140%X and that's not what was intended.  I'll put that code back in when it'll work...  :)
#(9-30-06 bugfix) : The script previously only used to work with the old stretch tool.  It now works with the Modo2 Transform and TransformScale tools.
#(9-10-09 error reporting) : I made it so the script now complains if you're not using the correct stretch tools or haven't done any actual stretching yet.
#(10-15-09 bugfix) : What this script does is ask modo if you're using the xfrm.stretch, Transform, or TransformScale tool, and if not, it wouldn't know which tool properties it should be adjusting and would normally cancel.  Now, you can override it's query by just typing in either a "stretch" or "transform" cvar and that will force the script to adjust those tool settings manually.  This was made, so that if you're using a tool preset called "stretchyfuntime" or whatever, heh, you can still get the script to do it's job by telling it you're really just using the stretch tool.

#script arguments :
# "stretch" : Use this argument to force the script to assume you're using the xfrm.stretch tool
# "Transform" : Use this argument to force the script to assume you're using the Transform tool



lxout("[->] : Running STRETCH SNAP TO ZERO : version 1.11");

if( lxq( "tool.set xfrm.stretch ?") eq "on" )												{our $tool = "stretch";}
elsif((lxq( "tool.set TransformScale ?") eq "on") || (lxq("tool.set Transform  ?") eq "on")){our $tool = "Transform";}
foreach my $arg (@ARGV){
	if ($arg =~ /stretch/i)																	{our $tool = "stretch"; lxout("Forcing the script to assume you're actually using the stretch tool");}
	elsif ($arg =~ /transform/i)															{our $tool = "Transform"; lxout("Forcing the script to assume you're actually using the Transform tool");}
}

if ($tool eq "stretch"){
	my $X = lxq("tool.attr xfrm.stretch factX ?");
	my $Y = lxq("tool.attr xfrm.stretch factY ?");
	my $Z = lxq("tool.attr xfrm.stretch factZ ?");
	if (($X == 1) && ($Y == 1) && ($Z == 1)){die("What this script does is check the current values of the stretch tool and if any of the scales are not at 100%, it'll change those values to 0%, thus flattening them.  Right now, I'm seeing that all 3 values are 100% and thus the script will do nothing and so I'm cancelling it.");}

	if ($X != 1)	{	lx("tool.attr xfrm.stretch factX 0");	}
	if ($Y != 1)	{	lx("tool.attr xfrm.stretch factY 0");	}
	if ($Z != 1)	{	lx("tool.attr xfrm.stretch factZ 0");	}

	lx("tool.doApply");
	lx("tool.set xfrm.stretch off");
}

elsif($tool eq "Transform"){
	my $X = lxq("tool.attr xfrm.transform SX ?");
	my $Y = lxq("tool.attr xfrm.transform SY ?");
	my $Z = lxq("tool.attr xfrm.transform SZ ?");
	if (($X == 1) && ($Y == 1) && ($Z == 1)){die("What this script does is check the current values of the stretch tool and if any of the scales are not at 100%, it'll change those values to 0%, thus flattening them.  Right now, I'm seeing that all 3 values are 100% and thus the script will do nothing and so I'm cancelling it.");}

	if ($X != 1)	{	lx("tool.attr xfrm.transform SX 0");	}
	if ($Y != 1)	{	lx("tool.attr xfrm.transform SY 0");	}
	if ($Z != 1)	{	lx("tool.attr xfrm.transform SZ 0");	}

	lx("tool.doApply");
	lx("tool.set xfrm.stretch off");
}

else{
	die("You're not using the xfrm.stretch, Transform, or TransformScale tool, and you didn't override the script's query of what tool you're using by typing in the 'stretch' or 'Transform' cvar and so the script is being cancelled.");
}








sub popup #(MODO2 FIX)
{
	lx("dialog.setup yesNo");
	lx("dialog.msg {@_}");
	lx("dialog.open");
	my $confirm = lxq("dialog.result ?");
	if($confirm eq "no"){die;}
}
