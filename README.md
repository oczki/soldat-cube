#cube - CTF/INF Ultimate Balancer

**Warning**: To prevent two scripts overlapping each other, please **disable all other team-related scripts before installing cube**.

##What it does

cube is a team balancer intended for use on public Soldat servers, for Capture The Flag and Infiltration gamemodes. It is more complex than most other balancers you can find, and balances teams in a seemingly more natural way. It works best on servers with 6 or more players, but it won't cause any problems with fewer people.

**Features list:**
- uses seven methods of choosing the player to be moved, including "least caps", "worst k/d ratio", and more
- avoids flag carriers not to ruin the game
- automatically puts new players into weaker team
- gives some "immunity time" to moved players, so they won't be moved again too soon
- disables itself in the last 10 seconds of a map (to avoid "wrong map version" problems)
- supports some well-known triggers such as !alpha, !spec (+aliases), and, of course, !balance (!bal, teams, ...)
- "team-changing" triggers can be disabled or limited to _X_ uses per player per map
- locks the recenly moved players in their new teams, so they won't fight the system and go back
- in case of a big unbalance, admins can shuffle the teams using one simple command (/mix)
- admins can swap the teams of two or all players at once
- you can exclude some people from the balance by putting their nicknames or HWIDs on the exclusion list
- can keep teams' scores even if all players left (optional)

**Admin-only commands:**
- **/swap _ID1_ _ID2_** - swap teams of two players
- **/swap all** - swap everyone
- **/shuffle**, **/mix** - shuffle teams by sorting players by kills and putting them to alternating teams. Useful when teams are so uneven a simple balance wouldn't fix the situation.
- **/kickbots** - kicks all bots
- **/kickspec** - kicks all spectators
- **/gamemode _X_** - simplified this command to use 'dm', 'ctf', etc. instead of numbers that are hard to remember
- **/hwid _ID_** - get player's hardware ID
- **/exclude _ID_** - exclude specified player from balance
- **/cubeinfo** - shows information about current cube's config

