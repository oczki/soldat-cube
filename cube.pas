// --- cube v1.6 --- advanced Soldat team balancer by fri [ http://oko.im ]

const
// -------------------------------------------------------------------------------------------------------------------------
// ----------[ CONFIG STARTS HERE ]-----------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------------------------------------------

// --------------------------------------------------
// CheckOnLeave:  true or false
//     If true, cube will check balance when someone leaves the server.
//     Default: false (because it would balance too often on public servers)
CheckOnLeave = false;

// --------------------------------------------------
// KeepTeamScore:  true or false
//     If true, cube will restore team's score after all its players leave (Soldat clears it by default).
//     Default: false
KeepTeamScore = false;

// --------------------------------------------------
// SwapCountsFlags:  true or false
//     If true, player's captures are counted, and players with one or more caps are not preferred during choosing.
//     If false, automatic swap will ignore number of caps the chosen player has, and just choose whoever fits the balance.
//     Default: false
SwapCountsFlags = false;

// --------------------------------------------------
// SwapLimit:  non-negative integer
//     Specifies the maximum number of swaps per map. If it's reached and current status would result in another swap,
//     cube will say that teams are balanced. Set 0 for unlimited swaps.
//     Default: 2
SwapLimit = 2;

// --------------------------------------------------
// TriggerLimit:  integer
//     Specifies the maximum number of team-changing trigger uses (e.g. !alpha, !2). Only affects the built-in triggers,
//     so using the Esc-menu isn't limited. Resets after map change. Set -1 to disable those triggers. Set 0 for no limits.
//     Default: 2
TriggerLimit = 2;

// --------------------------------------------------
// Interval:  non-negative integer
//     Time in minutes between automatic balance checks. If someone manually requested the balance check, timer is reset.
//     Set 0 to disable automatic balance checks.
//     Default: 3
Interval = 3;

// --------------------------------------------------
// ImmuneTime:  non-negative integer
//     Time in minutes, specifying the immunity from cube. The player won't be moved again during this time, except it's
//     really necessary (e.g. all other players have been moved recently). Set 0 to disable immunity time. Bad idea.
//     Default: 20
ImmuneTime = 20;

// --------------------------------------------------
// LockTime:  non-negative integer
//     Time in minutes, during which the recently moved player can't change the team again. They still can go to spec, or
//     join the weaker team out of their own will. It just won't let them go back to the stronger team. Set 0 to disable.
//     Default: 2
LockTime = 2;

// --------------------------------------------------
// Method:  integer in range 1..7
//     Specifies the default method of choosing players to move. Possible options:
//     1: Completely random player.       2: Player with fewest kills.                3: Player with fewest caps.
//     4: Player with worst K/D ratio.    5: Player with fewest kills and no caps.    6: Player with worst K/D and no caps.
//     7: Random player with no caps.
//     Default: 5
Method = 5;

// --------------------------------------------------
// Colors:  longint
//     Color of messages spit out by cube.
//     ColorGreen: Good messages. Default: $FFAAFFAA
//     ColorRed: Bad messages.    Default: $FFFFAAAA
//     ColorMsg: Notifications.   Default: $FFF8F35A
ColorGreen = $FFAAFFAA;
ColorRed   = $FFFFAAAA;
ColorMsg   = $FFF8F35A;

// --------------------------------------------------
// Nickname and HardwareID exclusion
//     Players can be excluded from cube's reach, which makes them immune to balance all the time. They can also use
//     triggers without limits and join any team they want. This section specifies who to exclude.
//     You can also use [ /exclude ID ] or [ /exclude nickname ] command to exclude someone until they leave the server.
//     To get someone's HardwareID, use [ /hwid ID ] or [ /hwid nickname ]. Nicknames are case-sensitive in those commands.
// --
// Exclusion:  integer in range 0..2
//     Specifies the type of exclusion. Possible options:
//     0: Exclusion is disabled.    1: Exclusion based on nicknames.    2: Exclusion based on HardwareID.
//     Default: 1
Exclusion = 1;

// Insert multiple nicknames or HWIDs to exclude by separating them with "; " - semicolon and space. Semicolon AND space.
// Don't forget to put the semicolon at the very end of the line, too.
//     Default:  Nicks = 'Dutch; fri; rr-';
//               HWIDs = '2B6D3D6C7B9; 7C0505C3BFB; BFDCAA9C57D';
Nicks = 'Dutch; fri; rr-';
HWIDs = '2B6D3D6C7B9; 7C0505C3BFB; BFDCAA9C57D';

// -------------------------------------------------------------------------------------------------------------------------
// ----------[ END OF CONFIG ]--- DON'T TOUCH ANYTHING BELOW THIS LINE -----------------------------------------------------
// -------------------------------------------------------------------------------------------------------------------------

cubeVersion = '1.6';

type tbal = record
	mode,           // used for delaying the messages and showing different ones, based on trigger
	restoreDelay:   // delaying setteamscore after last team player leaves. alpha: >0, bravo: <0
		shortint;
	justLeft:       // used for events after player leaves
		boolean;
	numberGlobal,   // number of balances since recompile
	lastbalance,    // time since last successful balance
	lastcheck:      // time since last check
		integer;
	numberMap,      // number of balances on current map
	swaps,          // number of swaps on current map
	tempAlphaScore, // used only if KeepTeamScore is true
	tempBravoScore, // used only if KeepTeamScore is true
	maxBalances,    // used to limit the number of balances per trigger (safety measure)
	smallerTeam:    // smaller team (calculated on every team change)
		byte;
end;

type tpl = record
	lock,           // time since forced team change
	immune:         // time of immunity against future balances
		integer;
	prevteam,       // storing the last team the player was in
	triggers:       // number of team-changing trigger uses (!alpha, !2, etc.)
		byte;
	excluded,       // is the player on the exclusion list?
	movedByScript:  // was the player moved by script, or by himself?
		boolean;
end;


var
	bal: tbal;                       // balance-related
	pl: array [1..32] of tpl;        // player-related
	MinDiff, SwapDiff: byte;         // minimum difference in team scores to balance if player diff = 1
	exclusionlist: array of string;  // exploded list of nicks or hardware IDs excluded from balance



// by CurryWurst and Curt (DorkeyDear)
function Explode(Source: string; const Delimiter: string): array of string;
var
	Position, DelLength, ResLength: integer;
