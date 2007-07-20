/*
  PortalMap.js - zoomable hierarchical tilemap widget for javascript
  Copyright (C) 2007  Ilmari Heikkinen

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
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


Object.require('/scripts/zogen/MapHelpers.js')
Object.require('/scripts/zogen/MapItems.js')
Object.require('/scripts/zogen/Selection.js')


Zoomable = {
  left : 0, top : 0,
  relativeZ : 0, 
  width: 0, height: 0,
  bgColor : null,
  className : null,
  minVisibleWidth : 1,
  minVisibleHeight : 1,

  // state variables
  tx : 0, ty : 0, z : 0, targetZ : 0,
  x : 0, y : 0, w : 256, h : 256,
  ax : 0, ay : 0,
  is_visible : true,
  
  init : function(config) {
    if (config) Object.extend(this, config)
    this.children = []
    this.element = E('div',null,null,this.className, {
      position: 'absolute',
      top: '0px',
      left: '0px',
      width: this.width + 'px',
      height: this.height + 'px'
    })
    this.ownWidth = this.width
    this.ownHeight = this.height
    this.right = this.left + this.width
    this.bottom = this.top + this.height
    if (this.parent) {
      this.parent.addChild(this)
    } else if (this.container) {
      this.root = this
      this.loader = new Loader(this)
      this.setContainer(this.container)
    }
  },
  
  /**
    Sets parent node in zoomable scenegraph.
    */
  setParent : function(parent) {
    this.parent = parent
    this.bgColor = parent.bgColor
    this.root = parent.root
    this.loader = parent.loader
    this.setContainer(parent.container)
  },
  
  /**
    Sets the container for the map.
    */
  setContainer : function(container) {
    this.container = container
    if (!this.parent) {
      this.container.appendChild(this.element)
      this.container.style.backgroundColor = '#'+this.bgColor
    }
  },
  
  /**
    Sets bgColor for this and passes down to children.
    */
  setBgColor : function(bgcolor) {
    this.bgColor = bgcolor
    this.children.invoke('setBgColor', bgcolor)
  },
  
  /**
    Adds child to zoomable scenegraph.
    */
  addChild : function(child) {
    child.setParent(this)
    if (child.element)
      this.element.appendChild(child.element)
    if (!this.children.include(child))
      this.children.push(child)
    child.z = this.z + this.relativeZ
    child.updateDimensions()
    child.zoom(child.z)
  },

  /**
    Figure out if this portal is visible by comparing its extents
    to the container's extents.
    Hide portal if its width is smaller than minVisibleWidth or
    its height is smaller than minVisibleHeight.
    */
  isVisible : function(need_update) {
    if (!need_update) return this.is_visible
    if (this.parent && (this.parent.is_visible == false)) {
      this.is_visible = false
    } else if (this.w < this.minVisibleWidth || this.h < this.minVisibleHeight) {
      this.is_visible = false
    } else {
      var c = this.projectExtentsToContainer()
      this.is_visible = (c.right > 0 && c.bottom > 0 &&
                         c.left < this.container.width && c.top < this.container.height)
    }
    return this.is_visible
  },

  /**
    Called when the map has been moved.
    Updates map visibility.
    */
  moved : function(dx, dy) {
    this.updateAbsoluteCoordinates()
    var need_update = (dx != 0 || dy != 0)
    if (this.isVisible(need_update)) {
      for(var i=0,cl=this.children.length; i<cl; i++)
        this.children[i].moved(dx, dy)
      if (this.element.style.display == 'none')
        this.zoom(this.z)
      return true
    } else if (this.element.style.display != 'none') {
      this.element.style.display = 'none'
      return false
    }
  },

  /**
    Zooms to z and sets targetZ to targetZ || z.
    Updates absolute and parent-relative position and size.
    Zooms children if visible.
    */
  zoom : function(z, targetZ) {
    var need_update = (z != this.z)
    this.z = z
    this.targetZ = targetZ == undefined ? z : targetZ
    this.updatePosition()
    this.updateAbsoluteCoordinates()
    if (this.isVisible(need_update)) {
      if (this.element.style.display == 'none')
        this.element.style.display = 'inherit'
      var c = this.children
      var rz = z+this.relativeZ
      var rtz = this.targetZ+this.relativeZ
      for (var i=0,cl=c.length; i<cl; i++)
        c[i].zoom(rz, rtz)
      return true
    } else {
      this.element.style.display = 'none'
      return false
    }
  },

  /**
    Project extents to viewport space.
    */
  projectExtentsToContainer : function() {
    return {
      left: this.ax,
      top: this.ay,
      right: this.ax + this.w,
      bottom: this.ay + this.h,
    }
  },

  /**
    Updates boundary dimensions for the map.
    */
  updateDimensions : function(updateParent) {
    this.leftBound = this.topBound = this.bottomBound = this.rightBound = 0
    if (this.children && this.children.length > 0) {
      this.leftBound = this.children.pluck('left').min()
      this.topBound = this.children.pluck('top').min()
      this.rightBound = this.children.pluck('right').max()
      this.bottomBound = this.children.pluck('bottom').max()
      var fac = Math.pow(2,this.relativeZ)
      if (this.leftBound != 0) {
        var lb = -this.leftBound
        this.left -= lb * fac
        this.rightBound += lb
        for (var i=0; i<this.children.length; i++) {
          var c = this.children[i]
          if (c.noMoveWithResize) continue
          c.left += lb
          c.right += lb
          c.updatePosition()
        }
        this.leftBound = 0
      }
      if (this.topBound != 0) {
        var lb = -this.topBound
        this.top -= lb * fac
        this.bottomBound += lb
        for (var i=0; i<this.children.length; i++) {
          var c = this.children[i]
          if (c.noMoveWithResize) continue
          c.top += lb
          c.bottom += lb
          c.updatePosition()
        }
        this.topBound = 0
      }
    }
    this.updatePosition()
    if (this.parent) this.parent.updateDimensions()
  },

  /**
    Updates position and dimensions of element.
    */
  updatePosition : function() {
    var relfac = Math.pow(2, this.relativeZ)
    this.width = Math.max(this.rightBound-this.leftBound, this.ownWidth)*relfac
    this.height = Math.max(this.bottomBound-this.topBound, this.ownHeight)*relfac
    this.updateCoordinates()
    this.element.style.left = Math.floor(this.x) + 'px'
    this.element.style.top = Math.floor(this.y) + 'px'
    this.element.style.width = Math.ceil(this.w) + 'px'
    this.element.style.height = Math.ceil(this.h) + 'px'
    this.right = this.left + this.width
    this.bottom = this.top + this.height
  },

  /**
    Updates absolute coordinates.
    */
  updateAbsoluteCoordinates : function() {
    this.ax = this.x
    this.ay = this.y
    if (this.parent) {
      this.ax += this.parent.ax
      this.ay += this.parent.ay
    }
  },

  /**
    Updates parent-relative map coordinates.
    */
  updateCoordinates : function() {
    var fac = Math.pow(2, this.z)
    this.x = this.left * fac
    this.y = this.top * fac
    this.w = this.width * fac
    this.h = this.height * fac
  }

}
Object.extend(Zoomable, EventListener)






