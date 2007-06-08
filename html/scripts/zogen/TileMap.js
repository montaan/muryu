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
  'TileMap.DblClickToEditTitle' : 'Double-click to edit search terms',
  'TileMap' : 'Search',
  'TileMap.EditTitle' : 'Edit search terms',
  'TileMap.RemoveMap' : 'Remove search',
  'TileMap.ShowColors' : 'Color items',
  'Item.open' : 'Open',
  'Item.select' : 'Select',
  'Item.click_to_inspect' : 'Left-click to inspect ',
  'Item.add_to_playlist' : 'Add to playlist',
  'Item.view_in_slideshow' : 'View in slideshow',
  'Item.makePublic' : 'Make public',
  'Item.makePrivate' : 'Make private',
  'Selection' : 'Selection',
  'Selection.clear' : 'Clear selection',
  'Selection.deselect' : 'Deselect',
  'Selection.makePublic' : 'Make public',
  'Selection.makePrivate' : 'Make private',
  'Selection.delete_all' : 'Delete all',
  'Selection.undelete_all' : 'Undelete all',
  'Selection.add_to_playlist' : 'Add to playlist',
  'Selection.create_presentation' : 'Create presentation'
})
Tr.addTranslations('fi-FI', {
  'TileMap.DblClickToEditTitle' : 'Kaksoisnapsauta muokataksesi hakua',
  'TileMap' : 'Haku',
  'TileMap.EditTitle' : 'Muokkaa hakua',
  'TileMap.RemoveMap' : 'Poista haku',
  'TileMap.ShowColors' : 'Väritä tiedostot',
  'Item.open' : 'Avaa',
  'Item.select' : 'Valitse',
  'Item.click_to_inspect' : 'Napsauta nähdäksesi ',
  'Item.add_to_playlist' : 'Lisää soittolistaan',
  'Item.view_in_slideshow' : 'Näytä kuvaesityksessä',
  'Item.makePublic' : 'Tee julkiseksi',
  'Item.makePrivate' : 'Tee yksityiseksi',
  'Selection' : 'Valinta',
  'Selection.clear' : 'Tyhjennä valinta',
  'Selection.deselect' : 'Poista valinnasta',
  'Selection.makePublic' : 'Tee julkiseksi',
  'Selection.makePrivate' : 'Tee yksityiseksi',
  'Selection.delete_all' : 'Poista kaikki',
  'Selection.undelete_all' : 'Tuo kaikki takaisin',
  'Selection.add_to_playlist' : 'Lisää soittolistaan',
  'Selection.create_presentation' : 'Luo esitys'
})


