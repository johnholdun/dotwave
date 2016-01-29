create table artists(
  id varchar(50) primary key not null,
  name text,
  popularity int
);

create table albums(
  id varchar(50) primary key not null,
  name text,
  type text,
  release_date varchar(10),
  popularity int
);

create table album_artists(
  album_id varchar(50) not null,
  artist_id varchar(50) not null
);

create table users(
  id varchar(50) primary key not null,
  fetched_at integer
);

create table follows(
  user_id varchar(50) not null,
  artist_id varchar(50) not null
);