/**
  A Portal consists of a selection layer and a submap layer.
  
  When panning the top-level map, it informs all its submaps.
  
  A map that is outside the container hides itself and stops updating
  its submaps.

  The submaps of a map can't go outside the parent map's boundary -
  the parent map's boundary is ( min(submaps.left), min(submaps.top),
  max(submaps.right), max(submaps.bottom) ).
  */
Portal = function(config) {
  this.init(config)
}
Portal.prototype = Object.extend({}, Zoomable)
Object.extend(Portal.prototype, {
  pointerX : 0, pointerY : 0,
  maxZoom : 16, minZoom : -3,
  className : 'PortalBackground',
  bgColor : '13163C',

  // state variables
  zoomIn : false, zoomOut : false,

  /**
    Does an animated zoom towards the cursor.
    */
  animatedZoom : function( z, dx, dy ) {
    if (this.animation || z > this.maxZoom || z < this.minZoom) return
    this.pointerX = dx
    this.pointerY = dy
    var elapsed = 0
    var time = new Date().getTime()
    var oz = this.z
    var delay = this.zoomIn || this.zoomOut ? 200 : 200
    this.animation = setInterval(function(){
      var t = new Date().getTime()
      elapsed += t - time
      time = t
      var pos = elapsed / delay
      if (pos >= 1) {
        if (this.zoomOut || this.zoomIn) {
          pos %= 1
          elapsed = pos * delay
          time = t
          if (this.zoomIn) z++
          if (this.zoomOut) z--
          if (z >= this.maxZoom-0.00001 || z <= this.minZoom-0.00001) {
            pos = 1
          } else {
            oz = this.z
          }
        } else {
          pos = 1
        }
      }
      var nz = z * pos + oz * (1-pos)
      this.panBy(-this.pointerX, -this.pointerY, false)
      this.z = nz
      this.updateCoordinates()
      this.panBy(this.pointerX, this.pointerY, false)
      this.zoom(nz, z)
      if (pos == 1) {
        clearInterval(this.animation)
        this.animation = false
      }
    }.bind(this), 20)
  },

  /**
    Moves the map by dx, dy.
    */
  panBy : function(dx, dy, updateCoords) {
    var fac = Math.pow(2, -this.z)
    var rdx = dx * fac
    var rdy = dy * fac
    this.left += rdx
    this.right += rdx
    this.top += rdy
    this.bottom += rdy
    if (updateCoords != false) {
      this.updatePosition()
      this.moved(dx, dy)
    }
  }

})









