Portal = function(config) {
  this.mergeD(config)
  var t = this
  postQuery(this.tileInfoPrefix, '',
    function(res){
      var obj = res.responseText.parseRawJSON()
      t.mergeD(obj)
      t.init()
    },
    this.queryErrorHandler('Loading portal info')
  )
}


Portal.prototype = {
  title : 'zogen',
  language: guessLanguage(),
  defaultLanguage : 'en-US',
  
  x : -20,
  y : -60,
  zoom : 2,
  maxZoom : 7,
  tileSize : 256,

  loadLinks : true,
  createLinks : true,

  tilePrefix : '/tile/',
  tileSuffix : '',

  tileInfoPrefix : '/tile_info/',
  tileInfoSuffix : '',

  itemPrefix : '/items/',
  itemSuffix : '',
  itemJSONSuffix : '/json',
  editSuffix : '/edit',

  userPrefix : '/users/',

  filePrefix : '/files/',
  fileSuffix : '',
  
  query : '?' + window.location.search.substring(1),

  translations : {
    'en-US' : {
      DateObject : function(d){ return d.toLocaleString(this.language) },
      by : 'by',
      author : 'author',
      date_taken : 'date taken',
      camera : 'camera',
      manufacturer : 'manufacturer',
      software : 'software',
      edit : 'edit',
      filename : 'filename',
      source : 'source',
      referrer : 'referrer',
      sets : 'sets',
      groups : 'groups',
      tags : 'content',
      mimetype : 'file type',
      deleted : 'deleted',
      title : 'title',
      publisher : 'publisher',
      publish_time : 'publish time',
      description : 'description',
      location : 'location',
      genre : 'genre',
      album : 'album',
      tracknum : 'track number',
      album_art : 'album art',
      cancel : 'cancel',
      done : 'save',
      edit_failed : 'Saving edits failed',
      loading_tile_info : 'Loading tile info failed',
      loading_item_info : 'Loading item info failed',
      byte_abbr : 'B',
      click_to_edit : 'Click to edit'
    },
    'en-GB' : {},
    'fi-FI' : {
      by : '-',
      author : 'tekijä',
      date_taken : 'otettu',
      camera : 'kamera',
      manufacturer : 'valmistaja',
      software : 'ohjelmisto',
      edit : 'muokkaa',
      filename : 'tiedostonimi',
      source : 'lähde',
      referrer : 'viittaaja',
      sets : 'joukot',
      groups : 'ryhmät',
      tags : 'tagit',
      mimetype : 'tiedostomuoto',
      deleted : 'poistettu',
      title : 'otsikko',
      publisher : 'julkaisija',
      publish_time : 'julkaisuaika',
      description : 'kuvaus',
      location : 'sijainti',
      genre : 'tyylilaji',
      album : 'albumi',
      tracknum : 'raidan numero',
      album_art : 'kansitaide',
      cancel : 'peruuta',
      done : 'tallenna',
      edit_failed : 'Muutosten tallentaminen epäonnistui',
      loading_tile_info : 'Tiilen tietojen lataaminen epäonnistui',
      loading_item_info : 'Kohteen tietojen lataaminen epäonnistui',
      byte_abbr : 'T',
      click_to_edit : 'Napsauta muokataksesi'
    }
  },

  translate : function(key, string) {
    var tr = (this.translations[this.language] || {})[key]
    if (!tr) tr = this.translations[this.defaultLanguage][key]
    if (!tr) return false
    if (!string) string = ''
    if (typeof tr == 'string')
      return tr + string
    else
      return tr(string)
  },

  init : function() {
    this.tiles = {tilesInCache : 0}
    this.initView()
    this.container.appendChild(this.view)
    this.itemCoords = {}
    this.initItemLink()
    this.updateTiles()
    this.view.addEventListener("mousedown", this.bind('mousedownHandler'), false)
    this.view.addEventListener("DOMMouseScroll", this.bind('DOMMouseScrollHandler'), false)
    this.view.addEventListener("keypress", this.bind('keyHandler'), false)
    window.addEventListener("mousemove", this.bind('mousemoveHandler'), false)
    window.addEventListener("mouseup", this.bind('mouseupHandler'), false)
    window.addEventListener("blur", this.bind('mouseupHandler'), false)
    this.infoLayer = Elem('div', null, null, 'infoLayer')
    this.view.appendChild(this.infoLayer)
  },

  initView : function(){
    var v = Elem('div')
    v.style.position = 'absolute'
    v.left = -this.x
    v.top = -this.y
    v.style.left = v.left + 'px'
    v.style.top = v.top + 'px'
    v.cX = this.container.offsetWidth/2
    v.cY = this.container.offsetHeight/2
    var t = Elem('h2', this.title)
    t.style.mergeD({
      position: 'absolute',
      fontSize: '20px',
      left: '0px', top: '-40px',
      zIndex: 4, color: 'white'
    })
    this.titleElem = t
    v.appendChild(t)
    this.view = v
  },

  initItemLink : function(i) {
    var ti = this.itemLink = Elem('a', null, null, 'itemLink')
    ti.addEventListener("click", this.linkClick(), false)
    ti.addEventListener("mousedown", this.linkDown, false)
    ti.style.zIndex = 2
    this.view.appendChild(this.itemLink)
  },

  updateTiles : function(zoomed){
    var t = this
    var v = this.view
    var c = this.container
    var sl = -(v.left - (v.left % t.tileSize))
    var st = -(v.top - (v.top % t.tileSize))
    this.x = -v.left
    this.y = -v.top
    this.currentLocation.href = "#x" + this.x + "y" + this.y + "z" + this.zoom
    var tile_coords = []
    var visible_tiles = 0
    var midX = c.offsetWidth/2 - v.left - t.tileSize / 2
    var midY = c.offsetHeight/2 - v.top - t.tileSize / 2
    this.titleElem.style.fontSize = parseInt(10 * Math.pow(2, this.zoom)) + 'px'
    this.titleElem.style.top = parseInt(-20 * Math.pow(2, this.zoom)) + 'px'
    Rg(-1, c.offsetWidth/t.tileSize+1).each(function(i){
      var x = i*t.tileSize+sl
      var dx = Math.abs(x - midX)
      Rg(-1, c.offsetHeight/t.tileSize+1).each(function(j){
        var y = j*t.tileSize+st
        var dy = Math.abs(y - midY)
        var d = Math.sqrt(dx*dx + dy*dy)
        t.showTile(x,y, d)
        visible_tiles++
      })
    })
    if (t.tiles.tilesInCache > visible_tiles*2 || zoomed) {
      t.removeTiles(sl - t.tileSize,
                    st - t.tileSize,
                    sl + c.offsetWidth + t.tileSize,
                    st + c.offsetHeight + t.tileSize)
    }
  },

  removeTiles : function(left, top, right, bottom){
    for (var i in this.tiles) {
      if (i.match(/:/)) {
        var xy = i.split(":")
        var x = parseInt(xy[0])
        var y = parseInt(xy[1])
        var zoom = parseInt(xy[2])
        if (zoom != this.zoom ||
            x < left || x > right || y < top || y > bottom)
        {
          if (this.tiles[i].timeout) clearTimeout(this.tiles[i].timeout)
          try{ this.view.removeChild(this.tiles[i].parentNode) } catch(e) {}
          this.tiles[i].src = null
          this.tiles.tilesInCache--
          delete this.tiles[i]
        }
      }
    }
  },

  showTile : function(x, y, priority){
    if (!this.tiles[x+':'+y+':'+this.zoom]) {
      var tile = Elem('img',null,null,'tile')
      tile.style.position = 'absolute'
      tile.style.left = '0px'
      tile.style.top = '0px'
      this.tiles[x+':'+y+':'+this.zoom] = tile
      this.tiles.tilesInCache++
      var t = this
      tile.timeout = setTimeout(function(){
        tile.style.visibility = 'hidden'
        var tileQuery = 'x'+ x +'y'+ y +'z'+ t.zoom +
                    'w'+ t.tileSize +'h'+ t.tileSize
        tile.addEventListener("load",
          function(){
            tile.style.visibility = 'visible'
            if (!t.loadLinks) return
            postQuery(t.tileInfoPrefix + tileQuery + t.tileInfoSuffix, t.query,
              function(res){ t.createInfoEntry(res, x, y) },
              t.queryErrorHandler(t.translate('loading_tile_info'))
            )
          },
          false
        )
        var tile_cont = Elem('div')
        tile_cont.style.position = 'absolute'
        tile_cont.style.left = x+'px'
        tile_cont.style.top = y+'px'
        tile_cont.appendChild(tile)
        t.view.appendChild(tile_cont)
        tile.width = t.tileSize
        tile.height = t.tileSize
        tile.src = t.tilePrefix + tileQuery + t.tileInfoSuffix + t.query
        tile.timeout = false
      }, priority/40)
    }
  },

  // Inserts the info into infoEntries for the tile
  createInfoEntry : function(res, tx, ty){
    if (!this.createLinks) return false
    var infos = res.responseText.parseRawJSON()
    var t = this
    infos.each(function(i){
      i.x += tx
      i.y += ty
      i.w = i.h = i.sz
      // See if all these necessary ?
      t.insertInfoEntry(i, i.x, i.y)
      t.insertInfoEntry(i, i.x+i.w, i.y)
      t.insertInfoEntry(i, i.x, i.y+i.h)
      t.insertInfoEntry(i, i.x+i.w, i.y+i.h)
    })
  },

  // Pushes i to the info entry array at x,y
  insertInfoEntry : function(i, x, y) {
    var ie = this.coordsInfoEntry(x, y, true)
    if (!ie.includes(i)) ie.push(i)
  },

  // Gets the info entry array at x,y.
  // If autovivify is true, creates one if one doesn't exist.
  // Otherwise returns false if there's no info entry array.
  coordsInfoEntry : function(x, y, autovivify) {
    var gx = Math.floor(x / this.tileSize)
    var gy = Math.floor(y / this.tileSize)
    var row = this.itemCoords[gx]
    if (!row) {
      if (!autovivify) {
        return false
      } else {
        row = this.itemCoords[gx] = {}
      }
    }
    var ie = row[gy]
    if (!ie) {
      if (!autovivify) {
        return false
      } else {
        ie = row[gy] = []
      }
    }
    return ie
  },

  // Finds the first matching info entry at x,y.
  findInfoEntry : function(x, y) {
    var ie = this.coordsInfoEntry(x,y)
    return ie.findAll(function(i){
      return i.x <= x && i.x+i.w > x && i.y <= y && i.y+i.h > y
    })[0]
  },

  // Move item link to i's position and set it to point to i.
  updateItemLink : function(i) {
    var ti = this.itemLink
    ti.style.left = i.x + 'px'
    ti.style.top = i.y + 'px'
    ti.style.width = i.w + 'px'
    ti.style.height = i.h + 'px'
//     ti.style.border = '1px solid yellow'
    ti.href = this.filePrefix + i.info.path + this.fileSuffix
    ti.infoObj = i
  },

  // Creates an info overlay from the infoObj and attaches it to the container.
  createTileOverlay : function(container, infoObj) {
    var x = infoObj.x
    var y = infoObj.y
    var w = infoObj.w
    var h = infoObj.h
    var info = Elem('div', null, null, 'info',
      { position: 'absolute', left: x + 'px', top: y + 'px' }
    )
    var emblems = [
      ['e', 'FUNNY HATS!! - £4.99 from eBay.co.uk'],
      ['euro', 'Rocket Ship - 8.49€ from Amazon.de'],
      ['location', 'Bavaria, Germania']]
    emblems = []
    emblems.each(function(n){
      ti.emblems.push(n)
      var el = Elem('img')
      el.src = '/zogen/' + n[0] + '_16.png'
      el.style.display = 'block'
      el.style.margin = '1px'
      info.appendChild(el)
    })
    var info_text = Elem('div', null, null, 'infoText')
    info_text.style.mergeD({
      position: 'absolute',
      left: x + 'px',
      top: (y + h - 16) + 'px',
      width: w,
      height: '16px'
    })
    info_text.innerHTML = t.parseItemTitle('span', infoObj.info.path, true, false)
    container.appendChild(info)
    container.appendChild(info_text)
  },

  // Note where mouse button went down to avoid misclicks when dragging.
  linkDown : function(e) {
    this.downX = e.clientX
    this.downY = e.clientY
  },

  // When clicking a link with LMB and no modifier, toggle its info floater.
  linkClick : function() {
    var t = this
    return function(e) {
      if (e.button == 0 && !(e.ctrlKey || e.altKey || e.shiftKey)) {
        e.preventDefault()
        if ((Math.abs(e.clientX - this.downX) > 3) &&
            (Math.abs(e.clientY - this.downY) > 3)) {
          return false
        }
        if (!t.infoLayerVisible() || t.infoTargetChanged()) {
          var c = t.viewCoords(e)
          t.infoTarget = t.itemLink.infoObj
          postQuery(t.itemPrefix+t.itemLink.infoObj.info.path+t.itemJSONSuffix, '',
            function(res) {
              var fullInfo = res.responseText.parseRawJSON()
              t.showInfoLayer(c.x, c.y, fullInfo)
            },
            t.queryErrorHandler(t.translate('loading_item_info'))
          )
        } else {
          t.hideInfoLayer()
        }
        return false
      }
    }
  },

  infoLayerVisible : function() {
    return(this.infoLayer.style.display != 'none')
  },

  infoTargetChanged : function() {
    return(this.infoTarget != this.itemLink.infoObj)
  },

  // Set this.infoLayer according to info, position it at (x,y) and
  // make it visible.
  //
  showInfoLayer : function(x,y,info) {
    this.infoLayerData = info
    var infoLayer = this.infoLayer
    this.infoLayer.innerHTML = ''
    this.infoLayer.appendChild(this.parseItemTitle('h3', info, true, true))
    this.infoLayer.appendChild(this.parseUserInfo(info))
    var i = Elem('img')
    i.width = info.metadata.width
    i.height = info.metadata.height
    i.src = this.filePrefix + info.path + this.fileSuffix
    this.infoLayer.appendChild(i)
    this.infoLayer.appendChild(this.parseItemMetadata(info))
//     info.emblems.each(function(n){
//       var d = Elem('div')
//       var a = Elem('a', n[1], null, 'infoLink')
//       a.href = n[1]
//       var el = Elem('img')
//       el.style.display = 'inline'
//       el.src = '/zogen/' + n[0] + '_32.png'
//       d.appendChild(el)
//       d.appendChild(a)
//       infoLayer.appendChild(d)
//     })
    this.infoLayer.style.left = x + 'px'
    this.infoLayer.style.top = y + 'px'
    this.infoLayer.style.display = 'block'
  },

  // Create item title from info. Show title if metadata.title exists and 
  // show_title is true. Show possible dimensions and author when show_metadata
  // is true.
  //
  // Returns the title as a element named in tag.
  //
  parseItemTitle : function(tag, info, show_title, show_metadata) {
    var elem = Elem(tag)
    var metadata = Elem('span')
    if (!info.metadata)
      return info.path.split("/").last()
    if (info.metadata.title && show_title) {
      var title = Elem('span', info.metadata.title)
      makeEditable(title, this.itemPrefix+info.path+this.editSuffix,
        'metadata.title', null, this.translate('click_to_edit'))
      elem.appendChild(title)
    } else {
      var title = Elem('span')
      var basename = info.path.split("/").last()
      var editable_part = Elem('span', basename)
      makeEditable(editable_part, this.itemPrefix+info.path+this.editSuffix,
        'title',
        function(base){
          if (base.length == 0) return false
          info.metadata.title = base
          return base
      }, this.translate('click_to_edit') )
      title.appendChild(editable_part)
      elem.appendChild(title)
    }
    if ( show_metadata ) {
      if (info.metadata.author) {
        metadata.appendChild(Text(this.translate('by')+" "))
        var author = Elem('span', info.metadata.author)
        makeEditable(author, this.itemPrefix+info.path+this.editSuffix,
          'metadata.author', null, this.translate('click_to_edit'))
        metadata.appendChild(author)
      }
      if (info.metadata.length)
        metadata.appendChild(Text(" " + info.metadata.length))
      if (info.metadata.width && info.metadata.height)
        metadata.appendChild(Text(" (" + info.metadata.width+"x"+info.metadata.height +
                      (info.metadata.dimensions_unit || "") + ")"))
    }
    elem.appendChild(Text(" "))
    elem.appendChild(metadata)
    return elem
  },

  // Creates user | src | ref | date | size -div and returns it.
  parseUserInfo : function(info) {
    var infoDiv = Elem('div', null, null, 'infoDiv')
    var by = Elem('p')
    by.appendChild(Elem('a', info.owner, null, 'infoDivLink', null,
                              {href:this.userPrefix+info.owner}))
    if (info.source && info.source.length > 0) {
      by.appendChild(Text(' | '))
      by.appendChild(Elem('a', this.translate("source"), null, 'infoDivLink', null,
                                {href:info.source}))
    }
    if (info.referrer && info.referrer.length > 0) {
      by.appendChild(Text(' | '))
      by.appendChild(Elem('a', this.translate("referrer"), null, 'infoDivLink', null,
                                {href:info.referrer}))
    }
    by.appendChild(Text(' | ' + this.translate('DateObject', info.created_at)))
    by.appendChild(Text(' | ' + Number.mag(info.size, this.translate('byte_abbr'), 1)))
    infoDiv.appendChild(by)
    return infoDiv
  },

  // Creates a metadata div from info.
  //
  // Returns the created metadata div (belongs to CSS class infoDiv.)
  //
  parseItemMetadata : function(info) {
    var infoDiv = Elem('div', null, null, 'infoDiv')
    var pubdata = []
/*    if (info.metadata.publish_time)
      pubdata.push('created: ' + info.metadata.publish_time.toLocaleString())*/
    if (info.metadata.publisher)
      pubdata.push(this.translate('publisher', ': ' + info.metadata.publisher))
    if (info.metadata.album)
      pubdata.push(this.translate('album', ': ' + info.metadata.album))
    if (pubdata.length > 0)
      infoDiv.appendChild(Elem('p', pubdata.join(" | ")))
    if (info.metadata.exif) {
      var tuples = {}
      info.metadata.exif.split("\n").each(function(tup){
        var kv = tup.split("\t")
        tuples[kv[0]] = kv[1]
      })
      var exifdata = []
      if (tuples['Date and Time']) {
        var dc = tuples['Date and Time'].split(/[^0-9]/)
        var d = new Date(dc[0], dc[1], dc[2], dc[3], dc[4], dc[5])
        exifdata.push(this.translate("date taken", ": " +
                                     this.translate("DateObject", d)))
      }
      if (tuples.Manufacturer)
        exifdata.push(this.translate("camera", ": " + tuples.Model +
                      ", " + this.translate("manufacturer", ": " + tuples.Manufacturer)))
      if (tuples.Software)
        exifdata.push(this.translate("software", ": " + tuples.Software))
      exifdata.each(function(pd){
        infoDiv.appendChild(Elem('p', pd))
      })
    }
    if (info.metadata.description) {
      var desc = Elem('p')
      desc.appendChild(Text(info.metadata.description))
      infoDiv.appendChild(desc)
    }
//     infoDiv.appendChild(Elem('pre', info.metadata.exif))
    if (info.writable) {
      var editLink = Elem("a", this.translate("edit"), null, null,
        {textAlign:'right', display:'block'},
        {href:this.itemPrefix+info.path+this.itemSuffix})
      var t = this
      editLink.addEventListener("click", function(e){
        if (e.button == 0 && !(e.ctrlKey || e.shiftKey || e.altKey)) {
          e.preventDefault()
          t.itemEditForm(infoDiv, info)
        }
      }, false)
      infoDiv.appendChild(editLink)
    }
    return infoDiv
  },

  itemEditForm : function(infoDiv, info) {
    if (infoDiv.editor) {
      var editor = infoDiv.editor
      editor.detachSelf()
      infoDiv.editor = false
    } else {
      var editor = Elem('div', null, null, 'editor',
        {
          position: 'absolute',
          left: infoDiv.parentNode.computedStyle().left + 'px',
          top: infoDiv.parentNode.computedStyle().top + 'px',
          width: infoDiv.parentNode.offsetWidth + 'px',
          height: infoDiv.parentNode.offsetHeight + 'px'
        }
      )
      infoDiv.editor = editor
      editor.appendChild(Elem('h3', info.path.split("/").last()))
      var ef = Elem("form")
      ef.method = 'POST'
      ef.action = this.itemPrefix + info.path + this.editSuffix
      obj = new Object()
      var d = Elem('span')
      d.style.display = 'block'
      d.style.position = 'relative'
      d.style.width = '100%'
      d.style.height = Math.max(parseInt(editor.style.height),
                                parseInt(editor.computedStyle().minHeight)) - 64 + 'px'
      d.style.overflow = 'auto'
      var tb = Elem('table')
      tb.width = "100%"
      d.appendChild(tb)
      var tr = Elem('tr')
      tr.vAlign = 'top'
      tb.appendChild(tr)
      var td = Elem('td')
      td.width = "50%"
      tr.appendChild(td)
      td.appendChild(Elem('h4', this.translate('item')))
      var dd = Elem('div')
      td.appendChild(dd)
      dd.appendChild(Elem("h5", this.translate('filename')))
      dd.appendChild(Elem("input", null,null,null,null,
        { type: 'text',
          name: 'filename',
          value: info.path.split("/").last().split(".").slice(0,-1).join("."),
        }
      ))
      var infoKeys = [
        'source',
        'referrer',
        'sets',
        'tags',
        'groups',
        'mimetype',
        'deleted'
      ]
      var t = this
      infoKeys.each(function(i) {
        dd.appendChild(Elem("h5", t.translate(i)))
        dd.appendChild(Elem("input", null, null, null, null,
          {type:'text', name: i, value:info[i]}
        ))
      })
      td = Elem('td')
      td.width = "50%"
      tr.appendChild(td)
      td.appendChild(Elem('h4', this.translate('metadata')))
      dd = Elem('div')
      td.appendChild(dd)
      var metadataKeys = [
        'title',
        'author',
        'publisher',
        'publish_time',
        'description',
        'location',
        'genre',
        'album',
        'tracknum',
        'album_art'
      ]
      metadataKeys.each(function(i) {
        dd.appendChild(Elem("h5", t.translate(i)))
        dd.appendChild(Elem("input", null, null, null, null,
          {type:'text', name: 'metadata.'+i, value:info.metadata[i]}
        ))
      })
      ef.appendChild(d)
      var es = Elem('div', null, null, 'editorSubmit')
      var cancel = Elem('input', null, null, null, null,
        {type:'reset', value:this.translate('cancel')})
      cancel.onclick = function() {
        editor.detachSelf()
        infoDiv.editor = false
      }
      var done = Elem('input', null, null, null, null,
        {type:'submit', value:this.translate('done')})
      var t = this
      done.onclick = function(e) {
        e.preventDefault()
        postForm(ef, function(res){
            editor.detachSelf()
            infoDiv.editor = false
          },
          t.queryErrorHandler(t.translate("edit_failed"))
        )
      }
      es.appendChild(cancel)
      es.appendChild(done)
      ef.appendChild(es)
      editor.appendChild(ef)
      infoDiv.parentNode.appendChild(editor)
    }
  },

  queryErrorHandler : function(operation) {
    return function(res){
      alert(operation + ": " + res.statusText + "(" + res.statusCode + ")")
    }
  },

  hideInfoLayer : function() {
    this.infoLayerData = false
    this.infoLayer.style.display = 'none'
  },

  pan : function(x,y,e){
    this.view.left += x
    this.view.top += y
    this.updateTiles()
    this.view.style.left = this.view.left + 'px'
    this.view.style.top = this.view.top + 'px'
    if (e && e.preventDefault) e.preventDefault()
  },

  zoomOut : function(e){
    if (this.zoom > 0) {
      var lx = this.view.cX - this.view.left - parseInt(this.container.computedStyle().left)
      var ly = this.view.cY - this.view.top - parseInt(this.container.computedStyle().top)
      this.zoom--
      this.view.left += parseInt(lx / 2)
      this.view.top += parseInt(ly / 2)
      if(this.zoomTimeout) clearTimeout(this.zoomTimeout)
      this.zoomTimeout = setTimeout(this.bind(function(){
        this.view.style.left = this.view.left + 'px'
        this.view.style.top = this.view.top + 'px'
        this.updateTiles(true)
      }), 200)
    }
    if (e && e.preventDefault) e.preventDefault()
  },

  zoomIn : function(e){
    if (this.zoom < this.maxZoom) {
      var lx = this.view.cX - this.view.left - parseInt(this.container.computedStyle().left)
      var ly = this.view.cY - this.view.top - parseInt(this.container.computedStyle().top)
      this.zoom++
      this.view.left -= (lx)
      this.view.top -= (ly)
      if(this.zoomTimeout) clearTimeout(this.zoomTimeout)
      this.zoomTimeout = setTimeout(this.bind(function(){
        this.view.style.left = this.view.left + 'px'
        this.view.style.top = this.view.top + 'px'
        this.updateTiles(true)
      }), 200)
    }
    if (e && e.preventDefault) e.preventDefault()
  },

  mousedownHandler : function(e){
    if (e.which != 1) return
    if (['INPUT', 'SPAN', 'P'].includes(e.target.tagName)) return
    this.dragging = true
    this.dragX = e.clientX
    this.dragY = e.clientY
    this.container.focus()
    e.preventDefault()
  },

  mousemoveHandler : function(e){
    this.view.cX = e.clientX
    this.view.cY = e.clientY
    if (this.dragging) {
      this.pan(e.clientX-this.dragX, e.clientY-this.dragY)
      this.dragX = e.clientX
      this.dragY = e.clientY
    }
    var x = e.clientX - parseInt(this.container.computedStyle().left) - this.view.left
    var y = e.clientY - parseInt(this.container.computedStyle().top) - this.view.top
    var ie = this.findInfoEntry(x, y)
    if (ie) this.updateItemLink(ie)
  },

  viewCoords: function(e) {
    return {
      x: e.clientX - parseInt(this.container.computedStyle().left) - this.view.left,
      y: e.clientY - parseInt(this.container.computedStyle().top) - this.view.top
    }
  },

  mouseupHandler : function(e){
    this.dragging = false
  },

  DOMMouseScrollHandler : function(e){
    if (e.detail > 0 ) {
      this.zoomOut(e)
    } else {
      this.zoomIn(e)
    }
  },

  keyHandler : function(e){
    if (e.target.tagName == 'INPUT') return
    switch(e.charCode | e.keyCode){
      case 90:
      case 122:
        this.zoomIn(e)
        break
      case 88:
      case 120:
        this.zoomOut(e)
        break
      case 37:
        this.pan(64,0,e)
        break
      case 38:
        this.pan(0,64,e)
        break
      case 39:
        this.pan(-64,0,e)
        break
      case 40:
        this.pan(0,-64,e)
        break
    }
  }
}