begin
	DelLength := Length(Delimiter);
	Source := Source + Delimiter;
	repeat
		Position := Pos(Delimiter, Source);
		SetArrayLength(Result, ResLength + 1);
		Result[ResLength] := Copy(Source, 1, Position - 1);
		ResLength := ResLength + 1;
		Delete(Source, 1, Position + DelLength - 1);
	until (Position = 0);
	SetArrayLength(Result, ResLength - 1);
end;



procedure msg(id: byte; text: string; good: boolean); // good: true - green, false - red. i have no idea why using "word" type doesn't work here...
begin
	if (id = 255) then writeln('cube>  ' + text)
	else begin
		if (good) then writeconsole(id, text, ColorGreen) else writeconsole(id, text, ColorRed);
	end;
end;



// built-in abs(x) works on Extended instead of Integer
function abs2(val: integer): integer;
begin
	result := iif(val<0, -val, val);
end;



function CheckExclusion(input: string): boolean;
var i: shortint;
begin
	result := false;
	for i := 0 to (GetArrayLength(exclusionlist)-1) do if (input = exclusionlist[i]) then begin
		result := true;
		break;
	end;
end;



// oh god what's going on here
function CalcWeakerTeam(noswap: boolean): byte;  // 0: teams are balanced,  1, 31: alpha is smaller,  2, 32: bravo is smaller,
var intAlphaPlayers, intAlphaScore: integer;     // 11: swap best bravo with worst alpha,  12: swap best alpha with worst bravo,
begin                                            // 21: move worst bravo to alpha,  22: move worst alpha to bravo.
	result := 0;
	intAlphaPlayers := AlphaPlayers;
	intAlphaScore := AlphaScore;
	if (not noswap) and (intAlphaPlayers = BravoPlayers) then begin
		if (abs2(intAlphaScore-BravoScore) >= SwapDiff) then begin
			if (intAlphaScore > BravoScore) then result := 12 else result := 11;
		end else begin
			if (intAlphaScore > BravoScore) then result := 42 else if (intAlphaScore < BravoScore) then result := 41;
		end;
	end else if (abs2(intAlphaPlayers-BravoPlayers) >= 2) then begin
		if (abs2(intAlphaScore-BravoScore) >= SwapDiff) then begin
			if (intAlphaPlayers > BravoPlayers) and (intAlphaScore < BravoScore) then result := 22
			else if (intAlphaPlayers < BravoPlayers) and (intAlphaScore > BravoScore) then result := 21
			else if (intAlphaPlayers > BravoPlayers) then result := 2 else result := 1;
		end else begin
			if (intAlphaPlayers > BravoPlayers) then result := 2 else result := 1;
		end;
	end else if (abs2(intAlphaPlayers-BravoPlayers) = 1) then begin // difference of one player: compare scores
		if (abs2(intAlphaScore-BravoScore) < MinDiff) then begin
			if (intAlphaPlayers > BravoPlayers) then result := 32 else result := 31; // used for onjoin check to move new player to smaller team.
		end                                                                              // balance itself treats it as if teams were balanced.
		else if (intAlphaPlayers > BravoPlayers) and (intAlphaScore > BravoScore) then result := 2
		else if (intAlphaPlayers < BravoPlayers) and (intAlphaScore < BravoScore) then result := 1;
	end;
end;



// cube info
procedure ShowCubeInfo(caller: byte);
begin
	msg(caller, 'cube v' + cubeVersion + ' by fri  ::  Gamemode: ' + iif(GameStyle=3, 'CTF', 'Inf') + '  ::  Current settings:', false);
	if (SwapCountsFlags) then msg(caller, 'SwapCntFlags =  true (swap will ignore players who capped the flag)', true);
	if (KeepTeamScore) then msg(caller, 'KeepTeamScr  =  true (even if team is empty, its score is kept)', true);
	case Exclusion of
		0: msg(caller, 'Exclusion  =  0 (everyone is included in balance)', true);
		1: msg(caller, 'Exclusion  =  1 (' + inttostr(GetArrayLength(exclusionlist)) + ' names excluded from balance)', true);
		2: msg(caller, 'Exclusion  =  2 (' + inttostr(GetArrayLength(exclusionlist)) + ' hardware IDs excluded from balance)', true);
		else msg(caller, 'Exclusion  =  ' + inttostr(Exclusion) + ' (ERROR: unknown mode, exclusion won''t work!)', false);
	end;
	case Method of
		1: msg(caller, 'Method     =  1 (random player will be moved)', true);
		2: msg(caller, 'Method     =  2 (player with the fewest kills will be moved)', true);
		3: msg(caller, 'Method     =  3 (player with the fewest caps will be moved)', true);
		4: msg(caller, 'Method     =  4 (player with the worst k/d ratio will be moved)', true);
		5: msg(caller, 'Method     =  5 (player with fewest kills and no caps will be moved)', true);
		6: msg(caller, 'Method     =  6 (player with worst k/d and no caps will be moved)', true);
		7: msg(caller, 'Method     =  7 (random player with no caps will be moved)', true);
		else msg(caller, 'Method     =  ' + inttostr(Method) + ' (ERROR: unknown method, balance won''t work!)', false);
	end;
	msg(caller, 'Interval   = ' + iif(Interval>9, '', ' ')   + inttostr(Interval)   + iif(Interval>0,   ' min (time between automatic balances)', ' (automatic balance is disabled)'), true);
	msg(caller, 'ImmuneTime = ' + iif(ImmuneTime>9, '', ' ') + inttostr(ImmuneTime) + iif(ImmuneTime>0, ' min (player won''t be moved again until ' + inttostr(ImmuneTime) + ' min pass)', ' (disabled)'), true);
	msg(caller, 'LockTime   = ' + iif(LockTime>9, '', ' ')   + inttostr(LockTime)   + iif(LockTime>0,   ' min (locking team of moved player for ' + inttostr(LockTime) + ' min)', ' (disabled)'), true);
	msg(caller, 'Balances this run: ' + inttostr(bal.numberGlobal) + ' (' + inttostr(bal.numberMap) + ' on prev map)' + iif(bal.numberGlobal>0, ' | Last one was ' + iif(bal.lastbalance=32767, 'over 9 hours ago', inttostr(bal.lastbalance div 60) + ' min ' + inttostr(bal.lastbalance mod 60) + ' s ago'), ''), false);
end;



