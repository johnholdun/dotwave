create table albums(
  id varchar(50) primary key not null,
  title text,
  type text,
  release_date varchar(10),
  release_week varchar(10),
  artists varchar(100),
  artist_id varchar(50),
  image_url varchar(100),
  popularity int
);

create index index_release_week on albums(release_week);
