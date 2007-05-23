/*
  TileMap.js - zoomable tilemap widget for javascript
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


Tr.addTranslations('en-US', {
  'Item.open' : 'Open',
  'Item.select' : 'Select',
  'Item.click_to_inspect' : 'Left-click to inspect ',
  'Item.add_to_playlist' : 'Add to playlist',
  'Selection' : 'Selection',
  'Selection.clear' : 'Clear selection',
  'Selection.deselect' : 'Deselect',
  'Selection.delete_all' : 'Delete all',
  'Selection.undelete_all' : 'Undelete all',
  'Selection.add_to_playlist' : 'Add to playlist',
  'Selection.create_presentation' : 'Create presentation'
})
Tr.addTranslations('fi-FI', {
  'Item.open' : 'Avaa',
  'Item.select' : 'Valitse',
  'Item.click_to_inspect' : 'Napsauta nähdäksesi ',
  'Item.add_to_playlist' : 'Lisää soittolistaan',
  'Selection' : 'Valinta',
  'Selection.clear' : 'Tyhjennä valinta',
  'Selection.deselect' : 'Poista valinnasta',
  'Selection.delete_all' : 'Poista kaikki',
  'Selection.undelete_all' : 'Tuo kaikki takaisin',
  'Selection.add_to_playlist' : 'Lisää soittolistaan',
  'Selection.create_presentation' : 'Luo esitys'
})


ItemArea = {
  delete : function() {
    new Desk.Window(this.itemHREF.replace(/json$/, 'delete'))
  },
  
  undelete : function() {
    new Desk.Window(this.itemHREF.replace(/json$/, 'undelete'))
  },

  edit : function() {
    new Desk.Window(this.itemHREF.replace(/json$/, 'edit'))
  },
  
  open : function() {
    new Desk.Window(this.itemHREF)
  },

  getTitle : function() {
    return Tr('Item.click_to_inspect', this.info.path.split("/").last())
  },

  toggleSelect : function() {
    Selection.toggle(this)
  },

  addToPlaylist : function() {
    if (MusicPlayer)
      MusicPlayer.addToPlaylist(this.href)
  },

  oncontextmenu : function(ev) {
    if (!ev.ctrlKey) {
      var menu = new Desk.Menu()
      menu.addTitle(this.href.split("/").last())
      if (this.href.match(/mp3$/i)) {
        menu.addItem(Tr('Item.add_to_playlist'), this.addToPlaylist.bind(this))
      }
      menu.addItem(Tr('Item.select'), this.toggleSelect.bind(this))
      menu.addItem(Tr('Item.open'), this.open.bind(this))
      menu.addSeparator()
      menu.addItem(Tr('Button.Item.edit'), this.edit.bind(this))
      menu.addSeparator()
      if (this.info.deleted == 't')
        menu.addItem(Tr('Button.Item.undelete_item'), this.undelete.bind(this))
      else
        menu.addItem(Tr('Button.Item.delete_item'), this.delete.bind(this))
      menu.skipHide = true
      menu.show(ev)
      Event.stop(ev)
    }
  },

  onclick : function(ev) {
    if (Event.isLeftClick(ev)) {
      if (this.Xdown == undefined ||
          (Math.abs(this.Xdown - ev.clientX) < 3 &&
           Math.abs(this.Ydown - ev.clientY) < 3)
      ) {
        if (ev.ctrlKey) {
          Selection.toggle(this)
        } else if (ev.shiftKey) {
          Selection.spanTo(this)
        } else {
          new Desk.Window(this.itemHREF)
        }
      }
      Event.stop(ev)
    }
  },

  onmousedown : function(ev) {
    if (Event.isLeftClick(ev)) {
      this.Xdown = ev.clientX
      this.Ydown = ev.clientY
    }
  }
  
}

Selection = {
  selection : [],
  lastSelected : null,
  
  oncontextmenu : function(ev) {
    if (!ev.ctrlKey) {
      var menu = new Desk.Menu()
      menu.addTitle(Tr('Selection'))
      menu.addItem(Tr('Selection.add_to_playlist'), Selection.addToPlaylist.bind(Selection))
      menu.addItem(Tr('Selection.create_presentation'))
      menu.addSeparator()
      menu.addItem(Tr('Selection.delete_all'), Selection.deleteSelected.bind(Selection))
      menu.addItem(Tr('Selection.undelete_all'), Selection.undeleteSelected.bind(Selection))
      menu.addSeparator()
      menu.addItem(Tr('Selection.deselect'), function() { Selection.deselect(this.item) }.bind(this))
      menu.addItem(Tr('Selection.clear'), Selection.clear.bind(Selection))
      menu.skipHide = true
      menu.show(ev)
      Event.stop(ev)
    }
  },

  deselect : function(obj) {
    if (!this.selection.include(obj)) return
    this.selection.deleteFirst(obj)
    $(obj.selectionIndicator).detachSelf()
    this.lastSelected = obj
  },

  select : function(obj) {
    if (this.selection.include(obj)) return
    this.selection.push(obj)
    var s = obj.selectionIndicator = E('div')
    s.item = obj
    var xywh = obj.coords.split(",")
    var tile = obj.parentNode.parentNode
    // this is just bad and doesn't work at all with zoom
    s.style.position = 'absolute'
    s.style.left = parseInt(tile.style.left) + parseInt(xywh[0]) + 'px'
    s.style.top = parseInt(tile.style.top) + parseInt(xywh[1]) + 'px'
    s.style.width = (xywh[2]-xywh[0]) + 'px'
    s.style.height = (xywh[3]-xywh[1]) + 'px'
    s.style.zIndex = '1'
    s.style.backgroundColor = 'blue'
    s.style.opacity = 0.75
    s.onclick = function(e) {
      if (Event.isLeftClick(e)) {
        if (!e.ctrlKey)
          Selection.clear()
        else
          Selection.toggle(obj)
      }
    }
    s.oncontextmenu = this.oncontextmenu.bind(s)
    tile.parentNode.appendChild(s)
    this.lastSelected = obj
  },
  
  toggle : function(obj) {
    if (this.selection.include(obj)) {
      this.deselect(obj)
    } else {
      this.select(obj)
    }
  },

  clear : function() {
    while(this.selection.length > 0)
      this.toggle(this.selection[0])
  },
  
  spanTo : function(obj) {
    if (this.lastSelected) {
      this.findSpan(this.lastSelected, obj).each(this.toggle.bind(this))
    } else {
      this.toggle(obj)
    }
  },
  
  findSpan : function(from, to) {
    return []
  },
  
  deleteSelected : function() {
    this.selection.invoke('delete')
  },
  
  undeleteSelected : function() {
    this.selection.invoke('undelete')
  },

  addToPlaylist : function() {
    this.selection.invoke('addToPlaylist')
  },
  
  addTags : function() {
  },
  
  removeTags : function() {
  },
  
  setTags : function() {
  },
  
  addGroups : function() {
  },
  
  removeGroups : function() {
  },
  
  setGroups : function() {
  },
  
  addSets : function() {
  },
  
  removeSets : function() {
  },
  
  setSets : function() {
  }
  
}


/*
* Creates a new TileMap inside the passed element.
*/
TileMap = function(config) {
  if (config)
    Object.extend(this, config)
  this.container = Desk.Windows.windowContainer
  this.element = document.createElement('div')
  this.element.style.position = 'absolute'
  this.element.style.left = '0px'
  this.element.style.top = '0px'
  this.element.style.overflow = 'hidden'
  this.container.appendChild(this.element)
  this.layers = []
  this.loader = new Loader(this.tileServers, this.tileInfoServers)
  this.pool = new ImagePool()
  this.init()
  Desk.Windows.addListener('resize', function(v){
    this.setWidth(v.width)
    this.setHeight(v.height)
  }.bind(this))
  Session.add(this)
}
TileMap.loadSession = function(data){
  Map = new TileMap(data)
  return Map
}
TileMap.prototype = {

  dumpLoader : 'TileMap',

  dumpSession : function() {
    var dump = {
      x: this.x,
      y: this.y,
      z: this.targetZ,
      targetZ : this.targetZ,
      query: this.query,
      color: this.color,
      bgcolor : this.bgcolor,
      bgimage : this.bgimage
    }
    return {
      loader: this.dumpLoader,
      data: dump
    }
  },

  tileServers : ['http://manifold.fhtr.org:8080/tile/'],
  tileInfoServers : ['http://manifold.fhtr.org:8080/tile_info/'],

  query : '',
  color : 'true',
  bgcolor : '03233C',
  bgimage : false,

  __tileQuery : '',
  __filePrefix : '/files/',
  __itemPrefix : '/items/',
  __itemSuffix : '/json',

  time : new Date().getTime(),

  x : 0,
  y : 0,
  z : 0,
  targetZ : 0,

  layerCount : 16, // max zoom of the map (this is a hack)

  width : 256,
  height: 256,

  pointerX : 0,
  pointerY : 0,

  frameTime : 16, // in milliseconds
  zoomDuration : 200, // in milliseconds

  frames : 0,
  totalFrameTimes : 0,
  fps : 0,
  avgFps : 0,

  tileSize : 256,

  /**
   Returns the relative tile path for the tile that is:
     - xth from the left, zero being leftmost
     - yth from the top, zero being topmost
     - on zoom level z, zero being most zoomed out
  */
  coordinateMapper : function(x, y, z) {
    if (x < 0 || y < 0 || x >= (1 << z) || y >= (1 << z))
      return 'x-256y-256z0'
    else
      return 'x'+(x*256)+'y'+(y*256)+'z'+z
  },

  /**
   Called by the constructor to set up the TileMap.
  
   Sets up the map layers, loads the initial view and sets up event listeners.
  */
  init : function() {
    var t = this
    this.zoomer = function(){ t.zoomStep() }
    for (var i=0; i<this.layerCount; i++) {
      var layer = new MapLayer(this, i)
      this.layers.push(layer)
      this.element.appendChild(layer.element)
    }
    this.updateTileQuery(false)
    var x = this.x
    var y = this.y
    this.zoom(this.z, 0, 0)
    this.panBy(x, y)
    this.selectionElem = E('div')
    this.selectionElem.style.border = '2px solid blue'
    this.selectionElem.style.backgroundColor = 'darkblue'
    this.selectionElem.style.opacity = 0.5
    this.selectionElem.style.position = 'absolute'
    this.selectionElem.style.display = 'none'
    this.selectionElem.style.zIndex = 50
    this.element.appendChild(this.selectionElem)
    this.setupEventListeners()
  },

  /**
   When removing a TileMap from the document, call this.
  
   Removes event listeners, unloads layers.
  */
  unload : function() {
    this.removeEventListeners()
    clearInterval(this.zoomIval)
    delete this.zoomer
    this.x = this.layers[0].x
    this.y = this.layers[0].y
    while(this.layers.length > 0) {
      var layer = this.layers.pop()
      layer.unload()
      this.element.removeChild(layer.element)
    }
  },

  /**
   Creates event listener functions and adds them to element and document.
  */
  setupEventListeners : function() {
    var t = this
    this.onmousedown = function(ev) {
      if (Event.isLeftClick(ev)) {
        if (ev.ctrlKey) {
          t.selecting = true
          t.selectX = ev.pageX - t.container.offsetLeft
          t.selectY = ev.pageY - t.container.offsetTop
          t.selectionElem.style.display = 'block'
          t.selectionElem.style.left = t.selectX + 'px'
          t.selectionElem.style.top = t.selectY + 'px'
          t.selectionElem.style.width = '0px'
          t.selectionElem.style.height = '0px'
          t.selection = new Hash()
          t.selectUnderSelection()
        } else {
          t.panning = true
          t.panX = ev.clientX
          t.panY = ev.clientY
        }
        Event.stop(ev)
      }
    }
    this.onmouseup = function(ev) {
      t.panning = false
      t.selecting = false
      t.selectionElem.style.display = 'none'
    }
    this.onmousemove = function(ev) {
      t.pointerX = ev.pageX - t.container.offsetLeft
      t.pointerY = ev.pageY - t.container.offsetTop
      t.focused = true
      if (t.panning) {
        var dx = ev.clientX - t.panX
        var dy = ev.clientY - t.panY
        t.panBy(dx, dy)
        t.panX = ev.clientX
        t.panY = ev.clientY
        Event.stop(ev)
      } else if (t.selecting) {
        t.selectionElem.style.display = 'block'
        t.selectionElem.style.left = Math.min(t.pointerX, t.selectX) + 'px'
        t.selectionElem.style.top = Math.min(t.pointerY, t.selectY) + 'px'
        t.selectionElem.style.width = Math.abs(t.pointerX-t.selectX) + 'px'
        t.selectionElem.style.height = Math.abs(t.pointerY-t.selectY) + 'px'
        t.selectUnderSelection()
        Event.stop(ev)
      }
    }
    this.onmouseover = function(ev) { t.focused = true }
    this.onmouseout = function(ev) { t.focused = false }
    this.onmousescroll = function(ev) {
      if (ev.detail < 0) {
        t.animatedZoom(t.z+1)
      } else {
        t.animatedZoom(t.z-1)
      }
      Event.stop(ev)
    }
    this.onkeypress = function(ev) {
      if (t.focused && !ev.ctrlKey) {
        if (String.fromCharCode(ev.keyCode | ev.charCode | ev.which).toUpperCase() == 'T') {
          t.animatedZoom(t.z+1)
        } else if (String.fromCharCode(ev.keyCode | ev.charCode | ev.which).toUpperCase() == 'G') {
          t.animatedZoom(t.z-1)
        }
        Event.stop(ev)
      }
    }
    this.onunload = function(ev) {
      t.unload()
    }
    this.element.addEventListener("mousedown", this.onmousedown, false)
    document.addEventListener("mouseup", this.onmouseup, false)
    this.element.addEventListener("mousemove", this.onmousemove, false)
    this.element.addEventListener("mouseover", this.onmouseover, false)
    this.element.addEventListener("mouseout", this.onmouseout, false)
    this.element.addEventListener("DOMMouseScroll", this.onmousescroll, false)
    document.addEventListener("keypress", this.onkeypress, false)
    document.addEventListener("unload", this.onunload, false)
  },

  /**
   * Selects all items that intersect the lasso selection box (selectionElem).
   */
  selectUnderSelection : function() {
    var z = Math.max(Math.min(this.targetZ, this.layerCount-1), 0)
    var layer = this.layers[z]
    var tsz = this.tileSize
    var left = -layer.x + parseInt(this.selectionElem.style.left)
    var top = -layer.y + parseInt(this.selectionElem.style.top)
    var width = parseInt(this.selectionElem.style.width)
    var height = parseInt(this.selectionElem.style.height)
    var l = Math.floor(left / tsz)
    var t = Math.floor(top / tsz)
    var r = Math.ceil((left+width) / tsz)
    var b = Math.ceil((top+height) / tsz)
    var previousSelection = this.selection
    this.selection = new Hash()
    for (var x=l; x<=r; x++) {
      for (var y=t; y<=b; y++) {
        var tile = layer.tiles[x+':'+y]
        if (tile && tile.ImageMap) {
          var areas = tile.ImageMap.childNodes
          var tx = parseInt(tile.style.left)
          var ty = parseInt(tile.style.top)
          for (var i=0; i<areas.length; i++) {
            var area = areas[i]
            if (
              !(this.selection[area.itemHREF]) && // not already processed
              this.intersect(left, top, width, height,
                             area.info.x+tx, area.info.y+ty, area.info.sz, area.info.sz)
            ) {
              var pr = previousSelection[area.itemHREF]
              if (pr && pr != area) {
                this.selection[area.itemHREF] = pr
              } else {
                if (!pr) // not previously selected
                  area.toggleSelect()
                this.selection[area.itemHREF] = area
              }
            }
          }
        }
      }
    }
    var s = this.selection
    previousSelection.each(function(kv,i) {
      if (!s[kv[0]])
        kv[1].toggleSelect()
    })
  },
  intersect : function(x1,y1,w1,h1, x2,y2,w2,h2) {
    return !(x1 > x2+w2 || y1 > y2+h2 || x1+w1 < x2 || y1+h1 < y2)
  },

  /**
   Removes event listeners from element and document,
   then deletes the event listener functions.
  */
  removeEventListeners : function() {
    this.element.removeEventListener("mousedown", this.onmousedown, false)
    document.removeEventListener("mouseup", this.onmouseup, false)
    this.element.removeEventListener("mousemove", this.onmousemove, false)
    this.element.removeEventListener("mouseover", this.onmouseover, false)
    this.element.removeEventListener("mouseout", this.onmouseout, false)
    this.element.removeEventListener("DOMMouseScroll", this.onmousescroll, false)
    document.removeEventListener("keypress", this.onkeypress, false)
    document.removeEventListener("unload", this.onunload, false)
    delete this.onmousemove
    delete this.onmouseover
    delete this.onmouseout
    delete this.onmousescroll
    delete this.onkeypress
    delete this.onunload
  },

  /**
   Sets map width to w, updates element width and visible tiles as well.
  */
  setWidth : function(w) {
    this.width = w
    this.element.style.width = this.width + 'px'
    this.updateTiles(this.pointerX, this.pointerY, 1)
  },

  /**
   Sets map height to w, updates element height and visible tiles as well.
  */
  setHeight : function(h) {
    this.height = h
    this.element.style.height = this.height + 'px'
    this.updateTiles(this.pointerX, this.pointerY, 1)
  },

  /**
   Set the list of tile servers to use.
  */
  setTileServers : function(ts) {
    this.tileServers = ts
    this.loader.setServers(this.tileServers)
  },

  /**
   Set the list of tileinfo servers to use.
  */
  setTileInfoServers : function(ts) {
    this.tileInfoServers = ts
    this.loader.setInfoServers(this.tileInfoServers)
  },

  /**
   Sets search query and reloads all tiles.
  */
  setQuery : function(q) {
    this.query = q
    this.updateTileQuery()
  },

  /**
   Sets tile coloring and reloads all tiles.
  */
  setColor : function(q) {
    this.color = q
    this.updateTileQuery()
  },

  /**
   Sets bgcolor and reloads all tiles.
  */
  setBgcolor : function(q) {
    this.bgcolor = q
    this.updateTileQuery()
  },

  /**
   Sets bgimage and reloads all tiles.
  */
  setBgimage : function(q) {
    this.bgimage = q
    this.updateTileQuery()
  },

  /**
   Forces tile update.
  */
  forceUpdate : function() {
    this.time = new Date().getTime()
    this.updateTileQuery()
  },

  /**
   Updates the GET query for the tiles and reloads all tiles unless reload_tiles is false.
  */
  updateTileQuery : function(reload_tiles) {
    var nq = []
    if (this.query)
      nq.push('q='+encodeURIComponent(this.query))
    if (this.color)
      nq.push('color='+encodeURIComponent(this.color))
    if (this.bgcolor)
      nq.push('bgcolor='+encodeURIComponent(this.bgcolor))
    if (this.bgimage)
      nq.push('bgimage='+encodeURIComponent(this.bgimage))
    if (this.time)
      nq.push('time='+this.time)
    if (nq.length == 0)
      this.__tileQuery = ''
    else
      this.__tileQuery = '?'+nq.join('&')
    if (reload_tiles != false) {
      for (var i=0; i<this.layers.length; i++) {
        this.layers[i].discardAllTiles()
      }
      this.updateTiles(this.pointerX, this.pointerY, 0)
    }
  },

  /*
   Pans map by (dx, dy) pixels.
  */
  panBy : function(dx, dy) {
    var need_update = false
    for (var i=0; i<this.layers.length; i++) {
      var rv = this.layers[i].panBy(dx, dy)
      need_update = need_update || rv
    }
    if (need_update)
      this.updateTiles(this.pointerX, this.pointerY, 0)
    this.x = this.layers[0].x
    this.y = this.layers[0].y
    return need_update
  },

  /**
   Zooms each layer to zoom z, with (pointer_x, pointer_y) as the origin.
  */
  zoom : function(z, pointer_x, pointer_y) {
    for (var i=0; i<this.layers.length; i++) {
      var layer = this.layers[i]
      layer.zoom(z, pointer_x, pointer_y)
    }
    this.x = this.layers[0].x
    this.y = this.layers[0].y
  },

  /**
   Does an animated zoom to level z, with (this.pointerX, this.pointerY) as the origin.
   The zoom duration is this.zoomDuration, and each frame will take a minimum of
   this.frameTime.
  */
  animatedZoom : function(z) {
    if (this.zoomIval) {
      this.targetZ = z
      return
    }
    var i = 0
    this.targetZ = z
    this.zoomDirection = (this.z < z ? 1 : -1)
    this.zoomStartTime = this.oldTime = new Date().getTime()
    if (this.zoomDirection == -1)
      this.updateTiles(this.pointerX, this.pointerY, this.zoomDirection, false)
    this.zoomIval = setInterval(this.zoomer, this.frameTime)
  },

  /**
   Does a single zoom animation step, calling this.zoom with the
   current zoom level, and updateTiles at the end of the zoom.
  */
  zoomStep : function() {
    this.currentTime = new Date().getTime()
    var elapsed = this.currentTime - this.zoomStartTime
    var frame_elapsed = (this.currentTime - this.oldTime)
    this.fps = 1000 / frame_elapsed
    this.frames++
    this.totalFrameTimes += frame_elapsed
    this.avgFps = 1000 / (this.totalFrameTimes / this.frames)
    if (elapsed >= this.zoomDuration){
      this.zoom(this.targetZ, this.pointerX, this.pointerY)
      clearInterval(this.zoomIval)
      this.zoomIval = false
      this.z = this.targetZ
      // discard tiles outside zoom
      this.updateTiles(this.pointerX, this.pointerY, this.zoomDirection, true)
    } else {
      var f = (elapsed / this.zoomDuration)
      var zi = this.z*(1-f) + this.targetZ*f
      this.zoom(zi, this.pointerX, this.pointerY)
    }
  },

  /**
   Updates the visible tileset. Discards tiles that aren't visible
   and loads the layer corresponding to target zoom.
  */
  updateTiles : function(pointer_x, pointer_y, dir, at_zoom_end) {
    if (dir == undefined) dir = 1
    if (this.z < 0 || this.targetZ < 0) return
    var occluded = false
    for(var z=this.layers.length-1; z>=0; z--) {
      var layer = this.layers[z]
      // discard all tiles with too high resolution
      if (z > this.targetZ) {
        layer.discardAllTiles()
        layer.hide()
        continue
      }

      // hide the layer if it can't be seen
      if (occluded)
        layer.hide()
      else
        layer.show()

      var border = 1
      if (z == this.targetZ) border = 3
      else if (dir == 0 && z == this.targetZ-2) border = 2

      for(var i=0; i<layer.tiles.length; i++) {
        var tile = layer.tiles[i]
        if (
          // discard tiles outside screen area
          (tile.X+1+border) * tile.rSize < -layer.x ||
          (tile.Y+1+border) * tile.rSize < -layer.y ||
          (tile.X  -border) * tile.rSize > -layer.x + this.width ||
          (tile.Y  -border) * tile.rSize > -layer.y + this.height
        ) {
          layer.discardTile(i)
          i--
        }
      }
      // Request tiles that have wanted zoom.
      // Preload a level from above when panning.
      // Keep z0 always loaded to avoid showing empty spots.
      if (z == 0 || z == this.targetZ || (dir == 0 && z == this.targetZ-2))
        layer.requestVisibleTiles(pointer_x, pointer_y, dir, at_zoom_end && z == this.targetZ)

      occluded = occluded || layer.coversWholeScreen(pointer_x, pointer_y, dir)
    }
  }

}



