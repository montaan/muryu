Desk.Panel = function(side, applets, config){
  this.applets = []
  Desk.Window.apply(this, [null, config])
  if (applets)
    applets.each(this.addApplet.bind(this))
  this.updatePlanes()
  if (side) this.side = side
  this.setSide(this.side)
}
Desk.Panel.loadSession = function(data){
  return new Desk.Panel(
    data.side,
    data.applets.map(Session.loadDump),
    data.config)
}
Desk.Panel.prototype = {}
Object.extend(Desk.Panel.prototype, Desk.Window.prototype)
Object.extend(Desk.Panel.prototype, {
  defaultButtons : [],
  side : 'bottom',
  avoid : true,
  movable : false,
  showInTaskbar : false,
  layer : 10,
  loader : 'Desk.Panel',

  dumpSession : function() {
    var dump = Desk.Window.prototype.dumpSession.apply(this)
    dump.data.side = this.side
    dump.data.applets = this.applets.invoke('dumpSession')
    return dump
  },

  addApplet : function(applet) {
    this.applets.push(applet)
    this.contentElement.appendChild(applet)
    applet.panel = this
    this.newEvent('addApplet', {value: applet})
  },

  removeApplet : function(applet) {
    this.applets.deleteFirst(applet)
    this.contentElement.removeChild(applet)
    this.newEvent('removeApplet', {value: applet})
    applet.panel = null
  },

  init : function() {
    Desk.Window.prototype.init.apply(this)
    this.menu = new Desk.Menu()
    this.menu.addTitle('Panel')
    var t = this
    this.menu.addSubMenu('Add Applet', function(sm){
      var r = []
      for (i in Applets)
        if (i.match(/^[A-Z]/)) r.push(i)
      r.each(function(e){
        sm.addItem(e, function(){
          t.addApplet( Applets[e](t.windowManager) ) })
      })
    })
    this.menu.addItem('Remove Panel', this.close.bind(this), 'icons/Remove.png')
    this.element.addEventListener("DOMAttrModified", function(e){
      if (e.attrName == 'style') {
        this.updatePlanes()
        if (this.updateTimeout) clearTimeout(this.updateTimeout)
        this.updateTimeout = setTimeout(this.updateOffsets.bind(this), 20)
      }
    }.bind(this), false)
    this.element.addEventListener('click', function(e){
      if (Event.isLeftClick(e) && e.ctrlKey) {
        this.menu.show(e)
        Event.stop(e)
      }
    }.bind(this), false)
    window.addEventListener("mousemove", function(e){
      if (this.dragging) {
        var v = this.dragCur
        var closest_plane = this.planes.minKey(
          function(kv){ return kv[1].distance(v) })
        if (this.side != closest_plane)
          this.setSide(closest_plane)
      }
    }.bind(this), false)
  },

  updateOffsets : function() {
    if (this.element.offsetWidth != this.element.previousOffsetWidth ||
        this.element.offsetHeight != this.element.previousOffsetHeight) {
      this.element.previousOffsetWidth = this.element.offsetWidth
      this.element.previousOffsetHeight = this.element.offsetHeight
      this.windowManager.updateConstraints()
    }
  },

  updatePlanes : function() {
    var planes = new Hash()
    planes['top'] = new Plane(
      0, 1, parseInt(this.container.getStyle('top')))
    planes['bottom'] = new Plane(
      0, 1, this.container.getHeight() + planes['top'].y)
    planes['left'] = new Plane(
      1, 0, parseInt(this.container.getStyle('left')))
    planes['right'] = new Plane(
      1, 0, this.container.getWidth() + planes['left'].x)
    this.planes = planes
  },

  setSide : function(side) {
    this.side = side
    this.element.className = 'panel '+side+'Panel'
    if (this.container) {
      if (this.side == 'top') {
        this.element.style.height = null
        this.setX(0)
        this.setY(0)
        this.element.style.width = '100%'
      } else if (this.side == 'bottom') {
        this.element.style.height = null
        var h = this.element.getHeight()
        var ch = this.container.getHeight()
        this.setX(0)
        this.setY(ch-h)
        this.element.style.width = '100%'
      } else if (this.side == 'left') {
        this.element.style.width = null
        this.setX(0)
        this.setY(0)
        this.element.style.height = '100%'
      } else if (this.side == 'right') {
        this.element.style.width = null
        var w = this.element.getWidth()
        var cw = this.container.getWidth()
        this.setX(cw-w)
        this.setY(0)
        this.element.style.width = w + 'px'
        this.element.style.height = '100%'
      }
      this.windowManager.updateConstraints()
    }
  }
})
