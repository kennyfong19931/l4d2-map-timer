# l4d2-map-timer #
A sourcemod plugin for L4D2, it will record the time used to finish the map.

## Setup ##
- Copy the l4d2_map_timer.smx to \sourcemod\plugins
- Add the following code to \sourcemod\configs\databases.cfg 
```
	"Timer"
	{
		"driver"			"sqlite"
		"host"				"localhost"
		"database"			"timer-db"
		"user"				"root"
		"pass"				""
		//"timeout"			"0"
		//"port"			"0"
	}
```

## Avaliable Commands ##
- !time - show time for current run
- !best - show best record for current map on current difficulty

### Admin only command ###
- !timerenable - Enable map timer
- !timerdisable - Disable map timer
- !timerstart - Start map timer when timer is enabled
- !timerstop - Stop map timer when timer is enabled
- !cleartime - Clear record for current map and difficulty
- !cleartimeall - Clear all timer record is database
