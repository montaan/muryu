/*
  portal.js - zoomable tilemap library
  Copyright (C) 2007  Ilmari Heikkinen

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

  http://www.gnu.org/copyleft/gpl.html
*/

function createNewPortal(x, y, z, w, h, parent, config) {
  if (!config) config = {}
  var container = Elem('div', null, null, 'portal',
    {
      position : 'absolute',
      left : x + 'px',
      top : y + 'px',
      zIndex : z,
      width : (typeof w == 'string') ? w : w + 'px',
      height : (typeof h == 'string') ? h : h + 'px'
    }
  )
  config.container = container
  parent.appendChild(container)
  var portal = new Portal(config)
  container.addEventListener('mousedown',
    function(e){
      window.focusedPortal = portal
    }, false)
  return portal
}

function createNewPortalWindow(x, y, w, h, parent, config) {
  var win = Elem('div', null, null, 'portalWindow',
    { position: 'absolute',
      left: x+'px',
      top: y+'px',
      zIndex: 2,
      display: 'block' }, {left: x, top: y}
  )
  var title = Elem('h2', '', null, null,
    {cursor : 'move'})
  title.onmousedown = function(e){
    if (Mouse.normal(e)) {
      title.dragging = true
      title.prevX = e.clientX
      title.prevY = e.clientY
      e.preventDefault()
    }
  }
  title.addEventListener("dblclick", function(e) {
    if ( Mouse.normal(e) ) {
      title.dragging = false
      var ns = title.nextSibling
      if (ns) {
        if (ns.style.display != 'none') {
          title.style.width = ns.offsetWidth + 'px'
          ns.style.display = 'none'
        } else {
          title.style.width = null
          ns.style.display = null
        }
      }
    }
  }, false)
  window.addEventListener("mouseup", function(e) { title.dragging = false }, false)
  window.addEventListener("mousemove", function(e){
    if (title.dragging) {
      var dx = e.clientX - title.prevX
      var dy = e.clientY - title.prevY
      title.prevX = e.clientX
      title.prevY = e.clientY
      win.left += dx
      win.top += dy
      win.style.left = win.left + 'px'
      win.style.top = win.top + 'px'
    }
  }, false)
  win.appendChild(title)
  parent.appendChild(win)
  var portal = createNewPortal(0, 0, 1, w, h, win)
  portal.container.style.position = 'relative'
  portal.onlocationchange = function(x, y, z){
    title.innerHTML = portal.title + " (" + [x, y, z].join(":") + ")"
  }
  win.addEventListener('mousedown',
    function(e){
      window.focusedPortal = portal
    }, false)
  return portal
}

function createNewSubPortal() {
  var container = Elem('div', null, null, 'portal',
    { position : 'absolute', zIndex : 1 }
  )
  var fp = window.focusedPortal
  var sp = new Portal({
    subPortal : true,
    left: 256, top: 128*fp.subPortals.length,
    width: 256, height: 256,
    relativeZoom: -1,
    container: container,
    afterInit: function(){ fp.addSubPortal(sp) }
  })
}



Portal = function(config) {
  this.mergeD(config)
  var t = this
  postQuery(this.tileInfoPrefix, '',
    function(res){
      var obj = res.responseText.parseRawJSON()
      t.mergeD(obj)
      t.init()
      if (t.afterInit) t.afterInit()
    },
    this.queryErrorHandler('Loading portal info')
  )
}