// set default values to variables and show some spam
procedure ActivateServer();
var i: byte;
begin

	// set MinDiff and SwapDiff for current gamemode
	case GameStyle of
		3: begin
			MinDiff  := 2;
			SwapDiff := 6;
		end;
		5: begin
			MinDiff  := 30;
			SwapDiff := 75;
		end;
		else begin
			writeln('cube>  Not supported GameStyle. cube is disabled.');
			exit;
		end;
	end;

	// reset all variables
	bal.mode         := 0;
	bal.restoreDelay := 0;
	bal.numberGlobal := 0;
	bal.maxBalances  := 0;
	bal.lastbalance  := 5;
	bal.smallerTeam  := CalcWeakerTeam(true) mod 10;
	bal.justLeft     := false;
	if (KeepTeamScore) then begin
		bal.tempAlphaScore := AlphaScore;
		bal.tempBravoScore := BravoScore;
	end;
	if (Interval > 0) then bal.lastcheck := Interval * 60 else bal.lastcheck := -1;
	for i := 1 to 32 do begin
		pl[i].immune   := 0;
		pl[i].lock     := 0;
		pl[i].triggers := 0;
		pl[i].movedByScript := false;
		if (GetPlayerStat(i, 'Active') = true) then pl[i].prevteam := GetPlayerStat(i, 'Team') else pl[i].prevteam := 0;
	end;

	// check exclusion lists
	if (Exclusion = 1) then begin
		exclusionlist := Explode(Nicks, '; ');
		for i := 1 to 32 do if (GetPlayerStat(i, 'Active') = true) then pl[i].excluded := CheckExclusion(IDtoName(i));
	end else if (Exclusion = 2) then begin
		exclusionlist := Explode(HWIDs, '; ');
		for i := 1 to 32 do if (GetPlayerStat(i, 'Active') = true) then pl[i].excluded := CheckExclusion(IDtoHW(i));
	end;

	// show some information on recompile
	ShowCubeInfo(255);
	writeconsole(0, '       [ cube v' + cubeVersion + ' by fri ]', $FFFFCC55);
	writeconsole(0, 'Script recompiled. Happy balancing!', $FFFFCC55);
end;



// returns true (and shows a message) if a player is already in the specified team OR they already reached the trigger limit OR his current team is weaker
function CheckTeamChange(id, team: byte): boolean;
var temp: string;
begin
	result := false;
	if (TriggerLimit < 0) then begin
		writeconsole(id, 'Team-change triggers are disabled on this server.', ColorRed);
		result := true;
		exit;
	end;
	if (TriggerLimit > 0) then if (pl[id].triggers >= TriggerLimit) then if (team < 5) then if (not pl[id].excluded) then begin
		writeconsole(id, 'You''ve reached the trigger limit (' + inttostr(TriggerLimit) + '). Wait for map change.', ColorRed);
		result := true;
		exit;
	end;
	if (GetPlayerStat(id, 'Team') = team) then begin
		case team of
			1: temp := 'Alpha';
			2: temp := 'Bravo';
			5: temp := 'Spectator';
			else temp := '*error*';
		end;
		writeconsole(id, 'You are already in ' + temp + ' Team!', ColorRed);
		result := true;
		exit;
	end;
	if (not pl[id].excluded) then if (team <> 5) then begin
		if ((CalcWeakerTeam(true) mod 10) = GetPlayerStat(id, 'Team')) then begin
			writeconsole(id, 'Your team is weaker - please stay where you are.', ColorRed);
			result := true;
		end
		else if (CalcWeakerTeam(true) = 0) then begin
			writeconsole(id, 'Teams are balanced - please don''t ruin it.', ColorRed);
			result := true;
		end;
	end;
end;



// returns id of chosen player
function ChoosePlayer(team, choosingmethod: byte): byte;
var i: byte;
		j, maxval, temp: integer;
		player: array [1..32] of byte;
begin
	result := 0;

	// create an array of players who may be moved
	j := 0;
	for i := 1 to 32 do if (GetPlayerStat(i, 'Active') = true) then if not (pl[i].excluded) then if (pl[i].immune = 0) then if (GetPlayerStat(i, 'Team') = team) then if (GetPlayerStat(i, 'Flagger') = false) then if (GetPlayerStat(i, 'Human') = true) then begin
		if (choosingmethod = 7) and (GetPlayerStat(i, 'Flags') > 0) then continue; // the seventh method ignores players who have caps
		j := j + 1;
		player[j] := i;
	end;

	// the non-caps-random-method is similar to regular random, and since we already ignored players who have capped, we can use the first method
	if (choosingmethod = 7) then choosingmethod := 1;

	// good, now just pick one player using one of the methods
	if (j > 0) then case choosingmethod of

		// method 0: choose the player with the most kills AND no caps. if it fails, fewest caps (used for swapping best and weakest players)
		0: begin
				maxval := 0;
				for i := 1 to j do if (((SwapCountsFlags) and (GetPlayerStat(player[i], 'Flags') = 0)) or (not SwapCountsFlags)) then begin
					temp := GetPlayerStat(player[i], 'Kills');
					if (temp >= maxval) then begin
						maxval := temp;
						result := player[i];
					end;
				end;
				if (maxval = 0) then for i := 1 to j do begin
					temp := GetPlayerStat(player[i], 'Flags');
					if (temp <= maxval) then begin
						maxval := temp;
						result := player[i];
					end;
				end;
			end;

		// method 1: choose the player randomly
		1: result := iif(j=1, player[1], player[random(1, j+1)]);

		// method 2: choose the player with fewest kills
		2: begin
				maxval := 32767;
				for i := 1 to j do begin
					temp := GetPlayerStat(player[i], 'Kills');
					if (temp <= maxval) then begin
						maxval := temp;
						result := player[i];
					end;
				end;
			end;

		// method 3: choose the player with fewest flag captures
		3: begin
				maxval := 32767;
				for i := 1 to j do begin
					temp := GetPlayerStat(player[i], 'Flags');
					if (temp <= maxval) then begin
						maxval := temp;
						result := player[i];
					end;
				end;
			end;

		// method 4: choose the player with the worst kills/deaths ratio
		4: begin
				maxval := 32767;
				for i := 1 to j do begin
					temp := round(50 * (GetPlayerStat(player[i], 'Kills') / iif(GetPlayerStat(player[i], 'Deaths')=0, 1, GetPlayerStat(player[i], 'Deaths'))));
					if (temp <= maxval) then begin
						maxval := temp;
						result := player[i];
					end;
				end;
			end;

		// method 5: fewest kills AND no caps. if it fails, fewest caps
		5: begin
				maxval := 32767;
				for i := 1 to j do if (GetPlayerStat(player[i], 'Flags') = 0) then begin
					temp := GetPlayerStat(player[i], 'Kills');
					if (temp <= maxval) then begin
						maxval := temp;
						result := player[i];
					end;
				end;
				if (maxval = 32767) then for i := 1 to j do begin
					temp := GetPlayerStat(player[i], 'Flags');
					if (temp <= maxval) then begin
						maxval := temp;
						result := player[i];
					end;
				end;
			end;

		// method 6: worst k/d ratio AND no caps. if it fails, fewest caps
		6: begin
				maxval := 32767;
				for i := 1 to j do if (GetPlayerStat(player[i], 'Flags') = 0) then begin
					temp := round(50 * (GetPlayerStat(player[i], 'Kills') / iif(GetPlayerStat(player[i], 'Deaths')=0, 1, GetPlayerStat(player[i], 'Deaths'))));
					if (temp <= maxval) then begin
						maxval := temp;
						result := player[i];
					end;
				end;
				if (maxval = 32767) then for i := 1 to j do begin
					temp := GetPlayerStat(player[i], 'Flags');
					if (temp <= maxval) then begin
						maxval := temp;
						result := player[i];
					end;
				end;
			end;

		else writeln('cube>  ERROR - please check "Method" (should be 1, 2, ... or 7)');
	end
	// okay. but, if there are no players without immunity left, we need to use the final method:

	// choose the player with the least immune time left (this part of code is ran about 5% of the time actually)
	else begin
		writeln('cube>  Everyone in ' + iif(team=1, 'Alpha', 'Bravo') + ' Team is immune to balance. Using alternative method.');
		j := ImmuneTime * 60;
		for i := 1 to 32 do if (GetPlayerStat(i, 'Active') = true) then if (not pl[i].excluded) then if (GetPlayerStat(i, 'Team') = team) then if (pl[i].immune <= j) then if (GetPlayerStat(i, 'Human') = true) then begin
			j := pl[i].immune; // new smallest time found
			result := i;       // whose time was it?
		end;
	end;

	// did something go wrong?
	if (result = 0) then begin
		writeln('cube>  ChoosePlayer returned 0. Teams can''t be balanced. Probably everyone is excluded from balance.');
		exit;
	end;

	// give the chosen player some immunity time, not to annoy him with future balances
	if (ImmuneTime > 0) then pl[result].immune := ImmuneTime * 60;

	// set the lock timer to 0. it will be re-set after moving
	if (LockTime > 0) then pl[result].lock := 0;
