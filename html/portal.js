Portal = function(config) {
  this.mergeD(config)
  var t = this
  postQuery(this.tileInfoURL, '',
    function(res){
      eval("var obj = " + res.responseText)
      t.mergeD(obj)
      t.init()
    }
  )
}

Portal.prototype = {
  x : -20,
  y : -60,
  zoom : 2,
  maxZoom : 7,
  tileSize : 256,
  title : 'zogen',
  loadLinks : true,
  createLinks : true,
  tileURL : '/tile/',
  tileInfoURL : '/tile_info/',
  itemInfoURL : '/items/',
  itemInfoSuffix : '',
  query : '?' + window.location.search.substring(1),

  init : function() {
    this.tiles = {tilesInCache : 0}
    this.initView()
    this.container.appendChild(this.view)
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
      tile.timeout = setTimeout(this.bind(function(){
        tile.style.visibility = 'hidden'
        var t = this
        var tileQuery = 'x'+ x +'y'+ y +'z'+ this.zoom +
                    'w'+ this.tileSize +'h'+ this.tileSize
        var tile_cont = Elem('div')
        tile_cont.style.position = 'absolute'
        tile_cont.style.left = x+'px'
        tile_cont.style.top = y+'px'
        tile.addEventListener("load",
          function(){
            this.style.visibility = 'visible'
            if (t.zoom >= 5 && t.loadLinks) {
              postQuery(t.tileInfoURL + tileQuery, t.query,
                function(res){
                  tile.info = eval(res.responseText)
                  /*
                    Instead of many links, switch to fast (but complex)
                    mouse-following link system. Put tile infos into
                    grid-indexed 2D array, modulo mouse coords to grid
                    coords.

                    At far detail (64x64 and 128x128), bake
                    the emblems and item texts into the tiles.
                    Text seems to be the slowest thing to draw.
                    ( this is also true for server-side drawing :| )

                    Why?
                      Firefox doesn't like moving elements around,
                      so minimizing the amount of stuff it does need to
                      move makes the whole thing snappier.

                    init:
                      itemCoords = {}
                      itemCoords[info.x] ||= {}
                      itemCoords[info.x][info.y] ||= newLink(info)

                    mousemove:
                      col = itemCoords[mouse_x - (mouse_x % sz)]
                      if (col) item = col[mouse_y - (mouse_y % sz)]
                      itemLink.href = "/files/" + item.path
                  */
                  tile.info.each(function(i){
                    if (!t.createLinks) return false
                    var ti = Elem('a', null, null, 'itemLink')
                    ti.style.left = i[1][0][0] + 'px'
                    ti.style.top = i[1][0][1] + 'px'
                    ti.style.width = i[1][0][2] + 'px'
                    ti.style.height = i[1][0][2] + 'px'
                    ti.href = "/files/" + i[1][1].path
                    ti.emblems = []
                    ti.infoObj = i
                    ti.addEventListener("click", t.linkClick(), false)
                    ti.addEventListener("mousedown", t.linkDown, false)
                    ti.style.zIndex = 2
                    if (t.zoom == 7) {
                      var info = ti.info = Elem('div', null, null, 'info')
                      info.style.mergeD({
                        left: ti.style.left,
                        top: ti.style.top
                      })
                      var info_text = Elem('div', null, null, 'infoText')
                      info_text.style.mergeD({
                        left: ti.style.left,
                        top: (parseInt(ti.style.top) + parseInt(ti.style.height) - 16) + 'px',
                        width: ti.style.width,
                        height: '16px'
                      })
                      info_text.innerHTML = t.parseItemTitle('span', ti.infoObj[1][1], true, false)
                      var emblems = [
                        ['e', 'FUNNY HATS!! - £4.99 from eBay.co.uk'],
                        ['euro', 'Rocket Ship - 8.49€ from Amazon.de'],
                        ['location', 'Bavaria, Germania']]
                      emblems.each(function(n){
                        if (Math.random() < 0.7) return
                        ti.emblems.push(n)
                        var el = Elem('img')
                        el.style.display = 'block'
                        el.src = '/zogen/' + n[0] + '_16.png'
                        el.style.margin = '1px'
                        info.appendChild(el)
                      })
                    }
                    try{
                      tile_cont.appendChild(ti)
                      tile_cont.appendChild(info)
                      tile_cont.appendChild(info_text)
                    } catch(e) {}
                  })
                }
              )
            }
          },
        false)
        tile_cont.appendChild(tile)
        this.view.appendChild(tile_cont)
        tile.width = this.tileSize
        tile.height = this.tileSize
        tile.src = this.tileURL + tileQuery + this.query
        tile.timeout = false
      }), priority/40)
    }
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
        if (!this.fullInfo) {
          var th = this
          var x = e.layerX + parseInt(this.style.left) + parseInt(this.parentNode.style.left)
          var y = e.layerY + parseInt(this.style.top) + parseInt(this.parentNode.style.top)
          postQuery(t.itemInfoURL + this.infoObj[1][1].path + t.itemInfoSuffix, '',
            function(res) {
              eval("var obj = " + res.responseText)
              th.fullInfo = obj.merge({emblems: th.emblems})
              t.showInfoLayer(x, y, th.fullInfo)
            }
          )
        } else if (t.infoLayerData != this.fullInfo){
          var x = e.layerX + parseInt(this.style.left) + parseInt(this.parentNode.style.left)
          var y = e.layerY + parseInt(this.style.top) + parseInt(this.parentNode.style.top)
          t.showInfoLayer(x, y, this.fullInfo)
        } else {
          t.hideInfoLayer()
        }
        return false
      }
    }
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
    i.src = '/files/' + info.path
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
    var metadata = []
    if (!info.metadata)
      return info.path.split("/").last()
    if (info.metadata.title && show_title) {
      var title = Elem('span', info.metadata.title)
      makeEditable(title, '/items/'+info.path+'/edit', 'metadata.title')
      elem.appendChild(title)
    } else {
      var title = Elem('span')
      var path = info.path
      var ext = info.path.split(".").last()
      var basename = info.path.split("/").last()
      var filebase = basename.split(".").slice(0,-1).join(".")
      var dirname = info.path.split("/").slice(0,-1).join("/")
      var editable_part = Elem('span', filebase)
      makeEditable(editable_part, '/items/'+info.path+'/edit', 'filename', function(base){
        if (base.length == 0) return false
        base = base.replace("/", "_", 'g')
        info.path = path.split("/").slice(0,-1).join("/") + "/" + base + "." + ext
        return base
      })
      title.appendChild(editable_part)
      title.appendChild(Text("." + ext))
      elem.appendChild(title)
    }
    if ( show_metadata ) {
      if (info.metadata.author)
        metadata.push("by " + info.metadata.author)
      if (info.metadata.length)
        metadata.push(info.metadata.length)
      if (info.metadata.width && info.metadata.height)
        metadata.push("(" + info.metadata.width+"x"+info.metadata.height +
                      (info.metadata.dimensions_unit || "") + ")")
    }
    return elem
  },

  // Creates user | src | ref | date | size -div and returns it.
  parseUserInfo : function(info) {
    var infoDiv = Elem('div', null, null, 'infoDiv')
    var by = Elem('p')
    by.appendChild(Elem('a', info.owner, null, 'infoDivLink', null,
                              {href:'/users/'+info.owner}))
    if (info.source && info.source.length > 0) {
      by.appendChild(Text(' | '))
      by.appendChild(Elem('a', "source", null, 'infoDivLink', null,
                                {href:info.source}))
    }
    if (info.referrer && info.referrer.length > 0) {
      by.appendChild(Text(' | '))
      by.appendChild(Elem('a', "referrer", null, 'infoDivLink', null,
                                {href:info.referrer}))
    }
    by.appendChild(Text(' | ' + info.created_at.toLocaleString()))
    by.appendChild(Text(' | ' + Number.mag(info.size, 'B', 1)))
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
      pubdata.push('publisher: ' + info.metadata.publisher)
    if (info.metadata.album)
      pubdata.push('album: ' + info.metadata.album)
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
        var d = new Date(dc[0], dc[1], dc[2], dc[3], dc[4], dc[5]).toLocaleString()
        exifdata.push("date taken: " + d)
      }
      if (tuples.Manufacturer)
        exifdata.push("camera: " + tuples.Model +
                      ", manufacturer: " + tuples.Manufacturer)
      if (tuples.Software)
        exifdata.push("software: " + tuples.Software)
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
      var editLink = Elem("a", "edit", null, null,
        {textAlign:'right', display:'block'},
        {href:"/items/"+info.path})
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
      infoDiv.editor.onclick()
    } else {
      var editor = Elem('div', null, null, 'editor',
        {
          minWidth: infoDiv.parentNode.offsetWidth + 'px',
          minHeight: infoDiv.parentNode.offsetHeight + 'px'
        }
      )
      infoDiv.editor = editor
      editor.appendChild(Elem('h3', info.path.split("/").last()))
      var ef = Elem("form")
      ef.method = 'POST'
      ef.action = '/items/' + info.path + '/edit'
      obj = new Object()
      var d = Elem('span')
      d.style.display = 'block'
      d.style.position = 'relative'
      d.style.width = infoDiv.parentNode.offsetWidth + 'px'
      d.style.height = infoDiv.parentNode.offsetHeight - 64 + 'px'
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
      td.appendChild(Elem('h4', 'item'))
      var dd = Elem('div')
      td.appendChild(dd)
      dd.appendChild(Elem("h5", 'filename'))
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
      infoKeys.each(function(i) {
        dd.appendChild(Elem("h5", i.split("_").join(" ")))
        dd.appendChild(Elem("input", null, null, null, null,
          {type:'text', name: i, value:info[i]}
        ))
      })
      td = Elem('td')
      td.width = "50%"
      tr.appendChild(td)
      td.appendChild(Elem('h4', 'metadata'))
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
        dd.appendChild(Elem("h5", i.split("_").join(" ")))
        dd.appendChild(Elem("input", null, null, null, null,
          {type:'text', name: 'metadata.'+i, value:info.metadata[i]}
        ))
      })
      ef.appendChild(d)
      var es = Elem('div', null, null, 'editorSubmit')
      var cancel = Elem('input', null, null, null, null,
        {type:'reset', value:'cancel'})
      cancel.onclick = function() {
        editor.detachSelf()
        infoDiv.editor = false
      }
      var done = Elem('input', null, null, null, null,
        {type:'submit', value:'done'})
      done.onclick = function(e) {
        e.preventDefault()
        postForm(ef, function(res){
          editor.detachSelf()
          infoDiv.editor = false
        }, function(res){
          alert("Edit failed: " + res.statusText + ": " + res.responseText)
        })
      }
      es.appendChild(cancel)
      es.appendChild(done)
      ef.appendChild(es)
      editor.appendChild(ef)
      infoDiv.appendChild(editor)
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
