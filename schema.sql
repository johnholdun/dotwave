create table artists(
  id varchar(50) primary key not null,
  name text,
  popularity int,
  latest_release integer default 0
);

create table albums(
  id varchar(50) primary key not null,
  name text,
  type text,
  release_date varchar(10),
  release_week varchar(10),
  popularity int
);

create index index_release_week on albums(release_week);

create table album_artists(
  album_id varchar(50) not null,
  artist_id varchar(50) not null
);

create table users(
  id varchar(50) primary key not null,
  name text,
  fetched_at integer,
  playlist_id varchar(50),
  access_token text
);

create table follows(
  user_id varchar(50) not null,
  artist_id varchar(50) not null
);

create table updates(
  date text,
  step text,
  page int
);