**Some triggers for regular players:**
- **!alpha**, **!1**, **!red**, ... - join Alpha Team
- **!bravo**, **!2**, **!blue**, ... - join Bravo Team
- **!spec**, **!5**, **!s**, ...  - join Spectator Team
- **!join**, **!j** - join the weaker team (spectators only)
- **!balance**, **teams?**, **bal**, ... - check balance
- **/bal** (command, not chat) - check balance silently (other players won't see who triggered it)

There's a lot of safety checks and anti-abuse limiters, but they're not completely un-avoidable. For example, one can reset their limiters by rejoining the server - I keep it that way because limiting players' freedom that far would irritate them. It'd be rather easy to fix (using HWIDs), but, you know... People like to think that they've cheated the system.

##Nickname / hardware ID exclusion

You can tell cube to ignore users whose nickname or HWID matches one on the exclusion list. Those users won't be affected
	by balance or shuffle.

	Additionally, excluded players will be able to join any team and use team-related triggers without restrictions.

	Entries should be separated with a semicolon followed with space. So 'Major; Soldier; Steins;Gate' will affect three players:
	Major, Soldier and Steins;Gate. Also, don't forget to put a semicolon at the end of the line ( Nicks = 'asdsadas'; ).

	You can check any player's HWID using the admin-only command **/hwid _ID_**.

	You can also exclude players while in game, using **/exclude _ID_**. It will work until they leave the server.

##Changelog (pre-GitHub)

- **0.1** (05.06.2011)
  - initial release full of bugs

- **0.2** (??.06.2011)
  - **modified:** fixed a horrible bug that caused even bigger unbalance
  - **modified:** changed the calculations a bit (added abs2)
  - **modified:** code is a little more readable now

- **0.2b** (??.06.2011)
  - **added:** a few messages (writeln, writeconsole)
  - **added:** balance check on player leaving

- **0.2c** (??.06.2011)
  - **added:** spectators can't use the trigger now (kinda useless if the balance is automatic, as they can just wait for it to happen)
  - **modified:** now the script won't check the balance if there are less than three players

- **0.3** (??.06.2011)
  - **added:** delay at onleavegame (without the delay the player who just left was still virtually present)
  - **added:** if everyone has immune time > 0 then the one with the least time will be chosen (very unlikely, but it can happen if there are only a few players)
  - **modified:** balance check on leave is now optional and disabled by default

- **0.3b** (??.06.2011)
  - **added:** silent trigger (/bal), works for remote admins too
  - **added:** a few more messages for each type of trigger
  - **modified:** new default values for Weight and MinDiff - 4/5 instead of 5/6

- **0.3c** (??.06.2011)
  - **added:** counters - number of balances since recompile (global and last-map-only), time since last balance
  - **modified:** immune[id] was a byte. what the hell
  - **modified:** code is a lot more readable now

- **0.4** (??.06.2011)
  - **added:** balancer will try not to move the flagger. being a flagger doesn't matter in the alternative method though
  - **added:** lock the moved player to a new team, so he can't change it right after balance
  - **added:** swapping teams of two players (/swap id1 id2) or everyone (/swap all)
  - **added:** !alpha, !bravo and !spec triggers and their aliases
  - **modified:** shifted to types, more intuitive variables' names, more code cleaning

- **0.4b** (09.06.2011)
  - **added:** special rule for 3v1 situations. optional, enabled by default
  - **modified:** changed a few variable types to fix out of range errors

- **0.5** (10.06.2011)
  - **added:** three new methods of choosing the player to be moved (fewest kills, fewest caps, worst k/d ratio). default: k/d
  - **modified:** 3v1 special rule doesn't count spectators as players now

- **0.5b** (12.06.2011)
  - **added:** fifth method - choosing player with no caps and worst k/d ratio. if it fails - fewest caps; it's the default method now
  - **modified:** balance won't trigger in the last 10 seconds of a map to avoid wrong map version problems
  - **modified:** the !alpha-like triggers won't work in the last two seconds of a map

- **0.6** (12.06.2011)
  - **added:** optional method of dealing with 5v5 situations: swap best and weakest players' teams instead of moving one (and thus causing 4v6) (idea by Wookash)
  - **added:** another method - fewest kills and no caps (new default)
  - **modified:** swap is now a separate procedure - swap(caller, id1, id2);

- **0.7** (15.06.2011)
  - **added:** detect Infiltration / Capture The Flag and use respective Weight and MinDiff
  - **added:** 'teams?', 'balance?' and 'bal?' triggers
  - **modified:** can't swap spectators now
  - **modified:** "Teams balanced." won't show up after automatic swap anymore
  - **modified:** fixed bug with not balancing 4v6 when one team is stronger and SwapOnUnbal is true
  - **modified:** now balance autotriggers if (Interval*n) minutes passed since last balance (used to trigger every <Interval> minutes, no matter if other (requested) balances occured or not)
  - **modified:** if the last balance was swap then multiply the interval by 1.5 (to avoid another swap too soon after last one)
  - **modified:** player can't use !teams until 15 seconds since last successful balance pass

- **0.8** (19.06.2011)
  - **added:** /mix (or /shuffle) admin-only command to shuffle the teams
  - **added:** cube recompiles itself after /gamemode x
  - **added:** aliases for /gamemode x. no need to remember their numbers anymore
  - **added:** info about number of players and scores, shown with every balance (admin console only)
  - **added:** !a, !b, !s triggers (changing team)
  - **modified:** don't balance when one team has won the round and map hasn't changed yet (in addition to timeleft = 0)
  - **modified:** final fix for 4v6, no weird balance should happen anymore (on default config at least)
  - **removed:** IncludeFlags is hardcoded now (not optional anymore). if this was set to false, cube was no different from any other balancer. most of cube's code used team scores with no regard to this option anyway.

- **0.9** (24.06.2011)
  - **added:** limiting number of swaps per map (default: 2). If it's reached, teams are considered balanced (in situations where swap would normally occur, of course)
  - **modified:** less /setteam-ing for shuffle - don't move player if he's already in his 'destined team'
  - **modified:** shuffle locks players in teams for LockTime*60 seconds
  - **modified:** little changes in messages
  - **modified:** player choosing method defaults to 1 again (random player). it's more fun this way

- **1.0** (07.09.2011)
  - **added:** nick exclusion - a list of players (nicks) who won't be moved during balance
  - **added:** workaround for soldatserver 2.7.0. older cube versions won't work properly on the latest server version (1.0 works on all servers)
  - **added:** seventh method - choosing random player among those who haven't captured the flag even once (in other words - it's the first method (random player), but with excluding those who capped)
  - **modified:** default method changed again - now it's the new, seventh one
  - **modified:** you can't re-join a team using !1-like triggers if you're already in that team (idea by Vampir)
  - **modified:** shortened a few bits

