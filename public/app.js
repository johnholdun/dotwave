addEventListener('load', () => {
  const limit = 24
  const el = document.querySelector('#app')
  let page = 0
  let albums = []

  const fetchAlbums = (timeframe, page, callback) => {
    const request = new XMLHttpRequest()

    request.open(
      'GET',
      `/api/albums?filter[timeframe]=${timeframe}&page[limit]=${limit}&page[offset]=${limit * (page - 1)}`,
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
    fetchAlbums('this-week', ++page, ({ data: newAlbums }) => {
      albums = albums.concat(newAlbums)
      renderAlbums()
    })
  }

  const renderAlbums = () => {
    const body = albums.map((album) => (`
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
    `)).join('\n')

    el.innerHTML = `
      <div class="albums">
        ${body}
      </div>
      <button class="load-more">
        Load more
      </button>
    `

    document
      .querySelector('.load-more')
      .addEventListener('click', (e) => { console.log('load more'); loadMore() })
  }

  loadMore()
})