Portal.prototype = {
  title : 'portal',
  language: guessLanguage(),
  defaultLanguage : 'en-US',
  
  x : -20,
  y : -60,
  zoom : 2,
  maxZoom : 7,
  tileSize : 256,

  loadsInFlight : 0,
  maxLoadFlightSize : 2,

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

  emblemPrefix : '/zogen/',
  emblemSuffix : '.png',

  thumbnailPrefix : '/items/',
  thumbnailSuffix : '/thumbnail',

  userPrefix : '/users/',

  filePrefix : '/files/',
  fileSuffix : '',
  
  query : '?' + window.location.search.substring(1),

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
    if (this.hash) {
      var xyz = this.hash.split(/[xyz]/)
      if (xyz[1] && xyz[1].match(/^[-+]?[0-9]+$/)) this.x = parseInt(xyz[1])
      if (xyz[2] && xyz[2].match(/^[-+]?[0-9]+$/)) this.y = parseInt(xyz[2])
      if (xyz[3] && xyz[3].match(/^[0-9]+$/)) this.zoom = parseInt(xyz[3])
    }
    this.subPortals = []
    this.loadQueue = []
    this.tiles = {tilesInCache : 0}
    this.initView()
    this.viewMonitors = []
    this.container.appendChild(this.view)
    this.itemCoords = {}
    this.infoOverlays = {}
    this.initItemLink()
    this.updateTiles()
    this.container.addEventListener("DOMAttrModified", this.bind('containerResizeHandler'), false)
    this.view.addEventListener("DOMAttrModified", this.bind('viewScrollHandler'), false)
    this.container.addEventListener("mousedown", this.bind('mousedownHandler'), false)
    this.container.addEventListener("DOMMouseScroll", this.bind('DOMMouseScrollHandler'), false)
    this.container.addEventListener("keypress", this.bind('keyHandler'), false)
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
      left: '0px', top: '-20px',
      zIndex: 4, color: 'white'
    })
    this.titleElem = t
    v.appendChild(t)
    this.view = v
  },

  viewScrollHandler : function(e) {
    if (e.target == this.view && e.attrName == 'style')
      this.viewMonitors.each(function(vm){ vm[1](e) })
  },

  containerResizeHandler : function(e) {
    if (e.target == this.container && e.attrName == 'style') {
      this.updateTiles()
    }
  },

  initItemLink : function(i) {
    var ti = this.itemLink = Elem('a', null, null, 'itemLink')
    ti.addEventListener("click", this.linkClick(), false)
    ti.addEventListener("mousedown", this.linkDown, false)
    ti.style.zIndex = 2
    this.view.appendChild(this.itemLink)
  },

  addSubPortal : function(sp) {
    this.subPortals.push(sp)
    sp.parentPortal = this
    this.view.appendChild(sp.container)
    this.updateSubPortal(sp)
  },

  updateSubPortal : function(sp) {
    if (this.updateSubPortalCoords(sp)) {
      if (!sp.container.parentNode) this.view.appendChild(sp.container)
    } else if (sp.container.parentNode) {
      sp.container.detachSelf()
    }
  },

  updateSubPortalCoords : function(sp) {
    var ax, ay, aw, ah
    var zf = Math.pow(2, this.zoom)
    var rzf = zf * Math.pow(2, sp.relativeZoom)
    ax = sp.left * zf
    ay = sp.top * zf
    aw = sp.width * rzf
    ah = sp.height * rzf
    if (
      ay + ah > -this.view.top &&
      ax + aw > -this.view.left &&
      ay < -this.view.top + this.container.offsetHeight &&
      ax < -this.view.left + this.container.offsetWidth
    ) {
      // FIXME make this clip loaded tiles instead of container dimensions :(
      sp.setZoom(this.zoom + sp.relativeZoom)
      // clip subportal extents to this.container
      var ldx = ax + this.view.left
      var tdy = ay + this.view.top
      var rdx = ldx + aw - this.container.offsetWidth
      var bdy = tdy + ah - this.container.offsetHeight
      var px = 0
      var py = 0
      if (ldx < 0) {
        ax -= ldx
        aw += ldx
        px = ldx
      }
      if (tdy < 0) {
        ay -= tdy
        ah += tdy
        py = tdy
      }
      if (rdx > 0) aw -= rdx
      if (bdy > 0) ah -= bdy
      sp.container.style.mergeD({
        left: ax + 'px',
        top : ay + 'px',
        width: aw + 'px',
        height: ah + 'px'
      })
      sp.panTo(-px, -py)
      return true
    } else {
      return false
    }
  },

  updateSubPortals : function() {
    for(var i=0; i<this.subPortals.length; i++)
      this.updateSubPortal(this.subPortals[i])
  },

  updateTiles : function(zoomed){
    var t = this
    var v = this.view
    var c = this.container
    var sl = -(v.left - (v.left % t.tileSize))
    var st = -(v.top - (v.top % t.tileSize))
    this.x = -v.left
    this.y = -v.top
    if (this.currentLocation)
      this.currentLocation.href = "#x" + this.x + "y" + this.y + "z" + this.zoom
    if (this.onlocationchange)
      this.onlocationchange(this.x, this.y, this.zoom)
    var tile_coords = []
    var visible_tiles = 0
    var vc = {
      x : c.offsetWidth/2 - v.left,
      y : c.offsetHeight/2 - v.top 
    }
    if (v.cX && v.cY) {
      vc = this.viewCoords(v.cX, v.cY)
    }
    var midX = vc.x - t.tileSize / 2
    var midY = vc.y - t.tileSize / 2
    this.titleElem.style.fontSize = parseInt(10 * Math.pow(2, this.zoom)) + 'px'
    this.titleElem.style.top = parseInt(-15 * Math.pow(2, this.zoom)) + 'px'
    if (zoomed) {
      this.clearQueue()
      this.view.byTag("div").each(function(d){
        if (d.className == 'info' || d.className == 'infoText') d.detachSelf()
      })
    }
    var xMax = Math.ceil(c.offsetWidth/t.tileSize) + 1
    var yMax = Math.ceil(c.offsetHeight/t.tileSize) + 1
    for(var i=-1; i < xMax; i++) {
      var x = i*t.tileSize+sl
      var dx = x - midX
      for(var j=-1; j < yMax; j++) {
        var y = j*t.tileSize+st
        var dy = y - midY
        t.showTile(x,y, dx*dx+dy*dy)
        visible_tiles++
      }
    }
    t.visible_tiles = visible_tiles
    if (t.tiles.tilesInCache > visible_tiles*2 || zoomed) {
      if (zoomed) t.itemCoords = {}
      t.removeTiles(sl - t.tileSize,
                    st - t.tileSize,
                    sl + c.offsetWidth + t.tileSize,
                    st + c.offsetHeight + t.tileSize)
    }
    this.processQueue()
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
          if (this.tiles[i].onload) this.tiles[i].onload(false)
          try{ this.view.removeChild(this.tiles[i]) } catch(e) {}
          this.tiles[i].src = null
          this.tiles.tilesInCache--
          this.deleteInfoEntries(this.tiles[i].infoEntries)
          delete this.tiles[i]
        }
      }
    }
    this.processQueue()
  },

  // Loads the tile at x,y with the given priority.
  showTile : function(x, y, priority){
    if (!this.tiles[x+':'+y+':'+this.zoom]) {
      var tile = Elem('img',null,null,'tile')
      tile.style.position = 'absolute'
      tile.style.left = x + 'px'
      tile.style.top = y + 'px'
      this.tiles[x+':'+y+':'+this.zoom] = tile
      this.tiles.tilesInCache++
      var t = this
      tile.timeout = this.insertLoader(priority, function(done){
        tile.style.visibility = 'hidden'
        var tileQuery = 'x'+ x +'y'+ y +'z'+ t.zoom +
                    'w'+ t.tileSize +'h'+ t.tileSize
        tile.onload = function(e){
            tile.onload = false
            done()
            if (e) {
              tile.style.visibility = 'visible'
              if (!t.loadLinks || t.zoom < 5) return
              postQuery(t.tileInfoPrefix + tileQuery + t.tileInfoSuffix, t.query,
                function(res){ t.createInfoEntries(res, tile, x, y) },
                t.queryErrorHandler(t.translate('loading_tile_info'))
              )
            }
          }
        tile.width = t.tileSize
        tile.height = t.tileSize
        tile.src = t.tilePrefix + tileQuery + t.tileInfoSuffix + t.query
        t.view.appendChild(tile)
        tile.timeout = false
      })
    }
  },

  // Inserts loader to loadQueue at the given priority.
  // The smaller the priority value, the earlier it is called.
  insertLoader : function(priority, loader) {
    for(var i=0; i<this.loadQueue.length; i++) {
      if (this.loadQueue[i][0] > priority) {
        this.loadQueue.splice(i, 0, [priority, loader])
        return
      }
    }
    this.loadQueue.push([priority, loader])
    this.processQueue()
  },

  // Processes loadQueue by shifting and calling from the queue until
  // loadsInFlight is equal to maxLoadFlightSize or the loadQueue is empty.
  processQueue : function() {
    var t = this
    while (this.loadsInFlight < this.maxLoadFlightSize && this.loadQueue.length > 0) {
      var l = this.loadQueue.shift()
      t.loadsInFlight++
      l[1](function(){
        t.loadsInFlight--
        if (t.loadsInFlight < 0) t.loadsInFlight = 0
        t.processQueue()
      })
    }
  },

  // Clears the loadQueue and resets loadsInFlight.
  clearQueue : function() {
    this.loadsInFlight = 0
    this.loadQueue = []
  },

  // Inserts the info into itemCoords for the tile
  createInfoEntries : function(res, tile, tx, ty){
    if (!this.createLinks) return false
    var infos = res.responseText.parseRawJSON()
    tile.infoEntries = infos
    var t = this
    infos.each(function(i){
      i.x += tx
      i.y += ty
      i.w = i.h = i.sz
      t.insertInfoEntry(i, i.x, i.y)
    })
  },

  // Deletes the given infoEntries from itemCoords.
  deleteInfoEntries : function(infoEntries) {
    if (!infoEntries) return
    var t = this
    infoEntries.each(function(ie){
      var info = t.infoOverlays[ie.x + ":" + ie.y]
      if (info && info.references > 0) {
        info.references--
//         console.log('dec references', info.info.path, info.references)
        if (info.references < 1) {
          delete t.infoOverlays[ie.x + ":" + ie.y]
          info.overlayElements.each(function(ole){ try{ ole.detachSelf() } catch(err) {} })
          info.overlayElements = []
//           console.log('detached overlayElements of '+info.info.path)
        }
      }
      var mods = [[0,0], [ie.w, 0], [0, ie.h], [ie.w, ie.h]]
      mods.each(function(m){
        var x = ie.x + m[0]
        var y = ie.y + m[1]
        var entries = t.coordsInfoEntry(x, y)
        if (entries) {
          entries.deleteAll(ie)
          if (entries.isEmpty()) {
//             console.log('deleting entries at '+x+","+y)
            var row = t.coordsRow(y)
            delete row[Math.floor(x / t.tileSize)]
            var empty = true
            for ( var i in row ) {
              if (i.match(/^[0-9]+$/)) {
                empty = false
                break
              }
            }
            if (empty) {
//               console.log('deleting row at '+x+","+y)
              delete t.itemCoords[Math.floor(y / t.tileSize)]
            }
          }
        }
      })
    })
  },

  // Pushes i to the info entry array at x,y.
  // Creates an info overlay at the coords if needed.
  insertInfoEntry : function(i, x, y) {
    if (i.references == undefined) {
      i.references = 0
      i.overlayElements = []
    }
    if (this.zoom > 7) this.loadInfoOverlay(i)
    if (i.w && i.h) {
      var t = this
      var mx = i.w / t.tileSize
      var my = i.h / t.tileSize
      var nx, ny, ie, k, j, has
      for(nx=0; nx < mx+1; nx++) {
        if (nx > mx) nx = mx
        for(ny=0; ny < my+1; ny++) {
          if (ny > my) ny = my
          ie = t.coordsInfoEntry(x+nx*t.tileSize, y+ny*t.tileSize, true)
          has = false
          for(k=0; k < ie.length; k++) {
            j = ie[k]
            if (j.x==x && j.y==y && j.w==i.w && j.h==i.h) {
              has = true
              break
            }
          }
          if (!has) ie.push(i)
        }
      }
    } else {
      var ie = this.coordsInfoEntry(x, y, true)
      if (ie.findAll(function(j){return (j.x==x && j.y==y)}).isEmpty()) {
        ie.push(i)
      }
    }
  },

  // Loads item details for the item detailed in info.
  loadInfoOverlay : function(info) {
    var i = this.infoOverlays[info.x + ":" + info.y]
    if (i) {
      i.references++
//       console.log('inc references', i.info.path, i.references)
      return false
    }
    this.infoOverlays[info.x + ":" + info.y] = info
//     console.log('inc references', info.info.path, info.references)
    info.references++
    var t = this
    postQuery(this.itemPrefix + info.info.path + this.itemJSONSuffix, '',
      function(res) {
        var fullInfo = res.responseText.parseRawJSON()
        t.createInfoOverlay(info, fullInfo)
      },
      t.queryErrorHandler(t.translate('loading_item_info'))
    )
  },

  // Gets the info entry array at x,y.
  // If autovivify is true, creates one if one doesn't exist.
  // Otherwise returns false if there's no info entry array.
  coordsInfoEntry : function(x, y, autovivify) {
    var gx = Math.floor(x / this.tileSize)
    var gy = Math.floor(y / this.tileSize)
    var row = this.itemCoords[gy]
    if (!row) {
      if (!autovivify) {
        return false
      } else {
        row = this.itemCoords[gy] = {}
      }
    }
    var ie = row[gx]
    if (!ie) {
      if (!autovivify) {
        return false
      } else {
        ie = row[gx] = []
      }
    }
    return ie
  },

  // Get the info entry row at y and return it.
  coordsRow : function(y) {
    var gy = Math.floor(y / this.tileSize)
    var row = this.itemCoords[gy]
    return row
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
    // ti.style.border = '1px solid yellow'
    ti.href = this.filePrefix + i.info.path + this.fileSuffix
    ti.infoObj = i
  },

  // Creates an info overlay from the infoObj and attaches it to the view at info.
  createInfoOverlay : function(info, infoObj) {
    var t = this
    var emblemElems = []
    var top_left_info = Elem('div', null, null, 'info', {position: 'absolute'})
    var top_right_info = Elem('div', null, null, 'info', {position: 'absolute'})
    var bottom_info = Elem('div', null, null, 'infoText', {position:'absolute'})
    bottom_info.appendChild(this.parseItemTitle('div', infoObj, true, true, 'infoDiv'))
    info.overlayElements = [top_left_info, top_right_info, bottom_info]
    if (info.w >= 256) {
      var emblems = infoObj.emblems
      var emblemContainer = Elem('div')
      top_left_info.appendChild(emblemContainer)
      var emblem_size = ((info.w >= 512) ? 32 : 16)
      var emblemElems = emblems.mapWithIndex(function(n,i){
        var el = t.createEmblem(n[0], n[1], n[2], i, emblem_size)
        emblemContainer.appendChild(el)
        return el
      })
      bottom_info.appendChild(this.parseUserInfo(infoObj))
      bottom_info.appendChild(this.parseItemMetadata(infoObj, (info.w < 512), (info.w < 512)))
      if (info.h > this.container.offsetHeight || info.w > this.container.offsetWidth) {
        var key = [info.x,info.y,info.w,info.h].join(":")
        var overlayUpdater = function(e){
          t.updateOverlayCoords(info,top_left_info,top_right_info,bottom_info,emblemElems,false)
        }
        t.addViewMonitor(key, overlayUpdater)
        bottom_info.addEventListener("DOMNodeRemoved", function(ev){
          if (ev.target == this) t.removeViewMonitor(key)
        },false)
      }
    }
    this.view.appendChild(bottom_info)
    t.updateOverlayCoords(info,top_left_info,top_right_info,bottom_info,emblemElems,true)
    this.view.appendChild(top_left_info)
    this.view.appendChild(top_right_info)
  },

  addViewMonitor : function(key, monitor) {
    this.viewMonitors.push([key, monitor])
  },

  removeViewMonitor : function(key) {
    this.viewMonitors.deleteIf(function(t){ return t[0] == key })
  },

  expandEmblems : function(emblems, sz) {
    emblems.each(function(e){
      e.appendChild(Elem('a', e.title, null, 'emblemText'+sz, null, {href: e.href, title: e.title}))
    })
  },

  shrinkEmblems : function(emblems) {
    emblems.each(function(e){
      if (e.lastChild) e.lastChild.detachSelf()
    })
  },

  // Create emblem from
  createEmblem : function(name, title, href, index, emblem_size, show_always) {
    var t = this
    var el = Elem('div', null, null, 'emblem',
      { display: 'block',
        position: 'absolute',
        left: '1px',
        top: (1 + (emblem_size+1)*index) + 'px'
      }, { href: href, title: title }
    )
    var img = Elem('a', null, null, 'emblemImage'+emblem_size,
      { border:'0px', width:  emblem_size + 'px', height: emblem_size + 'px',
        display: 'block',
        position: 'absolute', left: '0px', top: '0px',
        background: 'url('+t.emblemPrefix+name+'_'+emblem_size+t.emblemSuffix+') no-repeat' },
      { href: href, title: title })
    el.appendChild(img)
    if (!show_always) {
      el.onmouseover = function(){ t.expandEmblems([el], emblem_size) }
      el.onmouseout = function(){ t.shrinkEmblems([el], emblem_size) }
    } else {
      t.expandEmblems([el], emblem_size)
    }
    return el
  },

  updateOverlayCoords : function(info,tl,tr,b,es, force_update){
    var t = this
    var rx = info.x
    var ry = info.y
    var rw = info.w
    var rh = info.h
    var aw = this.container.offsetWidth
    var ah = this.container.offsetHeight
    var x_out = (rw > aw &&
                 -t.view.left > rx &&
                 -t.view.left+aw < rx+rw)
    var y_out = (rh > ah &&
                 -t.view.top > ry &&
                 -t.view.top+ah < ry+rh)
    if (x_out) {
      rx = -t.view.left
      rw = aw
    } else if (rw > aw) {
      if (rx+t.view.left < 0) rx = rx+(rw-aw)
      rw = aw
    }
    if (y_out) {
      ry = -t.view.top
      rh = ah
    } else if (rh > ah) {
      if (ry+t.view.top < 0) ry = ry+(rh-ah)
      rh = ah
    }
    if (info.x_out != x_out || info.y_out != y_out) {
      force_update = true
      info.x_out = x_out
      info.y_out = y_out
    }
    if (x_out || force_update) {
      tr.style.top = ry + 'px'
      tr.style.left = (rx + rw) + 'px'
      b.style.left = tl.style.left = rx + 'px'
      b.style.width = rw + 'px'
      es.each(function(el){el.style.width = (rw-2) + 'px'})
    }
    if (y_out || force_update) {
      tl.style.top = ry + 'px'
      b.style.top = (ry + rh - b.offsetHeight) + 'px'
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
      if (Mouse.normal(e)) {
        e.preventDefault()
        if ((Math.abs(e.clientX - this.downX) > 3) &&
            (Math.abs(e.clientY - this.downY) > 3)) {
          return false
        }
        t.centerClicked(e)
        /*if (!t.infoLayerVisible() || t.infoTargetChanged()) {
          var c = t.viewCoords(e.clientX, e.clientY)
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
        }*/
        return false
      }
    }
  },

  centerClicked : function(e) {
    var info = this.itemLink.infoObj
    if (info) {
      var cx = info.x - 0.5*(this.container.offsetWidth-info.w)
      var cy = info.y - 0.5*(this.container.offsetHeight-info.h)
      this.animatedPanTo(cx, cy)
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
    this.infoLayer.style.display = 'none'
    this.infoLayer.style.left = x + 'px'
    this.infoLayer.style.top = y + 'px'
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
    this.infoLayer.style.display = 'block'
  },

  // Create item title from info. Show title if metadata.title exists and 
  // show_title is true. Show possible dimensions and author when show_metadata
  // is true.
  //
  // Returns the title as a element named in tag.
  //
  parseItemTitle : function(tag, info, show_title, show_metadata, klass) {
    var elem = Elem(tag, null, null, klass)
    var metadata = Elem('span')
    if (!info.metadata)
      return info.path.split("/").last()
    if (info.metadata.title && show_title) {
      var title = Elem('span', info.metadata.title)
      makeEditable(title, this.itemPrefix+info.path+this.editSuffix,
        'metadata.title', null, this.translate('click_to_edit_title'))
      elem.appendChild(title)
    } else {
      var title = Elem('span')
      var basename = info.path.split("/").last()
      var editable_part = Elem('span', basename)
      makeEditable(editable_part, this.itemPrefix+info.path+this.editSuffix,
        'metadata.title',
        function(base){
          if (base.length == 0) return false
          info.metadata.title = base
          return base
      }, this.translate('click_to_edit_title') )
      title.appendChild(editable_part)
      elem.appendChild(title)
    }
    if ( show_metadata ) {
      if (info.metadata.author) {
        metadata.appendChild(Text(this.translate('by')+" "))
        var author = Elem('span', info.metadata.author)
        makeEditable(author, this.itemPrefix+info.path+this.editSuffix,
          'metadata.author', null, this.translate('click_to_edit_author'))
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
  parseItemMetadata : function(info, hide_edit_link, hide_description, hide_metadata) {
    var infoDiv = Elem('div', null, null, 'infoDiv')
    if (!hide_metadata) {
      var pubdata = []
      // if (info.metadata.publish_time)
      //   pubdata.push('created: ' + info.metadata.publish_time.toLocaleString())
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
    }
    if (info.metadata.description && !hide_description) {
      var desc = Elem('p')
      desc.appendChild(Text(info.metadata.description))
      infoDiv.appendChild(desc)
    }
//     infoDiv.appendChild(Elem('pre', info.metadata.exif))
    if (info.writable && !hide_edit_link) {
      var editLink = Elem("a", this.translate("edit"), null, null,
        {textAlign:'right', display:'block'},
        {href:this.itemPrefix+info.path+this.itemSuffix})
      var t = this
      editLink.addEventListener("click", function(e){
        if (Mouse.normal(e)) {
          e.preventDefault()
          t.itemEditForm(infoDiv, info)
        }
      }, false)
      infoDiv.appendChild(editLink)
    }
    return infoDiv
  },

  itemKeys : [
    {name:'mimetype', type:['list', 'mimetypes']},
    {name:'source', type:['url']},
    {name:'referrer', type:['url']},
    {name:'tags', type:['autoComplete', 'tags']},
    {name:'sets', type:['listOrNew', 'sets', true]},
    {name:'groups', type:['listOrNew', 'groups', true]}
  ],
  
  metadataKeys : [
    {name:'title', type:['string']},
    {name:'author', type:['autoComplete', 'authors']},
    {name:'publisher', type:['autoComplete', 'publishers']},
    {name:'publish_time', type:['time']},
    {name:'description', type:['text']},
    {name:'genre', type:['string']},
    {name:'location', type:['location']}
    /*,
    {name:'album', type:['listOrNew', 'albums']},
    {name:'tracknum', type:['intInput']} */
  ],
  
  itemEditForm : function(infoDiv, info) {
    if (infoDiv.editor) {
      var editor = infoDiv.editor
      editor.detachSelf()
      infoDiv.editor = false
    } else {
      var t = this
      var editor = Elem('div', null, null, 'editor',
        {
          position: 'absolute',
          left: infoDiv.parentNode.computedStyle().left,
          top: infoDiv.parentNode.computedStyle().top,
          zIndex: 20
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
          value: info.path.split("/").last().split(".").slice(0,-1).join(".")
        }))
      this.itemKeys.each(function(i) {
        var args = i.type.slice(1)
        var ed
        dd.appendChild(Elem("h5", t.translate(i.name)))
        if (i.name == 'tags') {
          ed = Editors[i.type[0]](i.name, info[i.name].join(", "), args)
        } else if (i.type[0] == 'list' || i.type[0] == 'listOrNew') {
          var list_name = args.shift()
          ed = Elem('span')
          postQuery('/'+list_name+'/json', '', function(res){
            var items = res.responseText.parseRawJSON()
            var list_parse = function(it){
              return ((typeof it == 'string') ? it : it.name + ':' + it.namespace)
             }
            var poss_vals = items.map(list_parse)
            var values = ((typeof info[i.name] == 'string') ?
                          info[i.name] : info[i.name].map(list_parse))
            args = [poss_vals].concat(args)
            ed.appendChild(Editors[i.type[0]](i.name, values, args))
          })
        } else {
          ed = Editors[i.type[0]](i.name, info[i.name], args)
        }
        if (i.type[0] == 'location') {
          ed.mapAttachNode = editor
          ed.mapTop = editor.computedStyle().top
          ed.mapLeft = (parseInt(editor.computedStyle().left) +
               Math.max(parseInt(editor.computedStyle().width),
                        parseInt(editor.computedStyle().minWidth)) + 'px')
        }
        dd.appendChild(ed)
      })
      td = Elem('td')
      td.width = "50%"
      tr.appendChild(td)
      td.appendChild(Elem('h4', this.translate('metadata')))
      dd = Elem('div')
      td.appendChild(dd)
      this.metadataKeys.each(function(i) {
        var args = i.type.slice(1)
        var ed
        dd.appendChild(Elem("h5", t.translate(i.name)))
        if (i.type[0] == 'list' || i.type[0] == 'listOrNew') {
          var list_name = args.shift()
          ed = Elem('span')
          postQuery('/'+list_name+'/json', '', function(res){
            var items = res.responseText.parseRawJSON()
            var list_parse = function(it){ return it.name + ':' + it.namespace }
            var poss_vals = items.map(list_parse)
            var values = info.metadata[i.name].map(list_parse)
            args = [values, poss_vals].concat(args)
            ed.appendChild(Editors[i.type[0]]('metadata.'+i.name, info.metadata[i.name], args))
          })
        } else {
          ed = Editors[i.type[0]]('metadata.'+i.name, info.metadata[i.name], args)
        }
        if (i.type[0] == 'location') {
          ed.mapAttachNode = editor
          ed.mapTop = editor.computedStyle().top
          ed.mapLeft = (parseInt(editor.computedStyle().left) +
               Math.max(parseInt(editor.computedStyle().width),
                        parseInt(editor.computedStyle().minWidth)) + 'px')
        }
        dd.appendChild(ed)
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
      t.view.appendChild(editor)
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
    var v = this.view
    var ptz = 1 / this.tileSize
    v.left += parseInt(x)
    v.top += parseInt(y)
    var lt = Math.floor(-v.left * ptz)
    var tt = Math.floor(-v.top * ptz)
    if (v.leftTile != lt || v.topTile != tt) {
      v.leftTile = lt
      v.topTile = tt
      this.updateTiles()
    }
    this.updateSubPortals()
    v.style.left = v.left + 'px'
    v.style.top = v.top + 'px'
    if (e && e.preventDefault) e.preventDefault()
  },

  animatedPanTo : function(x,y,duration) {
    if (this.subPortal) {
      var rzf = Math.pow(2, this.relativeZoom)
      var pzf = Math.pow(2, this.parentPortal.zoom)
      var rx = pzf * this.left + x
      var ry = pzf * this.top + y
      this.parentPortal.animatedPanTo(rx, ry, duration)
    } else {
      if (!duration) duration = 500
      var ox = -this.view.left
      var oy = -this.view.top
      var dx = x - ox
      var dy = y - oy
      var st = new Date().getTime()
      var t = this
      clearInterval(t.panAnimation)
      this.panAnimation = setInterval(function() {
        var ct = new Date().getTime()
        var v = (ct - st) / duration
        if (v > 1) v = 1
        var iv = t.cos_interpolate(v)
        t.panTo(ox + dx*iv, oy + dy*iv)
        if (v == 1) clearInterval(t.panAnimation)
      }, 16)
    }
  },

  panTo : function(x,y) {
    var dx = -(this.view.left + x)
    var dy = -(this.view.top + y)
    this.pan(dx, dy)
  },

  cos_interpolate : function(v) {
    return Math.sin(v * 0.5*Math.PI)
  },

  setZoom : function(z) {
    if (this.zoom != z && z >= 0 && z <= this.maxZoom) {
      this.zoom = z
    }
  },
  
  // Zooms out from the mouse pointer.
  zoomOut : function(e){
    if (this.zoom > 0) {
      var lx = this.view.cX - this.view.left - this.container.absoluteLeft()
      var ly = this.view.cY - this.view.top - this.container.absoluteTop()
      this.zoom--
      this.view.left += parseInt(lx / 2)
      this.view.top += parseInt(ly / 2)
      this.updateZoom(-1)
    }
    if (e && e.preventDefault) e.preventDefault()
  },

  // Zooms in towards the mouse pointer.
  zoomIn : function(e){
    if (this.zoom < this.maxZoom) {
      var lx = this.view.cX - this.view.left - this.container.absoluteLeft()
      var ly = this.view.cY - this.view.top - this.container.absoluteTop()
      this.zoom++
      this.view.left -= (lx)
      this.view.top -= (ly)
      this.updateZoom(+1)
    }
    if (e && e.preventDefault) e.preventDefault()
  },

  // Sets zoom timeout for updating the map.
  // FIXME Make this do nice animated zoom
  updateZoom : function(direction) {
    if(this.zoomTimeout) clearTimeout(this.zoomTimeout)
    var t = this
    this.zoomTimeout = setTimeout(function(){
      t.view.style.left = t.view.left + 'px'
      t.view.style.top = t.view.top + 'px'
      t.view.topTile = t.view.leftTile = null
      t.updateTiles(true)
      t.updateSubPortals()
    }, 0)
  },

  mousedownHandler : function(e){
    if (!Mouse.normal(e)) return
    if (['INPUT', 'SPAN', 'P', 'SELECT', 'OPTION', 'UL', 'LI'].includes(e.target.tagName)) return
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
    this.view.rX = e.clientX - this.container.absoluteLeft() - this.view.left
    this.view.rY = e.clientY - this.container.absoluteTop() - this.view.top
    var ie = this.findInfoEntry(this.view.rX, this.view.rY)
    if (ie) this.updateItemLink(ie)
  },

  viewCoords: function(x, y) {
    return {
      x: x - this.container.absoluteLeft() - this.view.left,
      y: y - this.container.absoluteTop() - this.view.top
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
    if (e.target.tagName == 'INPUT' || e.target.tagName == 'TEXTAREA') return
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
  },



  translations : {
    'en-US' : {
      DateObject : function(d){
        weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
        months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
        return (weekdays[d.getDay()] + ', ' + months[d.getMonth()] + ' ' +
                d.getDate() + ', ' + (d.getYear() + 1900) + ' ' +
                (d.getHours()%13).toString().rjust(2, '0') + ':' +
                d.getMinutes().toString().rjust(2, '0') + ':' +
                d.getSeconds().toString().rjust(2, '0') + ' ' +
                (d.getHours() < 13 ? 'am' : 'pm'))
      },
      by : 'by',
      author : 'author',
      date_taken : 'date taken',
      camera : 'camera',
      manufacturer : 'manufacturer',
      software : 'software',
      edit : 'edit metadata',
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
      click_to_edit_title : 'Click to edit item title',
      click_to_edit_author : 'Click to edit item author',
      item : 'item',
      metadata : 'metadata'
    },
    'en-GB' : {
      DateObject : function(d){
        weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
        months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
        return (weekdays[d.getDay()] + ', ' + d.getDate() + ' ' +
                months[d.getMonth()] + ' ' + (d.getYear() + 1900) + ' ' +
                (d.getHours()%13).toString().rjust(2, '0') + ':' +
                d.getMinutes().toString().rjust(2, '0') + ':' +
                d.getSeconds().toString().rjust(2, '0') + ' ' +
                (d.getHours() < 13 ? 'am' : 'pm'))
      }
    },
    'fi-FI' : {
      DateObject : function(d){
        weekdays = ['su', 'ma', 'ti', 'ke', 'to', 'pe', 'la']
        months = ['tammi', 'helmi', 'maalis', 'huhti', 'touko', 'kesä', 'heinä', 'elo', 'syys', 'loka', 'marras', 'joulu']
        return (weekdays[d.getDay()] + ' ' + d.getDate() + '. ' +
                months[d.getMonth()] + 'kuuta ' + (d.getYear() + 1900) + ' ' +
                d.getHours().toString().rjust(2, '0') + ':' +
                d.getMinutes().toString().rjust(2, '0') + ':' +
                d.getSeconds().toString().rjust(2, '0'))
      },
      by : '-',
      author : 'tekijä',
      date_taken : 'otettu',
      camera : 'kamera',
      manufacturer : 'valmistaja',
      software : 'ohjelmisto',
      edit : 'muokkaa tietoja',
      filename : 'tiedostonimi',
      source : 'lähde',
      referrer : 'viittaaja',
      sets : 'joukot',
      groups : 'ryhmät',
      tags : 'tagit',
      mimetype : 'tiedostomuoto',
      deleted : 'poistettu',
      title : 'nimeke',
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
      click_to_edit_title : 'Napsauta muokataksesi nimekettä',
      click_to_edit_author : 'Napsauta muokataksesi tekijän nimeä',
      item : 'kohde',
      metadata : 'sisältö'
    },
    'de-DE' : {
      by : '-',
      author : 'Urheber',
      date_taken : 'Erstellungsdatum',
      camera : 'Kameramodell',
      manufacturer : 'Hersteller',
      software : 'Software',
      edit : 'Metadaten bearbeiten',
      filename : 'Dateiname',
      source : 'Quelle',
      referrer : 'Referrer',
      sets : 'Garnituren',
      groups : 'Gruppen',
      tags : 'Tags',
      mimetype : 'Dateityp',
      deleted : 'gelöscht',
      title : 'Titel',
      publisher : 'Herausgeber',
      publish_time : 'Veröffentlichungszeit',
      description : 'Beschreibung',
      location : 'Ort',
      genre : 'Genre',
      album : 'Album',
      tracknum : 'Titelnummer',
      album_art : 'Albencover',
      cancel : 'abbrechen',
      done : 'speichern',
      edit_failed : 'Speicherung der Änderungen fehlgeschlagen',
      loading_tile_info : 'Kachelladevorgang fehlgeschlagen',
      loading_item_info : 'Dateiladevorgang fehlgeschlagen',
      byte_abbr : 'B',
      click_to_edit_title : 'Klicken Sie hier, um den Titel zu ändern',
      click_to_edit_author : 'Klicken Sie hier, um den Urhebernamen zu ändern',
      item : 'Datei',
      metadata : 'Metadaten'
    }
  }

}