- **1.1** (08.09.2011)
  - **added:** HWID exclusion - same as nick exclusion, but with hardware IDs. cube v1.1+ won't work on older soldatserver versions (< 2.7.0)
  - **added:** '/hwid <ID>' admin command to check one's hardware ID (example: '/hwid 4' returns HWID of player with ID 4)
  - **added:** 'TriggerLimit' to disable (-1) or limit (>0) the built-in team change triggers (!alpha, !2, etc.). (doesn't limit !5 / !spec - if you want to limit it too, delete "and (team < 5)" and uncomment line that contains "uncomment")
  - **modified:** changed the type of some variables to reduce memory usage and deleted useless checks

- **1.1b** (10.10.2011)
  - **modified:** some remote admin commands didn't return any text to their console and caused access violations on 2.7.0
  - **modified:** made the .pas file smaller by about 20% (changelog in separate file, tabs instead of spaces)
  - **modified:** every cube's message has a prefix now (in remote admin console)
  - **modified:** a few other barely visible changes

- **1.2** (28.10.2011)
  - **added:** '/kickbots' and '/kickspec' commands to kick all bots/spectators from the server
  - **added:** option to keep team's score even if everyone from that team left (Soldat itself clears the score if a team is empty). Said option (named KeepTeamScore) is disabled by default.
  - **added:** some checks for incorrect values of Weight and MinDiff
  - **added:** more '!balance' aliases
  - **modified:** fixed unnatural balancing when Weight and MinDiff are small and there are few players (e.g. 3v0, 0:5, W=2, MD=2 - cube thought it was balanced) (reported by Vampir)
  - **modified:** in-game admins can now use '/bal' command even if they're in the spectator team
  - **modified:** enriched readme.txt and divided config in cube.pas into categories to make it neater

- **1.2b** (05.11.2011)
  - **modified:** fixed double writeconsole message when an admin uses /bal
  - **modified:** /bal now properly returns error messages when used by remote admin
  - **modified:** automatic balance won't trigger right after map change now (at least 5 seconds must pass first)

- **1.5** (25.11.2011)
  - **removed:** hardcoded four config values: Balance3v1, SwapOnUnbal, Weight and MinDiff. cube started to grow dangerously big while struggling with compatibility issues. Some new features wouldn't work correctly on non-default config anyway.
  - **added:** !join trigger for spectators - joins weaker team (one with fewer players and points)
  - **added:** new players are now forced to join weaker team (except they're on the exclusion list)
  - **added:** iteration limiter to only balance as many times as it's needed
  - **added:** a few more aliases to already existing triggers
  - **modified:** balance procedure rewritten and simplified a bit; main stress moved to another function (CalcWeakerTeam)
  - **modified:** recently moved (locked) players get unlocked if they're trying to join weaker team (this one was annoying: you couldn't fix unbalanced teams yourself, because cube moved you back)
  - **modified:** players that are on the exclusion list have more rights now: they can switch team and use team-change triggers without limits
  - **modified:** swap doesn't touch players that have capped the flag now (except everyone did - in such cases it chooses one who capped fewest times)
  - **modified:** players' lock timers are reset before manual /shuffle or /mix
  - **modified:** AppOnIdle is now compatible with Falcon's modified server binary (60 Hz)
  - **modified:** improved performance a bit and fixed some omissions that could cause bugs

##"Thank you"s

- **Bonecrusher** - for the initial idea - "hey, could you make a balancer that would check team scores too?", for giving me admin powers on his very popular public servers and letting me test cube on them  
- **Vampir** - for pointing out bugs and giving great suggestions via e-mail  
- **Furai** - for a brilliant idea of dealing with teams that are equal in number, but unbalanced in power (i.e., swapping)  
- **rr-** - for some things regarding optimizing and debugging, constructive criticism, etc.  

Also, big thanks to all regular players who are unaware that they helped me enhance cube.

cube uses *Explode* function made by **CurryWurst** and **DorkeyDear** (used in exclusion lists).

**Thread on soldatforums**:  http://forums.soldat.pl/index.php?topic=40163.0