end;



function ShowPlayers(): string;
begin
	result := '[' + inttostr(AlphaPlayers) + 'v' + inttostr(BravoPlayers) + ' ' + inttostr(AlphaScore) + ':' + inttostr(BravoScore) + ']';
end;



procedure Swap(caller, id1, id2: byte);
var i: byte;
begin
	if (TimeLeft <= 10) then begin
		if (caller = 255) or (caller = 0) then writeln('cube>  Less than 10 seconds left. Swap is blocked.') 
			else writeconsole(caller, 'Less than 10 seconds left. Swap is blocked.', ColorRed);
		exit;
	end;

	// swap all
	if (id1 = 0) and (id2 = 0) then begin
		for i := 1 to 32 do if (GetPlayerStat(i, 'Active') = true) then if (GetPlayerStat(i, 'Team') <= 2) then begin
			pl[i].lock := 0;
			pl[i].movedByScript := true;
			command('/setteam' + iif(GetPlayerStat(i, 'Team') = 1, '2 ', '1 ') + inttostr(i));
		end;
		writeconsole(0, 'Teams swapped!', ColorGreen);
		writeln('cube>  Swap: teams swapped.');
	end // end of swap all

	// two players only
	else if (id1 <> 0) and (id2 <> 0) then try
		if (GetPlayerStat(id1, 'Active') = false) or (GetPlayerStat(id2, 'Active') = false) then begin
			if (caller = 255) or (caller = 0) then writeln('cube>  Swap: one or both players you specified ain''t present.') else writeconsole(caller, 'One or both players you specified ain''t present.', ColorRed);
			exit;
		end;
		i := GetPlayerStat(id1, 'Team');
		if (i = 5) or (GetPlayerStat(id2, 'Team') = 5) then begin
			if (caller = 255) or (caller = 0) then writeln('cube>  Swap: can''t swap spectators.') else writeconsole(caller, 'Can''t swap spectators.', ColorRed);
			exit;
		end;
		if (GetPlayerStat(id2, 'Team') = i) then begin
			if (caller = 255) or (caller = 0) then writeln('cube>  Swap: no point in swapping players from the same team.') else writeconsole(caller, 'No point in swapping players from the same team.', ColorRed);
			exit;
		end;
		pl[id1].lock := 0;
		pl[id2].lock := 0;
		pl[id1].movedByScript := true;
		pl[id2].movedByScript := true;
		command('/setteam' + inttostr(i) + ' ' + inttostr(id2));
		command('/setteam' + iif(i=1, '2 ', '1 ') + inttostr(id1));
		writeconsole(id1, 'Swapped teams with ' + idtoname(id2) + '.', ColorMsg);
		writeconsole(id2, 'Swapped teams with ' + idtoname(id1) + '.', ColorMsg);
		if (caller = 255) or (caller = 0) then writeln('cube>  Swap: successfully swapped teams of chosen players.') else writeconsole(caller, 'Successfully swapped teams of chosen players.', ColorGreen);
	except
		if (caller = 255) or (caller = 0) then writeln('cube>  Swap: something went wrong. Check the command and try again.') else writeconsole(caller, 'Something went wrong. Check the command and try again.', ColorRed);
		exit;
	end // end of swap two players only

	else begin
		if (caller = 255) or (caller = 0) then writeln('cube>  Swap: something went wrong. Check the command and try again.') else writeconsole(caller, 'Something went wrong. Check the command and try again.', ColorRed);
	end;

	if (caller = 0) then writeconsole(0, 'Teams balanced by swapping two players. ' + ShowPlayers(), ColorGreen);
end;



// auto: true = internal (apponidle, onleavegame, balance itself) or hidden (/bal); false = external (onplayerspeak)
procedure Balance(auto, noswap: boolean);
var intAlphaPlayers, intAlphaScore: integer; // we need to have AlphaPlayers and ~Score as an integer, not a byte. it used to work on 2.6.5 without such workarounds...
	stopBalance: boolean;
	temp, pl1, pl2: byte;
