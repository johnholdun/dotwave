# Dotwave

[![Code Climate](https://codeclimate.com/github/johnholdun/dotwave/badges/gpa.svg)](https://codeclimate.com/github/johnholdun/dotwave)

## Find new albums on [Spotify][] from artists you follow

If you’re trying to run this locally, you’ll need:

- [A registered Spotify application][Spotify developer]
- A postgres database running somewhere
- A [Dotenv][] file with these values:
  - `COOKIE_SECRET`: A random string
  - `SPOTIFY_CLIENT_ID`: From your Spotify app
  - `SPOTIFY_CLIENT_SECRET`: Also from your Spotify app
  - `DATABASE_URL`: The URL where your Postgres database is running.

`schema.sql` will get your database set up and `update.rb` will populate new
releases.

[Check it out live][live]; pull requests are welcome. Bye!

[Spotify]: https://www.spotify.com/
[Spotify developer]: https://developer.spotify.com/my-applications/
[Dotenv]: https://github.com/bkeepers/dotenv
[live]: http://dotwave.johnholdun.com