ItemArea = {
  deleteItem : function() {
    new Desk.Window(this.itemHREF.replace(/json$/, 'delete'))
  },
  
  undelete : function() {
    new Desk.Window(this.itemHREF.replace(/json$/, 'undelete'))
  },

  edit : function() {
    new Desk.Window(this.itemHREF.replace(/json$/, 'edit'))
  },
  
  defaultAction : function() {
    var ext = this.getExt()
    if (['jpeg','jpg','png','gif'].include(ext)) {
      this.viewInSlideshow()
    } else if ( MusicPlayer && ext == 'mp3' ) {
      MusicPlayer.addToPlaylist(this.href)
      MusicPlayer.goToIndex(MusicPlayer.playlist.length - 1)
    } else if (ext == 'html') {
      window.open(this.href, '_tab')
    } else {
      this.open()
    }
  },
  
  open : function() {
    new Desk.Window(this.itemHREF)
  },

  getTitle : function() {
    return Tr('Item.click_to_inspect', this.info.path.split("/").last())
  },

  toggleSelect : function() {
    this.getMap().selection.toggle(this)
  },

  getExt : function() {
    return this.href.split(".").last().toString().toLowerCase()
  },

  addToPlaylist : function() {
    if (MusicPlayer && this.getExt() == 'mp3')
      MusicPlayer.addToPlaylist(this.href)
  },
  
  viewInSlideshow : function() {
    var m = this.getMap()
    if (m.slideshowWindow) {
      if (!m.slideshowWindow.windowManager)
        m.slideshowWindow.setWindowManager(Desk.Windows)
      m.slideshowWindow.slideshow.showIndex(this.info.index)
    } else {
      m.slideshowWindow = Slideshow.make(this.info.index, m.query)
    }
  },

  oncontextmenu : function(ev) {
    if (!ev.ctrlKey) {
      var menu = new Desk.Menu()
      menu.addTitle(this.href.split("/").last())
      menu.addItem(Tr('Item.open'), this.open.bind(this))
      menu.addItem(Tr('Item.select'), this.toggleSelect.bind(this))
      var ext = this.getExt()
      if (ext == 'mp3') {
        menu.addSeparator()
        menu.addItem(Tr('Item.add_to_playlist'), this.addToPlaylist.bind(this))
      } else if (ext.match(/^(jpe?g|png|gif)$/)) {
        menu.addSeparator()
        menu.addItem(Tr('Item.view_in_slideshow'), this.viewInSlideshow.bind(this))
      }
      menu.addSeparator()
      menu.addItem(Tr('Button.Item.edit'), this.edit.bind(this))
      menu.addItem(Tr('Item.makePublic'), this.makePublic.bind(this))
      menu.addItem(Tr('Item.makePrivate'), this.makePrivate.bind(this))
      menu.addSeparator()
      if (this.info.deleted == 't')
        menu.addItem(Tr('Button.Item.undelete_item'), this.undelete.bind(this))
      else
        menu.addItem(Tr('Button.Item.delete_item'), this.deleteItem.bind(this))
      menu.skipHide = true
      menu.show(ev)
      Event.stop(ev)
    }
  },

  makePublic : function() {
    new Ajax.Request(this.itemHREF.replace(/json$/, 'make_public'), {
      onSuccess : function(res) {
        this.deselect()
      }.bind(this)
    })
  },

  makePrivate : function() {
    new Ajax.Request(this.itemHREF.replace(/json$/, 'make_private'), {
      onSuccess : function(res) {
        this.deselect()
      }.bind(this)
    })
  },

  onclick : function(ev) {
    if (Event.isLeftClick(ev)) {
      if (this.Xdown == undefined ||
          (Math.abs(this.Xdown - ev.clientX) < 3 &&
           Math.abs(this.Ydown - ev.clientY) < 3)
      ) {
        if (ev.ctrlKey) {
          this.getMap().selection.toggle(this)
        } else if (ev.shiftKey) {
          this.getMap().selection.spanTo(this)
        } else {
          this.defaultAction()
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
  },

  getTile : function() {
    if (this.parentNode)
      return this.parentNode.parentNode
  },

  getMap : function() {
    return this.getTile().map
  },
  
  onselect : function() {
    var tile = this.getTile()
    var s = E('div')
    this.selectionIndicator = s
    s.item = this
    s.selection = tile.map.selection
    s.style.position = 'absolute'
    s.X = (tile.X * (tile.Size / this.info.sz) + (this.info.x / this.info.sz))
    s.Y = (tile.Y * (tile.Size / this.info.sz) + (this.info.y / this.info.sz))
    s.style.left = s.X * this.info.sz * (tile.rSize/tile.Size) + 'px'
    s.style.top = s.Y * this.info.sz * (tile.rSize/tile.Size) + 'px'
    s.style.width = this.info.sz * (tile.rSize/tile.Size) + 'px'
    s.style.height = this.info.sz * (tile.rSize/tile.Size) + 'px'
    s.style.backgroundColor = 'cyan'
    s.style.opacity = 0.5
    s.onmousedown = function(e) {
      this.downX = e.clientX
      this.downY = e.clientY
    }
    s.onclick = function(e) {
      if (Event.isLeftClick(e) &&
          (this.downX == undefined || this.downY == undefined) ||
          (Math.abs(this.downX - e.clientX) < 3 &&
           Math.abs(this.downY - e.clientY) < 3   )
      ) {
        if (!e.ctrlKey)
          this.selection.clear()
        else
          this.selection.toggle(this.item)
      }
    }
    s.oncontextmenu = s.selection.oncontextmenu
    tile.map.selectionLayer.element.appendChild(s)
  },
  
  ondeselect : function() {
    $(this.selectionIndicator).detachSelf()
  }
  
}


Selection = function() {
  this.items = new Hash()
}
Selection.prototype = {
  lastSelected : null,
  
  oncontextmenu : function(ev) {
    if (!ev.ctrlKey) {
      var menu = new Desk.Menu()
      menu.addTitle(Tr('Selection'))
      menu.addItem(Tr('Selection.add_to_playlist'), this.selection.addToPlaylist.bind(this.selection))
      menu.addItem(Tr('Selection.create_presentation'))
      menu.addSeparator()
      menu.addItem(Tr('Selection.makePublic'), this.selection.makePublic.bind(this.selection))
      menu.addItem(Tr('Selection.makePrivate'), this.selection.makePrivate.bind(this.selection))
      menu.addSeparator()
      menu.addItem(Tr('Selection.delete_all'), this.selection.deleteSelected.bind(this.selection))
      menu.addItem(Tr('Selection.undelete_all'), this.selection.undeleteSelected.bind(this.selection))
      menu.addSeparator()
      menu.addItem(Tr('Selection.deselect'), function() { this.selection.deselect(this.item) }.bind(this))
      menu.addItem(Tr('Selection.clear'), this.selection.clear.bind(this.selection))
      menu.skipHide = true
      menu.show(ev)
      Event.stop(ev)
    }
  },

  deselect : function(obj) {
    if (!this.items[obj.itemHREF]) return
    var s = this.items[obj.itemHREF]
    delete this.items[obj.itemHREF]
    if (s.ondeselect) s.ondeselect()
    this.lastSelected = s
  },

  select : function(obj) {
    if (this.items[obj.itemHREF]) return
    this.items[obj.itemHREF] = obj
    if (obj.onselect) obj.onselect()
    this.lastSelected = obj
  },
  
  toggle : function(obj) {
    if (this.items[obj.itemHREF]) {
      this.deselect(obj)
    } else {
      this.select(obj)
    }
  },

  clear : function() {
    this.items.values().each(this.deselect.bind(this))
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
    this.items.values().invoke('deleteItem')
  },
  
  undeleteSelected : function() {
    this.items.values().invoke('undelete')
  },

  addToPlaylist : function() {
    this.items.values().invoke('addToPlaylist')
  },
  
  makePublic : function() {
    this.items.values().invoke('makePublic')
  },

  makePrivate : function() {
    this.items.values().invoke('makePrivate')
  },

  addTags : function(tags) {
    this.items.values().invoke('addTags', tags)
  },
  
  removeTags : function(tags) {
    this.items.values().invoke('removeTags', tags)
  },
  
  setTags : function(tags) {
    this.items.values().invoke('setTags', tags)
  },
  
  addGroups : function(groups) {
    this.items.values().invoke('addGroups', groups)
  },
  
  removeGroups : function(groups) {
    this.items.values().invoke('removeGroups', groups)
  },
  
  setGroups : function(groups) {
    this.items.values().invoke('setGroups', groups)
  },
  
  addSets : function(sets) {
    this.items.values().invoke('addSets', sets)
  },
  
  removeSets : function(sets) {
    this.items.values().invoke('removeSets', sets)
  },
  
  setSets : function(sets) {
    this.items.values().invoke('setSets', sets)
  }
  
}


/*
* Creates a new TileMap inside the passed element.
*/
TileMap = function(config) {
  if (config)
    Object.extend(this, config)
  this.selection = new Selection()
  this.root = this
  this.parent = this
  this.layerCount = this.noTiles ? 0 : this.maxZoom + 1
  this.element = document.createElement('div')
  this.element.isMap = true
  this.element.style.position = 'absolute'
  this.element.style.left = this.left + 'px'
  this.element.style.top = this.top + 'px'
  this.element.style.backgroundColor = (this.noTiles ? '#'+this.bgcolor : 'gray')
  this.element.left = this.left
  this.element.top = this.top
  this.element.width = this.width
  this.element.height = this.height
  if (this.width && this.height) {
    this.element.style.width = this.width + 'px'
    this.element.style.height = this.height + 'px'
  }
  this.element.style.zIndex = 0
  this.element.style.overflow = 'hidden'
  this.element.map = this
  if (!this.isSubmap) {
    this.container = Desk.Windows.windowContainer
    this.container.appendChild(this.element)
  }
  this.layers = []
  this.children = []
  this.loader = new Loader(this, this.tileServers, this.tileInfoServers)
  this.pool = ImagePool.getPool()
  this.init()
  if (!this.isSubmap) {
    Desk.Windows.addListener('resize', function(v){
      this.setWidth(v.width)
      this.setHeight(v.height)
    }.bind(this))
  }
  if (this.submaps) {
    var nc = this.submaps.map(Session.loadDump)
    nc.invoke('setParent', this)
  }
  if (!this.isSubmap) {
    Map = this
    window.lastFocusedMap = this
    document.focusedMap = this
    Session.add(this)
  }
}
TileMap.loadSession = function(data){
  var tm = new TileMap(data)
  if (!tm.isSubmap)
    Map = tm
  return tm
}
TileMap.prototype = {

  dumpLoader : 'TileMap',

  dumpSession : function() {
    var dump = {
      left: this.left,
      top : this.top,
      width : this.width,
      height : this.height,
      relativeZ : this.relativeZ,
      x: this.x,
      y: this.y,
      z: this.targetZ,
      noTiles : this.noTiles,
      title : this.title,
      query: this.query,
      color: this.color,
      bgcolor : this.bgcolor,
      bgimage : this.bgimage,
      isSubmap : !(this.parent == this),
      submaps : this.children.invoke('dumpSession')
    }
    return {
      loader: this.dumpLoader,
      data: dump
    }
  },

  parent : null,

  tileServers : ['/tile/'],
  tileInfoServers : ['/tile_info/'],

  query : '',
  color : 'true',
  bgcolor : '03233C',
  bgimage : false,

  __tileQuery : '',
  __filePrefix : '/files/',
  __itemPrefix : '/items/',
  __itemSuffix : '/json',

  time : new Date().getTime(),

  panAmount : 64,

  left : 0,      // submap left coord
  top : 0,       // submap top coord
  width : null,  // submap width
  height : null, // submap height
  relativeZ : 0, // submap zoom change wrt parent map

  x : 0, // pan x coord
  y : 0, // pan y coord
  z : 0, // current zoom
  targetZ : 0, // target zoom

  maxZoom : 10, // max zoom of the map (should get from the server)

  pointerX : 0,
  pointerY : 0,

  frameTime : 16, // in milliseconds
  zoomDuration : 200, // in milliseconds

  frames : 0,
  totalFrameTimes : 0,
  fps : 0,
  avgFps : 0,

  tileSize : 256,


  setParent : function(p) {
    if (this.parent) this.parent.removeChild(this)
    this.parent = p
    if (this.parent) {
      this.root = p.root
      this.parent.addChild(this)
    } else {
      this.root = null
    }
  },

  detachSelf : function() {
    this.setParent(null)
  },

  addChild : function(c) {
    if (!this.children.include(c))
      this.children.push(c)
    c.setContainer(this.submapLayer.element)
    this.zoom(this.z,0,0)
    this.updateTiles(0,0,0)
  },

  removeChild : function(c) {
    this.children.deleteFirst(c)
    c.setContainer(null)
  },

  setContainer : function(c) {
    if (this.container) {
      $(this.element).detachSelf()
      $(this.titleElem).detachSelf()
    }
    this.container = c
    if (this.container) {
      this.container.appendChild(this.element)
      this.container.appendChild(this.titleElem)
    }
  },


  /**
    Key handlers for the map
  */
  getKeyHandlers : function() {
    if (!this.keyHandlers) {
      this.keyHandlers = {
        't' : function(){ this.animatedZoom(this.z+1) },
        'g' : function(){ this.animatedZoom(this.z-1) },
        'z' : function(){ this.animatedZoom(this.z+1) },
        'x' : function(){ this.animatedZoom(this.z-1) },
        'f' : function(){ this.panRight() },
        'e' : function(){ this.panUp() },
        's' : function(){ this.panLeft() },
        'd' : function(){ this.panDown() }
      }
      var kh = this.keyHandlers
      kh[Event.KEY_RIGHT] = function(){ this.panRight() }
      kh[Event.KEY_UP]    = function(){ this.panUp() }
      kh[Event.KEY_LEFT]  = function(){ this.panLeft() }
      kh[Event.KEY_DOWN]  = function(){ this.panDown() }
    }
    return this.keyHandlers
  },

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
    if (this.isSubmap) {
      this.titleElem = E('h3', this.title || this.query, null, 'mapTitle', {
        position: 'absolute',
        top: (this.element.top - 20) + 'px',
        left: this.element.left + 'px',
        fontSize: '12px',
        color: 'white',
        zIndex: 49,
        cursor: 'move',
        whiteSpace: 'nowrap'
      })
      this.titleElem.title = Tr('TileMap.DblClickToEditTitle')
      this.titleElem.map = this
    }
    var t = this
    this.targetZ = this.z
    this.zoomer = function(){ t.zoomStep() }
    for (var i=0; i<this.layerCount; i++) {
      var layer = new MapLayer(this, i)
      this.layers.push(layer)
      this.element.appendChild(layer.element)
    }
    this.selectionLayer = new SelectionLayer(this)
    this.element.appendChild(this.selectionLayer.element)
    this.submapLayer = new SubmapLayer(this)
    this.element.appendChild(this.submapLayer.element)
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
    this.x = this.submapLayer.x
    this.y = this.submapLayer.y
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
    this.titleDragStart = function(ev) {
      if (Event.isLeftClick(ev)) {
        window.lastFocusedMap = this.map
        this.dragging = true
        this.dragX = Event.pointerX(ev)
        this.dragY = Event.pointerY(ev)
        Event.stop(ev)
      }
    }
    this.titleDragEnd = function(ev) {
      this.dragging = false
    }
    this.titleDrag = function(ev) {
      if (this.dragging) {
        var x = Event.pointerX(ev)
        var y = Event.pointerY(ev)
        var dx = x - this.dragX
        var dy = y - this.dragY
        t.moveBy(dx,dy)
        this.dragX = x
        this.dragY = y
        Event.stop(ev)
      }
    }
    this.titleEdit = function(ev) {
      if (!ev || Event.isLeftClick(ev)) {
        $(this).replaceWithEditor(function(val) {
          this.innerHTML = val
          this.map.setQuery(val)
        }.bind(this))
      }
    }
    if (this.titleElem) {
      this.titleElem.ondblclick = this.titleEdit
      this.titleElem.onmousedown = this.titleDragStart
      document.addEventListener('mouseup', this.titleDragEnd.bind(this.titleElem), false)
      document.addEventListener('mousemove', this.titleDrag.bind(this.titleElem), false)
      this.titleMenu = new Desk.Menu()
      this.titleMenu.addTitle(Tr('TileMap'))
      this.titleMenu.addItem(Tr('TileMap.EditTitle'), this.titleEdit.bind(this.titleElem))
      this.titleMenu.addItem(Tr('TileMap.ShowColors'), function(){
        if (this.color != 'false') {
          this.titleMenu.uncheckItem(Tr('TileMap.ShowColors'))
          this.setColor('false')
        } else {
          this.titleMenu.checkItem(Tr('TileMap.ShowColors'))
          this.setColor('true')
        }
      }.bind(this))
      this.titleMenu.checkItem(Tr('TileMap.ShowColors'))
      if (this.color == 'false')
        this.titleMenu.uncheckItem(Tr('TileMap.ShowColors'))
      this.titleMenu.addSeparator()
      this.titleMenu.addItem(Tr('TileMap.RemoveMap'), this.detachSelf.bind(this))
      this.titleMenu.bind(this.titleElem)
    }
    if (this.isSubmap) return
    this.onmousedown = function(ev) {
      window.focus()
      document.focusedMap = this
      var obj = ev.target
      while (!obj.map && obj.parentNode)
        obj = obj.parentNode
      if (obj)
        window.lastFocusedMap = obj.map
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
          t.selected = new Hash()
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
      document.focusedMap = this
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
        var obj = ev.target
        while (obj && !obj.map) {
          obj = obj.parentNode
        }
        if (obj)
          obj.map.selectUnderSelection()
        Event.stop(ev)
      }
    }
    this.onmousescroll = function(ev) {
      if (ev.detail < 0) {
        t.animatedZoom(t.z+1)
      } else {
        t.animatedZoom(t.z-1)
      }
      Event.stop(ev)
    }
    this.onkeypress = function(ev) {
      if (ev.target.tagName == 'INPUT') return
      if (document.focusedMap == this && !ev.ctrlKey) {
        var c = ev.keyCode | ev.charCode | ev.which
        var cs = String.fromCharCode(c).toLowerCase()
        var keyHandlers = t.getKeyHandlers()
        var h = keyHandlers[c] || keyHandlers[cs]
        if (h) h.apply(t, [c,cs])
        Event.stop(ev)
      }
    }
    this.onunload = function(ev) {
      t.unload()
    }
    this.element.addEventListener("mousedown", this.onmousedown, false)
    document.addEventListener("mouseup", this.onmouseup, false)
    this.element.addEventListener("mousemove", this.onmousemove, false)
    this.element.addEventListener("DOMMouseScroll", this.onmousescroll, false)
    document.addEventListener("keypress", this.onkeypress, false)
    document.addEventListener("unload", this.onunload, false)
  },
  
  /**
   Removes event listeners from element and document,
   then deletes the event listener functions.
  */
  removeEventListeners : function() {
    this.element.removeEventListener("mousedown", this.onmousedown, false)
    document.removeEventListener("mouseup", this.titleDragEnd, false)
    document.removeEventListener("mousemove", this.titleDrag, false)
    document.removeEventListener("mouseup", this.onmouseup, false)
    this.element.removeEventListener("mousemove", this.onmousemove, false)
    this.element.removeEventListener("DOMMouseScroll", this.onmousescroll, false)
    document.removeEventListener("keypress", this.onkeypress, false)
    document.removeEventListener("unload", this.onunload, false)
    delete this.onmousemove
    delete this.onmousescroll
    delete this.onkeypress
    delete this.onunload
  },

  /**
    Selects all items that intersect the lasso selection box (selectionElem).
  */
  selectUnderSelection : function() {
    var z = Math.max(Math.min(this.targetZ, this.layerCount-1), 0)
    var layer = this.layers[z]
    var lx = layer.x
    var ly = layer.y
    var tsz = this.tileSize
    if (this.isSubmap){
      this.selectionElem = this.root.selectionElem
      lx = this.root.x
      ly = this.root.y
      var obj = this
      while (obj.parent != obj) {
        lx += obj.parent.submapLayer.fac * obj.left
        ly += obj.parent.submapLayer.fac * obj.top
        obj = obj.parent
      }
    }
    this.selectionElem.map = this
    var left = -lx + parseInt(this.selectionElem.style.left)
    var top = -ly + parseInt(this.selectionElem.style.top)
    var width = parseInt(this.selectionElem.style.width)
    var height = parseInt(this.selectionElem.style.height)
    var l = Math.floor(left / tsz)
    var t = Math.floor(top / tsz)
    var r = Math.ceil((left+width) / tsz)
    var b = Math.ceil((top+height) / tsz)
    var previousSelection = this.selected || new Hash()
    this.selected = new Hash()
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
              !(this.selected[area.itemHREF]) && // not already processed
              this.intersect(left, top, width, height,
                             area.info.x+tx, area.info.y+ty, area.info.sz, area.info.sz)
            ) {
              var pr = previousSelection[area.itemHREF]
              // If the item was in previous selected, but not from this area,
              // use the previous selected and skip this one.
              if (pr && pr != area) {
                this.selected[area.itemHREF] = pr
              } else {
                if (!pr) // not previously selected
                  area.toggleSelect()
                this.selected[area.itemHREF] = area
              }
            }
          }
        }
      }
    }
    var s = this.selected
    // deselect all that fell out of selection
    previousSelection.each(function(kv,i) {
      if (!s[kv[0]]) 
        kv[1].toggleSelect()
    })
  },

  /**
   * Box intersection test.
   */
  intersect : function(x1,y1,w1,h1, x2,y2,w2,h2) {
    return !(x1 > x2+w2 || y1 > y2+h2 || x1+w1 < x2 || y1+h1 < y2)
  },

  /**
   Sets map width to w, updates element width and visible tiles as well.
  */
  setWidth : function(w) {
    this.width = w
    this.element.width = w
    this.element.style.width = this.width + 'px'
    this.updateTiles(this.pointerX, this.pointerY, 1)
  },

  /**
   Sets map height to w, updates element height and visible tiles as well.
  */
  setHeight : function(h) {
    this.height = h
    this.element.height = h
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
    if (this.noTiles) this.element.style.backgroundColor = '#'+q
    this.children.invoke('setBgcolor',q)
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
    this.loader.flushCache()
    if (reload_tiles != false) {
      for (var i=0; i<this.layers.length; i++) {
        this.layers[i].discardAllTiles()
      }
      this.updateTiles(this.pointerX, this.pointerY, 0)
    }
    var params = {}
    if (this.query)
      params.q = this.query
    if (this.time)
      params.time = this.time
    if (this.lastQuery != this.query) {
      this.lastQuery = this.query
      new Ajax.Request('/tile_info', {
        parameters : params,
        onSuccess : function(res) {
          var obj = res.responseText.evalJSON()
          var dims = obj.dimensions
          this.tileInfo = obj
          if (this.isSubmap) {
            this.width = obj.dimensions.width
            this.height = obj.dimensions.height
            if (this.parent != this) {
              this.parent.submapLayer.zoom(this.parent.z,0,0)
            }
          }
        }.bind(this)
      })
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
    this.selectionLayer.panBy(dx, dy)
    this.submapLayer.panBy(dx, dy)
    if (need_update)
      this.updateTiles(this.pointerX, this.pointerY, 0)
    this.x = this.submapLayer.x
    this.y = this.submapLayer.y
    return need_update
  },

  /**
    Pan to left by amt or this.panAmount.
  */
  panLeft : function(amt) {
    if (!amt) amt = this.panAmount
    this.panBy(amt, 0)
  },
  
  /**
    Pan to right by amt or this.panAmount.
  */
  panRight : function(amt) {
    if (!amt) amt = this.panAmount
    this.panBy(-amt, 0)
  },
  
  /**
    Pan up by amt or this.panAmount.
  */
  panUp : function(amt) {
    if (!amt) amt = this.panAmount
    this.panBy(0, amt)
  },

  /**
    Pan down by amt or this.panAmount.
  */
  panDown : function(amt) {
    if (!amt) amt = this.panAmount
    this.panBy(0, -amt)
  },

  /**
   Moves the whole map on by amtX, amtY.
   */
  moveBy : function(amtX, amtY) {
    var rfac = Math.pow(2, -this.parent.z)
    this.left += amtX * rfac
    this.top += amtY * rfac
    this.element.style.left = parseInt(this.element.style.left) + amtX + 'px'
    this.element.style.top = parseInt(this.element.style.top) + amtY + 'px'
    this.titleElem.style.left = parseInt(this.titleElem.style.left) + amtX + 'px'
    this.titleElem.style.top = parseInt(this.titleElem.style.top) + amtY + 'px'
  },

  /**
   Zooms each layer to zoom z, with (pointer_x, pointer_y) as the origin.
  */
  zoom : function(z, pointer_x, pointer_y) {
    for (var i=0; i<this.layers.length; i++) {
      var layer = this.layers[i]
      layer.zoom(z, pointer_x, pointer_y)
    }
    this.selectionLayer.zoom(z, pointer_x, pointer_y)
    this.submapLayer.zoom(z, pointer_x, pointer_y)
    this.x = this.submapLayer.x
    this.y = this.submapLayer.y
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
    this.submapLayer.updateTiles(pointer_x, pointer_y, dir, this.targetZ)
    if (this.noTiles) return
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
          (tile.X+1+border) * tile.rSize < -layer.x - this.element.left ||
          (tile.Y+1+border) * tile.rSize < -layer.y - this.element.top  ||
          (tile.X  -border) * tile.rSize > -layer.x - this.element.left + this.element.width ||
          (tile.Y  -border) * tile.rSize > -layer.y - this.element.top + this.element.height
        ) {
          layer.discardTile(i)
          i--
        }
      }
      // Keep z0 always loaded to avoid showing empty spots.
      // Request tiles that have wanted zoom.
      // Preload from two levels above when panning.
      // Preload from three levels above when zooming out.
      // Load most zoomed-in layer if zoomed beyond maxZoom.
      if (z == 0 ||
          z == this.targetZ ||
          (dir == 0 && z == this.targetZ-2) ||
          (dir == -1 && z == this.targetZ-3) ||
          (this.targetZ > this.maxZoom && z == this.maxZoom))
        layer.requestVisibleTiles(pointer_x, pointer_y, dir, at_zoom_end && z == this.targetZ)

      occluded = occluded || layer.coversWholeScreen(pointer_x, pointer_y, dir)
    }
  }

}