begin
	// if current gamemode is not supported (neither ctf nor inf) then exit
	if (GameStyle <> 3) and (GameStyle <> 5) then exit;

	// start counting down the time since last check
	if (Interval > 0) then bal.lastcheck := Interval * 60;

	// soldatserver 2.7.0+ workaround
	intAlphaPlayers := AlphaPlayers;
	intAlphaScore := AlphaScore;
	stopBalance := false;
	bal.smallerTeam := 0;

	// if there are less than three active players then don't bother balancing
	if (NumPlayers-Spectators < 3) then begin
		if (not auto) then writeconsole(0, 'Too few players. Balance is disabled.', $FFFFAAAA) else writeln('cube>  Too few players. Balance is disabled.');
		exit;
	end;

	// don't balance if one team won the round
	if (intAlphaScore = ScoreLimit) or (BravoScore = ScoreLimit) then begin
		if (not auto) then begin
			writeconsole(0, 'The map will change soon. Balance is disabled', ColorRed);
			writeconsole(0, 'to prevent ''wrong map version'' problems.', ColorRed);
			writeln('cube>  One team won the round. Balance is blocked until the map changes.');
		end;
		exit;
	end;

	// different spam messages for each trigger method
	case bal.mode of
		0: if (auto) then writeln('cube>  Checking balance (automatic check)... ' + ShowPlayers())
			else writeln('cube>  Checking balance (request by player)... ' + ShowPlayers());
		1: writeln('cube>  Performing another balance check... ' + ShowPlayers());
		2: writeln('cube>  Checking balance (after shuffle)... ' + ShowPlayers());
		3: writeln('cube>  Checking balance (player leaving)... ' + ShowPlayers());
		4: writeln('cube>  Checking balance (silent request by player)... ' + ShowPlayers());
		5: writeln('cube>  Checking balance (request by admin)... ' + ShowPlayers());
	end;
	if (bal.mode > 2) then bal.mode := 0;

	// calculate the balance
	temp := CalcWeakerTeam(noswap);

	if (temp > 30) then temp := 0;

	// no action
	if (temp = 0) then begin
		if (bal.mode = 0) and (not auto) then begin
			writeconsole(0, 'Teams are fine, no need to balance. ' + ShowPlayers(), ColorGreen);
		end;
		exit;
	end;

	// regular balance
	if (temp < 3) then begin
		pl1 := ChoosePlayer(iif(temp=1, 2, 1), Method);
		if (pl1 = 0) then begin
			writeconsole(0, 'Something went wrong. Maybe everyone is excluded from balance?', ColorRed);
			writeconsole(0, 'Or there are multiple bots, which I can''t move? I quit. *sniff*', ColorRed);
			exit;
		end;
		pl[pl1].movedByScript := true;
		command('/setteam' + iif(temp=1, '1 ', '2 ') + inttostr(pl1));
		if (bal.mode <> 2) then writeconsole(pl1, 'You were moved due to unbalanced teams.', ColorMsg);
		if (LockTime > 0) then pl[pl1].lock := LockTime * 60; // locking the player in his new team
	end // end of regular balance

	// swap when teams are equal in player count, but one is clearly stronger
	else if (temp < 20) then begin

		// swaps limit not reached, swap the players!
		if (bal.swaps < SwapLimit) or (SwapLimit = 0) then begin
		
			// best player (most kills), from the stronger team
			pl1 := ChoosePlayer(iif(temp=11, 2, 1), 0);
			
			// weakest player (fewest kills), from the opposite team
			pl2 := ChoosePlayer(iif(temp=11, 1, 2), iif(SwapCountsFlags, 5, 2));
			
			Swap(0, pl1, pl2);
			if (SwapLimit <> 0) then bal.swaps := bal.swaps + 1;

			// lock their teams in case they wanted to go back
			if (LockTime > 0) then begin
				pl[pl1].lock := LockTime * 60;
				pl[pl2].lock := LockTime * 60;
			end;

			// don't show "Teams balanced.", as there is another message especially for this method
			temp := 250;

			// multiply the interval by 1.5 after swap, so another swap won't occur too fast
			if (Interval > 0) then bal.lastcheck := Interval * 90;

		// swaps limit reached, do nothing
		end else begin
			writeln('cube>  Swap would trigger now, but the SwapLimit (' + inttostr(SwapLimit) + ') is reached.');
			if (bal.mode = 0) and (not auto) then writeconsole(0, 'Teams are fine, no need to balance. ' + ShowPlayers(), ColorGreen);
			exit;
		end;

	end // end of swap

	// move weakest player to opposite team (if it wasn't here then cube would use normal balance, and then immediately swap)
	else begin
		pl1 := ChoosePlayer(iif(temp=21, 2, 1), 2);
		if (pl1 = 0) then exit;
		pl[pl1].movedByScript := true;
		command('/setteam' + iif(temp=21, '1 ', '2 ') + inttostr(pl1));
		if (bal.mode <> 2) then writeconsole(pl1, 'You were moved due to unbalanced teams.', ColorMsg);
		if (LockTime > 0) then pl[pl1].lock := LockTime * 60;
	end;

	// don't show msg after shuffle
	if (bal.mode = 2) then temp := 250;

	// now add some delay for spam message
	if (temp = 250) then bal.mode := 0 else bal.mode := 1;

	// increase balance counters
	inc(bal.numberGlobal, 1);
	bal.numberMap := bal.numberMap + 1;

	// start counting the time since last balance
	bal.lastbalance := 0;

	// check if some previous methods want us to cease re-balancing
	if (temp > 240) or (stopBalance) then begin
		bal.maxBalances := 0;
		exit;
	end;

	// iterations limiter
	bal.maxBalances := bal.maxBalances + 1;
	if (bal.maxBalances >= (intAlphaPlayers + BravoPlayers)/2 + 1) then exit;

	// re-run the balance. maybe we need to transfer two players instead of one?
	Balance(true, true);
end;



// shuffling the teams on admin's demand
procedure Shuffle(caller: byte);
var i, j, numpl, temp: byte;
		intAlphaScore: integer;
		player: array [1..32] of byte;