MapLayer = function(map, z) {
  this.map = map
  this.z = z
  this.own_fac = Math.pow(2, this.z)
  this.element = document.createElement("div")
  this.element.className = "mapLayer"
  this.element.style.position = "absolute"
  this.element.style.left = "0px"
  this.element.style.top = "0px"
  this.element.style.zIndex = this.z
  this.__tileOnload = this.makeTileOnload()
  this.tiles = []
}
MapLayer.prototype = {
  x : 0,
  y : 0,
  z : 0,
  cZ : 0,
  fac : 1,
  rfac : 1,
  own_fac : 1,

  unload : function() {
    this.discardAllTiles()
    delete this.map
    delete this.__tileOnload
    delete this.tiles
    delete this.element
  },

  hide : function() {
    this.element.style.display = 'none'
  },

  show : function() {
    this.element.style.display = 'block'
  },

  discardAllTiles : function() {
    while(this.tiles.length > 0) this.discardTile(0)
  },

  requestVisibleTiles : function(pointer_x, pointer_y, dir, load_info) {
    var tsz = this.map.tileSize * (this.fac / this.own_fac)
    var x0 = Math.floor((-this.x / tsz))
    var y0 = Math.floor((-this.y / tsz))
    var w = Math.ceil(this.map.width / tsz) + 1
    var h = Math.ceil(this.map.height / tsz) + 1
    if (dir == 0) {
      x0--
      y0--
      w++
      h++
    }
    for (var x=x0; x<x0+w; x++) {
      for (var y=y0; y<y0+h; y++) {
        if (!this.tiles[x + ":" + y]) {
          var tile = this.makeTile(x, y, load_info)
          this.tiles.push(tile)
          this.tiles[x + ":" + y] = tile
          tile.zoom(this.cZ)
          var tx = this.x + ((tile.X+0.5) * tile.rSize)
          var ty = this.y + ((tile.Y+0.5) * tile.rSize)
          var dx = (pointer_x-tx)
          var dy = (pointer_y-ty)
          this.map.loader.load(-this.z*(dir < 0 ? -1 : 1), dir*dx*dx+dy*dy, this, tile)
        }
      }
    }
  },

  coversWholeScreen : function(pointer_x, pointer_y, dir) {
    var tsz = this.map.tileSize * (this.fac / this.own_fac)
    if (dir < 0) tsz *= 0.5 // hack to avoid grey tiles on zooming out
    var x0 = Math.floor((-this.x / tsz))
    var y0 = Math.floor((-this.y / tsz))
    var w = Math.ceil(this.map.width / tsz) + 1
    var h = Math.ceil(this.map.height / tsz) + 1
    for (var x=x0; x<x0+w; x++) {
      for (var y=y0; y<y0+h; y++) {
        var tile = this.tiles[x + ":" + y]
        if (!tile || !tile.parentNode) return false
      }
    }
    return true
  },

  discardTile : function(i) {
    var tile = this.tiles[i]
    delete this.tiles[tile.X + ":" + tile.Y]
    this.tiles.splice(i,1)
    tile.loading = false
    tile.removeEventListener('load', this.__tileOnload, false)
    if (tile.parentNode)
      tile.parentNode.removeChild(tile)
    this.map.loader.cancel(this, tile)
    if (tile.handleInfo) {
      delete tile.handleInfo
      if (tile.ImageMap) {
        if (tile.ImageMap.parentNode)
         tile.removeChild(tile.ImageMap)
        delete tile.ImageMap
        tile.useMap = false
      }
    }
    if (tile.loaded) tile.loaded(false)
    delete tile.query
    delete tile.load
    delete tile.zoom
    tile.className = null
    tile.style.position = null
    this.map.pool.put(tile)
  },

  panBy : function(dx, dy) {
    var ox = Math.floor(this.x / this.map.tileSize)
    var oy = Math.floor(this.y / this.map.tileSize)
    var ox2 = Math.floor((this.x + this.map.width) / this.map.tileSize)
    var oy2 = Math.floor((this.y + this.map.height) / this.map.tileSize)
    this.x += dx
    this.y += dy
    this.element.style.left = this.x + 'px'
    this.element.style.top = this.y + 'px'
    var nx = Math.floor(this.x / this.map.tileSize)
    var ny = Math.floor(this.y / this.map.tileSize)
    var nx2 = Math.floor((this.x + this.map.width) / this.map.tileSize)
    var ny2 = Math.floor((this.y + this.map.height) / this.map.tileSize)
    if (ox != nx || oy != ny || ox2 != nx2 || oy2 != ny2)
      return true
    return false
  },

  zoom : function(outer_z, pointer_x, pointer_y) {
    this.rx = (-this.x + pointer_x) * this.rfac
    this.ry = (-this.y + pointer_y) * this.rfac
    var fac = Math.pow(2, outer_z)
    this.panBy(-this.rx * (fac-this.fac), -this.ry * (fac-this.fac))
    this.fac = fac
    this.rfac = 1 / fac
    this.cZ = outer_z
    for (var j=0; j<this.tiles.length; j++) {
      this.tiles[j].zoom(outer_z)
    }
  },

  makeTile : function(x, y, load_info) {
    var tile = this.map.pool.get()
    tile.className = "tile"
    tile.style.position = 'absolute'
    tile.X = x
    tile.Y = y
    tile.Z = this.z
    tile.relativeURL = this.map.coordinateMapper(x, y, this.z)
    tile.Size = this.map.tileSize
    tile.loading = false
    tile.style.visibility = 'hidden'
    tile.filePrefix = this.map.__filePrefix
    tile.itemPrefix = this.map.__itemPrefix
    tile.itemSuffix = this.map.__itemSuffix
    tile.query = this.map.__tileQuery
    tile.load = this.__tileLoad
    tile.addEventListener('load', this.__tileOnload, false)
    tile.zoom = this.__tileZoom
    return tile
  },

  __tileLoad : function(server, infoManager) {
    this.src = server + this.relativeURL + this.query
    this.loading = true
    this.handleInfo = function(infos) {
      if (!infos) return
      this.ImageMap = E('map')
      this.ImageMap.name = this.src
      this.appendChild(this.ImageMap)
      for(var i=0; i<infos.length; i++) {
        var info = infos[i]
        var area = E('area')
        Object.extend(area, ItemArea)
        area.info = info
        area.shape = 'rect'
        area.coords = [info.x, info.y, info.x + info.sz, info.y + info.sz].join(",")
        area.href = this.filePrefix + info.path
        area.title = area.getTitle()
        area.itemHREF = this.itemPrefix + info.path + this.itemSuffix
        this.ImageMap.appendChild(area)
      }
      this.useMap = '#'+this.src
    }
    infoManager.requestInfo(this.X*this.Size, this.Y*this.Size, this.Z, this)
  },

  makeTileOnload : function() {
    var t = this
    return function() {
      if (this.loading) {
        t.element.appendChild(this)
        this.style.visibility = 'inherit'
        this.loading = false
      }
    }
  },

  __tileZoom : function(outer_z) {
    var fac = Math.pow(2, outer_z - this.Z)
    this.rSize = this.Size * fac
    this.style.left = Math.floor(this.X * this.rSize) + 'px'
    this.style.top = Math.floor(this.Y * this.rSize) + 'px'
    this.style.width = Math.ceil(this.rSize) + 'px'
    this.style.height = Math.ceil(this.rSize) + 'px'
  }
}

