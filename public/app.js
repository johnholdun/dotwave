addEventListener('load', () => {
  const LIMIT = 24
  const el = document.querySelector('#app')
  const env = {
    template: () => {},
    events: [],
    props: {
      page: 1,
      albums: [],
      settings: {}
    }
  }

  const setProps = (newProps) => {
    Object.assign(env.props, newProps)
    render()
  }

  const fetchAlbums = ({ page = 1, timeframe = 'this-week', subType = '' }, callback) => {
    const request = new XMLHttpRequest()

    request.open(
      'GET',
      `/api/albums?filter[timeframe]=${timeframe}&filter[subType]=${subType}&page[limit]=${LIMIT}&page[offset]=${LIMIT * (page - 1)}`,
      true
    )

    request.onload = () => {
      if (request.status >= 200 && request.status < 400) {
        callback(JSON.parse(request.responseText))
      }
    }

    request.send()
  }

  const loadAlbums = () => {
    const { page, albums, settings } = env.props
    const { timeframe, subType } = settings
    fetchAlbums({ page, timeframe, subType }, ({ data: newAlbums }) => {
      setProps({ page: page + 1, albums: env.props.albums.concat(newAlbums) })
    })
  }

  const navigate = (path) => {
    if (path.indexOf('/') !== 0) {
      window.location = path
      return
    }
    history.pushState(null, {}, path)
    route(path)
  }

  const inlineLoad = (event, newTarget = null) => {
    const target = newTarget || event.target
    if (target.nodeName !== 'A') {
      return inlineLoad(event, target.parentElement)
    }
    if (target.getAttribute('target') === '_blank') {
      return true
    }
    event.preventDefault()
    navigate(target.getAttribute('href'))
  }

  const saveSettings = (event) => {
    const form = event.target
    event.preventDefault()

    const settings = {
      subType: form.querySelector('[name="subType"]').value,
      timeframe: form.querySelector('[name="timeframe"]').value,
      service: form.querySelector('[name="service"]').value
    }

    if (typeof window.localStorage === 'object' && typeof localStorage.setItem === 'function') {
      Object.keys(settings).forEach((setting) => {
        localStorage.setItem(setting, settings[setting])
      })
    }

    setProps({ albums: [], page: 1 })
    navigate('/')
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
    ${body}
  `)

  const LABELS = {
    subType: {
      all: 'releases',
      album: 'albums',
      single: 'singles'
    },
    timeframe: {
      'this-week': 'this week',
      'last-week': 'last week',
      'two-weeks-ago': 'two weeks ago'
    },
    service: {
      spotify: 'Spotify',
      youtube: 'YouTube',
      itunes: 'iTunes',
      google: 'Google',
      soundcloud: 'SoundCloud',
      amazon: 'Amazon',
      fanburst: 'Fanburst',
      napster: 'Napster',
      tidal: 'Tidal',
      deezer: 'Deezer'
    }
  }

  const loadSettings = () => {
    const settings = {}

    Object.keys(LABELS).forEach((setting) => {
      let value = localStorage.getItem(setting)
      if (Object.keys(LABELS[setting]).indexOf(value) === -1) {
        value = Object.keys(LABELS[setting])[0]
      }
      settings[setting] = value
    })

    setProps({ settings })
  }

  const albumsTemplate = ({ albums, settings: { subType, timeframe, service } }) => {
    return withLayout(`
      <div class="status">
        <p class="inner">
          All new
          ${LABELS.subType[subType]}
          ${LABELS.timeframe[timeframe]},
          linked to ${LABELS.service[service]}.
          <a class="inline" href="/settings">
            Settings</a>
          <a class="inline" href="/about">
            About</a>
        </p>
      </div>
      <div class="inner">
        <div class="albums">
          ${albums.map((album) => (`
            <section class="album">
              <a
                class="album-link"
                href="https://song.link/redirect?url=${encodeURIComponent(`https://open.spotify.com/album/${album.id}`)}&to=${service}"
                target="_blank"
                title="Open in ${LABELS.service[service]}"
              >
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
      </div>
    `)
  }

  const inlineLinkEvent = {
    event: 'click',
    selector: 'a',
    callback: inlineLoad
  }

  const albumsEvents = [
    {
      event: 'click',
      selector: '.load-more',
      callback: loadAlbums
    },
    inlineLinkEvent
  ]

  const notFoundTemplate = () => (
    withLayout(`
      <div class="baby">
        <h1 class="title">Page not found</h1>
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

  const aboutTemplate = () => (
    withLayout(`
      <div class="baby">
        <h1 class="title">About</h1>
        <p>
          Dotwave is a comprehensive list of new music releases every week. It’s a love
          letter to the late Rdio written by
          <a class="inline" href="http://twitter.com/johnholdun">
            John Holdun</a>,
          and its source is on
          <a class="inline" href="https://github.com/johnholdun/dotwave">
            GitHub</a>
          if you’re curious.
        </p>
        <p>
          Release data comes from
          <a href="https://developer.spotify.com/web-api/">
            the Spotify API</a>;
          streaming service links are powered by
          the incomparable
          <a href="https://song.link/">
            Songlink</a>.
        </p>
      </div>
    `)
  )

  const settingsTemplate = ({ settings: { subType, timeframe, service }}) => (
    withLayout(`
      <div class="baby">
        <h1 class="title">
          Settings
        </h1>
        <form class="settings-form">
          <div class="input-wrapper">
            <label for="subType">
              Release type
            </label>
            <select id="subType" name="subType">
              <option ${subType === 'all' ? 'selected' : ''} value="all">
                All releases
              </option>
              <option ${subType === 'album' ? 'selected' : ''} value="album">
                Albums only
              </option>
              <option ${subType === 'single' ? 'selected' : ''} value="single">
                Singles only
              </option>
            </select>
          </div>
          <div class="input-wrapper">
            <label for="timeframe">
              Timeframe
            </label>
            <select id="timeframe" name="timeframe">
              <option ${timeframe === 'this-week' ? 'selected' : ''} value="this-week">
                This week
              </option>
              <option ${timeframe === 'last-week' ? 'selected' : ''} value="last-week">
                Last week
              </option>
              <option ${timeframe === 'two-weeks-ago' ? 'selected' : ''} value="two-weeks-ago">
                Two weeks ago
              </option>
            </select>
          </div>
          <div class="input-wrapper">
            <label for="service">
              Links open in
            </label>
            <select id="service" name="service">
              <option ${service === 'spotify' ? 'selected' : ''} value="spotify">
                Spotify
              </option>
              <option ${service === 'youtube' ? 'selected' : ''} value="youtube">
                YouTube
              </option>
              <option ${service === 'itunes' ? 'selected' : ''} value="itunes">
                iTunes
              </option>
              <option ${service === 'google' ? 'selected' : ''} value="google">
                Google
              </option>
              <option ${service === 'soundcloud' ? 'selected' : ''} value="soundcloud">
                SoundCloud
              </option>
              <option ${service === 'amazon' ? 'selected' : ''} value="amazon">
                Amazon
              </option>
              <option ${service === 'fanburst' ? 'selected' : ''} value="fanburst">
                Fanburst
              </option>
              <option ${service === 'napster' ? 'selected' : ''} value="napster">
                Napster
              </option>
              <option ${service === 'tidal' ? 'selected' : ''} value="tidal">
                Tidal
              </option>
              <option ${service === 'deezer' ? 'selected' : ''} value="deezer">
                Deezer
              </option>
            </select>
          </div>
          <div class="input-wrapper">
            <button class="btn">
              Save settings
            </button>
          </div>
        </form>
      </div>
    `)
  )

  const settingsEvents = [
    {
      event: 'submit',
      selector: 'form',
      callback: saveSettings
    },
    inlineLinkEvent
  ]

  const render = () => {
    const { template, props, events } = env
    el.innerHTML = template(props)
    events.forEach(({ event, selector, callback }) => {
      el.querySelectorAll(selector).forEach((target) => {
        target.addEventListener(event, callback)
      })
    })
  }

  const route = (path) => {
    if (path === '/') {
      loadSettings()
      loadAlbums()
      env.template = albumsTemplate
      env.events = albumsEvents
    } else if (path === '/about') {
      env.template = aboutTemplate
    } else if (path === '/settings') {
      loadSettings()
      env.template = settingsTemplate
      env.events = settingsEvents
    } else {
      env.template = notFoundTemplate
      env.events = [inlineLinkEvent]
    }

    render()
  }

  route(location.pathname)

  addEventListener('popstate', () => { route(location.pathname) })
})