begin
	// this doesn't work for non-two-team gamemodes
	if (GameStyle <> 3) and (GameStyle <> 5) and (GameStyle <> 6) then exit;

	// don't shuffle if there are less than four players
	if (NumPlayers-Spectators <= 3) then begin
		msg(caller, 'Too few players to shuffle.', false);
		exit;
	end;

	// create an array of online players and reset their lock time. don't touch excluded players!
	numpl := 0;
	for i := 1 to 32 do if (GetPlayerStat(i, 'Active') = true) then if (GetPlayerStat(i, 'Team') <> 5) then if (not pl[i].excluded) then begin
		numpl := numpl + 1;
		player[numpl] := i;
		pl[i].lock := 0;
	end;

	// sort players by kills (descending)
	j := numpl;
	while j > 1 do begin
		for i := 1 to j-1 do if (GetPlayerStat(player[i], 'Kills') < GetPlayerStat(player[i+1], 'Kills')) then begin
			temp := player[i];
			player[i] := player[i+1];
			player[i+1] := temp;
		end;
		j := j - 1;
	end;

	// put players to alternating teams, starting with weaker team
	intAlphaScore := AlphaScore;
	temp := iif(intAlphaScore-BravoScore>0, 0, 1);
	for i := 1 to numpl do begin
		bal.smallerTeam := 0;
		pl[i].movedByScript := true;
		if (GetPlayerStat(player[i], 'Team') <> iif(i mod 2 = temp, 1, 2)) then command('/setteam' + iif(i mod 2 = temp, '1 ', '2 ') + inttostr(player[i]));
		pl[i].movedByScript := false;
	end;

	// make sure teams are balanced
	bal.mode := 2;
	Balance(true, true);
end;



// count some things here and there
procedure AppOnIdle(ticks: integer);
var i: byte;
begin
	if (ticks mod 60 <> 0) then exit; // compatibility fix for 60 Hz AppOnIdle

	if (GameStyle <> 3) and (GameStyle <> 5) then exit;

	// optional score restoring, delayed one second after last team's player leaves
	if (KeepTeamScore) then if (bal.restoreDelay <> 0) then begin
		setteamscore(iif(bal.restoreDelay>0, 1, 2), abs2(bal.restoreDelay));
		bal.restoreDelay := 0;
	end;

	// the part after the delay
	if (bal.mode = 1) then begin
		bal.mode := 0;
		bal.maxBalances := 0;
		writeconsole(0, 'Teams balanced. ' + ShowPlayers(), ColorGreen);
		writeln('cube>  Teams balanced. ' + ShowPlayers());
	end;

	// spam after shuffle, and lock shuffled players
	if (bal.mode = 2) then begin
		for i := 1 to 32 do if (GetPlayerStat(i, 'Active') = true) and (GetPlayerStat(i, 'Team') <> 5) then pl[i].lock := LockTime * 60;
		bal.mode := 0;
		bal.maxBalances := 0;
		writeconsole(0, 'Teams shuffled!', ColorGreen);
		writeln('cube>  Teams shuffled. ' + ShowPlayers());
	end;

	// another delay, this time for OnLeaveGame check. it has to be delayed, because without it the leaving player is still "present"
	if (bal.mode = 3) then Balance(true, false);

	// periodic check. "then-if"s fit better than "and"s here
	if (Interval > 0) then if (TimeLeft > 10) then if (bal.lastcheck = 0) then if (NumPlayers-Spectators >= 3) then Balance(true, false);

	// managing the immunity time counters
	if (ImmuneTime > 0) then for i := 1 to 32 do if (pl[i].immune > 0) then dec(pl[i].immune, 1);

	// managing the lock time counters
	if (LockTime > 0) then for i := 1 to 32 do if (pl[i].lock > 0) then dec(pl[i].lock, 1);

	// counting time since last balance...
	if (bal.lastbalance < 32767) then inc(bal.lastbalance, 1);

	// ...and since last check
	if (bal.lastcheck > 0) then dec(bal.lastcheck, 1);

	// re-check which team is smaller (delay after OnLeaveGame)
	if (bal.justLeft) then begin
		bal.justLeft := false;
		bal.smallerTeam := CalcWeakerTeam(false) mod 10;
	end;
end;



// the player desperately seeks the reason for his team losing and uses this trigger
procedure OnPlayerSpeak(id: byte; text: string);
var temp: byte;
begin
	if (GameStyle <> 3) and (GameStyle <> 5) then exit;

	case lowercase(text) of
		'!balance', '!bal', '!teams', 'balance', 'bal', 'teams', 'balance?', 'bal?', 'teams?', '/balance', '/bal', '/teams': begin

			// unless you're a spectator...
			if (GetPlayerStat(id, 'Team') = 5) then begin
				writeconsole(id, 'Spectators can''t use this trigger.', $FFFFAAAA);
				writeln('cube>  ' + idtoname(id) + ' tried to use !balance as a spectator. What a loser.');
				exit;
			end;

			// ...and last balance was at least 15 seconds ago...
			if (bal.lastbalance < 15) then begin
				writeconsole(0, 'Last balance was less than 15 s ago. Please be patient.', ColorRed);
				exit;
			end;

			// ...and there's more than 10 seconds of current map left...
			if (TimeLeft <= 10) then begin
				writeconsole(0, 'The map will change soon. Balance is disabled', ColorRed);
				writeconsole(0, 'to prevent ''wrong map version'' problems.', ColorRed);
				writeln('cube>  Less than 10 seconds left. Balance is blocked.');
				exit;
			end;

			// ...the balance is triggered ("false" means it's on demand)
			Balance(false, false);

		end; // end of !balance
	end;

	if (copy(text, 0, 1) <> '!') then exit; // don't waste cpu if it's not a trigger
	
	case lowercase(text) of
		'!alpha', '!red', '!1', '!a', '!joina', '!join1': begin
			if CheckTeamChange(id, 1) then exit;
			if ((pl[id].lock = 0) or (GetPlayerStat(id, 'Team') = 5)) and (TimeLeft > 2) then begin
				command('/setteam1 ' + inttostr(id));
				if (TriggerLimit > 0) then pl[id].triggers := pl[id].triggers + 1;
			end else begin
				writeconsole(id, 'You were moved due to unbalanced teams.', ColorRed);
				writeconsole(id, 'You can''t change teams for ' + inttostr(LockTime) + ' min after being moved.', ColorRed);
				exit;
			end;
		end; // end of !alpha

		'!bravo', '!blu', '!blue', '!2', '!b', '!joinb', '!join2': begin
			if CheckTeamChange(id, 2) then exit;
			if ((pl[id].lock = 0) or (GetPlayerStat(id, 'Team') = 5)) and (TimeLeft > 2) then begin
				command('/setteam2 ' + inttostr(id));
				if (TriggerLimit > 0) then pl[id].triggers := pl[id].triggers + 1;
			end else begin
				writeconsole(id, 'You were moved due to unbalanced teams.', ColorRed);
				writeconsole(id, 'You can''t change teams for ' + inttostr(LockTime) + ' min after being moved.', ColorRed);
				exit;
			end;
		end; // end of !bravo

		'!spectator', '!spect', '!spec', '!5', '!s', '!join5': begin
			if CheckTeamChange(id, 5) then exit;
			if (TimeLeft > 2) then command('/setteam5 ' + inttostr(id));
			// if (TriggerLimit > 0) then pl[id].triggers := pl[id].triggers + 1;  // uncomment
		end; // end of !spect

		'!join', '!j': begin
			if (GetPlayerStat(id, 'Team') <> 5) then begin
				writeconsole(id, 'This trigger is for spectators only.', ColorRed);
				exit;
			end;
			temp := CalcWeakerTeam(true) mod 10;
			if (temp = 0) then begin
				if (AlphaScore > BravoScore) then temp := 2
				else if (AlphaScore < BravoScore) then temp := 1
				else temp := random(1, 3);
			end;
			command('/setteam' + inttostr(temp) + ' ' + inttostr(id));
		end;

	end; // end of switch