/**
  A zoomable layer that handles submaps instead of image tiles.
 */
SubmapLayer = function(map) {
  this.map = map
  this.z = 0
  this.own_fac = Math.pow(2, this.z)
  this.element = document.createElement("div")
  this.element.className = "submapLayer"
  this.element.style.position = "absolute"
  this.element.style.left = "0px"
  this.element.style.top = "0px"
  this.element.style.zIndex = 49
}
SubmapLayer.prototype = {
  x : 0,
  y : 0,
  z : 0,
  cZ : 0,
  fac : 1,
  rfac : 1,
  own_fac : 1,

  panBy : function(dx, dy) {
    var ox = Math.floor(this.x / this.map.tileSize)
    var oy = Math.floor(this.y / this.map.tileSize)
    var ox2 = Math.floor((this.x + this.map.element.width) / this.map.tileSize)
    var oy2 = Math.floor((this.y + this.map.element.height) / this.map.tileSize)
    this.x += dx
    this.y += dy
    this.element.style.left = Math.floor(this.x) + 'px'
    this.element.style.top = Math.floor(this.y) + 'px'
    var nx = Math.floor(this.x / this.map.tileSize)
    var ny = Math.floor(this.y / this.map.tileSize)
    var nx2 = Math.floor((this.x + this.map.element.width) / this.map.tileSize)
    var ny2 = Math.floor((this.y + this.map.element.height) / this.map.tileSize)
    if (ox != nx || oy != ny || ox2 != nx2 || oy2 != ny2) {
      return true
    }
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
    var divs = this.element.childNodes
    for (var j=0; j<divs.length; j++) {
      var d = divs[j]
      if (!d.isMap) continue
      var m = d.map
      d.left = Math.floor(m.left * fac)
      d.top = Math.floor(m.top * fac)
      d.width = Math.ceil(m.width * fac)
      d.height = Math.ceil(m.height * fac)
      d.style.left = d.left + 'px'
      d.style.top = d.top + 'px'
      d.style.width = d.width + 'px'
      d.style.height = d.height + 'px'
      m.titleElem.style.left = d.style.left
      m.titleElem.style.fontSize = (10 * fac) + 'px'
      m.titleElem.style.top = (d.top - 18 * fac) + 'px'
      this.cropMap(m)
      m.zoom(m.relativeZ+outer_z, 0,0)
    }
  },

  cropMap : function(m) {
    var d = m.element
    d.left = Math.floor(m.left * this.fac)
    d.top = Math.floor(m.top * this.fac)
    d.width = Math.ceil(m.width * this.fac)
    d.height = Math.ceil(m.height * this.fac)
    if (d.left + m.root.x < 0) {
      d.left += m.root.x
    }
    if (d.top + m.root.y < 0) {
      d.top += m.root.y
    }
    if (
      d.left > -m.root.x + m.root.width ||
      d.top > -m.root.y + m.root.height ||
      d.left + d.width < 0 ||
      d.top + d.height < 0
    ) {
      d.width = 0
      d.height = 0
    }
    if (d.width > m.parent.element.width) {
      d.width = m.parent.element.width
    }
    if (d.height > m.parent.element.height) {
      d.height = m.parent.element.height
    }
  },

  updateTiles : function(pointer_x, pointer_y, dir, tz) {
    var divs = this.element.childNodes
    for (var j=0; j<divs.length; j++) {
      var d = divs[j]
      if (!d.isMap) continue
      var m = d.map
      this.cropMap(m)
      m.targetZ = m.relativeZ + tz
      m.updateTiles(
        pointer_x - (m.left*this.fac),
        pointer_y - (m.top*this.fac),
        dir)
    }
  }
}


