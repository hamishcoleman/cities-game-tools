--
--
--

--
-- The primary map storage
CREATE TABLE map (
	realm	VARCHAR,		-- allows unknown locations
	x	INTEGER,
	y	INTEGER,
	class	VARCHAR,
	name	VARCHAR,
	visits	INTEGER,
	lastseen	DATE,
	lastvisited	DATE,
	lastchanged	DATE,
	lastchangedby	VARCHAR,
	textnote	VARCHAR,	-- hinting for unknown locations
	PRIMARY KEY (realm,x,y)
);
CREATE INDEX map_realmyx ON map(realm,y,x);

--
-- Each user of this system will appear here
CREATE TABLE user (
	name	VARCHAR,
	session	VARCHAR,		-- The session cookie for this user
	has_intrinsic_location	INTEGER,	-- um?
	lastseen	DATE,
	lastx	INTEGER,
	lasty	INTEGER,
	realm	VARCHAR,		-- current realm for unknown locations
	PRIMARY KEY (name)
);

--
-- Log of the text events that the user has seen
CREATE TABLE userlog (
	entry	INTEGER,
	name	VARCHAR,
	date	DATE,
	gametime	VARCHAR,
	realm	VARCHAR,
	x	INTEGER,
	y	INTEGER,
	text	VARCHAR,
	PRIMARY KEY (entry)
);

--
-- Place to store robot goals
-- goals dont have a realm as at the moment it is too difficult to consider
-- using them on anything other than the primary area
CREATE TABLE robotgoal (
	id	INTEGER,
	name	VARCHAR,	-- robot this applies to
	command	VARCHAR,	-- goal for this entry
	x	INTEGER,
	y	INTEGER,
	PRIMARY KEY(id)
);
