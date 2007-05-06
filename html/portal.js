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
  var portal = new Portal.FileMap(config)
  container.addEventListener('mousedown',
    function(e){
      window.focusedPortal = portal
    }, false)
  return portal
}

function createNewPortalWindow(x, y, w, h, parent, config) {
  var win = new Portal.Floater({
    x:x, y:y, container:parent
  })
  var portal = createNewPortal(0, 0, 1, w, h, win.content)
  portal.container.style.position = 'relative'
  portal.onlocationchange = function(x, y, z){
    win.title = portal.title + " (" + [x, y, z].join(":") + ")"
  }
  win.element.addEventListener('mousedown',
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
  var sp = new Portal.FileMap({
    subPortal : true,
    left: 256, top: 0,
    width: 256, height: 256,
    relativeZoom: 0,
    query: 'q=sort:big',
    container: container,
    afterInit: function(){ fp.addSubPortal(sp) }
  })
}



Portal = {}


Portal.Button = function(
  name, normal_image, hover_image, down_image, onclickHandler, text
){
  var button = Elem('a')
  button.name = name
  button.href = 'javascript:void(null)'
  button.normal_image = normal_image
  button.hover_image = hover_image
  button.down_image = down_image
  button.onclickHandler = onclickHandler
  button.image = Elem('img')
  button.image.alt = name
  button.image.title = name
  button.image.style.border = '0px'
  button.image.src = normal_image
  button.toggle = function(){
    var tmp = this.down_image
    this.down_image = this.normal_image
    this.normal_image = tmp
  }
  button.onmouseover = function(e){ this.image.src = this.hover_image }
  button.onmouseout = function(e){ this.image.src = this.normal_image }
  button.onmousedown = function(e){
    this.image.src = this.down_image
    e.stopPropagation()
    e.preventDefault()
  }
  button.onclick = function(e){
    this.onclickHandler(this, e)
    this.image.src = this.normal_image
    e.stopPropagation()
    e.preventDefault()
  }
  button.appendChild(button.image)
  if (text) {
    var cont = Elem('span')
    cont.appendChild(button)
    cont.appendChild(Text(' '))
    var tb = Elem('a').mergeD(button)
    tb.appendChild(Text(button.name))
    cont.appendChild(tb)
    return cont
  }
  return button
}


Portal.Floater = function(config) {
  if (config) this.mergeD(config)
  this.initialize()
}
Portal.Floater.prototype = {
  resizable : false,
  title : 'Floater',
  windowShade : true,
  visible : true,
  maximized : false,
  shaded : false,
  sticky : false,
  buttonImageDir : 'images/',
  buttonInactiveSuffix : '_grey',
  buttonActiveSuffix : '_yellow',
  enabledButtons : ['close', 'maximize', 'duplicate'],
  x : 0,
  y : 0,
  z : 2,

  initialize : function() {
    if (!this.container)
      this.container = document.body
    var el = this.element = Elem('div', null, null, 'floater',
      { position: 'absolute',
        left: this.x+'px',
        top: this.y+'px',
        zIndex: this.z,
        display: 'none' }
    )
    this.initButtons()
    var te = this.titleElement = Elem('h3', this.title, null, 'floaterTitle')
    this.content = Elem('div', null, null, 'floaterContent', {display: 'block'})
    el.addEventListener('mousedown', this.bind('elementMousedown'), false)
    te.addEventListener("dblclick", this.bind('titleDblclick'), false)
    window.addEventListener("mouseup", this.bind('windowMouseup'), false)
    window.addEventListener("mousemove", this.bind('windowMousemove'), false)
    this.element.appendChild(te)
    this.element.appendChild(this.content)
    this.container.appendChild(this.element)
    this.watch('x', this.styleIntChanger('element', 'left', 'px'))
    this.watch('y', this.styleIntChanger('element', 'top', 'px'))
    this.watch('z', this.styleIntChanger('element', 'zIndex'))
    this.watch('width', this.styleIntChanger('content', 'width', 'px'))
    this.watch('height', this.styleIntChanger('content', 'height', 'px'))
    this.watch('title', this.titleChanger())
    this.watch('container', this.bind('containerChange'))
    this.watch('sticky', this.bind('stickyChange'))
    this.watch('maximized', this.bind('maximizedChange'))
    this.watch('shaded', this.bind('shadedChange'))
    this.watch('visible', this.bind('visibleChange'))
    if (this.visible) this.show()
  },

  buttonURL : function(button_name, active) {
    return (this.buttonImageDir.replace(/\/?$/, '/') + button_name +
            (active ? this.buttonActiveSuffix : this.buttonInactiveSuffix) +
            '.png')
  },

  initButtons : function() {
    var bs = this.buttons = Elem('div', null, null, 'floaterButtons')
    var t = this
    this.enabledButtons.each(function(b){
      var button = Portal.Button(
        b.capitalize(),
        t.buttonURL(b, false),
        t.buttonURL(b, true),
        t.buttonURL(b, true),
        t.buttonClickHandler(b)
      )
      t[b+'Button'] = button
      bs.appendChild(button)
    })
    this.element.appendChild(bs)
  },

  buttonClickHandler : function(buttonName) {
    var hn = buttonName + 'ButtonClick'
    return this.bind(function(button, e){
      if (this[hn]) this[hn](this, e)
    })
  },

  closeButtonClick : function() {
    this.close()
  },

  maximizeButtonClick : function() {
    this.toggleMaximize()
  },

  stickyButtonClick : function() {
    this.toggleSticky()
  },

  toggleMaximize : function() {
    this.maximized = !this.maximized
  },

  toggleSticky : function() {
    this.sticky = !this.sticky
  },
  
  close : function() {
    this.visible = false
    this.element.detachSelf()
  },

  visibleChange : function(k,o,n){
    this.element.style.display = (n ? 'block' : 'none')
    return n
  },
  
  show : function() {
    this.visible = true
  },

  hide : function() {
    this.visible = false
  },

  elementMousedown : function(e){
    if (Mouse.normal(e)) {
      window.focusedFloater = this
      this.dragging = true
      this.prevX = e.clientX
      this.prevY = e.clientY
      e.preventDefault()
      e.stopPropagation()
    }
  },

  titleDblclick : function(e) {
    if ( Mouse.normal(e) && this.windowShade ) {
      e.stopPropagation()
      e.preventDefault()
      this.dragging = false
      this.shaded = !this.shaded
    }
  },

  windowMouseup : function(e) {
    this.dragging = false
  },

  windowMousemove : function(e){
    if (this.dragging) {
      var dx = e.clientX - this.prevX
      var dy = e.clientY - this.prevY
      this.prevX = e.clientX
      this.prevY = e.clientY
      this.x += dx
      this.y += dy
      e.preventDefault()
      e.stopPropagation()
    }
  },

  containerChange : function(k,o,n){
    this.element.detachSelf()
    n.appendChild(this.element)
    return n
  },

  shadedChange : function(k,o,n){
    var ns = this.content
    if (n) {
      this.titleElement.style.minWidth = ns.offsetWidth-44 + 'px'
      ns.style.display = 'none'
    } else {
      this.titleElement.style.minWidth = null
      ns.style.display = null
    }
    return n
  },
  
  maximizedChange : function(k,o,n){
    if (this.maximizeButton)
      this.maximizeButton.toggle()
    if (this.maximizedHandler) this.maximizedHandler(this, n)
    return n
  },

  stickyChange : function(k,o,n){
    if (this.stickyButtonImage)
      this.stickyButton.toggle()
    if (this.stickyHandler) this.stickyHandler(this, n)
    return n
  },

  titleChanger : function(){
    return this.bind(function(k,o,n){
      if (typeof n == 'string') {
        this.titleElement.innerHTML = n
      } else {
        this.titleElement.innerHTML = ''
        this.titleElement.appendChild(n)
      }
      return n
    })
  },

  styleIntChanger : function(elem, name, suffix) {
    if (!suffix) suffix = 0
    return this.bind(function(k, o, n) {
      n = parseInt(n)
      if (!isNaN(n)) {
        this[elem].style[name] = n + suffix
        return n
      } else {
        return o
      }
    })
  }

}


Portal.MapCanvas = function(config) {
  this.mergeD(config)
  if (this.initialize) this.initialize()
}
Portal.MapCanvas.prototype = {
}

Portal.FloaterHelpers = {}

Portal.OverlayHelpers = {}



Portal.PriorityQueue = function(){
  this.queue = []
  this.mergeD({
    insert : function(priority, value) {
      for(var i=0; i<this.queue.length; i++) {
        if (this.queue[i][0] > priority) {
          this.queue.splice(i, 0, [priority, value])
          return
        }
      }
      this.queue.push([priority, value])
    },

    shift : function(){
      if (this.queue.length == 0) return false
      return this.queue.shift()[1]
    }
  })
}



Portal.TileLoader = function(config) {
  this.mergeD({
    maxFlightSize : 6,

    // Inserts loader to queue at the given priority.
    // The smaller the priority value, the earlier it is called.
    insert : function(priority, loader) {
      this.queue.insert(priority, loader)
      this.process()
    },

    // Processes queue by shifting and calling from the queue until
    // flight size is equal to maxFlightSize or the queue is empty.
    process : function() {
      while (this.flight.length < this.maxFlightSize) {
        var obj = this.queue.shift()
        if (!obj) break
        this.flight.push(obj)
        obj(this.makeDone(obj))
      }
    },

    makeDone : function(obj){
      var t = this
      return function(){
        t.flight.deleteAll(obj)
        t.process()
      }
    },

    // Clears the queue and flight.
    clear : function() {
      while(this.queue.shift()) false
      this.flight = []
    }
  })
  this.mergeD(config)
  this.flight = []
  this.queue = new Portal.PriorityQueue()
  this.tiles = {}
}



































////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

Portal.TileMap = function(config) {
  this.mergeD(config)
}
Portal.TileMap.prototype = {
  title : 'portal',
  language: guessLanguage(),
  defaultLanguage : 'en-US',

  x : -20,
  y : -60,
  zoom : 2,
  maxZoom : 7,
  tileSize : 256,

  tilePrefix : '/tile/',
  tileSuffix : '',
  query : '',
  color : true,

  tileInfoPrefix : '/tile_info/',
  tileInfoSuffix : '',

  loadTileInfo : true,

  initialize : function(){
    var t = this
    postQuery(this.tileInfoPrefix, this.query,
      function(res){
        var obj = res.responseText.parseRawJSON()
        t.mergeD(obj)
//         t.query = 'q=owner:'+t.title.split(" ")[0]+' '+t.query.slice(2)
        t.init()
        if (t.afterInit) t.afterInit()
      },
      this.queryErrorHandler('Loading portal info')
    )
  },

  init : function() {
    if (this.hash) {
      var xyz = this.hash.split(/[xyz]/)
      if (xyz[1] && xyz[1].match(/^[-+]?[0-9]+$/)) this.x = parseInt(xyz[1])
      if (xyz[2] && xyz[2].match(/^[-+]?[0-9]+$/)) this.y = parseInt(xyz[2])
      if (xyz[3] && xyz[3].match(/^[0-9]+$/)) this.zoom = parseInt(xyz[3])
    }
    if (this.subPortal) {
      this.x = 0
      this.y = 0
    }
    this.topPortal = this
    this.subPortals = []
    this.tiles = {tilesInCache : 0}
    this.loader = new Portal.TileLoader()
    this.initView()
    this.viewMonitors = []
    this.container.appendChild(this.view)
    this.itemCoords = {}
    this.infoOverlays = {}
    this.updateTiles()
    this.container.addEventListener("DOMAttrModified", this.bind('containerResizeHandler'), false)
    this.view.addEventListener("DOMAttrModified", this.bind('viewScrollHandler'), false)
    // this.view.addEventListener("dblclick", this.bind('zoomIn'), false)
    this.container.addEventListener("mousedown", this.bind('mousedownHandler'), false)
    if (!this.subPortal) {
      this.container.addEventListener("DOMMouseScroll", this.bind('DOMMouseScrollHandler'), false)
      this.container.addEventListener("keypress", this.bind('keyHandler'), false)
    }
    window.addEventListener("mousemove", this.bind('mousemoveHandler'), false)
    window.addEventListener("mouseup", this.bind('mouseupHandler'), false)
    window.addEventListener("blur", this.bind('mouseupHandler'), false)
  },

  initView : function(){
    var v = Elem('div')
    v.style.position = 'absolute'
    v.left = -this.x
    v.top = -this.y
    v.style.left = v.left + 'px'
    v.style.top = v.top + 'px'
    v.style.zIndex = 0
    v.cX = this.container.offsetWidth/2
    v.cY = this.container.offsetHeight/2
    var t = Elem('h2', this.title)
    t.style.mergeD({
      position: 'absolute',
      fontSize: '20px',
      marginTop: '-20px',
      left: '0px', top: '0px',
      zIndex: 4, color: 'white'
    })
    this.titleElem = t
    if (!this.subPortal)
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

  addSubPortal : function(sp) {
    this.subPortals.push(sp)
    sp.parentPortal = this
    sp.topPortal = this.topPortal
    sp.bgcolor = this.bgcolor
    sp.color = this.color
    this.view.appendChild(sp.titleElem)
    this.view.appendChild(sp.container)
    this.updateSubPortal(sp)
  },

  updateSubPortal : function(sp) {
    var vis = sp.visible
    if (this.updateSubPortalCoords(sp)) {
      if (!sp.container.parentNode) this.view.appendChild(sp.container)
      if (vis != sp.visible) sp.updateTiles()
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
    sp.titleElem.style.left = ax + 'px'
    sp.titleElem.style.top = ay + 'px'
    sp.setZoom(this.zoom + sp.relativeZoom)
    if (
      ay + ah > -this.view.top &&
      ax + aw > -this.view.left &&
      ay < -this.view.top + this.container.offsetHeight &&
      ax < -this.view.left + this.container.offsetWidth
    ) {
      sp.container.style.mergeD({
        left: ax + 'px',
        top : ay + 'px',
        width: aw + 'px',
        height: ah + 'px'
      })
      sp.visible = true
      return true
    } else {
      sp.visible = false
      return false
    }
  },

  updateSubPortals : function() {
    for(var i=0; i<this.subPortals.length; i++)
      this.updateSubPortal(this.subPortals[i])
  },

  // Updates visible tile set, loading new tiles if needed, prioritized so that
  // the tiles nearest to the cursor are loaded first. Removes invisible tiles
  // when the tile cache is full and after zooming.
  //
  // FIXME make cursor coords behave right for subportals
  //       make removing invisible tiles work right
  updateTiles : function(zoomed){
    var t = this
    var v = this.view
    var c = this.topPortal.container
    if (this.subPortal) {
      if (!this.parentPortal) return
      var vl = parseInt(this.container.style.left) + this.parentPortal.view.left
      var vt = parseInt(this.container.style.top) + this.parentPortal.view.top
    } else {
      var vl = v.left
      var vt = v.top
    }
    var sl = -(vl - (vl % t.tileSize))
    var st = -(vt - (vt % t.tileSize))
    this.x = -v.left
    this.y = -v.top
    if (this.currentLocation)
      this.currentLocation.href = "#x" + this.x + "y" + this.y + "z" + this.zoom
    if (this.onlocationchange)
      this.onlocationchange(this.x, this.y, this.zoom)
    var tile_coords = []
    var visible_tiles = 0
    var vc = {
      x : c.offsetWidth/2 - vl,
      y : c.offsetHeight/2 - vt
    }
    if (v.cX && v.cY) {
      vc = this.viewCoords(v.cX, v.cY)
    }
    var midX = vc.x - t.tileSize / 2
    var midY = vc.y - t.tileSize / 2
//     console.log(this.subPortal, midX, midY)
    this.titleElem.style.fontSize = parseInt(10 * Math.pow(2, this.zoom)) + 'px'
    this.titleElem.style.marginTop = parseInt(-15 * Math.pow(2, this.zoom)) + 'px'
    this.titleElem.style.width = parseInt(256 * Math.pow(2, this.zoom)) + 'px'
    if (zoomed) {
      this.loader.clear()
      this.view.byTag("div").each(function(d){
        if (d.className == 'info' || d.className == 'infoText') d.detachSelf()
      })
      for (var k in this.tiles)
        if (this.tiles[k].key)
          this.removeTile(this.tiles[k])
    }
    var xMax = Math.ceil(c.offsetWidth/t.tileSize) + 1
    var yMax = Math.ceil(c.offsetHeight/t.tileSize) + 1
    var zf = Math.pow(2, this.zoom)
    for(var i=-1; i < xMax; i++) {
      var x = i*t.tileSize+sl
      var dx = x - midX
      for(var j=-1; j < yMax; j++) {
        var y = j*t.tileSize+st
        var show = true
        for (var k=0; k<this.subPortals.length; ++k) {
          var sp = this.subPortals[k]
          var rzf = zf * Math.pow(2, sp.relativeZoom)
          if (sp.left*zf <= x && sp.left*zf + sp.width*rzf >= x+t.tileSize &&
              sp.top*zf <= y && sp.top*zf + sp.height*rzf >= y+t.tileSize) {
//             console.log('skipping loading ' + this.title + ': '+x + ','+y)
            show = false
            break
          }
        }
        if (show) {
          var dy = y - midY
          t.showTile(x,y, dx*dx+dy*dy)
          visible_tiles++
        }
      }
    }
    t.visible_tiles = visible_tiles
    if (t.tiles.tilesInCache > visible_tiles*2 || zoomed) {
      if (zoomed) t.itemCoords = {}
      t.removeTiles(sl - t.tileSize,
                    st - t.tileSize,
                    sl + xMax*t.tileSize,
                    st + yMax*t.tileSize)
    }
    this.subPortals.each(function(sp){ if (sp.visible) sp.updateTiles(zoomed) })
    this.loader.process()
  },

  removeTiles : function(left, top, right, bottom){
    var tile
    for (var i in this.tiles) {
      tile = this.tiles[i]
      if ((tile.key) && (tile.tileZoom != this.zoom ||
          tile.tileX < left || tile.tileX > right ||
          tile.tileY < top || tile.tileY > bottom)
      ) this.removeTile(tile)
    }
    this.loader.process()
  },

  removeTile : function(tile) {
    tile.cancelLoad = true
    if (tile.onload) tile.onload(false)
    tile.src = null
    try{ tile.detachSelf() } catch(e) {}
    if (tile.destructor) tile.destructor()
    // if (this.subPortal) console.log('removing tile', tile.key)
    if (this.tiles[tile.key]) {
      this.tiles.tilesInCache--
      delete this.tiles[tile.key]
    }
  },

  // Loads the tile at x,y with the given priority.
  showTile : function(x, y, priority){
    var key = x+':'+y+':'+this.zoom
    if (!this.tiles[key]) {
      var tile = Elem('img',null,null,'tile')
      tile.key = key
      tile.tileX = x
      tile.tileY = y
      tile.tileZoom = this.zoom
      tile.style.position = 'absolute'
      tile.style.left = x + 'px'
      tile.style.top = y + 'px'
      this.tiles[key] = tile
      this.tiles.tilesInCache++
      var t = this
      var tl = function(done){
        if (tile.cancelLoad) return done()
        tile.style.display = 'none'
        var tileQuery = 'x'+ x +'y'+ y +'z'+ t.zoom +
                    'w'+ t.tileSize +'h'+ t.tileSize
        tile.onload = function(e){
            tile.onload = false
            done()
            if (e) {
              tile.style.display = 'block'
              if (!t.loadTileInfo) return
              postQuery(t.tileInfoPrefix + tileQuery + t.tileInfoSuffix, t.query,
                function(res){ t.handleTileInfo(res, tile, x, y) },
                t.queryErrorHandler(t.translate('loading_tile_info'))
              )
            }
          }
        tile.width = t.tileSize
        tile.height = t.tileSize
        tile.src = t.tilePrefix + tileQuery + t.tileInfoSuffix + '?' + t.query + '&color=' + t.color + ((t.bgcolor != null) ? '&bgcolor='+t.bgcolor : '') + (t.updateTime ? '&time='+t.updateTime : '')
        t.view.appendChild(tile)
        tile.timeout = false
      }
      tl.query = [x,y,t.zoom]
      tl.tile = tile
      tile.timeout = this.loader.insert(priority, tl)
    }
  },

  toggleColor : function() {
    this.color = !this.color
    this.subPortals.each(function(sp){ sp.toggleColor() })
    this.updateTiles(true)
  },

  setBgColor : function(color) {
    this.bgcolor = color
    this.subPortals.each(function(sp){ sp.setBgColor(color) })
    this.updateTiles(true)
  },

  tileInit : function(tile) {},

  handleTileInfo : function(res, tile, tx, ty){
  },

  addViewMonitor : function(key, monitor) {
    this.viewMonitors.push([key, monitor])
  },

  removeViewMonitor : function(key) {
    this.viewMonitors.deleteIf(function(t){ return t[0] == key })
  },

  centerClicked : function(e) {
    this.animatedPanTo(e.clientX-this.topPortal.container.absoluteLeft() - this.view.left - 0.5*(this.topPortal.container.offsetWidth), e.clientY-this.topPortal.container.absoluteTop() - this.view.top - 0.5*(this.topPortal.container.offsetHeight))
  },

  queryErrorHandler : function(operation) {
    return function(res){
      alert(operation + ": " + res.statusText + "(" + res.statusCode + ")")
    }
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
    if (e) e.stopPropagation()
  },

  apX : 0, apY : 0,

  animatedPan : function(x,y,duration,e) {
    if (this.apInProgress) {
      clearTimeout(this.apInProgress)
      x /= 2
      y /= 2
    } else {
      this.panStartX = this.view.left
      this.panStartY = this.view.top
    }
    var dx = this.view.left - this.panStartX
    var dy = this.view.top - this.panStartY
    this.apX += x
    this.apY += y
    this.animatedPanTo(-this.view.left+dx-this.apX, -this.view.top+dy-this.apY, duration)
    this.apInProgress = setTimeout(this.bind(function(){
      this.apX = this.apY = 0
      this.panStartX = this.panStartY = 0
      this.apInProgress = false
    }), duration)
    if (e && e.preventDefault) e.preventDefault()
    if (e) e.stopPropagation()
  },

  animatedPanTo : function(x,y,duration,e) {
    if (this.subPortal) {
      var rx = parseInt(this.container.style.left) + x
      var ry = parseInt(this.container.style.top) + y
//       console.log(x, y, rx, ry)
      this.parentPortal.animatedPanTo(rx, ry, duration, e)
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
        t.panTo(ox + dx*iv, oy + dy*iv, e)
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
    if (this.subPortal) return this.topPortal.zoomOut(e)
    if (this.zoom > 0) {
      var lx = this.view.cX - this.view.left - this.container.absoluteLeft()
      var ly = this.view.cY - this.view.top - this.container.absoluteTop()
      this.zoom--
      this.view.left += parseInt(lx / 2)
      this.view.top += parseInt(ly / 2)
      this.updateZoom(-1)
    }
    if (e && e.preventDefault) e.preventDefault()
    if (e) e.stopPropagation()
  },

  // Zooms in towards the mouse pointer.
  zoomIn : function(e){
    if (this.subPortal) return this.topPortal.zoomIn(e)
    if (this.zoom < this.maxZoom) {
      var lx = this.view.cX - this.view.left - this.container.absoluteLeft()
      var ly = this.view.cY - this.view.top - this.container.absoluteTop()
      this.zoom++
      this.view.left -= (lx)
      this.view.top -= (ly)
      this.updateZoom(+1)
    }
    if (e && e.preventDefault) e.preventDefault()
    if (e) e.stopPropagation()
  },

  // Sets zoom timeout for updating the map.
  // FIXME Make this do nice animated zoom
  updateZoom : function(direction) {
    var t = this.topPortal
    if(t.zoomTimeout) clearTimeout(t.zoomTimeout)
    t.zoomTimeout = setTimeout(function(){
      t.view.style.left = t.view.left + 'px'
      t.view.style.top = t.view.top + 'px'
      t.view.topTile = t.view.leftTile = null
      t.updateSubPortals()
      t.updateTiles(true)
    }, 0)
  },

  mousedownHandler : function(e){
    if (this.subPortal) return
    if (!Mouse.normal(e)) return
    if (!e.target.className.match(/\btile\b/)) return
    this.dragging = true
    this.dragX = e.clientX
    this.dragY = e.clientY
    this.container.focus()
    e.preventDefault()
    e.stopPropagation()
  },

  mousemoveHandler : function(e){
    this.view.cX = e.clientX
    this.view.cY = e.clientY
    if (this.dragging && !this.subPortal) {
      this.pan(e.clientX-this.dragX, e.clientY-this.dragY)
      this.dragX = e.clientX
      this.dragY = e.clientY
    }
    this.view.rX = e.clientX - this.container.absoluteLeft() - this.view.left
    this.view.rY = e.clientY - this.container.absoluteTop() - this.view.top
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

  keyHandlers : {
    z: function(e) { this.zoomOut(e) },
    a: function(e) { this.zoomIn(e) },
    s: function(e) { this.animatedPan(64,0,500,e) },
    e: function(e) { this.animatedPan(0,64,500,e) },
    f: function(e) { this.animatedPan(-64,0,500,e) },
    d: function(e) { this.animatedPan(0,-64,500,e) }
  },
  
  keyHandler : function(e){
    if (e.target.tagName == 'INPUT' || e.target.tagName == 'TEXTAREA') return
    var k = (e.charCode | e.keyCode)
    var ks = String.fromCharCode(k)
    var kh = (this.keyHandlers[k] || this.keyHandlers[ks])
    if (kh) kh.call(this, e)
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

  translations : {
    'en-US' : {loading_tile_info : 'Loading tile info failed'}
  }
}













































////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

Portal.FileMap = function(config) {
  this.mergeD(config)
  this.initialize()
}
Portal.FileMap.prototype = new Portal.TileMap()
Portal.FileMap.prototype.mergeD({
  title : 'portal',
  
  loadLinks : true,
  createLinks : true,

  itemPrefix : '/items/',
  itemSuffix : '',
  itemJSONSuffix : '/json',
  
  deleteSuffix : '/delete',
  undeleteSuffix : '/undelete',
  purgeSuffix : '/purge',
  editSuffix : '/edit',

  emblemPrefix : '',
  emblemSuffix : '.png',

  thumbnailPrefix : '/items/',
  thumbnailSuffix : '/thumbnail',

  userPrefix : '/users/',

  filePrefix : '/files/',
  fileSuffix : '',

  query : window.location.search.substring(1),

  init : function() {
    Portal.TileMap.prototype.init.call(this)
    this.initItemLink()
    this.infoLayer = new Portal.Floater({
      container : this.container, visible: false
    })
    this.infoLayer.titleElement.className = 'infoTitle'
    this.infoLayer.deleteButtonClick = this.bind('deleteFloater')
    this.infoLayer.editButtonClick = this.bind('editFloater')
    this.infoLayer.duplicateButtonClick = this.bind('duplicateFloater')
    this.infoLayer.maximizedHandler = this.bind('toggleFloaterMaximized')
  },

  deleteFloater : function(floater) {
  },

  editFloater : function(floater) {
  },

  duplicateFloater : function(floater) {
    var copy = new Portal.Floater({
      container: this.container,
      x: Math.max(0, floater.x + 10),
      y: Math.max(0, floater.y + 10)
    })
    copy.titleElement.className = 'infoTitle'
    copy.duplicateButtonClick = this.bind('duplicateFloater')
    copy.maximizedHandler = this.bind('toggleFloaterMaximized')
    this.setupInfoFloater(copy, floater.info, false)
  },
  
  toggleFloaterSticky : function(floater, sticky) {
    var c
    if (sticky) {
      c = this.viewCoords(
        floater.element.absoluteLeft(),
        floater.element.absoluteTop())
      floater.container = this.view
    } else {
      c = {x: floater.element.absoluteLeft(),
           y: floater.element.absoluteTop() }
      floater.container = this.container
    }
    floater.x = c.x
    floater.y = c.y
  },

  toggleFloaterMaximized : function(floater, maximized) {
    var img = floater.content.byTag('img')[0]
    if (img) {
      var using_canvas = (img.nextSibling.tagName == 'CANVAS')
      if (maximized) {
        img.origCoords = [img.width, img.height]
        if (using_canvas) {
          img.style.position = null
          img.style.opacity = null
          img.nextSibling.style.display = 'none'
        }
        img.width = floater.info.metadata.width
        img.height = floater.info.metadata.height
      } else if (img.origCoords) {
        if (using_canvas) {
          floater.y += 1 // hack to force firefox relayout
          if (floater.x < 0) floater.x = 0
          if (floater.y < 0) floater.y = 0
          setTimeout(function(){
            if (floater.y != 0) floater.y -= 1
          },0)
          img.nextSibling.style.display = null
          img.style.opacity = 0
          img.style.position = 'absolute'
        }
        img.width = img.origCoords[0]
        img.height = img.origCoords[1]
      }
    }
  },

  initItemLink : function(i) {
    var ti = this.itemLink = Elem('a', null, null, 'itemLink tile')
    ti.addEventListener("click", this.bind('linkClick'), false)
    ti.addEventListener("mousedown", this.bind('linkDown'), false)
    ti.style.zIndex = 2
    this.view.appendChild(this.itemLink)
  },

  tileInit : function(tile) {
    var t = this
    tile.destructor = function(){ t.deleteInfoEntries(this.infoEntries) }
  },
  
  mousemoveHandler : function(e) {
    Portal.TileMap.prototype.mousemoveHandler.call(this, e)
    var ie = this.findInfoEntry(this.view.rX, this.view.rY)
    if (ie) this.updateItemLink(ie)
  },

  handleTileInfo : function(res, tile, tx, ty){
    this.createInfoEntries(res, tile, tx, ty)
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
        if (info.references < 1) {
          delete t.infoOverlays[ie.x + ":" + ie.y]
          info.overlayElements.each(function(ole){ try{ ole.detachSelf() } catch(err) {} })
          info.overlayElements = []
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
      return false
    }
    this.infoOverlays[info.x + ":" + info.y] = info
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

  // Note where mouse button went down to avoid misclicks when dragging.
  linkDown : function(e) {
    var t = this.topPortal
    t.downX = e.clientX
    t.downY = e.clientY
  },

  // When clicking a link with LMB and no modifier, toggle its info floater.
  linkClick : function(e) {
    if (Mouse.normal(e)) {
      e.preventDefault()
      var t = this.topPortal
      if ((Math.abs(e.clientX - t.downX) > 3) ||
          (Math.abs(e.clientY - t.downY) > 3)) {
        return false
      }
      if (!t.infoLayerVisible() || t.infoTargetChanged()) {
        var c = t.viewCoords(e.clientX, e.clientY)
        t.infoTarget = this.itemLink.infoObj
        postQuery(t.itemPrefix+this.itemLink.infoObj.info.path+t.itemJSONSuffix, '',
          function(res) {
            var fullInfo = res.responseText.parseRawJSON()
            t.showInfoLayer(0, 0, fullInfo)
          },
          t.queryErrorHandler(t.translate('loading_item_info'))
        )
      } else {
        t.hideInfoLayer()
      }
      return false
    }
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

  centerClickedItem : function(e) {
    var info = this.itemLink.infoObj
    if (info) {
      var cx = info.x - 0.5*(this.topPortal.container.offsetWidth-info.w)
      var cy = info.y - 0.5*(this.topPortal.container.offsetHeight-info.h)
      this.animatedPanTo(cx, cy)
    }
  },

  infoLayerVisible : function() {
    return(this.infoLayer.visible)
  },

  infoTargetChanged : function() {
    return(this.infoTarget != this.itemLink.infoObj)
  },

  // Set this.infoLayer according to info, position it at (x,y) and
  // make it visible.
  //
  showInfoLayer : function(x,y,info) {
    this.infoLayerData = info
    if (this.infoLayer.sticky) this.infoLayer.sticky = false
    if (!this.infoLayer.element.parentNode) {
      this.infoLayer.container = this.container
      this.infoLayer.x = 0
      this.infoLayer.y = 0
    }
    if (this.infoLayer.x < 0) this.infoLayer.x = 0
    if (this.infoLayer.y < 0) this.infoLayer.y = 0
    if (this.infoLayer.maximized) this.infoLayer.maximized = false
    if (this.infoLayer.shaded) this.infoLayer.shaded = false
    this.setupInfoFloater(this.infoLayer, info, true)
  },

  setupInfoFloater : function(infoFloater, info, click_image_to_close) {
    infoFloater.info = info
    infoFloater.hide()
    infoFloater.title = this.parseItemTitle('span', info, true, true)
    infoFloater.content.innerHTML = ''
    infoFloater.content.appendChild(this.parseUserInfo(info))
    if (['image/jpeg','image/png','image/gif'].includes(info.mimetype)) {
      var i = Elem('img')
      var mw = this.container.offsetWidth
      var mh = this.container.offsetHeight
      var iw = info.metadata.width
      var ih = info.metadata.height
      i.width = 0
      i.height = 0
      i.onmousedown = function(e){
        this.downX = e.clientX
        this.downY = e.clientY
      }
      var h = (click_image_to_close ? '' : 'dbl')
      i['on'+h+'click'] = function(e){
        if (Mouse.normal(e) &&
            Math.abs(this.downX - e.clientX) < 3 &&
            Math.abs(this.downY - e.clientY) < 3) infoFloater.close()
      }
      i.src = this.filePrefix + info.path + this.fileSuffix
      infoFloater.content.appendChild(i)
      infoFloater.content.appendChild(this.parseItemMetadata(info))
      if (mw < (iw + 20)) {
        ih *= (mw - 20) / iw
        iw = mw - 20
      }
      infoFloater.show()
      var lh = 16 + infoFloater.element.offsetHeight
      if (mh < (ih + lh)) {
        iw *= (mh - lh) / ih
        ih = mh - lh
      }
      i.width = iw
      i.height = ih
      if (i.width < info.metadata.width || i.height < info.metadata.height) {
        if (navigator.userAgent.match(/rv:1\.[78].*Gecko/)) {
          var ic = Elem('canvas')
          if (ic.getContext) {
            ic.style.display = 'block'
            ic.width = iw
            ic.height = ih
            ic.onclick = i.onclick
            i.onload = function(){
              i.style.position = 'absolute'
              i.style.opacity = 0
              i.style.zIndex = 2
              ic.style.zIndex = 1
              i.parentNode.insertAfter(ic, i)
              var c = ic.getContext('2d')
              c.drawImage(i,0,0,iw,ih)
            }
          }
        }
      } else {
        infoFloater.maximized = true
      }
    } else {
      if (info.mimetype.match(/\bvideo\b/)) {
        var i = Elem('embed')
        i.width = info.metadata.width
        i.height = info.metadata.height
        i.src = this.filePrefix + info.path + this.fileSuffix
        i.setAttribute("type", "application/x-mplayer2")
      } else if (info.mimetype.split("/")[0] == 'audio') {
        var i = Elem('embed')
        i.width = 400
        i.height = 16
        i.src = this.filePrefix + info.path + this.fileSuffix
        i.setAttribute("type", info.mimetype)
      } else if (info.mimetype == 'text/html') {
        var i = Elem('iframe')
        i.style.backgroundColor = "white"
        i.width = 600
        i.height = 400
        i.src = this.filePrefix + info.path + this.fileSuffix + "/"
      } else if (info.mimetype.split("/")[0] == 'text') {
        var i = Elem('iframe')
        i.style.backgroundColor = "white"
        i.width = 600
        i.height = 400
        i.src = this.filePrefix + info.path + this.fileSuffix
      } else {
        var i = Elem('img')
        i.onmousedown = function(e){
          this.downX = e.clientX
          this.downY = e.clientY
        }
        var h = (click_image_to_close ? '' : 'dbl')
        i['on'+h+'click'] = function(e){
          if (Mouse.normal(e) &&
              Math.abs(this.downX - e.clientX) < 3 &&
              Math.abs(this.downY - e.clientY) < 3) infoFloater.close()
        }
        i.src = this.thumbnailPrefix + info.path + this.thumbnailSuffix
      }
      infoFloater.content.appendChild(i)
      infoFloater.content.appendChild(this.parseItemMetadata(info))
      infoFloater.show()
    }
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
      var t = this
      var editButton = Portal.Button(
        this.translate("edit"),
        Portal.Floater.prototype.buttonURL("edit", false),
        Portal.Floater.prototype.buttonURL("edit", true),
        Portal.Floater.prototype.buttonURL("edit", true),
        function(){ t.itemEditForm(infoDiv, info) },
        true
      )
      var deleteButton = Portal.Button(
        this.translate("delete_item"),
        Portal.Floater.prototype.buttonURL("delete", false),
        Portal.Floater.prototype.buttonURL("delete", true),
        Portal.Floater.prototype.buttonURL("delete", true),
        function(){ t.deleteItem(infoDiv, info) },
        true
      )
      var editDiv = Elem("div", null, null, 'editDiv',
        {textAlign:'right', display:'block', marginTop:'3px'})
      editDiv.appendChild(editButton)
      editDiv.appendChild(deleteButton)
      infoDiv.appendChild(editDiv)
    }
    return infoDiv
  },

  deleteItem : function(div, info) {
    if (div)
      div.parentNode.parentNode.detachSelf()
    var url = this.itemPrefix + info.path + this.itemSuffix + this.deleteSuffix
    postQuery(url, '',
      this.bind(function(res){
        this.updateTime = new Date().getTime()
        this.updateTiles(true)
      }),
      this.bind(function(res){
        this.queryErrorHandler(
          this.translate("delete_failed")
        )
      })
    )
  },

  itemKeys : [
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
          left: (this.container.offsetWidth / 2) - 413 + 'px',
          top: (this.container.offsetHeight / 2) - 270 + 'px',
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
      t.container.appendChild(editor)
    }
  },


  hideInfoLayer : function() {
    this.infoLayerData = false
    this.infoLayer.hide()
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
      welcome : function(name){
        return 'Welcome, '+name
      },
      sign_in : 'Sign in',
      register : 'Create account',
      sign_out : 'Sign out',
      username : 'Account name',
      password : 'Password',
      by : 'by',
      author : 'author',
      date_taken : 'date taken',
      camera : 'camera',
      manufacturer : 'manufacturer',
      software : 'software',
      edit : 'Edit metadata',
      delete_item : 'Delete',
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
      delete_failed : 'Deleting item failed',
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
      welcome : function(name){
        return 'Tervetuloa, '+name
      },
      sign_in : 'Kirjaudu sisään',
      register : 'Luo tunnuksesi',
      sign_out : 'Lopeta',
      username : 'Tunnus',
      password : 'Salasana',
      by : '-',
      author : 'tekijä',
      date_taken : 'otettu',
      camera : 'kamera',
      manufacturer : 'valmistaja',
      software : 'ohjelmisto',
      edit : 'Muokkaa tietoja',
      delete_item : 'Poista',
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
      delete_failed : 'Poisto epäonnistui',
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

})