/**
  A zoomable layer that handles selection divs instead of image tiles.
 */
SelectionLayer = function(map) {
  this.map = map
  this.z = 0
  this.own_fac = Math.pow(2, this.z)
  this.element = document.createElement("div")
  this.element.className = "selectionLayer"
  this.element.style.position = "absolute"
  this.element.style.left = "0px"
  this.element.style.top = "0px"
  this.element.style.zIndex = 48
}
SelectionLayer.prototype = {
  x : 0,
  y : 0,
  z : 0,
  cZ : 0,
  fac : 1,
  rfac : 1,
  own_fac : 1,

  panBy : function(dx, dy) {
    this.x += dx
    this.y += dy
    this.element.style.left = this.x + 'px'
    this.element.style.top = this.y + 'px'
  },

  zoom : function(outer_z, pointer_x, pointer_y) {
    this.rx = (-this.x + pointer_x) * this.rfac
    this.ry = (-this.y + pointer_y) * this.rfac
    var fac = Math.pow(2, outer_z)
    this.panBy(-this.rx * (fac-this.fac), -this.ry * (fac-this.fac))
    this.fac = fac
    this.rfac = 1 / fac
    this.cZ = outer_z
    var divs = this.element.childNodes
    for (var j=0; j<divs.length; j++) {
      divs[j].style.width = divs[j].style.height = Math.ceil(fac) + 'px'
      divs[j].style.left = Math.floor(divs[j].X * fac) + 'px'
      divs[j].style.top = Math.floor(divs[j].Y * fac) + 'px'
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
    if (this.map.element.width <= 0 || this.map.element.height <= 0)
      return
    var tsz = this.map.tileSize * (this.fac / this.own_fac)
    var x0 = Math.floor(((-this.x-Math.min(0,this.map.element.left)) / tsz))
    var y0 = Math.floor(((-this.y-Math.min(0,this.map.element.top)) / tsz))
    var w = Math.ceil(this.map.element.width / tsz) + 1
    var h = Math.ceil(this.map.element.height / tsz) + 1
    if (dir == 0) {
      x0--
      y0--
      w++
      h++
    }
    var cs = this.map.children
    this.avoids = {}
    var ctsz = this.map.tileSize / this.own_fac
    for (var i=0; i<cs.length; i++) {
      var c = cs[i]
      var cx0 = Math.max(x0, Math.ceil(c.left/ctsz))
      var cy0 = Math.max(y0, Math.ceil(c.top/ctsz))
      var cx1 = Math.min(x0+w, Math.floor((c.left+c.width)/ctsz))
      var cy2 = Math.min(y0+h, Math.floor((c.top+c.height)/ctsz))
      for (var x=cx0; x<cx1; x++)
        for (var y=cy0; y<cy2; y++)
          this.avoids[x+':'+y] = true
    }
    for (var x=Math.max(this.isSubmap ? 0 : x0,x0); x<x0+w; x++) {
      for (var y=Math.max(this.isSubmap ? 0 : y0,y0); y<y0+h; y++) {
        var k = x+':'+y
        if (!this.tiles[k] && !this.avoids[k]) {
          var tile = this.makeTile(x, y, load_info)
          this.tiles.push(tile)
          this.tiles[k] = tile
          tile.zoom(this.cZ)
          var rx = this.x
          var ry = this.y
          if (this.map.parent != this.map) {
            rx = this.map.parent.submapLayer.x
            ry = this.map.parent.submapLayer.y
          }
          var tx = rx + ((tile.X+0.5) * tile.rSize)
          var ty = ry + ((tile.Y+0.5) * tile.rSize)
          var dx = (pointer_x-tx)
          var dy = (pointer_y-ty)
          this.map.loader.load(-this.z*(dir < 0 ? -1 : 1), dir*dx*dx+dy*dy, this, tile)
        } else if (this.tiles[k] && this.avoids[k]) {
          var i = this.tiles.indexOf(this.tiles[k])
          this.discardTile(i)
        }
      }
    }
  },

  coversWholeScreen : function(pointer_x, pointer_y, dir) {
    var tsz = this.map.tileSize * (this.fac / this.own_fac)
    if (dir < 0) tsz *= 0.5 // hack to avoid grey tiles on zooming out
    var x0 = Math.floor(((-this.x-Math.min(0,this.map.element.left)) / tsz))
    var y0 = Math.floor(((-this.y-Math.min(0,this.map.element.top)) / tsz))
    var w = Math.ceil(this.map.element.width / tsz) + 1
    var h = Math.ceil(this.map.element.height / tsz) + 1
    for (var x=Math.max(0,x0); x<x0+w; x++) {
      for (var y=Math.max(0,y0); y<y0+h; y++) {
        var tile = this.tiles[x + ":" + y]
        if (!tile || !tile.parentNode) return false
      }
    }
    return true
  },

  panBy : function(dx, dy) {
    var ox = Math.floor(this.x / this.map.tileSize)
    var oy = Math.floor(this.y / this.map.tileSize)
    var ox2 = Math.floor((this.x + this.map.width) / this.map.tileSize)
    var oy2 = Math.floor((this.y + this.map.height) / this.map.tileSize)
    this.x += dx
    this.y += dy
    this.element.style.left = Math.floor(this.x) + 'px'
    this.element.style.top = Math.floor(this.y) + 'px'
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
    tile.useMap = false
    tile.loading = false
    tile.map = this.map
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

  discardTile : function(i) {
    var tile = this.tiles[i]
    delete this.tiles[tile.X + ":" + tile.Y]
    this.tiles.splice(i,1)
    tile.loading = false
    tile.removeEventListener('load', this.__tileOnload, false)
    if (tile.parentNode)
      $(tile).detachSelf()
    this.map.loader.cancel(this, tile)
    if (tile.loaded) tile.loaded(false)
    if (tile.ImageMap && tile.ImageMap.parentNode) 
      $(tile.ImageMap).detachSelf()
    tile.useMap = false
    delete tile.handleInfo
    delete tile.ImageMap
    delete tile.map
    delete tile.query
    delete tile.load
    delete tile.zoom
    tile.className = null
    tile.style.position = null
    tile.style.cursor = 'default'
    this.map.pool.put(tile)
  },

  __tileLoad : function(server, infoManager) {
    this.src = server + this.relativeURL + this.query
    this.loading = true
    if (this.Z < 5) return
    this.style.cursor = 'wait'
    this.handleInfo = function(infos) {
      if (!infos) return
      this.style.cursor = 'default'
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
    this.style.left = Math.ceil(this.X * this.rSize) + 'px'
    this.style.top = Math.ceil(this.Y * this.rSize) + 'px'
    this.style.width = Math.ceil(this.rSize) + 'px'
    this.style.height = Math.ceil(this.rSize) + 'px'
  }
}

ImagePool = function() {
  this.pool = []
}
ImagePool.getPool = function() {
  if (!ImagePool.pool)
    ImagePool.pool = new ImagePool()
  return ImagePool.pool
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

Loader = function(map, servers, infoServers) {
  this.map = map
  this.servers = servers
  this.queue = new PriorityQueue()
  this.tileInfoManager = new TileInfoManager(map, infoServers)
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
  },
  
  flushCache : function() {
    this.tileInfoManager.flushCache()
  }

}


TileInfoManager = function(map, servers) {
  this.map = map
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
  cacheZ : 5,

  flushCache : function() {
    this.cache = {}
  },

  requestInfo : function(x,y,z, callback) {
    var rv = this.getCachedInfo(x,y,z)
    if (rv && callback.handleInfo)
      callback.handleInfo(rv)
    else
      this.bundleRequest(arguments)
  },

  getCachedInfo : function(x,y,z) {
    var zc = this.cache[z]
    var c = zc && zc[x+':'+y]
    if (c) {
      return c
    } else if (z > this.cacheZ) {
      if (!this.cache[this.cacheZ]) return false
      var zf = 1 << (z-this.cacheZ)
      var rzf = 1.0 / zf
      var rx = x * rzf
      var ry = y * rzf
      var rsz = this.map.tileSize * rzf
      var xz = Math.floor(rx / this.map.tileSize) * this.map.tileSize
      var yz = Math.floor(ry / this.map.tileSize) * this.map.tileSize
      var tz = this.cache[this.cacheZ][xz+':'+yz]
      if (!tz) return false
      var res = []
      var rrx = rx - xz
      var rry = ry - yz
      for (var i=0; i<tz.length; i++) {
        var a = tz[i]
        if (!(a.x+a.sz < rrx || a.y+a.sz < rry || a.x >= rrx+rsz || a.y >= rry+rsz)) {
          var na = Object.extend({}, a)
          na.x = (a.x - rrx) * zf
          na.y = (a.y - rry) * zf
          na.sz *= zf
          res.push(na)
        }
      }
      if (!this.cache[z]) this.cache[z] = {}
      this.cache[z][x+':'+y] = res
      return res
    } else {
      return false
    }
  },

  bundleRequest : function(req) {
    this.request_bundle.push(req)
    if (this.requestTimeout) clearTimeout(this.requestTimeout)
    this.requestTimeout = setTimeout(this.sendBundle, 500)
  },

  bundleSender : function() {
    var reqs = []
    var callbacks = []
    var reqb = this.request_bundle
    this.request_bundle = []
    var tsz = this.map.tileSize
    for (var i=0; i<reqb.length; i++) {
      var req = reqb[i]
      var info = this.getCachedInfo(req[0], req[1], req[2])
      if (!info) {
        if (req[2] >= this.cacheZ) {
          var rz = 1 << (req[2]-this.cacheZ)
          reqs.push([Math.floor(req[0]/rz/tsz) * tsz, Math.floor(req[1]/rz/tsz) * tsz, this.cacheZ])
        } else {
          reqs.push(req.slice(0,3))
        }
        callbacks.push(req)
      } else {
        this.callbackHandler(req)
      }
    }
    reqs = reqs.uniq()
    var t = this
    var parameters = {}
    parameters.tiles = Object.toJSON(reqs)
    if (this.map.query)
      parameters.q = this.map.query
    if (this.map.time)
      parameters.time = this.map.time
    new Ajax.Request(this.rotateServers(), {
      method : 'post',
      parameters : parameters,
      onSuccess : function(res) {
        var infos = res.responseText.evalJSON()
        for (var i=0; i<reqs.length; i++) {
          var info = infos[i]
          var req = reqs[i]
          if (!t.cache[req[2]])
            t.cache[req[2]] = {}
          t.cache[req[2]][req[0]+':'+req[1]] = info
        }
        // everything cached, let's retry getCachedInfo
        for (var i=0; i<callbacks.length; i++) {
          t.callbackHandler(callbacks[i])
        }
      },
      onFailure : function(res) {
        for (var i=0; i<callbacks.length; i++) {
          var callback = callbacks[i]
          if (callback[3].handleInfo)
            callback[3].handleInfo(false)
        }
      }
    })
    this.requestTimeout = false
  },

  callbackHandler : function(callback) {
    setTimeout(this.makeCallbackHandler(callback), this.callbackDelay)
  },

  makeCallbackHandler : function(callback) {
    var t = this
    return function(){
      if (callback[3].handleInfo) {
        var info = t.getCachedInfo.apply(t, callback)
        callback[3].handleInfo(info)
      }
    }
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
