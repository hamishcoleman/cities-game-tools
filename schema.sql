--
--
--

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