ImagePool = function(){
  this.pool = []
}
ImagePool.prototype = {

  get : function() {
    if (this.pool.length == 0) {
      this.pool.push(document.createElement("img"))
    }
    return this.pool.shift()
  },

  put : function(img) {
    this.pool.push(img)
  }

}

Loader = function(servers, infoServers) {
  this.servers = servers
  this.queue = new PriorityQueue()
  this.tileInfoManager = new TileInfoManager(infoServers)
  var t = this
  this.loaded = function(completed){
    delete this.loaded
    this.removeEventListener("load", t.loaded, true)
    this.removeEventListener("abort", t.loaded, true)
    this.removeEventListener("error", t.loaded, true)
    if (completed) t.totalCompletes++
    t.loads--
    t.process()
  }
}
Loader.prototype = {
  totalLoads : 0,
  totalRequests : 0,
  totalCancels : 0,
  totalCompletes : 0,

  loads : 0,
  maxLoads : 2,
  tileSize : 0.125, // in Mbps
  bandwidthLimit : -0.3, // in Mbps, negative values for no limit

  load : function(dZ, dP, layer, tile) {
    var lt = {layer: layer, tile: tile}
    this[layer.z+':'+tile.X+':'+tile.Y] = lt
    this.queue.insert(lt, [dZ, dP])
    this.totalRequests++
    this.process()
  },

  setServers : function(s) {
    this.servers = s
  },

  setInfoServers : function(s) {
    this.tileInfoManager.servers = s
  },

  process : function() {
    while ((this.loads < this.maxLoads) && !this.queue.isEmpty()) {
      var lt = this.queue.shift()
      lt.tile.loaded = this.loaded
      lt.tile.addEventListener("load", this.loaded, true)
      lt.tile.addEventListener("abort", this.loaded, true)
      lt.tile.addEventListener("error", this.loaded, true)
      this.loads++
      delete this[lt.layer.z+':'+lt.tile.X+':'+lt.tile.Y]
      var t = this
      if (this.bandwidthLimit > 0) {
        setTimeout(function(){
          if (lt.tile.load)
            lt.tile.load(t.rotateServers(), t.tileInfoManager)
        }, 1000 * ((this.tileSize * this.maxLoads) / this.bandwidthLimit))
      } else {
        setTimeout(function(){
          if (lt.tile.load)
            lt.tile.load(t.rotateServers(), t.tileInfoManager)
        }, 0)
        // hack to make zooming out a bit less of a pain
        // if zooming out and answering queries instantly from cache
      }
      this.totalLoads++
    }
  },

  rotateServers : function() {
    this.servers.push(this.servers.shift())
    return this.servers[0]
  },

  cancel : function(layer, tile) {
    var lt = this[layer.z+':'+tile.X+':'+tile.Y]
    if (lt) {
      this.queue.remove(lt)
      this.totalCancels++
    }
    this.process()
  }

}