end;



// give the TCP admin an illusion of controlling the server
function OnCommand(id: byte; text: string): boolean;
var i, temp: byte;
begin
	// kicking out all bots
	if (lowercase(text) = '/kickbots') or (lowercase(text) = '/kickbot') then begin
		temp := 0;
		for i := 1 to 32 do if (GetPlayerStat(i, 'Active') = true) and (GetPlayerStat(i, 'Human') = false) then begin
			temp := temp + 1;
			Command('/kick ' + inttostr(i));
		end;
		if (temp = 0) then msg(id, 'There are no bots here!', false) else msg(0, 'Kicked out ' + inttostr(temp) + ' bot(s).', true);
		exit;
	end;

	// kicking out spectators
	if (lowercase(text) = '/kickspect') or (lowercase(text) = '/kickspec') or (lowercase(text) = '/kickspecs') then begin
		temp := 0;
		for i := 1 to 32 do if (GetPlayerStat(i, 'Active') = true) and (GetPlayerStat(i, 'Team') = 5) then begin
			temp := temp + 1;
			Command('/kick ' + inttostr(i));
		end;
		if (temp = 0) then msg(id, 'There are no spectators here!', false) else msg(0, 'Kicked out ' + inttostr(temp) + ' spectator(s).', true);
		exit;
	end;
	
	if (lowercase(text) = '/cubeinfo') then ShowCubeInfo(id);

	// returns hardware ID of specified player ID
	if (lowercase(getpiece(text, ' ', 0)) = '/hwid') then begin 
		if (length(text) > 6) then begin
			try
				temp := strtoint(getpiece(text, ' ', 1));
			except
				temp := nametoid(getpiece(text, ' ', 1));
			end;
			if (GetPlayerStat(temp, 'Active') = true) then
				msg(id, 'ID: ' + inttostr(temp) + '  |  Name: ' + idtoname(temp) + '  |  ' + iif(GetPlayerStat(temp, 'Human') = true, 'HWID: ' + idtohw(temp), 'Bots don''t have HWIDs'), true)
			else
				msg(id, 'There''s no such player here.', false);
		end else msg(id, 'Usage: [ /hwid ID ].' + iif(id = 255, '', ' To get player''s ID, press [F1] and then [/].'), false);
		exit;
	end;
	
	// exclude the specified player from cube's power
	if (lowercase(getpiece(text, ' ', 0)) = '/exclude') then begin
		if (length(text) > 9) then begin
			try
				temp := strtoint(getpiece(text, ' ', 1));
			except
				temp := nametoid(getpiece(text, ' ', 1));
			end;
			if (GetPlayerStat(temp, 'Active') = true) then begin
				if (GetPlayerStat(temp, 'Human') = false) then begin
					msg(id, 'cube does not move bots. No need to exclude them manually.', false);
					exit;
				end;
				pl[temp].excluded := true;
				msg(id, 'Player [ ' + idtoname(temp) + ' ] is now excluded from balance.', true);
			end else 
				msg(id, 'There''s no such player here.', false);
		end else msg(id, 'Usage: [ /exclude ID ] or [ /exclude nickname ].' + iif(id = 255, '', ' To get player''s ID, press [F1] and then [/].'), false);
	end;

	// balancing silently, with fewer restrictions
	if (lowercase(text) = '/bal') then begin
		if (GameStyle <> 3) and (GameStyle <> 5) then begin
			msg(id, 'Not supported GameStyle. cube is disabled.', false);
			exit;
		end;

		// if it was used in-game, don't check again (OnPlayerCommand already checked the balance)
		if (bal.lastcheck > Interval * 60 - 2) then exit;

		// if OnPlayerCommand failed (e.g. an admin is in spec team), force the check
		if (TimeLeft <= 2) then begin
			msg(id, 'Less than 2 seconds left. Balance is blocked.', false);
			exit;
		end;
		if (id <> 255) then writeconsole(id, 'Forcing the balance check. If nothing happens, teams are balanced.', ColorMsg);
		bal.mode := 5;
		Balance(true, false);
		exit;
	end;

	// shuffling the teams
	if (lowercase(text) = '/shuffle') or (lowercase(text) = '/mix') then begin
		Shuffle(id);
		exit;
	end;

	// recompile cube when gamemode is changed
	if (lowercase(getpiece(text, ' ', 0)) = '/gamemode') and (length(text) >= 11) then begin
		result := true; // ignore the built-in command
		case (lowercase(getpiece(text, ' ', 1))) of
			'0', 'd', 'dm', 'death', 'deathmatch'     : temp := 0;
			'1', 'p', 'pm', 'point', 'pointmatch'     : temp := 1;
			'2', 't', 'tm', 'tdm', 'team', 'teammatch': temp := 2;
			'3', 'c', 'ctf', 'cap', 'capture'         : temp := 3;
			'4', 'r', 'rm', 'rambo', 'rambomatch'     : temp := 4;
			'5', 'i', 'inf', 'infiltration'           : temp := 5;
			'6', 'h', 'htf', 'hold', 'holdtheflag'    : temp := 6;
			else begin
				msg(id, 'ERROR: unknown gamemode.', false);
				exit;
			end;
		end;
		if (GameStyle = temp) then begin
			msg(id, 'The gamemode you specified is already on.', false);
			exit;
		end;
		writeconsole(0, 'Changing gamemode. Please rejoin.', ColorGreen);
		command('/gamemode ' + inttostr(temp));
		command('/recompile cube');
		exit;
	end; // end of /gamemode x

	// swapping the teams globally or for two players only
	if (lowercase(getpiece(text, ' ', 0)) = '/swap') then begin

		// we don't want to cause unwanted wrong map version errors
		if (TimeLeft <= 10) then begin
			if (id = 255) or (id = 0) then writeln('cube>  Less than 10 seconds left. Swap is blocked.') else writeconsole(id, 'Less than 10 seconds left. Swap is blocked.', ColorRed);
			exit;
		end;

		// swap all
		if (lowercase(getpiece(text, ' ', 1)) = 'all') then Swap(id, 0, 0)

		// swap two players
		else if (length(text) >= 9) then try
			Swap(id, strtoint(getpiece(text, ' ', 1)), strtoint(getpiece(text, ' ', 2)));
		except
			if (id = 255) or (id = 0) then writeln('cube>  Swap: something went wrong. Check the command and try again.') else writeconsole(id, 'Something went wrong. Check the command and try again.', ColorRed);
		end;

	end; // end of swap

	result := false;
