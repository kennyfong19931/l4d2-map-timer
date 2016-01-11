# l4d2-map-timer
A sourcemod plugin for L4D2, it will record the time used to finish the map.

Setup
-----
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