/**
  TitledPortal has a Portal and a Title.
 */
TitledPortal = function(config) {
  this.init(config)
  this.title = new Title({parent: this, title: this.title, relativeZ: 1, maxFontSize: 40})
  this.portal = new Portal(
    Object.extend(Object.clone(config),
    {parent: this, relativeZ: 0, left: 0, top: 56})
  )
}
TitledPortal.prototype = Object.extend({}, Zoomable)
Object.extend(TitledPortal.prototype, {
  className : 'TitledPortal'
})



/**
  A PortalMap has a TileMap and a Title.
 */
PortalMap = function(config) {
  this.init(config)
  this.title = new Title({parent: this, title: this.title})
  this.map = new TileMap(
    Object.extend(Object.clone(config),
    {parent: this, relativeZ: 0, left: 0, top: 28})
  )
}
PortalMap.prototype = Object.extend({}, Zoomable)
Object.extend(PortalMap.prototype, {
  className : 'PortalMap'
})







Title = function(config) {
  this.init(config)
}
Title.prototype = Object.extend({}, Zoomable)
Object.extend(Title.prototype, {
  title: 'Title',
  className: 'Title',
  fontSize : 20,
  maxFontSize : 20,
  minVisibleWidth : 4,
  minVisibleHeight : 2,
  noMoveWithResize : true,

  // state vars
  absoluteFontSize : 0,

  init : function(config) {
    this.onTitleChange = this.titleChangeHandler.bind(this)
    this.titleElement = E('h3')
    this.titleElement.style.display = 'block'
    this.titleElement.style.position = 'absolute'
    this.titleElement.style.margin = '0px'
    this.titleElement.style.padding = '0px'
    this.titleElement.style.color = 'white'
    this.titleElement.style.cursor = 'move'
    this.titleElement.style.fontFamily = 'URW Gothic L'
    Zoomable.init.apply(this, arguments)
    this.element.appendChild(this.titleElement)
    this.setTitle( this.title )
    this.setupEventListeners()
  },

  setupEventListeners : function(){
    this.element.addEventListener('mousedown', function(ev){
      if (Event.isLeftClick(ev)) {
        this.downX = Event.pointerX(ev)
        this.downY = Event.pointerY(ev)
        this.down = true
        Event.stop(ev)
      }
    }.bind(this.parent), false)
    window.addEventListener('mouseup', function(ev){
      if (Event.isLeftClick(ev)) {
        this.dragging = false
        this.down = false
        Event.stop(ev)
      }
    }.bind(this.parent), false)
    window.addEventListener('mousemove', function(ev){
      if (this.dragging) {
        this.currentX = Event.pointerX(ev)
        this.currentY = Event.pointerY(ev)
        var fac = Math.pow(2, this.z)
        var dx = (this.currentX - this.dragX) / fac
        var dy = (this.currentY - this.dragY) / fac
        this.left += dx
        this.right += dx
        this.top += dy
        this.bottom += dy
        this.updateDimensions()
        this.moved(dx, dy)
        this.dragX = this.currentX
        this.dragY = this.currentY
        Event.stop(ev)
      } else if (this.down) {
        this.currentX = Event.pointerX(ev)
        this.currentY = Event.pointerY(ev)
        if (Math.abs(this.currentX - this.downX) > 3 ||
            Math.abs(this.currentY - this.downY) > 3) {
          this.dragX = this.currentX
          this.dragY = this.currentY
          this.dragging = true
        }
        Event.stop(ev)
      }
    }.bind(this.parent), false)
  },

  setParent : function() {
    if (this.parent)
      this.parent.removeListener('titleChange', this.onTitleChange)
    Zoomable.setParent.apply(this, arguments)
    if (this.parent)
      this.parent.addListener('titleChange', this.onTitleChange)
  },

  zoom : function(z,tz) {
    var need_update = (this.z != z)
    if (Zoomable.zoom.apply(this, arguments)) {
      var maxfac = this.maxFontSize / this.fontSize
      var fac = Math.min(Math.pow(2,this.z+this.relativeZ), maxfac)
      var newFontSize = Math.round(this.fontSize * fac)
      if (newFontSize != this.absoluteFontSize) {
        this.absoluteFontSize = newFontSize
        this.titleElement.style.fontSize = this.absoluteFontSize + 'px'
        need_update = true
      }
      if (need_update)
        this.titleElement.style.top = Math.floor(this.h - this.ownHeight*fac) + 'px'
    }
  },

  titleChangeHandler : function(ev){
    this.setTitle(ev.value)
  },

  setTitle : function(title) {
    this.title = title
    this.titleElement.innerHTML = this.title
    this.titleElement.style.fontSize = Math.round(this.fontSize) + 'px'
    this.ownWidth = this.titleElement.offsetWidth
    this.ownHeight = this.titleElement.offsetHeight
    this.absoluteFontSize = 0
    this.zoom(this.z)
  }
})





