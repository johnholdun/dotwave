addEventListener('load', () => {
  const LIMIT = 24
  const el = document.querySelector('#app')
  const env = {
    template: () => {},
    events: [],
    props: {
      page: 0,
      albums: []
    }
  }

  const setProps = (newProps) => {
    Object.assign(env.props, newProps)
    render()
  }

  const fetchAlbums = (timeframe, page, callback) => {
    const request = new XMLHttpRequest()

    request.open(
      'GET',
      `/api/albums?filter[timeframe]=${timeframe}&page[limit]=${LIMIT}&page[offset]=${LIMIT * (page - 1)}`,
      true
    )

    request.onload = () => {
      if (request.status >= 200 && request.status < 400) {
        callback(JSON.parse(request.responseText))
      }
    }

    request.send()
  }

  const loadMore = () => {
    fetchAlbums('this-week', ++env.props.page, ({ data: newAlbums }) => {
      setProps({ albums: env.props.albums.concat(newAlbums) })
    })
  }

  const withLayout = (body) => (`
    <header>
      <div class="inner">
        <h1 class="branding">
          <a href="/">
            Dotwave
          </a>
        </h1>
      </div>
    </header>
    <div class="inner">
      ${body}
    </div>
    <footer>
      <p class="inner">
        <a href="http://twitter.com/johnholdun">
          John Holdun created Dotwave. It’s a labor of love, and
          <a href="https://github.com/johnholdun/dotwave">
            it’s on GitHub</a>.
      </p>
    </footer>
  `)

  const albumsTemplate = ({ albums }) => (
    withLayout(`
      <div class="albums">
        ${albums.map((album) => (`
          <section class="album">
            <a class="album-link" href="spotify:album:${album.id}" title="Open in Spotify">
              <figure class="album-image">
                <img src="${album.image}" width="320" height="320" alt="${album.artists} - ${album.title}" />
              </figure>
              <h1 class="album-artist">
                ${album.artists}
              </h1>
              <h2 class="album-title">
                ${album.title}
              </h2>
              <p class="album-type">
                ${album.subType}
              </p>
            </a>
           </section>
        `)).join('\n')}
      </div>
      <button class="load-more">
        Load more
      </button>
    `)
  )

  const albumsEvents = [
    {
      event: 'click',
      selector: '.load-more',
      callback: (e) => { loadMore() }
    }
  ]

  const notFoundTemplate = () => (
    withLayout(`
      <h1 class="title">Page not found</h1>

      <div class="ill-tell-you-what">
        <p>
          This is probably my bad, but I just have no idea where you were trying to
          go. Were you looking for a profile? I got rid of those in favor of just new
          releases for everybody. Hope you don’t mind.
        </p>

        <p>
          If this seems like a goof, or you just want to talk, let’s talk! I’m
          <a class="inline" href="https://twitter.com/johnholdun">@johnholdun</a>,
          in case you missed that before.
        </p>
      </div>
    `)
  )

  const render = () => {
    const { template, props, events } = env
    el.innerHTML = template(props)
    events.forEach(({ event, selector, callback }) => {
      el.querySelectorAll(selector).forEach((target) => {
        target.addEventListener(event, callback)
      })
    })
  }

  if (location.pathname === '/') {
    env.template = albumsTemplate
    env.events = albumsEvents
    loadMore()
  } else {
    env.template = notFoundTemplate
    env.events = []
  }

  render()
})