end;



// if someone doesn't want to be seen as a whiny wimp, he can use the silent method (/bal)
function OnPlayerCommand(id: byte; text: string): boolean;
begin
	if (lowercase(text) = '/bal') then if (GetPlayerStat(id, 'Team') <> 5) then if ((GameStyle = 3) or (GameStyle = 5)) then if (bal.lastbalance > 0) then begin
		if (TimeLeft <= 10) then begin
			writeconsole(id, 'Less than 10 seconds left. Balance is disabled.', ColorRed);
			exit;
		end;
		if (bal.lastbalance < 15) then begin
			writeconsole(id, 'Last balance was less than 15 s ago. Please be patient.', ColorRed);
			exit;
		end;
		writeconsole(id, 'Checking balance. If nothing happens, teams are balanced.', ColorMsg);
		bal.mode := 4;
		Balance(true, false);
	end;
	result := false;
end;



// show more spam
procedure OnMapChange(newmap: string);
var i: byte;
begin
	if (GameStyle <> 3) and (GameStyle <> 5) then exit;

	// if you were curious why no spam shows up, this one should make it clear
	if (NumPlayers-Spectators <= 2) then writeln('cube>  Balance won''t work until there are at least 3 players.');

	// show counters
	writeln('cube>  Balances this run: ' + inttostr(bal.numberGlobal) + ' (' + inttostr(bal.numberMap) + ' on prev map)' + iif(bal.numberGlobal>0, ' | Last one was ' + iif(bal.lastbalance=32767, 'over 9 hours ago', inttostr(bal.lastbalance div 60) + ' min ' + inttostr(bal.lastbalance mod 60) + ' s ago'), ''));

	// reset balance counter of current map
	bal.numberMap := 0;

	// reset swaps counter
	bal.swaps := 0;

	// delay balance check a little, so it won't trigger right after mapchange
	if (Interval > 0) then if (bal.lastcheck < 5) then bal.lastcheck := 5;

	// reset trigger counters
	if (TriggerLimit > 0) then for i := 1 to 32 do pl[i].triggers := 0;

	if (KeepTeamScore) then begin
		bal.restoreDelay   := 0;
		bal.tempAlphaScore := 0;
		bal.tempBravoScore := 0;
	end;
end;



procedure OnJoinTeam(id, team: byte);
begin
	if (GameStyle <> 3) and (GameStyle <> 5) then exit;

	// check whether the player is on the exclusion list, but don't check again if he already is and just changes teams
	if (Exclusion > 0) then if (not pl[id].excluded) then pl[id].excluded := CheckExclusion(iif(Exclusion = 1, IDtoName(id), IDtoHW(id)));

	// if someone tries to join the stronger team then move him back (except he's on the exclusion list or was moved by cube)
	if (not pl[id].movedByScript) then if (team <> 5) then if (not pl[id].excluded) then begin
		if (bal.smallerTeam = 0) then begin
			bal.smallerTeam := CalcWeakerTeam(true); // re-check to make sure this player doesn't cause unbalance
			if (bal.smallerTeam > 30) then bal.smallerTeam := 0 else bal.smallerTeam := bal.smallerTeam mod 10;
		end;
		if (bal.smallerTeam > 0) then if (bal.smallerTeam <> team) then if (NumPlayers > 1) then begin
			pl[id].movedByScript := true;
			command('/setteam' + inttostr(bal.smallerTeam) + ' ' + inttostr(id));
			writeconsole(id, iif(pl[id].prevteam=1, 'Bravo', 'Alpha') + ' Team is full.', ColorMsg);
		end;
	end;

	if (KeepTeamScore) then if ((team = 2) and (AlphaPlayers = 0)) or ((team = 1) and (BravoPlayers = 0)) then bal.restoreDelay := iif(team=2, bal.tempAlphaScore, -bal.tempBravoScore);

	// joining spectator team is not harmful, so let the player join
	if (team = 5) or (pl[id].prevteam = team) then begin
		bal.smallerTeam := CalcWeakerTeam(true) mod 10;
		exit;
	end;

	// if someone is trying to fix unbalanced teams, let him change
	if (not pl[id].movedByScript) then if (bal.smallerTeam = team) then pl[id].lock := 0;

	if (pl[id].lock <> 0) then begin
		command('/setteam' + inttostr(pl[id].prevteam) + ' ' + inttostr(id));
		writeconsole(id, 'You were moved due to unbalanced teams.', ColorRed);
		writeconsole(id, 'You can''t change teams for ' + inttostr(LockTime) + ' min after being moved.', ColorRed);
	end else pl[id].prevteam := team;

	pl[id].movedByScript := false;

	bal.smallerTeam := CalcWeakerTeam(true) mod 10;
end;



procedure OnLeaveGame(id, team: byte; kicked: boolean);
begin
	if (GameStyle <> 3) and (GameStyle <> 5) then exit;

	pl[id].excluded := false;

	// optional balance check on player leaving
	if (CheckOnLeave) then bal.mode := 3;

	// optional teamscore restore if this player was the last one in his team
	if (KeepTeamScore) then if ((team = 1) and (AlphaPlayers = 1)) or ((team = 2) and (BravoPlayers = 1)) then bal.restoreDelay := iif(team=1, AlphaScore, -BravoScore);

	// disable the lock timer, so future players won't suffer from what the previous ID holder went through
	pl[id].lock := 0;

	// same for immunity time
	pl[id].immune := 0;

	// aaand trigger usage counter
	pl[id].triggers := 0;

	bal.justLeft := true;
end;



// updating variables. we need ones that won't reset when everyone leaves
procedure OnFlagScore(id, team: byte);
begin
	if (KeepTeamScore) then begin
		bal.tempAlphaScore := AlphaScore;
		bal.tempBravoScore := BravoScore;
	end;
end;