/**
  A TileMap consists of a map tiletree.
  
  A map that has moved to new floor(absolute_c / tileSize) -coord
  updates its visible tileset.
  
 */
TileMap = function(config) {
  this.init(config)
}

TileMap.prototype = Object.extend({}, Zoomable)
Object.extend(TileMap.prototype, {
  tileServers : [
    'http://t0.manifold.fhtr.org:8080/tile/',
    'http://t1.manifold.fhtr.org:8080/tile/',
    'http://t2.manifold.fhtr.org:8080/tile/',
    'http://t3.manifold.fhtr.org:8080/tile/'
  ],
  tileInfoServers : [
    '/tile_info/'
  ],
  
  tileSize : 256,
  tileQuery : false,
  className : 'MapBackground',
  bgColor : '13163C',
  
  minVisibleWidth :  5,
  minVisibleHeight : 5,

  time : new Date().getTime(),
  
  init : function(config) {
    this.tiles = []
    Zoomable.init.apply(this, arguments)
    this.element.style.backgroundColor = '#444444'
    this.element.style.overflow = 'hidden'
    this.updateInfo()
  },

  /**
    Updates dimensions from the server.
    */
  updateInfo : function() {
    this.discardTiles()
    new Ajax.Request('/tile_info', {
      method : 'get',
      onSuccess : function(res) {
        var obj = res.responseText.evalJSON()
        var dims = obj.dimensions
        this.tileInfo = obj
        this.ownWidth = obj.dimensions.width
        this.ownHeight = obj.dimensions.height
        if (this.ownWidth < this.minVisibleWidth)
          this.minVisibleWidth = this.ownWidth
        if (this.ownHeight < this.minVisibleHeight)
          this.minVisibleHeight = this.ownHeight
        this.updateDimensions()
        this.initTiles()
      }.bind(this)
    })
  },

  /**
    Creates the top-level TileNodes for this map.
    */
  initTiles : function() {
    for (var y=0; y < this.ownHeight/this.tileSize; y++) {
      for (var x=0; x < this.ownWidth/this.tileSize; x++) {
        var tile = new TileNode(x, y, 0, null, this)
        this.tiles.push(tile)
      }
    }
    var z = this.z+this.relativeZ
    if (this.isVisible())
      for(var i=0,cl=this.tiles.length; i<cl; i++)
        this.tiles[i].zoom(z,z)
  },

  /**
    Discards the top-level TileNodes.
    */
  discardTiles : function() {
    for(var i=0,cl=this.tiles.length; i<cl; i++)
      this.tiles[i].unload()
    this.tiles.clear()
  },
  
  /**
    Zooms map.
    */
  zoom : function(z, targetZ) {
    if (Zoomable.zoom.apply(this, arguments)) {
      var c = this.tiles
      var rz = z+this.relativeZ
      var rtz = this.targetZ+this.relativeZ
      for (var i=0,cl=c.length; i<cl; i++)
        c[i].zoom(rz, rtz)
    }
  },
  
  /**
    Called when the map has been moved.
    Updates tiles and map visibility.
    */
  moved : function(dx, dy) {
    if (Zoomable.moved.apply(this, arguments)) {
      var rtsz = 1 / (this.tileSize*Math.pow(2,Math.min(0, this.z+this.relativeZ)))
      var x = Math.min(this.ax, 0)
      var y = Math.min(this.ay, 0)
      var tl = Math.floor(x * rtsz)
      var tt = Math.floor(y * rtsz)
      var tr = Math.floor((x+this.w) * rtsz)
      var tb = Math.floor((y+this.h) * rtsz)
      if (tl != this.tl || tt != this.tt || tr != this.tr || tb != this.tb) {
        this.tl = tl
        this.tt = tt
        this.tb = tb
        this.tr = tr
        this.zoom(this.z)
      }
    }
  },
  
  /**
    Rotates the tile servers and returns the current first tile server.
    */
  rotateTileServers : function() {
    this.tileServers.push(this.tileServers.shift())
    return this.tileServers[0]
  },
  
  /**
    Rotates the tile info servers and returns the current first tile info server.
    */
  rotateTileInfoServers : function() {
    this.tileInfoServers.push(this.tileInfoServers.shift())
    return this.tileInfoServers[0]
  },
  
  getTileQuery : function() {
    return "?time=" + this.time
  },
  
  getInfoQuery : function() {
    return "?time=" + this.time
  }

})