TileInfoManager = function(servers) {
  this.servers = servers
  this.request_bundle = []
  this.cache = {}
  var t = this
  this.sendBundle = function(){
    t.bundleSender()
  }
}
TileInfoManager.prototype = {

  callbackDelay : 50,

  requestInfo : function(x,y,z, callback) {
    var rv = this.getCachedInfo(x,y,z)
    if (rv && callback.handleInfo)
      callback.handleInfo(rv)
    else
      this.bundleRequest(x,y,z, callback)
  },

  getCachedInfo : function(x,y,z) {
    if (!this.cache[z]) return false
    return this.cache[z][x+':'+y]
  },

  bundleRequest : function(x,y,z, callback) {
    this.request_bundle.push([[x,y,z],callback])
    if (this.requestTimeout) clearTimeout(this.requestTimeout)
    this.requestTimeout = setTimeout(this.sendBundle, 150)
  },

  bundleSender : function() {
    var reqs = []
    var callbacks = []
    var reqb = this.request_bundle
    this.request_bundle = []
    for (var i=0; i<reqb.length; i++) {
      var req = reqb[i][0]
      var info = this.getCachedInfo(req[0], req[1], req[2])
      if (!info) {
        reqs.push(req)
        callbacks.push(reqb[i][1])
      } else if (reqb[i][1].handleInfo)
        this.callbackHandler(reqb[i][1], info)
    }
    var t = this
    new Ajax.Request(this.rotateServers(), {
      method : 'post',
      parameters : {
        tiles : Object.toJSON(reqs)
      },
      onSuccess : function(res) {
        var infos = res.responseText.evalJSON()
        for (var i=0; i<reqs.length; i++) {
          var info = infos[i]
          var req = reqs[i]
          var callback = callbacks[i]
          if (!t.cache[req[2]])
            t.cache[req[2]] = {}
          t.cache[req[2]][req[0]+':'+req[1]] = info
          if (callback.handleInfo)
            t.callbackHandler(callback, info)
        }
      },
      onFailure : function(res) {
        for (var i=0; i<callbacks.length; i++) {
          var callback = callbacks[i]
          if (callback.handleInfo)
            callback.handleInfo(false)
        }
      }
    })
    this.requestTimeout = false
  },

  callbackHandler : function(callback, info) {
    setTimeout(this.makeCallbackHandler(callback, info), this.callbackDelay)
  },

  makeCallbackHandler : function(callback, info) {
    return function(){ if (callback.handleInfo) callback.handleInfo(info) }
  },

  rotateServers : function() {
    this.servers.push(this.servers.shift())
    return this.servers[0]
  }

}


PriorityQueue = function(){
  this.queue = []
}
PriorityQueue.prototype = {

  insert : function(item, priority) {
    for (var i=0; i<this.queue.length; i++) {
      if (this.queue[i].priority[0] > priority[0] ||
          (this.queue[i].priority[0] == priority[0] &&
          this.queue[i].priority[1] > priority[1])
      ) {
        this.queue.splice(i,0, {priority: priority, value: item})
        return
      }
    }
    this.queue.push({priority: priority, value: item})
  },

  remove : function(item) {
    for (var i=0; i<this.queue.length; i++) {
      if (this.queue[i].value == item) {
        this.queue.splice(i,1)
        return
      }
    }
  },

  shift : function() {
    if (this.queue.length == 0) return false
    return this.queue.shift().value
  },

  isEmpty : function() {
    return this.queue.length == 0
  }

}