/**
  TileNodes make up a mipmap hierarchy.

  When you zoom in, each visible TileNode creates children for itself,
  which load their tile images from the server.
  If the TileNode's children cover the container-intersecting part of
  the TileNode, the TileNode hides its image.
  
  When zooming out, the TileNode shows its image and discards its children.

  */
TileNode = function(x, y, z, parent, map) {
  this.x = x
  this.y = y
  this.z = z
  this.map = map
  this.uuid = TileNode.uuid++
  this.children = []
  this.setParent(parent)
}
TileNode.uuid = 0
TileNode.prototype = {
  maxZoom : 15,

  getImageURL : function() {
    return this.map.rotateTileServers() + this.getTilePath()
  },

  getInfoURL : function() {
    return this.map.rotateTileInfoServers() + this.getInfoPath()
  },

  getInfoQuery : function() {
    return this.map.getInfoQuery()
  },

  getInfoServer : function() {
    return this.map.rotateTileInfoServers()
  },

  getInfoPath : function() {
    return 'x'+this.tileX  +  'y'+this.tileY  +  'z'+this.z + this.map.getInfoQuery()
  },

  getTilePath : function() {
    return 'x'+this.tileX  +  'y'+this.tileY  +  'z'+this.z + this.map.getTileQuery()
  },

  /**
    Sets node's parent node (called on TileNode creation.)
    */
  setParent : function(parent) {
    this.parent = parent
    if (!this.parent) {
      this.parent = this
      this.root = this
      this.tileX = this.x * 256
      this.tileY = this.y * 256
    } else {
      this.tileX = this.parent.tileX * 2 + this.x * 256
      this.tileY = this.parent.tileY * 2 + this.y * 256
    }
    this.root = this.parent.root
  },

  /**
    Gets the selection that this tile uses.
    */
  getSelection : function() {
    return this.root.selection
  },
  
  /**
    Zooms this node to the zoom level.
    
    Sets the position and dimensions of this TileNode, updates visibility,
    creates/discards children when needed.

    Invokes zoom on children if there are any.

    Loads image if needed.
    */
  zoom : function(zoom, targetZ) {
    this.updateDims(zoom, targetZ)
    this.updateVars(zoom, targetZ)
    if (this.image && !this.imageHidden && this.changed)
      this.updateImage()
    if (this.is_visible) {
      this.determineChildren()
      this.determineImage()
      for(var i=0,cl=this.children.length; i<cl; i++)
        this.children[i].zoom(this.zoom_level, this.targetZ)
      this.updateCoverage()
    } else {
      this.hideImage()
      this.determineChildren()
      for(var i=0,cl=this.children.length; i<cl; i++)
        this.children[i].zoom(this.zoom_level, this.targetZ)
    }
  },

  determineChildren : function() {
    if (this.d <= 0 || this.is_current) {
      if (this.zoom_complete && (!this.is_visible || this.loaded || this.above_loaded))
        this.discardChildren()
    } else if (this.is_visible && !this.is_current) {
      this.createChildren()
    }
  },

  updateImage : function() {
    if (this.image && !this.imageHidden && this.changed) {
      this.image.style.left = this.left + 'px'
      this.image.style.top = this.top + 'px'
      this.image.style.width = this.image.style.height = this.size + 'px'
    }
  },

  updateDims : function(zoom, targetZ) {
    var zfac = Math.pow(2, zoom - this.z)
    this.left = 0
    this.top = 0
    if (this.parent == this)
      this.size = this.map.tileSize * zfac
    else
      this.size = this.parent.size * 0.5
    this.left = Math.floor(this.parent.left + this.x * this.size)
    this.top = Math.floor(this.parent.top + this.y * this.size)
    this.size = Math.ceil(this.size)
  },
  
  updateVars : function(zoom, targetZ) {
    if (this.zoom_level != zoom) this.changed = true
    this.zoom_level = zoom
    this.zoom_complete = zoom == targetZ
    if (this.targetZ != targetZ || this.zoom_complete) {
      this.targetZ = targetZ
      var d = this.d = targetZ - this.z
      var zo = (targetZ <= this.z && this.parent == this)
      this.is_zoom_out_cache = (this.parent==this) || (d == 2 && targetZ-zoom <= 0)
      this.is_current = d == 0 || zo || this.z == this.maxZoom
      this.load_image = (d >= 0 && d < 1) || this.is_zoom_out_cache
      this.too_high_res = d < 0 && !zo
      this.too_low_res = d > 2 && !zo
    }
    if (this.parent == this) this.is_visible = this.isVisible()
    else this.is_visible = this.parent.is_visible && this.isVisible()
    if (d <= 0)
      this.above_loaded = this.parent.above_loaded || this.loaded
    else
      this.above_loaded = false
    this.need_high_res = !this.above_loaded
    this.need_image =
      this.load_image && this.is_visible &&
      (this.is_current || this.is_zoom_out_cache)
  },

  determineImage : function() {
    if (this.need_image) {
      if (!this.image && this.load_image) this.loadImage(this.targetZ)
      if (!this.is_current && this.above_loaded) this.hideImage(false)
    // cancel unloaded tiles
    } else if (this.zoom_complete && !this.loaded) {
      this.discardImage()
    // toss unneeded hires tiles and lores tiles
    } else if ((this.too_high_res && !this.need_high_res) || (this.zoom_complete && this.too_low_res)) {
      this.hideImage()
    }
  },

  /**
    Hides the image of this TileNode if it has one.
    */
  hideImage : function(discard) {
    this.imageHidden = true
    if (!this.loaded && discard != false) this.discardImage()
    else if (this.image) this.image.style.display = 'none'
  },

  /**
    Shows the image of this TileNode if it has one.
    */
  showImage : function() {
    this.imageHidden = false
    if (this.image && this.loaded) {
      this.changed = true
      this.updateImage()
      this.image.style.display = 'block'
    }
  },

  /**
    Update coverage.
    */
  updateCoverage : function() {
    if (this.targetZ <= this.z) {
      if (this.parent != this) {
        var o = this
        while (o.z <= this.targetZ) {
          if (o.loaded || o.above_loaded) {
            this.above_loaded = true
            break
          }
          o = o.parent
          if (o == o.parent) break
        }
      } else {
        this.above_loaded = this.loaded
      }
      if (!this.is_visible || this.above_loaded) {
        this.discardChildren()
      }
      return
    }
    this.covered = this.isCovered()
    if (this.covered)
      this.hideImage()
    else
      this.showImage()
  },

  /**
    Figure out if this TileNode is hidden from view by its children.
    */
  isCovered : function() {
    if (this.children.length == 0) {
      return false
    } else {
      for (var i=0; i<this.children.length; i++) {
        if (!(this.children[i].covered || this.children[i].loaded) &&
            this.children[i].isVisible()
        ) {
          return false
        }
      }
      return true
    }
  },

  /**
    Figure out if this TileNode is visible by comparing its extents
    to the container's extents.
    */
  isVisible : function() {
    var m = this.root.map
    var c = this.projectExtentsToContainer()
    var container = m.container
    return (c.right > -this.size && c.bottom > -this.size &&
            c.left < container.width + this.size && c.top < container.height + this.size)
  },

  /**
    Project extents to viewport space.
    */
  projectExtentsToContainer : function() {
    var m = this.map
    var c = m.projectExtentsToContainer()
    return {
      left: c.left + this.left,
      top: c.top + this.top,
      right: c.left + this.left + this.size,
      bottom: c.top + this.top + this.size,
    }
  },
  
  /**
    Creates the lower level mipmap children for this tile.
    
    Ordered like this:
    [ 0, 1 ]
    [ 2, 3 ]
    */
  createChildren : function() {
    if (this.maxZoom != undefined && this.z >= this.maxZoom) return
    if (this.children.length > 0) return
    for(var y=0; y<2; y++) {
      for(var x=0; x<2; x++) {
        this.children.push(new TileNode(x, y, this.z+1, this, this.map))
      }
    }
  },

  /**
    Discards children.
    */
  discardChildren : function() {
    this.covered = false
    this.showImage()
    for(var i=0,cl=this.children.length; i<cl; i++)
      this.children[i].unload()
    this.children.clear()
  },

  /**
    Sends a load request to the loader.
    */
  loadImage : function(zoom) {
    this.image = ImagePool.getPool().get()
    this.image.tile = this
    var c = this.projectExtentsToContainer()
    var dx = ((c.left + this.size/2)-this.map.root.pointerX)
    var dy = ((c.top + this.size/2)-this.map.root.pointerY)
    var container = this.root.map.container
    var directly_visible = (
      c.right > 0 && c.bottom > 0 &&
      c.left < container.width && c.top < container.height
    )
    var dz = (directly_visible ? 0 : 5) // load offscreen tiles last
    this.root.map.loader.load(
      -this.z + dz,
      Math.sqrt(dx*dx+dy*dy),
      this
    )
  },

  /**
    Delegate to this.image.
    */
  addEventListener : function(e,f,b) {
    this.image.addEventListener(e,f,b)
  },

  /**
    Delegate to this.image.
    */
  removeEventListener : function(e,f,b) {
    this.image.removeEventListener(e,f,b)
  },

  /**
    Called by the loader.
    */
  load : function(tileInfoManager) {
    if (!this.image) return
    this.image.style.position = 'absolute'
    this.image.style.zIndex = this.z
    this.image.style.display = 'none'
    this.image.style.border = '0px'
    this.image.tile = this
    this.image.onload = this.onload.bind(this)
    this.map.element.appendChild(this.image)
    var url = this.getImageURL()
    this.image.src = url
    if (this.z < 5) return
    this.image.style.cursor = 'wait'
    this.handleInfo = function(infos) {
      if (!infos || !this.image) return
      this.image.style.cursor = 'default'
      this.image.ImageMap = E('map')
      this.image.ImageMap.name = this.image.src
      this.image.appendChild(this.image.ImageMap)
      for(var i=0; i<infos.length; i++) {
        var info = infos[i]
        var area = E('area')
        Object.extend(area, ItemArea)
        area.info = info
        area.shape = 'rect'
        area.coords = [info.x, info.y, info.x + info.sz, info.y + info.sz].join(",")
        area.href = '/files/' + info.path
        area.title = area.getTitle()
        area.itemHREF = '/items/' + info.path + '/json'
        this.image.ImageMap.appendChild(area)
      }
      this.image.useMap = '#'+this.image.src
    }
    tileInfoManager.requestInfo(this.getInfoServer()+this.getInfoQuery(), this.tileX, this.tileY, this.z, this)
  },

  /**
    Event listener for the tile image onload.
    */
  onload : function() {
    if (!this.image) return
    this.image.style.left = this.left + 'px'
    this.image.style.top = this.top + 'px'
    this.image.style.width = this.image.style.height = this.size + 'px'
    this.loaded = true
    this.updateCoverage()
    if (this.parent != this) this.parent.updateCoverage()
  },

  /**
    Discards the tile image of this node and returns it to the ImagePool.
    */
  discardImage : function() {
    if (this.loader) this.loader()
    if (this.image) {
      if (!this.loaded) {
        delete this.image.onload
        this.map.loader.cancel(this)
      }
      this.image.src = 'data:'
      if (this.image.parentNode) $(this.image).detachSelf()
      delete this.image.tile
      ImagePool.getPool().put(this.image)
      delete this.image
    }
    this.loaded = false
  },

  /**
    Unloads the tile and its children.
    */
  unload : function(){
    this.discardChildren()
    this.hideImage(false)
    setTimeout(function(){
      this.discardImage()
      if (this.loader) this.loader()
      this.map.loader.cancel(this)
      delete this.parent
      delete this.root
      delete this.children
      delete this.map
    }.bind(this), 50)
  }
}




